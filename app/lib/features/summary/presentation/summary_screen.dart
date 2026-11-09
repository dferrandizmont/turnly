import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/app_date_format.dart';
import '../../../core/format/money.dart';
import '../../../core/icons/app_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/router.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/choice_grid.dart';
import '../../../core/widgets/choice_pill.dart';
import '../../../core/widgets/content_app_bar.dart';
import '../../../core/widgets/empty_illustration.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/page_body.dart';
import '../../../core/widgets/value_row.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../calendar/application/schedule_controller.dart';
import '../../calendar/application/visible_month.dart';
import '../../absences/presentation/absence_icons.dart';
import '../../absences/presentation/absence_summary_card.dart';
import '../../holidays/application/holidays_provider.dart';
import '../../settings/application/preferences_controller.dart';
import '../../settings/presentation/withholding_sheet.dart';
import '../../year/application/year_providers.dart';
import '../../year/presentation/year_image.dart';
import '../../calendar/presentation/shift_badge.dart';
import '../../calendar/presentation/shift_format.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../application/summary_providers.dart';
import '../domain/month_summary.dart';
import '../domain/pay_period.dart';
import '../domain/payroll.dart';
import '../domain/period_hours.dart';
import '../domain/summary_range.dart';
import 'hours_goal_section.dart';
import 'how_am_i_doing_card.dart';
import '../../reports/presentation/report_share_button.dart';
import 'month_sharing.dart';
import 'overtime_cap_card.dart';
import 'summary_format.dart';
import 'summary_stat_row.dart';
import 'year_table.dart';

/// "Resumen del mes" (free, `docs/roadmap.md`): per shift type the days, the
/// hours, the night hours and the estimated pay; the totals, the rest days,
/// the absences and the hours worked on holidays; the change in hours against
/// the previous month. A switch shows the year as a table of its twelve
/// months. It reads the ACTIVE calendar; the definitions are in
/// `month_summary.dart` and in the notes at the bottom of the screen.
class SummaryScreen extends ConsumerStatefulWidget {
  const SummaryScreen({super.key, this.month, this.yearView = false});

  /// Month to open (any day of it); the month on the calendar when null.
  final CivilDate? month;

  /// Opens on the table of the year.
  final bool yearView;

  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

/// What the summary covers: one month, one quarter, one year, or two dates of
/// the user.
enum _Period { month, quarter, year, range }

DateTime _dateTime(CivilDate d) => DateTime(d.year, d.month, d.day);

class _SummaryScreenState extends ConsumerState<SummaryScreen> {
  late CivilDate _month;
  late _Period _period;
  late SummaryRange _range;

  /// The quarter shown by «Trimestre» (P9): T1 to T4 of a civil year.
  late int _quarterYear;
  late Quarter _quarter;

  /// The user already chose the dates of the range (it is no longer just the
  /// month on screen).
  bool _rangeTouched = false;

  /// The last end date had to be shortened to the limit of 366 days.
  bool _rangeClamped = false;
  final _scroll = ScrollController();

  /// The picture of the year is being drawn and shared.
  bool _sharingYear = false;

  bool get _yearView => _period == _Period.year;

  @override
  void initState() {
    super.initState();
    final CivilDate start = widget.month ?? ref.read(visibleMonthProvider);
    _month = start.firstDayOfMonth;
    _period = widget.yearView ? _Period.year : _Period.month;
    _range = SummaryRange.month(_month);
    _quarterYear = _month.year;
    _quarter = _quarterOf(_month);
  }

  static Quarter _quarterOf(CivilDate day) =>
      Quarter.values[(day.month - 1) ~/ 3];

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// New period, new page: back to the top.
  void _toTop() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _setPeriod(_Period period) {
    _toTop();
    setState(() {
      _period = period;
      if (period == _Period.range && !_rangeTouched) {
        _range = SummaryRange.month(_month);
      }
      if (period == _Period.quarter) {
        _quarterYear = _month.year;
        _quarter = _quarterOf(_month);
      }
    });
  }

  void _step(int direction) => setState(() {
    _toTop();
    switch (_period) {
      case _Period.year:
        _month = CivilDate(_month.year + direction, _month.month, 1);
      case _Period.month:
        _month = direction < 0
            ? _month.addDays(-1).firstDayOfMonth
            : _month.addDays(_month.daysInMonth);
      case _Period.quarter:
        final index = _quarter.number - 1 + direction;
        _quarterYear += (index / 4).floor();
        _quarter = Quarter.values[index % 4];
      case _Period.range:
        _range = _range.shifted(direction);
        _rangeTouched = true;
        _rangeClamped = false;
    }
  });

