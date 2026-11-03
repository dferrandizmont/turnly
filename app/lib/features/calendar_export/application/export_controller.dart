import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/diagnostics/crash_reporting.dart';
import '../../../core/providers.dart';
import '../../calendar/application/schedule_controller.dart';
import '../../calendars/domain/calendar.dart';
import '../../import/domain/import_models.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../data/calendar_exporter.dart';
import '../domain/calendar_sync_settings.dart';
import '../domain/device_calendar_api.dart';
import '../domain/export_events.dart';
import 'calendar_sync_providers.dart';
import 'device_calendar_providers.dart';

/// Why an export could not run or finish.
enum ExportProblem {
  permissionDenied,
  permissionRestricted,
  calendarUnavailable,
  failed,
}

/// What the export screen shows.
class ExportState {
  const ExportState({
    required this.from,
    required this.to,
    this.access,
    this.declined = false,
    this.loading = true,
    this.calendars = const [],
    this.targetId,
    this.includeRest = false,
    this.includeAbsences = false,
    this.rangeCut = false,
    this.plan,
    this.running = false,
    this.syncing = false,
    this.done = 0,
    this.total = 0,
    this.result,
    this.problem,
  });

  final CalendarAccess? access;

  /// The user refused the system question (it may be asked again).
  final bool declined;

  /// Reading the permission and the calendars.
  final bool loading;

  /// The calendars the export may write to.
  final List<DeviceCalendarInfo> calendars;

  /// The phone calendar chosen; `null` = create «Turnly».
  final String? targetId;
  final CivilDate from;
  final CivilDate to;

  /// Also export the days off (Libre, Saliente).
  final bool includeRest;

  /// Also export absences (vacations, sick leave...). Off by default: the
  /// calendar chosen may be synced to an account.
  final bool includeAbsences;

  /// The last range asked for was longer than a year and its end was cut.
  /// A range of exactly a year is not cut.
  final bool rangeCut;

  /// What exporting now would do (counts shown before the button).
  final ExportPlan? plan;
  final bool running;

  /// Turning «Mantener al día» on: the first pass is running.
  final bool syncing;
  final int done;
  final int total;
  final ExportResult? result;
  final ExportProblem? problem;

  bool get hasAccess => access == CalendarAccess.granted;

  /// The phone calendar chosen; `null` when a new one will be created.
  DeviceCalendarInfo? get target =>
      calendars.where((c) => c.id == targetId).firstOrNull;

  ExportState copyWith({
    CalendarAccess? access,
    bool? declined,
    bool? loading,
    List<DeviceCalendarInfo>? calendars,
    String? targetId,
    bool newCalendar = false,
    CivilDate? from,
    CivilDate? to,
    bool? includeRest,
    bool? includeAbsences,
    bool? rangeCut,
    ExportPlan? plan,
    bool clearPlan = false,
    bool? running,
    bool? syncing,
    int? done,
    int? total,
    ExportResult? result,
    bool clearResult = false,
    ExportProblem? problem,
    bool clearProblem = false,
  }) => ExportState(
    access: access ?? this.access,
    declined: declined ?? this.declined,
    loading: loading ?? this.loading,
    calendars: calendars ?? this.calendars,
    targetId: newCalendar ? null : targetId ?? this.targetId,
    from: from ?? this.from,
    to: to ?? this.to,
    includeRest: includeRest ?? this.includeRest,
    includeAbsences: includeAbsences ?? this.includeAbsences,
    rangeCut: rangeCut ?? this.rangeCut,
    plan: clearPlan ? null : plan ?? this.plan,
    running: running ?? this.running,
    syncing: syncing ?? this.syncing,
    done: done ?? this.done,
    total: total ?? this.total,
    result: clearResult ? null : result ?? this.result,
    problem: clearProblem ? null : problem ?? this.problem,
  );
}

class ExportController extends Notifier<ExportState> {
  int _token = 0;

  /// The user picked a phone calendar (or «crear»): a later refresh keeps it.
  bool _chosen = false;

  CalendarExporter get _exporter =>
      CalendarExporter(ref.read(deviceCalendarApiProvider));

  @override
  ExportState build() {
    final today = CivilDate.fromDateTime(ref.read(clockProvider)());
    _token = 0;
    _chosen = false;
    Future.microtask(refresh);
    // Next three months, from today.
    return ExportState(from: today, to: addMonths(today, 3).addDays(-1));
  }

  ExportProblem _problemOf(Object error, StackTrace stack) {
    if (error is CalendarApiException) {
      return switch (error.error) {
        CalendarApiError.permissionDenied => ExportProblem.permissionDenied,
        CalendarApiError.unavailable => ExportProblem.calendarUnavailable,
        _ => ExportProblem.failed,
      };
    }
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
    return ExportProblem.failed;
  }

