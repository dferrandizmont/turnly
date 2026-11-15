import Foundation

// Snapshot written by the Flutter side (`lib/features/widget/domain/
// widget_snapshot.dart`) into the App Group UserDefaults: contract in
// docs/widget-contrato.md (v3; v2 and v1 still read). Golden rule: this extension
// does not compute shifts, format hours, translate or pick colours. It reads
// the JSON, picks the entry of the day and paints it.
//
// Decoding is strict for the base schema (every key is always present, like
// the Android `WidgetModelBuilder`): a missing key, a bad pointer or an
// unknown version gives the honest "open Turnly" notice, never half a day.
// The optional root extensions (`descriptions`, and the v3 `dayExtras` and
// `stripTotals`) are read leniently: a damaged one is simply absent, and v1/v2
// never carry the v3 pair. `nextOff` and `notes` are not used by the six iOS
// families and are ignored.

/// App Group shared with Runner (`kWidgetAppGroupId`).
let widgetAppGroupId = "group.es.cuadrante.app"
/// Key of the snapshot in that suite (`kWidgetSnapshotKey`).
let widgetSnapshotKey = "cuadrante.widget.snapshot"
/// Versions this reader understands (`kWidgetSnapshotVersion` = 3; v1 and v2 still read).
let widgetSnapshotVersions: ClosedRange<Int> = 1...3

/// Cells of a month grid and of a medium strip (`kWidgetMonthCells`, `kWidgetStripDays`).
let widgetMonthCells = 42
let widgetStripDays = 7

// MARK: - Base schema

struct WidgetShift: Decodable {
  let code: String
  let name: String
  let timeLabel: String?
  let compactTime: String?
  /// `work`, `rest` or `absence`.
  let category: String
  let barLight: UInt32, tintLight: UInt32, inkLight: UInt32, discLight: UInt32
  let barDark: UInt32, tintDark: UInt32, inkDark: UInt32, discDark: UInt32

  var isAbsence: Bool { category == "absence" }
}

struct WidgetStyle: Decodable {
  let barLight: UInt32, tintLight: UInt32, inkLight: UInt32, discLight: UInt32
  let barDark: UInt32, tintDark: UInt32, inkDark: UInt32, discDark: UInt32
  let dimBarLight: UInt32, dimTintLight: UInt32, dimInkLight: UInt32, dimDiscLight: UInt32
  let dimBarDark: UInt32, dimTintDark: UInt32, dimInkDark: UInt32, dimDiscDark: UInt32
}

struct WidgetBand: Decodable {
  let code: String
  /// Index in `WidgetSnapshot.styles`.
  let style: Int
}

struct WidgetSmall: Decodable {
  let big: String
  let isEmpty: Bool
  let detail: String?
  let tomorrow: String
}

struct WidgetStripCell: Decodable {
  let date: String
  let weekdayShort: String
  let dayOfMonth: Int
  let isToday: Bool
  let isHoliday: Bool
  let hasNote: Bool
  let bands: [WidgetBand]
}

struct WidgetMedium: Decodable {
  let cells: [WidgetStripCell]
}

struct WidgetLarge: Decodable {
  /// Index in `WidgetSnapshot.months`.
  let month: Int
  /// 0...41 in that month's grid.
  let todayCell: Int
}

struct WidgetLock: Decodable {
  let inline: String
  let circular: String
  /// Exactly two lines.
  let rectangular: [String]
}

struct WidgetDay: Decodable {
  let date: String
  let weekday: Int
  let weekdayShort: String
  let dayOfMonth: Int
  let dateLabel: String
  let isHoliday: Bool
  let holidayName: String?
  let hasNote: Bool
  let shifts: [WidgetShift]
  let small: WidgetSmall
  let medium: WidgetMedium
  let large: WidgetLarge
  let lock: WidgetLock
}

struct WidgetMonthCell: Decodable {
  let date: String
  let dayOfMonth: Int
  let inMonth: Bool
  let isHoliday: Bool
  let hasNote: Bool
  let bands: [WidgetBand]
}

struct WidgetMonth: Decodable {
  /// `yyyy-MM`.
  let key: String
  let title: String
  let cells: [WidgetMonthCell]
}

/// v2 auxiliary day. Every absence is already anonymized here by Dart
/// (`code` and `name` are the localized «Ausencia», no hours, neutral colours):
/// the lock screen takes its neutral text from these days.
struct WidgetDisplayDay: Decodable {
  let date: String
  let shifts: [WidgetShift]
}

/// Optional extension `descriptions`: VoiceOver sentences, already localized.
struct WidgetDescriptions: Decodable {
  /// «hoy»: prefixed, with a full stop, only to the day shown as today.
  let today: String?
  let days: [String: String]?
  /// Anonymized sentences for dates with absences.
  let absences: [String: String]?
}

/// v3: hours counting for this job over the seven days that start on a date
/// (`label` is the localized «7 días: …»; `minutes` is informational).
struct WidgetStripTotal: Decodable {
  let minutes: Int
  let label: String
}