  SummaryRange get _quarterRange =>
      SummaryRange.quarter(_quarterYear, _quarter);

  void _openMonth(CivilDate month) => setState(() {
    _toTop();
    _month = month.firstDayOfMonth;
    _period = _Period.month;
  });

  /// «Compartir como imagen» of Resumen › Año: draws the year picture of the
  /// annual view off-screen and hands it to the share sheet.
  Future<void> _shareYear(int year) async {
    if (_sharingYear) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sharingYear = true);
    try {
      final share = ref.read(yearImageSharerProvider);
      final png = await renderYearImage(
        year: year,
        schedule: ref.read(scheduleControllerProvider).schedule,
        holidays: ref.read(holidaysProvider),
        today: CivilDate.fromDateTime(ref.read(minuteClockProvider)),
        weekStart: ref.read(preferencesProvider).weekStart,
        locale: Locale(l10n.localeName),
      );
      await share(png, 'cuadrante-$year.png', l10n.yearShareSubject(year));
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(appSnackBar(content: Text(l10n.yearShareFailed)));
    } finally {
      if (mounted) setState(() => _sharingYear = false);
    }
  }

  /// Picks one end of the range with the system calendar. The last day can
  /// only be chosen between the first day and 366 days later.
  Future<void> _pickDate({required bool start}) async {
    final current = start ? _range.from : _range.to;
    final l10n = context.l10n;
    final first = start ? DateTime(2000) : _dateTime(_range.from);
    final limit = _dateTime(_range.from.addDays(maxSummaryRangeDays - 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateTime(current),
      firstDate: first,
      lastDate: start ? DateTime(2100) : limit,
      helpText: start ? l10n.summaryRangeFrom : l10n.summaryRangeTo,
    );
    if (picked == null || !mounted) return;
    final day = CivilDate.fromDateTime(picked);
    final result = start ? _range.withFrom(day) : _range.withTo(day);
    setState(() {
      _range = result.range;
      _rangeTouched = true;
      _rangeClamped = result.clamped;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.type;
    final format = AppDateFormat.of(context);
    final sharing = ref.watch(monthSharingProvider);
    final closingDay = ref.watch(summaryClosingDayProvider);
    final periodLabel = switch (_period) {
      _Period.year => '${_month.year}',
      _Period.month => capitalize(
        format.monthYear(DateTime(_month.year, _month.month)),
      ),
      _Period.quarter => l10n.moneyQuarterLabel(_quarter.number, _quarterYear),
      _Period.range => formatRange(format.locale, _range.from, _range.to),
    };

    return Scaffold(
      appBar: ContentAppBar.adaptive(
        context,
        title: Text(l10n.summaryTitle),
        actions: [
          if (_period == _Period.month)
            IconButton(
              key: const ValueKey('summary-share'),
              tooltip: l10n.shareMonthTooltip,
              icon: Icon(AppIcons.share),
              onPressed: sharing
                  ? null
                  : () => shareMonthImage(context, ref, _month),
            ),
          // PDF or CSV of the month or any dates (features/reports).
          if (_period != _Period.year) ReportShareButton(month: _month),
          // The same picture as the annual view's (H-T08-5). «Fechas…» has
          // none: a free range is not a calendar page.
          if (_period == _Period.year)
            IconButton(
              key: const ValueKey('summary-share'),
              tooltip: l10n.yearShare,
              icon: Icon(AppIcons.share),
              onPressed: sharing || _sharingYear
                  ? null
                  : () => _shareYear(_month.year),
            ),
        ],
      ),
      body: PageBody(
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(
            Sp.page,
            Sp.xs,
            Sp.page,
            Sp.section,
          ),
          children: [
            ChoiceGrid.pills(
              sizing: ChoiceGridSizing.wholeLabel,
              maxColumns: 4,
              pills: [
                ChoicePill(
                  expand: true,
                  reserveIcon: true,
                  key: const ValueKey('summary-mode-month'),
                  label: l10n.summaryModeMonth,
                  selected: _period == _Period.month,
                  onTap: () => _setPeriod(_Period.month),
                ),
                ChoicePill(
                  expand: true,
                  reserveIcon: true,
                  key: const ValueKey('summary-mode-quarter'),
                  label: l10n.moneyModeQuarter,
                  selected: _period == _Period.quarter,
                  onTap: () => _setPeriod(_Period.quarter),
                ),
                ChoicePill(
                  expand: true,
                  reserveIcon: true,
                  key: const ValueKey('summary-mode-year'),
                  label: l10n.summaryModeYear,
                  selected: _yearView,
                  onTap: () => _setPeriod(_Period.year),
                ),
                ChoicePill(
                  expand: true,
                  reserveIcon: true,
                  key: const ValueKey('summary-mode-range'),
                  label: l10n.summaryModeRange,
                  selected: _period == _Period.range,
                  onTap: () => _setPeriod(_Period.range),
                ),
              ],
            ),
            const SizedBox(height: Sp.s),
            Row(
              children: [
                IconButton(
                  key: const ValueKey('summary-previous'),
                  tooltip: switch (_period) {
                    _Period.year => l10n.yearPrevious,
                    _Period.month => l10n.calendarPreviousMonth,
                    _Period.quarter => l10n.moneyQuarterPrevious,
                    _Period.range => l10n.summaryRangePrevious,
                  },
                  icon: Icon(AppIcons.chevronLeft),
                  onPressed: () => _step(-1),
                ),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        periodLabel,
                        key: const ValueKey('summary-period'),
                        textAlign: TextAlign.center,
                        style: AppTypography.tabular(type.title),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('summary-next'),
                  tooltip: switch (_period) {
                    _Period.year => l10n.yearNext,
                    _Period.month => l10n.calendarNextMonth,
                    _Period.quarter => l10n.moneyQuarterNext,
                    _Period.range => l10n.summaryRangeNext,
                  },
                  icon: Icon(AppIcons.chevronRight),
                  onPressed: () => _step(1),
                ),
              ],
            ),
            if (_period == _Period.quarter)
              Center(
                child: Text(
                  formatRange(
                    format.locale,
                    _quarterRange.from,
                    _quarterRange.to,
                  ),
                  key: const ValueKey('summary-quarter-dates'),
                  style: type.meta.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
            // With a closing day the month is the payroll month: its dates
            // say which days it counts.
            if (closingDay != null &&
                (_period == _Period.month || _period == _Period.year))
              Center(
                child: Builder(
                  builder: (context) {
                    final range = _period == _Period.month
                        ? payPeriodOf(_month, closingDay)
                        : payYearOf(_month.year, closingDay);
                    return Text(
                      formatRange(format.locale, range.from, range.to),
                      key: const ValueKey('summary-pay-period-dates'),
                      textAlign: TextAlign.center,
                      style: type.meta.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    );
                  },
                ),
              ),
            if (_period == _Period.range) ...[
              const SizedBox(height: Sp.s),
              _RangePicker(
                range: _range,
                clamped: _rangeClamped,
                onPickFrom: () => _pickDate(start: true),
                onPickTo: () => _pickDate(start: false),
              ),
            ],
            const SizedBox(height: Sp.s),
            switch (_period) {
              _Period.year => _YearBody(
                year: _month.year,
                onOpenMonth: _openMonth,
              ),
              _Period.month => _MonthBody(month: _month),
              _Period.quarter => _RangeBody(
                range: _quarterRange,
                previous: SummaryRange.quarter(
                  _quarter == Quarter.first ? _quarterYear - 1 : _quarterYear,
                  Quarter.values[(_quarter.number + 2) % 4],
                ),
                previousName: l10n.moneyQuarterLabel(
                  Quarter.values[(_quarter.number + 2) % 4].number,
                  _quarter == Quarter.first ? _quarterYear - 1 : _quarterYear,
                ),
              ),
              _Period.range => _RangeBody(range: _range),
            },
          ],
        ),
      ),
    );
  }
}

/// Everything under the month switcher.
class _MonthBody extends ConsumerWidget {
  const _MonthBody({required this.month});

  final CivilDate month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final summary = ref.watch(monthSummaryProvider(month));
    if (summary.isEmpty) {
      return _EmptyPeriod(
        title: l10n.summaryEmptyTitle,
        message: l10n.summaryEmptyBody,
      );
    }
    final previous = ref.watch(
      monthSummaryProvider(month.addDays(-1).firstDayOfMonth),
    );
    final previousName = AppDateFormat.of(context)
        .monthName(DateTime(previous.month.year, previous.month.month));
    return _PeriodBody(
      summary: summary,
      previous: previous,
      previousName: previousName,
      period: ref.watch(summaryMonthRangeProvider(month)),
      month: month,
    );
  }
}

/// The year: «¿Cómo voy?» (when the year has shifts) above the table of its
/// twelve months.
class _YearBody extends ConsumerWidget {
  const _YearBody({required this.year, required this.onOpenMonth});

  final int year;
  final ValueChanged<CivilDate> onOpenMonth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final empty = ref.watch(yearTotalsProvider(year).select((t) => t.isEmpty));
    final closingDay = ref.watch(summaryClosingDayProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!empty) ...[
          HowAmIDoingCard(
            span: GoalSpan.year,
            range: payYearOf(year, closingDay),
          ),
          OvertimeCapCard(query: OvertimeCapQuery.year(year)),
          AbsenceSummaryCard(year: year),
          const SizedBox(height: Sp.section),
        ],
        YearTable(year: year, onOpenMonth: onOpenMonth),
      ],
    );
  }
}

