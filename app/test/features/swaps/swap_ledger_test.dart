import 'package:cuadrante/features/schedule/domain/civil_date.dart';
import 'package:cuadrante/features/swaps/domain/shift_swap.dart';
import 'package:cuadrante/features/swaps/domain/swap_ledger.dart';
import 'package:flutter_test/flutter_test.dart';

ShiftSwap _swap(
  String id, {
  String colleague = 'Marta',
  CivilDate date = const CivilDate(2026, 11, 3),
  CivilDate? returnDate,
  SwapDirection direction = SwapDirection.theyOwe,
  SwapStatus status = SwapStatus.pending,
  List<String>? given,
  List<String>? received,
  int? closedAt,
  String? note,
  int createdAt = 1,
}) => ShiftSwap(
  id: id,
  calendarId: 'main',
  date: date,
  colleague: colleague,
  direction: direction,
  givenShiftTypeIds: given,
  receivedShiftTypeIds: received,
  returnDate: returnDate,
  status: status,
  note: note,
  createdAt: createdAt,
  updatedAt: createdAt,
  closedAt: closedAt,
);

void main() {
  group('stage and counts', () {
    test('a change without a received day is pending', () {
      final swap = _swap('s', given: const ['night']);
      expect(swap.stage, SwapStage.pending);
      expect(swap.givenCount, 1);
      expect(swap.receivedCount, 0);
      expect(swap.netShifts, 1);
    });

    test('a change with a received day is returned', () {
      final swap = _swap(
        's',
        given: const ['night'],
        received: const ['morning'],
        returnDate: const CivilDate(2026, 11, 10),
      );
      expect(swap.stage, SwapStage.returned);
      expect(swap.givenCount, 1);
      expect(swap.receivedCount, 1);
      expect(swap.netShifts, 0);
    });

    test('a closed change is settled', () {
      final swap = _swap(
        's',
        status: SwapStatus.returned,
        closedAt: 10,
        returnDate: const CivilDate(2026, 11, 10),
      );
      expect(swap.stage, SwapStage.settled);
      expect(swap.isReturned, isTrue);
    });

    test('the shifts that were not recorded count as one', () {
      final swap = _swap('s');
      expect(swap.givenCount, 1);
      expect(swap.receivedCount, 0);
      expect(swap.netShifts, 1);
    });

    test('a received day without shifts counts as one received', () {
      final swap = _swap('s', returnDate: const CivilDate(2026, 11, 10));
      expect(swap.receivedCount, 1);
      expect(swap.netShifts, 0);
    });

    test('several shifts count one by one', () {
      final swap = _swap('s', given: const ['night', 'morning']);
      expect(swap.givenCount, 2);
      expect(swap.netShifts, 2);
    });

    test('the other way round: I owe them', () {
      final swap = _swap('s', direction: SwapDirection.iOwe);
      expect(swap.netShifts, -1);
      // While the favour is still owed (no return date) only the side the
      // change says is the debt counts: recording a shift of the other side
      // does not cancel it.
      final both = _swap(
        's',
        direction: SwapDirection.iOwe,
        given: const ['night'],
        received: const ['morning'],
      );
      expect(both.netShifts, -1);
    });

    test('the side that is not the debt only counts once it came back', () {
      final owed = _swap(
        's',
        direction: SwapDirection.iOwe,
        given: const ['night'],
        received: const ['morning'],
        returnDate: const CivilDate(2026, 11, 10),
      );
      expect(owed.netShifts, 0, reason: 'what came back cancels what was owed');
    });

    test('recording the shift I gave away does not cancel my debt (H3)', () {
      // «Se lo debo» and a shift recorded on the given side: I still owe the
      // favour, so the balance is -1, not 0.
      final swap = _swap(
        's',
        direction: SwapDirection.iOwe,
        given: const ['night'],
      );
      expect(swap.givenCount, 0, reason: 'the given side is not the debt');
      expect(swap.receivedCount, 1);
      expect(swap.netShifts, -1);
    });

    test('recording the shift I received does not cancel their debt (H3)', () {
      // «Me lo deben» and a shift recorded on the received side: they still
      // owe me the favour, so the balance is 1, not 0.
      final swap = _swap('s', received: const ['night']);
      expect(swap.givenCount, 1);
      expect(
        swap.receivedCount,
        0,
        reason: 'the received side is not the debt',
      );
      expect(swap.netShifts, 1);
    });
  });

  group('service days', () {
    test('the day I give and the day I receive, with the service data', () {
      final swap = _swap(
        's',
        given: const ['night'],
        received: const ['morning'],
        returnDate: const CivilDate(2026, 11, 10),
      );
      expect(swap.serviceDays, [
        const SwapServiceDay(
          date: CivilDate(2026, 11, 3),
          side: SwapSide.given,
          colleague: 'Marta',
          shiftTypeIds: ['night'],
        ),
        const SwapServiceDay(
          date: CivilDate(2026, 11, 10),
          side: SwapSide.received,
          colleague: 'Marta',
          shiftTypeIds: ['morning'],
        ),
      ]);
    });

    test('a change that is still owed has only the day it gives', () {
      final swap = _swap('s');
      expect(swap.serviceDays, hasLength(1));
      expect(swap.serviceDays.single.side, SwapSide.given);
      expect(swap.serviceDays.single.shiftTypeIds, isEmpty);
    });
  });

  group('copyWith', () {
    test('keeps what it is not given', () {
      final swap = _swap('s', given: const ['night'], note: 'Me cubre');
      final edited = swap.copyWith(colleague: 'Lucía', updatedAt: 5);
      expect(edited.id, 's');
      expect(edited.colleague, 'Lucía');
      expect(edited.givenShiftTypeIds, ['night']);
      expect(edited.note, 'Me cubre');
      expect(edited.updatedAt, 5);
      expect(edited.createdAt, swap.createdAt);
    });

    test('the clear flags take a field back to null', () {
      final swap = _swap(
        's',
        given: const ['night'],
        received: const ['morning'],
        note: 'Me cubre',
        returnDate: const CivilDate(2026, 11, 10),
      );
      final edited = swap.copyWith(
        clearGivenShiftTypeIds: true,
        clearReceivedShiftTypeIds: true,
        clearReturnDate: true,
        clearNote: true,
      );
      expect(edited.givenShiftTypeIds, isNull);
      expect(edited.receivedShiftTypeIds, isNull);
      expect(edited.returnDate, isNull);
      expect(edited.note, isNull);
    });
  });

  group('ledger', () {
    test('an empty ledger has no balances', () {
      final ledger = buildSwapLedger(const []);
      expect(ledger.swaps, isEmpty);
      expect(ledger.balances, isEmpty);
      expect(ledger.pending, isEmpty);
      expect(ledger.settled, isEmpty);
    });

    test('they owe me the shifts I gave', () {
      final ledger = buildSwapLedger([
        _swap('a', given: const ['night', 'morning']),
      ]);
      final balance = ledger.balances.single;
      expect(balance.colleague, 'Marta');
      expect(balance.theyOweMe, 2);
      expect(balance.iOweThem, 0);
      expect(balance.net, 2);
      expect(balance.pendingCount, 1);
      expect(balance.settledCount, 0);
      expect(balance.isSettled, isFalse);
    });

    test('I owe them the shifts they gave me', () {
      final ledger = buildSwapLedger([
        _swap('a', direction: SwapDirection.iOwe, received: const ['night']),
      ]);
      final balance = ledger.balances.single;
      expect(balance.iOweThem, 1);
      expect(balance.theyOweMe, 0);
      expect(balance.net, -1);
    });

    test('the balance nets what came back', () {
      final ledger = buildSwapLedger([
        _swap('a', given: const ['night', 'morning']),
        _swap(
          'b',
          date: const CivilDate(2026, 11, 10),
          direction: SwapDirection.iOwe,
          received: const ['afternoon'],
        ),
      ]);
      final balance = ledger.balances.single;
      expect(balance.net, 1);
      expect(balance.theyOweMe, 1);
      expect(balance.iOweThem, 0);
      expect(balance.pendingCount, 2);
    });

    test('a settled change leaves the balance', () {
      final ledger = buildSwapLedger([
        _swap('a', given: const ['night']),
        _swap(
          'b',
          colleague: 'Lucía',
          direction: SwapDirection.iOwe,
          status: SwapStatus.returned,
          closedAt: 10,
        ),
      ]);
      expect(ledger.balances, hasLength(2));
      final marta = ledger.balanceOf('Marta')!;
      expect(marta.net, 1);
      expect(marta.pendingCount, 1);
      final lucia = ledger.balanceOf('Lucía')!;
      expect(lucia.net, 0);
      expect(lucia.pendingCount, 0);
      expect(lucia.settledCount, 1);
      expect(lucia.isSettled, isTrue);
      expect(ledger.pending, hasLength(1));
      expect(ledger.settled, hasLength(1));
    });

    test('the same person written in two ways is one balance', () {
      final ledger = buildSwapLedger([
        _swap('a', colleague: 'Marta', given: const ['night']),
        _swap(
          'b',
          colleague: '  marta ',
          date: const CivilDate(2026, 11, 10),
          direction: SwapDirection.iOwe,
        ),
      ]);
      expect(ledger.balances, hasLength(1));
      expect(ledger.balances.single.net, 0);
      expect(ledger.balanceOf('MARTA')!.colleague, 'Marta');
      expect(ledger.swapsOf('Marta'), hasLength(2));
      expect(ledger.balanceOf('Ana'), isNull);
    });

    test('the balances come ordered by pending', () {
      final ledger = buildSwapLedger([
        _swap('a', colleague: 'Zoraida'),
        _swap(
          'b',
          colleague: 'Ana',
          date: const CivilDate(2026, 11, 4),
          direction: SwapDirection.iOwe,
        ),
        _swap(
          'c',
          colleague: 'Bea',
          date: const CivilDate(2026, 11, 5),
          given: const ['night', 'morning', 'afternoon'],
        ),
        _swap(
          'd',
          colleague: 'Nuria',
          date: const CivilDate(2026, 11, 6),
          status: SwapStatus.returned,
          closedAt: 1,
        ),
      ]);
      expect(ledger.balances.map((b) => b.colleague), [
        'Bea',
        'Ana',
        'Zoraida',
        'Nuria',
      ]);
      expect(ledger.balances.last.hasPending, isFalse);
    });
  });
}
