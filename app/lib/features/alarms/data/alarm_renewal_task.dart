import 'dart:async';
import 'dart:io';
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:drift/native.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:workmanager/workmanager.dart';

import '../../../core/background/background_tasks.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_opener.dart' show databaseFileName;
import '../../../core/diagnostics/debug_log.dart';
import '../../../core/format/app_date_format.dart';
import '../../../core/format/app_formats.dart';
import '../../../core/format/region_defaults.dart';
import '../../../core/l10n/app_locales.dart';
import '../../../l10n/app_localizations.dart';
import '../../calendars/data/calendars_repository.dart';
import '../../schedule/data/schedule_repository.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../../settings/data/preferences_repository.dart';
import '../application/alarm_renewal.dart';
import '../domain/alarm_settings.dart';
import '../domain/alarm_strings.dart';
import 'alarm_foreground_relay.dart';
import 'alarm_settings_repository.dart';
import 'local_alarm_scheduler.dart';

/// Unique name (and task name) of the periodic renewal in WorkManager.
const String alarmRenewalTaskName = 'es.cuadrante.app.alarmRenewal';

/// How often Android runs the renewal. WorkManager may run it later (Doze,
/// battery saver, a manufacturer's restrictions), never more often.
const Duration alarmRenewalFrequency = Duration(hours: 12);

/// First wait after registering: the app has just planned, nothing to renew.
const Duration alarmRenewalInitialDelay = Duration(hours: 1);

/// Wait before retrying a failed run (database busy...), exponential.
const Duration alarmRenewalBackoff = Duration(minutes: 30);

/// How long the background connection waits for the app's write lock.
const Duration alarmRenewalBusyTimeout = Duration(seconds: 3);

/// Android: registers the periodic renewal with WorkManager (A1).
///
/// The first call of each process registers or cancels (initializing the
/// plugin, which stores the callback handle of the app's shared
/// [backgroundTaskDispatcher], before the first registration: the folder copy
/// initializes with the same function, so neither replaces the other's
/// entry point); later calls only act when the state
/// changes. The policy is `update`: an
/// app start keeps the task's timing instead of restarting it. No network,
/// battery or charging requirement: the work is local and short.
class WorkmanagerAlarmRenewal implements AlarmRenewalRegistrar {
  WorkmanagerAlarmRenewal({Workmanager? workmanager})
    : _workmanager = workmanager ?? Workmanager();

  final Workmanager _workmanager;
  bool _initialized = false;
  bool? _enabled;

  @override
  Future<void> setEnabled(bool enabled) async {
    if (_enabled == enabled) return;
    if (enabled) {
      // Registering needs the callback handle stored; cancelling does not.
      if (!_initialized) {
        await _workmanager.initialize(backgroundTaskDispatcher);
        _initialized = true;
      }
      await _workmanager.registerPeriodicTask(
        alarmRenewalTaskName,
        alarmRenewalTaskName,
        frequency: alarmRenewalFrequency,
        initialDelay: alarmRenewalInitialDelay,
        constraints: Constraints(networkType: NetworkType.notRequired),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: alarmRenewalBackoff,
      );
    } else {
      await _workmanager.cancelByUniqueName(alarmRenewalTaskName);
    }
    _enabled = enabled;
  }
}

/// Entry point of an earlier build (a callback handle it stored may still be
/// in WorkManager until the app starts again and initializes with the shared
/// [backgroundTaskDispatcher]): delegates to it.
@pragma('vm:entry-point')
void alarmRenewalDispatcher() => backgroundTaskDispatcher();

/// The background renewal, as the shared dispatcher runs it for
/// [alarmRenewalTaskName]. It has plugins but no providers, no widgets and no
/// localizations of its own.
Future<bool> runAlarmRenewalTask() async {
  final outcome = await runAlarmRenewal(
    askApp: askForegroundToResync,
    openStore: openAlarmRenewalStore,
    // No sounds service (its channel lives in MainActivity, absent here)
    // and no system channel: every custom sound is trusted and its channel
    // is left as the app made it.
    scheduler: () => LocalAlarmScheduler(manageSoundChannels: false),
    strings: alarmStringsFor,
    now: DateTime.now,
    onError: (error, _) => debugLogFailure('Alarmas: renovación', error),
  );
  debugLog('Alarmas: renovación en segundo plano: ${outcome.name}');
  return alarmRenewalSucceeded(outcome);
}

