import 'dart:async';

import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/features/calendar/presentation/month_screen.dart';
import 'package:cuadrante/features/reports/presentation/report_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_font.dart';
import '../calendar/harness.dart';

/// iPad QA 1.1.0 F3: on an iPad mini in landscape the report sheet was nearly
/// as tall as the screen and «Crear y compartir» was cut at its bottom edge.
/// The options scroll inside the sheet and the button stays under them, so it
/// is within reach at any size and text scale, on both platforms.
const _sizes = {
  'iPad': Size(1024, 1366),
  'iPad landscape': Size(1366, 1024),
  'iPad mini': Size(744, 1133),
  'iPad mini landscape': Size(1133, 744),
  'Android tablet': Size(800, 1280),
  'Android tablet landscape': Size(1280, 800),
};

Finder _key(String value) => find.byKey(ValueKey(value));

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeLocale();
    expect(await loadRoboto(), isTrue, reason: 'Roboto from the Flutter SDK');
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final entry in _sizes.entries) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          '${platform.name}: ${entry.key}, text $scale: the action is within '
          'reach on first open',
          (tester) async {
            final size = entry.value;
            await pumpCalendar(tester, size: size, textScale: scale);
            unawaited(
              showReportSheet(
                tester.element(find.byType(MonthScreen)),
                month: fixedToday,
              ),
            );
            await tester.pumpAndSettle();

            final sheet = tester.getRect(find.byType(BottomSheet));
            final create = tester.getRect(_key('report-create'));
            expect(sheet.top, greaterThanOrEqualTo(0));
            expect(sheet.bottom, lessThanOrEqualTo(size.height));
            expect(
              create.bottom,
              lessThanOrEqualTo(sheet.bottom),
              reason: 'the button is inside the sheet: $create / $sheet',
            );
            expect(create.top, greaterThanOrEqualTo(sheet.top));
            expect(_key('report-create').hitTestable(), findsOneWidget);

            // The options above it still scroll to their last line.
            await tester.ensureVisible(_key('report-absences-detailed'));
            await tester.pumpAndSettle();
            expect(
              _key('report-absences-detailed').hitTestable(),
              findsOneWidget,
            );
            expect(
              tester.getRect(_key('report-absences-detailed')).bottom,
              lessThanOrEqualTo(tester.getRect(_key('report-create')).top),
              reason: 'the options end above the button, not behind it',
            );
            expect(tester.takeException(), isNull);
          },
          variant: TargetPlatformVariant.only(platform),
        );
      }
    }
  }
}
