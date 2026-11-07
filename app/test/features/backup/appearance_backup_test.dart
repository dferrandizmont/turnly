import 'dart:io';

import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/features/backup/domain/backup_codec.dart';
import 'package:cuadrante/features/settings/data/preferences_repository.dart';
import 'package:cuadrante/features/settings/domain/preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'backup_test_support.dart';
import 'golden_dataset.dart';

/// Proposal 8 (6-nov-2026): the new accents and the pure-black background
/// travel in the backup like the accent and the theme always did.
void main() {
  late Directory dir;
  late AppDatabase db;

  setUp(() {
    dir = makeTempDir('appearance-backup');
    db = openMemoryDatabase();
  });
  tearDown(() => db.close());

  for (final accent in AppAccent.values) {
    test(
      '${accent.stored}: DB -> file -> fresh DB keeps accent and black',
      () async {
        final preferences = PreferencesRepository(db);
        await preferences.setAccent(accent);
        await preferences.setPureBlack(true);
        await seedDatabase(db, buildGoldenBackupData());
        final repository = makeRepository(db, Directory(p.join(dir.path, 'a')));

        const codec = BackupCodec();
        final bytes = codec.encode(
          await repository.readAll(),
          appVersion: testAppVersion,
          exportedAt: goldenExportedAt,
        );
        final data = codec.decode(bytes).data;
        expect(data.settings['appearance.accent'], '"${accent.stored}"');
        expect(data.settings['appearance.pureBlack'], 'true');

        final other = openMemoryDatabase();
        addTearDown(other.close);
        await makeRepository(
          other,
          Directory(p.join(dir.path, 'b')),
        ).restore(data);
        final restored = await PreferencesRepository(other).load();
        expect(restored.accent, accent);
        expect(restored.pureBlack, isTrue);
      },
    );
  }

  test(
    'a copy from before (no pureBlack, an old accent) restores as off',
    () async {
      await seedDatabase(db, buildGoldenBackupData());
      final repository = makeRepository(db, Directory(p.join(dir.path, 'c')));
      final golden = buildGoldenBackupData();
      expect(golden.settings.containsKey('appearance.pureBlack'), isFalse);
      await repository.restore(golden);
      final restored = await PreferencesRepository(db).load();
      expect(restored.pureBlack, isFalse);
      expect(restored.accent, AppAccent.indigo);
    },
  );
}
