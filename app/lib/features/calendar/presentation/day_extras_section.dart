import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/money.dart';
import '../../../core/icons/app_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/value_row.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../../summary/application/summary_providers.dart';
import '../../summary/domain/month_summary.dart';
import '../../summary/presentation/summary_format.dart';
import '../application/schedule_controller.dart';
import 'overtime_format.dart';
import 'overtime_sheet.dart';

/// «Horas extra / Salí antes» of the day detail (docs/paridad.md, A6): the
/// day's blocks of extra hours (schema v7: type, schedule, length and what
/// they earn; tapping one edits it in [OvertimeBlockSheet]), «Añadir horas
/// extra», the total of the day («Total del día: 14 h · 217,50 €»: shifts +
/// extras − early leave, the money only with prices) and the early leave,
/// in steps of [step] minutes. The early leave is written when the user
/// stops tapping ([settle]) or the sheet closes, so a run of taps is ONE
/// undo step; 0 clears it. The summary adds the extra hours to the hours
/// worked and subtracts the early leave (docs/motor-de-turnos.md).
class DayExtrasSection extends ConsumerStatefulWidget {
  const DayExtrasSection({super.key, required this.date});

  final CivilDate date;

  /// Minutes added or removed by each tap.
  static const int step = 15;

  /// Quiet time after the last tap before the value is written.
  static const Duration settle = Duration(milliseconds: 600);

  @override
  ConsumerState<DayExtrasSection> createState() => DayExtrasSectionState();
}

class DayExtrasSectionState extends ConsumerState<DayExtrasSection> {
  late final ScheduleController _schedule;
  Timer? _timer;

  // The early leave the user has set and is not written yet.
  int? _pendingEarlyLeave;

  CivilDate get _date => widget.date;

  @override
  void initState() {
    super.initState();
    _schedule = ref.read(scheduleControllerProvider.notifier);
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_pendingEarlyLeave case final earlyLeave?) {
      final date = _date;
      final schedule = _schedule;
      // The tree is locked while it is being disposed.
      scheduleMicrotask(
        () => schedule.setDayExtras(date, earlyLeaveMinutes: earlyLeave),
      );
    }
    super.dispose();
  }

  void _commit() {
    _timer?.cancel();
    final earlyLeave = _pendingEarlyLeave;
    if (earlyLeave == null) return;
    _pendingEarlyLeave = null;
    _schedule.setDayExtras(_date, earlyLeaveMinutes: earlyLeave);
  }

  /// Finish the debounce before a parent action snapshots or clears the day.
  /// Once cleared, disposal must never reinsert the previous draft.
  void commitPending() => _commit();

  void _changeEarlyLeave({required int by, required int now}) {
    final next = (now + by).clamp(0, maxDayExtraMinutes);
    setState(() => _pendingEarlyLeave = next);
    _timer?.cancel();
    _timer = Timer(DayExtrasSection.settle, _commit);
  }

  void _openBlock({OvertimeBlock? block}) {
    // The early leave being tapped is one step, the block another.
    _commit();
    editOvertimeBlock(context, _date, block: block);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    final schedule = ref.watch(
      scheduleControllerProvider.select((s) => s.schedule),
    );
    final entry = schedule.entries[_date];
    final day = schedule.resolve(_date);
    final earlyLeave = _pendingEarlyLeave ?? entry?.earlyLeaveMinutes ?? 0;
    // While the user is still tapping the early leave, the total follows.
    final counted = _pendingEarlyLeave == null
        ? schedule
        : schedule.copyWith(
            entries: {
              ...schedule.entries,
              _date: (entry ?? DayEntry(date: _date)).copyWith(
                earlyLeaveMinutes: earlyLeave,
              ),
            },
          );
    final summary = summarizeRange(
      counted,
      _date,
      _date,
      holidays: ref.watch(summaryHolidaysProvider),
    );
    final hours = formatHours(l10n, summary.workedMinutes);
    final money = summary.earningsCents;

    return Column(
      key: const ValueKey('day-extras'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Sp.l),
        Semantics(
          header: true,
          child: Text(
            l10n.dayExtrasTitle.toUpperCase(),
            style: type.label.copyWith(color: colors.textMuted),
          ),
        ),
        const SizedBox(height: Sp.xs),
        for (final block in day.overtimeBlocks)
          if (schedule.overtimeTypeById(block.typeId) case final t?)
            _BlockRow(
              block: block,
              type: t,
              nextDay: overtimeOnNextDay(block, day),
              amountCents: overtimeAmountCents(
                block,
                t,
                day,
                schedule.baseHourlyRateCents,
              ),
              onTap: () => _openBlock(block: block),
            ),
        const SizedBox(height: Sp.s),
        SecondaryButton(
          key: const ValueKey('day-add-overtime'),
          icon: AppIcons.add,
          label: l10n.overtimeSheetAdd,
          onPressed: _openBlock,
        ),
        if (summary.workedMinutes > 0 || money != null)
          Padding(
            padding: const EdgeInsets.only(top: Sp.m, bottom: Sp.xs),
            child: Text(
              money == null
                  ? l10n.overtimeDayTotal(hours)
                  : l10n.overtimeDayTotalMoney(
                      hours,
                      formatMoneyCents(context, money),
                    ),
              key: const ValueKey('day-total'),
              style: type.bodyStrong,
            ),
          ),
        _ExtrasRow(
          id: 'early',
          label: l10n.dayExtrasEarlyLeave,
          minutes: earlyLeave,
          onChange: (by) => _changeEarlyLeave(by: by, now: earlyLeave),
        ),
        Text(l10n.dayExtrasHelper, style: type.meta),
      ],
    );
  }
}

