import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../calendar/application/schedule_controller.dart';
import '../application/calendar_sync_providers.dart';
import '../domain/calendar_sync_settings.dart';
import 'export_texts.dart';

/// Keeps the phone's calendar up to date with the schedule («Mantener al
/// día», C8): a pass when the app starts, when it comes back to the front
/// and, debounced, when the schedule changes. When a pass has to turn it off
/// (the permission or a calendar is gone) it says so once with a notice.
/// Shows nothing; it only wraps [child].
class CalendarSyncHost extends ConsumerStatefulWidget {
  const CalendarSyncHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<CalendarSyncHost> createState() => _CalendarSyncHostState();
}

class _CalendarSyncHostState extends ConsumerState<CalendarSyncHost> {
  late final AppLifecycleListener _lifecycle;
  StreamSubscription<CalendarSyncNotice>? _notices;

  @override
  void initState() {
    super.initState();
    final sync = ref.read(calendarSyncProvider);
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(sync.sync()));
    _notices = sync.notices.listen(_showNotice);
    // Nothing happens when it is off: the pass reads one settings row.
    unawaited(sync.sync());
  }

  void _showNotice(CalendarSyncNotice notice) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        appSnackBar(
          content: Text(calendarSyncNoticeText(context.l10n, notice)),
        ),
      );
  }

  @override
  void dispose() {
    unawaited(_notices?.cancel());
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(scheduleControllerProvider, (previous, next) {
      // Only a different schedule matters (not undo/redo availability).
      if (!identical(previous?.schedule, next.schedule)) {
        ref.read(calendarSyncProvider).requestSync();
      }
    });
    return widget.child;
  }
}
