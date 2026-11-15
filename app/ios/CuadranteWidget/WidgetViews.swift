import SwiftUI
import UIKit
import WidgetKit

// Views per family (contract §4), drawn like the app's own previews
// (`widget_previews.dart`, design 7A) and docs/diseno.md: the code on the tint
// of its shift, one bar per shift, today with a ring, holidays with the number
// in `holiday`. Never colour alone: the code is always painted, and the time
// where there is room. In the accented / vibrant modes of iOS 18
// (`widgetRenderingMode != .fullColor`) the system tints everything, so the
// cells keep the code and the shape (outline) and do not rely on the fill.
// Lock-screen families are monochrome text only (`lock.*`).

struct CuadranteEntryView: View {
  @Environment(\.widgetFamily) private var family
  let entry: CuadranteEntry

  var body: some View {
    switch entry.content {
    case .small(let model): SmallView(model: model)
    case .medium(let model): MediumView(model: model)
    case .large(let model): LargeView(model: model)
    case .lock(let model):
      switch family {
      case .accessoryInline: InlineLockView(model: model)
      case .accessoryCircular: CircularLockView(model: model)
      default: RectangularLockView(model: model)
      }
    case .stale(let title, let body):
      StaleView(title: title, message: body, family: family)
    }
  }
}

// MARK: - Shared pieces

private extension View {
  /// The whole view read as one sentence when the snapshot brings it;
  /// otherwise VoiceOver reads the visible texts together.
  @ViewBuilder
  func spoken(_ label: String?) -> some View {
    if let label {
      self.accessibilityElement(children: .ignore).accessibilityLabel(Text(verbatim: label))
    } else {
      self.accessibilityElement(children: .combine)
    }
  }
}

// MARK: - Adjustment labels (v3)

/// Fixed layout arithmetic. WidgetKit archives the rendered view tree of every
/// timeline entry, so the views do not measure themselves (`GeometryReader`,
/// `ViewThatFits`): `EntryBuilder` gets the widget size from the provider and
/// decides what fits when it builds the entry.
enum WidgetLayout {
  /// [size] from the system, or the smallest iPhone size of [family] when
  /// unknown (iPhone SE: 141 pt small, 292 pt wide medium).
  static func size(_ size: CGSize, _ family: WidgetFamily) -> CGSize {
    guard size.width <= 0 || size.height <= 0 else { return size }
    switch family {
    case .systemMedium: return CGSize(width: 292, height: 141)
    case .systemLarge: return CGSize(width: 292, height: 311)
    default: return CGSize(width: 141, height: 141)
    }
  }

  /// Height of one line of the system font at [size].
  static func line(_ size: CGFloat, _ weight: UIFont.Weight = .semibold) -> CGFloat {
    ceil(UIFont.systemFont(ofSize: size, weight: weight).lineHeight)
  }
}

/// Packs the localized adjustment labels («+2 h extra», «Salí 1 h antes») into
/// at most `maxLines` lines of whole words, one label per line group, and ends
/// with a separate « …» when something is left out: a native tail truncation
/// could cut a word («Da…»). The complete text stays in the spoken label.
enum ExtrasWrap {
  static func lines(
    _ labels: [String], width: CGFloat, maxLines: Int, size: CGFloat,
    weight: UIFont.Weight = .semibold
  ) -> [String] {
    guard maxLines > 0, width > 0 else { return [] }
    let font = UIFont.systemFont(ofSize: size, weight: weight)
    func measure(_ text: String) -> CGFloat {
      ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }
    // Like Android's `wholeWordLines`: a word that does not fit alone is never
    // emitted; the text ends there with a separate « …» on the previous line.
    var all: [String] = []
    var truncated = false
    pack: for label in labels {
      var line = ""
      for word in label.split(whereSeparator: \.isWhitespace).map(String.init) {
        let next = line.isEmpty ? word : "\(line) \(word)"
        if measure(next) <= width {
          line = next
          continue
        }
        if !line.isEmpty { all.append(line) }
        if measure(word) > width || all.count >= maxLines {
          truncated = true
          break pack
        }
        line = word
      }
      if !line.isEmpty { all.append(line) }
      if all.count > maxLines {
        truncated = true
        break
      }
    }
    if all.count > maxLines {
      all = Array(all.prefix(maxLines))
      truncated = true
    }
    guard truncated else { return all }
    var last = all.popLast() ?? ""
    while !last.isEmpty && measure("\(last) …") > width {
      guard let cut = last.lastIndex(of: " ") else {
        last = ""
        break
      }
      last = String(last[..<cut])
    }
    if last.isEmpty {
      // Nothing of the last line fits with the ellipsis: drop it too.
      return measure("…") <= width ? all + ["…"] : all
    }
    return all + ["\(last) …"]
  }
}

