import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'qa_harness.dart';

/// The day detail is in layers (`docs/diseno.md`, «Detalle del día», option
/// 4A of 31 Oct): the row moves are in the menu of each shift row, the
/// palette opens with «Añadir turno» (it is already out on an empty day) and
/// extras, own holiday, reminder, «Sin alarma este día», «Duplicar en otro
/// día» and «Borrar día» are in «Más opciones», folded.
extension DaySheetQa on WidgetTester {
  /// Reaches the control [key] the way a person does:
  ///
  /// - `day-change-N`, `day-up-N`, `day-down-N`, `day-remove-N`: opens the
  ///   menu of the shift row N;
  /// - `day-add-<id>`: «Añadir turno»;
  /// - anything else not built yet: unfolds «Más opciones».
  ///
  /// Only for a control that is expected: a missing one would fold «Más
  /// opciones» back if it was open.
  Future<void> revealDayControl(String key) async {
    final target = find.byKey(ValueKey(key));
    if (target.evaluate().isNotEmpty) return;
    final row = RegExp(r'^day-(change|up|down|remove)-(\d+)$').firstMatch(key);
    final String opener;
    if (row != null) {
      opener = 'day-shift-menu-${row.group(2)}';
    } else if (key.startsWith('day-add-') && key != 'day-add-open') {
      opener = 'day-add-open';
    } else {
      opener = 'day-more';
    }
    await tapAndSettle(find.byKey(ValueKey(opener)), reason: opener);
  }

  /// [revealDayControl], then taps it.
  Future<void> tapDayControl(String key) async {
    await revealDayControl(key);
    await tapAndSettle(find.byKey(ValueKey(key)), reason: key);
  }

  /// Unfolds «Más opciones» when it is folded.
  Future<void> openDayMore() async {
    if (find.byKey(const ValueKey('day-more-content')).evaluate().isNotEmpty) {
      return;
    }
    await tapAndSettle(
      find.byKey(const ValueKey('day-more')),
      reason: 'Más opciones',
    );
  }
}
