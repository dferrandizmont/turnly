import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/swap_application.dart';
import '../domain/swap_schedule_plan.dart';
import 'shift_swaps_repository.dart';

extension SwapApplicationRowMapper on SwapApplicationRow {
  SwapApplicationRecord toRecord() => SwapApplicationRecord(
    swapId: swapId,
    date: date,
    previousShiftTypeIds: previousShiftTypeIds,
    createdAt: createdAt,
    appliedOverride: appliedOverride == null
        ? null
        : (
            shiftTypeIds: (jsonDecode(appliedOverride!) as List?)
                ?.cast<String>(),
          ),
  );
}

extension SwapApplicationMapper on SwapApplicationRecord {
  /// [calendarId] is the calendar of the swap.
  SwapApplicationsCompanion toCompanion(String calendarId) =>
      SwapApplicationsCompanion.insert(
        swapId: swapId,
        calendarId: calendarId,
        date: date,
        previousShiftTypeIds: Value(previousShiftTypeIds),
        appliedOverride: Value(
          appliedOverride == null
              ? null
              : jsonEncode(appliedOverride!.shiftTypeIds),
        ),
        createdAt: createdAt,
      );
}

/// Reads the actual days a swap modified and persists their undo snapshots.
class SwapAppliedStore {
  SwapAppliedStore(this._db);

  final AppDatabase _db;

  Selectable<SwapApplicationRecord> _forSwap(String id) =>
      (_db.select(_db.swapApplications)
            ..where((t) => t.swapId.equals(id))
            ..orderBy([(t) => OrderingTerm.asc(t.date)]))
          .map((row) => row.toRecord());

  Future<List<SwapApplicationRecord>> before(String id) => _forSwap(id).get();

  Stream<List<SwapApplicationRecord>> watch(String id) => _forSwap(id).watch();

  Selectable<SwapDayClaim> _claims(String calendarId) =>
      (_db.select(_db.swapApplications).join([
              innerJoin(
                _db.shiftSwaps,
                _db.shiftSwaps.id.equalsExp(_db.swapApplications.swapId),
              ),
            ])
            ..where(_db.shiftSwaps.calendarId.equals(calendarId))
            ..orderBy([OrderingTerm.asc(_db.swapApplications.date)]))
          .map(
            (row) => SwapDayClaim(
              date: row.readTable(_db.swapApplications).date,
              swapId: row.readTable(_db.swapApplications).swapId,
              colleague: row.readTable(_db.shiftSwaps).colleague,
            ),
          );

  /// Every day an applied swap of [calendarId] holds, with its colleague.
  Future<List<SwapDayClaim>> claims(String calendarId) =>
      _claims(calendarId).get();

  Stream<List<SwapDayClaim>> watchClaims(String calendarId) =>
      _claims(calendarId).watch();

  /// Called inside ScheduleRepository.apply's transaction, after the days.
  Future<void> write(String calendarId, SwapChange change) async {
    final swaps = ShiftSwapsRepository(_db);
    final current = await swaps.byId(change.swapId);
    final definition = change.definition;
    if ((current != null && current.calendarId != calendarId) ||
        (definition?.after != null &&
            definition!.after!.calendarId != calendarId)) {
      throw StateError('Swap belongs to another calendar');
    }
    if (definition != null) {
      final swap = definition.after;
      if (swap == null) {
        // Deleting the parent prunes all its records in the same transaction.
        await swaps.delete(change.swapId);
        return;
      }
      await swaps.save(swap);
    }
    if (current == null && definition == null) {
      throw StateError('Swap no longer exists');
    }
    // The step replaces the records it was computed from. Different ones
    // mean it is stale (another write of this swap came first): fail the
    // whole transaction rather than drop the records of a day it changed.
    if (!_sameRecords(await before(change.swapId), change.before)) {
      throw StateError('Swap records changed since the step was computed');
    }
    await (_db.delete(
      _db.swapApplications,
    )..where((t) => t.swapId.equals(change.swapId))).go();
    await _db.batch((batch) {
      batch.insertAll(_db.swapApplications, [
        // A day another swap holds breaks idx_swap_applications_day: the
        // whole transaction fails and nothing is written.
        for (final record in change.after) record.toCompanion(calendarId),
      ]);
    });
  }
}

bool _sameRecords(
  List<SwapApplicationRecord> stored,
  List<SwapApplicationRecord> expected,
) {
  String key(SwapApplicationRecord r) => jsonEncode([
    r.swapId,
    r.date.toIso(),
    r.previousShiftTypeIds,
    r.createdAt,
    if (r.appliedOverride case final override?) [override.shiftTypeIds],
  ]);
  final a = stored.map(key).toList()..sort();
  final b = expected.map(key).toList()..sort();
  return const ListEquality<String>().equals(a, b);
}
