import 'dart:async';

import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/router.dart';
import 'package:cuadrante/core/theme/theme_context.dart';
import 'package:cuadrante/core/widgets/value_row.dart';
import 'package:cuadrante/features/calendar/presentation/month_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/real_font.dart';
import '../../support/text_lines.dart';
import '../calendar/harness.dart';

// 1.1.0 QA, F11: in Catalan «Quant a» wrapped to «Quant / a» beside the
// version, and in Basque the base hourly rate row put its title and help in a
// column of nine lines beside a long value. A short label that fits on a line
// of its own, and a title that would be left in a narrow column, go above
// their value instead.

const _glyph = 7.5;
const _style = TextStyle(fontSize: _glyph);

Widget _row({
  required String title,
  required String value,
  String? subtitle,
  double width = 300,
}) => Align(
  alignment: Alignment.topLeft,
  child: SizedBox(
    width: width,
    child: ValueRow(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, key: const ValueKey('title'), style: _style),
          if (subtitle != null)
            Text(subtitle, key: const ValueKey('subtitle'), style: _style),
        ],
      ),
      value: Text(value, key: const ValueKey('value'), style: _style),
      valueGap: 8,
    ),
  ),
);

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.noScaling),
      child: Scaffold(body: child),
    ),
  ),
);

void main() {
  setUpAll(initializeLocale);

  group('ValueRow: a short label does not wrap beside its value', () {
    testWidgets('«Quant a» and a long version stack', (tester) async {
      // The longest word of the title and the value fit side by side; the
      // whole title and the value do not.
      await _pump(
        tester,
        _row(title: 'Quant a', value: 'Versió 1.10', width: 130),
      );
      final title = tester.getRect(find.byKey(const ValueKey('title')));
      final value = tester.getRect(find.byKey(const ValueKey('value')));
      expect(value.top, greaterThanOrEqualTo(title.bottom - 0.5));
      expect(value.left, closeTo(title.left, 0.5));
      final paragraph = tester.renderObject<RenderParagraph>(
        find.byKey(const ValueKey('title')),
      );
      expect(paragraph.size.height, lessThan(_glyph * 2));
    });

    testWidgets('a title that fits beside the value stays beside it', (
      tester,
    ) async {
      await _pump(tester, _row(title: 'Quant a', value: 'Versió 1.1.0'));
      final title = tester.getRect(find.byKey(const ValueKey('title')));
      final value = tester.getRect(find.byKey(const ValueKey('value')));
      expect(value.top, lessThan(title.bottom));
      expect(value.left, greaterThan(title.right));
    });

    testWidgets('a title with a long help is not squeezed beside a long '
        'value', (tester) async {
      await _pump(
        tester,
        _row(
          title: 'Orduko oinarrizko prezioa',
          subtitle:
              'Txanda bezala ordaintzen diren aparteko orduek erabiltzen '
              'dute, preziodun txandarik gabeko egunetan.',
          value: 'Oinarrizko preziorik ez',
          width: 280,
        ),
      );
      final title = tester.getRect(find.byKey(const ValueKey('title')));
      final value = tester.getRect(find.byKey(const ValueKey('value')));
      final subtitle = tester.getRect(find.byKey(const ValueKey('subtitle')));
      // The help has most of the row, not a column of nine lines.
      expect(subtitle.width, greaterThan(280 * 0.6));
      expect(value.top, greaterThanOrEqualTo(subtitle.bottom - 0.5));
      expect(value.left, closeTo(title.left, 0.5));
    });

    testWidgets('a long help beside a short value keeps the value beside', (
      tester,
    ) async {
      await _pump(
        tester,
        _row(
          title: 'Titulo',
          subtitle:
              'Una ayuda larga que ocupa varias lineas en una fila de ajustes',
          value: '2 h',
          width: 280,
        ),
      );
      final title = tester.getRect(find.byKey(const ValueKey('title')));
      final value = tester.getRect(find.byKey(const ValueKey('value')));
      final subtitle = tester.getRect(find.byKey(const ValueKey('subtitle')));
      expect(value.left, greaterThan(title.right));
      expect(value.top, lessThan(subtitle.bottom));
    });
  });

  group('the settings screen in Catalan and Basque', () {
    setUp(() {});

    Future<void> openSettings(WidgetTester tester, Locale locale) async {
      expect(await tester.runAsync(loadRoboto), isTrue);
      addTearDown(() => AppTypography.debugFamily = null);
      await pumpCalendar(tester, size: const Size(376, 780), locale: locale);
      unawaited(
        GoRouter.of(tester.element(find.byType(MonthScreen)))
            .push(AppRoutes.settings),
      );
      await tester.pumpAndSettle();
    }

    Future<void> reveal(WidgetTester tester, String key) async {
      final finder = find.byKey(ValueKey(key));
      await tester.scrollUntilVisible(
        finder,
        300,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 60,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('ca: «Quant a» stays on one line', (tester) async {
      await openSettings(tester, const Locale('ca'));
      await reveal(tester, 'settings-about');
      final title = find.descendant(
        of: find.byKey(const ValueKey('settings-about')),
        matching: find.text('Quant a'),
      );
      final lines = paragraphLines(tester.renderObject<RenderParagraph>(title));
      expect(lines, ['Quant a']);
    });

    testWidgets('eu: the base rate row keeps a readable title and help', (
      tester,
    ) async {
      await openSettings(tester, const Locale('eu'));
      await reveal(tester, 'settings-overtime-base-rate');
      final row = find.byKey(const ValueKey('settings-overtime-base-rate'));
      final rowRect = tester.getRect(row);
      final texts = find.descendant(of: row, matching: find.byType(Text));
      for (final element in texts.evaluate()) {
        final paragraph = element.renderObject!.parent;
        expect(paragraph, isNotNull);
      }
      // No text of the row is squeezed into a column under 40 % of the row.
      for (final element
          in find
              .descendant(of: row, matching: find.byType(RichText))
              .evaluate()) {
        final render = element.renderObject! as RenderParagraph;
        final text = render.text.toPlainText();
        if (text.length < 8) continue;
        expect(
          render.size.width,
          greaterThan(rowRect.width * 0.4),
          reason: '«$text» in a column of ${render.size.width}',
        );
        expect(wrapsOnlyBetweenWords(render), isTrue, reason: text);
      }
      expect(tester.takeException(), isNull);
    });
  });
}
