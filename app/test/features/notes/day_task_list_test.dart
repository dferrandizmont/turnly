import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/features/notes/application/day_task_list.dart';
import 'package:cuadrante/features/notes/data/day_tasks_repository.dart';
import 'package:cuadrante/features/notes/domain/day_task.dart';
import 'package:cuadrante/features/schedule/domain/civil_date.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_storage.dart';

const _day = CivilDate(2026, 11, 3);
const _other = CivilDate(2026, 11, 4);

/// A repository that fails on the [failFromSave]-th `save` (1-based), to see
/// what an undo that breaks half way leaves behind.
class _FlakyRepository extends DayTasksRepository {
  // ignore: use_super_parameters
  _FlakyRepository(AppDatabase db) : super(db);

  int _saves = 0;

  /// The number of the `save` call (1-based) from which every write fails.
  int? failFromSave;

  @override
  Future<void> save(DayTask task) {
    _saves++;
    final at = failFromSave;
    if (at != null && _saves >= at) {
      return Future<void>.error(StateError('disk full'));
    }
    return super.save(task);
  }
}

void main() {
  group('the tasks of a day', () {
    late AppDatabase db;
    late DayTaskList list;

    setUp(() {
      db = openMemoryDatabase();
      addTearDown(db.close);
      list = DayTaskList(
        DayTasksRepository(db),
        now: () => DateTime.utc(2026, 11, 10, 9),
      );
    });

    test('a task is created at the end of the list', () async {
      final first = await list.add('main', _day, 'Comprar pan');
      final second = await list.add('main', _day, 'Llamar al médico');
      expect((await list.load('main', _day)).map((t) => t.title), [
        'Comprar pan',
        'Llamar al médico',
      ]);
      expect(first.sortOrder, 0);
      expect(second.sortOrder, 1);
      expect(
        first.createdAt,
        DateTime.utc(2026, 11, 10, 9).millisecondsSinceEpoch,
      );
    });

    test('an empty title is refused and nothing is remembered', () async {
      await expectLater(list.add('main', _day, '  '), throwsArgumentError);
      expect(await list.load('main', _day), isEmpty);
      expect(list.canUndo('main', _day), isFalse);
    });

    test('a task is ticked and unticked', () async {
      final task = await list.add('main', _day, 'Comprar pan');
      expect(
        await list.setDone(task.id, done: true, calendarId: 'main', date: _day),
        isTrue,
      );
      expect((await list.load('main', _day)).single.done, isTrue);
      expect(
        await list.setDone(
          task.id,
          done: false,
          calendarId: 'main',
          date: _day,
        ),
        isTrue,
      );
      expect((await list.load('main', _day)).single.done, isFalse);
    });

    test('a task that is not there is not ticked', () async {
      expect(
        await list.setDone('ghost', done: true, calendarId: 'main', date: _day),
        isFalse,
      );
      expect(list.canUndo('main', _day), isFalse);
    });

    test('the list is reordered', () async {
      final first = await list.add('main', _day, 'Primera');
      final second = await list.add('main', _day, 'Segunda');
      final third = await list.add('main', _day, 'Tercera');
      await list.move('main', _day, third.id, 0);
      expect((await list.load('main', _day)).map((t) => t.title), [
        'Tercera',
        'Primera',
        'Segunda',
      ]);
      await list.move('main', _day, third.id, 99);
      expect((await list.load('main', _day)).map((t) => t.title), [
        'Primera',
        'Segunda',
        'Tercera',
      ]);
      expect(first.id, isNot(second.id));
    });

    test('a task is deleted', () async {
      final task = await list.add('main', _day, 'Comprar pan');
      expect(
        await list.remove(task.id, calendarId: 'main', date: _day),
        isTrue,
      );
      expect(await list.load('main', _day), isEmpty);
      expect(
        await list.remove(task.id, calendarId: 'main', date: _day),
        isFalse,
      );
    });

    test('the tasks of a day do not touch the other days', () async {
      await list.add('main', _day, 'Primera');
      await list.add('main', _other, 'Otra');
      expect(await list.load('main', _day), hasLength(1));
      expect(await list.load('main', _other), hasLength(1));
      expect(await list.load('other', _day), isEmpty);
    });
  });

  group('the undo of the tasks', () {
    late AppDatabase db;
    late DayTaskList list;

    setUp(() {
      db = openMemoryDatabase();
      addTearDown(db.close);
      list = DayTaskList(
        DayTasksRepository(db),
        now: () => DateTime.utc(2026, 11, 10, 9),
      );
    });

    test('there is nothing to undo at the start', () async {
      expect(list.canUndo('main', _day), isFalse);
      expect(await list.undo('main', _day), isFalse);
    });

    test('a task added is taken back', () async {
      await list.add('main', _day, 'Comprar pan');
      expect(list.canUndo('main', _day), isTrue);
      expect(await list.undo('main', _day), isTrue);
      expect(await list.load('main', _day), isEmpty);
      expect(list.canUndo('main', _day), isFalse);
    });

    test('the list comes back exactly as it was', () async {
      final first = await list.add('main', _day, 'Primera');
      await list.add('main', _day, 'Segunda');
      await list.setDone(first.id, done: true, calendarId: 'main', date: _day);
      final before = await list.load('main', _day);
      await list.add('main', _day, 'Tercera');
      await list.move('main', _day, first.id, 0);
      expect(await list.load('main', _day), isNot(before));

      // One step back: the list before the move (with the third task).
      expect(await list.undo('main', _day), isTrue);
      expect(await list.load('main', _day), hasLength(3));

      // One more step: the list as it was.
      expect(await list.undo('main', _day), isTrue);
      final after = await list.load('main', _day);
      expect(after, before);
      expect(after.map((t) => t.id), before.map((t) => t.id));
      expect(after.map((t) => t.done), before.map((t) => t.done));
      expect(after.map((t) => t.sortOrder), before.map((t) => t.sortOrder));
    });

    test('each change is undone in one step', () async {
      final task = await list.add('main', _day, 'Comprar pan');
      await list.add('main', _day, 'Segunda');

      // The last change: the second task goes away.
      expect(await list.undo('main', _day), isTrue);
      expect((await list.load('main', _day)).single.id, task.id);

      // The one before: the first task goes away too.
      expect(await list.undo('main', _day), isTrue);
      expect(await list.load('main', _day), isEmpty);
      expect(await list.undo('main', _day), isFalse);
    });

    test('a deleted task comes back', () async {
      final task = await list.add('main', _day, 'Comprar pan');
      await list.remove(task.id, calendarId: 'main', date: _day);
      expect(await list.load('main', _day), isEmpty);
      expect(await list.undo('main', _day), isTrue);
      final back = await list.load('main', _day);
      expect(back, hasLength(1));
      expect(back.single.id, task.id);
      expect(back.single.title, 'Comprar pan');
    });

    test('the undo of one day does not touch the other', () async {
      await list.add('main', _day, 'Primera');
      await list.add('main', _other, 'Otra');
      await list.undo('main', _other);
      expect(await list.load('main', _day), hasLength(1));
      expect(await list.load('main', _other), isEmpty);
    });

    test('an undo that fails keeps the day and the step (M2)', () async {
      final repository = _FlakyRepository(db);
      final flaky = DayTaskList(
        repository,
        now: () => DateTime.utc(2026, 11, 10, 9),
      );
      final first = await flaky.add('main', _day, 'Primera');
      await flaky.add('main', _day, 'Segunda');
      await flaky.remove(first.id, calendarId: 'main', date: _day);

      // The undo writes the two tasks back; the second write fails.
      repository.failFromSave = 4;
      await expectLater(flaky.undo('main', _day), throwsStateError);

      // All or nothing: the day keeps what it had (Primera is still gone),
      // it was not left half empty.
      expect((await flaky.load('main', _day)).map((t) => t.title), ['Segunda']);
      // The step was not dropped: it can be tried again.
      expect(flaky.canUndo('main', _day), isTrue);

      repository.failFromSave = null;
      expect(await flaky.undo('main', _day), isTrue);
      expect((await flaky.load('main', _day)).map((t) => t.title), [
        'Primera',
        'Segunda',
      ]);
    });

    test('the history of a day is not endless', () async {
      for (var i = 0; i < list.historyLength + 5; i++) {
        await list.add('main', _day, 'Tarea $i');
      }
      var undone = 0;
      while (await list.undo('main', _day)) {
        undone++;
      }
      expect(undone, list.historyLength);
    });
  });
}
