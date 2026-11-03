import 'dart:async';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

/// A lock shared by every isolate of this process (the app's and the ones
/// WorkManager starts), over the process-wide [IsolateNameServer]:
/// `registerPortWithName` only succeeds when nobody holds the name, which is
/// an atomic test-and-set. File locks cannot do this: on Android they belong
/// to the process, so two isolates of the same process would both get them.
///
/// The holder answers pings on its port. A name whose holder does not answer
/// within [probe] (its isolate died while holding it) is taken over.
class IsolateMutex {
  IsolateMutex(
    this.name, {
    this.probe = const Duration(seconds: 2),
    this.retryEvery = const Duration(milliseconds: 500),
  });

  final String name;

  /// How long a holder has to answer before it counts as dead.
  final Duration probe;

  /// How often [acquire] with a wait tries again.
  final Duration retryEvery;

  ReceivePort? _held;

  /// Whether this instance holds the lock.
  bool get isHeld => _held != null;

  /// Takes the lock once; `false` when a live holder has it.
  Future<bool> tryAcquire() async {
    if (_held != null) return false;
    final port = ReceivePort();
    port.listen((message) {
      if (message is SendPort) message.send(true);
    });
    if (IsolateNameServer.registerPortWithName(port.sendPort, name)) {
      _held = port;
      return true;
    }
    final holder = IsolateNameServer.lookupPortByName(name);
    if (holder != null && await _answers(holder)) {
      port.close();
      return false;
    }
    // Released meanwhile, or held by a dead isolate: take it over.
    if (IsolateNameServer.lookupPortByName(name) == holder) {
      IsolateNameServer.removePortNameMapping(name);
    }
    if (IsolateNameServer.registerPortWithName(port.sendPort, name)) {
      _held = port;
      return true;
    }
    port.close();
    return false;
  }

  Future<bool> _answers(SendPort holder) async {
    final reply = ReceivePort();
    try {
      holder.send(reply.sendPort);
      await reply.first.timeout(probe);
      return true;
    } on TimeoutException {
      return false;
    } finally {
      reply.close();
    }
  }

  /// Takes the lock, trying again every [retryEvery] for up to [wait]
  /// (`Duration.zero`: one try). `false` if it never got it.
  Future<bool> acquire({Duration wait = Duration.zero}) async {
    final deadline = DateTime.now().add(wait);
    while (true) {
      if (await tryAcquire()) return true;
      if (!DateTime.now().isBefore(deadline)) return false;
      await Future<void>.delayed(retryEvery);
    }
  }

  /// Gives the lock back (only the mapping that is still ours).
  void release() {
    final port = _held;
    if (port == null) return;
    _held = null;
    if (IsolateNameServer.lookupPortByName(name) == port.sendPort) {
      IsolateNameServer.removePortNameMapping(name);
    }
    port.close();
  }
}
