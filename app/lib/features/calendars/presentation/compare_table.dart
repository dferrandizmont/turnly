import 'dart:math' show max;

import 'package:flutter/material.dart';

import '../../../core/format/app_date_format.dart';
import '../../../core/icons/app_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../calendar/presentation/day_cell.dart' show textHeight;
import '../../calendar/presentation/shift_format.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../domain/calendar.dart';
import '../domain/calendar_comparison.dart';
import 'calendar_dot.dart';

/// The grid of the comparison of several calendars (P12): **one row per
/// calendar and one column per day** of the month.
///
/// The column of the names does not scroll: the days do (a whole month does
/// not fit in a phone, not even at 320 dp), so the name of a calendar is
/// always in front of its shifts. Every cell carries the code of the shifts
/// of that calendar that day, in the colour of the shift, so a day is never
/// told by colour alone. The days everybody is free carry a check and the
/// days with nothing annotated carry the hollow mark of [UnrecordedMark]
/// (A6: an empty day is not a day off).
///
/// Read-only: it never changes a calendar nor a schedule.
class CompareTable extends StatelessWidget {
  const CompareTable({
    super.key,
    required this.comparison,
    required this.today,
  });

  /// The comparison of the month: the rows (the calendars) and the columns
  /// (the days).
  final MultiComparison comparison;

  /// The day with the ring of "today".
  final CivilDate today;