/// The packed lines, centred or leading. Pre-wrapped to fit the width, so the
/// scale factor only absorbs small measuring differences between UIKit and
/// SwiftUI; a word that does not fit is never drawn (`ExtrasWrap`).
private struct ExtrasLines: View {
  let lines: [String]
  let size: CGFloat
  var color: Color
  var alignment: TextAlignment = .center

  var body: some View {
    Text(verbatim: lines.joined(separator: "\n"))
      .font(.system(size: size, weight: .semibold))
      .foregroundStyle(color)
      .multilineTextAlignment(alignment)
      .lineLimit(lines.count)
      .minimumScaleFactor(0.6)
      .fixedSize(horizontal: false, vertical: true)
  }
}

/// A day of the strip and of the month grid: the number top left, the
/// code(s) on the tint of the first shift (up to two, then «+N»), a bar per
/// shown shift, holiday dot and note clip top right, today with a ring.
struct DayCellView: View {
  @Environment(\.colorScheme) private var scheme
  @Environment(\.widgetRenderingMode) private var renderingMode

  let dayOfMonth: Int
  let bands: [BandPaint]
  let isToday: Bool
  let isHoliday: Bool
  let hasNote: Bool
  var dim: Bool = false
  let radius: CGFloat
  let codeSize: CGFloat
  /// An absence day: redacted on a locked device (StandBy), question 15.
  var sensitive: Bool = false
  /// v3 adjustment labels already packed into whole-word lines that fit this
  /// cell (`extraLines`; empty where there is no room, as in the month grid).
  var extras: [String] = []

  static let extrasSize: CGFloat = 9
  /// Height of the date row (11 pt text + its top padding).
  private static let headerHeight: CGFloat = 17

  /// Whole lines of [labels] that fit a cell of [cell] points under the code
  /// and above the bar (up to [maxLines]); none when they do not fit.
  static func extraLines(
    _ labels: [String], cell: CGSize, shown: Int, codeSize: CGFloat, maxLines: Int
  ) -> [String] {
    guard !labels.isEmpty, maxLines > 0 else { return [] }
    let lineHeight = WidgetLayout.line(extrasSize)
    let used =
      headerHeight + (shown == 0 ? 0 : WidgetLayout.line(codeSize, .heavy) + WidgetMetrics.cellBar)
      + WidgetMetrics.hair
    let fitting = min(maxLines, Int(max(0, cell.height - used) / lineHeight))
    return ExtrasWrap.lines(
      labels, width: cell.width - 2 * WidgetMetrics.hair, maxLines: fitting, size: extrasSize)
  }

