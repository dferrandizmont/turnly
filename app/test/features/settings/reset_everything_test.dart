import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cuadrante/features/backup/application/backup_service.dart';
import 'package:cuadrante/features/backup/data/backup_repository.dart';
import 'package:cuadrante/features/backup/data/local_file_backup_store.dart';
import 'package:cuadrante/features/backup/domain/backup_codec.dart';
import 'package:cuadrante/features/backup/domain/backup_store.dart';
import 'package:cuadrante/features/backup/domain/canonical_json.dart';
import 'package:cuadrante/features/notes/data/attachment_store.dart';
import 'package:cuadrante/features/notes/data/note_attachments_repository.dart';
import 'package:cuadrante/features/notes/domain/note_attachment.dart';
import 'package:cuadrante/features/onboarding/data/onboarding_repository.dart';
import 'package:cuadrante/features/schedule/domain/civil_date.dart';
import 'package:cuadrante/features/settings/application/reset_everything.dart';
import 'package:cuadrante/features/settings/data/preferences_repository.dart';
import 'package:cuadrante/features/settings/data/reset_repository.dart';
import 'package:cuadrante/features/settings/domain/preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_storage.dart';

final _now = DateTime(2026, 11, 4, 12);
final _copy = BackupEntry(id: 'before.turnly', modifiedAt: _now, sizeBytes: 1);

