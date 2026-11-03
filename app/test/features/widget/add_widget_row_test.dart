import 'package:cuadrante/core/router.dart';
import 'package:cuadrante/features/widget/application/widget_providers.dart';
import 'package:cuadrante/features/widget/data/widget_publisher.dart';
import 'package:cuadrante/features/widget/presentation/widget_previews.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../calendar/harness.dart';

Finder _key(String key) => find.byKey(ValueKey(key));

Future<void> _openRow(WidgetTester tester) async {
  final row = _key('settings-widget');
  await tester.scrollUntilVisible(
    row,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(row);
  await tester.pumpAndSettle();
}

/// Taps the gallery tile of [id] («small», «two-weeks»…).
Future<void> _choose(WidgetTester tester, String id) async {
  final tile = _key('widget-preview-$id');
  await tester.ensureVisible(tile);
  await tester.pumpAndSettle();
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

const _ids = ['small', 'agenda', 'medium', 'two-weeks', 'four-weeks', 'large'];

void main() {
  testWidgets('Ajustes has the row; without pinning the gallery stays and '
      'the steps replace the button', (tester) async {
    final publisher = FakeWidgetPublisher();
    final app = await AppUnderTest.pump(
      tester,
      overrides: [widgetPublisherProvider.overrideWithValue(publisher)],
    );
    await app.openSettings();
    expect(find.text('Añadir widget'), findsOneWidget);
    await _openRow(tester);
    for (final id in _ids) {
      expect(_key('widget-preview-$id'), findsOneWidget, reason: id);
    }
    expect(_key('widget-add-manual'), findsOneWidget);
    expect(find.textContaining('Mantén pulsada'), findsOneWidget);
    for (final id in _ids) {
      expect(_key('widget-pin-$id'), findsNothing, reason: id);
    }
    expect(publisher.pinRequests, isEmpty);
  });

  testWidgets('where the launcher can pin, the chosen widget is the one the '
      'button adds', (tester) async {
    final publisher = FakeWidgetPublisher()..pinSupported = true;
    final app = await AppUnderTest.pump(
      tester,
      overrides: [widgetPublisherProvider.overrideWithValue(publisher)],
    );
    await app.openSettings();
    await _openRow(tester);
    expect(_key('widget-add-manual'), findsNothing);
    // Mediano is chosen at first, as in the design.
    expect(find.text('Añadir Mediano'), findsOneWidget);
    await tester.tap(_key('widget-pin-medium'));
    await tester.pumpAndSettle();
    expect(publisher.pinRequests, [WidgetSize.medium]);

    final expected = <WidgetSize>[WidgetSize.medium];
    for (final (id, size, label) in [
      ('small', WidgetSize.small, 'Añadir Pequeño'),
      ('large', WidgetSize.large, 'Añadir Grande'),
      ('agenda', WidgetSize.agenda, 'Añadir Agenda'),
      ('two-weeks', WidgetSize.twoWeeks, 'Añadir Dos semanas'),
      ('four-weeks', WidgetSize.fourWeeks, 'Añadir Cuatro semanas'),
    ]) {
      await _openRow(tester);
      await _choose(tester, id);
      expect(find.text(label), findsOneWidget, reason: id);
      expect(_key('widget-pin-medium'), findsNothing, reason: id);
      await tester.tap(_key('widget-pin-$id'));
      await tester.pumpAndSettle();
      expected.add(size);
      expect(publisher.pinRequests, expected, reason: id);
    }
  });

  testWidgets('each tile is one button for screen readers, selected or not', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final app = await AppUnderTest.pump(
      tester,
      overrides: [
        widgetPublisherProvider.overrideWithValue(
          FakeWidgetPublisher()..pinSupported = true,
        ),
      ],
    );
    await app.openSettings();
    await _openRow(tester);
    expect(
      tester.getSemantics(_key('widget-preview-medium')),
      matchesSemantics(
        label: 'Mediano: los próximos 7 días',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(_key('widget-preview-agenda')),
      matchesSemantics(
        label: 'Agenda: próximos turnos',
        isButton: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('the drawings show the real shifts of today and the week', (
    tester,
  ) async {
    final app = await AppUnderTest.pump(
      tester,
      overrides: [
        widgetPublisherProvider.overrideWithValue(FakeWidgetPublisher()),
      ],
    );
    await app.openSettings();
    await _openRow(tester);
    expect(find.byType(WidgetPreview), findsNWidgets(6));
    // Monday 19 October 2026 is a Noche in the demo data: the small widget
    // says so in big, the strip of the medium one starts with it.
    expect(
      find.descendant(
        of: _key('widget-preview-small'),
        matching: find.text('N'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _key('widget-preview-medium'),
        matching: find.text('N'),
      ),
      findsWidgets,
    );
  });

  for (final brightness in Brightness.values) {
    for (final (size, scale) in [
      (const Size(320, 568), 2.0),
      (const Size(390, 844), 1.0),
    ]) {
      testWidgets('the gallery fits ${size.width.toInt()} dp x$scale in '
          '${brightness.name}', (tester) async {
        await pumpCalendar(
          tester,
          size: size,
          textScale: scale,
          brightness: brightness,
          overrides: [
            widgetPublisherProvider.overrideWithValue(
              FakeWidgetPublisher()..pinSupported = true,
            ),
          ],
        );
        containerOf(tester).read(routerProvider).go(AppRoutes.settings);
        await tester.pumpAndSettle();
        await _openRow(tester);
        expect(tester.takeException(), isNull);
        for (final id in _ids) {
          await tester.ensureVisible(_key('widget-preview-$id'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: id);
        }
        await _choose(tester, 'large');
        expect(_key('widget-pin-large'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