  var body: some View {
    let p = WidgetPalette.of(scheme)
    let full = renderingMode == .fullColor
    let dark = scheme == .dark
    let shown = Array(bands.prefix(2)).map { (code: $0.code, colors: $0.colors(dark: dark)) }
    let extra = bands.count - shown.count
    let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
    let codes = shown.map(\.code).joined(separator: " ") + (extra > 0 ? " +\(extra)" : "")
    let numberColor = isHoliday ? p.holiday : (dim ? p.textMuted : p.textSecondary)

    VStack(spacing: 0) {
      HStack(spacing: WidgetMetrics.hair) {
        Text(verbatim: String(dayOfMonth))
          .font(.system(size: 11, weight: isToday ? .black : .semibold))
          .monospacedDigit()
          .foregroundStyle(numberColor)
          .lineLimit(1)
          .minimumScaleFactor(0.6)
        Spacer(minLength: 0)
        if hasNote {
          Image(systemName: "paperclip")
            .font(.system(size: 8, weight: .semibold))
            .foregroundStyle(p.textMuted)
        }
        if isHoliday {
          Circle().fill(p.holiday)
            .frame(width: WidgetMetrics.holidayDot, height: WidgetMetrics.holidayDot)
        }
      }
      .padding(.horizontal, WidgetMetrics.xs)
      .padding(.top, 3)
      Spacer(minLength: 0)
      if let first = shown.first {
        Text(verbatim: codes)
          .font(.system(size: codeSize, weight: .heavy))
          .monospacedDigit()
          .foregroundStyle(first.colors.ink)
          .lineLimit(1)
          .minimumScaleFactor(0.35)
          .padding(.horizontal, WidgetMetrics.hair)
      }
      if !extras.isEmpty {
        ExtrasLines(
          lines: extras, size: Self.extrasSize,
          color: shown.first?.colors.ink ?? p.textSecondary
        )
        .padding(.horizontal, WidgetMetrics.hair)
      }
      Spacer(minLength: 0)
      if !shown.isEmpty {
        HStack(spacing: 0) {
          ForEach(shown.indices, id: \.self) { i in
            Rectangle()
              .fill(full ? shown[i].colors.bar : Color.primary)
              .widgetAccentable()
          }
        }
        .frame(height: WidgetMetrics.cellBar)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background {
      if full {
        shape.fill(shown.first?.colors.tint ?? (dim ? p.surfaceMuted : p.surface))
      } else {
        shape.fill(Color.primary.opacity(shown.isEmpty ? 0 : 0.1))
      }
    }
    .clipShape(shape)
    .overlay {
      if isToday {
        shape.strokeBorder(full ? p.todayRing : Color.primary, lineWidth: WidgetMetrics.ring)
          .widgetAccentable()
      } else if !full && !shown.isEmpty {
        shape.strokeBorder(Color.primary.opacity(0.35), lineWidth: 1)
      }
    }
    .privacySensitive(sensitive)
  }
}

// MARK: - systemSmall

/// The date, today's code big on the tint of its shift, the time, the day's
/// adjustments (v3), tomorrow, and a bar per shift (the «Hoy» card of the app).
/// Like Android, with adjustments the layout gives them the height first:
/// tomorrow goes before they lose lines, and the code and time shrink last.
/// What fits was decided when the entry was built (`EntryBuilder`).
struct SmallView: View {
  @Environment(\.colorScheme) private var scheme
  @Environment(\.widgetRenderingMode) private var renderingMode
  let model: SmallModel

  var body: some View {
    let p = WidgetPalette.of(scheme)
    let full = renderingMode == .fullColor
    let shifts = model.shifts.map { $0.colors(dark: scheme == .dark) }
    let bigSize: CGFloat = model.isEmpty ? 21 : (model.compact ? 26 : 36)
    let detailSize: CGFloat = model.compact ? 15 : 19

    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: WidgetMetrics.xs) {
        Text(verbatim: model.dateLabel)
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(model.isHoliday ? p.holiday : p.textMuted)
          .lineLimit(1)
        if model.isHoliday {
          Circle().fill(p.holiday)
            .frame(width: WidgetMetrics.holidayDot, height: WidgetMetrics.holidayDot)
        }
        Spacer(minLength: 0)
        if model.hasNote {
          Image(systemName: "paperclip")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(p.textMuted)
        }
      }
      Text(verbatim: model.big)
        .font(.system(size: bigSize, weight: .heavy))
        .foregroundStyle(shifts.first?.ink ?? p.textPrimary)
        .lineLimit(1)
        .minimumScaleFactor(0.4)
        .padding(.top, WidgetMetrics.hair)
      if let detail = model.detail {
        // Split shifts («09–13 · 17–21») shrink instead of being cut.
        Text(verbatim: detail)
          .font(.system(size: detailSize, weight: .semibold))
          .monospacedDigit()
          .foregroundStyle(p.textSecondary)
          .lineLimit(1)
          .minimumScaleFactor(0.5)
      }
      if !model.extra.isEmpty {
        ExtrasLines(
          lines: model.extra, size: 11, color: p.textSecondary, alignment: .leading
        )
        .padding(.top, WidgetMetrics.hair)
      }
      Spacer(minLength: WidgetMetrics.hair)
      if model.showTomorrow {
        Text(verbatim: model.tomorrow)
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(p.textMuted)
          .lineLimit(1)
          .minimumScaleFactor(0.6)
      }
      if !shifts.isEmpty {
        HStack(spacing: WidgetMetrics.hair) {
          ForEach(shifts.indices, id: \.self) { i in
            Capsule()
              .fill(full ? shifts[i].bar : Color.primary)
              .frame(height: WidgetMetrics.smallBar)
              .widgetAccentable()
          }
        }
        .padding(.top, 8)
      }
    }
    .padding(.horizontal, WidgetMetrics.l)
    .padding(.vertical, model.compact ? WidgetMetrics.xs * 2 : WidgetMetrics.m)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .spoken(model.spoken)
    .privacySensitive(model.sensitive)
    .widgetURL(WidgetLink.day(model.date))
    .containerBackground(for: .widget) {
      shifts.first?.tint ?? p.surface
    }
  }
}

