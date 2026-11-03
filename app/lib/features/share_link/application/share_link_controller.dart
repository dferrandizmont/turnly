import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/diagnostics/crash_reporting.dart';
import '../../../core/providers.dart';
import '../../calendar/application/schedule_controller.dart';
import '../../calendar_export/application/ics_export.dart';
import '../../calendars/application/calendars_providers.dart';
import '../../calendars/domain/calendar.dart';
import '../../schedule/application/schedule_providers.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../data/share_link_api.dart';
import '../data/share_link_repository.dart';
import '../domain/share_feed.dart';
import '../domain/share_token.dart';

/// Least time between two automatic uploads (the schedule changed).
const Duration shareAutoUploadGap = Duration(minutes: 2);

/// Least time between two uploads the person asks for («Actualizar ahora»,
/// a switch). The worker refuses closer ones (`MIN_PUT_INTERVAL_SECONDS`).
const Duration shareManualUploadGap = Duration(seconds: 30);

/// An unchanged feed is uploaded again after this long, so the worker keeps
/// it (it forgets feeds not updated in `FEED_TTL_DAYS`) and the window of
/// fourteen months moves on.
const Duration shareRefreshAfter = Duration(days: 7);

/// The worker of this build, or `null` when the build has no
/// `SHARE_LINK_BASE_URL` (the feature then says it is not available).
final shareLinkApiProvider = Provider<ShareLinkApi?>((ref) {
  final base = ref.watch(appConfigProvider).shareLinkBase;
  return base == null ? null : HttpShareLinkApi(base);
});

final shareLinkRepositoryProvider = Provider<ShareLinkRepository>(
  (ref) => ShareLinkRepository(ref.watch(appDatabaseProvider)),
);

/// What is going on right now.
enum ShareLinkBusy { none, publishing, revoking }

class ShareLinkState {
  const ShareLinkState({
    required this.available,
    this.loading = true,
    this.settings = const ShareLinkSettings(),
    this.calendars = const [],
    this.busy = ShareLinkBusy.none,
    this.problem,
    this.url,
    this.waiting = false,
  });

  /// The build has a worker (`SHARE_LINK_BASE_URL`).
  final bool available;
  final bool loading;
  final ShareLinkSettings settings;

  /// The calendars that can be shared (not archived).
  final List<Calendar> calendars;
  final ShareLinkBusy busy;

  /// What went wrong the last time, until the next success.
  final ShareLinkFailure? problem;

  /// The `https` address of the feed, once there is a token.
  final Uri? url;

  /// A change is waiting for the least time between uploads to pass.
  final bool waiting;

  bool get isPublished => settings.isPublished;

  /// The calendar the link shares, when it still exists.
  Calendar? get sharedCalendar =>
      calendars.where((c) => c.id == settings.calendarId).firstOrNull;

  /// There is a link but its calendar was archived or is gone (a restored
  /// backup): nothing is uploaded until another one is chosen.
  bool get calendarMissing =>
      settings.hasToken && !loading && sharedCalendar == null;

  ShareLinkState copyWith({
    bool? loading,
    ShareLinkSettings? settings,
    List<Calendar>? calendars,
    ShareLinkBusy? busy,
    ShareLinkFailure? problem,
    bool clearProblem = false,
    Uri? url,
    bool clearUrl = false,
    bool? waiting,
  }) => ShareLinkState(
    available: available,
    loading: loading ?? this.loading,
    settings: settings ?? this.settings,
    calendars: calendars ?? this.calendars,
    busy: busy ?? this.busy,
    problem: clearProblem ? null : problem ?? this.problem,
    url: clearUrl ? null : url ?? this.url,
    waiting: waiting ?? this.waiting,
  );
}

/// Publishes, refreshes and revokes the shared link (docs/compartir.md).
///
/// Nothing leaves the phone until the person taps «Publicar»; with no
/// worker configured nothing is ever sent.
class ShareLinkController extends Notifier<ShareLinkState> {
  Timer? _timer;
  DateTime? _lastAttempt;
  Future<void>? _loading;

