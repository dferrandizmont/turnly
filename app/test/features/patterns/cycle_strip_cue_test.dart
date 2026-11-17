import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/theme/app_theme.dart';
import 'package:cuadrante/features/patterns/presentation/cycle_strip.dart';
import 'package:cuadrante/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// iOS 1.2.0 QA, iPad F2: the strip of the cycle showed 5 cells and a thin
// scrollbar was the only sign that more waited to the side.

double _opacity(WidgetTester tester, String key) => tester
    .widget<AnimatedOpacity>(
      find.ancestor(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(AnimatedOpacity),
      ),
    )
    .opacity;

Future<void> _pump(
  WidgetTester tester, {
  required int days,
  double? width,
  Color? fadeColor,
  bool reduceMotion = false,
}) {
  tester.view.physicalSize = const Size(900, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('es'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(2.35),
          disableAnimations: reduceMotion,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width ?? 300,
            child: CycleStrip(
              steps: [for (var i = 0; i < days; i++) const <String>[]],
              shiftOf: (_) => null,
              offset: 0,
              onOffsetChanged: (_) {},
              keyPrefix: 't-',
              fadeColor: fadeColor,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(initializeLocale);

  testWidgets('a strip that scrolls fades its end, and its start once moved', (
    tester,
  ) async {
    await _pump(tester, days: 14);
    await tester.pumpAndSettle();
    expect(_opacity(tester, 't-cycle-fade-end'), 1);
    expect(_opacity(tester, 't-cycle-fade-start'), 0);

    final scroll = find.byType(SingleChildScrollView).first;
    await tester.drag(scroll, const Offset(-2000, 0));
    await tester.pumpAndSettle();
    expect(_opacity(tester, 't-cycle-fade-end'), 0);
    expect(_opacity(tester, 't-cycle-fade-start'), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a strip that fits has no fades', (tester) async {
    await _pump(tester, days: 7, width: 880);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('t-cycle-fade-end')), findsNothing);
    expect(find.byKey(const ValueKey('t-cycle-fade-start')), findsNothing);
  });

  testWidgets('reduce motion: the fades change at once', (tester) async {
    await _pump(tester, days: 14, reduceMotion: true);
    await tester.pumpAndSettle();
    final fade = tester.widget<AnimatedOpacity>(
      find.ancestor(
        of: find.byKey(const ValueKey('t-cycle-fade-end')),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(fade.duration, Duration.zero);
  });

  testWidgets('the fades go to the colour of the surface they sit on', (
    tester,
  ) async {
    const surface = Color(0xFF123456);
    await _pump(tester, days: 14, fadeColor: surface);
    await tester.pumpAndSettle();
    final box = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('t-cycle-fade-end')),
    );
    final gradient =
        (box.decoration as BoxDecoration).gradient! as LinearGradient;
    expect(gradient.colors.first, surface);
  });
}
