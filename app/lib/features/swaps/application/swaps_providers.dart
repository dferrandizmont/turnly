import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../data/shift_swaps_repository.dart';
import '../data/swap_applied_store.dart';
import '../domain/swap_application.dart';
import '../domain/swap_schedule_plan.dart';

/// The only door to the swap ledger (the `shift_swaps` rows).
final shiftSwapsRepositoryProvider = Provider<ShiftSwapsRepository>(
  (ref) => ShiftSwapsRepository(ref.watch(appDatabaseProvider)),
);

/// What the days of each applied change had before it was applied, so it can
/// be taken off the calendar exactly.
final swapAppliedStoreProvider = Provider<SwapAppliedStore>(
  (ref) => SwapAppliedStore(ref.watch(appDatabaseProvider)),
);

final swapApplicationRecordsProvider = StreamProvider.autoDispose
    .family<List<SwapApplicationRecord>, String>(
      (ref, id) => ref.watch(swapAppliedStoreProvider).watch(id),
    );

/// The days the applied swaps of a calendar hold (at most one swap a day).
final swapDayClaimsProvider = StreamProvider.autoDispose
    .family<List<SwapDayClaim>, String>(
      (ref, calendarId) =>
          ref.watch(swapAppliedStoreProvider).watchClaims(calendarId),
    );
