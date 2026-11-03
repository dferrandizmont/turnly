import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/device_events_providers.dart';

/// Reads the events of the phone again when the app comes back to the front:
/// the calendar of the phone may have changed while the app was away (and
/// the person may have given the permission in the settings of the system in
/// the meantime).
///
/// Nothing is read at start-up: the screens ask for what they show, and only
/// when they show it. Shows nothing; it only wraps [child].
class DeviceEventsHost extends ConsumerStatefulWidget {
  const DeviceEventsHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<DeviceEventsHost> createState() => _DeviceEventsHostState();
}

class _DeviceEventsHostState extends ConsumerState<DeviceEventsHost> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => refreshDeviceEvents(ref),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
