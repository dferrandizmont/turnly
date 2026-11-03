import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cuadrante/features/calendar/application/calendar_background_providers.dart';
import 'package:cuadrante/features/calendar/data/calendar_background_store.dart';
import 'package:cuadrante/features/calendar/presentation/month_screen.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/shift_types/domain/shift_color_presets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../support/qa_core.dart';
import '../support/qa_harness.dart';

// Extras visuales (UX), Q102.
//
// The four rows Ajustes › Apariencia gains with the UX package: the note in the
// month, the sound when painting, the prepared colour sets (applied at once and
// undone) and the calendar background. The gallery picker is a fake (the system
// one cannot be driven from the battery) and the background files go to a
// scratch folder, exactly as the widget tests do. The registry lists
// [uxExtrasScenarios].

/// Scenarios of this file, listed by `registry.dart`.
final List<QaScenario> uxExtrasScenarios = [
  qaUxExtras, // Q102
];

Finder _key(String k) => find.byKey(ValueKey(k));

/// A 1×1 PNG: enough for the thumbnail of the row and for the month layer.
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

/// The day that carries a note, in the demo month of the battery.
const _noteDay = CivilDate(2026, 10, 22);
const _noteText = 'Cumple de Ana\nllevar tarta';

/// A free day, to paint over it and hear the click.
const _paintDay = CivilDate(2026, 10, 25);

// ---- Q102 ------------------------------------------------------------------

/// Q102.
const qaUxExtras = QaScenario(
  'Q102',
  'Extras visuales: nota en el mes, sonido al pintar, paletas preparadas e '
      'imagen de fondo',
  _uxExtras,
  timeout: Duration(minutes: 5),
);

