import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../schedule/domain/civil_date.dart';
import '../domain/day_task.dart';

extension DayTaskRowMapper on DayTaskRow {
  DayTask toTask() => DayTask(
    id: id,
    calendarId: calendarId,
    date: date,
    title: title,
    done: done,
    sortOrder: sortOrder,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

extension DayTaskMapper on DayTask {
  DayTasksCompanion toCompanion() => DayTasksCompanion.insert(
    id: id,
    calendarId: calendarId,
    date: date,
    title: title,
    done: Value(done),
    sortOrder: Value(sortOrder),
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

/// The `day_tasks` rows (schema v6): the checkbox list of a day. Each write
/// is one row, outside the schedule's undo queue.
class DayTasksRepository {
  DayTasksRepository(this._db, {String Function()? newId})
    : _newId = newId ?? (() => 'task-${const Uuid().v4()}');

  final AppDatabase _db;
  final String Function() _newId;

  /// A fresh id for a new task.
  String newId() => _newId();

  /// The tasks of [date] in [calendarId], in their order.
  Future<List<DayTask>> forDay(String calendarId, CivilDate date) => _ordered(
    (t) => t.calendarId.equals(calendarId) & t.date.equals(date.toIso()),
  );

  /// The tasks of [calendarId] from [from] to [to] (both included), by day
  /// and then in their order.
  Future<List<DayTask>> inRange(
    String calendarId,
    CivilDate from,
    CivilDate to,
  ) => _ordered(
    (t) =>
        t.calendarId.equals(calendarId) &
        t.date.isBetweenValues(from.toIso(), to.toIso()),
  );

  /// Inserts or replaces [task] (by id). Throws [ArgumentError] when it is
  /// not valid ([DayTask.problem]), without writing.
  Future<void> save(DayTask task) async {
    final problem = task.problem;
    if (problem != null) throw ArgumentError.value(task, 'task', problem);
    await _db.into(_db.dayTasks).insertOnConflictUpdate(task.toCompanion());
  }

  /// Ticks or unticks [id]. Returns whether the task exists.
  Future<bool> setDone(String id, {required bool done, required int at}) async =>
      await (_db.update(_db.dayTasks)..where((t) => t.id.equals(id))).write(
        DayTasksCompanion(done: Value(done), updatedAt: Value(at)),
      ) >
      0;

  /// Removes [id]. Returns whether a row went.
  Future<bool> delete(String id) async =>
      await (_db.delete(_db.dayTasks)..where((t) => t.id.equals(id))).go() > 0;

  /// Removes every task of [date] in [calendarId]. Returns how many went.
  Future<int> deleteForDay(String calendarId, CivilDate date) async =>
      await (_db.delete(
        _db.dayTasks,
      )..where((t) => t.calendarId.equals(calendarId) & t.date.equals(date.toIso())))
          .go();

  /// Runs [action] as one transaction: a list of the day is written in
  /// several rows, so an undo that fails half way must not leave the day
  /// empty.
  Future<T> transaction<T>(Future<T> Function() action) =>
      _db.transaction(action);

  /// Writes the order of the tasks of a day: [orderedIds] is the new order
  /// (the first one is the first task of the list). The tasks that are not in
  /// it keep the order they had.
  Future<void> setOrder(
    String calendarId,
    CivilDate date,
    List<String> orderedIds, {
    required int at,
  }) async {
    var order = 0;
    for (final id in orderedIds) {
      final updated = await (_db.update(
        _db.dayTasks,
      )..where((t) => t.id.equals(id))).write(
        DayTasksCompanion(sortOrder: Value(order), updatedAt: Value(at)),
      );
      if (updated > 0) order++;
    }
  }

  Future<List<DayTask>> _ordered(
    Expression<bool> Function($DayTasksTable t) filter,
  ) async {
    final rows =
        await (_db.select(_db.dayTasks)
              ..where(filter)
              ..orderBy([
                (t) => OrderingTerm.asc(t.date),
                (t) => OrderingTerm.asc(t.sortOrder),
                (t) => OrderingTerm.asc(t.createdAt),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    return [for (final row in rows) row.toTask()];
  }
}
