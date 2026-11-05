import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'reset_everything.dart';

/// Kept through navigation so first use can explain an incomplete system
/// cleanup without suggesting that the database reset failed.
class ResetCleanupNotice extends Notifier<Set<ResetCleanupStep>> {
  @override
  Set<ResetCleanupStep> build() => {};

  void show(Set<ResetCleanupStep> failures) => state = Set.of(failures);
}

final resetCleanupNoticeProvider =
    NotifierProvider<ResetCleanupNotice, Set<ResetCleanupStep>>(
      ResetCleanupNotice.new,
    );
