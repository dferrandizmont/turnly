import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../calendar/application/schedule_controller.dart';
import '../application/share_link_controller.dart';

/// How long the schedule must stay still before the feed is rebuilt: a run
/// of quick edits (painting a week) gives one upload, not one per day.
const Duration shareLinkDebounce = Duration(seconds: 20);

/// Keeps a published link up to date: checks at start, on resume and a
/// moment after the schedule changes (`ShareLinkController.autoSync`, which
/// uploads only when the feed really changed, never closer than two
/// minutes). With no link, or no worker in the build, it does nothing and
/// nothing is sent. Shows nothing; it only wraps [child].
class ShareLinkHost extends ConsumerStatefulWidget {
  const ShareLinkHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ShareLinkHost> createState() => _ShareLinkHostState();
}

class _ShareLinkHostState extends ConsumerState<ShareLinkHost> {
  late final AppLifecycleListener _lifecycle;
  Timer? _debounce;
  bool _started = false;

  ShareLinkController get _controller =>
      ref.read(shareLinkControllerProvider.notifier);

  bool get _hasLink {
    final state = ref.read(shareLinkControllerProvider);
    return state.available && state.settings.hasToken;
  }

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _check);
  }

  Future<void> _check() async {
    if (!ref.read(shareLinkControllerProvider).available) return;
    await _controller.load(force: true);
    if (!mounted || !_hasLink) return;
    await _controller.autoSync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final label = context.l10n.shareLinkAbsence;
    final changed = _controller.absenceLabel != label;
    _controller.absenceLabel = label;
    if (!_started) {
      _started = true;
      unawaited(_check());
    } else if (changed) {
      _schedule();
    }
  }

  void _schedule() {
    if (!_hasLink) return;
    _debounce?.cancel();
    _debounce = Timer(
      shareLinkDebounce,
      () => unawaited(_controller.autoSync()),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(scheduleControllerProvider, (previous, next) {
      if (!identical(previous?.schedule, next.schedule)) _schedule();
    });
    return widget.child;
  }
}
