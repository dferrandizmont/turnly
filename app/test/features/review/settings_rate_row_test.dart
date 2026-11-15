import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/features/review/application/review_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';

class _FakePlatform implements StoreReviewPlatform {
  int listings = 0;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> requestReview() async {}

  @override
  Future<void> openStoreListing() async => listings++;
}

/// Ajustes › Ayuda: the «Valorar Turnly» row opens the store page.
void main() {
  setUpAll(initializeLocale);

  testWidgets('the row is in Settings and opens the store listing', (
    tester,
  ) async {
    final platform = _FakePlatform();
    final app = await AppUnderTest.pump(
      tester,
      size: const Size(390, 6000),
      overrides: [storeReviewPlatformProvider.overrideWithValue(platform)],
    );
    await app.openSettings();

    final row = find.byKey(const ValueKey('settings-rate'));
    expect(row, findsOneWidget);
    expect(find.text('Valorar Turnly'), findsOneWidget);
    expect(
      find.text('Una reseña ayuda a que otros la encuentren'),
      findsOneWidget,
    );

    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pump();
    expect(platform.listings, 1);
  });
}
