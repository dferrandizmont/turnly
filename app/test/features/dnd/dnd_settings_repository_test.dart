import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/features/dnd/data/dnd_settings_repository.dart';
import 'package:cuadrante/features/dnd/domain/dnd_settings.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_storage.dart';

void main() {
  late AppDatabase db;
  late DndSettingsRepository repository;

  setUp(() {
    db = openMemoryDatabase();
    repository = DndSettingsRepository(db);
  });
  tearDown(() => db.close());

  test('nothing stored: everything off', () async {
    final settings = await repository.load();
    expect(settings, DndSettings.disabled);
    expect(settings.enabled, isFalse);
    expect(settings.anyActive, isFalse);
  });

  test('round trip', () async {
    const settings = DndSettings(
      enabled: true,
      filter: DndFilter.none,
      byShiftType: {
        'night': DndTypeSettings(enabled: true),
        'morning': DndTypeSettings(enabled: false),
      },
    );
    await repository.save(settings);
    expect(await repository.load(), settings);
  });

  test('saving again replaces the row', () async {
    await repository.save(const DndSettings(enabled: true));
    await repository.save(const DndSettings(filter: DndFilter.alarms));
    final loaded = await repository.load();
    expect(loaded.enabled, isFalse);
    expect(loaded.filter, DndFilter.alarms);
    expect(await db.select(db.settings).get(), hasLength(1));
  });

  test('a corrupt value reads as the defaults instead of throwing', () async {
    await db.into(db.settings).insert(
      SettingsCompanion(
        key: const Value(dndSettingsKey),
        value: const Value('{not json'),
      ),
    );
    expect(await repository.load(), DndSettings.disabled);

    await db.into(db.settings).insertOnConflictUpdate(
      SettingsCompanion(
        key: const Value(dndSettingsKey),
        value: const Value('[1, 2]'),
      ),
    );
    expect(await repository.load(), DndSettings.disabled);
  });

  test('the row is a normal setting: it travels in the copy', () async {
    await repository.save(const DndSettings(enabled: true));
    final rows = await db.select(db.settings).get();
    expect(rows, hasLength(1));
    expect(rows.single.key, dndSettingsKey);
    expect(rows.single.value, contains('"enabled":true'));
  });
}
