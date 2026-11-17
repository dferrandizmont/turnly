import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/theme_context.dart';
import 'keyboard_done_bar.dart';

/// The one way to open a bottom sheet: root navigator, scroll-controlled
/// (tall content and the keyboard never clip it), safe area, max content
/// width, and the theme's radius and drag handle.
///
/// With [padded] the builder's content is wrapped in [AppSheetBody]
/// (scroll view, page gutter, keyboard inset), the layout most sheets want.
/// Without it the builder owns its layout (lists with their own scroll,
/// search sheets) and the keyboard inset.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool padded = false,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    // The dimmed area is a button for TalkBack: it says what it does (it
    // read «Sombreado», H-T18-3).
    barrierLabel: context.l10n.close,
    constraints: const BoxConstraints(maxWidth: Sp.maxContentWidth),
    builder: padded ? (ctx) => AppSheetBody(child: builder(ctx)) : builder,
  );
}

/// Standard sheet body: bottom safe area, page gutter, keyboard inset.
///
/// Tapping an empty part of the sheet closes the keyboard, and while a
/// number pad is up (it has no Return key on iOS) a [KeyboardDoneBar] sits
/// above it (1.1.0 QA, F4). Buttons and fields take their own taps first.
/// The field being typed in is scrolled above the pad and the bar, so the
/// person never types blind (1.2.0 QA, iPhone F5).
class AppSheetBody extends StatefulWidget {
  const AppSheetBody({super.key, required this.child});

  final Widget child;

  @override
  State<AppSheetBody> createState() => _AppSheetBodyState();
}

class _AppSheetBodyState extends State<AppSheetBody> {
  bool _hadBar = false;
  BuildContext? _revealed;
  Timer? _settle;

  @override
  void dispose() {
    _settle?.cancel();
    super.dispose();
  }

  /// Brings the focused field into view once the bar has made room for
  /// itself, and again when the keyboard has finished rising.
  void _reveal(bool bar) {
    final field = FocusManager.instance.primaryFocus?.context;
    final fresh = bar && (!_hadBar || !identical(field, _revealed));
    _hadBar = bar;
    if (!bar) {
      _revealed = null;
      _settle?.cancel();
      return;
    }
    if (!fresh) return;
    _revealed = field;
    void show() {
      final ctx = FocusManager.instance.primaryFocus?.context;
      if (!mounted || ctx == null || !ctx.mounted) return;
      final box = ctx.findRenderObject();
      final scrollable = Scrollable.maybeOf(ctx);
      if (box is! RenderBox || !box.attached || scrollable == null) return;
      // The sheet reaches under the keyboard and the Done bar: what is
      // visible ends above both, with a line of room for a helper or error.
      final media = MediaQuery.of(context);
      final visibleBottom =
          media.size.height -
          media.viewInsets.bottom -
          KeyboardDoneBar.height -
          Sp.xxl;
      final top = box.localToGlobal(Offset.zero).dy;
      final bottom = top + box.size.height;
      var delta = bottom - visibleBottom;
      if (delta <= 0) return;
      // Never push the field itself off the top.
      delta = math.min(delta, top - media.padding.top - Sp.xl);
      if (delta <= 0) return;
      final position = scrollable.position;
      final target = (position.pixels + delta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      // Reduce motion: the page jumps instead of gliding.
      if (MediaQuery.disableAnimationsOf(context)) {
        position.jumpTo(target);
      } else {
        position.animateTo(target, duration: Motion.state, curve: Motion.curve);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => show());
    _settle?.cancel();
    _settle = Timer(const Duration(milliseconds: 400), show);
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: ListenableBuilder(
        listenable: FocusManager.instance,
        builder: (context, _) {
          // Only the sheet on top: one opened from another (the form of a
          // type over the list) leaves the one below without the bar.
          final bar =
              inset > 0 &&
              (ModalRoute.of(context)?.isCurrent ?? true) &&
              numberPadHasFocus();
          _reveal(bar);
          return Stack(
            children: [
              SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    Sp.page,
                    0,
                    Sp.page,
                    Sp.l + inset + (bar ? KeyboardDoneBar.height : 0),
                  ),
                  child: widget.child,
                ),
              ),
              if (bar)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: inset,
                  child: const KeyboardDoneBar(),
                ),
            ],
          );
        },
      ),
    );
  }
}
