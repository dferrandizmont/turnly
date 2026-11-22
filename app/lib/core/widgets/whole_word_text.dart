import 'package:flutter/widgets.dart';

import '../format/text_measure.dart';

/// A text that wraps between words and, when its longest word does not fit the
/// width it is given, is drawn a little smaller until it does: a word is never
/// cut in the middle («Nig / ht», «22:0 / 0», «¿Cuándo empieza / s?»).
///
/// [Text] breaks inside a word as soon as the word is wider than the line, and
/// at the largest accessibility sizes in a narrow box (the side pane of a
/// phone in landscape, a card beside an icon) that happens to shift names,
/// hours and dates (iOS 1.2.2 QA, F1 and F2). Here the text keeps the size the
/// reader chose whenever it fits, which is every time at the usual sizes, so
/// nothing changes there.
///
/// It never shrinks below [minTextScale] times the normal size, so a very
/// narrow box ends up with text as large as an ordinary phone shows, not
/// smaller; past that the word is the one that breaks. It needs a bounded
/// width and cannot be asked for its intrinsic size (a [LayoutBuilder]).
class WholeWordText extends StatelessWidget {
  const WholeWordText(
    String text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.minTextScale = 1,
  }) : span = null,
       _text = text;

  const WholeWordText.rich(
    InlineSpan this.span, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.minTextScale = 1,
  }) : _text = null;

  final String? _text;
  final InlineSpan? span;

  /// The base style, as in [Text.style].
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  /// The smallest the text is drawn, in times the normal (unscaled) size.
  final double minTextScale;

  InlineSpan get _span => span ?? TextSpan(text: _text);

  /// The share of the reader's text size at which the longest word of [span]
  /// fits in [width]: 1 when it already does, never below what leaves the text
  /// at [minTextScale] times its normal size.
  @visibleForTesting
  static double scaleToFit(
    BuildContext context,
    InlineSpan span,
    TextStyle? style,
    double width, {
    double minTextScale = 1,
  }) {
    if (!width.isFinite) return 1;
    final size = style?.fontSize ?? 14;
    final base = MediaQuery.textScalerOf(context).scale(size) / size;
    final drawn = effectiveTextStyle(context, style ?? const TextStyle());
    final direction = Directionality.of(context);

    double longestAt(double factor) {
      final painter = TextPainter(
        text: TextSpan(style: drawn, children: [span]),
        textDirection: direction,
        textScaler: TextScaler.linear(base * factor),
      )..layout();
      final longest = painter.minIntrinsicWidth;
      painter.dispose();
      return longest;
    }

    final needed = longestAt(1);
    if (needed <= width) return 1;
    final floor = base <= 0 ? 1.0 : (minTextScale / base).clamp(0.0, 1.0);
    var factor = (width / needed).clamp(floor, 1.0);
    // Widths do not scale exactly with the size (hinting, spacing): step down
    // until it fits or the floor is reached.
    while (factor > floor && longestAt(factor) > width) {
      factor = (factor - 0.03).clamp(floor, 1.0);
    }
    return factor;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final factor = scaleToFit(
          context,
          _span,
          style,
          box.maxWidth,
          minTextScale: minTextScale,
        );
        TextScaler? scaler;
        if (factor < 1) {
          final size = style?.fontSize ?? 14;
          final base = MediaQuery.textScalerOf(context).scale(size) / size;
          scaler = TextScaler.linear(base * factor);
        }
        final text = _text;
        if (text != null) {
          return Text(
            text,
            style: style,
            maxLines: maxLines,
            overflow: overflow,
            textAlign: textAlign,
            textScaler: scaler,
          );
        }
        return Text.rich(
          _span,
          style: style,
          maxLines: maxLines,
          overflow: overflow,
          textAlign: textAlign,
          textScaler: scaler,
        );
      },
    );
  }
}