/// Everything under the dates of a free range (`docs/paridad.md` A7): the
/// same cards as a month, compared with the same number of days before.
class _RangeBody extends ConsumerWidget {
  const _RangeBody({required this.range, this.previous, this.previousName});

  final SummaryRange range;

  /// The period to compare with when it is not the same number of days
  /// before (the quarter before a quarter), and how it is named.
  final SummaryRange? previous;
  final String? previousName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final summary = ref.watch(rangeSummaryProvider(range));
    if (summary.isEmpty) {
      return _EmptyPeriod(
        title: l10n.summaryRangeEmptyTitle,
        message: l10n.summaryRangeEmptyBody,
      );
    }
    final before = ref.watch(rangeSummaryProvider(previous ?? range.previous));
    return _PeriodBody(
      summary: summary,
      previous: before,
      previousName: previousName ?? l10n.summaryRangePreviousName(range.days),
      period: range,
      isRange: true,
    );
  }
}

class _EmptyPeriod extends ConsumerWidget {
  const _EmptyPeriod({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    key: const ValueKey('summary-empty'),
    padding: const EdgeInsets.symmetric(vertical: Sp.x3),
    child: EmptyState(
      icon: AppIcons.summary,
      illustration: EmptyIllustration(
        kind: EmptyIllustrationKind.calendar,
        shifts: ref.watch(scheduleControllerProvider.select((s) => s.palette)),
      ),
      title: title,
      message: message,
    ),
  );
}

/// The two dates of a free range: «Desde» and «Hasta», each a row that opens
/// the system calendar, the number of days and, when the end had to be
/// shortened, why.
class _RangePicker extends StatelessWidget {
  const _RangePicker({
    required this.range,
    required this.clamped,
    required this.onPickFrom,
    required this.onPickTo,
  });

