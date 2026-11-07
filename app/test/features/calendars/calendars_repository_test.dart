import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/features/calendars/data/calendars_repository.dart';
import 'package:cuadrante/features/calendars/domain/calendar.dart';
import 'package:cuadrante/features/schedule/data/schedule_repository.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_storage.dart';

void main() {
  late AppDatabase db;
  late CalendarsRepository repo;
  var counter = 0;

  CalendarsRepository make() => CalendarsRepository(
    db,
    now: () => DateTime.utc(2026, 11, 2, 8),
    newId: () => 'cal-${++counter}',
  );

  setUp(() {
    counter = 0;
    db = openMemoryDatabase();
    repo = make();
  });
  tearDown(() => db.close());

  Future<String?> stored(String key) async {
    final row = await (db.select(
      db.settings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  group('list and create', () {
    test('a new database has main', () async {
      final calendars = await repo.list();
      expect(calendars, [
        const Calendar(
          id: 'main',
          name: 'Mi cuadrante',
          colorValue: 0xFF4B4FD1,
          sortOrder: 0,
        ),
      ]);
    });

    test('create adds a calendar at the end and returns it', () async {
      final created = await repo.create(
        name: '  Pareja ',
        colorValue: 0xFFE5484D,
      );
      expect(
        created,
        const Calendar(
          id: 'cal-1',
          name: 'Pareja',
          colorValue: 0xFFE5484D,
          sortOrder: 1,
        ),
      );
      expect((await repo.list()).map((c) => c.id), ['main', 'cal-1']);
      expect(await repo.get('cal-1'), created);
      expect(await repo.get('nope'), isNull);
    });

    test('ids are unique without help (uuid)', () async {
      final real = CalendarsRepository(db);
      final a = await real.create(name: 'A', colorValue: 1);
      final b = await real.create(name: 'B', colorValue: 1);
      expect(a.id, startsWith('cal-'));
      expect(a.id, isNot(b.id));
    });

    test('a blank name is refused', () async {
      await expectLater(
        repo.create(name: '   ', colorValue: 1),
        throwsA(isA<ArgumentError>()),
      );
      expect(await repo.list(), hasLength(1));
    });
  });

  group('many calendars', () {
    test('creates more than ten calendars and keeps their order', () async {
      final created = <Calendar>[];
      for (var i = 1; i <= 15; i++) {
        created.add(await repo.create(name: 'C$i', colorValue: i));
      }
      final listed = await repo.list();
      expect(listed.map((c) => c.id), ['main', ...created.map((c) => c.id)]);
      expect(listed.map((c) => c.sortOrder), List.generate(16, (i) => i));
      expect(listed.skip(1), created);
    });

    test(
      'a new repository keeps existing calendars and can add more',
      () async {
        for (var i = 1; i <= 12; i++) {
          await repo.create(name: 'C$i', colorValue: i);
        }
        final before = await repo.list();
        final reopened = make();
        expect(await reopened.list(), before);
        final added = await reopened.create(name: 'Otro', colorValue: 9);
        expect(await reopened.list(), [...before, added]);
      },
    );
  });

  group('rename and recolor', () {
    test('change only what they say', () async {
      final c = await repo.create(name: 'Pareja', colorValue: 1);
      await repo.rename(c.id, ' Mi pareja ');
      await repo.recolor(c.id, 0xFF00FF00);
      expect(
        await repo.get(c.id),
        const Calendar(
          id: 'cal-1',
          name: 'Mi pareja',
          colorValue: 0xFF00FF00,
          sortOrder: 1,
        ),
      );
      expect((await repo.get('main'))!.name, 'Mi cuadrante');
    });

    test('unknown calendars and blank names are refused', () async {
      await expectLater(
        repo.rename('ghost', 'x'),
        throwsA(isA<CalendarNotFound>()),
      );
      await expectLater(
        repo.recolor('ghost', 1),
        throwsA(isA<CalendarNotFound>()),
      );
      await expectLater(
        repo.rename('main', ' '),
        throwsA(isA<ArgumentError>()),
      );
      expect((await repo.get('main'))!.name, 'Mi cuadrante');
    });
  });

  group('archive', () {
    test('the last calendar cannot be archived', () async {
      await expectLater(
        repo.archive('main'),
        throwsA(isA<LastCalendarCannotBeArchived>()),
      );
      expect((await repo.list()).single.archived, isFalse);
    });

    test('nor the last one that is left', () async {
      final second = await repo.create(name: 'B', colorValue: 1);
      await repo.archive('main');
      await expectLater(
        repo.archive(second.id),
        throwsA(isA<LastCalendarCannotBeArchived>()),
      );
      expect((await repo.list()).map((c) => c.id), [second.id]);
    });

    test('an archived calendar leaves the list but keeps its data', () async {
      final second = await repo.create(name: 'B', colorValue: 1);
      final schedules = ScheduleRepository(db);
      const day = CivilDate(2026, 11, 3);
      await schedules.apply(
        second.id,
        ScheduleChange(
          patch: EntriesPatch({
            day: EntryChange(null, DayEntry(date: day, note: 'guardada')),
          }),
        ),
      );

      await repo.archive(second.id);

      expect((await repo.list()).map((c) => c.id), ['main']);
      final all = await repo.list(includeArchived: true);
      expect(all.firstWhere((c) => c.id == second.id).archived, isTrue);
      expect(
        (await schedules.load(second.id)).schedule.entries[day]?.note,
        'guardada',
      );
    });

    test('unknown or already archived calendars are refused', () async {
      final second = await repo.create(name: 'B', colorValue: 1);
      await repo.archive(second.id);
      await expectLater(
        repo.archive(second.id),
        throwsA(isA<CalendarNotFound>()),
      );
      await expectLater(
        repo.archive('ghost'),
        throwsA(isA<CalendarNotFound>()),
      );
    });

    test('archiving the active or the primary moves the settings on', () async {
      final second = await repo.create(name: 'B', colorValue: 1);
      await repo.setActive(second.id);
      await repo.setPrimary(second.id);

      await repo.archive(second.id);

      expect(await repo.activeId(), 'main');
      expect(await repo.primaryId(), 'main');
      expect(await stored(CalendarSettings.active), '"main"');
      expect(await stored(CalendarSettings.primary), '"main"');
    });

    test('archiving another calendar leaves the settings alone', () async {
      final second = await repo.create(name: 'B', colorValue: 1);
      await repo.setActive(second.id);
      await repo.archive('main');
      expect(await repo.activeId(), second.id);
      expect(await stored(CalendarSettings.active), '"cal-1"');
    });
  });

  group('active and primary', () {
    test('both default to main and nothing is stored yet', () async {
      expect(await repo.activeId(), 'main');
      expect(await repo.primaryId(), 'main');
      expect(await stored(CalendarSettings.active), isNull);
      expect(await stored(CalendarSettings.primary), isNull);
    });

    test('are kept as JSON text in the settings table', () async {
      final second = await repo.create(name: 'B', colorValue: 1);
      await repo.setActive(second.id);
      await repo.setPrimary('main');
      expect(await stored('calendars.active'), '"cal-1"');
      expect(await stored('calendars.primary'), '"main"');
      expect(await repo.activeId(), second.id);
      expect(await repo.primaryId(), 'main');
    });

    test('the active one follows the primary one until chosen', () async {
      final second = await repo.create(name: 'B', colorValue: 1);
      await repo.setPrimary(second.id);
      expect(await repo.activeId(), second.id);
    });

    test(
      'only calendars that exist and are not archived can be chosen',
      () async {
        final second = await repo.create(name: 'B', colorValue: 1);
        await repo.archive(second.id);
        await expectLater(
          repo.setActive('ghost'),
          throwsA(isA<CalendarNotFound>()),
        );
        await expectLater(
          repo.setPrimary(second.id),
          throwsA(isA<CalendarNotFound>()),
        );
        expect(await stored(CalendarSettings.active), isNull);
        expect(await stored(CalendarSettings.primary), isNull);
      },
    );

    test(
      'a stored id that is unknown, archived or not text falls back',
      () async {
        final second = await repo.create(name: 'B', colorValue: 1);

        Future<void> put(String key, String value) async {
          await db.customStatement(
            'INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)',
            [key, value],
          );
        }

        // A restored backup may point anywhere.
        await put('calendars.active', '"ghost"');
        await put('calendars.primary', '"ghost"');
        expect(await repo.activeId(), 'main');
        expect(await repo.primaryId(), 'main');

        await put('calendars.active', '42');
        await put('calendars.primary', 'not json');
        expect(await repo.activeId(), 'main');
        expect(await repo.primaryId(), 'main');

        // Archived behind the repository's back.
        await put('calendars.active', '"${second.id}"');
        await db.customStatement(
          "UPDATE calendars SET archived = 1 WHERE id = '${second.id}'",
        );
        expect(await repo.activeId(), 'main');
      },
    );

    test(
      'with main archived the first calendar left is the fallback',
      () async {
        final second = await repo.create(name: 'B', colorValue: 1);
        await db.customStatement(
          "UPDATE calendars SET archived = 1 WHERE id = 'main'",
        );
        expect(await repo.primaryId(), second.id);
        expect(await repo.activeId(), second.id);
      },
    );
  });

  group('ensureMain', () {
    test('creates main only when there is no calendar at all', () async {
      await repo.ensureMain();
      expect(await repo.list(), hasLength(1));

      await db.customStatement('DELETE FROM calendars');
      expect(await repo.list(includeArchived: true), isEmpty);
      await repo.ensureMain();
      expect((await repo.list()).map((c) => c.id), ['main']);
      expect((await repo.get('main'))!.name, 'Mi cuadrante');
    });

    test('primaryId repairs a database without calendars', () async {
      await db.customStatement('DELETE FROM calendars');
      expect(await repo.primaryId(), 'main');
      expect(await repo.list(), hasLength(1));
    });
  });

  group('deleteArchived', () {
    /// One of every kind of row that belongs to a calendar.
    Future<void> seedOwnedBy(String calendar) async {
      Future<void> sql(String statement, [List<Object?> args = const []]) =>
          db.customStatement(statement, args);
      await sql(
        'INSERT OR IGNORE INTO patterns (id, name, steps, created_at, '
        "updated_at) VALUES ('p', 'P', '[[\"t\"]]', 0, 0)",
      );
      await sql(
        'INSERT INTO pattern_runs (id, calendar_id, pattern_id, start_date, '
        "seq, created_at) VALUES (?, ?, 'p', '2026-10-01', ?, 0)",
        ['run-$calendar', calendar, calendar == 'main' ? 1 : 2],
      );
      await sql(
        'INSERT INTO day_entries (calendar_id, date, note, updated_at) '
        "VALUES (?, '2026-10-02', 'nota', 0)",
        [calendar],
      );
      await sql(
        'INSERT INTO day_tasks (id, calendar_id, date, title, created_at, '
        "updated_at) VALUES (?, ?, '2026-10-02', 'Tarea', 0, 0)",
        ['task-$calendar', calendar],
      );
      await sql(
        'INSERT INTO shift_swaps (id, calendar_id, date, colleague, '
        "direction, created_at, updated_at) VALUES (?, ?, '2026-10-03', "
        "'Marta', 'theyOwe', 0, 0)",
        ['swap-$calendar', calendar],
      );
      await sql(
        'INSERT INTO note_attachments (id, calendar_id, date, kind, '
        'relative_path, mime_type, size_bytes, sha256, created_at) '
        "VALUES (?, ?, '2026-10-02', 'file', ?, 'text/plain', 1, ?, 0)",
        ['att-$calendar', calendar, '$calendar/a.txt', 'a' * 64],
      );
      await sql(
        'INSERT INTO absence_balances (year, type, allowed_days, calendar_id) '
        'VALUES (2026, ?, 22, ?)',
        ['vac-$calendar', calendar],
      );
    }

    Future<int> count(String table, String calendar) async {
      final rows = await db
          .customSelect(
            'SELECT COUNT(*) AS n FROM $table WHERE calendar_id = ?',
            variables: [Variable.withString(calendar)],
          )
          .getSingle();
      return rows.read<int>('n');
    }

    const owned = [
      'pattern_runs',
      'day_entries',
      'day_tasks',
      'shift_swaps',
      'note_attachments',
      'absence_balances',
    ];

    test('removes the calendar and only the rows that belong to it', () async {
      final other = await repo.create(name: 'Prueba', colorValue: 1);
      await seedOwnedBy('main');
      await seedOwnedBy(other.id);
      // A balance that follows the primary calendar belongs to none.
      await db.customStatement(
        'INSERT INTO absence_balances (year, type, allowed_days) '
        "VALUES (2026, 'shared', 5)",
      );
      for (final table in owned) {
        expect(await count(table, other.id), 1, reason: table);
      }
      await repo.archive(other.id);

      await repo.deleteArchived(other.id);

      expect(await repo.get(other.id), isNull);
      expect((await repo.list(includeArchived: true)).map((c) => c.id), [
        'main',
      ]);
      for (final table in owned) {
        expect(await count(table, other.id), 0, reason: table);
        expect(await count(table, 'main'), 1, reason: table);
      }
      final shared = await db
          .customSelect(
            'SELECT COUNT(*) AS n FROM absence_balances '
            'WHERE calendar_id IS NULL',
          )
          .getSingle();
      expect(shared.read<int>('n'), 1);
      // Patterns are shared: they stay.
      final patterns = await db
          .customSelect('SELECT COUNT(*) AS n FROM patterns')
          .getSingle();
      expect(patterns.read<int>('n'), 1);
    });

    test(
      'refuses a calendar that is not archived and changes nothing',
      () async {
        final other = await repo.create(name: 'Prueba', colorValue: 1);
        await seedOwnedBy(other.id);

        await expectLater(
          repo.deleteArchived(other.id),
          throwsA(isA<CalendarNotArchived>()),
        );
        await expectLater(
          repo.deleteArchived('main'),
          throwsA(isA<CalendarNotArchived>()),
        );

        expect(await repo.get(other.id), isNotNull);
        for (final table in owned) {
          expect(await count(table, other.id), 1, reason: table);
        }
      },
    );

    test('refuses an unknown id', () async {
      await expectLater(
        repo.deleteArchived('nope'),
        throwsA(isA<CalendarNotFound>()),
      );
    });

    test('never deletes the only calendar there is', () async {
      await db.customStatement(
        "UPDATE calendars SET archived = 1 WHERE id = 'main'",
      );
      await expectLater(
        repo.deleteArchived('main'),
        throwsA(isA<LastCalendarCannotBeArchived>()),
      );
      expect(await repo.get('main'), isNotNull);
    });
  });
}
