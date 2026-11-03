import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/diagnostics/crash_reporting.dart';
import '../../../core/diagnostics/debug_log.dart';
import '../../../core/providers.dart';
import '../../alarms/data/alarm_scheduler.dart' show AsyncMutex;
import '../../calendar/application/schedule_controller.dart';
import '../../calendars/application/calendars_providers.dart';
import '../../schedule/application/schedule_providers.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../data/calendar_sync_repository.dart';
import '../domain/calendar_sync_settings.dart';
import 'calendar_sync.dart';
import 'device_calendar_providers.dart';

final calendarSyncRepositoryProvider = Provider<CalendarSyncRepository>(
  (ref) => CalendarSyncRepository(ref.watch(appDatabaseProvider)),
);

/// One writer at a time to the phone's calendar: the manual export and the
/// continuous one both take it, so they never interleave (that is how a
/// duplicate would be written).
final calendarWriteLockProvider = Provider<AsyncMutex>((ref) => AsyncMutex());

/// The schedule of the Turnly calendar [id] for the continuous export: the
/// one being edited when it is that calendar (the freshest), else the stored
/// one after the queued writes finish. `null` when the calendar is gone.
Future<Schedule?> readScheduleOf(Ref ref, String id) async {
  final current = ref.read(scheduleControllerProvider);
  if (current.calendarId == id) return current.schedule;
  await ref.read(scheduleControllerProvider.notifier).pendingWrites;
  if (await ref.read(calendarsRepositoryProvider).get(id) == null) return null;
  return (await ref.read(scheduleRepositoryProvider).load(id)).schedule;
}

/// The continuous export («Mantener al día»). The host asks it for passes;
/// tests override [deviceCalendarApiProvider] and [clockProvider].
final calendarSyncProvider = Provider<CalendarSync>((ref) {
  final repository = ref.watch(calendarSyncRepositoryProvider);
  final sync = CalendarSync(
    api: ref.watch(deviceCalendarApiProvider),
    load: repository.load,
    save: repository.save,
    readSchedule: (id) => readScheduleOf(ref, id),
    now: ref.watch(clockProvider),
    lock: ref.watch(calendarWriteLockProvider),
    onChanged: () => ref.invalidate(calendarSyncSettingsProvider),
    onError: (error, stack) {
      debugLogFailure('Calendario del móvil: mantener al día', error);
      try {
        unawaited(
          ref
              .read(crashReporterProvider)
              .record(redactError(error), stack, fatal: false)
              .catchError((Object _) {}),
        );
      } catch (_) {
        // A reporter that throws must not break the sync.
      }
    },
  );
  ref.onDispose(sync.dispose);
  return sync;
});

/// The stored «Mantener al día» choices. The controller edits them; a pass of
/// [calendarSyncProvider] reloads them (it records when it ran and turns
/// itself off by itself).
class CalendarSyncSettingsController
    extends AsyncNotifier<CalendarSyncSettings> {
  // Edits are read-modify-write: one at a time.
  final AsyncMutex _edits = AsyncMutex();

  CalendarSyncRepository get _repository =>
      ref.read(calendarSyncRepositoryProvider);

  @override
  Future<CalendarSyncSettings> build() =>
      ref.watch(calendarSyncRepositoryProvider).load();

  Future<void> _edit(
    CalendarSyncSettings Function(CalendarSyncSettings current) change,
  ) => _edits.run(() async {
    final next = change(await _repository.load());
    await _repository.save(next);
    if (ref.mounted) state = AsyncData(next);
  });

  /// Turns «Mantener al día» on for [appCalendarId] -> [deviceCalendarId].
  Future<void> enable({
    required String deviceCalendarId,
    required String deviceCalendarName,
    required String appCalendarId,
    required bool includeRest,
    required bool includeAbsences,
  }) => _edit(
    (_) => CalendarSyncSettings(
      enabled: true,
      deviceCalendarId: deviceCalendarId,
      deviceCalendarName: deviceCalendarName,
      appCalendarId: appCalendarId,
      includeRest: includeRest,
      includeAbsences: includeAbsences,
    ),
  );

  /// Turns it off. The events already written stay in the calendar.
  Future<void> disable() =>
      _edit((s) => s.copyWith(enabled: false, clearNotice: true));

  /// The options chosen on the export screen changed while it is on.
  Future<void> setOptions({bool? includeRest, bool? includeAbsences}) => _edit(
    (s) =>
        s.copyWith(includeRest: includeRest, includeAbsences: includeAbsences),
  );

  /// The user has seen why it turned itself off.
  Future<void> dismissNotice() => _edit((s) => s.copyWith(clearNotice: true));
}

final calendarSyncSettingsProvider =
    AsyncNotifierProvider<CalendarSyncSettingsController, CalendarSyncSettings>(
      CalendarSyncSettingsController.new,
    );
