import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/features/calendar/presentation/month_screen.dart';
import 'package:cuadrante/features/onboarding/application/onboarding_controller.dart';
import 'package:cuadrante/features/onboarding/domain/profession.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_font.dart';
import 'onboarding_support.dart';

// Q50/Q51: the emulator's 1080×2400 screen at 2.625 px/dp, with system bars.
const _pixelRatio = 2.625;
const _phone = Size(1080 / _pixelRatio, 2400 / _pixelRatio);

Future<FirstLaunch> _open(WidgetTester tester) async {
  final app = await FirstLaunch.open(tester, size: _phone);
  tester.view.devicePixelRatio = _pixelRatio;
  tester.view.physicalSize = const Size(1080, 2400);
  const padding = FakeViewPadding(
    top: 24 * _pixelRatio,
    bottom: 24 * _pixelRatio,
  );
  tester.view.padding = padding;
  tester.view.viewPadding = padding;
  addTearDown(() {
    tester.view.resetPadding();
    tester.view.resetViewPadding();
  });
  await tester.pumpAndSettle();
  return app;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeLocale();
    expect(await loadRoboto(), isTrue);
  });

  testWidgets('Q50: profession list leaves Next reachable on the QA phone', (
    tester,
  ) async {
    final app = await _open(tester);
    await app.choosePath('rotation');
    expect(app.title, '¿Dónde trabajas?');
    await app.tap(key('onboarding-region'));
    await app.tap(find.text('Comunidad de Madrid'));
    await app.tap(key('onboarding-next'));
    expect(app.title, '¿Cómo es tu rotación?');
    await app.tap(key('onboarding-profession-nursing'));
    expect(
      app.container.read(onboardingControllerProvider).profession,
      Profession.nursing,
    );
    await app.tap(key('onboarding-pattern-12h'));

    // No scroll-to-button helper: the fixed footer must remain tappable
    // after revealing and choosing a row in the profession list.
    expect(key('onboarding-next').hitTestable(), findsOneWidget);
    final rect = tester.getRect(key('onboarding-next'));
    expect(rect.bottom, lessThanOrEqualTo(_phone.height - 24));
    await tester.tap(key('onboarding-next'));
    await tester.pumpAndSettle();
    expect(app.title, '¿Cuándo empiezas?');
    await app.tap(key('onboarding-offset-1'));
    await app.tap(key('onboarding-next'));
    expect(app.title, 'Listo');
    await app.tap(key('onboarding-next'));
    expect(find.byType(MonthScreen), findsOneWidget);
    await app.flushWrites();
    expect(idsOn(app.schedule, onboardingToday), 'night12');
    expect(idsOn(app.schedule, onboardingToday.addDays(1)), 'postNight');
    expect(idsOn(app.schedule, onboardingToday.addDays(3)), 'day12');
    final profile = await app.real(
      () => app.database
          .customSelect(
            "SELECT value FROM settings WHERE key = 'onboarding.profile'",
          )
          .getSingle(),
    );
    expect(profile.read<String>('value'), '"nursing"');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Q51: skip the place, go back, then skip import and place', (
    tester,
  ) async {
    final app = await _open(tester);
    await app.choosePath('rotation');
    expect(app.title, '¿Dónde trabajas?');
    await app.tap(key('onboarding-skip'));
    expect(app.title, '¿Cómo es tu rotación?');
    await app.tap(key('onboarding-back'));
    expect(app.title, '¿Dónde trabajas?');
    await app.tap(key('onboarding-back'));
    expect(app.title, '¿Cómo empiezas tu cuadrante?');
    await app.choosePath('import');
    expect(app.title, '¿Vienes de otra app?');
    await app.tap(key('onboarding-skip'));
    expect(app.title, '¿Dónde trabajas?');
    await app.tap(key('onboarding-skip'));
    expect(app.title, 'Listo');
    await app.tap(key('onboarding-next'));
    expect(find.byType(MonthScreen), findsOneWidget);
    await app.flushWrites();
    expect(app.schedule.runs, isEmpty);
    expect(app.schedule.entries, isEmpty);
    final settings = await app.real(
      () => app.database
          .customSelect(
            'SELECT key, value FROM settings WHERE key IN '
            "('onboarding.done', 'onboarding.profile', 'holidays.region')",
          )
          .get(),
    );
    expect(settings, hasLength(1));
    expect(settings.single.read<String>('key'), 'onboarding.done');
    expect(settings.single.read<String>('value'), 'true');
    expect(tester.takeException(), isNull);
  });
}
