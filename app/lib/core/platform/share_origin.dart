import 'package:flutter/widgets.dart';

/// Rect for `ShareParams.sharePositionOrigin`. On iPad the share sheet is a
/// popover and `share_plus` fails without a non-zero origin in global
/// coordinates; other platforms ignore it.
///
/// Uses the global rect of [context]'s render box (the button that triggered
/// the share) when it is mounted and laid out with a non-empty size, or the
/// rect remembered by [rememberShareOrigin] if it is recent and still inside
/// the view. Otherwise a small rect at the centre of the first view. Never zero.
Rect shareOrigin([BuildContext? context]) {
  final pending = _pending;
  final pendingAt = _pendingAt;
  _pending = null;
  _pendingAt = null;
  if (context != null) {
    final rect = _rectOf(context);
    if (rect != null && _insideView(rect)) return rect;
  } else if (pending != null &&
      pendingAt != null &&
      DateTime.now().difference(pendingAt) <= pendingLifetime &&
      _insideView(pending)) {
    return pending;
  }
  return _viewCentre();
}

/// How long a remembered button rect stays usable. An export that takes longer
/// (or fails before sharing) falls back to the centre of the view.
const pendingLifetime = Duration(seconds: 30);

Rect? _pending;
DateTime? _pendingAt;

/// Remembers the rect of [context] (the button the person just pressed) for
/// the next [shareOrigin] call without a context, so the share can be started
/// further down (providers, senders) without threading a `BuildContext`
/// through them. Consumed once; it expires after [pendingLifetime] and is
/// ignored if the window changed so that it no longer fits.
void rememberShareOrigin(BuildContext context) {
  _pending = _rectOf(context);
  _pendingAt = _pending == null ? null : DateTime.now();
}

Rect? _rectOf(BuildContext context) {
  if (!context.mounted) return null;
  final box = context.findRenderObject();
  if (box is RenderBox && box.hasSize && box.attached) {
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (!rect.isEmpty && rect.isFinite) return rect;
  }
  return null;
}

Size? _viewSize() {
  final views = WidgetsBinding.instance.platformDispatcher.views;
  if (views.isEmpty) return null;
  final view = views.first;
  final size = view.physicalSize / view.devicePixelRatio;
  return size.width > 0 && size.height > 0 ? size : null;
}

bool _insideView(Rect rect) {
  final size = _viewSize();
  if (size == null) return true;
  return (Offset.zero & size).overlaps(rect);
}

Rect _viewCentre() {
  const side = 2.0;
  final size = _viewSize();
  final centre = size == null
      ? const Offset(200, 400)
      : Offset(size.width / 2, size.height / 2);
  return Rect.fromCenter(center: centre, width: side, height: side);
}
