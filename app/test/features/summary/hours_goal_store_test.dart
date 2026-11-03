import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/core/database/database_provider.dart';
import 'package:cuadrante/core/providers.dart';
import 'package:cuadrante/features/schedule/domain/civil_date.dart';
import 'package:cuadrante/features/summary/application/summary_providers.dart';
import 'package:cuadrante/features/summary/data/hours_goal_store.dart';
import 'package:cuadrante/features/summary/domain/hours_goal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_storage.dart';

void main() {
  late AppDatabase db;
  late HoursGoalStore store;

  setUp(() {
    db = openMemoryDatabase();
    store = HoursGoalStore(db);
  });
  tearDown(() => db.close());

  Future<void> write(String json) => db
      .into(db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion(
          key: const Value(HoursGoalStore.key),
          value: Value(json),
        ),
      );

  Future<String?> stored() async {
    final row = await (db.select(
      db.settings,
    )..where((s) => s.key.equals(HoursGoalStore.key))).getSingleOrNull();
    return row?.value;
  }

  test('nothing stored: no goal', () async {
    expect(await store.load(), isNull);
  });

  test('saves, reads and replaces the goal in one settings row', () async {
    await store.save(const HoursGoal(HoursGoalPeriod.year, 1642));
    expect(await store.load(), const HoursGoal(HoursGoalPeriod.year, 1642));
    expect(await stored(), '{"period":"year","hours":1642}');
    await store.save(const HoursGoal(HoursGoalPeriod.month, 140));
    expect(await store.load(), const HoursGoal(HoursGoalPeriod.month, 140));
    expect(await db.select(db.settings).get(), hasLength(1));
  });

  test('clear removes it', () async {
    await store.save(const HoursGoal(HoursGoalPeriod.year, 1642));
    await store.clear();
    expect(await store.load(), isNull);
    expect(await stored(), isNull);
    // Clearing nothing is fine.
    await store.clear();
  });

  test('a bad row is no goal and does not throw', () async {
    for (final bad in [
      'not json',
      '"year"',
      '{"period":"year","hours":0}',
      '{"period":"day","hours":8}',
    ]) {
      await write(bad);
      expect(await store.load(), isNull, reason: bad);
    }
  });

  test('refuses a goal out of range', () async {
    expect(
      () => store.save(const HoursGoal(HoursGoalPeriod.month, 745)),
      throwsArgumentError,
    );
    expect(await store.load(), isNull);
  });

  test('the day the goal was set is stored and read back (M3)', () async {
    expect(await store.loadSince(), isNull);
    await store.saveSince(const CivilDate(2026, 1, 15));
    expect(await store.loadSince(), const CivilDate(2026, 1, 15));
    // It can be replaced.
    await store.saveSince(const CivilDate(2026, 2, 1));
    expect(await store.loadSince(), const CivilDate(2026, 2, 1));
  });

  test('clear removes the goal and its day (M3)', () async {
    await store.save(const HoursGoal(HoursGoalPeriod.year, 1642));
    await store.saveSince(const CivilDate(2026, 1, 15));
    await store.clear();
    expect(await store.load(), isNull);
    expect(await store.loadSince(), isNull);
  });

  test('a row that is not a date is ignored as the day (M3)', () async {
    for (final bad in ['not json', '12', '"not a date"']) {
      await db
          .into(db.settings)
          .insertOnConflictUpdate(
            SettingsCompanion(
              key: const Value(HoursGoalStore.sinceKey),
              value: Value(bad),
            ),
          );
      expect(await store.loadSince(), isNull, reason: bad);
    }
  });

  group('the controller remembers the day (M3)', () {
    late ProviderContainer container;
    var now = DateTime.utc(2026, 1, 15, 9);

    setUp(() {
      now = DateTime.utc(2026, 1, 15, 9);
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);
    });

    test('the first save stores the day, later changes keep it', () async {
      final sub = container.listen(hoursGoalProvider, (_, _) {});
      addTearDown(sub.close);

      await container
          .read(hoursGoalProvider.notifier)
          .set(const HoursGoal(HoursGoalPeriod.year, 1642));
      expect(await store.loadSince(), const CivilDate(2026, 1, 15));

      // Changing the goal months later does not move the day the bag starts.
      now = DateTime.utc(2026, 3, 1, 9);
      await container
          .read(hoursGoalProvider.notifier)
          .set(const HoursGoal(HoursGoalPeriod.month, 150));
      expect(await store.loadSince(), const CivilDate(2026, 1, 15));
    });

    test('clearing forgets the day', () async {
      final sub = container.listen(hoursGoalProvider, (_, _) {});
      addTearDown(sub.close);

      await container
          .read(hoursGoalProvider.notifier)
          .set(const HoursGoal(HoursGoalPeriod.year, 1642));
      expect(await store.loadSince(), isNotNull);

      await container.read(hoursGoalProvider.notifier).clear();
      expect(await store.load(), isNull);
      expect(await store.loadSince(), isNull);
    });
  });
}
