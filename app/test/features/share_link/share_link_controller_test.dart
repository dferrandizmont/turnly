import 'package:cuadrante/core/providers.dart';
import 'package:cuadrante/features/calendar/application/schedule_controller.dart';
import 'package:cuadrante/features/share_link/application/share_link_controller.dart';
import 'package:cuadrante/features/share_link/data/share_link_api.dart';
import 'package:cuadrante/features/share_link/data/share_link_repository.dart';
import 'package:cuadrante/features/share_link/domain/share_feed.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart' show harnessNow, harnessToday;
import '../../support/test_storage.dart';
import 'share_link_support.dart';

DateTime _now = harnessNow;

/// The controller on its own (no widgets): a container over an in-memory
/// database seeded like the app, with a clock the test moves.
class _Rig {
  _Rig._(this.storage, this.container);

  final TestStorage storage;
  final ProviderContainer container;

  static Future<_Rig> open({FakeShareApi? api, bool absence = false}) async {
    _now = harnessNow;
    var storage = await TestStorage.open(now: harnessNow);
    if (absence) {
      await addAbsence(storage.database);
      storage = await storage.withReloadedSnapshot();
    }
    final container = ProviderContainer(
      overrides: [
        ...storage.overrides,
        clockProvider.overrideWithValue(() => _now),
        ...shareOverrides(api),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await storage.close();
    });
    return _Rig._(storage, container);
  }

  ShareLinkController get controller =>
      container.read(shareLinkControllerProvider.notifier);

  ShareLinkState get state => container.read(shareLinkControllerProvider);

  Future<ShareLinkSettings> stored() =>
      ShareLinkRepository(storage.database).load();
}

