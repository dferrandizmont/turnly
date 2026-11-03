import '../../schedule/domain/civil_date.dart';
import '../data/day_tasks_repository.dart';
import '../domain/day_task.dart';

/// The tasks of a day: create, tick, reorder, delete — and undo the last
/// change of the list in one step.
///
/// The tasks live in their own table (`day_tasks`), so they are **not** a
/// change of the schedule: they never go through the undo queue of the engine
/// (docs/datos.md, «Esquema v6»). That is why this class keeps its own
/// history: the list of the day before each change, ready to be put back.
class DayTaskList {
  DayTaskList(
    this._repository, {
    DateTime Function()? now,
    this.historyLength = 20,
  }) : _now = now ?? DateTime.now;

  final DayTasksRepository _repository;
  final DateTime Function() _now;

  /// How many changes of a day are kept to be undone.
  final int historyLength;

  /// Day key -> the list of the day before each change (the last one first).
  final Map<String, List<List<DayTask>>> _history = {};

  /// The tasks of [date] in [calendarId], in their order.
  Future<List<DayTask>> load(String calendarId, CivilDate date) =>
      _repository.forDay(calendarId, date);

  /// Adds a task at the end of the list of the day.
  ///
  /// Throws [ArgumentError] when the title is empty or too long (the same
  /// rules as the table).
  Future<DayTask> add(String calendarId, CivilDate date, String title) async {
    await _remember(calendarId, date);
    final at = _now().toUtc().millisecondsSinceEpoch;
    final tasks = await _repository.forDay(calendarId, date);
    final task = DayTask(
      id: _repository.newId(),
      calendarId: calendarId,
      date: date,
      title: title,
      sortOrder: tasks.length,
      createdAt: at,
      updatedAt: at,
    );
    try {
      await _repository.save(task);
    } catch (_) {
      _forgetLast(calendarId, date);
      rethrow;
    }
    return task;
  }

  /// Ticks (or unticks) a task. Returns whether the task exists.
  Future<bool> setDone(
    String id, {
    required bool done,
    required String calendarId,
    required CivilDate date,
  }) async {
    await _remember(calendarId, date);
    final changed = await _repository.setDone(
      id,
      done: done,
      at: _now().toUtc().millisecondsSinceEpoch,
    );
    if (!changed) _forgetLast(calendarId, date);
    return changed;
  }

  /// Moves a task to [index] in the list of the day (0 = first). A task that
  /// is not there is left alone.
  Future<void> move(
    String calendarId,
    CivilDate date,
    String id,
    int index,
  ) async {
    final tasks = await _repository.forDay(calendarId, date);
    final from = tasks.indexWhere((t) => t.id == id);
    if (from < 0) return;
    await _remember(calendarId, date);
    final reordered = [...tasks]..removeAt(from);
    final to = index < 0
        ? 0
        : (index > reordered.length ? reordered.length : index);
    reordered.insert(to, tasks[from]);
    await _repository.setOrder(
      calendarId,
      date,
      [for (final task in reordered) task.id],
      at: _now().toUtc().millisecondsSinceEpoch,
    );
  }

  /// Deletes a task. Returns whether there was something to delete.
  Future<bool> remove(
    String id, {
    required String calendarId,
    required CivilDate date,
  }) async {
    await _remember(calendarId, date);
    final gone = await _repository.delete(id);
    if (!gone) _forgetLast(calendarId, date);
    return gone;
  }

  /// Whether the last change of the day can be undone.
  bool canUndo(String calendarId, CivilDate date) =>
      (_history[_key(calendarId, date)]?.isNotEmpty) ?? false;

  /// Puts the list of the day back as it was before its last change. Returns
  /// whether there was something to undo.
  ///
  /// The whole list is written inside one transaction: if putting it back
  /// fails half way, the day keeps what it had (the history step is only
  /// dropped once the write has gone through).
  Future<bool> undo(String calendarId, CivilDate date) async {
    final key = _key(calendarId, date);
    final stack = _history[key];
    if (stack == null || stack.isEmpty) return false;
    final previous = stack.last;
    await _repository.transaction(() async {
      await _repository.deleteForDay(calendarId, date);
      for (final task in previous) {
        await _repository.save(task);
      }
    });
    stack.removeLast();
    if (stack.isEmpty) _history.remove(key);
    return true;
  }

  /// Forgets the history of the day (the screen leaves it, or the day is
  /// restored from a copy).
  void forget(String calendarId, CivilDate date) =>
      _history.remove(_key(calendarId, date));

  Future<void> _remember(String calendarId, CivilDate date) async {
    final key = _key(calendarId, date);
    final stack = _history.putIfAbsent(key, () => []);
    stack.add(await _repository.forDay(calendarId, date));
    while (stack.length > historyLength) {
      stack.removeAt(0);
    }
  }

  void _forgetLast(String calendarId, CivilDate date) {
    final stack = _history[_key(calendarId, date)];
    if (stack == null || stack.isEmpty) return;
    stack.removeLast();
    if (stack.isEmpty) _history.remove(_key(calendarId, date));
  }

  String _key(String calendarId, CivilDate date) => '$calendarId|$date';
}
