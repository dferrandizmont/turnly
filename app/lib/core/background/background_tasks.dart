import 'dart:ui' show DartPluginRegistrant;

import 'package:workmanager/workmanager.dart';

import '../../features/alarms/data/alarm_renewal_task.dart';
import '../../features/backup/data/folder_backup_task.dart';

/// One background task: runs and says whether it worked (`false` asks
/// WorkManager to retry it later with its backoff).
typedef BackgroundTask = Future<bool> Function();

/// Every background task of the app, by its WorkManager task name. A new task
/// adds one line here and registers itself with its own unique name, always
/// initializing WorkManager with [backgroundTaskDispatcher]
/// (docs/copia-de-seguridad.md, section 11; docs/alarmas.md).
Map<String, BackgroundTask> appBackgroundTasks() => {
  alarmRenewalTaskName: runAlarmRenewalTask,
  folderBackupTaskName: runFolderBackupTask,
};

/// Runs the task called [task] from [tasks]. An unknown name (a task left
/// registered by an older build) is done: `true`, so it is not retried. A task
/// that throws is `false`.
Future<bool> runBackgroundTask(
  String task,
  Map<String, BackgroundTask> tasks,
) async {
  final run = tasks[task];
  if (run == null) return true;
  try {
    return await run();
  } catch (_) {
    return false;
  }
}

/// The app's **only** WorkManager entry point (Android). WorkManager keeps one
/// callback handle per app, written by the last `initialize`, so every
/// feature that registers work initializes with this same function
/// (`WorkmanagerAlarmRenewal`, `WorkmanagerFolderBackup`) and adds its task to
/// [appBackgroundTasks]. Top level and `vm:entry-point` so the compiler keeps
/// it; the isolate it runs in has plugins (also `turnly_folder_access`) but no
/// providers, widgets or localizations.
@pragma('vm:entry-point')
void backgroundTaskDispatcher() {
  Workmanager().executeTask((task, _) async {
    try {
      DartPluginRegistrant.ensureInitialized();
    } catch (_) {
      // Already done by the binding.
    }
    return runBackgroundTask(task, appBackgroundTasks());
  });
}
