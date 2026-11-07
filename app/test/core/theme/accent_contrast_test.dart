import 'package:cuadrante/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// P8 · Apariencia (option 8.3 of the 31-oct canvas): ten accents (the first
/// five of 31-oct, the rest of proposal 8, 6-nov), Índigo by default. Every accent reaches AA in light and dark, and it only paints
/// links, switches, selection and tabs: never the shifts nor the amber.
void main() {
  const aa = 4.5;
  // Non-text contrast (WCAG 1.4.11): icons and the switch track.
  const nonText = 3.0;

  group('every accent passes AA', () {
    for (final accent in AppAccent.values) {
      for (final base in [
        AppColors.light,
        AppColors.dark,
        AppColors.dark.withPureBlack(),
      ]) {
        final mode = base.isDark
            ? (base.background == AppColors.pureBlack ? 'pure black' : 'dark')
            : 'light';
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

  group('the ten accents', () {
    test('the first five keep their order and their stored names', () {
      expect(AppAccent.values, hasLength(10));
      expect(AppAccent.values.take(5).map((a) => a.stored), [
        'indigo',
        'blue',
        'petrol',
        'raspberry',
        'graphite',
      ]);
      expect(AppAccent.values.skip(5).map((a) => a.stored), [
        'violet',
        'plum',
        'emerald',
        'olive',
        'terracotta',
      ]);
      expect(
        AppAccent.values.map((a) => a.stored).toSet(),
        hasLength(10),
        reason: 'two accents share a stored name',
      );
    });

    test('no two accents share a colour in either theme', () {
      expect(AppAccent.values.map((a) => a.light).toSet(), hasLength(10));
      expect(AppAccent.values.map((a) => a.dark).toSet(), hasLength(10));
    });

    test('the amber of the app is not an accent', () {
      for (final accent in AppAccent.values) {
        expect(accent.light, isNot(AppColors.light.highlight));
        expect(accent.dark, isNot(AppColors.dark.highlight));
      }
    });
  });

  group('pure black background (OLED)', () {
    test('only the background of the dark theme changes', () {
      final black = AppColors.dark.withPureBlack();
      expect(black.background, const Color(0xFF000000));
      final dark = AppColors.dark;
      expect(black.surface, dark.surface);
      expect(black.surfaceMuted, dark.surfaceMuted);
      expect(black.surfaceRaised, dark.surfaceRaised);
      expect(black.border, dark.border);
      expect(black.textPrimary, dark.textPrimary);
      expect(black.textMuted, dark.textMuted);
      expect(black.accent, dark.accent);
      expect(black.highlight, dark.highlight);
      expect(black.isDark, isTrue);
    });

    test('the light theme ignores it', () {
      expect(
        identical(AppColors.light.withPureBlack(), AppColors.light),
        isTrue,
      );
    });

    test('every text token reads on pure black', () {
      final c = AppColors.dark.withPureBlack();
      for (final (name, color) in [
        ('textPrimary', c.textPrimary),
        ('textSecondary', c.textSecondary),
        ('textMuted', c.textMuted),
        ('highlight', c.highlight),
        ('holiday', c.holiday),
      ]) {
        expect(
          contrastRatio(color, c.background),
          greaterThanOrEqualTo(aa),
          reason: name,
        );
      }
    });

    test('the dark theme paints it, and the default stays as it was', () {
      expect(
        AppTheme.dark(pureBlack: true).scaffoldBackgroundColor,
        const Color(0xFF000000),
      );
      expect(
        AppTheme.dark().scaffoldBackgroundColor,
        AppColors.dark.background,
      );
      expect(
        AppTheme.light().scaffoldBackgroundColor,
        AppColors.light.background,
      );
      expect(
        identical(
          AppTheme.dark(pureBlack: true),
          AppTheme.dark(pureBlack: true),
        ),
        isTrue,
      );
      expect(
        identical(AppTheme.dark(pureBlack: true), AppTheme.dark()),
        isFalse,
      );
    });

    test('the shift colours do not depend on it', () {
      // The swatches come from the brightness only: a night shift reads the
      // same on black as on the usual dark background.
      for (final color in ShiftPalette.editorChoices) {
        final swatch = ShiftSwatch.forColor(color.toARGB32(), Brightness.dark);
        expect(
          contrastRatio(swatch.ink, swatch.tint),
          greaterThanOrEqualTo(kTextContrast),
        );
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
