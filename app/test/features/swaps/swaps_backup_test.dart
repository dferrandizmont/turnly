import 'package:cuadrante/features/schedule/domain/civil_date.dart';
import 'package:cuadrante/features/swaps/data/shift_swaps_repository.dart';
import 'package:cuadrante/features/swaps/domain/shift_swap.dart';
import 'package:flutter_test/flutter_test.dart';

import '../backup/backup_test_support.dart';

const _third = CivilDate(2026, 11, 3);
const _tenth = CivilDate(2026, 11, 10);

ShiftSwap _swap(
  String id, {
  String colleague = 'Marta',
  SwapDirection direction = SwapDirection.theyOwe,
  SwapStatus status = SwapStatus.pending,
  int? closedAt,
}) => ShiftSwap(
  id: id,
  calendarId: 'main',
  date: _third,
  colleague: colleague,
  direction: direction,
  givenShiftTypeIds: const ['night'],
  receivedShiftTypeIds: const ['morning'],
  returnDate: _tenth,
  status: status,
  note: 'Me devuelve la noche del 10',
  createdAt: 7,
  updatedAt: 9,
  closedAt: closedAt,
);

void main() {
  test('the ledger travels in the copy and comes back', () async {
    final dir = makeTempDir('swaps-backup');
    final source = openMemoryDatabase();
    addTearDown(source.close);

    final repository = ShiftSwapsRepository(source);
    final pending = _swap('swap-1');
    final settled = _swap(
      'swap-2',
      colleague: 'Luis',
      direction: SwapDirection.iOwe,
      status: SwapStatus.returned,
      closedAt: 9,
    );
    await repository.save(pending);
    await repository.save(settled);

    final data = await makeRepository(source, dir).readAll();
    expect(data.shiftSwaps, hasLength(2));

    final target = openMemoryDatabase();
    addTearDown(target.close);
    await makeRepository(target, dir).restore(data);

    final restored = await ShiftSwapsRepository(target).list();
    expect(restored, hasLength(2));
    expect(restored, contains(pending));
    expect(restored, contains(settled));
  });
}
