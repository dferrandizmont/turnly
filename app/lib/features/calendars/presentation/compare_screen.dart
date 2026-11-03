import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/app_date_format.dart';
import '../../../core/icons/app_icons.dart';
import '../../../core/icons/parity_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../core/router.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/content_app_bar.dart';
import '../../../core/widgets/empty_illustration.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/page_body.dart';
import '../../calendar/presentation/shift_format.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../application/calendars_controller.dart';
import '../application/compare_providers.dart';
import '../domain/calendar.dart';
import '../domain/calendar_comparison.dart';
import 'calendar_dot.dart';
import 'compare_calendars_sheet.dart';
import 'compare_table.dart';

/// «Comparar calendarios» (`/comparar`, `docs/paridad.md` A4, P12): from two
/// to six calendars of the user side by side, a row each and a column per
/// day, with the days everybody is free marked, how many they are, the free
/// weekends and the list of those dates.
///
/// Read-only: it uses the [Schedule] of each calendar and never changes the
/// one on screen. Free for everyone.
///
/// Opens on the calendar on screen and the next one; [firstId], [secondId]
/// and [month] come from the link (`?a=&b=&mes=2026-10`).
class CompareScreen extends ConsumerStatefulWidget {
  const CompareScreen({super.key, this.firstId, this.secondId, this.month});

  final String? firstId;
  final String? secondId;

  /// Month to open (any day of it); the current month when null.
  final CivilDate? month;

  @override
  ConsumerState<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends ConsumerState<CompareScreen> {
  /// The ids of the calendars being compared, in the order of the rows. Empty
  /// until the person picks them (or until the link does).
  late List<String> _picked;

  late CivilDate _month;

  @override
  void initState() {
    super.initState();
    _picked = [
      for (final id in [widget.firstId, widget.secondId])
        if (id != null && id.isNotEmpty) id,
    ];
    final CivilDate start =
        widget.month ?? CivilDate.fromDateTime(ref.read(clockProvider)());
    _month = start.firstDayOfMonth;
  }

  void _step(int direction) => setState(() {
    _month = direction < 0
        ? _month.addDays(-1).firstDayOfMonth
        : _month.addDays(_month.daysInMonth);
  });

  /// Puts the second calendar first and the first one second.
  void _swap(List<Calendar> compared) =>
      setState(() => _picked = [for (final c in compared.reversed) c.id]);

  /// Opens the sheet that picks the calendars to compare.
  Future<void> _choose(
    List<Calendar> all,
    List<Calendar> compared,
  ) async {
    final ids = await showCompareCalendarsSheet(
      context,
      calendars: all,
      selectedIds: [for (final c in compared) c.id],
    );
    if (ids == null || !mounted) return;
    setState(() => _picked = ids);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final calendarsState = ref.watch(calendarsControllerProvider);
    final all = calendarsState.value?.calendars ?? const <Calendar>[];
    // The calendars of the rows: the ones picked, and (with fewer than two
    // picked) the calendar on screen and the ones that follow it.
    final compared = ref.watch(
      comparedCalendarsProvider(ComparedSelection(_picked)),
    );
    final canCompare = all.length >= 2 && compared.length >= 2;
    final request = CompareRequest.month(calendars: compared, month: _month);
    final comparison = ref.watch(multiComparisonProvider(request));

    return Scaffold(
      appBar: ContentAppBar.adaptive(
        context,
        title: Text(l10n.compareTitle),
        actions: [
          // Swapping only makes sense with two calendars: with more, the rows
          // are picked in the sheet.
          if (canCompare && compared.length == 2)
            IconButton(
              key: const ValueKey('compare-swap'),
              tooltip: l10n.compareSwap,
              icon: Icon(ParityIcons.swap),
              onPressed: () => _swap(compared),
            ),
        ],
      ),
      body: PageBody(
        child: calendarsState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => ErrorState(
            message: l10n.compareLoadFailed,
            onRetry: () => ref.invalidate(calendarsControllerProvider),
          ),
          data: (data) {
            if (!canCompare) return const _NeedTwoCalendars();
            return _Comparison(
              calendars: data.calendars,
              compared: compared,
              month: _month,
              comparison: comparison,
              onStep: _step,
              onChoose: () => _choose(data.calendars, compared),
              onRetry: () => ref.invalidate(multiComparisonProvider(request)),
            );
          },
        ),
      ),
    );
  }
}

