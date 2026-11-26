import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/widgets/whole_word_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_font.dart';
import '../../support/text_lines.dart';
import 'harness.dart';

/// iOS 1.2.2 QA, F1: on a phone in landscape with the text at AX3 (about x3.1)
/// the side pane broke shift names and hours in the middle of a word in the
/// «Hoy» card and in «Próximos días» («Nig / ht», «22:0 / 0», «Aftern / oon»).
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeLocale();
    expect(await loadRoboto(), isTrue, reason: 'Roboto from the Flutter SDK');
  });

  const landscape = Size(852, 393);
  Finder key(String k) => find.byKey(ValueKey(k));

  /// Whether [paragraph] wraps only between words. An hour range counts as one
  /// word: it never breaks after its dash («22:00–» then «06:00», N1 of 1.2.3).
  bool wholeWords(RenderParagraph paragraph) {
    List<String> words(String text) => text
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    return [for (final line in paragraphLines(paragraph)) ...words(line)]
            .length ==
        words(paragraph.text.toPlainText()).length;
  }

  /// The paragraphs of the pane that break inside a word.
  List<String> brokenInPane(WidgetTester tester) => [
    for (final element
        in find
            .descendant(of: key('pane-today'), matching: find.byType(RichText))
            .evaluate())
      if (!wholeWords(element.renderObject! as RenderParagraph))
        paragraphLines(element.renderObject! as RenderParagraph).join(' | '),
  ];

  for (final locale in [const Locale('es'), const Locale('en')]) {
    testWidgets('${locale.languageCode}: landscape, text x3.1: the pane of '
        'the month wraps between words', (tester) async {
      await pumpCalendar(
        tester,
        size: landscape,
        textScale: 3.1,
        locale: locale,
      );
      expect(key('pane-divider'), findsOneWidget);
      expect(key('pane-today'), findsOneWidget);

      final position = tester
          .state<ScrollableState>(
            find.descendant(
              of: key('pane-today'),
              matching: find.byType(Scrollable),
            ),
          )
          .position;
      position.jumpTo(0);
      var sawUpcoming = false;
      for (var i = 0; i < 60; i++) {
        await tester.pump();
        expect(brokenInPane(tester), isEmpty, reason: 'scroll $i');
        if (key('upcoming-2026-10-20').evaluate().isNotEmpty) {
          sawUpcoming = true;
        }
        if (position.pixels >= position.maxScrollExtent) break;
        position.jumpTo(
          (position.pixels + 120).clamp(0, position.maxScrollExtent).toDouble(),
        );
      }
      expect(sawUpcoming, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the hours and the names of the next days are on screen', (
    tester,
  ) async {
    await pumpCalendar(
      tester,
      size: landscape,
      textScale: 3.1,
      locale: const Locale('es'),
    );
    // Monday 20 has «Noche»: the name and its hours are drawn whole.
    final row = key('upcoming-2026-10-20');
    await tester.scrollUntilVisible(
      row,
      100,
      scrollable: find.descendant(
        of: key('pane-today'),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    final texts = [
      for (final e
          in find
              .descendant(of: row, matching: find.byType(RichText))
              .evaluate())
        (e.renderObject! as RenderParagraph).text.toPlainText(),
    ];
    expect(texts.any((t) => t.contains('Noche')), isTrue, reason: '$texts');
    expect(texts.any((t) => t.contains('22:00')), isTrue, reason: '$texts');
    expect(tester.takeException(), isNull);
  });

  group('WholeWordText', () {
    Future<void> pump(
      WidgetTester tester, {
      required double width,
      required double scale,
      String text = 'Afternoon 22:00',
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: WholeWordText(
                  text,
                  style: const TextStyle(fontSize: 16, fontFamily: 'Roboto'),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('a text that fits keeps the size the reader chose', (
      tester,
    ) async {
      await pump(tester, width: 400, scale: 1.3);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.byType(RichText).last,
      );
      expect(paragraph.textScaler.scale(16), closeTo(16 * 1.3, 0.001));
      expect(wrapsOnlyBetweenWords(paragraph), isTrue);
    });

    testWidgets('a word wider than the box shrinks the text until it fits, '
        'never below the normal size', (tester) async {
      await pump(tester, width: 110, scale: 3.1);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.byType(RichText).last,
      );
      expect(paragraph.textScaler.scale(16), lessThan(16 * 3.1));
      expect(paragraph.textScaler.scale(16), greaterThanOrEqualTo(16));
      expect(wrapsOnlyBetweenWords(paragraph), isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}