Future<void> _uxExtras(QaContext qa) async {
  final t = qa.tester;

  // The background file goes to a scratch folder and the gallery is a fake:
  // the system picker is left for the manual pass (like the sound selector of
  // Q94).
  final background = (await t.runAsync(() async {
    final base = await getTemporaryDirectory();
    return Directory(
      p.join(base.path, 'qa-bg-${DateTime.now().microsecondsSinceEpoch}'),
    ).create(recursive: true);
  }))!;
  final store = CalendarBackgroundStore(
    Directory(p.join(background.path, calendarBackgroundDirectoryName)),
  );
  Future<Uint8List?> picker() async => Uint8List.fromList(_png);

  final app = await QaApp.open(
    qa,
    overrides: [
      calendarBackgroundStoreProvider.overrideWithValue(AsyncValue.data(store)),
      calendarImagePickerProvider.overrideWithValue(picker),
    ],
  );

  // A note on the 22nd, so the month has something to show in the cell.
  app.scheduleController.setNote(_noteDay, _noteText);
  await app.flushWrites();

  /// Reads one stored preference value (`null` = the key is not there).
  Future<Object?> pref(String key) async {
    final rows = await app.query(
      "SELECT value FROM settings WHERE key = '$key'",
    );
    return rows.isEmpty ? null : rows.single['value'];
  }

  /// Waits in real time until [check] is true.
  Future<void> until(Future<bool> Function() check, String what) async {
    final end = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(end)) {
      if (await check()) return;
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
    }
    throw TestFailure('Tiempo agotado esperando $what');
  }

  // ---- 1. Ver la nota en el mes ------------------------------------------
  await t.tapAndSettle(find.byTooltip('Abrir ajustes'), reason: 'Ajustes');

  final noteSwitch = _key('settings-note-in-month-switch');
  expect(
    t.widget<Switch>(noteSwitch).value,
    isFalse,
    reason: 'apagado al principio',
  );
  await t.tapAndSettle(noteSwitch, reason: 'Ver la nota en el mes');
  expect(t.widget<Switch>(noteSwitch).value, isTrue);
  expect(await pref('calendar.showNoteInMonth'), 'true');
  await qa.shot('nota-ajuste');

  // Back to the month: the cell of the 22nd is there and the month builds
  // without errors. The first line of the note is written when the number
  // leaves it room (wide surfaces); on a phone the clip of always stays.
  await _backToMonth(t);
  expect(cell(_noteDay), findsOneWidget, reason: 'el 22 con nota');

  // The capture must show the note text, not its clip. The cell of a phone
  // does not give it room, so the shot is taken at a tablet width, where the
  // month writes it (the widget test guarantees it from 700 dp).
  final noteText = _key('note-text-${_noteDay.toIso()}');
  if (noteText.evaluate().isEmpty) {
    qa.note(
      'en el móvil la celda no da para el texto de la nota (queda el clip): '
      'captura en ancho de tablet',
    );
    t.view.physicalSize = const Size(1024, 1400);
    t.view.devicePixelRatio = 1;
    await t.settle();
  }
  expect(noteText, findsOneWidget, reason: 'el texto de la nota, visible');
  qa.expectNoFlutterErrors('nota en el mes');
  await qa.shot('nota-mes');
  // Back to the phone for the rest of the scenario.
  t.view.resetPhysicalSize();
  t.view.resetDevicePixelRatio();
  await t.settle();

  // ---- 2. Sonido al pintar ------------------------------------------------
  await t.tapAndSettle(find.byTooltip('Abrir ajustes'), reason: 'Ajustes');
  final soundSwitch = _key('settings-paint-sound-switch');
  expect(
    t.widget<Switch>(soundSwitch).value,
    isFalse,
    reason: 'apagado al principio',
  );
  await t.tapAndSettle(soundSwitch, reason: 'Sonido al pintar');
  expect(t.widget<Switch>(soundSwitch).value, isTrue);
  expect(await pref('calendar.paintSound'), 'true');

  // Paint a free day: the click of the system plays (never breaks the stroke).
  await _backToMonth(t);
  await enterPaintMode(t);
  await t.tapAndSettle(tool('morning'), reason: 'turno Mañana');
  await t.tapAndSettle(cell(_paintDay), reason: 'pintar el 25');
  await app.flushWrites();
  expect((await app.storedDay(_paintDay))?.shiftTypeIds, [
    'morning',
  ], reason: 'el día pintado con el sonido activado');
  await exitPaintMode(t);
  qa.expectNoFlutterErrors('sonido al pintar');
  await qa.shot('sonido-pintar');

  // ---- 3. Paletas preparadas ----------------------------------------------
  await t.tapAndSettle(find.byTooltip('Abrir ajustes'), reason: 'Ajustes');
  await t.tapAndSettle(
    _key('settings-color-presets'),
    reason: 'Paletas preparadas',
  );
  for (final preset in shiftColorPresets) {
    expect(_key('preset-${preset.id}'), findsOneWidget, reason: preset.id);
  }

  Future<Map<String, Object?>> colors() async {
    final rows = await app.query(
      'SELECT id, color_value FROM shift_types ORDER BY sort_order',
    );
    return {for (final r in rows) r['id']! as String: r['color_value']};
  }

  final before = await colors();
  await t.tapAndSettle(
    _key('preset-${shiftColorPresets.first.id}'),
    reason: 'aplicar la paleta',
  );
  await t.waitFor(
    find.text('Paleta aplicada. Puedes deshacerlo.'),
    reason: 'el aviso',
  );
  await app.flushWrites();
  expect(
    await colors(),
    isNot(before),
    reason: 'los colores cambian de una vez',
  );
  await qa.shot('paleta-aplicada');

  await t.tapAndSettle(find.text('Deshacer'), reason: 'deshacer la paleta');
  await app.flushWrites();
  expect(await colors(), before, reason: 'un solo deshacer lo devuelve');
  await qa.shot('paleta-deshacer');

  // ---- 4. Imagen de fondo del calendario ----------------------------------
  await t.tapAndSettle(
    _key('settings-calendar-background'),
    reason: 'Imagen de fondo',
  );
  expect(_key('background-pick'), findsOneWidget);
  expect(_key('background-remove'), findsNothing, reason: 'aún no hay ninguna');
  await t.tapAndSettle(_key('background-pick'), reason: 'elegir de la galería');
  await until(
    () async => await pref('appearance.calendarBackground') != null,
    'que la imagen quede guardada',
  );

  // The preference is stored JSON-encoded (a quoted string), so the raw row
  // is decoded before asking the store about the file.
  final saved = jsonDecode(
    (await pref('appearance.calendarBackground'))! as String,
  ) as String;
  expect(await t.runAsync(() => store.exists(saved)), isTrue);
  // The row now shows the thumbnail, not «Elegir».
  await t.waitFor(
    find.descendant(
      of: _key('settings-calendar-background'),
      matching: find.byType(Image),
    ),
    reason: 'la miniatura de la imagen en uso',
  );
  await qa.shot('fondo-elegido');

  // And it can be removed again.
  await t.tapAndSettle(
    _key('settings-calendar-background'),
    reason: 'Imagen de fondo',
  );
  expect(_key('background-remove'), findsOneWidget);
  await t.tapAndSettle(_key('background-remove'), reason: 'quitar la imagen');
  await until(
    () async => await pref('appearance.calendarBackground') == null,
    'que la imagen se quite',
  );
  expect(
    find.descendant(
      of: _key('settings-calendar-background'),
      matching: find.byType(Image),
    ),
    findsNothing,
  );
  await qa.shot('fondo-quitado');

  qa.expectNoFlutterErrors();
}

/// Back to the month the way a person does it, closing whatever is on top.
Future<void> _backToMonth(WidgetTester t) async {
  for (var i = 0; i < 4 && find.byType(BackButton).evaluate().isNotEmpty; i++) {
    await t.tapAndSettle(find.byType(BackButton).last, reason: 'flecha atrás');
  }
  expect(find.byType(MonthScreen), findsOneWidget);
}
