import 'dart:io';
import 'dart:async';

import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/providers.dart';
import 'package:cuadrante/core/diagnostics/crash_reporting.dart';
import 'package:cuadrante/features/calendar/application/schedule_controller.dart';
import 'package:cuadrante/features/settings/application/reset_everything.dart';
import 'package:cuadrante/features/calendar_export/application/ics_export.dart';
import 'package:cuadrante/features/backup/application/backup_models.dart';
import 'package:cuadrante/features/backup/application/folder_backup_engine.dart';
import 'package:cuadrante/features/backup/application/folder_backup_providers.dart';
import 'package:cuadrante/features/backup/data/folder_backup_state_store.dart';
import 'package:cuadrante/features/backup/domain/folder_backup.dart';
import 'package:cuadrante/features/backup/domain/backup_store.dart';
import 'package:cuadrante/features/share_link/application/share_link_controller.dart';
import 'package:cuadrante/features/share_link/data/share_link_api.dart';
import 'package:cuadrante/features/share_link/domain/share_token.dart';
import 'package:cuadrante/l10n/app_localizations.dart';
import 'package:cuadrante/features/alarms/application/alarm_providers.dart';
import 'package:cuadrante/features/alarms/data/alarm_scheduler.dart';
import 'package:cuadrante/features/backup/domain/backup_codec.dart';
import 'package:cuadrante/features/backup/application/backup_providers.dart';
import 'package:cuadrante/features/backup/data/export_cache.dart';
import 'package:cuadrante/features/backup/presentation/backup_copy_list.dart';
import 'package:cuadrante/features/calendar/application/calendar_background_providers.dart';
import 'package:cuadrante/features/calendar/data/calendar_background_store.dart';
import 'package:cuadrante/features/calendar_export/application/device_calendar_providers.dart';
import 'package:cuadrante/features/dnd/application/dnd_providers.dart';
import 'package:cuadrante/features/dnd/data/dnd_channel.dart';
import 'package:cuadrante/features/notes/application/notes_providers.dart';
import 'package:cuadrante/features/notes/data/attachment_store.dart';
import 'package:cuadrante/features/onboarding/presentation/onboarding_screen.dart';
import 'package:cuadrante/features/onboarding/application/onboarding_controller.dart';
import 'package:cuadrante/features/settings/application/reset_providers.dart';
import 'package:cuadrante/features/settings/presentation/reset_screen.dart';
import 'package:cuadrante/features/settings/presentation/settings_widgets.dart';
import 'package:cuadrante/features/widget/application/widget_providers.dart';
import 'package:cuadrante/features/widget/data/widget_publisher.dart';
import 'package:cuadrante/features/widget/domain/widget_sync_planner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/probes.dart';
import '../../support/fake_device_calendar.dart';
import '../backup/backup_ui_support.dart';
import '../backup/folder_backup_support.dart';

