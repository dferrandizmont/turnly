import 'package:flutter/widgets.dart';

import '../theme/theme_context.dart';

/// [AnimatedSize] that follows «reducir movimiento»: with it the child just
/// changes size at once. (An [AnimatedSize] with a zero duration restarts its
/// animation inside its own layout, which Flutter does not allow.)
class MotionSize extends StatelessWidget {
  const MotionSize({
    super.key,
    required this.child,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final duration = Motion.of(context, Motion.state);
    if (duration == Duration.zero) return child;
    return AnimatedSize(
      duration: duration,
      curve: Motion.curve,
      alignment: alignment,
      child: child,
    );
  }
}
