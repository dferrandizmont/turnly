import 'package:flutter/material.dart';

import '../theme/theme_context.dart';

/// Never a blank screen: a 72 dp soft disc with an icon (or, for the empty
/// states that wait for the user's shifts, an [illustration] drawn with the
/// shift discs of the app: `EmptyIllustration`), a headline, one line of
/// body text and an optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.primaryAction = false,
    this.secondaryLabel,
    this.onSecondary,
    this.compact = false,
    this.footer,
    this.illustration,
  });

  final IconData icon;

  /// Replaces the icon disc (design 8.1B). Errors and searches keep the icon.
  final Widget? illustration;
  final String title;
  final String? message;
  final String? actionLabel;

  /// Icon of the action button, when it has one (so an empty-state action and
  /// the one of the screen's own bar are the same button).
  final IconData? actionIcon;
  final VoidCallback? onAction;

  /// Filled (primary) instead of outlined (secondary) action button.
  final bool primaryAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Inline (inside a card or list) instead of centred on the page.
  final bool compact;

  /// Optional extra widget under the actions (e.g. a help link).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final tone = colors.accentTone;

    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (illustration != null)
          illustration!
        else
          ExcludeSemantics(
            child: Container(
              width: Disc.xl,
              height: Disc.xl,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: tone.bg, shape: BoxShape.circle),
              child: Icon(icon, size: IconSize.hero, color: tone.fg, fill: 1),
            ),
          ),
        const SizedBox(height: Sp.l),
        Semantics(
          header: true,
          child: Text(title, style: type.headline, textAlign: TextAlign.center),
        ),
        if (message != null) ...[
          const SizedBox(height: Sp.s),
          Text(
            message!,
            style: type.body.copyWith(color: colors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
        if (actionLabel != null) ...[
          const SizedBox(height: Sp.xxl),
          if (actionIcon == null)
            if (primaryAction)
              FilledButton(onPressed: onAction, child: Text(actionLabel!))
            else
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!))
          else if (primaryAction)
            FilledButton.icon(
              onPressed: onAction,
              icon: Icon(actionIcon, size: IconSize.button),
              label: Text(actionLabel!),
            )
          else
            OutlinedButton.icon(
              onPressed: onAction,
              icon: Icon(actionIcon, size: IconSize.button),
              label: Text(actionLabel!),
            ),
        ],
        if (secondaryLabel != null) ...[
          const SizedBox(height: Sp.s),
          TextButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
        ],
        if (footer != null) ...[const SizedBox(height: Sp.xs), footer!],
      ],
    );

    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Sp.xl),
        child: column,
      );
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: Sp.x3,
          vertical: Sp.xxl,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: column,
        ),
      ),
    );
  }
}
