import 'dart:async';

import '../../schedule/domain/schedule_domain.dart';
import '../data/dnd_channel.dart';
import '../domain/dnd_planner.dart';
import '../domain/dnd_settings.dart';

/// Keeps the silence windows of the device equal to the plan of the current
/// schedule and settings (P13, docs/ola3-logica.md).
///
/// - [resync] runs now; [requestResync] waits [debounce] of quiet first (the
///   calendar emits a change for every day painted).
/// - Runs are serialised and coalesced: while one is in flight, further
///   requests only mark it dirty and it runs once more, so a burst of changes
///   costs at most two reschedules.
/// - Without the «Acceso a No molestar» permission nothing is armed (and what
///   was is cancelled): the phone is never silenced without permission.
/// - With the silence off (nothing configured, or the global switch off) the
///   armed windows are cancelled too, so the phone is freed.
/// - The horizon is the one of the shift alarms ([horizonDays]), so both run
///   out at the same time.
class DndSync {
  DndSync({
    required this.channel,
    required this.loadSettings,
    required this.readSchedule,
    required this.now,
    this.horizonDays,
    this.debounce = const Duration(seconds: 1),
    this.onError,
  });

  /// The device side (Android only; elsewhere a channel that does nothing).
  final DndChannel channel;

  /// The stored settings, read fresh on every run.
  final Future<DndSettings> Function() loadSettings;

  /// The schedule of the primary calendar, read fresh on every run.
  final FutureOr<Schedule> Function() readSchedule;

  /// "Now" (the clock of the app, so the tests can fix it).
  final DateTime Function() now;

  /// Days ahead that get planned. Null = [dndHorizonDays] (the horizon of
  /// the shift alarms).
  final Future<int> Function()? horizonDays;

  /// How long [requestResync] waits before it runs.
  final Duration debounce;

  /// Called with the errors of a run (it never stops the later ones).
  final void Function(Object error, StackTrace stack)? onError;

  /// The windows of the last run that reached the channel.
  List<DndWindow> get lastWindows => _lastWindows;
  List<DndWindow> _lastWindows = const [];

  /// Number of runs that reached the channel (for tests and diagnostics).
  int runs = 0;

  Timer? _timer;
  Future<void>? _loop;
  bool _dirty = false;
  bool _disposed = false;

  /// Debounced: the plan is recomputed [debounce] after the last call.
  void requestResync() {
    if (_disposed) return;
    _timer?.cancel();
    _timer = Timer(debounce, () {
      _timer = null;
      unawaited(resync());
    });
  }

  /// Completes when the (possibly coalesced) plan is up to date.
  Future<void> resync() {
    if (_disposed) return Future.value();
    _timer?.cancel();
    _timer = null;
    _dirty = true;
    return _loop ??= _run();
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _run() async {
    await null; // never complete synchronously (see `_loop = null` below)
    try {
      while (_dirty && !_disposed) {
        _dirty = false;
        try {
          await _once();
        } catch (error, stack) {
          // A failed run must not stop later ones; the next change retries.
          if (!_disposed) onError?.call(error, stack);
        }
      }
    } finally {
      _loop = null;
    }
  }

  Future<void> _once() async {
    final settings = await loadSettings();
    if (_disposed) return;

    // The silence off: whatever was armed is cancelled and the phone freed.
    if (!settings.anyActive) {
      await channel.cancelAll();
      _lastWindows = const [];
      runs++;
      return;
    }

    // Without the permission the phone cannot be silenced: nothing is armed
    // (and what was, if the permission was taken away, is cancelled).
    final permission = await channel.permissionStatus();
    if (_disposed) return;
    if (permission != DndPermission.granted) {
      await channel.cancelAll();
      _lastWindows = const [];
      runs++;
      return;
    }

    final days = await (horizonDays?.call() ?? Future.value(dndHorizonDays));
    if (_disposed) return;
    final windows = planDndWindows(
      schedule: await readSchedule(),
      settings: settings,
      now: now(),
      horizonDays: days,
    );
    if (_disposed) return;
    runs++;
    await channel.replaceWindows(windows);
    _lastWindows = windows;
  }
}
