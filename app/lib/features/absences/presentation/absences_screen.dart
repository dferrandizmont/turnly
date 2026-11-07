import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/icons/app_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_callout.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/content_app_bar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/page_body.dart';
import '../../../core/widgets/skeleton.dart';
import '../../calendar/application/schedule_controller.dart';
import '../../calendars/application/calendars_controller.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../../summary/presentation/summary_format.dart';
import '../../summary/presentation/summary_stat_row.dart';
import '../application/absence_providers.dart';
import '../domain/absence_status.dart';
import 'absence_balance_sheet.dart';
import 'absence_format.dart';
import 'absence_icons.dart';

/// «Vacaciones y permisos» (`/ajustes/ausencias`, P3): the balances of a
/// year, one card each: the days allowed, the ones carried over from the year
/// before (with the day they expire), the manual adjustments, the ones taken
/// and the ones planned, and in big what is left. The figures come from
/// `absenceBalancesProvider`; this screen only shows them and opens the sheet
/// that edits them.
class AbsencesScreen extends ConsumerStatefulWidget {
  const AbsencesScreen({super.key, this.year});

  /// The year to open on; this year when null.
  final int? year;

  @override
  ConsumerState<AbsencesScreen> createState() => _AbsencesScreenState();
}

class _AbsencesScreenState extends ConsumerState<AbsencesScreen> {
  late int _year =
      widget.year ?? CivilDate.fromDateTime(ref.read(clockProvider)()).year;

  void _step(int by) => setState(() => _year += by);

