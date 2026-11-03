import 'dart:io';

import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/features/alarms/data/alarm_foreground_relay.dart';
import 'package:cuadrante/features/backup/application/folder_backup_engine.dart';
import 'package:cuadrante/features/backup/application/folder_backup_providers.dart';
import 'package:cuadrante/features/backup/data/folder_backup_state_store.dart';
import 'package:cuadrante/features/backup/domain/folder_backup.dart';
import 'package:cuadrante/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../support/test_storage.dart';
import 'backup_ui_support.dart';
import 'folder_backup_support.dart';

// P10: the block «Copia automática en una carpeta» on the backup screen.

final _l10n = lookupAppLocalizations(const Locale('es'));

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeLocale();
  });

  late FakeFolderPlatform folder;
  late FakeFolderScheduling scheduler;
  late File stateFile;

  setUp(() {
    folder = FakeFolderPlatform();
    scheduler = FakeFolderScheduling();
    stateFile = File(
      p.join(makeTempDir('folder-ui').path, folderBackupStateFileName),
    );
  });

  List<Override> overrides() => [
    folderBackupSupportedProvider.overrideWithValue(true),
    folderBackupPlatformProvider.overrideWithValue(folder),
    folderBackupSchedulerProvider.overrideWithValue(scheduler),
    folderBackupStateFileProvider.overrideWith((ref) async => stateFile),
    folderBackupRunLockProvider.overrideWithValue(const NoFolderRunLock()),
    folderBackupRelayProvider.overrideWithValue(
      AlarmForegroundRelay(portName: 'test/folder-backup-ui'),
    ),
  ];

  // Real file I/O: outside the fake time of widget tests, or it never ends.
  Future<void> saveState(WidgetTester tester, FolderBackupState state) async {
    await tester.runAsync(() => FolderBackupStateStore(stateFile).save(state));
  }

  Finder key(String k) => find.byKey(ValueKey(k));

  Future<void> open(WidgetTester tester, {bool supported = true}) async {
    final h = BackupUiHarness(tester);
    await h.open(extraOverrides: supported ? overrides() : const []);
    if (supported) await pumpIo(tester, until: key('folder-backup'));
  }

  testWidgets('not shown where there is no folder copy (iOS for now)', (
    tester,
  ) async {
    await open(tester, supported: false);
    expect(key('folder-backup'), findsNothing);
  });

  testWidgets('no folder yet: what it does, what it carries, choose', (
    tester,
  ) async {
    await open(tester);
    expect(
      find.text(_l10n.autoBackupFolderTitle.toUpperCase()),
      findsOneWidget,
    );
    expect(find.text(_l10n.autoBackupFolderIntro), findsOneWidget);
    expect(find.text(_l10n.autoBackupFolderPrivacy), findsOneWidget);
    expect(key('folder-backup-choose'), findsOneWidget);
    expect(key('folder-backup-problem'), findsNothing);
    expect(
      scheduler.calls,
      isEmpty,
      reason: 'nothing registered without a folder',
    );
  });

  testWidgets('choosing a folder makes a first copy and shows it', (
    tester,
  ) async {
    await open(tester);
    await tapIo(
      tester,
      key('folder-backup-choose'),
      until: key('folder-backup-folder'),
    );
    await pumpIo(tester, until: find.text(_l10n.autoBackupFolderCopyDone));
    expect(folder.picks, 1);
    expect(folder.names.single, startsWith('turnly-auto-20261019-12'));
    expect(scheduler.calls, [true]);
    expect(find.text('Copias'), findsOneWidget);
    expect(
      find.textContaining('Última copia en la carpeta: hoy a las'),
      findsOneWidget,
    );
    expect(key('folder-backup-verify'), findsOneWidget);
  });

  testWidgets('going back from the picker changes nothing', (tester) async {
    folder.pickChoosesFolder = false;
    await open(tester);
    await tapIo(tester, key('folder-backup-choose'));
    expect(key('folder-backup-choose'), findsOneWidget);
    expect(folder.writes, 0);
    expect(scheduler.calls, isEmpty);
  });

  testWidgets('a picker that fails says so', (tester) async {
    folder.pickFails = FolderProblem.revoked;
    await open(tester);
    await tapIo(
      tester,
      key('folder-backup-choose'),
      until: find.text(_l10n.autoBackupFolderPickFailed),
    );
    expect(key('folder-backup-choose'), findsOneWidget);
  });

  testWidgets('a revoked permission is a clear warning with the fix', (
    tester,
  ) async {
    await saveState(
      tester,
      const FolderBackupState().withFolder(folder.uri, 'Copias'),
    );
    folder.revoked = true;
    await open(tester);
    await pumpIo(tester, until: key('folder-backup-problem'));
    expect(
      find.textContaining(_l10n.autoBackupFolderErrRevoked),
      findsOneWidget,
    );
    expect(find.text(_l10n.autoBackupFolderChooseAgain), findsOneWidget);
    expect(scheduler.calls, [true], reason: 'registered again at start');

    await tapIo(tester, key('folder-backup-problem-action'));
    await pumpIo(tester, until: find.text(_l10n.autoBackupFolderCopyDone));
    expect(key('folder-backup-problem'), findsNothing);
    expect(folder.names, hasLength(1));
  });

  testWidgets('a damaged record is a warning, never a silent "no folder"', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await stateFile.parent.create(recursive: true);
      await stateFile.writeAsString('{"uri": "content://x", trunc');
    });
    await open(tester);
    await pumpIo(tester, until: key('folder-backup-problem'));
    expect(
      find.textContaining(_l10n.autoBackupFolderErrDamaged),
      findsOneWidget,
    );
    expect(key('folder-backup-choose'), findsOneWidget);

    await tapIo(tester, key('folder-backup-problem-action'));
    await pumpIo(tester, until: find.text(_l10n.autoBackupFolderCopyDone));
    expect(key('folder-backup-problem'), findsNothing);
    expect(key('folder-backup-folder'), findsOneWidget);
  });

  testWidgets('a deleted folder says so', (tester) async {
    await saveState(
      tester,
      const FolderBackupState().withFolder(folder.uri, 'Copias'),
    );
    folder.deleted = true;
    await open(tester);
    await pumpIo(tester, until: key('folder-backup-problem'));
    expect(
      find.textContaining(_l10n.autoBackupFolderErrMissing),
      findsOneWidget,
    );
  });

  testWidgets('a background failure (no space) shows with "Reintentar"', (
    tester,
  ) async {
    await saveState(
      tester,
      const FolderBackupState()
          .withFolder(folder.uri, 'Copias')
          .failed(DateTime(2026, 10, 19, 3), FolderProblem.noSpace),
    );
    await open(tester);
    await pumpIo(tester, until: key('folder-backup-problem'));
    expect(
      find.textContaining(_l10n.autoBackupFolderErrNoSpace),
      findsOneWidget,
    );
    expect(find.textContaining('Último intento: hoy a las'), findsOneWidget);
    expect(find.text(_l10n.backupUiRetry), findsWidgets);

    await tapIo(tester, key('folder-backup-problem-action'));
    await pumpIo(tester, until: find.text(_l10n.autoBackupFolderCopyDone));
    expect(key('folder-backup-problem'), findsNothing);
  });

  testWidgets('"Copiar ahora" when the folder is full keeps the warning', (
    tester,
  ) async {
    await saveState(
      tester,
      const FolderBackupState().withFolder(folder.uri, 'Copias'),
    );
    folder.writeFails = FolderProblem.noSpace;
    await open(tester);
    await tapIo(
      tester,
      key('folder-backup-now'),
      until: key('folder-backup-problem'),
    );
    expect(find.textContaining(_l10n.autoBackupFolderErrNoSpace), findsWidgets);
    expect(folder.names, isEmpty);
  });

  testWidgets('testing the copy in the folder rebuilds it', (tester) async {
    await open(tester);
    await tapIo(
      tester,
      key('folder-backup-choose'),
      until: key('folder-backup-verify'),
    );
    await tapIo(
      tester,
      key('folder-backup-verify'),
      until: key('folder-backup-verify-result'),
    );
    expect(find.textContaining('La copia está completa'), findsOneWidget);
  });

  testWidgets('a foreign file in the folder is rejected by the test', (
    tester,
  ) async {
    final id = folder.addFile('turnly-auto-20261019-110000.turnly', [
      1,
      2,
      3,
      4,
    ]);
    await saveState(
      tester,
      const FolderBackupState()
          .withFolder(folder.uri, 'Copias')
          .succeeded(
            DateTime(2026, 10, 19, 11),
            FolderFile(
              id: id,
              name: 'turnly-auto-20261019-110000.turnly',
              sizeBytes: 4,
            ),
            'sha256:x',
          ),
    );
    await open(tester);
    await tapIo(
      tester,
      key('folder-backup-verify'),
      until: key('folder-backup-verify-result'),
    );
    expect(
      find.textContaining('No se ha podido probar la copia'),
      findsOneWidget,
    );
  });

  testWidgets('stopping forgets the folder and keeps its copies', (
    tester,
  ) async {
    folder.addFile('turnly-auto-20261018-030000.turnly');
    await saveState(
      tester,
      const FolderBackupState().withFolder(folder.uri, 'Copias'),
    );
    await open(tester);
    await tapIo(
      tester,
      key('folder-backup-stop'),
      until: key('folder-backup-choose'),
    );
    expect(folder.released, [folder.uri]);
    expect(scheduler.calls.last, isFalse);
    expect(folder.names, ['turnly-auto-20261018-030000.turnly']);
    expect(
      (await tester.runAsync(FolderBackupStateStore(stateFile).load))!
          .configured,
      isFalse,
    );
  });
}
