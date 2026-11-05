import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/l10n/catalog_texts.dart';
import 'package:cuadrante/core/theme/app_theme.dart';
import 'package:cuadrante/core/widgets/choice_pill.dart';
import 'package:cuadrante/features/patterns/presentation/cycle_start_picker.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The shared "which day of the cycle" picker on its own, without the whole
/// app: the labels of «ese turno se repite», the tap that keeps the choice,
/// the empty cycle and the first-use texts of the catalogue.
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
  ValueChanged<int>? onOffsetChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
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
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeLocale();
  });

  testWidgets('a cycle with no days draws nothing, it does not divide by '
      'zero', (tester) async {
    await _pump(tester, steps: const <List<String>>[]);
    expect(tester.takeException(), isNull);
    expect(find.byType(CycleStartPicker), findsOneWidget);
  });

  testWidgets('tapping the shift already chosen keeps the cycle day', (
    tester,
  ) async {
    final calls = <int>[];
    await _pump(
      tester,
      steps: patternPresetById('continental').steps,
      // Day 10 of the cycle (offset 9) is a Mañana, the first day of its
      // second run.
      offset: 9,
      onOffsetChanged: calls.add,
    );

    // The shift is already chosen: the tap must not move the day.
    await tester.tap(find.byKey(const ValueKey('shift-morning')));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);

    // Another shift does move it, to its first day (the first Noche).
    await tester.tap(find.byKey(const ValueKey('shift-night')));
    await tester.pumpAndSettle();
    expect(calls, [4]);
  });

  testWidgets('a run whose previous day is empty is labelled without '
      '«después de»', (tester) async {
    await _pump(
      tester,
      steps: [
        <String>[],
        ['morning'],
        ['morning'],
        <String>[],
        ['morning'],
      ],
      offset: 1,
    );

    // Two Mañana runs, each preceded by an empty day: the plain label, with
    // no dangling «después de » and no shift claimed before it.
    expect(find.text('Tanda 1 · Día 1 de 2'), findsOneWidget);
    expect(find.text('Tanda 2 · Mañana'), findsOneWidget);
    final labels = [
      for (final pill in tester.widgetList<ChoicePill>(find.byType(ChoicePill)))
        pill.label,
    ];
    expect(labels.any((l) => l.contains('después de')), isFalse);
  });

  testWidgets('tapping a shift that shares the day selects the tapped one', (
    tester,
  ) async {
    await _pump(
      tester,
      steps: [
        ['morning', 'night'],
        ['afternoon'],
      ],
    );
    // The first shift of the day is selected at first.
    expect(
      tester
          .widget<ChoicePill>(find.byKey(const ValueKey('shift-morning')))
          .selected,
      isTrue,
    );

    // Noche shares that day (its only one), so the offset does not move; even
    // so, the tapped pill must be the selected one.
    await tester.tap(find.byKey(const ValueKey('shift-night')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoicePill>(find.byKey(const ValueKey('shift-night')))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<ChoicePill>(find.byKey(const ValueKey('shift-morning')))
          .selected,
      isFalse,
    );
  });

  testWidgets('Basque keeps the ordinal as its own phrase, never glued to '
      'the display', (tester) async {
    final previous = catalogTexts;
    addTearDown(() => catalogTexts = previous);
    catalogTexts = catalogTextsFrom(lookupAppLocalizations(const Locale('eu')));
    await _pump(
      tester,
      steps: patternPresetById('continental').steps,
      locale: const Locale('eu'),
    );
    // The ordinal is «1. eguna», a whole phrase the message inserts on its
    // own; the run number leads the label.
    expect(
      find.text('1. sorta · 1. eguna, guztira 2 · Aurrekoa: Libre'),
      findsOneWidget,
    );
  });

  testWidgets('English ordinal select renders', (tester) async {
    final previous = catalogTexts;
    addTearDown(() => catalogTexts = previous);
    catalogTexts = catalogTextsFrom(lookupAppLocalizations(const Locale('en')));
    await _pump(
      tester,
      steps: patternPresetById('continental').steps,
      offset: 1,
      locale: const Locale('en'),
    );
    expect(find.text('Run 1 · Day 2 of 2, after Off'), findsOneWidget);
  });

  testWidgets('Catalan ordinal select renders', (tester) async {
    final previous = catalogTexts;
    addTearDown(() => catalogTexts = previous);
    catalogTexts = catalogTextsFrom(lookupAppLocalizations(const Locale('ca')));
    await _pump(
      tester,
      steps: patternPresetById('continental').steps,
      offset: 1,
      locale: const Locale('ca'),
    );
    expect(
      find.text('Tanda 1 · Dia 2 de 2, després de Lliure'),
      findsOneWidget,
    );
  });
}
