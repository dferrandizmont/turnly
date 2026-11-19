import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Room for the window controls of iPadOS 26 (Windowed Apps): the three dots
/// drawn over the top-left corner of the window.
///
/// Flutter's `MediaQuery.padding` only carries UIKit's `safeAreaInsets`, which
/// do not include them (the status bar is gone in a window and the top inset
/// is a 10 pt margin). UIKit apps keep clear through the corner-adapting
/// layout region of the view, which only Swift can read
/// (`ios/Runner/WindowControlsChannel.swift`). [WindowControlsInset] asks it
/// once, hears of every change from Swift (the region can move without the
/// view's metrics changing) and raises the top padding of every screen
/// under it, so app bars, rails and safe areas leave room as they do for the
/// status bar. Everywhere else (phones, full screen, Android, tests) the
/// answer is 0 and nothing changes.
class WindowControlsInset extends StatefulWidget {
  const WindowControlsInset({super.key, required this.child, this.channel});

  final Widget child;

  /// Replaces the platform channel in tests; with it the platform check is
  /// skipped.
  @visibleForTesting
  final MethodChannel? channel;

  static const channelName = 'app.cuadrante/window_controls';

  @override
  State<WindowControlsInset> createState() => _WindowControlsInsetState();
}

class _WindowControlsInsetState extends State<WindowControlsInset>
    with WidgetsBindingObserver {
  late final MethodChannel? _channel =
      widget.channel ??
      (Platform.isIOS
          ? const MethodChannel(WindowControlsInset.channelName)
          : null);

  double _top = 0;

  @override
  void initState() {
    super.initState();
    final channel = _channel;
    if (channel == null) return;
    WidgetsBinding.instance.addObserver(this);
    // Swift pushes the new value when the region changes.
    channel.setMethodCallHandler((call) async {
      if (call.method == 'topInset') _set((call.arguments as num?)?.toDouble());
    });
    unawaited(_read());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  // Resizing or rotating: a cheap second look, in case the push is late.
  @override
  void didChangeMetrics() => unawaited(_read());

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_read());
  }

  Future<void> _read() async {
    double top;
    try {
      top = (await _channel!.invokeMethod<num>('topInset'))?.toDouble() ?? 0;
    } on PlatformException {
      top = 0;
    } on MissingPluginException {
      top = 0;
    }
    _set(top);
  }

  void _set(double? top) {
    final value = top ?? 0;
    if (!mounted || value == _top) return;
    setState(() => _top = value);
  }

  @override
  Widget build(BuildContext context) {
    if (_top <= 0) return widget.child;
    final media = MediaQuery.of(context);
    // `padding` is `viewPadding` minus what the keyboard covers.
    final viewTop = math.max(_top, media.viewPadding.top);
    final padTop = math.max(0.0, viewTop - media.viewInsets.top);
    if (viewTop == media.viewPadding.top && padTop == media.padding.top) {
      return widget.child;
    }
    return MediaQuery(
      data: media.copyWith(
        padding: media.padding.copyWith(top: padTop),
        viewPadding: media.viewPadding.copyWith(top: viewTop),
      ),
      child: widget.child,
    );
  }
}
