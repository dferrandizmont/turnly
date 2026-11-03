import '../../schedule/domain/civil_date.dart';

/// Longest title of a task, in UTF-16 units.
const int maxDayTaskTitleLength = 500;

/// One checkbox of the task list of [date] in a calendar (a `day_tasks` row,
/// schema v6). Tasks live in their own table, not inside `day_entries`: a day
/// row comes and goes with the engine's edits (it is deleted when it holds
/// nothing), and ticking a box must be a one-row write that never goes
/// through the schedule's undo queue (docs/datos.md, «Esquema v6»).
class DayTask {
  const DayTask({
    required this.id,
    required this.calendarId,
    required this.date,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.done = false,
    this.sortOrder = 0,
  });

  final String id;
  final String calendarId;
  final CivilDate date;
  final String title;
  final bool done;

  /// Position in the list of the day (ascending).
  final int sortOrder;

  /// Milliseconds since the epoch (UTC).
  final int createdAt;
  final int updatedAt;

  /// Why this task cannot be stored, or `null` when it is valid.
  String? get problem {
    if (id.isEmpty) return 'empty id';
    if (calendarId.isEmpty) return 'no calendar';
    if (title.trim().isEmpty) return 'empty title';
    if (title.length > maxDayTaskTitleLength) return 'title too long';
    return null;
  }

  DayTask copyWith({
    CivilDate? date,
    String? title,
    bool? done,
    int? sortOrder,
    int? updatedAt,
  }) => DayTask(
    id: id,
    calendarId: calendarId,
    date: date ?? this.date,
    title: title ?? this.title,
    done: done ?? this.done,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is DayTask &&
      other.id == id &&
      other.calendarId == calendarId &&
      other.date == date &&
      other.title == title &&
      other.done == done &&
      other.sortOrder == sortOrder &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    calendarId,
    date,
    title,
    done,
    sortOrder,
    createdAt,
    updatedAt,
  );

  @override
  String toString() => 'DayTask($id, $calendarId $date, done: $done)';
}
