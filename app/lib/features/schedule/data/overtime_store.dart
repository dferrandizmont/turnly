import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/schedule_domain.dart';

/// Overtime types, blocks and the base rate in the database (schema v7).
class OvertimeStore {
  OvertimeStore(this._db);

  final AppDatabase _db;

  /// Every type, archived ones too, in `sort_order`.
  Future<List<OvertimeType>> types() async => [
    for (final row
        in await (_db.select(_db.overtimeTypes)..orderBy([
              (t) => OrderingTerm.asc(t.sortOrder),
              (t) => OrderingTerm.asc(t.id),
            ]))
            .get())
      row.toType(),
  ];

  /// The blocks of [calendarId], by day and start.
  Future<List<OvertimeBlock>> blocks(String calendarId) async => [
    for (final row
        in await (_db.select(_db.overtimeBlocks)
              ..where((b) => b.calendarId.equals(calendarId))
              ..orderBy([
                (b) => OrderingTerm.asc(b.date),
                (b) => OrderingTerm.asc(b.startMinute),
                (b) => OrderingTerm.asc(b.id),
              ]))
            .get())
      row.toBlock(),
  ];

  /// Inserts or updates [type]. An invalid one throws [ArgumentError]
  /// without writing.
  Future<void> saveType(OvertimeType type) async {
    if (type.problem case final problem?) {
      throw ArgumentError.value(type, 'type', 'invalid $problem');
    }
    await _db
        .into(_db.overtimeTypes)
        .insertOnConflictUpdate(type.toCompanion());
  }

  /// Replaces the blocks of [date] in [calendarId] with [blocks].
  Future<void> replaceDay(
    String calendarId,
    CivilDate date,
    List<OvertimeBlock> blocks,
  ) async {
    for (final b in blocks) {
      if (b.problem case final problem?) {
        throw ArgumentError.value(b, 'block', 'invalid $problem');
      }
      if (b.date != date) throw ArgumentError.value(b, 'block', 'other day');
    }
    await (_db.delete(_db.overtimeBlocks)..where(
          (b) => b.calendarId.equals(calendarId) & b.date.equalsValue(date),
        ))
        .go();
    for (final b in blocks) {
      await _db.into(_db.overtimeBlocks).insert(b.toCompanion(calendarId));
    }
  }

  /// The base hourly rate, or `null` when none is set.
  Future<int?> baseRate() async {
    final row = await (_db.select(
      _db.settings,
    )..where((s) => s.key.equals(baseHourlyRateKey))).getSingleOrNull();
    return parseBaseHourlyRate(row?.value);
  }

  /// Sets the base hourly rate; `null` removes it.
  Future<void> setBaseRate(int? cents) async {
    if (cents == null) {
      await (_db.delete(
        _db.settings,
      )..where((s) => s.key.equals(baseHourlyRateKey))).go();
      return;
    }
    if (cents < 0 || cents > maxStoredMoneyCents) {
      throw ArgumentError.value(cents, 'cents', 'out of range');
    }
    await _db
        .into(_db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(
            key: baseHourlyRateKey,
            value: jsonEncode(cents),
          ),
        );
  }
}

extension OvertimeTypeRowMapper on OvertimeTypeRow {
  OvertimeType toType() => OvertimeType(
    id: id,
    name: name,
    colorValue: colorValue,
    rateMode: rateMode,
    multiplierBasisPoints: multiplierBasisPoints,
    hourlyRateCents: hourlyRateCents,
    countsForGoal: countsForGoal,
    archived: archived,
    sortOrder: sortOrder,
  );
}

extension OvertimeBlockRowMapper on OvertimeBlockRow {
  OvertimeBlock toBlock() => OvertimeBlock(
    id: id,
    date: date,
    typeId: typeId,
    startMinute: startMinute,
    endMinute: endMinute,
    breakMinutes: breakMinutes,
    note: note,
  );
}

extension OvertimeTypeCompanion on OvertimeType {
  OvertimeTypesCompanion toCompanion() => OvertimeTypesCompanion.insert(
    id: id,
    name: Value(name),
    colorValue: colorValue,
    rateMode: rateMode,
    multiplierBasisPoints: Value(multiplierBasisPoints),
    hourlyRateCents: Value(hourlyRateCents),
    countsForGoal: countsForGoal,
    archived: Value(archived),
    sortOrder: Value(sortOrder),
  );
}

extension OvertimeBlockCompanion on OvertimeBlock {
  OvertimeBlocksCompanion toCompanion(String calendarId) =>
      OvertimeBlocksCompanion.insert(
        calendarId: calendarId,
        date: date,
        id: id,
        typeId: typeId,
        startMinute: startMinute,
        endMinute: endMinute,
        breakMinutes: Value(breakMinutes),
        note: Value(note),
      );
}