  /// «Ausencia» in the app's language; `ShareLinkHost` sets it.
  String absenceLabel = 'Ausencia';

  ShareLinkApi? get _api => ref.read(shareLinkApiProvider);
  ShareLinkRepository get _repo => ref.read(shareLinkRepositoryProvider);
  DateTime _now() => ref.read(clockProvider)();

  @override
  ShareLinkState build() {
    ref.onDispose(() => _timer?.cancel());
    _loading = null;
    final available = ref.watch(shareLinkApiProvider) != null;
    // A build with no worker never reads or sends anything.
    if (!available) {
      return const ShareLinkState(available: false, loading: false);
    }
    Future.microtask(load);
    return ShareLinkState(available: available);
  }

  /// Reads the stored link and the calendars (once; later calls wait for the
  /// same read unless [force]).
  Future<void> load({bool force = false}) {
    if (!state.available) return Future.value();
    if (force || _loading == null) _loading = _load();
    return _loading!;
  }

  Future<void> _load() async {
    try {
      final settings = await _repo.load();
      final calendars = await ref.read(calendarsRepositoryProvider).list();
      if (!ref.mounted) return;
      final api = _api;
      state = state.copyWith(
        loading: false,
        settings: settings,
        calendars: calendars,
        url: settings.token == null || api == null
            ? null
            : api.feedUrl(settings.token!),
        clearUrl: settings.token == null || api == null,
      );
    } catch (error, stack) {
      _report(error, stack);
      if (ref.mounted) state = state.copyWith(loading: false);
    }
  }

  /// Creates the link (or reuses the one there is) for [calendarId] and
  /// uploads the feed now. The token is saved **before** the upload, so a
  /// feed that reached the worker can always be revoked.
  Future<void> publish(String calendarId) async {
    final api = _api;
    if (api == null || state.busy != ShareLinkBusy.none) return;
    await load();
    var settings = state.settings;
    try {
      if (settings.token == null) {
        final token = ShareToken.generate();
        await _repo.saveNewLink(token, calendarId);
        settings = ShareLinkSettings(
          token: token,
          calendarId: calendarId,
          options: settings.options,
        );
      } else if (settings.calendarId != calendarId) {
        await _repo.saveCalendar(calendarId);
        settings = settings.copyWith(calendarId: calendarId);
      }
    } catch (error, stack) {
      _report(error, stack);
      if (ref.mounted) {
        state = state.copyWith(problem: ShareLinkFailure.server);
      }
      return;
    }
    if (!ref.mounted) return;
    state = state.copyWith(
      settings: settings,
      url: api.feedUrl(settings.token!),
    );
    await _upload();
  }

  /// «Actualizar ahora»: uploads even when nothing changed (not closer than
  /// [shareManualUploadGap] to the last upload).
  Future<void> refreshNow() => _request(manual: true, force: true);

  /// Shares another calendar through the same link.
  Future<void> setCalendar(String calendarId) async {
    if (!state.settings.hasToken || state.settings.calendarId == calendarId) {
      return;
    }
    try {
      await _repo.saveCalendar(calendarId);
    } catch (error, stack) {
      _report(error, stack);
      return;
    }
    if (!ref.mounted) return;
    state = state.copyWith(
      settings: state.settings.copyWith(calendarId: calendarId),
    );
    await _request(manual: true, force: true);
  }

  /// The two switches. Saved at once; a published link is updated.
  Future<void> setOptions(ShareFeedOptions options) async {
    if (options == state.settings.options) return;
    try {
      await _repo.saveOptions(options);
    } catch (error, stack) {
      _report(error, stack);
      return;
    }
    if (!ref.mounted) return;
    state = state.copyWith(settings: state.settings.copyWith(options: options));
    if (state.settings.hasToken) await _request(manual: true);
  }

