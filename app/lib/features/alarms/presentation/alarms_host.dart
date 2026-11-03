import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/app_date_format.dart';
import '../../../core/l10n/l10n.dart';
import '../../calendar/application/schedule_controller.dart';
import '../application/alarm_providers.dart';
import '../data/alarm_foreground_relay.dart';
import '../data/alarm_system.dart' show ClockChange;
import '../domain/alarm_strings.dart';

/// Keeps the device alarms in step with the app: resyncs at start, on resume,
/// when the schedule changes (debounced) and when the alarm settings change.
/// While mounted it also answers the background renewal (A1, Android): when
/// WorkManager runs it in this process, the app replans instead.
/// Shows nothing; it only wraps [child].
class AlarmsHost extends ConsumerStatefulWidget {
  const AlarmsHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AlarmsHost> createState() => _AlarmsHostState();
}

class _AlarmsHostState extends ConsumerState<AlarmsHost> {
  late final AppLifecycleListener _lifecycle;
  StreamSubscription<ClockChange>? _clock;
  AlarmForegroundRelay? _relay;
  bool _started = false;
  String? _locale;
  bool? _hour12;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      // A resume always replans, which also re-reads the device time zone
      // (`LocalAlarmScheduler.replaceAll`): the cold path of a zone change
      // that happened while the app was in the background.
      onResume: () => ref.read(alarmSyncProvider).resync(),
    );
    // H-T11-4: the zone or the time changed while the app is alive (and in
    // front, where no resume will come). The alarms are wall-clock times,
    // so they have to be placed again on the new zone at once.
    _clock = ref
        .read(alarmSystemProvider)
        .clockChanges
        .listen((_) => ref.read(alarmSyncProvider).resync());
    // A1: the background renewal hands its run to the live app, so only one
    // planner writes the pending alarms at a time.
    // `main` already listens (requests that came early are held until now);
    // listening here too covers a relay that was not started (tests).
    _relay = ref.read(alarmForegroundRelayProvider)
      ?..open(() => ref.read(alarmSyncProvider).resync());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = context.l10n;
    final format = AppDateFormat.of(context);
    final sync = ref.read(alarmSyncProvider);
    sync.strings = AlarmStrings.fromL10n(l10n, clock: alarmClock(format));
    if (!_started) {
      _started = true;
      // First run once the strings exist.
      sync.resync();
    } else if (_locale != l10n.localeName || _hour12 != format.hour12) {
      // Ajustes › Idioma and › Formato de hora: the pending notifications
      // carry their texts, so they are scheduled again in the new language
      // and with the new clock.
      sync.resync();
    }
    _locale = l10n.localeName;
    _hour12 = format.hour12;
  }

  @override
  void dispose() {
    unawaited(_clock?.cancel());
    // Detach only: the relay keeps listening for the life of the isolate, so
    // a later request is held instead of finding nobody.
    _relay?.detach();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sync = ref.read(alarmSyncProvider);
    ref.listen(scheduleControllerProvider, (previous, next) {
      // Only a different schedule matters (not undo/redo availability).
      if (!identical(previous?.schedule, next.schedule)) {
        sync.requestResync();
      }
    });
    ref.listen(alarmSettingsProvider, (previous, next) {
      final before = previous?.asData?.value;
      final after = next.asData?.value;
      if (after != null && before != null && before != after) {
        sync.resync();
      }
    });
    return widget.child;
  }
}
