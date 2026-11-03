import 'package:flutter/painting.dart' show Color;

/// The accent the user picks in Ajustes › Apariencia › Color de acento
/// (option 8.3 of the 31-oct design canvas, `docs/diseno.md`, "Acento
/// elegible").
///
/// The accent only paints links, switches, checkboxes, selection, tabs and
/// the like: never the colours of the shifts (`shift_palette.dart`) nor the
/// amber of the countdown and of «Pintar» (`AppColors.highlight`). Every
/// value reaches 4.5:1 on `background`, `surface` and `surfaceRaised` in its
/// theme, its `onAccent` reaches 4.5:1 on it, and `textPrimary` reaches
/// 4.5:1 on its soft fill (`test/core/theme/accent_contrast_test.dart`).
enum AppAccent {
  /// The accent the app always had: the default.
  indigo(
    'indigo',
    light: Color(0xFF4B4FD1),
    lightSoft: Color(0xFFE3E4FA),
    dark: Color(0xFFA5A8FF),
    darkSoft: Color(0xFF23245A),
  ),
  blue(
    'blue',
    light: Color(0xFF1A63C2),
    lightSoft: Color(0xFFDFE9F7),
    dark: Color(0xFF8DBBFF),
    darkSoft: Color(0xFF2D3649),
  ),
  petrol(
    'petrol',
    light: Color(0xFF0D7270),
    lightSoft: Color(0xFFDDEBEB),
    dark: Color(0xFF5ED3CF),
    darkSoft: Color(0xFF243B3F),
  ),
  raspberry(
    'raspberry',
    light: Color(0xFFB4235A),
    lightSoft: Color(0xFFF5E0E8),
    dark: Color(0xFFFF8FB8),
    darkSoft: Color(0xFF442D3A),
  ),
  graphite(
    'graphite',
    light: Color(0xFF3A3A44),
    lightSoft: Color(0xFFE2E2E5),
    dark: Color(0xFFC9C9D2),
    darkSoft: Color(0xFF393940),
  );

  const AppAccent(
    this.stored, {
    required this.light,
    required this.lightSoft,
    required this.dark,
    required this.darkSoft,
  });

  /// The stored value (`"indigo"`, `"blue"`...).
  final String stored;

  /// `accent` / `accentText` of the light theme and its soft fill.
  final Color light;
  final Color lightSoft;

  /// `accent` / `accentText` of the dark theme and its soft fill.
  final Color dark;
  final Color darkSoft;

  static const AppAccent defaultAccent = indigo;

  /// The accent of a stored value; anything unknown (or missing: an
  /// installation from before this setting) is [indigo].
  static AppAccent fromStored(Object? value) {
    for (final accent in values) {
      if (accent.stored == value) return accent;
    }
    return defaultAccent;
  }
}

/// How big the code and the time of a shift are drawn in the cells of the
/// month (Ajustes › Apariencia › Tamaño del turno en el mes, P8 of
/// `docs/paridad-pago.md`, row 10).
///
/// It scales the *starting* size of `cellCode`, `cellCodeMulti` and
/// `cellTime` (`AppTypography.from`); the cell still shrinks them down to
/// what fits (`cellCodeSize`, `cellTimeInCell`), so a bigger size never
/// overflows a narrow cell: it just reaches the cell's limit sooner.
enum CellTextSize {
  normal('normal', 1),
  large('large', 1.2),
  extraLarge('extraLarge', 1.4);

  const CellTextSize(this.stored, this.factor);

  /// The stored value (`"normal"`, `"large"`, `"extraLarge"`).
  final String stored;

  /// Multiplier of the cell styles.
  final double factor;

  /// The size of a stored value; anything unknown (or missing) is [normal].
  static CellTextSize fromStored(Object? value) {
    for (final size in values) {
      if (size.stored == value) return size;
    }
    return normal;
  }
}
