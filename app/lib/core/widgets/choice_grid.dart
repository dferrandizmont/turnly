import 'package:flutter/material.dart';

import '../theme/theme_context.dart';
import 'choice_pill.dart';

/// How [ChoiceGrid] sizes its cells from the texts of its pills.
enum ChoiceGridSizing {
  /// A cell fits its longest whole label on one line (short labels: «Mes»,
  /// «Trimestre», a shift's name).
  wholeLabel,

  /// A cell only needs the longest single word plus the pill around it, and
  /// the label wraps onto two or three lines inside it (long labels: shift
  /// types, absence kinds, template names). A word never breaks.
  longestWord,
}

/// Choices laid out in aligned columns, every cell the same width and every
/// row as tall as its tallest cell, so «Mañana», «Tarde», «Noche»… line up
/// instead of wrapping ragged. As many columns (up to [maxColumns], three by
/// default) as fit cells of [minCellWidth]: two on a phone, one when a cell
/// would not fit its longest text (narrow screen, large text), so no word ever
/// breaks inside a cell. Rows are balanced: four choices that fit three
/// columns go two and two, not three and one.
///
/// Every group of [ChoicePill]s uses it, also the short ones that always fit a
/// row («Mes | Trimestre | Año | Fechas», «2026 | 2027»): the cells are equal
/// even then. Pass `expand: true` and `reserveIcon: true` to its pills.
class ChoiceGrid extends StatelessWidget {
  /// A grid with cells of an explicit [minCellWidth].
  const ChoiceGrid({
    super.key,
    required this.minCellWidth,
    required this.children,
    this.maxColumns = 3,
  }) : labels = null,
       details = const [],
       sizing = ChoiceGridSizing.longestWord,
       compact = false,
       hasLeading = false,
       leadingSize = 0,
       assert(maxColumns >= 1);

  /// A grid whose cells are sized from the [labels] of its pills (and the
  /// [details] under them) at the reader's text scale, see [minCellWidthFor].
  const ChoiceGrid.forLabels({
    super.key,
    required List<String> this.labels,
    required this.children,
    this.details = const [],
    this.sizing = ChoiceGridSizing.longestWord,
    this.maxColumns = 3,
    this.compact = false,
    this.hasLeading = false,
    this.leadingSize = 0,
  }) : minCellWidth = 0,
       assert(maxColumns >= 1);

  /// A grid of [pills], sized from their own labels and details: what almost
  /// every group of choices uses. Give the pills `expand: true` and
  /// `reserveIcon: true`. [leadingSize] is the size of their `leading`, when
  /// they have one.
  ChoiceGrid.pills({
    super.key,
    required List<ChoicePill> pills,
    this.sizing = ChoiceGridSizing.longestWord,
    this.maxColumns = 3,
    this.leadingSize = 0,
  }) : children = pills,
       labels = [for (final pill in pills) pill.label],
       details = [for (final pill in pills) ?pill.detail],
       compact = pills.any((pill) => pill.compact),
       hasLeading = pills.any((pill) => pill.leading != null),
       minCellWidth = 0,
       assert(maxColumns >= 1);

  /// The narrowest a cell may be: its longest text plus the pill around it
  /// (ignored by [ChoiceGrid.forLabels] and [ChoiceGrid.pills], which measure
  /// it).
  final double minCellWidth;

  final List<Widget> children;

  /// The most columns the grid may use. For a short group that fits a row,
  /// the number of options; the grid falls back to fewer when they do not fit.
  final int maxColumns;

  final List<String>? labels;
  final List<String> details;
  final ChoiceGridSizing sizing;
  final bool compact;
  final bool hasLeading;
  final double leadingSize;

  /// How many columns of [minCellWidth] fit in [width] (1 to [maxColumns]).
  static int columnsFor(
    double width,
    double minCellWidth, {
    int maxColumns = 3,
  }) => ((width + Sp.s) / (minCellWidth + Sp.s)).floor().clamp(1, maxColumns);

  /// The narrowest cell that holds [labels] (and the [details] under them, in
  /// the quieter style) at the reader's text scale, plus the room the pill
  /// takes around its texts. With [ChoiceGridSizing.wholeLabel] it is the
  /// widest whole text; with [ChoiceGridSizing.longestWord] the widest single
  /// word, since the texts may wrap onto more lines. Measured in the bold
  /// style, the widest the pill ever draws.
  static double minCellWidthFor(
    BuildContext context, {
    required Iterable<String> labels,
    Iterable<String> details = const [],
    ChoiceGridSizing sizing = ChoiceGridSizing.longestWord,
    bool compact = false,
    bool hasLeading = false,
    double leadingSize = 0,
  }) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final type = context.type;
    double textWidth(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    Iterable<String> pieces(String text) =>
        sizing == ChoiceGridSizing.wholeLabel
        ? [text]
        : text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty);

    final labelStyle = type.body.copyWith(fontWeight: FontWeight.w800);
    var widest = 0.0;
    for (final label in labels) {
      for (final piece in pieces(label)) {
        final width = textWidth(piece, labelStyle);
        if (width > widest) widest = width;
      }
    }
    for (final detail in details) {
      for (final piece in pieces(detail)) {
        final width = textWidth(piece, type.meta);
        if (width > widest) widest = width;
      }
    }
    return widest +
        ChoicePill.chromeWidth(
          // A cell without a leading is centred with 12 dp sides (and keeps
          // room for the check of the chosen one), like a compact pill.
          compact: compact || !hasLeading,
          hasLeading: hasLeading,
          leadingSize: leadingSize,
        ) +
        1;
  }

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final cell = labels == null
        ? minCellWidth
        : minCellWidthFor(
            context,
            labels: labels!,
            details: details,
            sizing: sizing,
            compact: compact,
            hasLeading: hasLeading,
            leadingSize: leadingSize,
          );
    return LayoutBuilder(
      builder: (context, constraints) {
        var columns = columnsFor(
          constraints.maxWidth,
          cell,
          maxColumns: maxColumns,
        );
        if (columns > children.length) columns = children.length;
        // Balanced rows: 4 choices in 3 columns go 2 and 2, not 3 and 1.
        final rowCount = (children.length / columns).ceil();
        columns = (children.length / rowCount).ceil();
        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += columns) {
          if (rows.isNotEmpty) rows.add(const SizedBox(height: Sp.s));
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var c = 0; c < columns; c++) ...[
                    if (c > 0) const SizedBox(width: Sp.s),
                    Expanded(
                      child: i + c < children.length
                          ? children[i + c]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }
}