/// The alarm texts in [format], as `AlarmsHost` builds them: the ARB of the
/// language and the clock of `AppDateFormat(localeName, hour12)`.
Future<AlarmStrings> alarmStringsFor(AlarmTextFormat format) async {
  await initializeDateFormatting(format.locale.languageCode);
  return AlarmStrings.fromL10n(
    lookupAppLocalizations(format.locale),
    clock: alarmClock(
      AppDateFormat(
        format.formatLocale ?? format.locale.languageCode,
        format.hour12,
      ),
    ),
  );
}

/// Opens the app's database for the background renewal, **read-only** and
/// without Drift migrations, or returns null when it must not be read: there
/// is no file yet, or it is on another schema version than this code's (an
/// update the user has not opened: its migration, with its safety copy, is
/// only ever run by the app). Throws when SQLite cannot open it (busy, a
/// journal left by a crash that only a read-write open recovers): the run
/// fails and WorkManager retries later.
///
/// [directory] replaces Application Support (tests).
Future<AlarmRenewalStore?> openAlarmRenewalStore({Directory? directory}) async {
  final dir = directory ?? await getApplicationSupportDirectory();
  final file = File(p.join(dir.path, databaseFileName));
  if (!file.existsSync() || file.lengthSync() == 0) return null;
  final raw = sqlite3.open(file.path, mode: OpenMode.readOnly);
  try {
    raw.execute(
      'PRAGMA busy_timeout = ${alarmRenewalBusyTimeout.inMilliseconds}',
    );
    final version = raw.select('PRAGMA user_version').first.values.first;
    if (version != AppDatabase.latestSchemaVersion) {
      raw.close();
      return null;
    }
  } catch (_) {
    raw.close();
    rethrow;
  }
  return DatabaseAlarmRenewalStore(
    AppDatabase(NativeDatabase.opened(raw, enableMigrations: false)),
  );
}

/// [AlarmRenewalStore] over the app's repositories (the same reads the app
/// does: `AlarmSettingsRepository`, the primary calendar, the language and
/// the time format).
class DatabaseAlarmRenewalStore implements AlarmRenewalStore {
  /// [_phoneLocales] and [_phoneUses24Hour] replace the phone's languages and
  /// its 24-hour switch (tests).
  DatabaseAlarmRenewalStore(
    this._db, {
    this._phoneLocales,
    this._phoneUses24Hour,
  });

  final AppDatabase _db;
  final List<Locale>? _phoneLocales;
  final bool? _phoneUses24Hour;

  @override
  Future<AlarmSettings> loadSettings() => AlarmSettingsRepository(_db).load();

  @override
  Future<Schedule> loadPrimarySchedule() async {
    final id = await CalendarsRepository(_db).primaryId();
    return (await ScheduleRepository(_db).load(id)).schedule;
  }

  /// Resolved like `bootstrapApp` (language) and `FormatsHost` (format
  /// locale and clock). «Automático» has no `MediaQuery` here: it uses the
  /// engine's `alwaysUse24HourFormat`, which a headless engine usually never
  /// receives (false), so in practice the region decides, as in the app when
  /// the phone's 24-hour switch is off.
  @override
  Future<AlarmTextFormat> textFormat() async {
    final preferences = await PreferencesRepository(_db).load();
    final phone = _phoneLocales ?? PlatformDispatcher.instance.locales;
    final locale = preferences.language.locale ?? resolveAppLocale(phone);
    final formatLocale = formatLocaleName(locale.languageCode, phone);
    // `localeUses12HourClock` reads the patterns of `intl`.
    await initializeDateFormatting(locale.languageCode);
    return AlarmTextFormat(
      locale: locale,
      formatLocale: formatLocale,
      hour12: preferences.timeFormat.resolve(
        phoneUses24Hour:
            _phoneUses24Hour ??
            PlatformDispatcher.instance.alwaysUse24HourFormat,
        localeUses12Hour: localeUses12HourClock(formatLocale),
      ),
    );
  }

  @override
  Future<void> close() => _db.close();
}
