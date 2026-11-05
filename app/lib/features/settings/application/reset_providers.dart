import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/providers.dart';
import '../../../core/diagnostics/crash_reporting.dart';
import '../../alarms/application/alarm_providers.dart';
import '../../backup/application/backup_providers.dart';
import '../../backup/application/folder_backup_providers.dart';
import '../../backup/domain/backup_store.dart';
import '../../calendar/application/calendar_background_providers.dart';
import '../../calendar/application/paint_controller.dart';
import '../../calendar/application/month_presentation.dart';
import '../../calendar/application/open_day.dart';
import '../../calendar/application/schedule_controller.dart';
import '../../calendar/application/selection_controller.dart';
import '../../calendar/application/visible_month.dart';
import '../../calendar_export/application/calendar_sync_providers.dart';
import '../../calendar_export/application/ics_export.dart';
import '../../calendar_export/data/reset_calendar_events.dart';
import '../../calendars/application/calendars_controller.dart';
import '../../dnd/application/dnd_providers.dart';
import '../../device_events/application/device_events_providers.dart';
import '../../holidays/application/holidays_provider.dart';
import '../../notes/application/notes_providers.dart';
import '../../notes/presentation/attachment_history.dart';
import '../../onboarding/application/onboarding_controller.dart';
import '../../onboarding/application/onboarding_providers.dart';
import '../../patterns/application/post_night_provider.dart';
import '../../swaps/application/swaps_controller.dart';
import '../../share_link/application/share_link_controller.dart';
import '../../share_link/domain/share_token.dart';
import '../../year/application/year_providers.dart';
import '../../widget/application/widget_providers.dart';
import '../data/reset_repository.dart';
import '../data/preferences_repository.dart';
import 'preferences_controller.dart';
import 'reset_everything.dart';

/// A strict, read-back verified local safety copy. Only the two newest
/// verified pre-reset files rotate; automatic backups and cloud never touch it.
final resetBackupProvider = Provider<Future<BackupEntry> Function()>((ref) {
  return () async {
    final tools = await ref.read(backupToolsProvider.future);
    final bytes = await tools.service.exportBytes();
    final entry = await tools.preResetStore.save(
      bytes,
      at: ref.read(clockProvider)(),
    );
    try {
      await tools.service.decodeFile(await tools.preResetStore.read(entry));
    } catch (_) {
      await tools.preResetStore.delete(entry);
      rethrow;
    }
    await tools.preResetStore.prune();
    ref.invalidate(backupCopiesProvider);
    return entry;
  };
});

/// Uses the existing backup share sheet, sharing the saved file, never an
/// export of the now-empty database.
final shareResetBackupProvider = Provider<Future<void> Function(BackupEntry)>(
  (ref) => (entry) async {
    final tools = await ref.read(backupToolsProvider.future);
    await ref.read(backupSharerProvider)(
      await tools.preResetStore.read(entry),
      entry.id,
    );
  },
);

Future<void> _optionalNative(Future<void> Function() action) async {
  try {
    await action();
  } on MissingPluginException {
    // Dart is ready for the Mac; an absent iOS channel is inert.
  }
}

/// Temporary share files, isolated from application support and saved backups.
final resetTemporaryDirectoryProvider = Provider<Future<Directory> Function()>(
  (ref) => getTemporaryDirectory,
);

/// Housekeeping sweeps intentionally swallow individual filesystem failures.
/// Reset verifies their result so leftovers become a reported cleanup warning.
Future<void> _verifyEmptyFiles(Directory directory) async {
  if (!await directory.exists()) return;
  if (await directory
      .list(recursive: true, followLinks: false)
      .any((e) => e is File)) {
    throw StateError('reset files remain');
  }
}

