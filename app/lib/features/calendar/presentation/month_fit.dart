import 'package:flutter/material.dart';

import '../../../core/theme/theme_context.dart';
import 'day_cell.dart';
import 'today_card.dart';

/// Whether the whole month fits on the screen (decision 28 of
/// `docs/preguntas.md`): the grid rules, the card of today gives way.
///
/// The month screen of a phone stacks, from the top: the date row, the card of
/// today, the row of the month, the weekday row, the grid and the fixed row
/// at the bottom (above the bar of destinations). The grid always has six
/// rows ([monthGridRows]) of at least one cell each, so the answer does not
/// change when the month goes from five weeks to six.
///
/// It reads the size of the screen and the system insets, never the keyboard
/// or the room the layout really got, so it is stable: it only changes when
/// the window turns or the text size changes.
class MonthFit {
  const MonthFit._();

  /// The rows of the month grid: always six.
  static const int monthGridRows = 6;

  /// The date row and its three buttons (4 dp above, 48 dp buttons).
  static const double dateRow = Sp.xs + Sp.touch;

  /// The row of the month (title, Grid/List, arrows), on one line.
  static const double monthRow = Sp.s + Sp.touch;

  /// The weekday row: the initial and its margins.
  static double weekdayRow(BuildContext context) =>
      Sp.xs +
      textHeight(context.type.caption, MediaQuery.textScalerOf(context)) +
      Sp.xs;

  /// The fixed row under the grid: the height of the floating button and its
  /// margin, so the button floats over it and never over a cell.
  static const double fixedRow = Sp.fabClearance;

  /// The bar of destinations (its theme height and the line above it) and the
  /// system inset under it.
  static double bottomBar(BuildContext context) =>
      (NavigationBarTheme.of(context).height ?? 80) +
      1 +
      MediaQuery.viewPaddingOf(context).bottom;

  /// The height the month screen has under the status bar and above the bar
  /// of destinations.
  static double available(BuildContext context) =>
      MediaQuery.sizeOf(context).height -
      MediaQuery.viewPaddingOf(context).top -
      bottomBar(context);

  /// The height of the month without the card of today: everything that
  /// stays when the grid shows all its rows at their minimum.
  static double withoutCard(BuildContext context) =>
      dateRow +
      monthRow +
      weekdayRow(context) +
      monthGridRows * dayCellHeightWithTime(context) +
      fixedRow;

  /// Whether the card of today fits open with the whole month, without
  /// scrolling.
  static bool fitsWithOpenCard(BuildContext context) =>
      withoutCard(context) + TodayCard.openHeightEstimate(context) <=
      available(context);
}
