import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import '../theme/theme_context.dart';

/// Calm yes/no dialog. Returns true only when the user confirms.
///
/// Pass [body] for a plain message, or [content] for a richer body (it wins
/// over [body]). [destructive] tints the confirm button with the danger pair.
Future<bool> showConfirmDialog(
  BuildContext context, {
  String? title,
  String? body,
  Widget? content,
  required String confirmLabel,
  String? cancelLabel,
  bool destructive = false,
  bool scrollable = false,
  Key? confirmKey,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      scrollable: scrollable,
      title: title == null ? null : DialogTitle(title),
      content: content ?? (body == null ? null : Text(body)),
      actions: [
        _cancelButton(ctx, cancelLabel, false),
        _confirmButton(ctx, confirmLabel, destructive, confirmKey, true),
      ],
    ),
  );
  return ok == true;
}

/// Three-way variant: returns true (confirm), false ([alternativeLabel]) or
/// null when cancelled or dismissed.
Future<bool?> showConfirmDialogWithAlternative(
  BuildContext context, {
  String? title,
  String? body,
  required String confirmLabel,
  required String alternativeLabel,
  String? cancelLabel,
  bool destructive = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: title == null ? null : DialogTitle(title),
      content: body == null ? null : Text(body),
      actions: [
        _cancelButton(ctx, cancelLabel, null),
        TextButton(
          key: const ValueKey('confirm-alt'),
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(alternativeLabel),
        ),
        _confirmButton(ctx, confirmLabel, destructive, null, true),
      ],
    ),
  );
}

Widget _cancelButton(BuildContext ctx, String? label, bool? result) =>
    TextButton(
      key: const ValueKey('confirm-cancel'),
      onPressed: () => Navigator.pop(ctx, result),
      child: Text(label ?? ctx.l10n.cancel),
    );

Widget _confirmButton(
  BuildContext ctx,
  String label,
  bool destructive,
  Key? key,
  bool result,
) {
  final colors = ctx.colors;
  return FilledButton(
    key: key ?? const ValueKey('confirm-ok'),
    style: destructive
        ? FilledButton.styleFrom(
            backgroundColor: colors.dangerContainer,
            foregroundColor: colors.danger,
          )
        : null,
    onPressed: () => Navigator.pop(ctx, result),
    child: Text(label),
  );
}

/// The title of a dialog at the reader's text size, but never so big that a
/// word breaks in the middle: «¿Descartar la secuencia?» came out as
/// «¿Descarta / r la secuencia / ?» at the largest accessibility size on a
/// phone (1.2.0 QA, iPhone F8). If the longest word does not fit the width,
/// the title takes the biggest size (not below the normal one) at which it
/// does; it still wraps between words.
class DialogTitle extends StatelessWidget {
  const DialogTitle(this.text, {super.key});

  final String text;

  /// The title box of an `AlertDialog`: the window minus the 40 dp it keeps
  /// at each side, up to 560 dp wide, minus the 24 dp of padding at each
  /// side. Computed, not measured: an `AlertDialog` asks its title for its
  /// intrinsic width, which a `LayoutBuilder` cannot answer.
  static double boxWidth(double windowWidth) =>
      math.min(windowWidth - _sideInset * 2, Sp.dialogMaxWidth) -
      _titlePadding * 2;

  /// What an `AlertDialog` keeps free at each side of the window.
  static const double _sideInset = 40;

  /// The padding at each side of its title.
  static const double _titlePadding = 24;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final style = DefaultTextStyle.of(context).style;
    final width = boxWidth(MediaQuery.sizeOf(context).width);
    final size = style.fontSize ?? 14;
    var factor = scaler.scale(size) / size;
    while (factor > 1 && _longestWord(context, style, factor) > width) {
      factor = math.max(1.0, factor - 0.1);
    }
    return Text(text, textScaler: TextScaler.linear(factor));
  }

  double _longestWord(BuildContext context, TextStyle style, double factor) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: TextScaler.linear(factor),
    )..layout();
    final width = painter.minIntrinsicWidth;
    painter.dispose();
    return width;
  }
}