// MARK: - systemMedium

/// The day and the six following ones, each with its weekday, the day's
/// adjustments (v3, where the cell has room) and, above them, the seven-day
/// total (v3, «7 días: …», read from the snapshot as is).
struct MediumView: View {
  @Environment(\.colorScheme) private var scheme
  let model: MediumModel

  var body: some View {
    let p = WidgetPalette.of(scheme)
    VStack(spacing: WidgetMetrics.xs) {
      if let total = model.total {
        Text(verbatim: total)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(p.textSecondary)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, WidgetMetrics.hair)
          .privacySensitive(model.totalSensitive)
      }
      HStack(spacing: WidgetMetrics.xs) {
        ForEach(model.cells.indices, id: \.self) { i in
          let cell = model.cells[i]
          Link(destination: WidgetLink.day(cell.date)) {
            VStack(spacing: WidgetMetrics.xs) {
              Text(verbatim: cell.weekdayShort)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(p.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
              DayCellView(
                dayOfMonth: cell.dayOfMonth,
                bands: cell.bands,
                isToday: cell.isToday,
                isHoliday: cell.isHoliday,
                hasNote: cell.hasNote,
                radius: WidgetMetrics.stripRadius,
                codeSize: 20,
                sensitive: cell.sensitive,
                extras: cell.extra)
            }
          }
          .spoken(cell.spoken)
        }
      }
    }
    .padding(WidgetMetrics.m)
    .widgetURL(WidgetLink.day(model.date))
    .containerBackground(for: .widget) { p.surface }
  }
}

// MARK: - systemLarge

/// The month of the day: title, weekday headers, 6×7 cells, neighbouring
/// months dimmed, today with a ring.
struct LargeView: View {
  @Environment(\.colorScheme) private var scheme
  let model: LargeModel

