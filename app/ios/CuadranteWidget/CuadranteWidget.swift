import Foundation
import OSLog
import SwiftUI
import WidgetKit

/// Kind of the widget; Dart reloads it by this name (`kWidgetIosKind`).
/// One kind with the six families (contract §1).
let cuadranteWidgetKind = "CuadranteWidget"

/// The extension's own texts (Localizable.strings): only the gallery and the
/// notice shown when there is no valid snapshot. Everything else comes
/// localized in the JSON.
func widgetString(_ key: String) -> String {
  Bundle.main.localizedString(forKey: key, value: key, table: "Localizable")
}

struct CuadranteEntry: TimelineEntry {
  let date: Date
  /// A small precomputed slice for the family of the timeline (`EntryContent`).
  let content: EntryContent
}

/// One entry per day at 00:00 for the days left of the 60, in a window per
/// family (`maxEntries`: WidgetKit rejects a timeline whose archive passes
/// ~10 MiB). When the window does not reach the last day the policy is
/// `.after` a reload two days before the window ends: the provider then builds
/// the next window from the snapshot it already has, with no app launch. When
/// it does reach it, a final stale entry at the midnight after the last day and
/// policy `.after` that entry (contract §6). The widget therefore changes day
/// on its own, without the app; the app reloads the timeline whenever it
/// publishes.
struct CuadranteProvider: TimelineProvider {
  /// Entries per timeline for [family]: the archive of the whole timeline is
  /// what WidgetKit limits. Each entry is a slim model (see `EntryContent`);
  /// the large grid is the heaviest. Small and lock-screen families carry the
  /// whole timeline.
  static func maxEntries(_ family: WidgetFamily) -> Int {
    switch family {
    case .systemMedium: return 31
    case .systemLarge: return 8
    default: return Int.max
    }
  }

  /// Entries before the end of a truncated window at which the system is asked
  /// to reload, so a late reload still shows the right day.
  static let reloadMargin = 2

  func placeholder(in context: Context) -> CuadranteEntry {
    CuadranteEntry(
      date: Date(),
      content: SampleData.content(family: context.family, size: context.displaySize))
  }

  func getSnapshot(in context: Context, completion: @escaping (CuadranteEntry) -> Void) {
    let now = Date()
    let current = Self.timeline(
      snapshot: WidgetSnapshot.stored(), now: now, size: context.displaySize,
      family: context.family
    ).entries.first
    // The gallery shows the real day when there is one, else a sample.
    if context.isPreview, let current, !current.content.isStale {
      completion(current)
    } else if context.isPreview {
      completion(
        CuadranteEntry(
          date: now,
          content: SampleData.content(family: context.family, size: context.displaySize)))
    } else {
      completion(current ?? CuadranteEntry(date: now, content: Self.localStale))
    }
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<CuadranteEntry>) -> Void) {
    let timeline = Self.timeline(
      snapshot: WidgetSnapshot.stored(), now: Date(), size: context.displaySize,
      family: context.family)
    #if DEBUG
      WidgetDebugLog.timeline(timeline, family: context.family)
    #endif
    completion(timeline)
  }

  /// No (valid) snapshot yet: the extension's own notice.
  static var localStale: EntryContent {
    .stale(title: widgetString("widget_empty_title"), body: widgetString("widget_empty_body"))
  }

  static func timeline(
    snapshot: WidgetSnapshot?, now: Date, size: CGSize = .zero, family: WidgetFamily = .systemSmall
  ) -> Timeline<CuadranteEntry> {
    let retry = now.addingTimeInterval(3600)
    guard let snapshot else {
      return Timeline(
        entries: [CuadranteEntry(date: now, content: localStale)], policy: .after(retry))
    }
    let stale = EntryContent.stale(title: snapshot.staleTitle, body: snapshot.staleBody)
    let cal = CivilDate.calendar(for: snapshot)
    let today = CivilDate.iso(now, cal)
    // Before firstDate or after lastDate (clock moved, old JSON): the notice.
    guard let i = snapshot.days.firstIndex(where: { $0.date == today }) else {
      return Timeline(entries: [CuadranteEntry(date: now, content: stale)], policy: .after(retry))
    }
    let builder = EntryBuilder(snapshot: snapshot, family: family, size: size)
    let limit = maxEntries(family)
    var entries = [CuadranteEntry(date: now, content: builder.content(at: i))]
    var last = now
    var k = i + 1
    while k < snapshot.days.count, entries.count < limit {
      guard let start = CivilDate.startOfDay(snapshot.days[k].date, cal), start > last else { break }
      entries.append(CuadranteEntry(date: start, content: builder.content(at: k)))
      last = start
      k += 1
    }
    // The window stops short of the last day: no stale entry, just a reload
    // before it ends. The next window starts from today in that provider call.
    if k < snapshot.days.count, entries.count >= limit {
      let reload = entries[max(0, entries.count - 1 - reloadMargin)].date
      return Timeline(entries: entries, policy: .after(max(reload, now.addingTimeInterval(60))))
    }
    // The midnight after the last day carried by the entries.
    let lastISO = snapshot.days[i + entries.count - 1].date
    let end = CivilDate.startOfDay(lastISO, cal, addingDays: 1) ?? retry
    entries.append(CuadranteEntry(date: max(end, last.addingTimeInterval(1)), content: stale))
    return Timeline(entries: entries, policy: .after(entries.last!.date))
  }
}