struct WidgetSnapshot: Decodable {
  let v: Int
  /// Informational (DEBUG logs); never used to pick a day.
  let generatedAt: String?
  let timeZone: String
  let locale: String
  let firstDate: String
  let lastDate: String
  let staleTitle: String
  let staleBody: String
  let weekdayHeaders: [String]
  let styles: [WidgetStyle]
  let months: [WidgetMonth]
  let days: [WidgetDay]
  /// v2 only.
  let noShift: String?
  let displayDays: [WidgetDisplayDay]?
  let descriptions: WidgetDescriptions?
  /// v3 only: localized extra-hour / early-leave labels by date, kept apart
  /// from the base times. No entry = no adjustments.
  let dayExtras: [String: [String]]?
  /// v3 only: the seven-day total that starts on each date.
  let stripTotals: [String: WidgetStripTotal]?

  private enum CodingKeys: String, CodingKey {
    case v, generatedAt, timeZone, locale, firstDate, lastDate, staleTitle, staleBody, weekdayHeaders,
      styles, months, days, noShift, displayDays, descriptions, dayExtras, stripTotals
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    v = try c.decode(Int.self, forKey: .v)
    generatedAt = try? c.decodeIfPresent(String.self, forKey: .generatedAt)
    timeZone = try c.decode(String.self, forKey: .timeZone)
    locale = try c.decode(String.self, forKey: .locale)
    firstDate = try c.decode(String.self, forKey: .firstDate)
    lastDate = try c.decode(String.self, forKey: .lastDate)
    staleTitle = try c.decode(String.self, forKey: .staleTitle)
    staleBody = try c.decode(String.self, forKey: .staleBody)
    weekdayHeaders = try c.decode([String].self, forKey: .weekdayHeaders)
    styles = try c.decode([WidgetStyle].self, forKey: .styles)
    months = try c.decode([WidgetMonth].self, forKey: .months)
    days = try c.decode([WidgetDay].self, forKey: .days)
    if v >= 2 {
      noShift = try c.decode(String.self, forKey: .noShift)
      displayDays = try c.decode([WidgetDisplayDay].self, forKey: .displayDays)
    } else {
      noShift = nil
      displayDays = nil
    }
    // Optional extension: a damaged one is simply absent.
    descriptions = try? c.decodeIfPresent(WidgetDescriptions.self, forKey: .descriptions)
    // v3 pair: absent in v1/v2 (never read there), lenient like `descriptions`.
    if v >= 3 {
      dayExtras = try? c.decodeIfPresent([String: [String]].self, forKey: .dayExtras)
      stripTotals = try? c.decodeIfPresent([String: WidgetStripTotal].self, forKey: .stripTotals)
    } else {
      dayExtras = nil
      stripTotals = nil
    }
  }

  /// The stored snapshot, or nil when missing, undecodable, of an unknown
  /// version or internally inconsistent (contract §1: the widget then shows
  /// the notice; it never invents data).
  static func stored() -> WidgetSnapshot? {
    // A fresh handle and a sync on every call: nothing is cached between
    // reloads, so a snapshot the app has just published is the one read.
    let defaults = UserDefaults(suiteName: widgetAppGroupId)
    defaults?.synchronize()
    guard let json = defaults?.string(forKey: widgetSnapshotKey) else { return nil }
    return decode(json)
  }

  static func decode(_ json: String) -> WidgetSnapshot? {
    guard let data = json.data(using: .utf8),
      let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data),
      snapshot.isValid
    else { return nil }
    return snapshot
  }

  /// Pointers and fixed sizes the views rely on (so a view never indexes out
  /// of range).
  var isValid: Bool {
    guard widgetSnapshotVersions.contains(v), !days.isEmpty, weekdayHeaders.count == 7 else {
      return false
    }
    let styleCount = styles.count
    func bandsOK(_ bands: [WidgetBand]) -> Bool {
      bands.allSatisfy { $0.style >= 0 && $0.style < styleCount }
    }
    for month in months {
      guard month.cells.count == widgetMonthCells, month.cells.allSatisfy({ bandsOK($0.bands) })
      else { return false }
    }
    for day in days {
      guard day.medium.cells.count == widgetStripDays,
        day.medium.cells.allSatisfy({ bandsOK($0.bands) }),
        day.large.month >= 0, day.large.month < months.count,
        day.large.todayCell >= 0, day.large.todayCell < widgetMonthCells,
        day.lock.rectangular.count == 2
      else { return false }
    }
    return true
  }
}

// MARK: - What an entry carries

// WidgetKit archives the rendered views of EVERY entry of the timeline and
// refuses the whole timeline above ~10 MiB ("too large timeline archive").
// An entry therefore carries only the small, precomputed slice its family
// draws: primitives and short strings, never the decoded snapshot, its maps
// of all dates or the sets used to classify them. Those live in
// `EntryBuilder` (CuadranteWidget.swift) for the length of one provider call.
// All models are Codable only so DEBUG builds can log their size.

/// Colours of one shift or band in one theme (`0xAARRGGBB`, painted untouched).
struct ShiftPaint: Codable {
  let bar: UInt32, tint: UInt32, ink: UInt32
}