  var body: some View {
    let p = WidgetPalette.of(scheme)

    VStack(alignment: .leading, spacing: WidgetMetrics.xs) {
      Link(destination: WidgetLink.month(model.monthKey)) {
        Text(verbatim: model.title)
          .font(.system(size: 17, weight: .heavy))
          .foregroundStyle(p.textPrimary)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      HStack(spacing: WidgetMetrics.hair) {
        ForEach(model.weekdayHeaders.indices, id: \.self) { i in
          Text(verbatim: model.weekdayHeaders[i])
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(p.textMuted)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
        }
      }
      .accessibilityHidden(true)
      VStack(spacing: WidgetMetrics.hair) {
        ForEach(0..<6, id: \.self) { row in
          HStack(spacing: WidgetMetrics.hair) {
            ForEach(0..<7, id: \.self) { col in
              let cell = model.cells[row * 7 + col]
              Link(destination: WidgetLink.day(cell.date)) {
                DayCellView(
                  dayOfMonth: cell.dayOfMonth,
                  bands: cell.bands,
                  isToday: cell.isToday,
                  isHoliday: cell.isHoliday,
                  hasNote: cell.hasNote,
                  dim: !cell.inMonth,
                  radius: WidgetMetrics.gridRadius,
                  codeSize: 15,
                  sensitive: cell.sensitive)
              }
              .spoken(cell.spoken)
            }
          }
        }
      }
    }
    .padding(WidgetMetrics.m)
    .widgetURL(WidgetLink.month(model.monthKey))
    .containerBackground(for: .widget) { p.surface }
  }
}

// MARK: - Lock screen (monochrome text; absences already neutral in LockModel)

struct InlineLockView: View {
  let model: LockModel

  var body: some View {
    Text(verbatim: model.inline)
      .spoken(model.spoken)
      .widgetURL(WidgetLink.day(model.date))
      .containerBackground(for: .widget) { Color.clear }
  }
}

struct CircularLockView: View {
  let model: LockModel

  var body: some View {
    ZStack {
      AccessoryWidgetBackground()
      Text(verbatim: model.circular)
        .font(.system(size: 22, weight: .heavy))
        .lineLimit(1)
        .minimumScaleFactor(0.35)
        .padding(6)
    }
    .spoken(model.spoken)
    .widgetURL(WidgetLink.day(model.date))
    .containerBackground(for: .widget) { Color.clear }
  }
}

struct RectangularLockView: View {
  let model: LockModel

  var body: some View {
    VStack(alignment: .leading, spacing: 1) {
      // Split shifts («P · 09–13 · 17–21») shrink instead of being cut.
      Text(verbatim: model.line1)
        .font(.system(size: 17, weight: .bold))
        .lineLimit(1)
        .minimumScaleFactor(0.55)
      if let line2 = model.line2 {
        Text(verbatim: line2)
          .font(.system(size: 15))
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .minimumScaleFactor(0.55)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .spoken(model.spoken)
    .widgetURL(WidgetLink.day(model.date))
    .containerBackground(for: .widget) { Color.clear }
  }
}

// MARK: - Stale notice

/// Only `staleTitle` / `staleBody` (or the extension's own texts): never a
/// shift, a shift colour or anything of another day (contract §6).
struct StaleView: View {
  @Environment(\.colorScheme) private var scheme
  let title: String
  let message: String
  let family: WidgetFamily

  var body: some View {
    let p = WidgetPalette.of(scheme)
    Group {
      switch family {
      case .accessoryInline:
        Text(verbatim: message)
          .containerBackground(for: .widget) { Color.clear }
      case .accessoryCircular:
        ZStack {
          AccessoryWidgetBackground()
          Text(verbatim: "–").font(.system(size: 22, weight: .heavy))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: message))
        .containerBackground(for: .widget) { Color.clear }
      case .accessoryRectangular:
        VStack(alignment: .leading, spacing: 1) {
          Text(verbatim: title).font(.system(size: 17, weight: .bold)).lineLimit(1)
          Text(verbatim: message).font(.system(size: 15)).lineLimit(2).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .containerBackground(for: .widget) { Color.clear }
      default:
        VStack(alignment: .leading, spacing: WidgetMetrics.xs) {
          Text(verbatim: title)
            .font(.system(size: 17, weight: .heavy))
            .foregroundStyle(p.textPrimary)
            .lineLimit(1)
          Text(verbatim: message)
            .font(.system(size: 13))
            .foregroundStyle(p.textMuted)
            .lineLimit(4)
            .minimumScaleFactor(0.8)
          Spacer(minLength: 0)
        }
        .padding(WidgetMetrics.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
        .containerBackground(for: .widget) { p.surface }
      }
    }
    .widgetURL(WidgetLink.app)
  }
}
