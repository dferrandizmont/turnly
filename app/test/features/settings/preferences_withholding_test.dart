import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/features/settings/data/preferences_repository.dart';
import 'package:cuadrante/features/settings/domain/preferences.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_storage.dart';

// The withholding of the estimated pay (P9, fila 25 de
// `docs/paridad-pago.md`): a new preference of Ajustes.

void main() {
  late AppDatabase db;
  late PreferencesRepository repository;

  setUp(() {
    db = openMemoryDatabase();
    repository = PreferencesRepository(db);
  });
  tearDown(() => db.close());

  Future<void> store(String key, String json) => db
      .into(db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion(key: Value(key), value: Value(json)),
      );

  Future<String?> stored(String key) async {
    final row = await (db.select(
      db.settings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  test('nothing stored: no withholding', () async {
    expect(await repository.load(), Preferences.defaults);
    expect(Preferences.defaults.withholdingPercent, 0);
  });

  test('the withholding makes the round trip', () async {
    await repository.setWithholdingPercent(15);
    expect((await repository.load()).withholdingPercent, 15);
    expect(await stored(PreferenceKeys.withholdingPercent), '15');
    expect(PreferenceKeys.withholdingPercent, 'summary.withholdingPercent');
  });

  test('a percentage outside the range is refused', () async {
    expect(repository.setWithholdingPercent(-1), throwsArgumentError);
    expect(repository.setWithholdingPercent(101), throwsArgumentError);
    expect(isValidWithholdingPercent(0), isTrue);
    expect(isValidWithholdingPercent(100), isTrue);
    expect(isValidWithholdingPercent(101), isFalse);
  });

  test('a value the app does not offer falls back to the default', () async {
    await store(PreferenceKeys.withholdingPercent, '150');
    expect((await repository.load()).withholdingPercent, 0);
    await store(PreferenceKeys.withholdingPercent, '"15"');
    expect((await repository.load()).withholdingPercent, 0);
  });

  test('the preference travels with the other ones', () async {
    final preferences = await repository.load();
    expect(preferences.copyWith(withholdingPercent: 20).withholdingPercent, 20);
    expect(preferences.copyWith().withholdingPercent, 0);
  });
}
