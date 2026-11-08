import 'package:flutter/material.dart';

import '../../../core/theme/theme_context.dart';
import '../data/widget_publisher.dart';
import '../domain/widget_snapshot.dart';

/// Flutter drawings of the six home-screen widgets (design 7A, B8), made
/// from the same [WidgetSnapshot] the native widgets read, so they show the
/// user's real shifts with the native layout: the code on the tint of the
/// shift, one bar per shift, today with a ring, holidays with the number in
/// red. Each one is laid out at its home-screen size ([designSize]) and
/// scaled to the room it gets, so it never wraps or overflows; the text size
/// of the phone does not change it (the gallery says what each one is in
/// normal text under it).
class WidgetPreview extends StatelessWidget {
  const WidgetPreview({super.key, required this.size, required this.snapshot});

  final WidgetSize size;
  final WidgetSnapshot snapshot;

  /// Home-screen size of each widget, in dp (Android 2x2, 4x2, 4x4).
  static Size designSize(WidgetSize size) => switch (size) {
    WidgetSize.small => const Size(150, 150),
    WidgetSize.medium => const Size(320, 150),
    WidgetSize.large => const Size(320, 320),
    WidgetSize.agenda => const Size(320, 150),
    WidgetSize.twoWeeks => const Size(320, 150),
    WidgetSize.fourWeeks => const Size(320, 320),
  };

  @override
  Widget build(BuildContext context) {
    final design = designSize(size);
    final day = snapshot.days.first;
    final Widget body = switch (size) {
      WidgetSize.small => _Small(day: day),
      WidgetSize.medium => _Medium(snapshot: snapshot, day: day),
      WidgetSize.large => _Large(snapshot: snapshot, day: day),
      WidgetSize.agenda => _Agenda(snapshot: snapshot, day: day),
      WidgetSize.twoWeeks => _TwoWeeks(snapshot: snapshot, day: day),
      WidgetSize.fourWeeks => _FourWeeks(snapshot: snapshot, day: day),
    };
    return ExcludeSemantics(
      child: AspectRatio(
        aspectRatio: design.width / design.height,
        child: FittedBox(
          child: MediaQuery.withNoTextScaling(
            child: SizedBox.fromSize(
              size: design,
              child: _Frame(child: body),
            ),
          ),
        ),
      ),
    );
  }
}

/// The widget's own card: `surface`, the launcher radius, a soft shadow.
class _Frame extends StatelessWidget {
  const _Frame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: Rad.previewRadius,
        boxShadow: [BoxShadow(color: colors.softShadow, blurRadius: Sp.m)],
      ),
      child: ClipRRect(borderRadius: Rad.previewRadius, child: child),
    );
  }
}

/// Colours of a band in the theme on screen (dim: days of other months).
({Color bar, Color tint, Color ink}) _band(
  WidgetSnapshot snapshot,
  WidgetBand band,
  bool dark, {
  bool dim = false,
}) {
  final s = snapshot.styles[band.style];
  final bar = dim
      ? (dark ? s.dimBarDark : s.dimBarLight)
      : (dark ? s.barDark : s.barLight);
  final tint = dim
      ? (dark ? s.dimTintDark : s.dimTintLight)
      : (dark ? s.tintDark : s.tintLight);
  final ink = dim
      ? (dark ? s.dimInkDark : s.dimInkLight)
      : (dark ? s.inkDark : s.inkLight);
  return (bar: Color(bar), tint: Color(tint), ink: Color(ink));
}

({Color bar, Color tint, Color ink, Color disc}) _shift(
  WidgetShift s,
  bool dark,
) => (
  bar: Color(dark ? s.barDark : s.barLight),
  tint: Color(dark ? s.tintDark : s.tintLight),
  ink: Color(dark ? s.inkDark : s.inkLight),
  disc: Color(dark ? s.discDark : s.discLight),
);

/// 2x2: the date, today's code big on the tint of its shift, the time,
/// tomorrow, and a bar per shift.
class _Small extends StatelessWidget {
  const _Small({required this.day});