  /// Reads the permission (never asks) and, when it is granted, the
  /// calendars.
  Future<void> refresh() async {
    if (!ref.mounted) return;
    state = state.copyWith(loading: true, clearProblem: true);
    try {
      final api = ref.read(deviceCalendarApiProvider);
      final access = await api.access();
      if (!ref.mounted) return;
      if (access != CalendarAccess.granted) {
        state = state.copyWith(loading: false, access: access);
        return;
      }
      final writable = await _exporter.writableCalendars();
      if (!ref.mounted) return;
      // «Mantener al día» on: the screen shows what it keeps up to date.
      final sync = await _syncSettings();
      if (!ref.mounted) return;
      final syncTarget = sync.active
          ? writable.where((c) => c.id == sync.deviceCalendarId).firstOrNull
          : null;
      if (syncTarget != null) _chosen = true;
      final kept =
          _chosen &&
          (state.targetId == null ||
              writable.any((c) => c.id == state.targetId));
      // The calendar called «Turnly», when there already is one (or the
      // «Cuadrante» one made before the app was renamed); else a new one is
      // created.
      final existing =
          writable
              .where((c) => c.name.trim().toLowerCase() == 'turnly')
              .firstOrNull ??
          writable
              .where((c) => c.name.trim().toLowerCase() == 'cuadrante')
              .firstOrNull;
      state = state.copyWith(
        loading: false,
        access: access,
        calendars: writable,
        targetId: syncTarget != null
            ? syncTarget.id
            : kept
            ? state.targetId
            : existing?.id,
        newCalendar: syncTarget != null
            ? false
            : kept
            ? state.targetId == null
            : existing == null,
        includeRest: syncTarget != null ? sync.includeRest : null,
        includeAbsences: syncTarget != null ? sync.includeAbsences : null,
      );
      await _updatePlan();
    } catch (error, stack) {
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, problem: _problemOf(error, stack));
    }
  }

  /// The button of the permission card: shows the system question.
  Future<void> requestAccess() async {
    if (state.loading) return;
    state = state.copyWith(loading: true, clearProblem: true);
    try {
      final outcome = await ref.read(deviceCalendarApiProvider).askForAccess();
      if (!ref.mounted) return;
      if (outcome.access == CalendarAccess.granted) {
        await refresh();
      } else {
        state = state.copyWith(
          loading: false,
          access: outcome.access,
          declined: outcome.declined,
        );
      }
    } catch (error, stack) {
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, problem: _problemOf(error, stack));
    }
  }

  Future<void> openAppSettings() async {
    try {
      await ref.read(deviceCalendarApiProvider).openSettings();
    } catch (_) {
      // The card keeps its text.
    }
  }

  Future<CalendarSyncSettings> _syncSettings() async {
    try {
      return await ref.read(calendarSyncSettingsProvider.future);
    } catch (_) {
      return CalendarSyncSettings.off;
    }
  }

  /// «Mantener al día» is on: the calendar and the options chosen are what
  /// it keeps current.
  bool get _keepingUpdated =>
      ref.read(calendarSyncSettingsProvider).asData?.value.active ?? false;

  void selectCalendar(String? id) {
    // Locked while it is on (the screen disables the rows too).
    if (_keepingUpdated) return;
    _chosen = true;
    state = state.copyWith(
      targetId: id,
      newCalendar: id == null,
      clearResult: true,
    );
    unawaited(_updatePlan());
  }

  void setRange(CivilDate from, CivilDate to) {
    if (to.isBefore(from)) return;
    final cut = to.differenceInDays(from) + 1 > maxExportDays;
    final last = cut ? from.addDays(maxExportDays - 1) : to;
    state = state.copyWith(
      from: from,
      to: last,
      rangeCut: cut,
      clearResult: true,
    );
    unawaited(_updatePlan());
  }

  void setIncludeRest(bool value) {
    state = state.copyWith(includeRest: value, clearResult: true);
    unawaited(_updatePlan());
    if (_keepingUpdated) unawaited(_updateSyncOptions(includeRest: value));
  }

  void setIncludeAbsences(bool value) {
    state = state.copyWith(includeAbsences: value, clearResult: true);
    unawaited(_updatePlan());
    if (_keepingUpdated) {
      unawaited(_updateSyncOptions(includeAbsences: value));
    }
  }

  /// The options changed while «Mantener al día» is on: it follows them.
  Future<void> _updateSyncOptions({
    bool? includeRest,
    bool? includeAbsences,
  }) async {
    await ref
        .read(calendarSyncSettingsProvider.notifier)
        .setOptions(includeRest: includeRest, includeAbsences: includeAbsences);
    ref.read(calendarSyncProvider).requestSync();
  }

  /// The switch «Mantener al día». Turning it on (with the calendar and the
  /// options chosen) creates the «Turnly» calendar when that is the choice,
  /// stores what to keep current and runs the first pass at once; turning it
  /// off leaves the events already written where they are.
  Future<void> setKeepUpdated(bool on) async {
    final settings = ref.read(calendarSyncSettingsProvider.notifier);
    if (!on) {
      await settings.disable();
      return;
    }
    if (state.running || state.syncing || !state.hasAccess) return;
    state = state.copyWith(
      syncing: true,
      clearResult: true,
      clearProblem: true,
    );
    try {
      final api = ref.read(deviceCalendarApiProvider);
      var id = state.targetId;
      if (id == null) {
        id = await api.createCalendar(
          name: exportCalendarName,
          colorValue: mainCalendarColor,
        );
        _chosen = true;
      }
      final writable = await _exporter.writableCalendars();
      final target = writable.where((c) => c.id == id).firstOrNull;
      if (target == null) {
        throw const CalendarApiException(CalendarApiError.notFound);
      }
      await settings.enable(
        deviceCalendarId: target.id,
        deviceCalendarName: target.name,
        appCalendarId: ref.read(scheduleControllerProvider).calendarId,
        includeRest: state.includeRest,
        includeAbsences: state.includeAbsences,
      );
      if (!ref.mounted) return;
      state = state.copyWith(calendars: writable, targetId: target.id);
      await ref.read(calendarSyncProvider).sync();
      if (!ref.mounted) return;
      state = state.copyWith(syncing: false);
      await _updatePlan();
    } catch (error, stack) {
      if (!ref.mounted) return;
      final problem = _problemOf(error, stack);
      state = state.copyWith(syncing: false, problem: problem);
      if (problem == ExportProblem.permissionDenied) await refresh();
    }
  }

  Future<void> _updatePlan() async {
    final token = ++_token;
    final scheduleState = ref.read(scheduleControllerProvider);
    try {
      final plan = await _exporter.preview(
        schedule: scheduleState.schedule,
        appCalendarId: scheduleState.calendarId,
        deviceCalendarId: state.targetId,
        from: state.from,
        to: state.to,
        includeRest: state.includeRest,
        includeAbsences: state.includeAbsences,
      );
      if (!ref.mounted || token != _token) return;
      state = state.copyWith(plan: plan);
    } catch (_) {
      if (!ref.mounted || token != _token) return;
      state = state.copyWith(clearPlan: true);
    }
  }

  /// Writes the shifts to the phone's calendar.
  Future<void> start() async {
    if (state.running || state.syncing || !state.hasAccess) return;
    final scheduleState = ref.read(scheduleControllerProvider);
    state = state.copyWith(
      running: true,
      done: 0,
      total: state.plan == null
          ? 0
          : state.plan!.toCreate.length + state.plan!.toDelete.length,
      clearResult: true,
      clearProblem: true,
    );
    try {
      final id = state.targetId;
      // One writer at a time: a pass of «Mantener al día» waits for this
      // export (and the other way round), so the two never interleave.
      final result = await ref
          .read(calendarWriteLockProvider)
          .run(
            () => _exporter.export(
              schedule: scheduleState.schedule,
              appCalendarId: scheduleState.calendarId,
              target: id == null
                  ? const NewCalendar(colorValue: mainCalendarColor)
                  : ExistingCalendar(id),
              from: state.from,
              to: state.to,
              includeRest: state.includeRest,
              includeAbsences: state.includeAbsences,
              onProgress: (done, total) {
                if (ref.mounted) {
                  state = state.copyWith(done: done, total: total);
                }
              },
            ),
          );
      if (!ref.mounted) return;
      // A calendar created now is the choice from now on (a second export
      // writes to it instead of creating another), and the plan is stale.
      _chosen = true;
      state = state.copyWith(
        running: false,
        result: result,
        targetId: result.deviceCalendarId,
      );
      try {
        final writable = await _exporter.writableCalendars();
        if (!ref.mounted) return;
        state = state.copyWith(calendars: writable);
      } catch (_) {
        // The list is refreshed the next time the screen opens.
      }
      await _updatePlan();
    } catch (error, stack) {
      if (!ref.mounted) return;
      final problem = _problemOf(error, stack);
      state = state.copyWith(running: false, problem: problem);
      if (problem == ExportProblem.permissionDenied) await refresh();
    }
  }
}

final exportControllerProvider =
    NotifierProvider.autoDispose<ExportController, ExportState>(
      ExportController.new,
    );
