import 'dart:convert';

import 'package:cuadrante/features/dnd/application/dnd_providers.dart';
import 'package:cuadrante/features/dnd/domain/dnd_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/qa_core.dart';
import '../support/qa_harness.dart';

/// Q104: «No molestar durante el turno» (P13). Android only: the switch of the
/// shift type editor, the global row of Ajustes › Alarmas and the state of the
/// «Acceso a No molestar» permission. The registry lists [dndScenarios].
final List<QaScenario> dndScenarios = [
  qaDndDuringShift, // Q104
];

const _night = 'night';
const _timeout = Duration(minutes: 4);

Finder _k(String key) => find.byKey(ValueKey(key));

Finder _switch(String key) =>
    find.descendant(of: _k(key), matching: find.byType(Switch));

/// The stored silence settings, read from the `settings` table (the real
/// evidence; the in-memory provider is only a mirror).
Future<DndSettings> _storedDnd(QaApp app) async {
  final rows = await app.query("SELECT value FROM settings WHERE key = 'dnd'");
  expect(rows, hasLength(1), reason: 'la fila de ajustes de No molestar');
  final json = jsonDecode(rows.single['value']! as String);
  return DndSettings.fromJson((json as Map).cast<String, Object?>());
}

Future<void> _backHome(WidgetTester t) async {
  for (var i = 0; i < 4 && find.byType(BackButton).evaluate().isNotEmpty; i++) {
    await t.tapAndSettle(find.byType(BackButton).last, reason: 'atrás');
  }
}

/// Ajustes › Mis turnos › Noche (the list builds its rows lazily).
Future<void> _openNightEditor(WidgetTester t) async {
  await t.tapAndSettle(find.byTooltip('Abrir ajustes'), reason: 'Ajustes');
  await t.tapAndSettle(_k('settings-shifts'), reason: 'Mis turnos');
  await t.scrollUntilVisible(
    _k('shift-row-$_night'),
    200,
    scrollable: find.descendant(
      of: _k('shift-list'),
      matching: find.byType(Scrollable),
    ),
  );
  await t.tapAndSettle(_k('shift-row-$_night'), reason: 'Noche');
}

/// Q104.
const qaDndDuringShift = QaScenario(
  'Q104',
  'No molestar: interruptor por turno y estado global',
  _dndBody,
  timeout: _timeout,
);

Future<void> _dndBody(QaContext qa) async {
  final t = qa.tester;
  addTearDown(t.platformDispatcher.clearAllTestValues);
  final app = await QaApp.open(qa);
  final permission = (await t.runAsync(
    () => app.container.read(dndChannelProvider).permissionStatus(),
  ))!;
  qa.note('acceso a No molestar: ${permission.name}');

  // 1. The editor of Noche: the switch is off and turns on.
  await _openNightEditor(t);
  expect(_k('shift-dnd'), findsOneWidget, reason: 'Android tiene No molestar');
  expect(t.widget<Switch>(_switch('shift-dnd')).value, isFalse);
  await t.tapAndSettle(_k('shift-dnd'), reason: 'activar No molestar de Noche');
  await qa.shot('editor_activo');
  await t.tapAndSettle(_k('shift-save'), reason: 'Guardar');
  await app.flushWrites();

  // The choice lives with the silence settings, not in the shift type, and
  // with the global switch off it does not silence anything yet.
  final afterEditor = await _storedDnd(app);
  expect(afterEditor.forShiftType(_night).enabled, isTrue);
  expect(afterEditor.enabled, isFalse, reason: 'el general sigue apagado');
  expect(afterEditor.isEnabledFor(_night), isFalse, reason: 'sin el general');

  // 2. Ajustes › Alarmas: the global row.
  await _backHome(t);
  await t.tapAndSettle(find.byTooltip('Abrir ajustes'), reason: 'Ajustes');
  await t.tapAndSettle(_k('settings-alarms'), reason: 'Alarmas');
  expect(t.widget<Switch>(_k('dnd-master-switch')).value, isFalse);
  await t.tapAndSettle(_k('dnd-master-switch'), reason: 'interruptor general');
  final afterMaster = await _storedDnd(app);
  expect(afterMaster.enabled, isTrue);
  expect(afterMaster.isEnabledFor(_night), isTrue, reason: 'Noche silencia');
  await qa.shot('alarmas_activo');

  // The filter row appears; pick «Solo las alarmas».
  await t.tapAndSettle(_k('dnd-filter'), reason: 'filtro');
  await t.tapAndSettle(find.text('Solo las alarmas'), reason: 'Solo las alarmas');
  expect((await _storedDnd(app)).filter, DndFilter.alarms);
  expect(
    find.descendant(
      of: _k('dnd-filter'),
      matching: find.text('Solo las alarmas'),
    ),
    findsOneWidget,
  );
  await qa.shot('filtro_alarmas');

  // The same section in the dark (the master switch, the filter and the
  // permission card).
  t.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
  await t.settle();
  await qa.shot('filtro_alarmas_oscuro');
  t.platformDispatcher.platformBrightnessTestValue = Brightness.light;
  await t.settle();

  // The permission card matches the real state of the phone. The access is a
  // normal permission on Android, but the scenario does not assume it.
  if (permission == DndPermission.granted) {
    expect(_k('dnd-permission-ok'), findsOneWidget);
    qa.note('acceso concedido: tarjeta verde');
  } else {
    expect(_k('dnd-permission-denied'), findsOneWidget);
    expect(_k('dnd-permission-open'), findsOneWidget);
    qa.note('acceso sin conceder: se explica y se abre el sistema');
    await qa.shot('permiso_denegado');
  }

  // 3. Close and open the app: both choices come back.
  await app.restart();
  await t.tapAndSettle(find.byTooltip('Abrir ajustes'), reason: 'Ajustes');
  await t.tapAndSettle(_k('settings-alarms'), reason: 'Alarmas');
  expect(t.widget<Switch>(_k('dnd-master-switch')).value, isTrue);
  expect(
    find.descendant(
      of: _k('dnd-filter'),
      matching: find.text('Solo las alarmas'),
    ),
    findsOneWidget,
  );
  await qa.shot('tras_reiniciar');
  qa.expectNoFlutterErrors('No molestar');
}
