import 'package:cuadrante/core/widgets/app_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const footerKey = ValueKey('footer');
  const bodyKey = ValueKey('body');

  Future<void> pumpSheet(
    WidgetTester tester, {
    double keyboardInset = 0,
    double footerHeight = 48,
    bool hasFooter = true,
  }) => tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          viewInsets: EdgeInsets.only(bottom: keyboardInset),
        ),
        child: Center(
          child: SizedBox(
            height: 400,
            child: AppSheetBody(
              footerHeight: footerHeight,
              footer: hasFooter
                  ? SizedBox(key: footerKey, height: footerHeight)
                  : null,
              child: const SizedBox(key: bodyKey, height: 600),
            ),
          ),
        ),
      ),
    ),
  );

  final scroll = find.byType(SingleChildScrollView);
  final footer = find.byKey(footerKey);
  Finder footerInScroll() => find.descendant(of: scroll, matching: footer);

  testWidgets('the keyboard moves a pinned footer into the scroll view', (
    tester,
  ) async {
    await pumpSheet(tester);
    expect(footer, findsOneWidget);
    expect(footerInScroll(), findsNothing);
    await pumpSheet(tester, keyboardInset: 100);
    expect(footerInScroll(), findsOneWidget);
  });

  testWidgets('a footer above 40 percent of the available height scrolls', (
    tester,
  ) async {
    await pumpSheet(tester, footerHeight: 170);
    expect(footerInScroll(), findsOneWidget);
  });

  testWidgets(
    'a sheet without a footer puts its body directly in the scroll view',
    (tester) async {
      await pumpSheet(tester, hasFooter: false);
      expect(footer, findsNothing);
      expect(tester.widget<SingleChildScrollView>(scroll).child?.key, bodyKey);
    },
  );
}
