import 'dart:async';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

/// Name under which the app's main isolate listens for renewal requests.
const String alarmForegroundPortName = 'es.cuadrante.app/alarms.resync';

/// How long the background renewal waits for the app to replan.
const Duration alarmForegroundTimeout = Duration(seconds: 60);

/// Lets the background renewal (A1) hand its work to the app when the app is
/// alive in the same process, so only one planner ever writes the pending
/// alarms at a time (the app's runs are already serialised by `AlarmSync`).
///
/// The app's main isolate [listen]s as early as it can (`main`, before the
/// database opens), so a run that starts while the app is starting already
/// finds it; requests that arrive before there is anything to run are held
/// until `AlarmsHost` [attach]es the resync (the background side waits up to
/// [alarmForegroundTimeout]). The background isolate calls
/// [askForegroundToResync]: the request goes through the process-wide
/// [IsolateNameServer], so it only reaches an app running in this very
/// process.
///
/// If the background side gives up waiting (a slow resync) it forgets the
/// mapping; the relay registers itself again as soon as it notices that the
/// name points nowhere (after each answer, on [listen] and [attach]), so the
/// app is never left disconnected for the rest of its life. It never takes
/// the name back from another relay that registered it meanwhile.
class AlarmForegroundRelay {
  AlarmForegroundRelay({
    this.portName = alarmForegroundPortName,
    this.answerFirst = false,
  });

  final String portName;

  /// Answer "the app does it" right away and run the work afterwards, so the
  /// background side never waits for (nor times out on) long work such as a
  /// folder copy. Off for the alarms: their background side waits for the
  /// replan to finish.
  final bool answerFirst;
  ReceivePort? _port;
  Future<void> Function()? _resync;
  final List<SendPort> _held = [];

  /// Whether it is registered and receiving requests.
  bool get isListening => _port != null;

  /// Starts receiving requests (held until [attach]). Replaces a mapping left
  /// by an earlier isolate (a hot restart, an engine that died without
  /// closing it). Calling it again while listening does nothing.
  void listen() {
    if (_port != null) {
      _registerAgainIfLost();
      return;
    }
    final port = ReceivePort();
    IsolateNameServer.removePortNameMapping(portName);
    IsolateNameServer.registerPortWithName(port.sendPort, portName);
    port.listen((message) {
      if (message is! SendPort) return;
      if (_resync == null) {
        _held.add(message);
      } else {
        unawaited(_answer(message));
      }
    });
    _port = port;
  }

  /// Answers requests with [resync] from now on, the held ones first.
  void attach(Future<void> Function() resync) {
    _resync = resync;
    _registerAgainIfLost();
    final held = [..._held];
    _held.clear();
    for (final reply in held) {
      unawaited(_answer(reply));
    }
  }

  /// Stops answering (requests are held again) but keeps listening.
  void detach() => _resync = null;

  /// [listen] and [attach] in one go.
  void open(Future<void> Function() resync) {
    listen();
    attach(resync);
  }

  Future<void> _answer(SendPort reply) async {
    if (answerFirst) reply.send(true);
    try {
      await _resync?.call();
    } catch (_) {
      // AlarmSync reports its own errors; the request was still handled.
    }
    if (!answerFirst) reply.send(true);
    _registerAgainIfLost();
  }

  /// The background side forgot the mapping (it timed out while this relay
  /// was busy): register again. A name now held by another relay is left
  /// alone.
  void _registerAgainIfLost() {
    final port = _port;
    if (port == null) return;
    if (IsolateNameServer.lookupPortByName(portName) != null) return;
    IsolateNameServer.registerPortWithName(port.sendPort, portName);
  }

  /// Stops listening. Leaves alone a mapping that is not ours any more.
  void close() {
    _resync = null;
    _held.clear();
    final port = _port;
    if (port == null) return;
    _port = null;
    if (IsolateNameServer.lookupPortByName(portName) == port.sendPort) {
      IsolateNameServer.removePortNameMapping(portName);
    }
    port.close();
  }
}

/// The app's relay (Android): `main` makes it listen before anything else,
/// `AlarmsHost` attaches and detaches its resync.
final AlarmForegroundRelay appAlarmForegroundRelay = AlarmForegroundRelay();

/// From the background isolate: asks the app alive in this process to replan
/// its alarms and waits for it. True when the app did it; false when there
/// is no app in this process or it did not answer within [timeout] (then
/// the mapping it left is forgotten: its isolate is gone or stuck, and the
/// caller does the work itself).
Future<bool> askForegroundToResync({
  String portName = alarmForegroundPortName,
  Duration timeout = alarmForegroundTimeout,
}) async {
  final target = IsolateNameServer.lookupPortByName(portName);
  if (target == null) return false;
  final reply = ReceivePort();
  try {
    target.send(reply.sendPort);
    await reply.first.timeout(timeout);
    return true;
  } on TimeoutException {
    if (IsolateNameServer.lookupPortByName(portName) == target) {
      IsolateNameServer.removePortNameMapping(portName);
    }
    return false;
  } finally {
    reply.close();
  }
}
