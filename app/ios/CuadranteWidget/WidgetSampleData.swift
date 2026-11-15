import Foundation
import WidgetKit

/// A sample day for the widget gallery and the placeholder, used only while
/// the app has never published a snapshot (with one, the gallery shows the
/// real day). Rotation M, M, T, T, N, N, free, free; the colours are the exact
/// `ShiftSwatch` values of the Android previews (`widget_colors.xml`). The
/// month title and weekday headers come from the phone's locale: sample only,
/// never shown for real data.
enum SampleData {
  /// M (0), T (1), N (2): light and dark colours (bar, tint, ink) and the dim
  /// variants for the neighbouring months of the grid.
  private static let paints: [(light: ShiftPaint, dark: ShiftPaint)] = [
    (ShiftPaint(bar: 0xFFF5_A524, tint: 0xFFFE_F6E9, ink: 0xFF98_6007),
     ShiftPaint(bar: 0xFFF5_A524, tint: 0xFF34_291C, ink: 0xFFF9_C777)),
    (ShiftPaint(bar: 0xFFF0_6A3F, tint: 0xFFFE_F0EC, ink: 0xFFBF_3A0F),
     ShiftPaint(bar: 0xFFF0_6A3F, tint: 0xFF34_2120, ink: 0xFFF7_B099)),
    (ShiftPaint(bar: 0xFF4B_4FD1, tint: 0xFFED_EDFA, ink: 0xFF4B_4FD1),
     ShiftPaint(bar: 0xFF67_6BD8, tint: 0xFF1D_1D34, ink: 0xFFA8_AAE9)),
  ]
  private static let dimLight = ShiftPaint(bar: 0xFFC9_C9D2, tint: 0xFFEC_ECF1, ink: 0xFF5A_5A64)
  private static let dimDark = ShiftPaint(bar: 0xFF34_343E, tint: 0xFF0F_0F13, ink: 0xFF8E_8E99)
  private static let codes = ["M", "T", "N"]
  private static let times = ["06:00–14:00", "14:00–22:00", "22:00–06:00"]
  private static let compact = ["06–14", "14–22", "22–06"]
  /// Style index of each day of the 8-day rotation; nil = no shift.
  private static let rotation: [Int?] = [0, 0, 1, 1, 2, 2, nil, nil]

  static func content(family: WidgetFamily, size: CGSize = .zero, now: Date = Date())
    -> EntryContent
  {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = .current
    cal.locale = .current
    let today = cal.startOfDay(for: now)
    func date(_ offset: Int, from base: Date = today) -> Date {
      cal.date(byAdding: .day, value: offset, to: base) ?? base
    }
    func slot(_ d: Date) -> Int? {
      let n = cal.dateComponents([.day], from: today, to: cal.startOfDay(for: d)).day ?? 0
      return rotation[((n % 8) + 8) % 8]
    }
    func bands(_ d: Date, dim: Bool = false) -> [BandPaint] {
      slot(d).map {
        [BandPaint(
          code: codes[$0], light: dim ? dimLight : paints[$0].light,
          dark: dim ? dimDark : paints[$0].dark)]
      } ?? []
    }
    let iso = { (d: Date) in CivilDate.iso(d, cal) }
    let dayNumber = { (d: Date) in cal.component(.day, from: d) }
    let weekdays = cal.shortStandaloneWeekdaySymbols
    let weekdayShort = { (d: Date) in weekdays[cal.component(.weekday, from: d) - 1] }
    // v3 preview: overtime and early leave today and tomorrow, and the
    // seven-day total.
    let extras: [String: [String]] = [
      iso(today): [widgetString("widget_sample_overtime")],
      iso(date(1)): [
        widgetString("widget_sample_overtime"), widgetString("widget_sample_early_leave"),
      ],
    ]
    let tomorrow = "\(widgetString("widget_sample_tomorrow")): \(codes[0]) \(compact[0])"

    switch family {
    case .systemMedium:
      let box = WidgetLayout.size(size, family)
      let total = widgetString("widget_sample_seven_days")
      let cellSize = CGSize(
        width: (box.width - 2 * WidgetMetrics.m - 6 * WidgetMetrics.xs) / 7,
        height: box.height - 2 * WidgetMetrics.m - WidgetLayout.line(12) - WidgetMetrics.xs
          - WidgetLayout.line(12) - WidgetMetrics.xs)
      let cells = (0..<widgetStripDays).map { i -> StripCellModel in
        let d = date(i)
        let b = bands(d)
        return StripCellModel(
          date: iso(d), weekdayShort: weekdayShort(d), dayOfMonth: dayNumber(d), isToday: i == 0,
          isHoliday: false, hasNote: false, bands: b,
          extra: DayCellView.extraLines(
            extras[iso(d)] ?? [], cell: cellSize, shown: min(b.count, 2), codeSize: 20,
            maxLines: 3),
          sensitive: false, spoken: nil)
      }
      return .medium(
        MediumModel(date: iso(today), total: total, totalSensitive: false, cells: cells))
    case .systemLarge:
      // Month grid: six weeks from the Monday on or before the 1st.
      let first = cal.date(from: cal.dateComponents([.year, .month], from: today)) ?? today
      let back = (cal.component(.weekday, from: first) + 5) % 7
      let gridStart = date(-back, from: first)
      let month = cal.component(.month, from: today)
      let todayCell = cal.dateComponents([.day], from: gridStart, to: today).day ?? 0
      let cells = (0..<widgetMonthCells).map { i -> GridCellModel in
        let d = date(i, from: gridStart)
        let inMonth = cal.component(.month, from: d) == month
        return GridCellModel(
          date: iso(d), dayOfMonth: dayNumber(d), isToday: i == todayCell, inMonth: inMonth,
          isHoliday: false, hasNote: false, bands: bands(d, dim: !inMonth), sensitive: false,
          spoken: nil)
      }
      let formatter = DateFormatter()
      formatter.locale = .current
      formatter.setLocalizedDateFormatFromTemplate("LLLLyyyy")
      let symbols = cal.veryShortStandaloneWeekdaySymbols
      return .large(
        LargeModel(
          date: iso(today), monthKey: String(iso(today).prefix(7)),
          title: formatter.string(from: today),
          weekdayHeaders: Array(symbols[1...] + symbols[..<1]), cells: cells))
    case .accessoryInline, .accessoryCircular, .accessoryRectangular:
      return .lock(
        LockModel(
          date: iso(today), inline: "\(codes[0]) · 06:00", circular: codes[0],
          line1: "\(codes[0]) · \(times[0])", line2: tomorrow, spoken: nil))
    default:
      // Today is M (rotation slot 0) and so is tomorrow.
      return .small(
        SmallModel(
          date: iso(today), dateLabel: "\(weekdayShort(today)) \(dayNumber(today))",
          isHoliday: false, hasNote: false, big: codes[0], isEmpty: false, detail: times[0],
          tomorrow: tomorrow, shifts: bands(today), extra: extras[iso(today)] ?? [],
          showTomorrow: false, compact: true, sensitive: false, spoken: nil))
    }
  }
}