extension EntryContent {
  var isStale: Bool {
    if case .stale = self { return true }
    return false
  }
}

// MARK: - Building the slim models

/// Turns `days[index]` of the decoded snapshot into the slim model its family
/// draws. It holds the whole snapshot and the date sets, but only for the
/// length of one provider call: none of that reaches an entry.
struct EntryBuilder {
  let snapshot: WidgetSnapshot
  let family: WidgetFamily
  /// Size of the widget, or the smallest iPhone size of the family when unknown.
  let size: CGSize
  /// Dates with an absence. Their cells are `privacySensitive`, so StandBy and
  /// other locked-device surfaces redact them (question 15).
  let absenceDates: Set<String>
  /// Dates whose shifts the snapshot spells out (`days` + `displayDays`).
  let knownDates: Set<String>

  init(snapshot: WidgetSnapshot, family: WidgetFamily, size: CGSize) {
    self.snapshot = snapshot
    self.family = family
    self.size = WidgetLayout.size(size, family)
    var absences = Set(
      snapshot.days.filter { $0.shifts.contains { $0.isAbsence } }.map(\.date))
    for aux in snapshot.displayDays ?? [] where aux.shifts.contains(where: { $0.isAbsence }) {
      absences.insert(aux.date)
    }
    absenceDates = absences
    knownDates = Set(snapshot.days.map(\.date)).union((snapshot.displayDays ?? []).map(\.date))
  }

  /// Fail closed: a cell is sensitive if it is an absence, or if it shows
  /// shifts (or adjustments) for a date the snapshot cannot classify.
  func isSensitive(_ date: String, hasBands: Bool) -> Bool {
    absenceDates.contains(date) || (hasBands && !knownDates.contains(date))
  }

  func content(at index: Int) -> EntryContent {
    switch family {
    case .systemMedium: return .medium(medium(at: index))
    case .systemLarge: return .large(large(at: index))
    case .accessoryInline, .accessoryCircular, .accessoryRectangular:
      return .lock(lock(at: index))
    default: return .small(small(at: index))
    }
  }

  // MARK: Pieces

  private func extras(_ date: String) -> [String] { snapshot.dayExtras?[date] ?? [] }

  private func paint(_ s: WidgetShift) -> BandPaint {
    BandPaint(
      code: s.code,
      light: ShiftPaint(bar: s.barLight, tint: s.tintLight, ink: s.inkLight),
      dark: ShiftPaint(bar: s.barDark, tint: s.tintDark, ink: s.inkDark))
  }