void main() {
  ResetEverything operation(
    List<String> calls, {
    bool failBackup = false,
    bool failFiles = false,
    bool failDatabase = false,
    bool failReload = false,
  }) {
    Future<void> step(String name) async => calls.add(name);
    return ResetEverything(
      runExclusive: (action) => action(),
      createBackup: () async {
        calls.add('backup');
        if (failBackup) throw const FileSystemException('disk full');
        return _copy;
      },
      pause: () => step('pause'),
      resume: () => calls.add('resume'),
      clearDatabase: () async {
        await step('database');
        if (failDatabase) throw StateError('database');
      },
      cleanup: [
        for (final name in ['calendar', 'alarms', 'dnd', 'widget'])
          ResetCleanup(ResetCleanupStep.values.byName(name), () => step(name)),
        ResetCleanup(ResetCleanupStep.attachments, () async {
          await step('files');
          if (failFiles) throw StateError('file cleanup failed');
        }),
        ResetCleanup(ResetCleanupStep.folderBackup, () => step('folder')),
      ],
      onError: (_, _) => calls.add('reported'),
      reload: () async {
        await step('reload');
        if (failReload) throw StateError('reload');
      },
    );
  }

  test(
    'backup precedes confirmation and every destructive dependency',
    () async {
      final calls = <String>[];
      expect(
        await operation(calls).resetEverything(
          confirm: (copy) async {
            expect(copy, _copy);
            calls.add('confirm');
            return true;
          },
        ),
        isTrue,
      );
      expect(calls, [
        'pause',
        'backup',
        'confirm',
        'database',
        'calendar',
        'alarms',
        'dnd',
        'widget',
        'files',
        'folder',
        'reload',
        'resume',
      ]);
    },
  );

  test(
    'failed backup does not confirm or delete anything and resumes',
    () async {
      final calls = <String>[];
      await expectLater(
        operation(calls, failBackup: true).resetEverything(
          confirm: (_) async {
            fail('must not confirm');
          },
        ),
        throwsA(isA<ResetBackupFailure>()),
      );
      expect(calls, ['pause', 'backup', 'resume']);
    },
  );

  test('database failure does not touch system or files', () async {
    final calls = <String>[];
    await expectLater(
      operation(
        calls,
        failDatabase: true,
      ).resetEverything(confirm: (_) async => true),
      throwsStateError,
    );
    expect(calls, ['pause', 'backup', 'database', 'resume']);
  });

  test(
    'post-database failures report and finish every remaining step',
    () async {
      final calls = <String>[];
      final reset = operation(calls, failFiles: true, failReload: true);
      expect(await reset.resetEverything(confirm: (_) async => true), isTrue);
      expect(calls.sublist(calls.indexOf('files')), [
        'files',
        'reported',
        'folder',
        'reload',
        'reported',
        'resume',
      ]);
      expect(reset.cleanupFailures, {
        ResetCleanupStep.attachments,
        ResetCleanupStep.reload,
      });
    },
  );

  test(
    'each cleanup failure is independent, even if reporting fails',
    () async {
      final calls = <String>[];
      final reset = ResetEverything(
        runExclusive: (action) => action(),
        createBackup: () async => _copy,
        pause: () async {},
        resume: () => calls.add('resume'),
        clearDatabase: () async => calls.add('database'),
        cleanup: [
          for (final step in ResetCleanupStep.values)
            ResetCleanup(step, () async {
              calls.add(step.name);
              throw StateError('private');
            }),
        ],
        reload: () async => calls.add('reload'),
        onError: (_, _) => throw StateError('reporter'),
      );
      expect(await reset.resetEverything(confirm: (_) async => true), isTrue);
      expect(reset.cleanupFailures, ResetCleanupStep.values.toSet());
      expect(calls, [
        'database',
        ...ResetCleanupStep.values.map((s) => s.name),
        'reload',
        'resume',
      ]);
    },
  );

  test(
    'reentry cannot pause, back up, confirm or resume a second time',
    () async {
      final calls = <String>[];
      final confirmation = Completer<bool>();
      final reached = Completer<void>();
      final reset = operation(calls);
      final first = reset.resetEverything(
        confirm: (_) {
          reached.complete();
          return confirmation.future;
        },
      );
      await reached.future;
      expect(await reset.resetEverything(confirm: (_) async => true), isFalse);
      expect(calls, ['pause', 'backup']);
      confirmation.complete(true);
      expect(await first, isTrue);
      expect(calls.where((c) => c == 'database'), hasLength(1));
      expect(calls.where((c) => c == 'resume'), hasLength(1));
    },
  );

  test('dismissing confirmation keeps data and the saved copy', () async {
    final calls = <String>[];
    expect(
      await operation(calls).resetEverything(confirm: (_) async => false),
      isFalse,
    );
    expect(calls, ['pause', 'backup', 'resume']);
  });

  for (final readable in [true, false]) {
    test(
      'prepared copy readable=$readable: reuses or replaces before confirming',
      () async {
        var created = 0;
        var deleted = false;
        final fresh = BackupEntry(
          id: 'fresh.turnly',
          modifiedAt: _now,
          sizeBytes: 1,
        );
        final reset = ResetEverything(
          runExclusive: (action) => action(),
          createBackup: () async {
            created++;
            return fresh;
          },
          verifyBackup: (copy) async {
            expect(copy, _copy);
            if (!readable) throw const FormatException('corrupt');
          },
          pause: () async {},
          resume: () {},
          clearDatabase: () async {
            deleted = true;
          },
          cleanup: [],
          reload: () async {},
        );
        expect(
          await reset.resetEverything(
            preparedBackup: _copy,
            confirm: (copy) async {
              expect(deleted, isFalse);
              expect(copy, readable ? _copy : fresh);
              return true;
            },
          ),
          isTrue,
        );
        expect(created, readable ? 0 : 1);
      },
    );
  }

  test('lost prepared copy and failed replacement never delete data', () async {
    var deleted = false;
    final reset = ResetEverything(
      runExclusive: (action) => action(),
      createBackup: () async => throw const FileSystemException('disk full'),
      verifyBackup: (_) async => throw const FileSystemException('missing'),
      pause: () async {},
      resume: () {},
      clearDatabase: () async {
        deleted = true;
      },
      cleanup: [],
      reload: () async {},
    );
    await expectLater(
      reset.resetEverything(
        preparedBackup: _copy,
        confirm: (_) async => fail('no verified copy'),
      ),
      throwsA(isA<ResetBackupFailure>()),
    );
    expect(deleted, isFalse);
  });

  test(
    'real database becomes a fresh installation; language and backup survive',
    () async {
      final storage = await TestStorage.open(now: _now);
      addTearDown(storage.close);
      final db = storage.database;
      final root = makeTempDir('reset');
      final attachments = AttachmentStore(
        Directory('${root.path}/attachments'),
      );
      final bytes = Uint8List.fromList([1, 2, 3]);
      final path = await attachments.put(bytes);
      await NoteAttachmentsRepository(db).save(
        NoteAttachment(
          id: 'photo',
          calendarId: 'main',
          date: const CivilDate(2026, 11, 4),
          kind: AttachmentKind.photo,
          relativePath: path,
          mimeType: 'image/jpeg',
          sizeBytes: bytes.length,
          sha256: sha256Hex(bytes),
          createdAt: 1,
        ),
      );
      final preferences = PreferencesRepository(db);
      await preferences.setLanguage(AppLanguage.ca);
      await preferences.setThemeMode(ThemeMode.dark);
      await preferences.setCurrency('USD');
      await OnboardingRepository(db).markDone(tip: true);
      await db.customStatement(
        "INSERT INTO day_tasks (id, calendar_id, date, title, created_at, updated_at) VALUES ('task', 'main', '2026-11-04', 'Task', 1, 1)",
      );
      await db.customStatement(
        "INSERT INTO shift_swaps (id, calendar_id, date, colleague, direction, created_at, updated_at) VALUES ('swap', 'main', '2026-11-04', 'Someone', 'theyOwe', 1, 1)",
      );
      await db.customStatement(
        "INSERT INTO absence_balances (year, type, allowed_days) VALUES (2026, 'vacation', 22)",
      );
      final store = LocalFileBackupStore(
        Directory('${root.path}/backups'),
        pruneOnSave: false,
      );
      final service = BackupService(
        repository: BackupRepository(
          db,
          safetyDirectory: store.directory,
          appVersion: 'test',
          now: () => _now,
          loadAttachmentStore: () async => attachments,
          runner: runOnThisIsolate,
        ),
        store: store,
        appVersion: 'test',
        now: () => _now,
        runner: runOnThisIsolate,
      );
      final calls = <String>[];
      final base = operation(calls);
      late BackupEntry saved;
      final reset = ResetEverything(
        runExclusive: base.runExclusive,
        createBackup: () async {
          saved = await store.save(await service.exportBytes(), at: _now);
          await service.decodeFile(await store.read(saved));
          return saved;
        },
        pause: base.pause,
        resume: base.resume,
        clearDatabase: ResetRepository(db, now: () => _now).clear,
        cleanup: [
          ResetCleanup(
            ResetCleanupStep.attachments,
            () => attachments.sweep({}),
          ),
        ],
        reload: base.reload,
      );
      await reset.resetEverything(confirm: (_) async => true);
      for (final table in db.allTables.where(
        (t) => !{
          'calendars',
          'shift_types',
          'patterns',
          'settings',
          'overtime_types',
        }.contains(t.actualTableName),
      )) {
        expect(
          await db.select(table).get(),
          isEmpty,
          reason: table.actualTableName,
        );
      }
      expect((await db.select(db.calendars).get()).single.id, 'main');
      expect(await db.select(db.shiftTypes).get(), isNotEmpty);
      expect(await db.select(db.patterns).get(), isNotEmpty);
      // The two built-in overtime types, as in a new installation.
      expect(
        (await db.select(db.overtimeTypes).get()).map((t) => t.id).toSet(),
        {'overtime', 'other-work'},
      );
      final remaining = await preferences.load();
      expect(remaining.language, AppLanguage.ca);
      expect(remaining.themeMode, Preferences.defaults.themeMode);
      expect(remaining.currency, Preferences.defaults.currency);
      expect(await OnboardingRepository(db).isDone(), isFalse);
      expect(await OnboardingRepository(db).hasUserData(), isFalse);
      expect(
        (await OnboardingRepository(
          db,
        ).resolve(demo: false, force: false)).needed,
        isTrue,
      );
      expect(await attachments.exists(path), isFalse);
      expect(
        await File('${store.directory.path}/${saved.id}').exists(),
        isTrue,
      );
      final restored = const BackupCodec().decode(await store.read(saved));
      expect(restored.data.dayEntries, isNotEmpty);
      expect(restored.data.dayTasks.single.title, 'Task');
      expect(restored.data.shiftSwaps, hasLength(1));
      expect(restored.data.absenceBalances, hasLength(1));
      expect(restored.attachmentFiles['photo'], bytes);
      expect((await store.list()).single, saved);
    },
  );
}
