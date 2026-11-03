import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/features/calendar/application/schedule_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_font.dart';
import '../../support/text_lines.dart';
import 'harness.dart';

// QA campaign, T02 (H-T02-11, H-T02-6): the title of paint mode showed
// «Mañ… · 08:00–15:00» at 412 dp and text x1.0, and at x2.0 the names of the
// tools broke inside a word. Since decision 28 the header is one line
// without the name of the tool (the hours moved to the preview); with the
// real font, on every width and text size, the header is never broken and no
// word of a tool is ever split.

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeLocale();
    expect(await loadRoboto(), isTrue, reason: 'Roboto from the Flutter SDK');
  });

  for (final width in [320.0, 360.0, 412.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('at $width dp, text $scale: a one-line header, no word is '
          'split', (tester) async {
        await pumpCalendar(tester, size: Size(width, 900), textScale: scale);
        await enterPaintMode(tester);
        final ids = [
          for (final s in containerOf(
            tester,
          ).read(scheduleControllerProvider).palette)
            s.id,
        ];

        for (final id in ids) {
          final tool = find.byKey(ValueKey('tool-$id'));
          await tester.ensureVisible(tool);
          await tester.pumpAndSettle();
          await tester.tap(tool);
          await tester.pumpAndSettle();

          // The header is one line, «PINTANDO · CAMBIAR EL TURNO» (decision
          // 28): the name and hours of the tool are not there any more.
          expect(find.byKey(const ValueKey('paint-title')), findsNothing);
          for (final key in ['paint-label', 'paint-mode-label']) {
            final paragraph = tester.renderObject<RenderParagraph>(
              find.byKey(ValueKey(key)),
            );
            expect(paragraphLines(paragraph), hasLength(1), reason: key);
            expect(paragraph.didExceedMaxLines, isFalse, reason: key);
          }

          // The names of the tools: whole words.
          for (final other in ids) {
            final label = find.descendant(
              of: find.byKey(ValueKey('tool-$other')),
              matching: find.byType(Text),
            );
            final paragraph = tester.renderObject<RenderParagraph>(label.last);
            expect(
              wrapsOnlyBetweenWords(paragraph),
              isTrue,
              reason: '$other breaks a word while $id is chosen',
            );
            expect(paragraph.didExceedMaxLines, isFalse, reason: other);
          }
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('the header reads naturally, with no stray separator', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpCalendar(tester, size: const Size(412, 900));
    await enterPaintMode(tester);
    final header = find.byKey(const ValueKey('paint-label'));
    expect(tester.getSemantics(header).label, 'Pintando, Cambiar el turno');
    await tester.tap(find.byKey(const ValueKey('tool-double')));
    await tester.pumpAndSettle();
    expect(tester.getSemantics(header).label, 'Pintando, Añadir otro turno');
    semantics.dispose();
  });
}