/// Fewer than two calendars: nothing to compare, and the way to make one.
class _NeedTwoCalendars extends StatelessWidget {
  const _NeedTwoCalendars();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return EmptyState(
      key: const ValueKey('compare-need-two'),
      icon: ParityIcons.compare,
      illustration: const EmptyIllustration(
        kind: EmptyIllustrationKind.calendar,
      ),
      title: l10n.compareNeedTwoTitle,
      message: l10n.compareNeedTwoBody,
      actionLabel: l10n.calendarsAdd,
      primaryAction: true,
      onAction: () => context.pushReplacement(AppRoutes.settingsCalendars),
    );
  }
}

class _Comparison extends ConsumerWidget {
  const _Comparison({
    required this.calendars,
    required this.compared,
    required this.month,
    required this.comparison,
    required this.onStep,
    required this.onChoose,
    required this.onRetry,
  });

  final List<Calendar> calendars;
  final List<Calendar> compared;
  final CivilDate month;
  final AsyncValue<MultiComparison> comparison;
  final void Function(int direction) onStep;
  final VoidCallback onChoose;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final type = context.type;
    final colors = context.colors;
    final format = AppDateFormat.of(context);
    final today = CivilDate.fromDateTime(ref.watch(minuteClockProvider));
    final title = capitalize(
      format.monthYear(DateTime(month.year, month.month)),
    );

    return ListView(
      key: const ValueKey('compare-list'),
      padding: const EdgeInsets.fromLTRB(Sp.page, Sp.xs, Sp.page, Sp.section),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Sp.xs, 0, Sp.xs, Sp.m),
          child: Text(
            l10n.compareIntro,
            style: type.meta.copyWith(color: colors.textMuted),
          ),
        ),
        _SelectorCard(calendars: compared, onChoose: onChoose),
        const SizedBox(height: Sp.s),
        Row(
          children: [
            IconButton(
              key: const ValueKey('compare-previous'),
              tooltip: l10n.calendarPreviousMonth,
              icon: Icon(AppIcons.chevronLeft),
              onPressed: () => onStep(-1),
            ),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  key: const ValueKey('compare-month'),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.tabular(type.title),
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('compare-next'),
              tooltip: l10n.calendarNextMonth,
              icon: Icon(AppIcons.chevronRight),
              onPressed: () => onStep(1),
            ),
          ],
        ),
        if (comparison.hasError)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Sp.x3),
            child: ErrorState(
              compact: true,
              message: l10n.compareLoadFailed,
              onRetry: onRetry,
            ),
          )
        else if (!comparison.hasValue)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: Sp.x3),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          CompareTable(
            comparison: comparison.requireValue,
            today: today,
          ),
          const SizedBox(height: Sp.l),
          _Summary(comparison: comparison.requireValue),
        ],
      ],
    );
  }
}

/// The calendars being compared, with their colours, and the way to change
/// them: from two to six.
class _SelectorCard extends StatelessWidget {
  const _SelectorCard({required this.calendars, required this.onChoose});

  final List<Calendar> calendars;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    return AppCard(
      key: const ValueKey('compare-selector'),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.l, Sp.m, Sp.xs, Sp.s),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.compareSelectorTitle,
                      style: type.label.copyWith(color: colors.textMuted),
                    ),
                  ),
                ),
                TextButton(
                  key: const ValueKey('compare-change'),
                  onPressed: onChoose,
                  child: Text(l10n.compareSelectorAction),
                ),
              ],
            ),
          ),
          for (final calendar in calendars)
            _CalendarRow(calendar: calendar),
          const SizedBox(height: Sp.xs),
        ],
      ),
    );
  }
}

/// One of the calendars being compared: its colour and its name.
class _CalendarRow extends StatelessWidget {
  const _CalendarRow({required this.calendar});

