import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../backup/application/backup_providers.dart'
    show restoreInProgressProvider;
import '../application/review_providers.dart';

/// Counts the days the app is opened for the store-review prompt (at start
/// and when it comes back to the foreground) and keeps the prompt quiet for
/// the rest of the session after a restore. Mounted once above the router
/// (`MaterialApp.builder`), shows nothing and only wraps [child].
class ReviewHost extends ConsumerStatefulWidget {
  const ReviewHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ReviewHost> createState() => _ReviewHostState();
}

class _ReviewHostState extends ConsumerState<ReviewHost> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _record);
    unawaited(_record());
  }

  Future<void> _record() => ref.read(reviewServiceProvider).recordOpen();

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A restore that just finished: the person is checking their data.
    ref.listen(restoreInProgressProvider, (was, now) {
      if (was == true && !now) {
        ref.read(reviewQuietProvider.notifier).set(true);
      }
    });
    return widget.child;
  }
}
