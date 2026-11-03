import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Brings a control of the day detail (sheet or pane) into reach the way a
/// person does (`docs/diseno.md`, «Detalle del día», by layers):
///
/// - `day-change-N`, `day-up-N`, `day-down-N`, `day-remove-N`: opens the
///   menu of the shift row N;
/// - `day-add-<id>`: opens the palette with «Añadir turno»;
/// - anything else that is not built yet: unfolds «Más opciones».
///
/// Only for a control that is expected to be there: a missing one would fold
/// «Más opciones» back if it was open.
Future<void> revealDayControl(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  if (target.evaluate().isEmpty) {
    final row = RegExp(r'^day-(change|up|down|remove)-(\d+)$').firstMatch(key);
    final String opener;
    if (row != null) {
      opener = 'day-shift-menu-${row.group(2)}';
    } else if (key.startsWith('day-add-') && key != 'day-add-open') {
      opener = 'day-add-open';
    } else {
      opener = 'day-more';
    }
    await _tapTop(tester, find.byKey(ValueKey(opener)));
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

/// [revealDayControl], then taps it.
Future<void> tapDayControl(WidgetTester tester, String key) async {
  await revealDayControl(tester, key);
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

/// Unfolds «Más opciones» when it is folded.
Future<void> openDayMore(WidgetTester tester) async {
  if (find.byKey(const ValueKey('day-more-content')).evaluate().isNotEmpty) {
    return;
  }
  await _tapTop(tester, find.byKey(const ValueKey('day-more')));
}

/// Taps near the top of [finder]: with the test font at text x2 the «Más
/// opciones» row (its summary wraps a lot) is taller than the sheet's
/// viewport, so its centre would be off screen.
Future<void> _tapTop(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  final rect = tester.getRect(finder);
  await tester.tapAt(
    Offset(
      rect.center.dx,
      rect.top + (rect.height < 48 ? rect.height / 2 : 24),
    ),
  );
  await tester.pumpAndSettle();
}

/// Closes an open popup menu (the menu of a shift row) without choosing.
Future<void> dismissMenu(WidgetTester tester) async {
  final item = find.byWidgetPredicate((w) => w is PopupMenuItem);
  if (item.evaluate().isEmpty) return;
  // Pops the menu's own route: a tap on the dimmed area could land on the
  // sheet's barrier and close the sheet instead.
  Navigator.of(tester.element(item.first)).pop();
  await tester.pumpAndSettle();
}