  final Calendar calendar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Padding(
      key: ValueKey('compare-calendar-${calendar.id}'),
      padding: const EdgeInsets.symmetric(horizontal: Sp.l, vertical: Sp.xs),
      child: Row(
        children: [
          CalendarDot(colorValue: calendar.colorValue),
          const SizedBox(width: Sp.m),
          Expanded(
            child: Text(
              calendar.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: type.body.copyWith(color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// «X días libres en común este mes», the free weekends, what the marks mean
/// and the list of those dates.
class _Summary extends StatelessWidget {
  const _Summary({required this.comparison});

  final MultiComparison comparison;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    final format = AppDateFormat.of(context);
    final count = comparison.commonFreeCount;
    final unrecorded = comparison.unrecordedCount;
    final weekends = comparison.commonFreeWeekends;
    // The weekend days that are not part of a whole free weekend: a free
    // Saturday whose Sunday somebody works.
    final whole = {for (final w in weekends) ...[w.saturday, w.sunday]};
    final halfWeekends = [
      for (final date in comparison.commonFreeWeekendDays)
        if (!whole.contains(date)) date,
    ];
    final markColor = colors.isDark ? colors.highlight : colors.accent;
    final onMarkColor = colors.isDark ? colors.onHighlight : colors.onAccent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          key: const ValueKey('compare-summary'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: markColor,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(Sp.hair),
                      child: Icon(
                        AppIcons.check,
                        size: IconSize.inline,
                        color: onMarkColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: Sp.s),
                  Expanded(
                    child: Text(
                      l10n.compareLegendFree.toUpperCase(),
                      style: type.label.copyWith(color: colors.textMuted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Sp.s),
              Semantics(
                liveRegion: true,
                child: Text(
                  l10n.compareCount(count),
                  key: const ValueKey('compare-count'),
                  style: type.title,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(height: Sp.m),
                Wrap(
                  key: const ValueKey('compare-free-list'),
                  spacing: Sp.s,
                  runSpacing: Sp.s,
                  children: [
                    for (final date in comparison.commonFreeDays)
                      _DatePill(
                        key: ValueKey('compare-free-date-${date.toIso()}'),
                        label: format.shortDate(
                          DateTime(date.year, date.month, date.day),
                        ),
                        spoken: format.weekdayDayMonth(
                          DateTime(date.year, date.month, date.day),
                        ),
                      ),
                  ],
                ),
              ],
              if (weekends.isNotEmpty) ...[
                const SizedBox(height: Sp.l),
                Semantics(
                  header: true,
                  child: Text(
                    l10n.compareWeekendTitle.toUpperCase(),
                    style: type.label.copyWith(color: colors.textMuted),
                  ),
                ),
                const SizedBox(height: Sp.xs),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    l10n.compareWeekendCount(weekends.length),
                    key: const ValueKey('compare-weekend-count'),
                    style: type.body,
                  ),
                ),
                const SizedBox(height: Sp.s),
                Wrap(
                  key: const ValueKey('compare-weekend-list'),
                  spacing: Sp.s,
                  runSpacing: Sp.s,
                  children: [
                    for (final weekend in weekends)
                      _DatePill(
                        key: ValueKey(
                          'compare-weekend-${weekend.saturday.toIso()}',
                        ),
                        label: format.shortDateRange(
                          DateTime(
                            weekend.saturday.year,
                            weekend.saturday.month,
                            weekend.saturday.day,
                          ),
                          DateTime(
                            weekend.sunday.year,
                            weekend.sunday.month,
                            weekend.sunday.day,
                          ),
                        ),
                        spoken: l10n.compareWeekendSpoken(
                          format.weekdayDayMonth(
                            DateTime(
                              weekend.saturday.year,
                              weekend.saturday.month,
                              weekend.saturday.day,
                            ),
                          ),
                          format.weekdayDayMonth(
                            DateTime(
                              weekend.sunday.year,
                              weekend.sunday.month,
                              weekend.sunday.day,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              if (halfWeekends.isNotEmpty) ...[
                const SizedBox(height: Sp.m),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    l10n.compareWeekendDaysCount(halfWeekends.length),
                    key: const ValueKey('compare-weekend-days-count'),
                    style: type.body.copyWith(color: colors.textSecondary),
                  ),
                ),
                const SizedBox(height: Sp.s),
                Wrap(
                  key: const ValueKey('compare-weekend-days-list'),
                  spacing: Sp.s,
                  runSpacing: Sp.s,
                  children: [
                    for (final date in halfWeekends)
                      _DatePill(
                        key: ValueKey(
                          'compare-weekend-day-${date.toIso()}',
                        ),
                        label: format.shortDate(
                          DateTime(date.year, date.month, date.day),
                        ),
                        spoken: format.weekdayDayMonth(
                          DateTime(date.year, date.month, date.day),
                        ),
                      ),
                  ],
                ),
              ],
              if (unrecorded > 0) ...[
                const SizedBox(height: Sp.l),
                Row(
                  key: const ValueKey('compare-unrecorded'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const UnrecordedMark(size: IconSize.inline),
                    const SizedBox(width: Sp.s),
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          l10n.compareUnrecordedCount(unrecorded),
                          key: const ValueKey('compare-unrecorded-count'),
                          style: type.body.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: Sp.card),
        AppCard(
          child: Text(
            l10n.compareNote,
            style: type.meta.copyWith(color: colors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill({super.key, required this.label, required this.spoken});

  final String label;
  final String spoken;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: spoken,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: Rad.pill,
          border: Border.all(color: colors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Sp.m,
            vertical: Sp.xs + Sp.hair,
          ),
          child: Text(
            label,
            style: AppTypography.tabular(
              context.type.caption.copyWith(color: colors.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}
