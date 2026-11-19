import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/theme/app_theme.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/widget/data/widget_publisher.dart';
import 'package:cuadrante/features/widget/domain/widget_snapshot.dart';
import 'package:cuadrante/features/widget/domain/widget_snapshot_builder.dart';
import 'package:cuadrante/features/widget/domain/widget_strings.dart';
import 'package:cuadrante/features/widget/presentation/widget_previews.dart';
import 'package:cuadrante/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_font.dart';
import '../schedule/domain/fixtures.dart';

/// iPad QA 1.1.0 F8: the small-widget preview of Ajustes › Añadir widget cut
/// «06:00–14:…» and «Tomorrow: M 06–…» with an ellipsis. The preview is drawn
/// at the size of the home-screen widget and scaled, so a day with two shifts
/// cut the same on any screen: its lines now shrink to the width instead.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeLocale();
    expect(await loadRoboto(), isTrue, reason: 'Roboto from the Flutter SDK');
  });

  const today = CivilDate(2026, 10, 19);
  const tomorrow = CivilDate(2026, 10, 20);

  WidgetSnapshot snapshot(
    String locale,
    List<String> ids, {
    bool h12 = false,
  }) => buildWidgetSnapshot(
    schedule: Schedule(
      shiftTypes: allTypes,
      entries: {
        today: DayEntry(date: today, shiftTypeIds: ids),
        tomorrow: DayEntry(date: tomorrow, shiftTypeIds: ids),
      },
    ),
    holidays: const {},
    today: today,
    timeZone: 'Europe/Madrid',
    strings: WidgetStrings.fromL10n(lookupAppLocalizations(Locale(locale))),
    generatedAt: DateTime.utc(2026, 10, 19),
  );

  const tablets = {
    'iPad mini landscape': Size(1133, 744),
    'iPad portrait': Size(1024, 1366),
    'Android tablet landscape': Size(1280, 800),
  };

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final entry in tablets.entries) {
      for (final locale in ['es', 'en', 'ca', 'gl', 'eu']) {
        for (final ids in [
          ['morning'],
          ['morning', 'afternoon'],
        ]) {
          testWidgets(
            '${platform.name}: ${entry.key}, $locale, ${ids.join(' + ')}: '
            'no line of the small preview is cut',
            (tester) async {
              tester.view.physicalSize = entry.value * 2;
              tester.view.devicePixelRatio = 2;
              addTearDown(tester.view.reset);
              await tester.pumpWidget(
                MaterialApp(
                  theme: AppTheme.light(),
                  locale: Locale(locale),
                  home: Scaffold(
                    body: Center(
                      child: SizedBox(
                        width: 200,
                        child: WidgetPreview(
                          size: WidgetSize.small,
                          snapshot: snapshot(locale, ids),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              final cut = [
                for (final element in find.byType(RichText).evaluate())
                  if ((element.renderObject! as RenderParagraph)
                      .didExceedMaxLines)
                    (element.widget as RichText).text.toPlainText(),
              ];
              expect(cut, isEmpty, reason: 'cut with an ellipsis: $cut');
              // All the text is still there, only smaller.
              expect(find.textContaining('06'), findsWidgets);
              expect(tester.takeException(), isNull);
            },
            variant: TargetPlatformVariant.only(platform),
          );
        }
      }
    }
  }

  // The lines shrink like the iOS widget's (`WidgetViews.swift`: 0.5 for the
  // hours, 0.6 for tomorrow) and no further: past that they end in an
  // ellipsis.
  testWidgets('a long line never goes under the minimum scale', (tester) async {
    const long = ShiftType(
      id: 'long',
      name: 'Turno especial de refuerzo de fin de semana largo',
      code: 'R',
      colorValue: 0xFF4B4FD1,
      category: ShiftCategory.work,
    );
    final snap = buildWidgetSnapshot(
      schedule: Schedule(
        shiftTypes: [...allTypes, long],
        entries: {
          today: DayEntry(date: today, shiftTypeIds: const ['long']),
          tomorrow: DayEntry(
            date: tomorrow,
            shiftTypeIds: const ['morning', 'afternoon', 'night'],
          ),
        },
      ),
      holidays: const {},
      today: today,
      timeZone: 'Europe/Madrid',
      strings: WidgetStrings.fromL10n(
        lookupAppLocalizations(const Locale('es')),
      ),
      generatedAt: DateTime.utc(2026, 10, 19),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('es'),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              child: WidgetPreview(size: WidgetSize.small, snapshot: snap),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final type = tester.element(find.byType(WidgetPreview)).type;
    for (final (text, full, min) in [
      (
        snap.days.first.small.detail!,
        type.bodyStrong.fontSize!,
        detailMinScale,
      ),
      (
        snap.days.first.small.tomorrow,
        type.caption.fontSize!,
        tomorrowMinScale,
      ),
    ]) {
      final line = tester.widget<Text>(find.text(text));
      expect(
        line.style!.fontSize! / full,
        greaterThanOrEqualTo(min - 0.001),
        reason: text,
      );
      expect(line.overflow, TextOverflow.ellipsis);
      final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
      expect(
        paragraph.didExceedMaxLines,
        isTrue,
        reason: 'it is too long for the minimum scale and ends in an ellipsis',
      );
    }
    expect(tester.takeException(), isNull);
  });
}