  private func paint(_ b: WidgetBand, dim: Bool = false) -> BandPaint {
    let s = snapshot.styles[b.style]
    return dim
      ? BandPaint(
        code: b.code,
        light: ShiftPaint(bar: s.dimBarLight, tint: s.dimTintLight, ink: s.dimInkLight),
        dark: ShiftPaint(bar: s.dimBarDark, tint: s.dimTintDark, ink: s.dimInkDark))
      : BandPaint(
        code: b.code,
        light: ShiftPaint(bar: s.barLight, tint: s.tintLight, ink: s.inkLight),
        dark: ShiftPaint(bar: s.barDark, tint: s.tintDark, ink: s.inkDark))
  }

  /// «hoy», prefixed to the day shown as today.
  private func prefixedToday(_ text: String) -> String {
    guard let word = snapshot.descriptions?.today, !word.isEmpty else { return text }
    return "\(word). \(text)"
  }

  /// Full VoiceOver sentence of [date] (adjustments included); today's gets
  /// the «hoy» prefix.
  private func description(_ date: String, isToday: Bool) -> String? {
    guard let text = snapshot.descriptions?.days?[date] else { return nil }
    return isToday ? prefixedToday(text) : text
  }

  // MARK: Small

  private func small(at index: Int) -> SmallModel {
    let day = snapshot.days[index]
    let small = day.small
    let extras = extras(day.date)
    // The snapshot's sentence already includes the adjustments; only without
    // it are they spelled out here (never twice).
    let spoken =
      description(day.date, isToday: true).map { "\($0). \(small.tomorrow)" }
      ?? (extras.isEmpty
        ? nil
        : [day.dateLabel, small.big, small.detail, extras.joined(separator: ". "), small.tomorrow]
          .compactMap { $0 }.joined(separator: ". "))
    let plan = smallPlan(day: day, extras: extras)
    return SmallModel(
      date: day.date, dateLabel: day.dateLabel, isHoliday: day.isHoliday, hasNote: day.hasNote,
      big: small.big, isEmpty: small.isEmpty, detail: small.detail, tomorrow: small.tomorrow,
      shifts: day.shifts.map(paint), extra: plan.extra, showTomorrow: plan.showTomorrow,
      compact: plan.compact,
      // Today or tomorrow an absence: redacted on a locked device (StandBy).
      sensitive: absenceDates.contains(day.date)
        || absenceDates.contains(day.medium.cells.dropFirst().first?.date ?? ""),
      spoken: spoken)
  }

  private static let smallExtrasSize: CGFloat = 11

  /// What the small day looks like, from fixed arithmetic: the first of these
  /// that fits the height (the last one when none does). With adjustments, the
  /// line of tomorrow goes first, then the code and time compact, and at the
  /// end whole lines of adjustments are dropped.
  private func smallPlan(day: WidgetDay, extras: [String])
    -> (extra: [String], showTomorrow: Bool, compact: Bool)
  {
    if extras.isEmpty { return ([], true, false) }
    let width = size.width - 2 * WidgetMetrics.l
    func wrap(_ n: Int) -> [String] {
      ExtrasWrap.lines(extras, width: width, maxLines: n, size: Self.smallExtrasSize)
    }
    let candidates: [(extra: [String], showTomorrow: Bool, compact: Bool)] = [
      (wrap(3), true, false), (wrap(3), false, false), (wrap(3), false, true),
      (wrap(2), false, true), (wrap(1), false, true),
    ]
    return candidates.first {
      smallHeight(day, $0.extra.count, $0.showTomorrow, $0.compact) <= size.height
    } ?? candidates[candidates.count - 1]
  }

