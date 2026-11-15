import SwiftUI

// Neutral tokens of design B "Noche" (docs/diseno.md), the same values as the
// Android widget (`res/values/widget_colors.xml` and `values-night`). The
// colours of the shifts are NOT here: they come resolved in the snapshot and
// are painted untouched (contract §3).

extension Color {
  /// `0xAARRGGBB` exactly as the snapshot carries it: no dimming, no
  /// lightening, no contrast recomputation.
  init(argb: UInt32) {
    self.init(
      .sRGB,
      red: Double((argb >> 16) & 0xFF) / 255,
      green: Double((argb >> 8) & 0xFF) / 255,
      blue: Double(argb & 0xFF) / 255,
      opacity: Double((argb >> 24) & 0xFF) / 255)
  }
}

struct WidgetPalette {
  let surface: Color
  let surfaceMuted: Color
  let textPrimary: Color
  let textSecondary: Color
  let textMuted: Color
  let border: Color
  let holiday: Color
  let todayRing: Color

  static let light = WidgetPalette(
    surface: Color(argb: 0xFFFF_FFFF),
    surfaceMuted: Color(argb: 0xFFEC_ECF1),
    textPrimary: Color(argb: 0xFF15_151A),
    textSecondary: Color(argb: 0xFF3A_3A44),
    textMuted: Color(argb: 0xFF5A_5A64),
    border: Color(argb: 0xFFDC_DCE2),
    holiday: Color(argb: 0xFFD9_3036),
    todayRing: Color(argb: 0xFF15_151A))

  static let dark = WidgetPalette(
    surface: Color(argb: 0xFF15_151B),
    surfaceMuted: Color(argb: 0xFF0F_0F13),
    textPrimary: Color(argb: 0xFFEC_ECF1),
    textSecondary: Color(argb: 0xFFC9_C9D2),
    textMuted: Color(argb: 0xFF8E_8E99),
    border: Color(argb: 0xFF23_232B),
    holiday: Color(argb: 0xFFFF_6369),
    todayRing: Color(argb: 0xFFF5_B547))

  static func of(_ scheme: ColorScheme) -> WidgetPalette { scheme == .dark ? .dark : .light }
}

/// The colours of a shift or band in the theme on screen.
struct ShiftColors {
  let bar: Color
  let tint: Color
  let ink: Color

  init(_ p: ShiftPaint) {
    bar = Color(argb: p.bar)
    tint = Color(argb: p.tint)
    ink = Color(argb: p.ink)
  }
}

extension BandPaint {
  func colors(dark: Bool) -> ShiftColors { ShiftColors(paint(dark: dark)) }
}

/// Sizes of docs/diseno.md (`Sp`, `Rad`, `AppTypography`), in points.
enum WidgetMetrics {
  static let hair: CGFloat = 2
  static let xs: CGFloat = 4
  static let m: CGFloat = 12
  static let l: CGFloat = 16
  /// Bar under a cell (`Sp.bar`) and under the small widget (`Sp.cardBar`).
  static let cellBar: CGFloat = 6
  static let smallBar: CGFloat = 5
  /// Today's ring (`Sp.ring`).
  static let ring: CGFloat = 2
  /// Cell radius in the medium strip (`Rad.inner`); the month grid uses the
  /// rounded-square rule (a quarter of the side, at most 14: `Rad.square`).
  static let stripRadius: CGFloat = 12
  static let gridRadius: CGFloat = 9
  /// Holiday dot (round: points of 8 or less stay round).
  static let holidayDot: CGFloat = 5
}
