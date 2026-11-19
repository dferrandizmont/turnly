import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/theme/theme_context.dart' show Sp;
import 'package:cuadrante/features/onboarding/presentation/choose_step.dart';
import 'package:cuadrante/features/onboarding/presentation/place_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_font.dart';
import 'onboarding_support.dart';

/// iPad QA 1.1.0 F6: on the tablet the first-use column was pinned to the top
/// with the lower half empty and «Siguiente» far below it. A step shorter than
/// the screen now sits in the middle between the bar and the button; a taller
/// one (large text) scrolls, from its top.
const _tablets = {
  'iPad': Size(1024, 1366),
  'iPad landscape': Size(1366, 1024),
  'iPad mini': Size(744, 1133),
  'iPad mini landscape': Size(1133, 744),
  'Android tablet': Size(800, 1280),
  'Android tablet landscape': Size(1280, 800),
};

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeLocale();
    expect(await loadRoboto(), isTrue, reason: 'Roboto from the Flutter SDK');
  });

  final scroll = find.byType(SingleChildScrollView).first;

  /// The step on screen inside the scroll view.
  Finder step() => find.descendant(
    of: scroll,
    matching: find.byWidgetPredicate((w) => w is ChooseStep || w is PlaceStep),
  );

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final entry in _tablets.entries) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          '${platform.name}: ${entry.key}, text $scale: a short step is '
          'centred, a tall one scrolls from the top',
          (tester) async {
            final app = await FirstLaunch.open(
              tester,
              size: entry.value,
              textScale: scale,
            );
            for (final stage in ['choose', 'place']) {
              if (stage == 'place') await app.choosePath('paint');
              expect(step(), findsOneWidget, reason: stage);
              final viewport = tester.getRect(scroll);
              final rect = tester.getRect(step());
              final position = tester
                  .state<ScrollableState>(
                    find.descendant(
                      of: scroll,
                      matching: find.byType(Scrollable),
                    ),
                  )
                  .position;
              if (position.maxScrollExtent > 0) {
                // Taller than the screen: it starts at the top and scrolls (with
                // large text the bar scrolls with it, so it can be a bar down).
                expect(position.pixels, 0, reason: stage);
                expect(
                  rect.top - viewport.top,
                  lessThanOrEqualTo(Sp.touch + Sp.xl + Sp.l),
                  reason: stage,
                );
              } else {
                // Shorter: about as much room above it as below it (the page
                // padding is 16 dp on top and 24 under, and «Siguiente» takes
                // its own room under it).
                final above = rect.top - viewport.top;
                final below = viewport.bottom - rect.bottom;
                expect(
                  (above - below).abs(),
                  lessThan(48),
                  reason: '$stage is not centred: $above above, $below below',
                );
                if (viewport.height - rect.height > 200) {
                  expect(
                    above,
                    greaterThan(Sp.l + Sp.section),
                    reason: '$stage is pinned to the top',
                  );
                }
              }
            }
            expect(tester.takeException(), isNull);
          },
          variant: TargetPlatformVariant.only(platform),
        );
      }
    }
  }

  testWidgets('a phone keeps the step at the top', (tester) async {
    await FirstLaunch.open(tester, size: const Size(390, 844));
    final viewport = tester.getRect(scroll);
    expect(tester.getRect(step()).top - viewport.top, closeTo(16, 0.5));
  });
}