  final SummaryRange range;
  final bool clamped;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    final locale = AppDateFormat.of(context).locale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _DateRow(
                key: const ValueKey('summary-range-from'),
                label: l10n.summaryRangeFrom,
                value: formatRangeDate(locale, range.from),
                onTap: onPickFrom,
              ),
              Divider(height: 1, thickness: 1, color: colors.border),
              _DateRow(
                key: const ValueKey('summary-range-to'),
                label: l10n.summaryRangeTo,
                value: formatRangeDate(locale, range.to),
                onTap: onPickTo,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Sp.xs, Sp.s, Sp.xs, 0),
          child: Text(
            clamped
                ? l10n.summaryRangeClamped(maxSummaryRangeDays)
                : l10n.summaryRangeDays(range.days, maxSummaryRangeDays),
            key: const ValueKey('summary-range-days'),
            style: type.meta.copyWith(color: colors.textMuted),
          ),
        ),
      ],
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final valueStyle = AppTypography.tabular(
      type.body.copyWith(fontWeight: FontWeight.w700),
    );
    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      label: '$label: $value',
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Sp.touch),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Sp.l,
              vertical: Sp.s,
            ),
            child: Row(
              children: [
                // With large text there is no room side by side: the date
                // goes under its label.
                Expanded(
                  child: context.largeText
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label, style: type.body),
                            Text(value, style: valueStyle),
                          ],
                        )
                      : ValueRow(
                          title: Text(label, style: type.body),
                          value: Text(
                            value,
                            textAlign: TextAlign.end,
                            style: valueStyle,
                          ),
                        ),
                ),
                const SizedBox(width: Sp.s),
                Icon(
                  AppIcons.chevronRight,
                  size: IconSize.inline,
                  color: colors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The cards of a period that has shifts.
class _PeriodBody extends ConsumerWidget {
  const _PeriodBody({
    required this.summary,
    required this.previous,
    required this.previousName,
    required this.period,
    this.month,
    this.isRange = false,
  });

  final MonthSummary summary;
  final MonthSummary previous;

  /// The month on screen (its first day), or `null` for a quarter or free
  /// dates. With a closing day [period] is its payroll month.
  final CivilDate? month;

  /// How the period before is named in the comparison ("septiembre", "los 7
  /// días anteriores").
  final String previousName;

  /// The days of the period (a whole month, or the free range).
  final SummaryRange period;

  /// A free range: the notes do not talk about months.
  final bool isRange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final hours = ref.watch(periodHoursProvider(period));
    final hasGoal = ref.watch(
      hoursGoalProvider.select((goal) => goal.value != null),
    );
    // «Horas en festivo: 0 h / 0 turnos en festivo» says nothing: like the
    // overtime lines, it is left out when both are 0 (H-T08-6 / H-T10-4).
    final showHolidays =
        summary.holidayMinutes > 0 || summary.holidayShifts > 0;
    // B5: what has no data is folded into one line each at the end (the
    // absences when there are none, the pay while no shift has a price).
    final absencesNone = summary.absenceTypes.isEmpty;
    final estimateNone = !summary.hasEarnings && summary.workedMinutes > 0;
    // «Llevas ganado» is about the month that is running now.
    final today = ref.watch(summaryTodayProvider);
    final shownMonth = month;
    final runningMonth =
        shownMonth != null &&
        !today.isBefore(period.from) &&
        !today.isAfter(period.to);
    final closingDay = ref.watch(summaryClosingDayProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HowAmIDoingCard(
          span: isRange ? GoalSpan.range : GoalSpan.month,
          range: period,
        ),
        const SizedBox(height: Sp.card),
        if (shownMonth != null)
          OvertimeCapCard(query: OvertimeCapQuery.month(shownMonth)),
        AbsenceSummaryCard(year: shownMonth?.year ?? period.from.year),
        _BreakdownCard(
          summary: summary,
          previous: previous,
          previousName: previousName,
          showHolidays: showHolidays,
        ),
        if (summary.hasEarnings) ...[
          const SizedBox(height: Sp.card),
          _EstimateCard(summary: summary),
        ],
        if (runningMonth) _EarnedSoFarCard(month: shownMonth),
        for (final group in [
          (l10n.summaryGroupWork, summary.workTypes),
          (l10n.summaryGroupRest, summary.restTypes),
          (l10n.summaryAbsences, summary.absenceTypes),
        ])
          if (group.$2.isNotEmpty) ...[
            const SizedBox(height: Sp.section),
            _TypeGroup(title: group.$1, rows: group.$2),
          ],
        if (absencesNone || estimateNone) ...[
          const SizedBox(height: Sp.section),
          _FoldedCard(
            summary: summary,
            absencesNone: absencesNone,
            estimateNone: estimateNone,
          ),
        ],
        const SizedBox(height: Sp.section),
        _Notes(
          summary: summary,
          range: isRange,
          holidays: showHolidays,
          tense: hours.tense,
          goal: hasGoal,
          closingDay: shownMonth == null ? null : closingDay,
        ),
      ],
    );
  }
}

