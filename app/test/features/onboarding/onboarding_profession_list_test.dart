import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/icons/app_icons.dart';
import 'package:cuadrante/core/widgets/choice_row.dart';
import 'package:cuadrante/features/onboarding/domain/profession.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'dart:ui' show CheckedState;
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_font.dart';
import '../../support/text_lines.dart';
import 'onboarding_support.dart';

/// «¿A qué te dedicas?»: now a single column inside one card, one row per job
/// with its usual hours underneath, single choice (only the chosen row carries
/// the mark).
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeLocale();
    expect(await loadRoboto(), isTrue, reason: 'Roboto from the Flutter SDK');
  });

  for (final width in [360.0, 412.0]) {
    testWidgets('one column at $width dp', (tester) async {
      final app = await FirstLaunch.open(tester, size: Size(width, 800));
      await app.toLastStep();
      await tester.ensureVisible(
        key('onboarding-profession-${spainProfessions.last.name}'),
      );
      await tester.pumpAndSettle();

      expect(brokenParagraphs(tester), isEmpty);

      final rects = [
        for (final profession in spainProfessions)
          tester.getRect(key('onboarding-profession-${profession.name}')),
      ];
      expect(rects, hasLength(spainProfessions.length));
      // A single column: every row starts at the same x.
      final lefts = {for (final r in rects) r.left.roundToDouble()}.toList()
        ..sort();
      expect(lefts, hasLength(1));
      // No row is marked before choosing anything.
      expect(find.byIcon(AppIcons.check), findsNothing);
      // Unchosen rows carry no icon at all.
      for (final profession in spainProfessions) {
        expect(
          find.descendant(
            of: key('onboarding-profession-${profession.name}'),
            matching: find.byIcon(AppIcons.check),
          ),
          findsNothing,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('tapping another profession moves the mark, only one remains', (
    tester,
  ) async {
    final app = await FirstLaunch.open(tester);
    await app.toLastStep();

    await app.tap(key('onboarding-profession-nursing'));
    expect(
      find.descendant(
        of: key('onboarding-profession-nursing'),
        matching: find.byIcon(AppIcons.check),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(AppIcons.check), findsOneWidget);

    await app.tap(key('onboarding-profession-police'));
    expect(
      find.descendant(
        of: key('onboarding-profession-police'),
        matching: find.byIcon(AppIcons.check),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: key('onboarding-profession-nursing'),
        matching: find.byIcon(AppIcons.check),
      ),
      findsNothing,
    );
    expect(find.byIcon(AppIcons.check), findsOneWidget);
  });

  testWidgets('semantics: mutually exclusive group, checked only in the chosen', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final app = await FirstLaunch.open(tester);
    await app.toLastStep();

    for (final profession in spainProfessions) {
      final data = tester
          .getSemantics(key('onboarding-profession-${profession.name}'))
          .getSemanticsData();
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
      expect(data.flagsCollection.isChecked, CheckedState.isFalse);
    }

    await app.tap(key('onboarding-profession-nursing'));
    expect(
      tester
          .getSemantics(key('onboarding-profession-nursing'))
          .getSemanticsData()
          .flagsCollection
          .isChecked,
      CheckedState.isTrue,
    );
    for (final profession in spainProfessions.where(
      (p) => p != Profession.nursing,
    )) {
      expect(
        tester
            .getSemantics(key('onboarding-profession-${profession.name}'))
            .getSemanticsData()
            .flagsCollection
            .isChecked,
        CheckedState.isFalse,
      );
    }
    handle.dispose();
  });

  for (final scale in [1.3, 2.0]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets('no overflow at 320 dp, text $scale, $brightness', (
        tester,
      ) async {
        final app = await FirstLaunch.open(
          tester,
          size: const Size(320, 800),
          textScale: scale,
          brightness: brightness,
        );
        await app.toLastStep();
        await tester.ensureVisible(
          key('onboarding-profession-${spainProfessions.last.name}'),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final width in [360.0, 412.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('no broken paragraphs at $width dp, text $scale', (
        tester,
      ) async {
        final app = await FirstLaunch.open(
          tester,
          size: Size(width, 800),
          textScale: scale,
        );
        await app.toLastStep();
        await tester.ensureVisible(
          key('onboarding-profession-${spainProfessions.last.name}'),
        );
        await tester.pumpAndSettle();
        expect(brokenParagraphs(tester), isEmpty);
      });
    }
  }

  testWidgets('compact: only the chosen row shows its hours line', (tester) async {
    final app = await FirstLaunch.open(tester);
    await app.chooseRotation();
    // Nothing chosen yet: no row carries its hours line.
    expect(
      tester
          .widgetList<ChoiceRow>(find.byType(ChoiceRow))
          .where((r) => r.subtitle != null)
          .length,
      0,
    );

    await app.tap(key('onboarding-profession-nursing'));
    await tester.pumpAndSettle();
    final rows = tester.widgetList<ChoiceRow>(find.byType(ChoiceRow)).toList();
    final withSubtitle = rows.where((r) => r.subtitle != null).toList();
    expect(withSubtitle, hasLength(1));
    expect(withSubtitle.single.label, 'Enfermería, TCAE y celadores');
  });
}
