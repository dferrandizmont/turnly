import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/features/schedule/domain/civil_date.dart';
import 'package:cuadrante/features/swaps/data/shift_swaps_repository.dart';
import 'package:cuadrante/features/swaps/domain/shift_swap.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_storage.dart';

ShiftSwap _swap(
  String id, {
  CivilDate date = const CivilDate(2026, 11, 3),
  String colleague = 'Marta',
  SwapDirection direction = SwapDirection.theyOwe,
  SwapStatus status = SwapStatus.pending,
  int? closedAt,
  String? note,
  int createdAt = 1,
  List<String>? given,
  List<String>? received,
}) => ShiftSwap(
  id: id,
  calendarId: 'main',
  date: date,
  colleague: colleague,
  direction: direction,
  givenShiftTypeIds: given,
  receivedShiftTypeIds: received,
  status: status,
  note: note,
  createdAt: createdAt,
  updatedAt: createdAt,
  closedAt: closedAt,
);

void main() {
  group('domain', () {
    test('problem', () {
      expect(_swap('s').problem, isNull);
      expect(_swap('').problem, 'empty id');
      expect(_swap('s', colleague: '  ').problem, 'no colleague');
      expect(
        _swap('s', colleague: 'x' * (maxSwapColleagueLength + 1)).problem,
        'colleague too long',
      );
      expect(
        _swap('s', note: 'x' * (maxSwapNoteLength + 1)).problem,
        'note too long',
      );
      expect(
        _swap('s', status: SwapStatus.returned).problem,
        startsWith('closedAt'),
      );
      expect(_swap('s', closedAt: 5).problem, startsWith('closedAt'));
      expect(
        _swap('s', status: SwapStatus.returned, closedAt: 5).problem,
        isNull,
      );
    });

    test('returned and reopened keep the rest', () {
      final swap = _swap('s', given: const ['night'], received: const []);
      final back = swap.returned(at: 50);
      expect(back.isReturned, isTrue);
      expect(back.closedAt, 50);
      expect(back.updatedAt, 50);
      expect(back.givenShiftTypeIds, ['night']);
      expect(back.problem, isNull);
      final again = back.reopened(at: 60);
      expect(again.status, SwapStatus.pending);
      expect(again.closedAt, isNull);
      expect(again.updatedAt, 60);
      expect(again.problem, isNull);
    });

    test('equality tells null lists from empty ones', () {
      expect(_swap('s', given: const []), isNot(_swap('s')));
      expect(_swap('s', given: const ['a']), _swap('s', given: const ['a']));
      expect(
        _swap('s', given: const ['a']).hashCode,
        _swap('s', given: const ['a']).hashCode,
      );
    });
  });

  group('repository', () {
    late AppDatabase db;
    setUp(() {
      db = openMemoryDatabase();
      addTearDown(db.close);
    });

    test('save, list by calendar and status, day, return and reopen, '
        'delete', () async {
      final repo = ShiftSwapsRepository(db, newId: () => 'swap-new');
      expect(repo.newId(), 'swap-new');
      final older = _swap(
        'a',
        date: const CivilDate(2026, 10, 1),
        given: const ['night'],
        received: const ['morning'],
      );
      final newer = _swap(
        'b',
        date: const CivilDate(2026, 11, 3),
        direction: SwapDirection.iOwe,
        note: 'Me cubre la tarde',
      );
      await repo.save(older);
      await repo.save(newer);
      expect(await repo.list(), [newer, older]);
      expect(await repo.list(calendarId: 'main'), [newer, older]);
      expect(await repo.list(calendarId: 'other'), isEmpty);
      expect(await repo.forDay('main', const CivilDate(2026, 10, 1)), [older]);

      final back = await repo.markReturned('a', at: 99);
      expect(back, older.returned(at: 99));
      expect(await repo.byId('a'), back);
      expect(await repo.list(status: SwapStatus.pending), [newer]);
      expect(await repo.list(status: SwapStatus.returned), [back]);
      expect(await repo.reopen('a', at: 100), older.returned(at: 99).reopened(at: 100));
      expect(await repo.markReturned('ghost', at: 1), isNull);

      expect(await repo.delete('b'), isTrue);
      expect(await repo.delete('b'), isFalse);
      expect(await repo.list(), hasLength(1));
    });

    test('an invalid swap writes nothing', () async {
      final repo = ShiftSwapsRepository(db);
      await expectLater(
        repo.save(_swap('s', status: SwapStatus.returned)),
        throwsArgumentError,
      );
      expect(await repo.list(), isEmpty);
    });
  });
}