/// The totals of the period under «¿Cómo voy?»: the change in hours against
/// the previous period, the shifts, the overtime and early leave, the night
/// hours, the rest days, the absences and the hours on holidays.
class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({
    required this.summary,
    required this.previous,
    required this.previousName,
    required this.showHolidays,
  });

  final MonthSummary summary;
  final MonthSummary previous;
  final String previousName;

  /// Whether the line of the hours on holidays shows.
  final bool showHolidays;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    final delta = summary.workedMinutes - previous.workedMinutes;
    final comparison = previous.isEmpty
        ? l10n.summaryDeltaNone(previousName)
        : delta == 0
        ? l10n.summaryDeltaSame(previousName)
        : l10n.summaryDelta(formatSignedHours(l10n, delta), previousName);

    Widget stat(String id, String label, String value, [String? detail]) =>
        SummaryStatRow(id: id, label: label, value: value, detail: detail);

    return AppCard(
      key: const ValueKey('summary-breakdown'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.summaryBreakdownTitle.toUpperCase(),
              style: type.label.copyWith(color: colors.textMuted),
            ),
          ),
          const SizedBox(height: Sp.xs),
          Text(
            comparison,
            key: const ValueKey('summary-delta'),
            style: type.body.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: Sp.m),
          Divider(height: 1, color: colors.border),
          stat(
            'summary-shifts',
            l10n.summaryShiftsWorked,
            '${summary.shiftsWorked}',
            summary.workedDays != summary.shiftsWorked
                ? l10n.summaryDays(summary.workedDays)
                : null,
          ),
          if (summary.overtimeMinutes > 0)
            stat(
              'summary-overtime',
              l10n.summaryOvertime,
              formatSignedHours(l10n, summary.overtimeMinutes),
              summary.overtimeCents > 0
                  ? l10n.summaryExtrasPay(
                      '+${formatMoneyCents(context, summary.overtimeCents)}',
                    )
                  : null,
            ),
          if (summary.earlyLeaveMinutes > 0)
            stat(
              'summary-early-leave',
              l10n.summaryEarlyLeave,
              formatSignedHours(l10n, -summary.earlyLeaveMinutes),
              summary.earlyLeaveCents > 0
                  ? l10n.summaryExtrasPay(
                      '−${formatMoneyCents(context, summary.earlyLeaveCents)}',
                    )
                  : null,
            ),
          stat(
            'summary-night',
            l10n.summaryNightHours,
            formatHours(l10n, summary.nightMinutes),
          ),
          stat('summary-rest', l10n.summaryRestDays, '${summary.restDays}'),
          stat(
            'summary-absences',
            l10n.summaryAbsences,
            '${summary.absenceDays}',
          ),
          if (showHolidays)
            stat(
              'summary-holiday',
              l10n.summaryHolidayHours,
              formatHours(l10n, summary.holidayMinutes),
              l10n.summaryHolidayDetail(summary.holidayShifts),
            ),
        ],
      ),
    );
  }
}

