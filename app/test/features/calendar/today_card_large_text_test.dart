import 'package:cuadrante/features/calendar/presentation/today_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_font.dart';
import 'harness.dart';

// 0.11.2 QA: at AX3 (text x3) the open «Hoy» card still took about half of
// the screen. Measured with the real font, as on a phone.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    expect(await loadRoboto(), isTrue, reason: 'Roboto from the Flutter SDK');
  });

  for (final size in [
    const Size(390, 844),
    const Size(414, 896),
    const Size(412, 915),
  ]) {
    testWidgets('at AX3 the open card takes about a third of $size', (
      tester,
    ) async {
      await pumpCalendar(
        tester,
        textScale: 3.0,
        size: size,
        clock: () => DateTime(2026, 10, 19, 18, 20),
      );
      expect(find.byKey(const ValueKey('today-card-open')), findsOneWidget);
      final card = tester.getSize(find.byType(TodayCard)).height;
      expect(card / size.height, lessThanOrEqualTo(0.36));
    });
  }
}
