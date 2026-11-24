import 'package:flutter/widgets.dart';

import '../../schedule/domain/schedule_domain.dart';

/// What the pattern builder draws when it is not the wizard's own: the
/// first-use flow (`OwnCycleScreen`) keeps its shift types in memory until the
/// end, so it hands the builder the palette and the way to draw a shift from
/// there (factory texts in the app's language, the job's hours, no absences)
/// instead of what the schedule stores. Without one above it, the builder reads
/// the schedule, as the wizard always did.
class PatternBuilderShifts extends InheritedWidget {
  const PatternBuilderShifts({
    super.key,
    required this.palette,
    required this.shiftOf,
    required this.defaultName,
    required super.child,
  });

  /// The shifts offered, in order.
  final List<ShiftType> palette;

  /// How to draw the shift with this id.
  final ShiftType? Function(String id) shiftOf;

  /// Name given to a cycle left unnamed (also the hint of the name field).
  final String defaultName;

  static PatternBuilderShifts? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PatternBuilderShifts>();

  // Rebuilt only when the screen above it is, which is when its inputs change.
  @override
  bool updateShouldNotify(PatternBuilderShifts oldWidget) => true;
}