  final WidgetDay day;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final dark = colors.isDark;
    final shifts = [for (final s in day.shifts) _shift(s, dark)];
    final small = day.small;
    return ColoredBox(
      color: shifts.isEmpty ? colors.surface : shifts.first.tint,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Sp.l, Sp.m, Sp.l, Sp.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              day.dateLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: type.meta.copyWith(
                color: colors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            // The code takes the room left, shrinking before it overflows.
            Flexible(
              flex: 3,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  small.big,
                  maxLines: 1,
                  style: (small.isEmpty ? type.title : type.display).copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ),
            ),
            if (small.detail != null)
              Text(
                small.detail!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: type.bodyStrong.copyWith(color: colors.textSecondary),
              ),
            const Spacer(),
            Text(
              small.tomorrow,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: type.caption.copyWith(
                color: colors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (shifts.isNotEmpty) ...[
              const SizedBox(height: Sp.s),
              Row(
                children: [
                  for (final s in shifts)
                    Expanded(
                      child: Container(
                        height: Sp.cardBar,
                        margin: const EdgeInsets.symmetric(
                          horizontal: Sp.hair / 2,
                        ),
                        decoration: BoxDecoration(
                          color: s.bar,
                          borderRadius: Rad.pill,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A day cell of the strips and grids: the day number, the code(s) on the
/// tint of the first shift, a bar per shift (up to two), today with a ring.
class _Cell extends StatelessWidget {
  const _Cell({
    required this.dayOfMonth,
    required this.bands,
    this.isToday = false,
    this.isHoliday = false,
    this.dim = false,
  });

  final int dayOfMonth;

  /// (code, colours) of each shift of the day.
  final List<(String, ({Color bar, Color tint, Color ink}))> bands;
  final bool isToday;
  final bool isHoliday;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final shown = bands.take(2).toList();
    final background = shown.isEmpty
        ? (dim ? colors.surfaceMuted : colors.surface)
        : shown.first.$2.tint;
    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: Rad.innerRadius,
        border: isToday
            ? Border.all(color: colors.todayRing, width: Sp.ring)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            left: Sp.xs,
            top: Sp.hair,
            child: Text(
              '$dayOfMonth',
              style: type.caption.copyWith(
                color: isHoliday
                    ? colors.holiday
                    : (dim ? colors.textMuted : colors.textSecondary),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (shown.isNotEmpty)
            Positioned.fill(
              top: Sp.m,
              bottom: Sp.bar,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Sp.hair),
                    child: Text(
                      shown.map((b) => b.$1).join(' '),
                      maxLines: 1,
                      style: type.cellCode.copyWith(color: shown.first.$2.ink),
                    ),
                  ),
                ),
              ),
            ),
          if (shown.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: Sp.xs,
              child: Row(
                children: [
                  for (final b in shown)
                    Expanded(child: ColoredBox(color: b.$2.bar)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 4x2: the day and the six following ones.
class _Medium extends StatelessWidget {
  const _Medium({required this.snapshot, required this.day});

  final WidgetSnapshot snapshot;
  final WidgetDay day;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final dark = colors.isDark;
    return Padding(
      padding: const EdgeInsets.all(Sp.m),
      child: Row(
        children: [
          for (final cell in day.medium.cells)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Sp.hair),
                child: Column(
                  children: [
                    Text(
                      cell.weekdayShort,
                      maxLines: 1,
                      style: type.caption.copyWith(
                        color: colors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: Sp.xs),
                    Expanded(
                      child: _Cell(
                        dayOfMonth: cell.dayOfMonth,
                        isToday: cell.isToday,
                        isHoliday: cell.isHoliday,
                        bands: [
                          for (final b in cell.bands)
                            (b.code, _band(snapshot, b, dark)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 4x4: the month of the day, six weeks of seven days.
class _Large extends StatelessWidget {
  const _Large({required this.snapshot, required this.day});

  final WidgetSnapshot snapshot;
  final WidgetDay day;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final dark = colors.isDark;
    final month = snapshot.months[day.large.month];
    return Padding(
      padding: const EdgeInsets.all(Sp.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            month.title,
            maxLines: 1,
            style: type.bodyStrong.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: Sp.xs),
          Row(
            children: [
              for (final h in snapshot.weekdayHeaders)
                Expanded(
                  child: Text(
                    h,
                    textAlign: TextAlign.center,
                    style: type.caption.copyWith(color: colors.textMuted),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Sp.xs),
          Expanded(
            child: Column(
              children: [
                for (var week = 0; week < 6; week++)
                  Expanded(
                    child: Row(
                      children: [
                        for (var d = 0; d < 7; d++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(Sp.hair / 2),
                              child: Builder(
                                builder: (context) {
                                  final i = week * 7 + d;
                                  final cell = month.cells[i];
                                  return _Cell(
                                    dayOfMonth: cell.dayOfMonth,
                                    isToday: i == day.large.todayCell,
                                    isHoliday: cell.isHoliday,
                                    dim: !cell.inMonth,
                                    bands: [
                                      for (final b in cell.bands)
                                        (
                                          b.code,
                                          _band(
                                            snapshot,
                                            b,
                                            dark,
                                            dim: !cell.inMonth,
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The days from today on, out of the auxiliary days of the snapshot.
List<WidgetDisplayDay> _fromToday(WidgetSnapshot snapshot, WidgetDay day) => [
  for (final d in snapshot.displayDays)
    if (d.date.compareTo(day.date) >= 0) d,
];

/// 4x2: today and the next days, one row each.
class _Agenda extends StatelessWidget {
  const _Agenda({required this.snapshot, required this.day});

  final WidgetSnapshot snapshot;
  final WidgetDay day;

  /// Rows a 4x2 widget fits at normal text size.
  static const int rows = 4;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final dark = colors.isDark;
    final days = _fromToday(snapshot, day).take(rows).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sp.l, vertical: Sp.s),
      child: Column(
        children: [
          for (var i = 0; i < days.length; i++)
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: i == 0
                      ? null
                      : Border(top: BorderSide(color: colors.border)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: Disc.l + Sp.l,
                      child: Text(
                        days[i].dateLabel,
                        maxLines: 1,
                        style: type.meta.copyWith(
                          color: days[i].isHoliday
                              ? colors.holiday
                              : colors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (days[i].shifts.isEmpty)
                      Expanded(
                        child: Text(
                          snapshot.noShift,
                          maxLines: 1,
                          style: type.meta.copyWith(color: colors.textMuted),
                        ),
                      )
                    else ...[
                      _Disc(
                        shift: _shift(days[i].shifts.first, dark),
                        code: days[i].shifts.first.code,
                      ),
                      const SizedBox(width: Sp.s),
                      Expanded(
                        child: Text(
                          days[i].shifts.first.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: type.meta.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (days[i].shifts.first.timeLabel != null)
                        Text(
                          days[i].shifts.first.timeLabel!,
                          maxLines: 1,
                          style: AppTypography.tabular(
                            type.caption.copyWith(color: colors.textSecondary),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The disc of a shift in the agenda: its code in its ink on its disc.
class _Disc extends StatelessWidget {
  const _Disc({required this.shift, required this.code});

  final ({Color bar, Color tint, Color ink, Color disc}) shift;
  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Disc.s - Sp.xs,
      height: Disc.s - Sp.xs,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: shift.disc,
        borderRadius: Rad.squareRadius(Disc.s - Sp.xs),
      ),
      child: FittedBox(
        child: Padding(
          padding: const EdgeInsets.all(Sp.hair),
          child: Text(
            code,
            maxLines: 1,
            style: context.type.cellCode.copyWith(color: shift.ink),
          ),
        ),
      ),
    );
  }
}

/// 4x4: four Monday-first weeks (the next day off on top, the weekday
/// headers, then four rows of seven days), each day with its number, its
/// shift and the first line of its note.
class _FourWeeks extends StatelessWidget {
  const _FourWeeks({required this.snapshot, required this.day});

  final WidgetSnapshot snapshot;
  final WidgetDay day;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final dark = colors.isDark;
    final days = snapshot.displayDays.take(kWidgetFourWeeksDays).toList();
    final headers = days.take(7).map((d) => d.weekdayShort).toList();
    final nextOff = snapshot.nextOff?[day.date]?.label;
    return Padding(
      padding: const EdgeInsets.all(Sp.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (nextOff != null) ...[
            Text(
              nextOff,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: type.meta.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: Sp.xs),
          ],
          Row(
            children: [
              for (final h in headers)
                Expanded(
                  child: Text(
                    h,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: type.caption.copyWith(color: colors.textMuted),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Sp.xs),
          Expanded(
            child: Column(
              children: [
                for (var week = 0; week < 4; week++)
                  Expanded(
                    child: Row(
                      children: [
                        for (var d = 0; d < 7; d++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(Sp.hair / 2),
                              child: week * 7 + d < days.length
                                  ? _FourWeeksCell(
                                      day: days[week * 7 + d],
                                      dark: dark,
                                      isToday:
                                          days[week * 7 + d].date == day.date,
                                      note: snapshot
                                          .notes?[days[week * 7 + d].date],
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One day of the four-week grid: the number, the shift code(s) on the tint
/// of the first shift, one bar per shift, the first line of its note under
/// them, today with a ring and holidays with the number in red.
class _FourWeeksCell extends StatelessWidget {
  const _FourWeeksCell({
    required this.day,
    required this.dark,
    required this.isToday,
    this.note,
  });

  final WidgetDisplayDay day;
  final bool dark;
  final bool isToday;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final bands = [
      for (final s in day.shifts)
        (
          s.code,
          () {
            final c = _shift(s, dark);
            return (bar: c.bar, tint: c.tint, ink: c.ink);
          }(),
        ),
    ];
    final shown = bands.take(2).toList();
    return Container(
      decoration: BoxDecoration(
        color: shown.isEmpty ? colors.surface : shown.first.$2.tint,
        borderRadius: Rad.innerRadius,
        border: isToday
            ? Border.all(color: colors.todayRing, width: Sp.ring)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: Sp.xs, top: Sp.hair),
            child: Text(
              '${day.dayOfMonth}',
              maxLines: 1,
              style: type.caption.copyWith(
                color: day.isHoliday ? colors.holiday : colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Sp.hair),
                  child: Text(
                    shown.map((b) => b.$1).join(' '),
                    maxLines: 1,
                    style: type.cellCode.copyWith(
                      color: shown.isEmpty
                          ? colors.textMuted
                          : shown.first.$2.ink,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.hair),
              child: Text(
                note!,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: type.cellTime.copyWith(color: colors.textMuted),
              ),
            ),
          if (shown.isNotEmpty)
            Row(
              children: [
                for (final b in shown)
                  Expanded(
                    child: SizedBox(
                      height: Sp.xs,
                      child: ColoredBox(color: b.$2.bar),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// 4x2: this week and the next, from Monday.
class _TwoWeeks extends StatelessWidget {
  const _TwoWeeks({required this.snapshot, required this.day});

  final WidgetSnapshot snapshot;
  final WidgetDay day;

  @override
  Widget build(BuildContext context) {
    final dark = context.colors.isDark;
    final days = snapshot.displayDays.take(14).toList();
    return Padding(
      padding: const EdgeInsets.all(Sp.m),
      child: Column(
        children: [
          for (var week = 0; week < 2; week++)
            Expanded(
              child: Row(
                children: [
                  for (var d = 0; d < 7; d++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(Sp.hair),
                        child: week * 7 + d < days.length
                            ? _Cell(
                                dayOfMonth: days[week * 7 + d].dayOfMonth,
                                isToday: days[week * 7 + d].date == day.date,
                                isHoliday: days[week * 7 + d].isHoliday,
                                bands: [
                                  for (final s in days[week * 7 + d].shifts)
                                    (
                                      s.code,
                                      () {
                                        final c = _shift(s, dark);
                                        return (
                                          bar: c.bar,
                                          tint: c.tint,
                                          ink: c.ink,
                                        );
                                      }(),
                                    ),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
