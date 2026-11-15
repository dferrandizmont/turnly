import 'dart:ui' show Tristate;

import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/theme/app_theme.dart';
import 'package:cuadrante/features/patterns/presentation/cycle_start_picker.dart';
import 'package:cuadrante/features/patterns/presentation/cycle_strip.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_font.dart';
import '../../support/text_lines.dart';

ShiftType? _shiftOf(String id) {
  for (final template in shiftTemplates) {
    if (template.key == id) return template.toShiftType(id);
  }
  return null;
}

Future<void> _pump(
  WidgetTester tester, {
  required List<List<String>> steps,
  int offset = 0,
  Locale locale = const Locale('es'),
  bool dark = false,
  ValueChanged<int>? onOffsetChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: SingleChildScrollView(
          child: CycleStartPicker(
            steps: steps,
            shiftOf: _shiftOf,
            offset: offset,
            onOffsetChanged: onOffsetChanged ?? (_) {},
            start: const CivilDate(2026, 10, 19),
            plan: null,
            showPreview: false,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _key(String key) => find.byKey(ValueKey(key));

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeLocale();
    expect(await loadRoboto(), isTrue);
  });

  testWidgets('empty cycle draws nothing', (tester) async {
    await _pump(tester, steps: const []);
    expect(find.byType(CycleStrip), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'all 63 days are visible; day 22 chooses offset 21 with full semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final calls = <int>[];
      await _pump(
        tester,
        steps: [
          for (var i = 0; i < 21; i++) ['morning'],
          for (var i = 0; i < 21; i++) ['night'],
          for (var i = 0; i < 21; i++) ['afternoon'],
        ],
        offset: 21,
        onOffsetChanged: calls.add,
      );
      expect(_key('offset-62'), findsOneWidget);
      expect(_key('cycle-toggle'), findsNothing);
      await tester.ensureVisible(_key('offset-21'));
      await tester.tap(_key('offset-21'));
      await tester.pumpAndSettle();
      expect(calls, [21]);
      final node = tester.getSemantics(_key('offset-21'));
      expect(node.label, 'Día 22 de 63, Noche, 22:00–06:00');
      expect(
        node.getSemanticsData().flagsCollection.isSelected,
        Tristate.isTrue,
      );
      expect(_key('shift-night'), findsNothing);
      semantics.dispose();
    },
  );

  testWidgets('folds after 12 rows and expands all 53 weeks', (tester) async {
    await _pump(tester, steps: List.generate(371, (_) => ['morning']));
    expect(_key('offset-83'), findsOneWidget);
    expect(_key('offset-84'), findsNothing);
    expect(find.text('Ver las 53 semanas'), findsOneWidget);
    await tester.ensureVisible(_key('cycle-toggle'));
    await tester.tap(_key('cycle-toggle'));
    await tester.pumpAndSettle();
    expect(_key('offset-370'), findsOneWidget);
    await tester.ensureVisible(_key('cycle-toggle'));
    await tester.tap(_key('cycle-toggle'));
    await tester.pumpAndSettle();
    expect(_key('offset-84'), findsNothing);
  });

  testWidgets('empty and multiple shifts stay distinct and accessible', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      steps: [
        [],
        ['rest'],
        ['morning', 'night'],
      ],
    );
    expect(tester.getSemantics(_key('offset-0')).label, contains('Sin turno'));
    expect(tester.getSemantics(_key('offset-1')).label, contains('Libre'));
    final label = tester.getSemantics(_key('offset-2')).label;
    expect(label, contains('Mañana'));
    expect(label, contains('Noche'));
    expect(label, contains('22:00–06:00'));
    semantics.dispose();
  });

  for (final (size, scale) in [
    (const Size(320, 568), 2.0),
    (const Size(390, 844), 1.0),
    (const Size(1024, 768), 2.0),
  ]) {
    for (final dark in [false, true]) {
      testWidgets(
        'seven columns and touch targets at $size x$scale, dark $dark',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await _pump(
            tester,
            steps: List.generate(63, (_) => ['night']),
            dark: dark,
          );
          for (var i = 0; i < 7; i++) {
            final rect = tester.getRect(_key('offset-$i'));
            expect(rect.width, greaterThanOrEqualTo(48));
            expect(rect.height, greaterThanOrEqualTo(48));
            expect(rect.top, tester.getRect(_key('offset-0')).top);
          }
          expect(
            tester.getRect(_key('offset-7')).top,
            greaterThan(tester.getRect(_key('offset-0')).bottom),
          );
          await tester.ensureVisible(_key('offset-21'));
          expect(brokenParagraphs(tester), isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'selected cycle column scrolls into view initially and on changes x$scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final semantics = tester.ensureSemantics();
        for (final offset in [6, 7, 13, 0]) {
          await _pump(
            tester,
            steps: List.generate(21, (_) => ['night']),
            offset: offset,
          );
          final rect = tester.getRect(_key('offset-$offset'));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(320));
          expect(_key('offset-$offset').hitTestable(), findsOneWidget);
          expect(
            find.bySemanticsLabel(
              'La tira del ciclo se desplaza horizontalmente',
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        }
        semantics.dispose();
      },
    );
  }

  const phrases = {
    'es': [
      ('1 día', '1 semana', '1 vez en total', 'Ver la semana completa'),
      ('3 días', '3 semanas', '3 veces en total', 'Ver las 3 semanas'),
      ('53 días', '53 semanas', '53 veces en total', 'Ver las 53 semanas'),
    ],
    'ca': [
      ('1 dia', '1 setmana', '1 vegada en total', 'Mostra la setmana completa'),
      ('3 dies', '3 setmanes', '3 vegades en total', 'Mostra les 3 setmanes'),
      (
        '53 dies',
        '53 setmanes',
        '53 vegades en total',
        'Mostra les 53 setmanes',
      ),
    ],
    'gl': [
      ('1 día', '1 semana', '1 vez en total', 'Ver a semana completa'),
      ('3 días', '3 semanas', '3 veces en total', 'Ver as 3 semanas'),
      ('53 días', '53 semanas', '53 veces en total', 'Ver as 53 semanas'),
    ],
    'eu': [
      ('Egun 1', '1 aste', 'Guztira 1 aldiz', 'Ikusi aste osoa'),
      ('3 egun', '3 aste', 'Guztira 3 aldiz', 'Ikusi aste guztiak: 3'),
      ('53 egun', '53 aste', 'Guztira 53 aldiz', 'Ikusi aste guztiak: 53'),
    ],
    'en': [
      ('1 day', '1 week', '1 time in total', 'Show the whole week'),
      ('3 days', '3 weeks', '3 times in total', 'Show all 3 weeks'),
      ('53 days', '53 weeks', '53 times in total', 'Show all 53 weeks'),
    ],
  };
  for (final entry in phrases.entries) {
    test('complete day, week and repetition plurals in ${entry.key}', () {
      final l10n = lookupAppLocalizations(Locale(entry.key));
      for (final (i, count) in [1, 3, 53].indexed) {
        final (days, weeks, times, showWeeks) = entry.value[i];
        expect(l10n.patternCycleDays(count), days);
        expect(l10n.patternWeeks(count), weeks);
        expect(l10n.patternShowWeeks(count), showWeeks);
        expect(l10n.patternRepeatTotal(count, days), '$times · $days');
      }
    });
  }
}
