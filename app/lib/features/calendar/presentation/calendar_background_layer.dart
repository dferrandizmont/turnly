import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_context.dart';
import '../application/calendar_background_providers.dart';

/// Draws the chosen picture behind the month (UX · Extras visuales): the
/// picture fills the body, a veil of `background` goes over it so everything
/// keeps reading, and [child] (the month) is drawn on top. The cells of the
/// grid and the cards keep their own opaque backgrounds, so their contrast is
/// the same as without a picture.
///
/// Without a picture (or while it is being read) it is just [child]: nothing
/// changes for an installation that never picked one.
class CalendarBackgroundLayer extends ConsumerWidget {
  const CalendarBackgroundLayer({super.key, required this.child});

  final Widget child;

  /// Opacity of the veil over the picture. High on purpose: the picture is a
  /// quiet texture, and the text drawn on the page background (the date, the
  /// month, the weekday row) keeps its contrast.
  static const double veilOpacity = 0.9;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = ref.watch(calendarBackgroundFileProvider).value;
    if (file == null) return child;
    final colors = context.colors;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: colors.background),
        Image.file(
          file,
          fit: BoxFit.cover,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
        ColoredBox(color: colors.background.withValues(alpha: veilOpacity)),
        child,
      ],
    );
  }
}
