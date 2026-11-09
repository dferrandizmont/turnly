import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/widgets/choice_pill.dart';
import 'package:cuadrante/features/onboarding/domain/profession.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_font.dart';
import '../../support/text_lines.dart';
import 'onboarding_support.dart';

/// «¿A qué te dedicas?» (9-nov-2026): the jobs were a ragged Wrap; they are an
/// aligned grid now, equal cells in level rows, and a label wraps between
/// words inside its cell.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeLocale();
    expect(await loadRoboto(), isTrue, reason: 'Roboto from the Flutter SDK');
  });

  List<Rect> pills(WidgetTester tester) => [
    for (final profession in spainProfessions)
      tester.getRect(key('onboarding-profession-${profession.name}')),
  ];

  for (final width in [360.0, 412.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('the jobs are in aligned columns at $width dp, text $scale', (
        tester,
      ) async {
        final app = await FirstLaunch.open(
          tester,
          size: Size(width, 800),
          textScale: scale,
        );
        await app.toLastStep();
        await tester.ensureVisible(
          key('onboarding-profession-${spainProfessions.first.name}'),
        );
        await tester.pumpAndSettle();

        final rects = pills(tester);
        expect(rects, hasLength(spainProfessions.length));
        // Equal cells.
        for (final r in rects) {
          expect(r.width, closeTo(rects.first.width, 0.5));
        }
        // Level rows: pills sharing a top share a height.
        final lefts = {for (final r in rects) r.left.roundToDouble()}.toList()
          ..sort();
        final tops = {for (final r in rects) r.top.roundToDouble()}.toList();
        expect(lefts.length, lessThanOrEqualTo(3));
        // Columns line up: a row starts at the first column and fills from
        // the left.
        for (final top in tops) {
          final row = [
            for (final r in rects)
              if (r.top.roundToDouble() == top) r,
          ];
          for (final r in row) {
            expect(r.height, closeTo(row.first.height, 0.5));
          }
          final rowLefts = [for (final r in row) r.left.roundToDouble()]
            ..sort();
          expect(rowLefts, lefts.take(rowLefts.length).toList());
        }
        // Two columns on a phone at the normal text size, one with large
        // text, never a word broken.
        if (scale == 1.0) expect(lefts.length, 2);
        if (scale == 2.0) expect(lefts.length, 1);
        expect(brokenParagraphs(tester), isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('a job can still be chosen in the grid', (tester) async {
    final app = await FirstLaunch.open(tester);
    await app.toLastStep();
    final nursing = key('onboarding-profession-nursing');
    expect(tester.widget<ChoicePill>(nursing).selected, isFalse);
    await app.tap(nursing);
    expect(tester.widget<ChoicePill>(nursing).selected, isTrue);
  });
}