final resetEverythingProvider = Provider<ResetEverything>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final schedule = ref.read(scheduleControllerProvider.notifier);
  final alarms = ref.read(alarmSyncProvider);
  final dnd = ref.read(dndSyncProvider);
  final widget = ref.read(widgetSyncProvider);
  final calendar = ref.read(calendarSyncProvider);
  final automatic = ref.read(autoBackupRunnerProvider);
  ShareToken? shareToken;
  var calendarWasUsed = true;
  void report(Object error, StackTrace stack) {
    unawaited(
      ref
          .read(crashReporterProvider)
          .record(redactError(error), stack, fatal: false)
          .catchError((Object _) {}),
    );
  }

  return ResetEverything(
    runExclusive: schedule.runExclusive,
    createBackup: ref.read(resetBackupProvider),
    verifyBackup: (entry) async {
      final tools = await ref.read(backupToolsProvider.future);
      await tools.service.decodeFile(await tools.preResetStore.read(entry));
    },
    onError: report,
    pause: () async {
      // Capture the token before settings disappear. Revocation itself comes
      // after the database transaction and uses no controller writes/timers.
      await ref.read(shareLinkControllerProvider.notifier).load();
      shareToken =
          ref.read(shareLinkControllerProvider).settings.token ??
          (await ref.read(shareLinkRepositoryProvider).load()).token;
      // Also before settings disappear: whether «Mantener al día» was ever
      // set up decides if a refused calendar permission is worth a warning.
      try {
        final sync = await ref.read(calendarSyncSettingsProvider.future);
        calendarWasUsed =
            sync.enabled ||
            sync.deviceCalendarId != null ||
            sync.lastSyncAt != null;
      } catch (_) {
        calendarWasUsed = true;
      }
      ref.read(restoreInProgressProvider.notifier).set(true);
      await automatic.pause();
      await Future.wait([
        alarms.pause(),
        dnd.pause(),
        widget.pause(),
        calendar.pause(),
      ]);
    },
    resume: () async {
      alarms.resume();
      dnd.resume();
      widget.resume();
      calendar.resume();
      // Read the committed first-use flags before lifting the pause. The
      // runner stays off after reset, including when reload partly failed.
      final ready = await ref.refresh(autoBackupReadyProvider.future);
      if (!ready) {
        // The first use is still pending: nothing may replace the copy of the
        // reset with one of the empty app.
        automatic.enabled = false;
      }
      ref.read(restoreInProgressProvider.notifier).set(false);
    },
    clearDatabase: ResetRepository(db, now: ref.read(clockProvider)).clear,
    cleanup: [
      ResetCleanup(
        ResetCleanupStep.calendar,
        () => ref
            .read(calendarWriteLockProvider)
            .run(
              () => ResetCalendarEvents(
                onError: report,
                calendarWasUsed: calendarWasUsed,
              ).deleteAppEvents(),
            ),
      ),
      ResetCleanup(
        ResetCleanupStep.alarms,
        () => _optionalNative(
          () => ref.read(alarmRenewalRegistrarProvider).setEnabled(false),
        ),
      ),
      ResetCleanup(
        ResetCleanupStep.alarms,
        () => _optionalNative(ref.read(alarmSchedulerProvider).cancelAll),
      ),
      ResetCleanup(
        ResetCleanupStep.dnd,
        () => _optionalNative(ref.read(dndChannelProvider).cancelAll),
      ),
      ResetCleanup(
        ResetCleanupStep.widget,
        ref.read(widgetPublisherProvider).clear,
      ),
      ResetCleanup(ResetCleanupStep.attachments, () async {
        final store = await ref.read(attachmentStoreProvider.future);
        await store.sweep({});
        await _verifyEmptyFiles(store.root);
      }),
      ResetCleanup(ResetCleanupStep.background, () async {
        final store = await ref.read(calendarBackgroundStoreProvider.future);
        await store.sweep(null);
        await _verifyEmptyFiles(store.root);
      }),
      ResetCleanup(ResetCleanupStep.exports, () async {
        final cache = await ref.read(exportCacheProvider.future);
        await cache.sweep();
        await _verifyEmptyFiles(cache.directory);
      }),
      ResetCleanup(ResetCleanupStep.ics, () async {
        final directory = await ref.read(icsExportDirectoryProvider)();
        if (await directory.exists()) await directory.delete(recursive: true);
      }),
      ResetCleanup(ResetCleanupStep.images, () async {
        await deleteStaleSharedImages(
          await ref.read(resetTemporaryDirectoryProvider)(),
          all: true,
        );
      }),
      ResetCleanup(ResetCleanupStep.shareLink, () async {
        final token = shareToken;
        if (token == null) return;
        final api = ref.read(shareLinkApiProvider);
        if (api == null) throw StateError('share link unavailable');
        await api.revoke(token);
      }),
      ResetCleanup(ResetCleanupStep.folderBackup, () async {
        if (ref.read(folderBackupSupportedProvider)) {
          await ref.read(folderBackupControllerProvider.notifier).stop();
        }
      }),
      ResetCleanup(ResetCleanupStep.preferences, () async {
        await PreferencesRepository(db).seedRegionDefaults(
          WidgetsBinding.instance.platformDispatcher.locales,
        );
      }),
    ],
    reload: () async {
      // Reload actual storage; invalidating bootstrap-backed controllers
      // would reinstate their pre-reset snapshots.
      var failed = false;
      for (final action in <Future<void> Function()>[
        schedule.reload,
        ref.read(preferencesProvider.notifier).reload,
        () async {
          await ref
              .read(holidayRepositoryProvider)
              .refreshBundled(ref.read(holidayBundleLoaderProvider));
        },
        ref.read(holidayControllerProvider.notifier).reload,
        ref.read(postNightAutoProvider.notifier).reload,
        ref.read(onboardingTipProvider.notifier).reload,
      ]) {
        try {
          await action();
        } catch (error, stack) {
          failed = true;
          report(error, stack);
        }
      }
      ref.invalidate(calendarsControllerProvider);
      ref.invalidate(alarmSettingsProvider);
      ref.invalidate(dndSettingsProvider);
      ref.invalidate(calendarSyncSettingsProvider);
      ref.invalidate(dayTaskListProvider);
      ref.invalidate(dayAttachmentHistoryProvider);
      ref.invalidate(swapLedgerProvider);
      ref.invalidate(paintControllerProvider);
      ref.invalidate(selectionControllerProvider);
      ref.invalidate(dayClipboardProvider);
      ref.invalidate(monthPresentationProvider);
      ref.invalidate(todayCardCollapsedProvider);
      ref.invalidate(monthDayFocusProvider);
      ref.invalidate(openDayProvider);
      ref.invalidate(noteDraftProvider);
      ref.invalidate(deviceEventsSettingsProvider);
      ref.invalidate(deviceEventsProvider);
      ref.invalidate(shareLinkControllerProvider);
      ref.invalidate(visibleMonthProvider);
      ref.invalidate(onboardingControllerProvider);
      ref.invalidate(backupCopiesProvider);
      ref.invalidate(autoBackupEnabledProvider);
      ref.invalidate(cloudBackupEnabledProvider);
      if (failed) throw StateError('reset reload incomplete');
    },
  );
});