  /// Height of the small layout, from the line heights of its fonts.
  private func smallHeight(
    _ day: WidgetDay, _ extraLines: Int, _ showTomorrow: Bool, _ compact: Bool
  ) -> CGFloat {
    let small = day.small
    let bigSize: CGFloat = small.isEmpty ? 21 : (compact ? 26 : 36)
    let detailSize: CGFloat = compact ? 15 : 19
    var h = 2 * (compact ? WidgetMetrics.xs * 2 : WidgetMetrics.m)
    h += WidgetLayout.line(13, .bold)
    h += WidgetLayout.line(bigSize, .heavy) + WidgetMetrics.hair
    if small.detail != nil { h += WidgetLayout.line(detailSize) }
    if extraLines > 0 {
      h += CGFloat(extraLines) * WidgetLayout.line(Self.smallExtrasSize) + WidgetMetrics.hair
    }
    h += WidgetMetrics.hair
    if showTomorrow { h += WidgetLayout.line(12, .bold) }
    if !day.shifts.isEmpty { h += 8 + WidgetMetrics.smallBar }
    return h
  }

  // MARK: Medium

  private func medium(at index: Int) -> MediumModel {
    let day = snapshot.days[index]
    let cells = day.medium.cells
    // v3 «7 días: …» of the first visible date; nil in v1/v2 (never computed
    // or translated here).
    let total = snapshot.stripTotals?[cells.first?.date ?? day.date]?.label
    // Size of a cell, from the widget size: width over seven columns, height
    // under the weekday (and the total, when there is one).
    let cellSize = CGSize(
      width: (size.width - 2 * WidgetMetrics.m - 6 * WidgetMetrics.xs) / 7,
      height: size.height - 2 * WidgetMetrics.m - WidgetLayout.line(12) - WidgetMetrics.xs
        - (total == nil ? 0 : WidgetLayout.line(12) + WidgetMetrics.xs))
    let models = cells.map { cell -> StripCellModel in
      let extras = extras(cell.date)
      let bands = cell.bands.map { paint($0) }
      let fallback: String? =
        extras.isEmpty
        ? nil
        : ([cell.weekdayShort, String(cell.dayOfMonth)] + cell.bands.map(\.code) + extras)
          .joined(separator: ". ")
      return StripCellModel(
        date: cell.date, weekdayShort: cell.weekdayShort, dayOfMonth: cell.dayOfMonth,
        isToday: cell.isToday, isHoliday: cell.isHoliday, hasNote: cell.hasNote, bands: bands,
        extra: DayCellView.extraLines(
          extras, cell: cellSize, shown: min(bands.count, 2), codeSize: 20, maxLines: 3),
        // Fail closed: adjustments of an unclassified date are redacted too.
        sensitive: isSensitive(cell.date, hasBands: !bands.isEmpty || !extras.isEmpty),
        spoken: description(cell.date, isToday: cell.isToday) ?? fallback)
    }
    return MediumModel(
      date: day.date, total: total,
      // The total is a sum over the strip: redacted with the strip when any of
      // its days is sensitive (or cannot be classified).
      totalSensitive: models.contains { $0.sensitive },
      cells: models)
  }

  // MARK: Large

  private func large(at index: Int) -> LargeModel {
    let day = snapshot.days[index]
    let month = snapshot.months[day.large.month]
    let todayCell = day.large.todayCell
    let cells = month.cells.enumerated().map { i, cell -> GridCellModel in
      let extras = extras(cell.date)
      let bands = cell.bands.map { paint($0, dim: !cell.inMonth) }
      let isToday = i == todayCell
      let fallback: String? =
        extras.isEmpty
        ? nil
        : ([String(cell.dayOfMonth)] + cell.bands.map(\.code) + extras).joined(separator: ". ")
      return GridCellModel(
        date: cell.date, dayOfMonth: cell.dayOfMonth, isToday: isToday, inMonth: cell.inMonth,
        isHoliday: cell.isHoliday, hasNote: cell.hasNote, bands: bands,
        // No adjustment text is drawn in the grid (its cells never have the
        // height for it on an iPhone); the spoken label has it. Fail closed:
        // adjustments of an unclassified date are redacted too.
        sensitive: isSensitive(cell.date, hasBands: !bands.isEmpty || !extras.isEmpty),
        spoken: description(cell.date, isToday: isToday) ?? fallback)
    }
    return LargeModel(
      date: day.date, monthKey: month.key, title: month.title,
      weekdayHeaders: snapshot.weekdayHeaders, cells: cells)
  }

  // MARK: Lock screen

