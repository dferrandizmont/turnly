import 'package:cuadrante/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// P8 · Apariencia (option 8.3 of the 31-oct canvas): five accents, Índigo
/// by default. Every accent reaches AA in light and dark, and it only paints
/// links, switches, selection and tabs: never the shifts nor the amber.
void main() {
  const aa = 4.5;
  // Non-text contrast (WCAG 1.4.11): icons and the switch track.
  const nonText = 3.0;

  group('every accent passes AA', () {
    for (final accent in AppAccent.values) {
      for (final base in [AppColors.light, AppColors.dark]) {
        final mode = base.isDark ? 'dark' : 'light';
        test('${accent.stored} · $mode', () {
          final c = base.withAccent(accent);
          // Links and small accent text on every surface they sit on.
          for (final (name, surface) in [
            ('background', c.background),
            ('surface', c.surface),
            ('surfaceRaised', c.surfaceRaised),
          ]) {
            expect(
              contrastRatio(c.accentText, surface),
              greaterThanOrEqualTo(aa),
              reason: 'accentText on $name',
            );
          }
          // The check of a checkbox, the text of a badge, the selected day.
          expect(contrastRatio(c.onAccent, c.accent), greaterThanOrEqualTo(aa));
          // The label of a selected row or pill over the soft fill.
          expect(
            contrastRatio(c.textPrimary, c.accentSoft),
            greaterThanOrEqualTo(aa),
          );
          // The selected tab icon over its indicator.
          expect(
            contrastRatio(c.accent, c.accentSoft),
            greaterThanOrEqualTo(nonText),
          );
          // The track of an on switch against the card.
          expect(
            contrastRatio(c.accent, c.surface),
            greaterThanOrEqualTo(nonText),
          );
        });
      }
    }

    test('the snack bar action reads on the snack bar in both modes', () {
      for (final accent in AppAccent.values) {
        for (final theme in [
          AppTheme.light(accent: accent),
          AppTheme.dark(accent: accent),
        ]) {
          final bar = theme.snackBarTheme.backgroundColor!;
          expect(
            contrastRatio(theme.snackBarTheme.actionTextColor!, bar),
            greaterThanOrEqualTo(aa),
            reason: '${accent.stored} ${theme.brightness.name}',
          );
        }
      }
    });
  });

  group('what the accent changes', () {
    test('Índigo is the accent the app always had', () {
      expect(AppAccent.defaultAccent, AppAccent.indigo);
      for (final base in [AppColors.light, AppColors.dark]) {
        final c = base.withAccent(AppAccent.indigo);
        expect(c.accent, base.accent);
        expect(c.accentText, base.accentText);
        expect(c.accentSoft, base.accentSoft);
      }
      expect(AppTheme.light().colorScheme.primary, AppColors.light.accent);
    });

    test('links, switches, selection and tabs follow the accent', () {
      for (final accent in AppAccent.values) {
        final light = AppTheme.light(accent: accent);
        final dark = AppTheme.dark(accent: accent);
        expect(light.colorScheme.primary, accent.light);
        expect(dark.colorScheme.primary, accent.dark);
        expect(light.extension<AppColors>()!.accentText, accent.light);
        expect(dark.extension<AppColors>()!.accentSoft, accent.darkSoft);
        expect(
          light.switchTheme.trackColor!.resolve({WidgetState.selected}),
          accent.light,
        );
        expect(
          light.checkboxTheme.fillColor!.resolve({WidgetState.selected}),
          accent.light,
        );
        expect(light.navigationBarTheme.indicatorColor, accent.lightSoft);
        expect(
          light.textButtonTheme.style!.foregroundColor!.resolve({}),
          accent.light,
        );
      }
    });

    test('never the amber, the today ring, the buttons or the shifts', () {
      for (final base in [AppColors.light, AppColors.dark]) {
        for (final accent in AppAccent.values) {
          final c = base.withAccent(accent);
          expect(c.highlight, base.highlight);
          expect(c.onHighlight, base.onHighlight);
          expect(c.todayRing, base.todayRing);
          expect(c.primaryButton, base.primaryButton);
          expect(c.fab, base.fab);
          expect(c.onFab, base.onFab);
          expect(c.holiday, base.holiday);
          expect(c.background, base.background);
          expect(c.surface, base.surface);
          expect(c.textMuted, base.textMuted);
        }
      }
      // The shift colours (`ShiftSwatch.forColor`) are derived from the
      // stored colour and the brightness only: the accent has no way in.
    });

    test('the themes are built once per combination', () {
      expect(
        identical(
          AppTheme.dark(accent: AppAccent.blue),
          AppTheme.dark(accent: AppAccent.blue),
        ),
        isTrue,
      );
      expect(identical(AppTheme.light(), AppTheme.dark()), isFalse);
    });
  });

  group('stored values', () {
    test('round trip, and anything unknown is Índigo', () {
      for (final accent in AppAccent.values) {
        expect(AppAccent.fromStored(accent.stored), accent);
      }
      expect(AppAccent.fromStored(null), AppAccent.indigo);
      expect(AppAccent.fromStored('purple'), AppAccent.indigo);
      expect(AppAccent.fromStored(3), AppAccent.indigo);
    });
  });
}