void main() {
  setUpAll(initializeLocale);
  Finder key(String value) => find.byKey(ValueKey(value));

  Future<AppUnderTest> open(
    WidgetTester tester,
    BackupUiHarness h, {
    List<Override> extra = const [],
    CalendarBackgroundStore? backgroundStore,
  }) async {
    final app = await AppUnderTest.pump(
      tester,
      size: const Size(390, 2200),
      overrides: [
        ...h.overrides,
        resetTemporaryDirectoryProvider.overrideWithValue(() async => h.root),
        icsExportDirectoryProvider.overrideWithValue(
          () async => Directory('${h.root.path}/ics-export'),
        ),
        exportCacheProvider.overrideWith(
          (ref) async => ExportCache(Directory('${h.root.path}/cache')),
        ),
        deviceCalendarApiProvider.overrideWithValue(FakeDeviceCalendar()),
        attachmentStoreProvider.overrideWith(
          (ref) async =>
              AttachmentStore(Directory('${h.root.path}/attachments')),
        ),
        calendarBackgroundStoreProvider.overrideWith(
          (ref) async =>
              backgroundStore ??
              CalendarBackgroundStore(Directory('${h.root.path}/background')),
        ),
        ...extra,
      ],
    );
    await app.openSettings();
    await tester.ensureVisible(key('settings-reset'));
    await tester.pumpAndSettle();
    await tester.tap(key('settings-reset'));
    await pumpIo(
      tester,
      until: find.byWidgetPredicate(
        (w) =>
            w.key == const ValueKey('reset-share') ||
            w.key == const ValueKey('reset-error'),
      ),
    );
    return app;
  }

  testWidgets('reset is the last row in its own danger section', (
    tester,
  ) async {
    final app = await AppUnderTest.pump(tester, size: const Size(390, 3600));
    await app.openSettings();
    final rows = tester
        .widgetList<SettingsRow>(find.byType(SettingsRow))
        .toList();
    expect(rows.last.key, const ValueKey('settings-reset'));
    expect(rows.last.destructive, isTrue);
    final section = find.ancestor(
      of: key('settings-reset'),
      matching: find.byType(SettingsSection),
    );
    expect(section, findsOneWidget);
    expect(
      find.descendant(of: section, matching: find.byType(SettingsRow)),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(key('settings-reset')).dy,
      greaterThan(tester.getTopLeft(key('settings-about')).dy),
    );
  });

  testWidgets('lists all data, saves a copy and shares that saved backup', (
    tester,
  ) async {
    final h = BackupUiHarness(tester);
    await open(tester, h);
    expect(find.byType(ResetScreen), findsOneWidget);
    final l10n = lookupAppLocalizations(const Locale('es'));
    final expected = [
      l10n.resetCalendars,
      l10n.resetNotes,
      l10n.resetAbsences,
      l10n.resetHolidays,
      l10n.resetSwaps,
      l10n.resetAlarms,
      l10n.resetWidget,
      l10n.resetDnd,
      l10n.resetCalendarEvents,
      l10n.resetShareLink,
      l10n.resetFolderBackup,
      l10n.resetPreferences,
    ];
    for (final item in expected) {
      expect(find.text('• $item'), findsOneWidget);
    }
    expect(
      tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => t.data?.startsWith('• ') ?? false),
      hasLength(expected.length),
    );
    expect(find.textContaining('Solo conservamos el idioma'), findsOneWidget);
    expect(h.files, hasLength(1));
    await tapIo(tester, key('reset-share'));
    expect(h.shared, hasLength(1));
    final data = const BackupCodec().decode(h.shared.single.bytes).data;
    expect(data.dayEntries, isNotEmpty);
    expect(h.shared.single.fileName, h.files.single);
  });

  testWidgets(
    'confirmation can be cancelled; confirming reaches first use with copy intact',
    (tester) async {
      final h = BackupUiHarness(tester);
      final scheduler = FakeAlarmScheduler();
      final widget = FakeWidgetPublisher();
      final dnd = FakeDndChannel();
      final app = await open(
        tester,
        h,
        extra: [
          alarmSchedulerProvider.overrideWithValue(scheduler),
          widgetPublisherProvider.overrideWithValue(widget),
          dndChannelProvider.overrideWithValue(dnd),
        ],
      );
      final dndCancellations = dnd.cancelCalls;
      final preparedCopy = h.filesStartingWith('pre-reset-').single;
      await tapIo(tester, key('reset-delete'), until: find.byType(AlertDialog));
      expect(find.text('¿Borrar todo?'), findsOneWidget);
      expect(
        find.textContaining('No se puede deshacer, pero tienes la copia del'),
        findsOneWidget,
      );
      await tester.tap(key('confirm-cancel'));
      await pumpIo(tester);
      expect(h.filesStartingWith('pre-reset-'), [preparedCopy]);
      expect(app.schedule.schedule.entries, isNotEmpty);
      expect(scheduler.cancelAllCalls, 0);
      await tapIo(tester, key('reset-delete'), until: find.byType(AlertDialog));
      await tester.tap(key('confirm-ok'));
      await pumpIo(tester, until: find.byType(OnboardingScreen));
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(ResetScreen), findsNothing);
      expect(app.schedule.schedule.entries, isEmpty);
      expect(app.schedule.schedule.runs, isEmpty);
      expect(scheduler.cancelAllCalls, 1);
      expect(dnd.cancelCalls, greaterThan(dndCancellations));
      expect(widget.stored, isNull);
      final reloads = widget.reloadCount;
      unawaited(
        app.container
            .read(widgetSyncProvider)
            .request(WidgetSyncTrigger.appResumed),
      );
      await pumpIo(
        tester,
        until: find.byWidgetPredicate(
          (w) => w is OnboardingScreen && widget.reloadCount > reloads,
        ),
      );
      expect(
        widget.stored,
        isNull,
        reason: 'resume during first use keeps the widget empty',
      );
      expect(h.filesStartingWith('pre-reset-'), [preparedCopy]);
      // Past debounce and spacing: first use must keep the empty database
      // out of the automatic store, even after a fresh runner is created.
      await tester.pump(const Duration(minutes: 16));
      await pumpIo(tester);
      expect(h.filesStartingWith('turnly-'), isEmpty);
      app.container.invalidate(autoBackupRunnerProvider);
      app.container.read(autoBackupRunnerProvider);
      await pumpIo(tester);
      await tester.pump(const Duration(minutes: 16));
      await pumpIo(tester);
      expect(h.filesStartingWith('turnly-'), isEmpty);
      await tester.tap(key('onboarding-restore'));
      await pumpIo(tester, until: key('backup-status'));
      await pumpIo(tester, until: find.byType(BackupCopyList));
      final copies = app.container.read(backupCopiesProvider).requireValue;
      expect(copies, isNotEmpty);
      expect(copies.every((c) => h.files.contains(c.id)), isTrue);
      expect(find.byKey(const ValueKey('backup-copies-empty')), findsNothing);
      expect(find.textContaining('Antes de empezar de cero'), findsWidgets);
      await app.back();
      final onboarding = app.container.read(
        onboardingControllerProvider.notifier,
      );
      onboarding.choosePaint();
      unawaited(onboarding.finish());
      await pumpIo(
        tester,
        until: find.byWidgetPredicate(
          (w) =>
              w is OnboardingScreen &&
              app.container.read(onboardingControllerProvider).stage ==
                  OnboardingStage.ready,
        ),
      );
      expect(
        app.container.read(onboardingControllerProvider).saveFailed,
        isFalse,
      );
      expect(app.container.read(autoBackupReadyProvider).value, isTrue);
      expect(app.container.read(autoBackupRunnerProvider).enabled, isTrue);
      await tester.pump(const Duration(seconds: 11));
      await pumpIo(
        tester,
        until: find.byWidgetPredicate(
          (w) =>
              w is OnboardingScreen &&
              h.filesStartingWith('turnly-').isNotEmpty &&
              !app.container.read(autoBackupRunnerProvider).status.running,
        ),
      );
      expect(h.filesStartingWith('turnly-'), hasLength(1));
      await app.container.read(autoBackupRunnerProvider).pause();
    },
  );

  testWidgets('failed mandatory backup blocks deletion and offers retry', (
    tester,
  ) async {
    final h = BackupUiHarness(tester);
    final app = await open(
      tester,
      h,
      extra: [
        resetBackupProvider.overrideWithValue(
          () async => throw const FileSystemException('disk full'),
        ),
      ],
    );
    expect(find.textContaining('No se ha borrado nada'), findsOneWidget);
    expect(tester.widget<FilledButton>(key('reset-delete')).onPressed, isNull);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(app.schedule.schedule.entries, isNotEmpty);
    expect(h.files, isEmpty);
  });
  testWidgets(
    'post-database failure reaches first use with warning and original data copy',
    (tester) async {
      final h = BackupUiHarness(tester);
      final app = await open(tester, h);
      app.container
          .read(resetEverythingProvider)
          .cleanup
          .insert(
            0,
            ResetCleanup(
              ResetCleanupStep.calendar,
              () async => throw StateError('private'),
            ),
          );
      await tapIo(tester, key('reset-delete'), until: find.byType(AlertDialog));
      await tester.tap(key('confirm-ok'));
      await pumpIo(tester, until: find.byType(OnboardingScreen));
      expect(
        find.text(
          'Algunos eventos del calendario del móvil no se han podido quitar.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('No se ha podido completar el borrado'),
        findsNothing,
      );
      expect(app.schedule.schedule.entries, isEmpty);
      final tools = await app.real(
        () => app.container.read(backupToolsProvider.future),
      );
      final copies = await app.real(tools.copies);
      expect(copies.every((c) => c.kind == BackupCopyKind.safety), isTrue);
      for (final c in copies) {
        final bytes = await app.real(() => tools.read(c));
        expect(const BackupCodec().decode(bytes).data.dayEntries, isNotEmpty);
      }
    },
  );

  testWidgets(
    'database failure keeps data, touches no system cleanup and stays on reset',
    (tester) async {
      final h = BackupUiHarness(tester);
      final scheduler = FakeAlarmScheduler();
      final app = await open(
        tester,
        h,
        extra: [alarmSchedulerProvider.overrideWithValue(scheduler)],
      );
      await app.real(
        () => app.database.customStatement(
          "CREATE TRIGGER fail_reset BEFORE DELETE ON day_entries BEGIN SELECT RAISE(ABORT, 'test'); END",
        ),
      );
      var cleanupCalls = 0;
      app.container
          .read(resetEverythingProvider)
          .cleanup
          .insert(
            0,
            ResetCleanup(ResetCleanupStep.calendar, () async {
              cleanupCalls++;
            }),
          );
      await tapIo(tester, key('reset-delete'), until: find.byType(AlertDialog));
      await tester.tap(key('confirm-ok'));
      await pumpIo(tester, until: key('reset-error'));
      expect(find.byType(ResetScreen), findsOneWidget);
      expect(
        find.textContaining('No se ha podido completar el borrado'),
        findsOneWidget,
      );
      expect(app.schedule.schedule.entries, isNotEmpty);
      expect(cleanupCalls, 0);
      expect(scheduler.cancelAllCalls, 0);
    },
  );

  testWidgets(
    'double tap starts once; deletion absorbs interaction and blocks back',
    (tester) async {
      final h = BackupUiHarness(tester);
      final app = await open(tester, h);
      final gate = Completer<void>();
      var calls = 0;
      app.container
          .read(resetEverythingProvider)
          .cleanup
          .insert(
            0,
            ResetCleanup(ResetCleanupStep.calendar, () async {
              calls++;
              await gate.future;
            }),
          );
      final press = tester.widget<FilledButton>(key('reset-delete')).onPressed!;
      press();
      press();
      await pumpIo(tester, until: find.byType(AlertDialog));
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(key('confirm-ok'));
      await pumpIo(tester, until: find.text('Borrando…'));
      expect(calls, 1);
      expect(
        tester.widget<AbsorbPointer>(key('reset-barrier')).absorbing,
        isTrue,
      );
      expect(
        tester.widget<FilledButton>(key('reset-delete')).onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(ResetScreen), findsOneWidget);
      gate.complete();
      await pumpIo(tester, until: find.byType(OnboardingScreen));
      expect(calls, 1);
    },
  );

  testWidgets('back is allowed while saving the initial copy', (tester) async {
    final h = BackupUiHarness(tester);
    final gate = Completer<BackupEntry>();
    final app = await AppUnderTest.pump(
      tester,
      size: const Size(390, 2200),
      overrides: [
        ...h.overrides,
        resetBackupProvider.overrideWithValue(() => gate.future),
      ],
    );
    await app.openSettings();
    await tester.ensureVisible(key('settings-reset'));
    await tester.tap(key('settings-reset'));
    await tester.pump();
    expect(find.text('Guardando la copia…'), findsOneWidget);
    expect(
      tester.widget<AbsorbPointer>(key('reset-barrier')).absorbing,
      isFalse,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ResetScreen), findsNothing);
    gate.complete(
      BackupEntry(
        id: 'unused.turnly',
        modifiedAt: DateTime(2026),
        sizeBytes: 1,
      ),
    );
    await pumpIo(tester);
  });

  testWidgets(
    'reset stops folder backup without deleting SAF documents; clears export caches and revokes link',
    (tester) async {
      final h = BackupUiHarness(tester);
      final folder = FakeFolderPlatform()
        ..addFile('existing.turnly')
        ..addFile('personal.txt');
      final stateFile = File('${h.root.path}/folder-state.json');
      final scheduling = FakeFolderScheduling();
      final api = _ResetShareApi();
      await tester.runAsync(() async {
        await FolderBackupStateStore(stateFile)
            .save(FolderBackupState(uri: folder.uri, name: folder.name));
        await Directory('${h.root.path}/ics-export').create();
        await File('${h.root.path}/ics-export/shifts.ics')
            .writeAsString('private');
        await File('${h.root.path}/cuadrante-2026.png').writeAsBytes([1]);
      });
      final app = await open(
        tester,
        h,
        extra: [
          folderBackupSupportedProvider.overrideWithValue(true),
          folderBackupPlatformProvider.overrideWithValue(folder),
          folderBackupSchedulerProvider.overrideWithValue(scheduling),
          folderBackupStateFileProvider.overrideWith((ref) async => stateFile),
          folderBackupRunLockProvider.overrideWithValue(
            const NoFolderRunLock(),
          ),
          shareLinkApiProvider.overrideWithValue(api),
        ],
      );
      final token = ShareToken.generate();
      await app.real(
        () => app.container
            .read(shareLinkRepositoryProvider)
            .saveNewLink(token, 'main'),
      );
      await app.real(
        () => app.container
            .read(shareLinkControllerProvider.notifier)
            .load(force: true),
      );
      api.beforeRevoke = () async {
        expect(
          await app.database.select(app.database.dayEntries).get(),
          isEmpty,
        );
      };
      await tapIo(tester, key('reset-delete'), until: find.byType(AlertDialog));
      await tester.tap(key('confirm-ok'));
      await pumpIo(tester, until: find.byType(OnboardingScreen));
      expect(api.revoked, [token]);
      expect(folder.names, ['existing.turnly', 'personal.txt']);
      expect(folder.released, [folder.uri]);
      expect(scheduling.calls.last, isFalse);
      expect(
        (await app.real(() => FolderBackupStateStore(stateFile).load())).uri,
        isNull,
      );
      expect(
        await app.real(() => Directory('${h.root.path}/ics-export').exists()),
        isFalse,
      );
      expect(
        await app.real(
          () => File('${h.root.path}/cuadrante-2026.png').exists(),
        ),
        isFalse,
      );
    },
  );
  testWidgets(
    'offline revocation is reported without secrets and does not block first use',
    (tester) async {
      final h = BackupUiHarness(tester);
      final api = _ResetShareApi()..offline = true;
      final reporter = RecordingCrashReporter();
      final app = await open(
        tester,
        h,
        extra: [
          shareLinkApiProvider.overrideWithValue(api),
          crashReporterProvider.overrideWithValue(reporter),
        ],
      );
      final token = ShareToken.generate();
      await app.real(
        () => app.container
            .read(shareLinkRepositoryProvider)
            .saveNewLink(token, 'main'),
      );
      await app.real(
        () => app.container
            .read(shareLinkControllerProvider.notifier)
            .load(force: true),
      );
      final before = reporter.errors.length;
      await tapIo(tester, key('reset-delete'), until: find.byType(AlertDialog));
      await tester.tap(key('confirm-ok'));
      await pumpIo(tester, until: find.byType(OnboardingScreen));
      expect(api.revoked, [token]);
      expect(app.schedule.schedule.entries, isEmpty);
      expect(key('reset-cleanup-warning'), findsOneWidget);
      final errors = reporter.errors.skip(before).toList();
      expect(errors, isNotEmpty);
      expect(errors.every((e) => e is RedactedError), isTrue);
      expect(
        errors.map((e) => e.toString()).join(),
        isNot(contains(token.value)),
      );
    },
  );

  testWidgets('reset waits for the real schedule write queue before copying', (
    tester,
  ) async {
    final h = BackupUiHarness(tester);
    final app = await open(tester, h);
    // A missing prepared copy requires a fresh export after draining writes.
    final tools = await app.real(
      () => app.container.read(backupToolsProvider.future),
    );
    final prepared = await app.real(() => tools.preResetStore.latest());
    await app.real(() => tools.preResetStore.delete(prepared!));
    final gate = Completer<void>();
    final reached = Completer<void>();
    final schedule = app.container.read(scheduleControllerProvider.notifier);
    final queued = schedule.runExclusive(() async {
      reached.complete();
      await gate.future;
      await app.database.customStatement(
        "UPDATE day_entries SET note = 'queued before reset'",
      );
    });
    await pumpIo(tester);
    expect(reached.isCompleted, isTrue);
    await tester.tap(key('reset-delete'));
    await tester.pump();
    expect(find.byType(AlertDialog), findsNothing);
    expect(h.filesStartingWith('pre-reset-'), isEmpty);
    gate.complete();
    await pumpIo(tester, until: find.byType(AlertDialog));
    await queued;
    final latest = await app.real(() => tools.preResetStore.latest());
    final bytes = await app.real(() => tools.preResetStore.read(latest!));
    expect(
      const BackupCodec()
          .decode(bytes)
          .data
          .dayEntries
          .every((e) => e.note == 'queued before reset'),
      isTrue,
    );
    await tester.tap(key('confirm-cancel'));
    await pumpIo(tester);
    expect(app.schedule.schedule.entries, isNotEmpty);
  });
  testWidgets(
    'a silently retained file is reported while other cleanup finishes',
    (tester) async {
      final h = BackupUiHarness(tester);
      final background = _UnsweptBackground(
        Directory('${h.root.path}/background'),
      );
      await tester.runAsync(() async {
        await background.root.create();
        await File('${background.root.path}/photo.png').writeAsBytes([1]);
      });
      final reporter = RecordingCrashReporter();
      final app = await open(
        tester,
        h,
        backgroundStore: background,
        extra: [crashReporterProvider.overrideWithValue(reporter)],
      );
      await tapIo(tester, key('reset-delete'), until: find.byType(AlertDialog));
      await tester.tap(key('confirm-ok'));
      await pumpIo(tester, until: find.byType(OnboardingScreen));
      expect(key('reset-cleanup-warning'), findsOneWidget);
      expect(app.schedule.schedule.entries, isEmpty);
      expect(
        reporter.errors.whereType<RedactedError>().map((e) => e.type),
        contains('StateError'),
      );
    },
  );
}

class _ResetShareApi implements ShareLinkApi {
  final revoked = <ShareToken>[];
  Future<void> Function()? beforeRevoke;
  bool offline = false;
  @override
  Uri feedUrl(ShareToken token) => Uri.parse('https://example.invalid/feed');
  @override
  Future<void> publish(ShareToken token, String ics) async {}
  @override
  Future<void> revoke(ShareToken token) async {
    await beforeRevoke?.call();
    revoked.add(token);
    if (offline) throw const ShareLinkException(ShareLinkFailure.network);
  }
}

class _UnsweptBackground extends CalendarBackgroundStore {
  _UnsweptBackground(super.root);
  @override
  Future<void> sweep(String? keep) async {}
}