  /// Shifts of the day after `days[index]`, from `days` or, past the last
  /// day, from `displayDays` (which run to `lastDate + 27`). nil if unknown.
  private func tomorrowShifts(after index: Int) -> [WidgetShift]? {
    let days = snapshot.days
    if index + 1 < days.count { return days[index + 1].shifts }
    guard let aux = snapshot.displayDays,
      let i = aux.firstIndex(where: { $0.date == days[index].date }), i + 1 < aux.count
    else { return nil }
    return aux[i + 1].shifts
  }

  private func lock(at index: Int) -> LockModel {
    let day = snapshot.days[index]
    let absence = day.shifts.contains { $0.isAbsence }
    let tomorrow = tomorrowShifts(after: index)
    // Unknown tomorrow (a v1 snapshot on its last day): hide the line rather
    // than risk naming an absence.
    let tomorrowHidden = tomorrow == nil || tomorrow!.contains { $0.isAbsence }
    let line2 = tomorrowHidden ? nil : day.lock.rectangular[1]

    guard absence else {
      let spoken = [description(day.date, isToday: true), line2].compactMap { $0 }
      return LockModel(
        date: day.date, inline: day.lock.inline, circular: day.lock.circular,
        line1: day.lock.rectangular[0], line2: line2,
        spoken: spoken.isEmpty ? nil : spoken.joined(separator: ". "))
    }
    // The neutral word comes from the JSON: the anonymized auxiliary day of
    // v2. A v1 snapshot has none: then a dash, never the shift's name.
    let neutral =
      snapshot.displayDays?.first(where: { $0.date == day.date })?.shifts
      .first(where: { $0.isAbsence })?.code ?? "–"
    var spoken: [String] = []
    if let text = snapshot.descriptions?.absences?[day.date] {
      spoken.append(prefixedToday(text))
    } else {
      spoken.append(neutral)
    }
    if let line2 { spoken.append(line2) }
    return LockModel(
      date: day.date, inline: neutral, circular: neutral, line1: neutral, line2: line2,
      spoken: spoken.joined(separator: ". "))
  }
}

#if DEBUG
  /// DEBUG builds only (never in a release): prints how big the timeline's
  /// entries are when encoded, so QA can compare entry sizes between builds
  /// and datasets (`log stream --predicate 'subsystem == "es.cuadrante.app"'`).
  /// This is the size of the models, not WidgetKit's own archive of the views.
  enum WidgetDebugLog {
    static func timeline(_ timeline: Timeline<CuadranteEntry>, family: WidgetFamily) {
      let encoder = PropertyListEncoder()
      encoder.outputFormat = .binary
      let sizes = timeline.entries.map { (try? encoder.encode($0.content).count) ?? -1 }
      let total = sizes.reduce(0, +)
      let snapshot = WidgetSnapshot.stored()
      let log = Logger(subsystem: "es.cuadrante.app", category: "widget")
      log.info(
        "timeline family=\(String(describing: family), privacy: .public) entries=\(sizes.count, privacy: .public) modelBytes=\(total, privacy: .public) perEntry=\(sizes.first ?? 0, privacy: .public) snapshotGeneratedAt=\(snapshot?.generatedAt ?? "none", privacy: .public)"
      )
    }
  }
#endif

@main
struct CuadranteWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: cuadranteWidgetKind, provider: CuadranteProvider()) { entry in
      CuadranteEntryView(entry: entry)
    }
    .configurationDisplayName(Text(verbatim: widgetString("widget_name")))
    .description(Text(verbatim: widgetString("widget_description")))
    .supportedFamilies([
      .systemSmall, .systemMedium, .systemLarge,
      .accessoryInline, .accessoryCircular, .accessoryRectangular,
    ])
    .contentMarginsDisabled()
    // Shifts (and absences) stay on the phone: no iPhone widget on a paired
    // Mac's desktop (§4.1 step 8, as in Mochila).
    .disfavoredLocations([.iPhoneWidgetsOnMac], for: [.systemSmall, .systemMedium, .systemLarge])
  }
}
