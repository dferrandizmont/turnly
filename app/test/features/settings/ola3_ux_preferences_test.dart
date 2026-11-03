import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/features/backup/data/backup_repository.dart';
import 'package:cuadrante/features/settings/application/preferences_controller.dart';
import 'package:cuadrante/features/settings/data/preferences_repository.dart';
import 'package:cuadrante/features/settings/domain/preferences.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_storage.dart';

/// UX · Extras visuales (docs/ola3-pantallas.md): the three preferences behind
/// the visual extras («Ver la nota en el mes», «Sonido al pintar» and «Imagen
/// de fondo del calendario»). They live in `settings` like the rest of the
/// appearance, fall back to their defaults when a row is unreadable, and the
/// background one is cleared by deleting its row (not by writing a JSON null).
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

    test('an installation from before: off, off and no background', () async {
      final loaded = await repository.load();
      expect(loaded.showNoteInMonth, isFalse);
      expect(loaded.paintSound, isFalse);
      expect(loaded.calendarBackgroundPath, isNull);
      expect(loaded, Preferences.defaults);
    });

    test('round trip of the three values', () async {
      await repository.setShowNoteInMonth(true);
      await repository.setPaintSound(true);
      await repository.setCalendarBackground('bg-123.img');
      final loaded = await repository.load();
      expect(loaded.showNoteInMonth, isTrue);
      expect(loaded.paintSound, isTrue);
      expect(loaded.calendarBackgroundPath, 'bg-123.img');

      await repository.setShowNoteInMonth(false);
      await repository.setPaintSound(false);
      expect((await repository.load()).showNoteInMonth, isFalse);
      expect((await repository.load()).paintSound, isFalse);
    });

    test('removing the background deletes its row', () async {
      await repository.setCalendarBackground('bg-1.img');
      var rows = await db.select(db.settings).get();
      expect(
        rows.where((r) => r.key == PreferenceKeys.calendarBackground),
        hasLength(1),
      );

      await repository.setCalendarBackground(null);
      rows = await db.select(db.settings).get();
      expect(
        rows.where((r) => r.key == PreferenceKeys.calendarBackground),
        isEmpty,
      );
      expect((await repository.load()).calendarBackgroundPath, isNull);
    });

    test('a row with something else falls back to the default', () async {
      await store(PreferenceKeys.showNoteInMonth, '7');
      await store(PreferenceKeys.paintSound, 'null');
      await store(PreferenceKeys.calendarBackground, '12');
      final loaded = await repository.load();
      expect(loaded.showNoteInMonth, isFalse);
      expect(loaded.paintSound, isFalse);
      expect(loaded.calendarBackgroundPath, isNull);
    });

    test(
      'the background picture is a device setting: it never travels (L3)',
      () {
        // The picture file is not in the backup, so neither is its path: a
        // restored copy must not point at another phone's picture.
        expect(isDeviceSetting(PreferenceKeys.calendarBackground), isTrue);
        // The other extras do travel.
        expect(isDeviceSetting(PreferenceKeys.showNoteInMonth), isFalse);
        expect(isDeviceSetting(PreferenceKeys.paintSound), isFalse);
      },
    );
  });

  group('controller', () {
    late AppDatabase db;
    late PreferencesRepository repository;
    late ProviderContainer container;

    setUp(() {
      db = openMemoryDatabase();
      repository = PreferencesRepository(db);
      container = ProviderContainer(
        overrides: [
          preferencesRepositoryProvider.overrideWithValue(repository),
          initialPreferencesProvider.overrideWithValue(Preferences.defaults),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(db.close);
    });

    test('applies at once and writes', () async {
      final controller = container.read(preferencesProvider.notifier);
      await controller.setShowNoteInMonth(true);
      await controller.setPaintSound(true);
      await controller.setCalendarBackground('bg-9.img');

      final state = container.read(preferencesProvider);
      expect(state.showNoteInMonth, isTrue);
      expect(state.paintSound, isTrue);
      expect(state.calendarBackgroundPath, 'bg-9.img');

      final stored = await repository.load();
      expect(stored.showNoteInMonth, isTrue);
      expect(stored.paintSound, isTrue);
      expect(stored.calendarBackgroundPath, 'bg-9.img');
    });

    test('a null background clears the state and the stored row', () async {
      final controller = container.read(preferencesProvider.notifier);
      await controller.setCalendarBackground('bg-5.img');
      await controller.setCalendarBackground(null);
      expect(
        container.read(preferencesProvider).calendarBackgroundPath,
        isNull,
      );
      expect((await repository.load()).calendarBackgroundPath, isNull);
    });
  });

  group('copyWith', () {
    test('the background path and the clear flag', () {
      const base = Preferences.defaults;
      final withImage = base.copyWith(calendarBackgroundPath: 'bg-2.img');
      expect(withImage.calendarBackgroundPath, 'bg-2.img');
      // Without the flag a new value sticks; with it, the background goes.
      expect(withImage.copyWith().calendarBackgroundPath, 'bg-2.img');
      expect(
        withImage
            .copyWith(clearCalendarBackground: true)
            .calendarBackgroundPath,
        isNull,
      );
      // The new fields take part in equality.
      expect(
        const Preferences(showNoteInMonth: true),
        isNot(const Preferences(paintSound: true)),
      );
      expect(
        const Preferences(paintSound: true),
        const Preferences(paintSound: true),
      );
    });
  });
}