  Future<void> _edit(
    List<AbsenceBalanceStatus> statuses, {
    AbsenceBalanceStatus? status,
    List<AbsenceBalanceStatus> previous = const [],
  }) {
    final activeId = ref.read(scheduleControllerProvider).calendarId;
    final calendarId = status?.calendarId ?? activeId;
    return showAbsenceBalanceSheet(
      context,
      year: _year,
      status: status,
      calendarId: calendarId,
      nextSortOrder: statuses.length,
      previousBalances: [
        for (final p in previous)
          if (p.calendarId == calendarId) p.balance,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.type;
    final balances = ref.watch(absenceBalancesProvider(_year));
    final calendars = ref.watch(calendarsControllerProvider).value?.calendars;
    // The balances of the year before, to offer continuing their series when
    // a new one is created.
    final previous = ref
        .watch(absenceBalancesProvider(_year - 1))
        .value ?? const <AbsenceBalanceStatus>[];

    return Scaffold(
      appBar: ContentAppBar.adaptive(context, title: Text(l10n.absenceTitle)),
      body: PageBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Sp.page,
            Sp.xs,
            Sp.page,
            Sp.section,
          ),
          children: [
            Row(
              children: [
                IconButton(
                  key: const ValueKey('absence-previous'),
                  tooltip: l10n.absenceYearPrevious,
                  icon: Icon(AppIcons.chevronLeft),
                  onPressed: () => _step(-1),
                ),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$_year',
                        key: const ValueKey('absence-year'),
                        textAlign: TextAlign.center,
                        style: AppTypography.tabular(type.title),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('absence-next'),
                  tooltip: l10n.absenceYearNext,
                  icon: Icon(AppIcons.chevronRight),
                  onPressed: () => _step(1),
                ),
              ],
            ),
            const SizedBox(height: Sp.s),
            ...balances.when(
              loading: () => const [
                SizedBox(
                  height: SkeletonList.placeholderHeight,
                  child: SkeletonList(header: false),
                ),
              ],
              error: (_, _) => [
                ErrorState(
                  compact: true,
                  onRetry: () => ref.invalidate(absenceBalancesProvider(_year)),
                ),
              ],
              data: (statuses) {
                if (statuses.isEmpty) {
                  return [
                    Padding(
                      key: const ValueKey('absence-empty'),
                      padding: const EdgeInsets.symmetric(vertical: Sp.x3),
                      child: EmptyState(
                        icon: AbsenceIcons.vacation,
                        title: l10n.absenceEmptyTitle,
                        message: l10n.absenceEmptyBody,
                        actionLabel: l10n.absenceAdd,
                        primaryAction: true,
                        onAction: () => _edit(statuses, previous: previous),
                      ),
                    ),
                  ];
                }
                final named = (calendars?.length ?? 1) > 1;
                return [
                  for (final status in statuses) ...[
                    _BalanceCard(
                      status: status,
                      calendarName: !named
                          ? null
                          : calendars
                                ?.where((c) => c.id == status.calendarId)
                                .map((c) => c.name)
                                .firstOrNull,
                      onEdit: () => _edit(
                        statuses,
                        status: status,
                        previous: previous,
                      ),
                    ),
                    const SizedBox(height: Sp.card),
                  ],
                  const SizedBox(height: Sp.s),
                  SecondaryButton(
                    key: const ValueKey('absence-add'),
                    icon: AppIcons.add,
                    label: l10n.absenceAdd,
                    onPressed: () => _edit(statuses, previous: previous),
                  ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// One balance: its name, in big what is left and the figures behind it.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.status,
    required this.calendarName,
    required this.onEdit,
  });

  final AbsenceBalanceStatus status;

  /// Shown under the name when the person has more than one calendar.
  final String? calendarName;
  final VoidCallback onEdit;

  String get _id => status.balance.type;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    final locale = l10n.localeName;
    final name = status.displayName;
    final left = status.remainingDays;
    final leftText = absenceNumberText(l10n, left);

    String dateText(CivilDate date) => formatRangeDate(locale, date);

    final carriedDetail = status.carryOverExpiry == null
        ? l10n.absenceCarriedNoExpiry
        : status.carryOverExpired
        ? l10n.absenceCarriedExpired(dateText(status.carryOverExpiry!))
        : l10n.absenceCarriedUntil(dateText(status.carryOverExpiry!));

    Widget warning(AbsenceWarning w) => switch (w) {
      CarryOverExpiring() => AppCallout(
        key: ValueKey('absence-warning-expiring-$_id'),
        icon: AbsenceIcons.warning,
        title: l10n.absenceWarnExpiring(
          absenceDaysText(l10n, w.days),
          dateText(w.expiryDate),
        ),
      ),
      PlannedExceedsAvailable() => AppCallout(
        key: ValueKey('absence-warning-planned-$_id'),
        icon: AbsenceIcons.warning,
        tone: TonePair(colors.dangerContainer, colors.danger),
        title: l10n.absenceWarnPlanned(
          absenceDaysText(l10n, w.plannedDays),
          absenceSignedLeft(l10n, w.leftDays),
        ),
      ),
    };

    return AppCard(
      key: ValueKey('absence-card-$_id'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        name.toUpperCase(),
                        key: ValueKey('absence-name-$_id'),
                        style: type.label.copyWith(color: colors.textMuted),
                      ),
                    ),
                    if (calendarName != null)
                      Text(
                        calendarName!,
                        style: type.meta.copyWith(color: colors.textSecondary),
                      ),
                  ],
                ),
              ),
              IconButton(
                key: ValueKey('absence-edit-$_id'),
                tooltip: l10n.absenceEditTooltip(name),
                icon: Icon(AppIcons.edit, size: IconSize.inline),
                onPressed: onEdit,
              ),
            ],
          ),
          const SizedBox(height: Sp.xs),
          Semantics(
            container: true,
            label: l10n.absenceLeftSemantics(name, absenceDaysText(l10n, left)),
            excludeSemantics: true,
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: Sp.s,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    leftText,
                    key: ValueKey('absence-left-$_id'),
                    style: AppTypography.tabular(type.display),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: Sp.xs),
                  child: Text(
                    l10n.absenceLeftCaption(left),
                    style: type.body.copyWith(color: colors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Sp.m),
          Divider(height: 1, color: colors.border),
          SummaryStatRow(
            id: 'absence-allowed-$_id',
            label: l10n.absenceAllowed,
            value: absenceDaysText(l10n, status.allowedDays),
            detail: status.balance.workingDaysOnly
                ? l10n.absenceWorkingDaysNote
                : null,
          ),
          if (status.balance.carryOver || status.carriedDays > 0)
            SummaryStatRow(
              id: 'absence-carried-$_id',
              label: l10n.absenceCarried,
              value: absenceDaysText(l10n, status.carriedInForceDays),
              detail: carriedDetail,
            ),
          if (status.adjustmentDays != 0)
            SummaryStatRow(
              id: 'absence-adjustment-$_id',
              label: l10n.absenceAdjustment,
              value: absenceSignedDaysText(l10n, status.adjustmentDays),
            ),
          SummaryStatRow(
            id: 'absence-enjoyed-$_id',
            label: l10n.absenceEnjoyed,
            value: absenceDaysText(l10n, status.enjoyedDays),
          ),
          SummaryStatRow(
            id: 'absence-planned-$_id',
            label: l10n.absencePlanned,
            value: absenceDaysText(l10n, status.plannedDays),
          ),
          for (final w in status.warnings) ...[
            const SizedBox(height: Sp.s),
            warning(w),
          ],
        ],
      ),
    );
  }
}