/// The estimated pay (gross and, with a withholding, net), or what is missing
/// to see it.
class _EstimateCard extends ConsumerWidget {
  const _EstimateCard({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    final withholding = ref.watch(withholdingPercentProvider);
    final earnings = summary.earningsCents;
    final unpriced = summary.unpricedTypes;
    return AppCard(
      key: const ValueKey('summary-estimate'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.summaryEstimateTitle.toUpperCase(),
            style: type.label.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: Sp.xs),
          if (earnings != null) ...[
            Semantics(
              label:
                  '${l10n.summaryEstimateTitle}: '
                  '${formatMoneyCents(context, earnings)}. '
                  '${l10n.summaryEstimateNote}',
              excludeSemantics: true,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatMoneyCents(context, earnings),
                  key: const ValueKey('summary-earnings'),
                  style: AppTypography.tabular(type.display),
                ),
              ),
            ),
            const SizedBox(height: Sp.xs),
            Text(
              l10n.summaryEstimateNote,
              style: type.body.copyWith(color: colors.textSecondary),
            ),
            _NetRow(
              idPrefix: 'summary',
              grossCents: earnings,
              withholdingPercent: withholding,
            ),
          ] else
            Text(
              l10n.summaryEstimateNone,
              key: const ValueKey('summary-earnings-none'),
              style: type.body.copyWith(color: colors.textSecondary),
            ),
          if (summary.fixedPlusCount > 0)
            SummaryStatRow(
              id: 'summary-fixed-plus',
              label: l10n.summaryFixedPluses,
              value: formatMoneyCents(context, summary.fixedPlusCents),
              detail: l10n.summaryFixedPlusCount(summary.fixedPlusCount),
            ),
          if (summary.nightPlusCents > 0)
            SummaryStatRow(
              id: 'summary-night-plus',
              label: l10n.summaryNightPlus,
              value: formatMoneyCents(context, summary.nightPlusCents),
            ),
          if (summary.holidayPlusCents > 0)
            SummaryStatRow(
              id: 'summary-holiday-plus',
              label: l10n.summaryHolidayPlus,
              value: formatMoneyCents(context, summary.holidayPlusCents),
            ),
          if (summary.extraAmountCents != 0)
            SummaryStatRow(
              id: 'summary-extra-amount',
              label: l10n.moneyReportExtraTotal,
              value: formatMoneyCents(context, summary.extraAmountCents),
            ),
          if (summary.extrasWithoutRateMinutes > 0) ...[
            const SizedBox(height: Sp.s),
            Text(
              l10n.summaryExtrasNoRate,
              key: const ValueKey('summary-extras-no-rate'),
              style: type.meta.copyWith(color: colors.textSecondary),
            ),
          ],
          if (earnings != null && unpriced.isNotEmpty) ...[
            const SizedBox(height: Sp.s),
            Text(
              l10n.summaryEstimateMissing(
                unpriced.map((t) => t.name).join(', '),
              ),
              key: const ValueKey('summary-earnings-missing'),
              style: type.meta.copyWith(color: colors.textSecondary),
            ),
          ],
          if (unpriced.isNotEmpty) ...[
            const SizedBox(height: Sp.m),
            SecondaryButton(
              key: const ValueKey('summary-rate-action'),
              label: l10n.summaryRateAction,
              onPressed: () => context.push(AppRoutes.shiftTypes),
            ),
          ],
        ],
      ),
    );
  }
}