  @override
  Widget build(BuildContext context) {
    final days = comparison.days;
    final calendars = comparison.calendars;
    if (days.isEmpty || calendars.isEmpty) return const SizedBox.shrink();
    final type = context.type;
    final scaler = MediaQuery.textScalerOf(context);
    final textScale = scaler.scale(1);
    // The text of the person makes the cells bigger, never smaller.
    final scale = textScale.clamp(1.0, 1.6);
    final dayWidth = Disc.s * scale;
    // The rows are as tall as the name of the calendar needs (two lines with
    // big text) and the head as tall as the number of the day, its weekday and
    // the mark of the day (free in common, or with nothing annotated): the
    // lines are measured with [textHeight], never guessed from the style, so
    // the head never clips the mark nor covers the number.
    final nameLine = textHeight(type.caption, scaler);
    final rowHeight = max(Disc.m * scale, nameLine * 2 + Sp.s);
    final headLine =
        textHeight(type.cellDay, scaler) +
        textHeight(
          type.caption.copyWith(fontSize: type.cellDay.fontSize),
          scaler,
        );
    final headHeight = max(
      rowHeight,
      headLine + _DayHeaderCell.markRoom + Sp.xs + 2 * Sp.hair,
    );
    final namesWidth = (Sp.x4 * 2 + Sp.l) * scale;

    return Row(
      key: const ValueKey('compare-table'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: namesWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _NamesHeader(height: headHeight),
              for (final calendar in calendars)
                _NameCell(calendar: calendar, height: rowHeight),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            key: const ValueKey('compare-days-scroll'),
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DaysHeader(
                  days: days,
                  today: today,
                  width: dayWidth,
                  height: headHeight,
                ),
                for (var i = 0; i < calendars.length; i++)
                  _DayRow(
                    days: days,
                    index: i,
                    calendar: calendars[i],
                    width: dayWidth,
                    height: rowHeight,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The head of the column of the names: what the rows are.
class _NamesHeader extends StatelessWidget {
  const _NamesHeader({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: height,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(
        left: Sp.xs,
        right: Sp.xs,
        bottom: Sp.hair,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Text(
        context.l10n.compareTableNames,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.type.caption,
      ),
    );
  }
}

/// The name of a calendar, with its colour: the row of the grid.
class _NameCell extends StatelessWidget {
  const _NameCell({required this.calendar, required this.height});

  final Calendar calendar;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Semantics(
      header: true,
      child: Container(
        key: ValueKey('compare-name-${calendar.id}'),
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: Sp.xs, vertical: Sp.xs),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: Sp.hair),
              child: CalendarDot(colorValue: calendar.colorValue),
            ),
            const SizedBox(width: Sp.xs),
            Expanded(
              child: Text(
                calendar.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: type.caption.copyWith(color: colors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The head of the days: the number of the day, its weekday and the marks of
/// the days everybody is free and of the days with nothing annotated.
class _DaysHeader extends StatelessWidget {
  const _DaysHeader({
    required this.days,
    required this.today,
    required this.width,
    required this.height,
  });

  final List<MultiComparedDay> days;
  final CivilDate today;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: height,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          for (final day in days)
            _DayHeaderCell(
              day: day,
              isToday: day.date == today,
              width: width,
              height: height,
            ),
        ],
      ),
    );
  }
}

/// One day of the head: its number and its weekday, and, in a row of its own
/// at the bottom, the check of the days free in common or the hollow mark of
/// the days with nothing annotated. The marks never land on the number or the
/// weekday, and the head reserves their room in every column so all the
/// numbers stay on the same line.
class _DayHeaderCell extends StatelessWidget {
  const _DayHeaderCell({
    required this.day,
    required this.isToday,
    required this.width,
    required this.height,
  });

  final MultiComparedDay day;
  final bool isToday;
  final double width;
  final double height;

  static const double _markSize = 11;

  /// Height of the bottom row of the head: the mark disc of the free day
  /// (the icon plus its own padding) or the hollow mark of a day with nothing
  /// annotated, plus the gap above it. Reserved in every column.
  static const double markRoom = _markSize + 2 * Sp.hair + Sp.hair;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    final format = AppDateFormat.of(context);
    final date = day.date;
    final free = day.allFree;
    final unrecorded = day.hasUnrecorded;
    // Dark mode selects in amber, light mode in the accent, like the marks
    // of the month grid.
    final markColor = colors.isDark ? colors.highlight : colors.accent;
    final onMarkColor = colors.isDark ? colors.onHighlight : colors.onAccent;

    return Semantics(
      container: true,
      header: true,
      excludeSemantics: true,
      label: [
        format.weekdayDayMonth(DateTime(date.year, date.month, date.day)),
        if (isToday) l10n.daySemanticsToday,
        if (free) l10n.compareBothFree,
        if (unrecorded) l10n.compareUnrecorded,
      ].join('. '),
      child: Container(
        key: ValueKey('compare-day-${date.toIso()}'),
        width: width,
        height: height,
        padding: const EdgeInsets.all(Sp.hair),
        decoration: BoxDecoration(
          color: isWeekendDay(date) ? colors.surfaceMuted : colors.surface,
          border: isToday
              ? Border.all(color: colors.todayRing, width: Sp.ring)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.topLeft,
                child: FittedBox(
                  // The number and its weekday never overflow the cell, not
                  // even with the text of the person at ×2.
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${date.day}',
                        maxLines: 1,
                        style: type.cellDay.copyWith(
                          fontWeight: isToday ? FontWeight.w900 : null,
                        ),
                      ),
                      Text(
                        _weekdayInitial(l10n, date),
                        maxLines: 1,
                        style: type.caption.copyWith(
                          fontSize: type.cellDay.fontSize,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // The mark of the day, in its own row at the bottom: never over
            // the number, never clipped by the edge of the last column.
            if (free || unrecorded)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (free)
                    DecoratedBox(
                      key: ValueKey('compare-free-${date.toIso()}'),
                      decoration: BoxDecoration(
                        color: markColor,
                        borderRadius: Rad.squareRadius(_markSize + 2 * Sp.hair),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(Sp.hair),
                        child: Icon(
                          AppIcons.check,
                          size: _markSize,
                          color: onMarkColor,
                        ),
                      ),
                    ),
                  if (unrecorded)
                    UnrecordedMark(
                      key: ValueKey('compare-unrecorded-${date.toIso()}'),
                      size: _markSize,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// The first letter of the weekday, as the head of the month grid shows it.
String _weekdayInitial(AppLocalizations l10n, CivilDate date) =>
    switch (date.weekday) {
      DateTime.monday => l10n.calendarWeekdayMon,
      DateTime.tuesday => l10n.calendarWeekdayTue,
      DateTime.wednesday => l10n.calendarWeekdayWed,
      DateTime.thursday => l10n.calendarWeekdayThu,
      DateTime.friday => l10n.calendarWeekdayFri,
      DateTime.saturday => l10n.calendarWeekdaySat,
      _ => l10n.calendarWeekdaySun,
    };

/// One row of the grid: the shifts of one calendar in every day of the month.
class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.days,
    required this.index,
    required this.calendar,
    required this.width,
    required this.height,
  });

  final List<MultiComparedDay> days;
  final int index;
  final Calendar calendar;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final day in days)
          _ShiftCell(
            day: day.dayOf(index),
            calendar: calendar,
            width: width,
            height: height,
          ),
      ],
    );
  }
}

/// The shifts of ONE calendar on a day: the codes of the shifts in the
/// colour of the first one, a dash when there is none.
class _ShiftCell extends StatelessWidget {
  const _ShiftCell({
    required this.day,
    required this.calendar,
    required this.width,
    required this.height,
  });

  final ResolvedDay day;
  final Calendar calendar;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    final brightness = colors.brightness;
    final swatches = [for (final shift in day.shifts) shift.swatch(brightness)];
    final lead = swatches.isEmpty ? null : swatches.first;
    final label = day.shifts.isEmpty
        ? l10n.compareNoShiftMark
        : day.shifts.map((shift) => shift.code).join('+');
    final shifts = day.shifts.isEmpty
        ? l10n.calendarNoShift
        : day.shifts.map((shift) => shift.name).join(' + ');

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: l10n.compareCellCalendar(calendar.name, shifts),
      child: Container(
        key: ValueKey('compare-cell-${calendar.id}-${day.date.toIso()}'),
        width: width,
        height: height,
        color: lead?.tint ?? colors.surface,
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: type.cellCodeMulti.copyWith(
              color: lead?.ink ?? colors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// The hollow mark of a day «sin anotar»: a ring with a dash, in muted tones
/// (never a day off, never a busy one). The legend of the summary uses it
/// too.
class UnrecordedMark extends StatelessWidget {
  const UnrecordedMark({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: Rad.squareRadius(size + 2 * Sp.hair),
        border: Border.all(color: colors.borderStrong),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Sp.hair),
        child: Icon(AppIcons.minus, size: size, color: colors.textMuted),
      ),
    );
  }
}
