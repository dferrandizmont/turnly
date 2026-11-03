import 'package:flutter/services.dart';

import '../domain/dnd_planner.dart';
import '../domain/dnd_settings.dart';

/// The device side of the silence windows (P13, docs/ola3-logica.md).
///
/// Android only: the app asks for «Acceso a No molestar» and programs two
/// exact alarms per window (one to silence the phone, one to free it). The
/// implementation is `PlatformDndChannel`; the hosts without it (iOS, where
/// Focus is not programmable by apps, and the tests) use [NoDndChannel] or
/// [FakeDndChannel].
///
/// The contract, in full (the native side is `DndChannel.kt`):
///
/// - [replaceWindows] makes the armed windows exactly the ones it gets: the
///   new ones are armed and the ones that are gone are cancelled. Only the
///   windows of the app are ever touched; the alarms of the shift do not
///   share their ids with these.
/// - A window whose start is already past and whose end is not is **active**:
///   the phone is silenced **at once** (an alarm in the past never rings) and
///   freed at its end. The window keeps its real start, so the device can
///   tell an active window from one that is still to come.
/// - The mode the phone had before is read when it is silenced and put back
///   when the window ends. **Only if the user did not change it by hand** in
///   the meantime: if the phone is no longer in the filter the app put it in,
///   the app does not touch it. That check lives in the native side, because
///   the window may end with the app closed.
/// - [cancelAll] cancels every armed window and frees the phone, with the
///   same rule about a change made by hand.
abstract interface class DndChannel {
  /// Whether this platform has silence windows at all (Android). iOS has no
  /// programmable Focus, so the whole feature is hidden there. Read
  /// synchronously: the screens decide with it whether to show anything.
  bool get supported;

  /// Whether the system lets the app change the interruption filter.
  /// Never prompts.
  Future<DndPermission> permissionStatus();

  /// Opens the system's «Acceso a No molestar» screen, where the user gives
  /// the permission. False when no screen opened.
  Future<bool> openPermissionSettings();

  /// The interruption filter the phone is in right now, or null when it
  /// cannot be read.
  Future<DndFilter?> currentFilter();

  /// Makes the armed windows exactly [windows]: it arms the alarms of the
  /// new ones and cancels the ones that are gone. The windows of the app
  /// only are ever touched.
  ///
  /// A window that is running right now ([DndWindow.isActiveAt]) silences
  /// the phone at once; the others are armed for their start.
  Future<void> replaceWindows(List<DndWindow> windows);

  /// Cancels every armed window (the silence is off) and frees the phone,
  /// unless the user changed the mode by hand.
  Future<void> cancelAll();
}

/// The Android implementation, over the platform channel
/// (`app.cuadrante/dnd`, `DndChannel.kt`).
class PlatformDndChannel implements DndChannel {
  PlatformDndChannel({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'app.cuadrante/dnd';

  final MethodChannel _channel;

  @override
  bool get supported => true;

  @override
  Future<DndPermission> permissionStatus() async {
    final reply = await _invoke<String>('permissionStatus');
    return switch (reply) {
      'granted' => DndPermission.granted,
      'denied' => DndPermission.denied,
      _ => DndPermission.unsupported,
    };
  }

  @override
  Future<bool> openPermissionSettings() async =>
      await _invoke<bool>('openPermissionSettings') ?? false;

  @override
  Future<DndFilter?> currentFilter() async {
    final reply = await _invoke<String>('currentFilter');
    if (reply == null) return null;
    return DndFilter.values.where((f) => f.name == reply).firstOrNull;
  }

  @override
  Future<void> replaceWindows(List<DndWindow> windows) async {
    await _invoke<Object?>('replaceWindows', {
      'windows': [
        for (final window in windows)
          {
            'id': window.id,
            'start': window.start.toUtc().millisecondsSinceEpoch,
            'end': window.end.toUtc().millisecondsSinceEpoch,
            'filter': window.filter.name,
          },
      ],
    });
  }

  @override
  Future<void> cancelAll() async {
    await _invoke<Object?>('cancelAll');
  }

  /// A call that never throws: a channel that is not there (iOS, a test
  /// without the platform) answers with the safe value.
  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}

/// A platform without silence windows (iOS: Focus is not programmable by
/// apps; desktop and the tests).
class NoDndChannel implements DndChannel {
  const NoDndChannel();

  @override
  bool get supported => false;

  @override
  Future<DndPermission> permissionStatus() async => DndPermission.unsupported;

  @override
  Future<bool> openPermissionSettings() async => false;

  @override
  Future<DndFilter?> currentFilter() async => null;

  @override
  Future<void> replaceWindows(List<DndWindow> windows) async {}

  @override
  Future<void> cancelAll() async {}
}

/// For tests: the answers are fields and the calls are recorded.
class FakeDndChannel implements DndChannel {
  FakeDndChannel({
    this.supported = true,
    this.permission = DndPermission.granted,
    this.filter = DndFilter.priority,
    this.settingsOpen = true,
  });

  /// Whether the platform has silence windows (Android).
  @override
  bool supported;

  /// What [permissionStatus] answers.
  DndPermission permission;

  /// What [currentFilter] answers.
  DndFilter? filter;

  /// What [openPermissionSettings] answers.
  bool settingsOpen;

  /// The windows of the last [replaceWindows].
  List<DndWindow> windows = const [];

  /// Every set of windows handed over, in order.
  final List<List<DndWindow>> history = [];

  int replaceCalls = 0;
  int cancelCalls = 0;
  int openedSettings = 0;

  @override
  Future<DndPermission> permissionStatus() async => permission;

  @override
  Future<bool> openPermissionSettings() async {
    openedSettings++;
    return settingsOpen;
  }

  @override
  Future<DndFilter?> currentFilter() async => filter;

  @override
  Future<void> replaceWindows(List<DndWindow> windows) async {
    replaceCalls++;
    this.windows = List.unmodifiable(windows);
    history.add(this.windows);
  }

  @override
  Future<void> cancelAll() async {
    cancelCalls++;
    windows = const [];
  }
}
