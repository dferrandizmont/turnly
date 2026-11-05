import 'dart:async';

import '../../alarms/data/alarm_scheduler.dart' show AsyncMutex;
import '../../schedule/domain/schedule_domain.dart';
import '../data/calendar_exporter.dart';
import '../domain/calendar_sync_settings.dart';
import '../domain/device_calendar_api.dart';

/// What one pass of the continuous export did.
enum CalendarSyncOutcome {
  /// «Mantener al día» is off (nothing was read or written).
  off,

  /// The phone calendar now matches the schedule in the window.
  synced,

  /// It turned itself off (see [CalendarSyncSettings.notice]).
  stopped,

  /// The pass failed (the calendar did not answer); the next one retries.
  failed,
}

/// Keeps the events Turnly exported to a calendar of the phone in step with
/// the schedule («Mantener al día», C8).
///
/// - A pass ([sync]) exports the window `today - calendarSyncPastDays` to
///   `today + calendarSyncFutureDays` through [CalendarExporter]: new shifts
///   are created, changed ones replaced, ones that no longer exist deleted,
///   and nothing is touched that does not carry Turnly's tag for the
///   calendar. Two passes in a row leave the same events (no duplicates).
/// - [requestSync] waits [debounce] of quiet first (the calendar emits a
///   change for every day painted); runs are serialised and coalesced like
///   the alarms' (`AlarmSync`): while one is in flight, more requests only
///   mark it dirty and it runs once more.
/// - It shares [lock] with the manual export so the two never write at once.
/// - It never asks for the permission. If the permission is gone, or the
///   phone calendar or the Turnly calendar no longer exists, it turns itself
///   off, leaves a [CalendarSyncSettings.notice] and tells [notices].
class CalendarSync {
  CalendarSync({
    required this.api,
    required this.load,
    required this.save,
    required this.readSchedule,
    required this.now,
    required this.lock,
    this.debounce = const Duration(seconds: 3),
    this.onError,
    this.onChanged,
  });

  final DeviceCalendarApi api;
  final Future<CalendarSyncSettings> Function() load;
  final Future<void> Function(CalendarSyncSettings settings) save;

  /// The schedule of the Turnly calendar [id], or `null` when it is gone.
  final Future<Schedule?> Function(String id) readSchedule;
  final DateTime Function() now;

  /// Taken around every write to the phone's calendar.
  final AsyncMutex lock;
  final Duration debounce;

  /// Errors of a pass (it never stops later ones).
  final void Function(Object error, StackTrace stack)? onError;

  /// The stored settings changed (a pass finished, or it turned itself off):
  /// whoever shows them reloads.
  final void Function()? onChanged;

  /// Emits each time a pass turns «Mantener al día» off by itself.
  Stream<CalendarSyncNotice> get notices => _notices.stream;
  final StreamController<CalendarSyncNotice> _notices =
      StreamController.broadcast();

  Timer? _timer;
  Future<CalendarSyncOutcome>? _loop;
  bool _dirty = false;
  bool _disposed = false;
  bool _paused = false;

  /// Stops triggers and drains an in-flight pass before destructive cleanup.
  Future<void> pause() async {
    _paused = true;
    _timer?.cancel();
    _timer = null;
    await _loop;
  }

  void resume() => _paused = false;
  CalendarSyncOutcome _last = CalendarSyncOutcome.off;

  /// Passes that got as far as reading the settings (tests, diagnostics).
  int runs = 0;

  /// Debounced: a pass runs [debounce] after the last call.
  void requestSync() {
    if (_disposed || _paused) return;
    _timer?.cancel();
    _timer = Timer(debounce, () {
      _timer = null;
      unawaited(sync());
    });
  }

  /// Runs a pass now (waiting for one in flight, and once more if asked
  /// meanwhile). Completes with how the last one ended.
  Future<CalendarSyncOutcome> sync() {
    if (_disposed || _paused) return Future.value(CalendarSyncOutcome.off);
    _timer?.cancel();
    _timer = null;
    _dirty = true;
    return _loop ??= _run();
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    unawaited(_notices.close());
  }

  Future<CalendarSyncOutcome> _run() async {
    await null; // never complete synchronously (see `_loop = null` below)
    try {
      while (_dirty && !_disposed && !_paused) {
        _dirty = false;
        try {
          _last = await lock.run(_once);
        } catch (error, stack) {
          _last = CalendarSyncOutcome.failed;
          if (!_disposed) onError?.call(error, stack);
        }
      }
      return _last;
    } finally {
      _loop = null;
    }
  }

  Future<CalendarSyncOutcome> _once() async {
    // Read inside the lock: a manual export or a switch may have changed it.
    final settings = await load();
    if (!settings.active) return CalendarSyncOutcome.off;
    runs++;
    final exporter = CalendarExporter(api);
    try {
      if (await api.access() != CalendarAccess.granted) {
        return await _stop(settings, CalendarSyncNotice.permission);
      }
      final writable = await exporter.writableCalendars();
      final target = writable
          .where((c) => c.id == settings.deviceCalendarId)
          .firstOrNull;
      if (target == null || !_sameName(target, settings)) {
        return await _stop(settings, CalendarSyncNotice.calendarGone);
      }
      final schedule = await readSchedule(settings.appCalendarId!);
      if (schedule == null) {
        return await _stop(settings, CalendarSyncNotice.sourceGone);
      }
      final today = CivilDate.fromDateTime(now());
      final result = await exporter.export(
        schedule: schedule,
        appCalendarId: settings.appCalendarId!,
        target: ExistingCalendar(target.id),
        from: today.addDays(-calendarSyncPastDays),
        to: today.addDays(calendarSyncFutureDays),
        includeRest: settings.includeRest,
        includeAbsences: settings.includeAbsences,
      );
      await save(
        settings.copyWith(lastSyncAt: now(), lastFailed: result.failed),
      );
      _changed();
      return CalendarSyncOutcome.synced;
    } on CalendarApiException catch (e) {
      if (e.error == CalendarApiError.permissionDenied) {
        return await _stop(settings, CalendarSyncNotice.permission);
      }
      rethrow;
    }
  }

  static bool _sameName(DeviceCalendarInfo c, CalendarSyncSettings s) {
    final stored = s.deviceCalendarName?.trim().toLowerCase();
    return stored == null || stored == c.name.trim().toLowerCase();
  }

  Future<CalendarSyncOutcome> _stop(
    CalendarSyncSettings settings,
    CalendarSyncNotice notice,
  ) async {
    await save(settings.copyWith(enabled: false, notice: notice));
    _changed();
    if (!_disposed) _notices.add(notice);
    return CalendarSyncOutcome.stopped;
  }

  void _changed() {
    if (!_disposed) onChanged?.call();
  }
}
