import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/core/theme/app_theme.dart';
import 'package:cuadrante/features/backup/data/backup_repository.dart'
    show isDeviceSetting;
import 'package:cuadrante/features/settings/application/preferences_controller.dart';
import 'package:cuadrante/features/settings/data/preferences_repository.dart';
import 'package:cuadrante/features/settings/domain/preferences.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/test_storage.dart';

/// P8 · Apariencia: Color de acento y Tamaño del turno en el mes
/// (docs/diseno.md, «Acento elegible» y «Tamaño del turno en la casilla»).
void main() {
  group('repository', () {
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

    test('an installation from before: Índigo and Normal', () async {
      final loaded = await repository.load();
      expect(loaded.accent, AppAccent.indigo);
      expect(loaded.cellTextSize, CellTextSize.normal);
      expect(loaded, Preferences.defaults);
    });

    test('round trip of every value', () async {
      for (final accent in AppAccent.values) {
        await repository.setAccent(accent);
        expect((await repository.load()).accent, accent);
      }
      for (final size in CellTextSize.values) {
        await repository.setCellTextSize(size);
        expect((await repository.load()).cellTextSize, size);
      }
    });

    test('rows that hold something else fall back to the defaults', () async {
      await store(PreferenceKeys.accent, '"purple"');
      await store(PreferenceKeys.cellTextSize, '"huge"');
      var loaded = await repository.load();
      expect(loaded.accent, AppAccent.indigo);
      expect(loaded.cellTextSize, CellTextSize.normal);
      await store(PreferenceKeys.accent, '7');
      await store(PreferenceKeys.cellTextSize, 'not json');
      loaded = await repository.load();
      expect(loaded.accent, AppAccent.indigo);
      expect(loaded.cellTextSize, CellTextSize.normal);
    });

    test('the other preferences are not touched', () async {
      await repository.setCurrency('USD');
      await repository.setAccent(AppAccent.petrol);
      final loaded = await repository.load();
      expect(loaded.currency, 'USD');
      expect(loaded.accent, AppAccent.petrol);
    });

    test('both travel in the backup, like the theme', () {
      expect(isDeviceSetting(PreferenceKeys.accent), isFalse);
      expect(isDeviceSetting(PreferenceKeys.cellTextSize), isFalse);
      expect(isDeviceSetting(PreferenceKeys.themeMode), isFalse);
    });

    test('controller: applies at once and writes', () async {
      final container = ProviderContainer(
        overrides: [
          preferencesRepositoryProvider.overrideWithValue(repository),
          initialPreferencesProvider.overrideWithValue(Preferences.defaults),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(preferencesProvider.notifier);
      await controller.setAccent(AppAccent.graphite);
      await controller.setCellTextSize(CellTextSize.extraLarge);
      final state = container.read(preferencesProvider);
      expect(state.accent, AppAccent.graphite);
      expect(state.cellTextSize, CellTextSize.extraLarge);
      final stored = await repository.load();
      expect(stored.accent, AppAccent.graphite);
      expect(stored.cellTextSize, CellTextSize.extraLarge);
    });
  });

  group('preferences', () {
    test('copyWith, equality and the stored values', () {
      const base = Preferences.defaults;
      final changed = base.copyWith(
        accent: AppAccent.blue,
        cellTextSize: CellTextSize.large,
      );
      expect(changed, isNot(base));
      expect(changed.copyWith(), changed);
      expect(changed.weekStart, base.weekStart);
      expect(
        changed,
        const Preferences(
          accent: AppAccent.blue,
          cellTextSize: CellTextSize.large,
        ),
      );
      for (final size in CellTextSize.values) {
        expect(CellTextSize.fromStored(size.stored), size);
      }
      expect(CellTextSize.fromStored(null), CellTextSize.normal);
      expect(CellTextSize.fromStored(1.2), CellTextSize.normal);
    });

    test('the size only scales the cell styles', () {
      final normal = AppTheme.light().extension<AppTypography>()!;
      for (final size in CellTextSize.values) {
        final type = AppTheme.light(cellSize: size).extension<AppTypography>()!;
        expect(type.cellCode.fontSize, closeTo(20 * size.factor, 1e-9));
        expect(type.cellCodeMulti.fontSize, closeTo(14 * size.factor, 1e-9));
        expect(type.cellTime.fontSize, closeTo(10 * size.factor, 1e-9));
        // The line keeps its proportion.
        expect(
          type.cellCode.fontSize! * type.cellCode.height!,
          closeTo(22 * size.factor, 1e-9),
        );
        expect(type.cellDay, normal.cellDay);
        expect(type.body, normal.body);
        expect(type.title, normal.title);
      }
      expect(CellTextSize.normal.factor, 1);
    });
  });

  group('Ajustes › Apariencia', () {
    const tall = Size(390, 2200);

    Future<Preferences> stored(AppUnderTest app) =>
        app.real(() => PreferencesRepository(app.database).load());

    Finder rowValue(String key, String text) => find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.text(text),
    );

    Finder inSheet(Finder what) =>
        find.descendant(of: find.byType(BottomSheet), matching: what);

    for (final brightness in Brightness.values) {
      testWidgets('the accent: five options, live change, '
          'stored (${brightness.name})', (tester) async {
        final app = await AppUnderTest.pump(
          tester,
          size: tall,
          platformBrightness: brightness,
        );
        final dark = brightness == Brightness.dark;
        expect(
          app.theme.extension<AppColors>()!.accent,
          dark ? AppAccent.indigo.dark : AppAccent.indigo.light,
        );
        await app.openSettings();
        expect(rowValue('settings-accent', 'Índigo'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('settings-accent')));
        await tester.pumpAndSettle();
        for (final name in [
          'Índigo',
          'Azul',
          'Petróleo',
          'Frambuesa',
          'Grafito',
        ]) {
          expect(inSheet(find.text(name)), findsOneWidget);
        }
        expect(inSheet(find.text('Por defecto')), findsOneWidget);
        // The selected one says so to TalkBack / VoiceOver.
        expect(
          tester.getSemantics(find.byKey(const ValueKey('accent-indigo'))),
          isSemantics(
            label: 'Índigo, Por defecto',
            isButton: true,
            isSelected: true,
            hasTapAction: true,
          ),
        );

        await tester.tap(inSheet(find.text('Petróleo')));
        await tester.pumpAndSettle();
        expect(rowValue('settings-accent', 'Petróleo'), findsOneWidget);
        expect(
          app.theme.extension<AppColors>()!.accent,
          dark ? AppAccent.petrol.dark : AppAccent.petrol.light,
        );
        expect(
          app.theme.colorScheme.primary,
          dark ? AppAccent.petrol.dark : AppAccent.petrol.light,
        );
        // The amber stays.
        expect(
          app.theme.extension<AppColors>()!.highlight,
          dark ? AppColors.dark.highlight : AppColors.light.highlight,
        );
        expect((await stored(app)).accent, AppAccent.petrol);
      });
    }

    testWidgets('the size: three options with a sample, live change, stored', (
      tester,
    ) async {
      final app = await AppUnderTest.pump(tester, size: tall);
      await app.openSettings();
      expect(rowValue('settings-cell-size', 'Normal'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('settings-cell-size')));
      await tester.pumpAndSettle();
      for (final name in ['Normal', 'Grande', 'Muy grande']) {
        expect(inSheet(find.text(name)), findsOneWidget);
      }
      // Each option draws its sample at its own size.
      final samples = tester
          .widgetList<Text>(inSheet(find.text('22–06')))
          .map((t) => t.style!.fontSize!)
          .toList();
      expect(samples, [10, 12, 14].map((s) => closeTo(s, 1e-9)).toList());

      await tester.tap(inSheet(find.text('Grande')));
      await tester.pumpAndSettle();
      expect(rowValue('settings-cell-size', 'Grande'), findsOneWidget);
      expect(
        app.theme.extension<AppTypography>()!.cellCode.fontSize,
        closeTo(24, 1e-9),
      );
      expect((await stored(app)).cellTextSize, CellTextSize.large);
    });

    testWidgets('a dismissed sheet changes nothing', (tester) async {
      final app = await AppUnderTest.pump(tester, size: tall);
      await app.openSettings();
      await tester.tap(find.byKey(const ValueKey('settings-accent')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(rowValue('settings-accent', 'Índigo'), findsOneWidget);
      expect((await stored(app)).accent, AppAccent.indigo);
    });
  });
}