/// One block of extra hours: its colour and type, and under it the schedule,
/// the paid length, what it earns and its note. Tapping it edits it.
class _BlockRow extends StatelessWidget {
  const _BlockRow({
    required this.block,
    required this.type,
    required this.nextDay,
    required this.amountCents,
    required this.onTap,
  });

  final OvertimeBlock block;
  final OvertimeType type;

  /// The morning after a shift that ends past midnight.
  final bool nextDay;
  final int? amountCents;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.type;
    final colors = context.colors;
    final detail = [
      overtimeRange(context, block),
      if (nextDay)
        l10n.overtimeOnNextDay
      else if (block.crossesMidnight)
        l10n.overtimeNextDay,
      if (amountCents case final cents?) formatMoneyCents(context, cents),
    ].join(' · ');
    final note = block.note;
    return Semantics(
      button: true,
      child: InkWell(
        key: ValueKey('day-overtime-${block.id}'),
        borderRadius: BorderRadius.circular(Rad.inner),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Sp.touch),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Sp.s),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: Sp.hair),
                  child: OvertimeTypeSwatch(colorValue: type.colorValue),
                ),
                const SizedBox(width: Sp.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ValueRow(
                        title: Text(
                          overtimeTypeName(l10n, type),
                          style: text.bodyStrong,
                        ),
                        value: Text(
                          formatHours(l10n, block.paidMinutes),
                          key: ValueKey('day-overtime-duration-${block.id}'),
                          style: text.bodyStrong,
                        ),
                      ),
                      Text(
                        detail,
                        style: text.body.copyWith(color: colors.textSecondary),
                      ),
                      if (note != null)
                        Text(
                          note,
                          style: text.meta.copyWith(color: colors.textMuted),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: Sp.s),
                ExcludeSemantics(
                  child: Icon(
                    AppIcons.edit,
                    size: IconSize.inline,
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One label with a «-», its value and a «+».
class _ExtrasRow extends StatelessWidget {
  const _ExtrasRow({
    required this.id,
    required this.label,
    required this.minutes,
    required this.onChange,
  });

  final String id;
  final String label;
  final int minutes;
  final ValueChanged<int> onChange;

  /// Room for «1 h 45 min» at the normal text size.
  static const double _valueWidth = Sp.x4 + Sp.x3 + Sp.s;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.type;
    final value = minutes == 0
        ? l10n.dayExtrasNone
        : formatHours(l10n, minutes);
    final stepper = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: ValueKey('day-$id-less'),
          tooltip: l10n.dayExtrasLess(label),
          icon: Icon(AppIcons.minus),
          onPressed: minutes == 0
              ? null
              : () => onChange(-DayExtrasSection.step),
        ),
        Flexible(
          child: Semantics(
            container: true,
            liveRegion: true,
            label: l10n.dayExtrasValue(label, value),
            excludeSemantics: true,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: _valueWidth),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  key: ValueKey('day-$id-value'),
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: AppTypography.tabular(
                    type.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),
        ),
        IconButton(
          key: ValueKey('day-$id-more'),
          tooltip: l10n.dayExtrasMore(label),
          icon: Icon(AppIcons.add),
          onPressed: minutes >= maxDayExtraMinutes
              ? null
              : () => onChange(DayExtrasSection.step),
        ),
      ],
    );
    // With big text the label gets its own line instead of being squeezed.
    final stacked = MediaQuery.textScalerOf(context).scale(14) >= 14 * 1.2;
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: Sp.s),
            child: Text(label, style: type.body),
          ),
          Align(alignment: Alignment.centerLeft, child: stepper),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: Text(label, style: type.body)),
        stepper,
      ],
    );
  }
}
