import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../domain/absence_balance.dart';

extension AbsenceBalanceRowMapper on AbsenceBalanceRow {
  AbsenceBalance toBalance() => AbsenceBalance(
    year: year,
    type: type,
    allowedDays: allowedDays,
    calendarId: calendarId,
    name: name,
    periodStart: periodStart,
    periodEnd: periodEnd,
    unit: unit,
    shiftTypeQuarters: shiftTypeQuarters ?? const {},
    carryOver: carryOver,
    carryOverMaxDays: carryOverMaxDays,
    adjustmentDays: adjustmentDays,
    sortOrder: sortOrder,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

extension AbsenceBalanceMapper on AbsenceBalance {
  AbsenceBalancesCompanion toCompanion() => AbsenceBalancesCompanion.insert(
    year: year,
    type: type,
    allowedDays: allowedDays,
    calendarId: Value(calendarId),
    name: Value(name),
    periodStart: Value(periodStart),
    periodEnd: Value(periodEnd),
    unit: Value(unit),
    // No types = NULL, as on the rows written before v6.
    shiftTypeQuarters: Value(
      shiftTypeQuarters.isEmpty ? null : shiftTypeQuarters,
    ),
    carryOver: Value(carryOver),
    carryOverMaxDays: Value(carryOverMaxDays),
    adjustmentDays: Value(adjustmentDays),
    sortOrder: Value(sortOrder),
    createdAt: Value(createdAt),
    updatedAt: Value(updatedAt),
  );
}

/// The `absence_balances` rows (extended in schema v6). What is used is
/// counted from the days by P3; this only keeps what is available.
class AbsenceBalancesRepository {
  AbsenceBalancesRepository(this._db);

  final AppDatabase _db;

  /// A key for a new series of balances. The app creates it (the key is the
  /// same every year, so the days can be carried from one year to the next,
  /// and it is unique among calendars); what the user sees is the name.
  static String newSeriesId() => 'abs-${const Uuid().v4()}';

  /// The balances (of [year] only, when given), by year, order and key.
  Future<List<AbsenceBalance>> list({int? year}) async {
    final query = _db.select(_db.absenceBalances)
      ..orderBy([
        (t) => OrderingTerm.asc(t.year),
        (t) => OrderingTerm.asc(t.sortOrder),
        (t) => OrderingTerm.asc(t.type),
      ]);
    if (year != null) query.where((t) => t.year.equals(year));
    return [for (final row in await query.get()) row.toBalance()];
  }

  /// The balance of the series [type] in [year], or `null`.
  Future<AbsenceBalance?> find(int year, String type) async {
    final row =
        await (_db.select(_db.absenceBalances)
              ..where((t) => t.year.equals(year) & t.type.equals(type)))
            .getSingleOrNull();
    return row?.toBalance();
  }

  /// Inserts or replaces [balance] (by year and type). Throws
  /// [ArgumentError] when it is not valid ([AbsenceBalance.problem]),
  /// without writing; a calendar that does not exist fails in the database.
  ///
  /// The timestamps are the ones of the balance: the controller stamps them
  /// ([AbsenceBalancesController.save]).
  Future<void> save(AbsenceBalance balance) async {
    final problem = balance.problem;
    if (problem != null) {
      throw ArgumentError.value(balance, 'balance', problem);
    }
    await _db
        .into(_db.absenceBalances)
        .insertOnConflictUpdate(balance.toCompanion());
  }

  /// Removes the balance of [type] in [year]. Returns whether a row went.
  Future<bool> delete(int year, String type) async =>
      await (_db.delete(
        _db.absenceBalances,
      )..where((t) => t.year.equals(year) & t.type.equals(type))).go() >
      0;
}