/// A shift or band: its code and its colours in both themes (the theme is only
/// known when the view draws).
struct BandPaint: Codable {
  let code: String
  let light: ShiftPaint
  let dark: ShiftPaint

  func paint(dark isDark: Bool) -> ShiftPaint { isDark ? dark : light }
}

struct SmallModel: Codable {
  let date: String
  let dateLabel: String
  let isHoliday: Bool
  let hasNote: Bool
  let big: String
  let isEmpty: Bool
  let detail: String?
  let tomorrow: String
  /// The day's shifts, in order.
  let shifts: [BandPaint]
  /// Adjustment lines already packed in whole words; layout already chosen
  /// from the widget size.
  let extra: [String]
  let showTomorrow: Bool
  let compact: Bool
  /// Today or tomorrow an absence: redacted on a locked device.
  let sensitive: Bool
  let spoken: String?
}

struct StripCellModel: Codable {
  let date: String
  let weekdayShort: String
  let dayOfMonth: Int
  let isToday: Bool
  let isHoliday: Bool
  let hasNote: Bool
  let bands: [BandPaint]
  /// Adjustment lines that fit this cell, already packed in whole words.
  let extra: [String]
  let sensitive: Bool
  let spoken: String?
}

struct MediumModel: Codable {
  let date: String
  /// v3 «7 días: …» as the snapshot spells it; nil for v1/v2.
  let total: String?
  let totalSensitive: Bool
  let cells: [StripCellModel]
}

struct GridCellModel: Codable {
  let date: String
  let dayOfMonth: Int
  let isToday: Bool
  let inMonth: Bool
  let isHoliday: Bool
  let hasNote: Bool
  /// Already the dim colours when the cell is of a neighbouring month.
  let bands: [BandPaint]
  let sensitive: Bool
  let spoken: String?
}

struct LargeModel: Codable {
  let date: String
  let monthKey: String
  let title: String
  let weekdayHeaders: [String]
  /// Exactly `widgetMonthCells`.
  let cells: [GridCellModel]
}

/// Lock-screen texts of one day, already made neutral for absences
/// (question 15, 25-oct-2026): on the lock screen EVERY absence is «Ausencia»,
/// with no name, code, icon, specific colour or accessibility label that
/// reveals the reason.
struct LockModel: Codable {
  let date: String
  let inline: String
  let circular: String
  let line1: String
  /// nil when tomorrow is (or may be) an absence: the line would name it.
  let line2: String?
  let spoken: String?
}

enum EntryContent: Codable {
  case small(SmallModel)
  case medium(MediumModel)
  case large(LargeModel)
  case lock(LockModel)
  /// `staleTitle` / `staleBody` of the JSON, or the extension's own texts
  /// when there is no valid JSON. Never a shift.
  case stale(title: String, body: String)
}

// MARK: - Civil dates

enum CivilDate {
  /// Calendar whose midnights open each day of the timeline.
  ///
  /// Contract §8, question 1: this uses the phone's CURRENT zone (alternative
  /// B, the same as the app and the Android widget), not the `timeZone` of the
  /// JSON. With the app closed, a zone change keeps the midnights of the old
  /// zone until iOS asks for a new timeline (the app republishes on open,
  /// resume and zone change). To switch to the contract's alternative A, build
  /// the calendar with `TimeZone(identifier: snapshot.timeZone) ?? .current`.
  /// The day-4 test of the 7-day protocol decides.
  static func calendar(for snapshot: WidgetSnapshot? = nil) -> Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = .current
    return cal
  }

  /// `yyyy-MM-dd` of [date] in [cal].
  static func iso(_ date: Date, _ cal: Calendar) -> String {
    let c = cal.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
  }

  /// First instant of the civil day [iso] in [cal]. Built from noon, which
  /// always exists, so days of 23 or 25 h and zones without a midnight on the
  /// change of time are covered (contract §6, rule 3).
  static func startOfDay(_ iso: String, _ cal: Calendar, addingDays: Int = 0) -> Date? {
    let parts = iso.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else { return nil }
    var comps = DateComponents()
    comps.year = parts[0]
    comps.month = parts[1]
    comps.day = parts[2]
    comps.hour = 12
    guard let noon = cal.date(from: comps),
      let shifted = cal.date(byAdding: .day, value: addingDays, to: noon)
    else { return nil }
    return cal.startOfDay(for: shifted)
  }
}

// MARK: - Links

/// Links of a tap. `home_widget` only hands to Dart the iOS URLs that carry
/// the `homeWidget` query item (`isWidgetUrl` in HomeWidgetPlugin.swift);
/// `widgetLinkTarget` (widget_links.dart) ignores it. They carry no data and
/// trigger no action.
enum WidgetLink {
  static func day(_ iso: String) -> URL {
    URL(string: "cuadrante://widget/day/\(iso)?homeWidget") ?? app
  }

  static func month(_ key: String) -> URL {
    URL(string: "cuadrante://widget/month/\(key)?homeWidget") ?? app
  }

  /// The stale notice: opens the app with no day.
  static let app = URL(string: "cuadrante://widget?homeWidget")!
}
