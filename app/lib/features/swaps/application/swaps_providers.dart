import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../data/shift_swaps_repository.dart';

/// The only door to the swap ledger (the `shift_swaps` rows).
final shiftSwapsRepositoryProvider = Provider<ShiftSwapsRepository>(
  (ref) => ShiftSwapsRepository(ref.watch(appDatabaseProvider)),
);
