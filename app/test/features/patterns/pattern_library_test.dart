import 'package:cuadrante/core/providers.dart';
import 'package:cuadrante/features/calendar/application/schedule_controller.dart';
import 'package:cuadrante/features/calendars/data/calendars_repository.dart';
import 'package:cuadrante/features/patterns/domain/new_pattern.dart';
import 'package:cuadrante/features/patterns/domain/pattern_application.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_storage.dart';

const _today = CivilDate(2026, 11, 14);
final _now = DateTime(2026, 11, 14, 12);
const _own = Pattern(
  id: 'own',
  name: 'Mi patrón',
  steps: [
    ['morning'],
    [],
  ],
);

void main() {
  late AppLocalizations l10n;
  setUp(
    () async => l10n = await AppLocalizations.delegate.load(const Locale('es')),
  );

  test(
    'new copy gets a new id, immutable steps and the next available name',
    () {
      final steps = <List<String>>[
        ['M', 'T'],
        [],
        ['rest'],
      ];
      final copy = createNewPattern(
        steps: steps,
        name: ' Mi patrón ',
        existingNames: ['Mi patrón', 'Mi patrón (2)', 'Mi patrón (4)'],
        copyName: l10n.patternCopyName,
      );
      final other = createNewPattern(
        steps: steps,
        name: 'Mi patrón',
        existingNames: [],
        copyName: l10n.patternCopyName,
      );
      expect(copy.id, startsWith('custom-'));
      expect(copy.id, isNot(other.id));
      expect(copy.name, 'Mi patrón (3)');
      expect(other.name, 'Mi patrón');
      steps[0].clear();
      steps.clear();
      expect(copy.steps, [
        ['M', 'T'],
        [],
        ['rest'],
      ]);
      expect(() => copy.steps.clear(), throwsUnsupportedError);
      expect(() => copy.steps.first.clear(), throwsUnsupportedError);
      expect(
        () => createNewPattern(
          steps: [],
          name: 'x',
          existingNames: [],
          copyName: l10n.patternCopyName,
        ),
        throwsArgumentError,
      );
      expect(
        () => createNewPattern(
          steps: [[]],
          name: ' ',
          existingNames: [],
          copyName: l10n.patternCopyName,
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'copy suffix is available through the ARB in all five languages',
    () async {
      for (final language in ['es', 'ca', 'gl', 'eu', 'en']) {
        final texts = await AppLocalizations.delegate.load(Locale(language));
        final copy = createNewPattern(
          steps: [[]],
          name: 'A',
          existingNames: ['A'],
          copyName: texts.patternCopyName,
        );
        expect(copy.name, 'A (2)');
      }
    },
  );

  group('repository', () {
    late TestStorage storage;
    setUp(() async {
      storage = await TestStorage.open(now: _now, demo: false);
      addTearDown(storage.close);
      await storage.repository.savePattern(_own);
    });

    test(
      'unused custom removed, unknown and catalogue (including variants) kept',
      () async {
        final repo = storage.repository;
        await repo.savePattern(
          const Pattern(id: '2x2-morning', name: 'preset', steps: [[]]),
        );
        expect(await repo.deletePatternIfUnused('correturnos'), isFalse);
        expect(await repo.deletePatternIfUnused('2x2-morning'), isFalse);
        expect(await repo.deletePatternIfUnused('missing'), isFalse);
        expect(await repo.deletePatternIfUnused(_own.id), isTrue);
        expect(await repo.usedPatternIds(), isNot(contains(_own.id)));
        final stored = (await repo.load(storage.snapshot.calendarId)).schedule;
        expect(stored.patternById(_own.id), isNull);
        expect(stored.patternById('correturnos'), isNotNull);
        expect(stored.patternById('2x2-morning'), isNotNull);
        expect(await repo.deletePatternIfUnused(_own.id), isFalse);
      },
    );

    for (final calendar in ['active', 'other', 'archived']) {
      test('used by $calendar calendar (ended run): no data changes', () async {
        final repo = storage.repository;
        var id = storage.snapshot.calendarId;
        if (calendar != 'active') {
          final calendars = CalendarsRepository(storage.database);
          id = (await calendars.create(name: 'Otro', colorValue: 1)).id;
          if (calendar == 'archived') await calendars.archive(id);
        }
        await repo.apply(
          id,
          ScheduleChange(
            runsAfter: [
              PatternRun(
                id: 'used',
                patternId: _own.id,
                startDate: _today.addDays(-100),
                endDate: _today.addDays(-1),
                seq: 50,
              ),
            ],
          ),
        );
        final before = await dumpTables(storage.database);
        expect(await repo.usedPatternIds(), contains(_own.id));
        expect(await repo.deletePatternIfUnused(_own.id), isFalse);
        expect(await dumpTables(storage.database), before);
      });
    }

    test('saving a copy preserves the original and its rotation', () async {
      final repo = storage.repository;
      final id = storage.snapshot.calendarId;
      await repo.apply(
        id,
        ScheduleChange(
          runsAfter: [
            PatternRun(
              id: 'original-run',
              patternId: _own.id,
              startDate: _today,
              seq: 1,
            ),
          ],
        ),
      );
      final before = (await repo.load(id)).schedule;
      final copies = await Future.wait([
        for (var i = 0; i < 2; i++)
          repo.saveAsNewPattern(
            steps: [
              ['night'],
            ],
            name: _own.name,
            copyName: l10n.patternCopyName,
          ),
      ]);
      expect(copies.map((p) => p.id).toSet(), hasLength(2));
      expect(copies.map((p) => p.name), ['Mi patrón (2)', 'Mi patrón (3)']);
      final after = (await repo.load(id)).schedule;
      expect(after.patternById(_own.id), _own);
      expect(after.runs, before.runs);
      expect(after.resolve(_today).shiftIds, ['morning']);
      expect(after.patternById(copies.first.id), copies.first);
    });

    test(
      'repository and engine keep cycles longer than the builder cap',
      () async {
        final long = Pattern(
          id: 'long',
          name: 'Long',
          steps: [
            for (var day = 0; day < 500; day++)
              [day == 499 ? 'night' : 'morning'],
          ],
        );
        await storage.repository.savePattern(long);
        await storage.repository.apply(
          storage.snapshot.calendarId,
          ScheduleChange(
            runsAfter: [
              PatternRun(
                id: 'long-run',
                patternId: long.id,
                startDate: _today,
                seq: 1,
              ),
            ],
          ),
        );
        final loaded = (await storage.repository.load(
          storage.snapshot.calendarId,
        )).schedule;
        expect(loaded.patternById('long')!.lengthDays, 500);
        expect(loaded.resolve(_today.addDays(499)).shiftIds, ['night']);
        expect(loaded.resolve(_today.addDays(500)).shiftIds, ['morning']);
      },
    );
  });

  test('controller serializes copies, protects queued runs and updates the library', () async {
    final storage = await TestStorage.open(now: _now, demo: false);
    addTearDown(storage.close);
    final container = ProviderContainer(
      overrides: [
        ...storage.overrides,
        clockProvider.overrideWithValue(() => _now),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(scheduleControllerProvider.notifier);
    final copies = await Future.wait([
      for (var i = 0; i < 2; i++)
        controller.saveAsNewPattern(
          steps: _own.steps,
          name: _own.name,
          copyName: l10n.patternCopyName,
        ),
    ]);
    final first = copies[0]!;
    final second = copies[1]!;
    expect(first.name, 'Mi patrón');
    expect(second.name, 'Mi patrón (2)');
    expect(
      container.read(scheduleControllerProvider).schedule.patternById(first.id),
      first,
    );
    await controller.applyPatternRun(
      PatternRequest(pattern: first, from: _today),
    );
    expect(await controller.deletePatternIfUnused(first.id), isFalse);
    expect(container.read(scheduleControllerProvider).canUndo, isTrue);
    controller.undo();
    expect(await controller.deletePatternIfUnused(first.id), isTrue);
    expect(container.read(scheduleControllerProvider).canRedo, isFalse);
    expect(
      container.read(scheduleControllerProvider).schedule.patternById(first.id),
      isNull,
    );
    expect(await controller.deletePatternIfUnused(second.id), isTrue);
    await controller.pendingWrites;
    expect(container.read(scheduleControllerProvider).saveErrors, 0);
    expect(
      (await storage.repository.load(storage.snapshot.calendarId)).schedule
          .patternById(first.id),
      isNull,
    );
  });
}