/// B5: the parts of the summary without data, folded into one line each in
/// a single card. «Ausencias · Ninguna» only says so; «Ingresos estimados ·
/// Sin precios» opens what to do to see the estimate.
class _FoldedCard extends StatefulWidget {
  const _FoldedCard({
    required this.summary,
    required this.absencesNone,
    required this.estimateNone,
  });

  final MonthSummary summary;
  final bool absencesNone;
  final bool estimateNone;

  @override
  State<_FoldedCard> createState() => _FoldedCardState();
}

class _FoldedCardState extends State<_FoldedCard> {
  bool _estimateOpen = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              if (widget.absencesNone)
                _FoldRow(
                  key: const ValueKey('summary-absences-fold'),
                  label: l10n.summaryAbsences,
                  value: l10n.summaryAbsencesNone,
                ),
              if (widget.absencesNone && widget.estimateNone)
                Divider(height: 1, color: colors.border),
              if (widget.estimateNone)
                _FoldRow(
                  key: const ValueKey('summary-estimate-fold'),
                  label: l10n.summaryEstimateTitle,
                  value: l10n.summaryEstimateNoPrices,
                  expanded: _estimateOpen,
                  onTap: () => setState(() => _estimateOpen = !_estimateOpen),
                ),
            ],
          ),
        ),
        if (widget.estimateNone && _estimateOpen) ...[
          const SizedBox(height: Sp.card),
          _EstimateCard(summary: widget.summary),
        ],
      ],
    );
  }
}

/// One folded line: the name, what it holds and, when it opens, a chevron.
class _FoldRow extends StatelessWidget {
  const _FoldRow({
    super.key,
    required this.label,
    required this.value,
    this.expanded,
    this.onTap,
  });

  final String label;
  final String value;

  /// Open or closed; `null` for a line that does not open.
  final bool? expanded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: Sp.touch),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Sp.l, vertical: Sp.m),
        child: ValueRow(
          title: Text(label, style: type.body),
          value: Text(
            value,
            style: type.body.copyWith(color: colors.textMuted),
          ),
          trailing: onTap == null
              ? null
              : RotatedBox(
                  quarterTurns: expanded == true ? 3 : 1,
                  child: Icon(
                    AppIcons.chevronRight,
                    size: IconSize.inline,
                    color: colors.textMuted,
                  ),
                ),
        ),
      ),
    );
    if (onTap == null) return MergeSemantics(child: row);
    // One node: «Ingresos estimados, Sin precios», a button that opens.
    return MergeSemantics(
      child: Semantics(
        button: true,
        expanded: expanded,
        child: InkWell(onTap: onTap, child: row),
      ),
    );
  }
}

/// A titled card with a row per shift type.
class _TypeGroup extends StatelessWidget {
  const _TypeGroup({required this.title, required this.rows});

  final String title;
  final List<ShiftTypeMonth> rows;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: Sp.s),
          child: Semantics(
            header: true,
            child: Text(title, style: context.type.bodyStrong),
          ),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) Divider(height: 1, color: colors.border),
                _TypeRow(row: rows[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TypeRow extends StatelessWidget {
  const _TypeRow({required this.row});

  final ShiftTypeMonth row;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    final shift = row.type;

    final counts = [
      l10n.summaryDays(row.days),
      if (row.count != row.days) l10n.summaryShifts(row.count),
    ].join(' · ');
    final hours = !row.isWork
        ? null
        : !shift.hasTimes
        ? l10n.summaryNoTimes
        : [
            formatHours(l10n, row.paidMinutes),
            if (row.nightMinutes > 0)
              l10n.summaryNightOf(formatHours(l10n, row.nightMinutes)),
          ].join(' · ');
    final pay = row.earningsCents;
    final Widget? payText = pay != null
        ? Text(
            formatMoneyCents(context, pay),
            key: ValueKey('summary-type-pay-${shift.id}'),
            style: AppTypography.tabular(type.bodyStrong),
          )
        : row.missingRate
        ? Text(
            l10n.summaryNoRate,
            key: ValueKey('summary-type-norate-${shift.id}'),
            style: type.meta.copyWith(color: colors.textMuted),
          )
        : null;

    return MergeSemantics(
      child: Padding(
        key: ValueKey('summary-type-${shift.id}'),
        padding: const EdgeInsets.symmetric(horizontal: Sp.m, vertical: Sp.m),
        child: Row(
          children: [
            ShiftBadge(shift: shift),
            const SizedBox(width: Sp.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(shift.name, style: type.bodyStrong),
                  Text(
                    counts,
                    style: AppTypography.tabular(
                      type.meta.copyWith(color: colors.textSecondary),
                    ),
                  ),
                  if (hours != null)
                    Text(
                      hours,
                      key: ValueKey('summary-type-hours-${shift.id}'),
                      style: AppTypography.tabular(
                        type.meta.copyWith(color: colors.textSecondary),
                      ),
                    ),
                  // With large text there is no room at the side.
                  if (context.largeText && payText != null) payText,
                ],
              ),
            ),
            if (!context.largeText && payText != null) ...[
              const SizedBox(width: Sp.s),
              payText,
            ],
          ],
        ),
      ),
    );
  }
}

