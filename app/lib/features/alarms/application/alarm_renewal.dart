import 'dart:async';
import 'dart:ui' show Locale;

import '../../schedule/domain/schedule_domain.dart';
import '../data/alarm_scheduler.dart';
import '../domain/alarm_planner.dart';
import '../domain/alarm_settings.dart';
import '../domain/alarm_strings.dart';

/// Keeps the periodic background renewal of the alarms (A1,
/// docs/alarmas.md «Renovación en segundo plano») registered while the shift
/// alarms are on, and cancelled when they are off. `AlarmSync` calls it after
/// every run.
abstract interface class AlarmRenewalRegistrar {
  /// Registers the periodic task ([enabled]) or cancels it. Cheap when
  /// nothing changes; may throw (the caller reports and carries on).
  Future<void> setEnabled(bool enabled);
}

/// Nothing to register: tests, desktop and **iOS**, whose background refresh
/// (`BGTaskScheduler`, with its `Info.plist` identifiers and capability) is
/// set up on the Mac (docs/alarmas.md, «iOS»). On iOS the renewal notice and
/// opening the app keep the alarms going until then.
class NoAlarmRenewal implements AlarmRenewalRegistrar {
  const NoAlarmRenewal();

  @override
  Future<void> setEnabled(bool enabled) async {}
}

/// Records the calls (tests).
class FakeAlarmRenewal implements AlarmRenewalRegistrar {
  final List<bool> calls = [];

  @override
  Future<void> setEnabled(bool enabled) async => calls.add(enabled);
}

/// What the background renewal reads from the database: opened, read and
/// closed in one go (`runAlarmRenewal`).
abstract interface class AlarmRenewalStore {
  Future<AlarmSettings> loadSettings();

  /// The schedule of the primary calendar (the one the alarms follow).
  Future<Schedule> loadPrimarySchedule();

  /// How the app writes the alarm texts: its language (Ajustes › Idioma,
  /// else the phone's) and its clock (Ajustes › Formato de hora), resolved
  /// as the app does, so the background texts match the app's.
  Future<AlarmTextFormat> textFormat();

  Future<void> close();
}

/// The language and the clock of the alarm texts (see
/// [AlarmRenewalStore.textFormat]).
class AlarmTextFormat {
  const AlarmTextFormat({
    required this.locale,
    this.formatLocale,
    this.hour12 = false,
  });

  /// Language of the app (the ARB file).
  final Locale locale;

  /// Language plus region for `intl` ("es_MX", `formatLocaleName`), as
  /// `AppFormats.localeName`; null = the language alone.
  final String? formatLocale;

  /// "10:00 PM" (true) or "22:00", as `AppFormats.hour12`.
  final bool hour12;

  @override
  bool operator ==(Object other) =>
      other is AlarmTextFormat &&
      other.locale == locale &&
      other.formatLocale == formatLocale &&
      other.hour12 == hour12;

  @override
  int get hashCode => Object.hash(locale, formatLocale, hour12);

  @override
  String toString() =>
      'AlarmTextFormat($locale, $formatLocale, '
      '${hour12 ? '12 h' : '24 h'})';
}

/// How a background renewal ended (logged, and what the tests check).
enum AlarmRenewalOutcome {
  /// The app was alive in this process and replanned itself.
  handledByApp,

  /// The plan was recomputed and handed to the scheduler.
  renewed,

  /// No database to read (not created yet, or on a schema other than this
  /// code's: an update not opened yet, whose migration only the app runs).
  noDatabase,

  /// The shift alarms are off: nothing is touched.
  alarmsOff,

  /// No notification permission: nothing is touched (the app cancels what
  /// it has to when it is opened).
  noPermission,

  /// Something failed (database busy, plugin error): nothing more is done
  /// and the task asks to be retried later.
  failed,
}

/// Whether WorkManager should count the run as done (`true`) or retry it
/// with its backoff (`false`).
bool alarmRenewalSucceeded(AlarmRenewalOutcome outcome) =>
    outcome != AlarmRenewalOutcome.failed;

/// One background renewal (A1), with every dependency injected so it is
/// tested as a plain function:
///
/// 1. [askApp]: if the app is alive in this process, it replans itself
///    (`AlarmSync`, serialised with its own runs) and nothing else is done,
///    so two planners never write the pending alarms at the same time.
/// 2. [openStore] (null = no usable database) is read and **closed** before
///    any notification work, so the database is held for milliseconds.
///    Alarms off: stop there, touching nothing.
/// 3. Same steps as `AlarmSync`: texts, plugin, permission (missing: stop,
///    touching nothing), the same planner (`planAlarmSchedule`) and
///    `replaceAll`, which only ever replaces our planned alarms by id. So it
///    never duplicates an alarm, a skipped day stays silent (it is in the
///    settings it read) and a snoozed alarm (another payload prefix) is never
///    touched.
/// 4. [askApp] again: if the app started meanwhile, it replans once more
///    over whatever this run wrote.
///
/// Never throws: any error is [AlarmRenewalOutcome.failed].
Future<AlarmRenewalOutcome> runAlarmRenewal({
  required Future<bool> Function() askApp,
  required Future<AlarmRenewalStore?> Function() openStore,
  required AlarmScheduler Function() scheduler,
  required Future<AlarmStrings> Function(AlarmTextFormat format) strings,
  required DateTime Function() now,
  void Function(Object error, StackTrace stack)? onError,
}) async {
  try {
    if (await askApp()) return AlarmRenewalOutcome.handledByApp;

    final store = await openStore();
    if (store == null) return AlarmRenewalOutcome.noDatabase;
    final AlarmSettings settings;
    final Schedule schedule;
    final AlarmTextFormat format;
    try {
      settings = await store.loadSettings();
      if (!settings.anyActive) return AlarmRenewalOutcome.alarmsOff;
      schedule = await store.loadPrimarySchedule();
      format = await store.textFormat();
    } finally {
      await store.close();
    }

    final texts = await strings(format);
    final plugin = scheduler();
    await plugin.configure(texts);
    await plugin.initialize();
    if (await plugin.permissionStatus() != AlarmPermission.granted) {
      return AlarmRenewalOutcome.noPermission;
    }
    final plan = planAlarmSchedule(
      schedule: schedule,
      settings: settings,
      now: now(),
      strings: texts,
      location: await plugin.planningZone(),
    );
    await plugin.replaceAll(plan.toSchedule);
    // The app may have started while this ran: let it have the last word.
    try {
      await askApp();
    } catch (_) {
      // The renewal itself is done.
    }
    return AlarmRenewalOutcome.renewed;
  } catch (error, stack) {
    onError?.call(error, stack);
    return AlarmRenewalOutcome.failed;
  }
}