void main() {
  test('without a worker nothing is read or sent', () async {
    final rig = await _Rig.open();
    expect(rig.state.available, isFalse);
    expect(rig.state.loading, isFalse);
    await rig.controller.publish('main');
    await rig.controller.autoSync();
    expect((await rig.stored()).hasToken, isFalse);
  });

  test('publish saves the token first, then uploads the feed', () async {
    final api = FakeShareApi();
    final rig = await _Rig.open(api: api, absence: true);
    var tokenBeforeUpload = false;
    api.onPublish = () async {
      final stored = await rig.stored();
      tokenBeforeUpload = stored.hasToken && stored.publishedAt == null;
    };
    await rig.controller.publish('main');

    expect(tokenBeforeUpload, isTrue);
    final upload = api.published.single;
    expect(upload.ics, startsWith('BEGIN:VCALENDAR\r\n'));
    expect(upload.ics, contains('X-WR-CALNAME:Mi cuadrante'));
    expect(upload.ics, contains('BEGIN:VEVENT'));
    // The vacation and its note never leave.
    expect(upload.ics, isNot(contains('Vacaciones')));
    expect(upload.ics, isNot(contains('Ausencia')));
    expect(upload.ics, isNot(contains('Cita')));

    final stored = await rig.stored();
    expect(stored.token, upload.token);
    expect(stored.calendarId, 'main');
    expect(stored.publishedAt, harnessNow.toUtc());
    expect(stored.fingerprint, isNotNull);
    expect(rig.state.isPublished, isTrue);
    expect(rig.state.url.toString(), contains(upload.token.feedId));
    expect(rig.state.problem, isNull);
  });

  test('absences go out only as an anonymous «Ausencia»', () async {
    final api = FakeShareApi();
    final rig = await _Rig.open(api: api, absence: true);
    await rig.controller.publish('main');
    _now = harnessNow.add(const Duration(minutes: 1));
    await rig.controller.setOptions(
      const ShareFeedOptions(includeAbsences: true),
    );
    expect(api.published, hasLength(2));
    final ics = api.published.last.ics;
    expect(ics, contains('SUMMARY:Ausencia'));
    expect(ics, isNot(contains('Vacaciones')));
    expect(ics, isNot(contains('Cita')));
    expect((await rig.stored()).options.includeAbsences, isTrue);
  });

  test('an unchanged feed is not uploaded again, an old one is', () async {
    final api = FakeShareApi();
    final rig = await _Rig.open(api: api);
    await rig.controller.publish('main');
    _now = harnessNow.add(const Duration(hours: 1));
    await rig.controller.autoSync();
    expect(api.published, hasLength(1));

    // A note changes the schedule but not the feed.
    final schedule = rig.container.read(scheduleControllerProvider.notifier);
    schedule.setNote(harnessToday, 'Nota privada');
    await schedule.pendingWrites;
    await rig.controller.autoSync();
    expect(api.published, hasLength(1));

    _now = _now.add(shareRefreshAfter);
    await rig.controller.autoSync();
    expect(api.published, hasLength(2));
    expect(api.published.last.ics, isNot(contains('Nota privada')));
  });

  test('a changed schedule waits for the least gap', () async {
    final api = FakeShareApi();
    final rig = await _Rig.open(api: api);
    await rig.controller.publish('main');
    final schedule = rig.container.read(scheduleControllerProvider.notifier);
    final morning = rig.container
        .read(scheduleControllerProvider)
        .palette
        .firstWhere((t) => t.id == 'morning');
    schedule.saveShiftType(morning.copyWith(name: 'Mañanas'));
    await schedule.pendingWrites;

    _now = harnessNow.add(const Duration(seconds: 30));
    await rig.controller.autoSync();
    expect(api.published, hasLength(1), reason: 'closer than two minutes');
    expect(rig.state.waiting, isTrue);

    _now = _now.add(shareAutoUploadGap);
    await rig.controller.autoSync();
    expect(api.published, hasLength(2));
    expect(api.published.last.ics, contains('Mañanas'));
    expect(rig.state.waiting, isFalse);
  });

  test('a failed upload is reported and kept for later', () async {
    final api = FakeShareApi()..failure = ShareLinkFailure.network;
    final rig = await _Rig.open(api: api);
    await rig.controller.publish('main');
    expect(rig.state.problem, ShareLinkFailure.network);
    expect(rig.state.isPublished, isFalse);
    expect((await rig.stored()).hasToken, isTrue);

    api.failure = null;
    _now = harnessNow.add(shareAutoUploadGap);
    await rig.controller.autoSync();
    expect(api.published, hasLength(1));
    expect(rig.state.isPublished, isTrue);
    expect(rig.state.problem, isNull);
  });

  test('a rate limit waits and says so', () async {
    final api = FakeShareApi()
      ..failure = ShareLinkFailure.rateLimited
      ..retryAfter = const Duration(minutes: 5);
    final rig = await _Rig.open(api: api);
    await rig.controller.publish('main');
    expect(rig.state.problem, ShareLinkFailure.rateLimited);
    expect(rig.state.waiting, isTrue);
  });

  test('revoke forgets the token only once the worker deleted it', () async {
    final api = FakeShareApi();
    final rig = await _Rig.open(api: api);
    await rig.controller.publish('main');
    await rig.controller.setOptions(const ShareFeedOptions(includeRest: true));
    final token = (await rig.stored()).token;

    api.failure = ShareLinkFailure.network;
    await rig.controller.revoke();
    expect(rig.state.problem, ShareLinkFailure.network);
    expect((await rig.stored()).token, token);

    api.failure = null;
    await rig.controller.revoke();
    expect(api.revoked, [token]);
    final stored = await rig.stored();
    expect(stored.hasToken, isFalse);
    expect(stored.publishedAt, isNull);
    expect(stored.options.includeRest, isTrue, reason: 'choices are kept');
    expect(rig.state.url, isNull);
    expect(rig.state.waiting, isFalse);

    // A new link is a new token.
    await rig.controller.publish('main');
    expect((await rig.stored()).token, isNot(token));
  });

  test(
    'a revocation the worker refuses stays pending and blocks uploads',
    () async {
      final api = FakeShareApi();
      final rig = await _Rig.open(api: api);
      await rig.controller.publish('main');
      final token = (await rig.stored()).token;

      api.failure = ShareLinkFailure.rateLimited;
      api.retryAfter = const Duration(minutes: 5);
      await rig.controller.revoke();
      expect(rig.state.problem, ShareLinkFailure.rateLimited);
      var stored = await rig.stored();
      expect(
        stored.token,
        token,
        reason: 'not forgotten before the worker says so',
      );
      expect(stored.revokePending, isTrue, reason: 'survives a restart');
      expect(rig.state.settings.revokePending, isTrue);

      // Nothing is uploaded under that id while the revocation is pending.
      _now = harnessNow.add(shareRefreshAfter);
      await rig.controller.refreshNow();
      await rig.controller.setOptions(
        const ShareFeedOptions(includeRest: true),
      );
      await rig.controller.publish('main');
      await rig.controller.autoSync();
      expect(api.published, hasLength(1));
      expect(api.revoked, isEmpty);

      // The next automatic check retries the revocation, and it goes through.
      api.failure = null;
      await rig.controller.autoSync();
      expect(api.revoked, [token]);
      expect(api.published, hasLength(1));
      stored = await rig.stored();
      expect(stored.hasToken, isFalse);
      expect(stored.revokePending, isFalse);
      expect(rig.state.settings.revokePending, isFalse);
    },
  );

  test(
    'a link revoked elsewhere is forgotten and never uploaded again',
    () async {
      final api = FakeShareApi();
      final rig = await _Rig.open(api: api);
      await rig.controller.publish('main');
      final old = (await rig.stored()).token;

      // The worker has a tombstone for it (revoked from a restored copy, or a
      // late request after a revoke).
      api.failure = ShareLinkFailure.revoked;
      _now = harnessNow.add(shareRefreshAfter);
      await rig.controller.autoSync();
      expect(rig.state.problem, ShareLinkFailure.revoked);
      expect(rig.state.settings.hasToken, isFalse);
      expect(rig.state.url, isNull);
      expect(rig.state.waiting, isFalse);
      final stored = await rig.stored();
      expect(stored.hasToken, isFalse);
      expect(stored.publishedAt, isNull);

      // Nothing more is sent until the person publishes again: a new token.
      api.failure = null;
      _now = _now.add(shareRefreshAfter);
      await rig.controller.autoSync();
      expect(api.published, hasLength(1));
      await rig.controller.publish('main');
      expect(api.published, hasLength(2));
      expect(api.published.last.token, isNot(old));
    },
  );

  test('a link whose calendar is gone uploads nothing', () async {
    final api = FakeShareApi();
    final rig = await _Rig.open(api: api);
    await rig.controller.publish('ghost');
    expect(api.published, isEmpty);
    expect(rig.state.calendarMissing, isTrue);
    await rig.controller.autoSync();
    expect(api.published, isEmpty);
    await rig.controller.setCalendar('main');
    expect(api.published, hasLength(1));
    expect(rig.state.calendarMissing, isFalse);
  });

  test('a size refused by the worker is reported', () async {
    final api = FakeShareApi()..failure = ShareLinkFailure.tooLarge;
    final rig = await _Rig.open(api: api);
    await rig.controller.publish('main');
    expect(rig.state.problem, ShareLinkFailure.tooLarge);
  });
}