/// How the numbers are counted, in plain words.
class _Notes extends StatelessWidget {
  const _Notes({
    required this.summary,
    required this.holidays,
    required this.tense,
    this.goal = false,
    this.range = false,
    this.closingDay,
  });

  final MonthSummary summary;

  /// The closing day of the month on screen: its note shows.
  final int? closingDay;

  /// Where the period stands against today: the note on worked and planned
  /// hours shows when there are planned ones.
  final PeriodTense tense;

  /// There is an hours goal: its note shows.
  final bool goal;

  /// The line of the holiday hours shows, so its note does too.
  final bool holidays;

  /// A free range: the first note speaks of days, not of months.
  final bool range;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    final notes = [
      range ? l10n.summaryRangeNoteMidnight : l10n.summaryNoteMidnight,
      l10n.summaryNoteNight,
      l10n.summaryNoteDst,
      if (summary.shiftsWithoutTimes > 0) l10n.summaryNoteNoTimes,
      if (summary.hasExtras) l10n.summaryNoteExtras,
      if (holidays) l10n.summaryNoteHoliday,
      if (tense != PeriodTense.past) l10n.summaryNoteTense,
      if (goal) l10n.summaryNoteGoal,
      if (closingDay case final day?) l10n.summaryNoteClosingDay(day),
    ];
    return AppCard.tinted(
      key: const ValueKey('summary-notes'),
      padding: const EdgeInsets.all(Sp.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(l10n.summaryNotesTitle, style: type.bodyStrong),
          ),
          for (final note in notes) ...[
            const SizedBox(height: Sp.s),
            Text(note, style: type.meta.copyWith(color: colors.textSecondary)),
          ],
        ],
      ),
    );
  }
}

/// The net estimate under a gross figure (P9): the net with the withholding
/// of Ajustes, or, while there is none, a button that sets it.
class _NetRow extends ConsumerWidget {
  const _NetRow({
    required this.idPrefix,
    required this.grossCents,
    required this.withholdingPercent,
  });

  final String idPrefix;
  final int grossCents;
  final int withholdingPercent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (withholdingPercent <= 0) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          key: ValueKey('$idPrefix-net-setup'),
          onPressed: () => editWithholding(context, ref),
          icon: Icon(AbsenceIcons.money, size: IconSize.button),
          label: Text(l10n.moneyNetSetup),
        ),
      );
    }
    return SummaryStatRow(
      id: '$idPrefix-net',
      label: l10n.moneyNet,
      value: formatMoneyCents(
        context,
        netCentsFrom(grossCents, withholdingPercent),
      ),
      detail: l10n.moneyNetNote(withholdingPercent),
    );
  }
}

/// «Llevas ganado» (P9): what the month that is running has paid until now,
/// gross and net: the days that passed and the part of today already worked.
class _EarnedSoFarCard extends ConsumerWidget {
  const _EarnedSoFarCard({required this.month});

  final CivilDate month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    final earned = ref.watch(earnedSoFarProvider(month));
    final gross = earned.grossCents;
    if (gross == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: Sp.card),
      child: AppCard(
        key: const ValueKey('summary-earned'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.moneyEarnedTitle.toUpperCase(),
                style: type.label.copyWith(color: colors.textMuted),
              ),
            ),
            const SizedBox(height: Sp.xs),
            Semantics(
              container: true,
              label:
                  '${l10n.moneyEarnedTitle}: '
                  '${formatMoneyCents(context, gross)}. ${l10n.moneyGross}',
              excludeSemantics: true,
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: Sp.s,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      formatMoneyCents(context, gross),
                      key: const ValueKey('summary-earned-gross'),
                      style: AppTypography.tabular(type.display),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: Sp.xs),
                    child: Text(
                      l10n.moneyGross,
                      style: type.body.copyWith(color: colors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Sp.xs),
            Text(
              l10n.moneyEarnedNote,
              style: type.body.copyWith(color: colors.textSecondary),
            ),
            if (earned.withholdingPercent > 0)
              _NetRow(
                idPrefix: 'summary-earned',
                grossCents: gross,
                withholdingPercent: earned.withholdingPercent,
              ),
          ],
        ),
      ),
    );
  }
}
