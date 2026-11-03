import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../schedule/domain/civil_date.dart';
import '../domain/shift_swap.dart';

extension ShiftSwapRowMapper on ShiftSwapRow {
  ShiftSwap toSwap() => ShiftSwap(
    id: id,
    calendarId: calendarId,
    date: date,
    colleague: colleague,
    direction: direction,
    givenShiftTypeIds: givenShiftTypeIds,
    receivedShiftTypeIds: receivedShiftTypeIds,
    returnDate: returnDate,
    status: status,
    note: note,
    createdAt: createdAt,
    updatedAt: updatedAt,
    closedAt: closedAt,
  );
}

extension ShiftSwapMapper on ShiftSwap {
  ShiftSwapsCompanion toCompanion() => ShiftSwapsCompanion.insert(
    id: id,
    calendarId: calendarId,
    date: date,
    colleague: colleague,
    direction: direction,
    givenShiftTypeIds: Value(givenShiftTypeIds),
    receivedShiftTypeIds: Value(receivedShiftTypeIds),
    returnDate: Value(returnDate),
    status: Value(status),
    note: Value(note),
    createdAt: createdAt,
    updatedAt: updatedAt,
    closedAt: Value(closedAt),
  );
}

/// The `shift_swaps` rows (schema v6): the swap ledger.
class ShiftSwapsRepository {
  ShiftSwapsRepository(this._db, {String Function()? newId})
    : _newId = newId ?? (() => 'swap-${const Uuid().v4()}');

  final AppDatabase _db;
  final String Function() _newId;

  /// A fresh id for a new swap.
  String newId() => _newId();

  /// The swaps of [calendarId] (every calendar when `null`), newest day
  /// first.
  Future<List<ShiftSwap>> list({String? calendarId, SwapStatus? status}) =>
      _ordered((t) {
        Expression<bool> where = const Constant(true);
        if (calendarId != null) where = where & t.calendarId.equals(calendarId);
        if (status != null) where = where & t.status.equals(status.name);
        return where;
      });

  /// The swaps of [date] in [calendarId].
  Future<List<ShiftSwap>> forDay(String calendarId, CivilDate date) => _ordered(
    (t) => t.calendarId.equals(calendarId) & t.date.equals(date.toIso()),
  );

  Future<ShiftSwap?> byId(String id) async {
    final row = await (_db.select(
      _db.shiftSwaps,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row?.toSwap();
  }

  /// Inserts or replaces [swap] (by id). Throws [ArgumentError] when it is
  /// not valid ([ShiftSwap.problem]), without writing.
  Future<void> save(ShiftSwap swap) async {
    final problem = swap.problem;
    if (problem != null) throw ArgumentError.value(swap, 'swap', problem);
    await _db.into(_db.shiftSwaps).insertOnConflictUpdate(swap.toCompanion());
  }

  /// Marks [id] as paid back at [at]. Returns the swap, or `null` when it
  /// does not exist.
  Future<ShiftSwap?> markReturned(String id, {required int at}) =>
      _change(id, (s) => s.returned(at: at));

  /// Marks [id] as owed again. Returns the swap, or `null` when it does not
  /// exist.
  Future<ShiftSwap?> reopen(String id, {required int at}) =>
      _change(id, (s) => s.reopened(at: at));

  /// Removes [id]. Returns whether a row went.
  Future<bool> delete(String id) async =>
      await (_db.delete(_db.shiftSwaps)..where((t) => t.id.equals(id))).go() >
      0;

  Future<ShiftSwap?> _change(String id, ShiftSwap Function(ShiftSwap) edit) =>
      _db.transaction(() async {
        final current = await byId(id);
        if (current == null) return null;
        final next = edit(current);
        await save(next);
        return next;
      });

  Future<List<ShiftSwap>> _ordered(
    Expression<bool> Function($ShiftSwapsTable t) filter,
  ) async {
    final rows =
        await (_db.select(_db.shiftSwaps)
              ..where(filter)
              ..orderBy([
                (t) => OrderingTerm.desc(t.date),
                (t) => OrderingTerm.desc(t.createdAt),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    return [for (final row in rows) row.toSwap()];
  }
}
