import 'dart:typed_data';

import 'package:cuadrante/core/providers.dart';
import 'package:cuadrante/features/backup/application/backup_models.dart';
import 'package:cuadrante/features/backup/application/backup_actions.dart';
import 'package:cuadrante/features/backup/application/backup_providers.dart';
import 'package:cuadrante/features/backup/application/backup_service.dart';
import 'package:cuadrante/features/backup/data/local_file_backup_store.dart';
import 'package:cuadrante/features/backup/domain/backup_codec.dart';
import 'package:cuadrante/features/backup/domain/backup_retention.dart';
import 'package:cuadrante/features/settings/data/reset_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_storage.dart';
import '../backup/backup_test_support.dart' show makeRepository;

class _BrokenService implements BackupService {
  @override
  Future<Uint8List> exportBytes() async => Uint8List.fromList([1, 2, 3]);
  @override
  Future<BackupFile> decodeFile(Uint8List bytes, {BackupCodec? codec}) async =>
      throw const FormatException('unreadable backup');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('failed decoding removes the broken pre-reset file and keeps earlier copies', () async {
    final dir = makeTempDir('reset-broken');
    final tools = BackupTools(
      directory: dir,
      service: _BrokenService(),
      autoStore: LocalFileBackupStore(dir),
      safetyStore: LocalFileBackupStore(dir, prefix: 'pre-restore'),
    );
    final earlier = await tools.preResetStore.save(
      Uint8List.fromList([42]),
      at: DateTime(2026, 1, 1),
    );
    final container = ProviderContainer(
      overrides: [
        backupToolsProvider.overrideWith((ref) async => tools),
        clockProvider.overrideWithValue(() => DateTime(2026, 11, 4)),
      ],
    );
    addTearDown(container.dispose);
    await expectLater(
      container.read(resetBackupProvider)(),
      throwsFormatException,
    );
    expect(await tools.preResetStore.list(), [earlier]);
  });

  test('actual pre-reset copy survives reset and automatic retention for forty days', () async {
    var now = DateTime(2026, 11, 4);
    final storage = await TestStorage.open(now: now);
    addTearDown(storage.close);
    final dir = makeTempDir('reset-rotation');
    const retention = BackupRetention(newest: 7, dailyForDays: 30);
    final automatic = LocalFileBackupStore(
      dir,
      retain: (entries) => retention.idsToKeep(entries, now: now),
      pruneOnSave: false,
    );
    final tools = BackupTools(
      directory: dir,
      autoStore: automatic,
      safetyStore: LocalFileBackupStore(dir, prefix: 'pre-restore'),
      service: BackupService(
        repository: makeRepository(storage.database, dir, now: () => now),
        store: automatic,
        appVersion: 'test',
        now: () => now,
        runner: runOnThisIsolate,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        backupToolsProvider.overrideWith((ref) async => tools),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    final copy = await container.read(resetBackupProvider)();
    await ResetRepository(storage.database, now: () => now).clear();
    for (var day = 0; day < 40; day++) {
      now = now.add(const Duration(days: 1));
      await tools.backupAndVerify();
    }
    final saved = (await tools.copies()).singleWhere((c) => c.id == copy.id);
    expect(saved.kind, BackupCopyKind.safety);
    expect(
      container.read(backupActionsProvider).requestFor(saved).origin,
      BackupImportOrigin.preResetCopy,
    );
    expect(
      const BackupCodec().decode(await tools.read(saved)).data.dayEntries,
      isNotEmpty,
    );
    expect(await automatic.list(), hasLength(30));
  });
}