  /// Called when the schedule changes and when the app starts or comes
  /// back: uploads when the feed is different from the last upload (or old),
  /// never closer than [shareAutoUploadGap].
  Future<void> autoSync() => _request(manual: false);

  /// Deletes the feed on the worker and, only then, forgets the token.
  ///
  /// The revocation is recorded first (`revokePending`): from that moment
  /// nothing is uploaded under this token, even after a restart. If the
  /// worker cannot be reached or says «too many» (429), the link stays
  /// pending and the screen says so; it is retried after the `Retry-After`,
  /// at start and on resume ([autoSync]). Forgetting the token before the
  /// worker confirms would leave a feed nobody can delete.
  Future<void> revoke() async {
    final api = _api;
    final token = state.settings.token;
    if (api == null || token == null || state.busy != ShareLinkBusy.none) {
      return;
    }
    _timer?.cancel();
    state = state.copyWith(
      busy: ShareLinkBusy.revoking,
      clearProblem: true,
      waiting: false,
      settings: state.settings.copyWith(revokePending: true),
    );
    try {
      await _repo.saveRevokePending();
      await api.revoke(token);
      await _repo.forgetLink();
      if (!ref.mounted) return;
      state = state.copyWith(
        busy: ShareLinkBusy.none,
        settings: ShareLinkSettings(options: state.settings.options),
        clearUrl: true,
      );
    } on ShareLinkException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(busy: ShareLinkBusy.none, problem: e.failure);
      if (e.failure == ShareLinkFailure.rateLimited) {
        _timer?.cancel();
        _timer = Timer(
          e.retryAfter ?? const Duration(seconds: 60),
          () => unawaited(revoke()),
        );
      }
    } catch (error, stack) {
      _report(error, stack);
      if (ref.mounted) {
        state = state.copyWith(
          busy: ShareLinkBusy.none,
          problem: ShareLinkFailure.server,
        );
      }
    }
  }

  Future<void> _request({required bool manual, bool force = false}) async {
    if (_api == null) return;
    await load();
    if (!ref.mounted) return;
    final settings = state.settings;
    if (!settings.hasToken || state.busy != ShareLinkBusy.none) return;
    // A revocation waiting for the worker: try it again, never upload.
    if (settings.revokePending) {
      if (!manual) await revoke();
      return;
    }
    if (state.calendarMissing) return;

    final now = _now();
    if (!force) {
      final built = await _buildFeed(fingerprintOnly: true);
      if (built == null || !ref.mounted) return;
      final stale =
          settings.publishedAt == null ||
          now.toUtc().difference(settings.publishedAt!) >= shareRefreshAfter;
      if (!stale && built.fingerprint == settings.fingerprint) return;
    }

    final gap = manual ? shareManualUploadGap : shareAutoUploadGap;
    final last = [settings.publishedAt, _lastAttempt]
        .whereType<DateTime>()
        .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
    final wait = last == null
        ? Duration.zero
        : gap - now.toUtc().difference(last);
    if (wait > Duration.zero) {
      _timer?.cancel();
      _timer = Timer(
        wait,
        () => unawaited(_request(manual: manual, force: force)),
      );
      state = state.copyWith(waiting: true);
      return;
    }
    await _upload();
  }

  Future<({String feed, String fingerprint})?> _buildFeed({
    bool fingerprintOnly = false,
  }) async {
    final settings = state.settings;
    final calendar = state.sharedCalendar;
    if (calendar == null) return null;
    final schedule = await _scheduleOf(calendar.id);
    final location = await ref.read(icsTimeZoneProvider)();
    final now = _now();
    String build(DateTime stamp) => buildShareFeed(
      schedule: schedule,
      calendarId: calendar.id,
      calendarName: calendar.name,
      today: CivilDate.fromDateTime(now),
      location: location,
      options: settings.options,
      absenceLabel: absenceLabel,
      stamp: stamp,
    );
    final fingerprint = shareFeedFingerprint(build(shareFingerprintStamp));
    return (feed: fingerprintOnly ? '' : build(now), fingerprint: fingerprint);
  }

  /// The schedule of [calendarId]: the one in memory when it is on screen
  /// (the freshest), else the stored one once the queued writes are done.
  Future<Schedule> _scheduleOf(String calendarId) async {
    final current = ref.read(scheduleControllerProvider);
    if (current.calendarId == calendarId) return current.schedule;
    await ref.read(scheduleControllerProvider.notifier).pendingWrites;
    final stored = await ref.read(scheduleRepositoryProvider).load(calendarId);
    return stored.schedule;
  }

  Future<void> _upload() async {
    final api = _api;
    final token = state.settings.token;
    if (api == null ||
        token == null ||
        state.settings.revokePending ||
        state.busy != ShareLinkBusy.none) {
      return;
    }
    _timer?.cancel();
    state = state.copyWith(
      busy: ShareLinkBusy.publishing,
      clearProblem: true,
      waiting: false,
    );
    try {
      final built = await _buildFeed();
      if (built == null) {
        if (ref.mounted) state = state.copyWith(busy: ShareLinkBusy.none);
        return;
      }
      if (utf8.encode(built.feed).length > maxShareFeedBytes) {
        throw const ShareLinkException(ShareLinkFailure.tooLarge);
      }
      _lastAttempt = _now().toUtc();
      await api.publish(token, built.feed);
      final at = _now().toUtc();
      // A revoke or a new link while uploading: do not resurrect the old one.
      if (!ref.mounted || state.settings.token != token) return;
      await _repo.savePublished(at, built.fingerprint);
      if (!ref.mounted) return;
      state = state.copyWith(
        busy: ShareLinkBusy.none,
        settings: state.settings.copyWith(
          publishedAt: at,
          fingerprint: built.fingerprint,
        ),
      );
    } on ShareLinkException catch (e) {
      if (!ref.mounted) return;
      if (e.failure == ShareLinkFailure.revoked) {
        await _forgetRevoked(token);
        return;
      }
      state = state.copyWith(busy: ShareLinkBusy.none, problem: e.failure);
      if (e.failure == ShareLinkFailure.rateLimited) {
        final wait = e.retryAfter ?? shareManualUploadGap;
        _timer?.cancel();
        _timer = Timer(wait, () => unawaited(_request(manual: true)));
        state = state.copyWith(waiting: true);
      }
    } catch (error, stack) {
      _report(error, stack);
      if (ref.mounted) {
        state = state.copyWith(
          busy: ShareLinkBusy.none,
          problem: ShareLinkFailure.server,
        );
      }
    }
  }

  /// The worker says [token]'s link was revoked (a restored system backup
  /// brought back an old token, or another copy of the app revoked it):
  /// forget it, stop uploading and say so. A new link needs a new «Publicar».
  Future<void> _forgetRevoked(ShareToken token) async {
    _timer?.cancel();
    try {
      if (state.settings.token == token) await _repo.forgetLink();
    } catch (error, stack) {
      _report(error, stack);
    }
    if (!ref.mounted) return;
    state = state.copyWith(
      busy: ShareLinkBusy.none,
      settings: ShareLinkSettings(options: state.settings.options),
      problem: ShareLinkFailure.revoked,
      clearUrl: true,
      waiting: false,
    );
  }

  void _report(Object error, StackTrace stack) {
    try {
      unawaited(
        ref
            .read(crashReporterProvider)
            .record(redactError(error), stack, fatal: false)
            .catchError((Object _) {}),
      );
    } catch (_) {
      // A reporter that throws must not break the screen.
    }
  }
}

final shareLinkControllerProvider =
    NotifierProvider<ShareLinkController, ShareLinkState>(
      ShareLinkController.new,
    );
