import 'dart:typed_data';

import 'package:cuadrante/features/calendar/application/calendar_background_providers.dart';
import 'package:cuadrante/features/calendar/application/schedule_controller.dart';
import 'package:cuadrante/features/calendar/data/calendar_background_store.dart';
import 'package:cuadrante/features/settings/data/preferences_repository.dart';
import 'package:cuadrante/features/settings/domain/preferences.dart';
import 'package:cuadrante/features/shift_types/domain/shift_color_presets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/test_storage.dart';

/// Ajustes › Apariencia › «Extras visuales» (UX · Extras visuales): the four
/// new rows. The note and the paint sound are switches saved at once; the
/// prepared sets repaint the default roles in one undoable step; the calendar
/// background takes a picture of the gallery (a fake one here), keeps it
/// beside the month and can be removed.

/// A 1×1 PNG: enough for the thumbnail `Image.file` of the row.
const List<int> _png = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89,
  0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54,
  0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01,
  0x0D, 0x0A, 0x2D, 0xB4,
  0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

Future<Uint8List?> _fakePicker() async => Uint8List.fromList(_png);

void main() {
  const tall = Size(390, 3400);

  Future<Preferences> stored(AppUnderTest app) =>
      app.real(() => PreferencesRepository(app.database).load());

  /// The colours of the shift types as they are stored (`id -> ARGB`).
  Future<Map<String, int>> storedColors(AppUnderTest app) async {
    final rows = await app.real(
      () => app.database
          .customSelect('SELECT id, color_value FROM shift_types')
          .get(),
    );
    return {
      for (final row in rows)
        row.read<String>('id'): row.read<int>('color_value'),
    };
  }

  Future<void> flushWrites(AppUnderTest app) => app.real(
    () => app.container.read(scheduleControllerProvider.notifier).pendingWrites,
  );

  /// Lets the file/database work behind a tap finish: a sheet has to close
  /// (fake time, `pumpAndSettle`) and then the gallery, the file and the
  /// database run in real time, so the two are interleaved.
  Future<void> settleWork(AppUnderTest app, WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pumpAndSettle();
      await app.real(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    }
    await tester.pumpAndSettle();
  }

  Finder rowValue(String key, String text) =>
      find.descendant(of: find.byKey(ValueKey(key)), matching: find.text(text));

  testWidgets('the note switch: off at start, saved on tap', (tester) async {
    final app = await AppUnderTest.pump(tester, size: tall);
    await app.openSettings();

    final toggle = find.byKey(const ValueKey('settings-note-in-month-switch'));
    expect(tester.widget<Switch>(toggle).value, isFalse);
    await tester.tap(toggle);
    await settleWork(app, tester);

    expect(tester.widget<Switch>(toggle).value, isTrue);
    expect((await stored(app)).showNoteInMonth, isTrue);
  });

  testWidgets('the paint-sound switch: off at start, saved on tap', (
    tester,
  ) async {
    final app = await AppUnderTest.pump(tester, size: tall);
    await app.openSettings();

    final toggle = find.byKey(const ValueKey('settings-paint-sound-switch'));
    expect(tester.widget<Switch>(toggle).value, isFalse);
    await tester.tap(toggle);
    await settleWork(app, tester);

    expect(tester.widget<Switch>(toggle).value, isTrue);
    expect((await stored(app)).paintSound, isTrue);
  });

  testWidgets('the prepared sets: five options, applied at once, undone', (
    tester,
  ) async {
    final app = await AppUnderTest.pump(tester, size: tall);
    await app.openSettings();

    // The row sits low in the settings list (the list grew with the phone
    // calendar and Do-not-disturb rows): bring it into view first.
    final row = find.byKey(const ValueKey('settings-color-presets'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    for (final preset in shiftColorPresets) {
      expect(
        find.byKey(ValueKey('preset-${preset.id}')),
        findsOneWidget,
        reason: preset.id,
      );
    }
    expect(find.text('Atardecer'), findsOneWidget);

    final before = await storedColors(app);
    await tester.tap(find.byKey(const ValueKey('preset-sunset')));
    await tester.pumpAndSettle();
    expect(find.text('Paleta aplicada. Puedes deshacerlo.'), findsOneWidget);
    await flushWrites(app);
    expect(await storedColors(app), isNot(before));

    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();
    await flushWrites(app);
    expect(await storedColors(app), before);
  });

  testWidgets(
    'the calendar background: picked from the gallery, shown, removed',
    (tester) async {
      final store = CalendarBackgroundStore(makeTempDir('ux-background'));
      final app = await AppUnderTest.pump(
        tester,
        size: tall,
        overrides: [
          calendarBackgroundStoreProvider.overrideWithValue(
            AsyncValue.data(store),
          ),
          calendarImagePickerProvider.overrideWithValue(_fakePicker),
        ],
      );
      await app.openSettings();
      expect(
        rowValue('settings-calendar-background', 'Elegir'),
        findsOneWidget,
      );

      // The row sits low in the settings list: bring it into view first.
      Future<void> openRow() async {
        final row = find.byKey(const ValueKey('settings-calendar-background'));
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        await tester.tap(row);
        await tester.pumpAndSettle();
      }

      // Pick one.
      await openRow();
      expect(find.byKey(const ValueKey('background-pick')), findsOneWidget);
      expect(find.byKey(const ValueKey('background-remove')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('background-pick')));
      await settleWork(app, tester);

      final path = (await stored(app)).calendarBackgroundPath;
      expect(path, isNotNull);
      final saved = path!;
      expect(await app.real(() => store.exists(saved)), isTrue);

      // The row now shows the thumbnail instead of «Elegir»; it resolves in
      // real time, so wait for it with the row in view.
      Future<void> reveal() async {
        final row = find.byKey(const ValueKey('settings-calendar-background'));
        if (row.evaluate().isNotEmpty) {
          await tester.ensureVisible(row);
          await tester.pumpAndSettle();
        }
      }

      for (var i = 0; i < 20 && find.byType(Image).evaluate().isEmpty; i++) {
        await app.real(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pumpAndSettle();
        await reveal();
      }
      expect(find.byType(Image), findsOneWidget);
      expect(rowValue('settings-calendar-background', 'Elegir'), findsNothing);

      // Remove it.
      await openRow();
      expect(find.byKey(const ValueKey('background-remove')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('background-remove')));
      await settleWork(app, tester);

      expect((await stored(app)).calendarBackgroundPath, isNull);
      // The sweep of the file itself is covered by the store/service unit
      // test: here the picture may still be held by the image cache, and the
      // store deliberately tolerates a file that cannot be deleted yet.
      expect(find.byType(Image), findsNothing);
      expect(
        rowValue('settings-calendar-background', 'Elegir'),
        findsOneWidget,
      );

      // Free the picture before the temporary folder goes: on Windows the
      // image cache keeps a handle while it holds the decoded picture.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
    },
  );
}
