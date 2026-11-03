import 'dart:io';

import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/features/backup/data/backup_repository.dart';
import 'package:cuadrante/features/dnd/data/dnd_settings_repository.dart';
import 'package:cuadrante/features/dnd/domain/dnd_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../backup/backup_test_support.dart';

void main() {
  late Directory dir;
  late AppDatabase db;
  late DndSettingsRepository settings;
  late BackupRepository repository;

  const stored = DndSettings(
    enabled: true,
    filter: DndFilter.none,
    byShiftType: {
      'night': DndTypeSettings(enabled: true),
      'morning': DndTypeSettings(enabled: false),
    },
  );

  setUp(() {
    dir = makeTempDir('dnd-backup');
    db = openMemoryDatabase();
    settings = DndSettingsRepository(db);
    repository = makeRepository(db, Directory(p.join(dir.path, 'backups')));
  });
  tearDown(() => db.close());

  test('the settings travel in the copy and come back on a restore', () async {
    await settings.save(stored);

    // The export carries them: the key is a normal setting.
    final data = await repository.readAll();
    expect(data.settings.containsKey(dndSettingsKey), isTrue);

    // The restore brings them back (into a fresh database).
    final other = openMemoryDatabase();
    addTearDown(other.close);
    await makeRepository(
      other,
      Directory(p.join(dir.path, 'other')),
    ).restore(data);

    expect(await DndSettingsRepository(other).load(), stored);
  });

  test('the copy of a phone without them restores them as off', () async {
    // Nothing stored: the copy carries no silence settings.
    final data = await repository.readAll();
    expect(data.settings.containsKey(dndSettingsKey), isFalse);

    final other = openMemoryDatabase();
    addTearDown(other.close);
    await makeRepository(
      other,
      Directory(p.join(dir.path, 'other')),
    ).restore(data);

    expect(await DndSettingsRepository(other).load(), DndSettings.disabled);
  });

  test('a restore of a file with them leaves the phone with them', () async {
    await settings.save(stored);
    final data = await repository.readAll();
    // The phone's own settings are replaced by the file's.
    await repository.restore(data);
    expect(await settings.load(), stored);
  });
}
