import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/app_date_format.dart';
import '../../../core/icons/app_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../core/theme/theme_context.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../../settings/application/preferences_controller.dart';
import '../application/month_presentation.dart';
import '../application/open_day.dart';
import '../application/schedule_controller.dart';
import '../application/selection_controller.dart';
import '../application/visible_month.dart';
import 'day_cell.dart';
import 'month_grid.dart';
import 'shift_format.dart';

/// Whether the List is suggested for the visible month on a panel
/// [panelWidth] wide (`docs/diseno.md`, «Mes: Cuadrícula / Lista»): cells
/// under 48 dp, a code or time that the grid would shrink or drop, several
/// shifts on a day, or text at 150 % or more. It is a suggestion, never a
/// change of presentation.
///
/// [inputs] come from [watchListRecommendationInputs], read in the build
/// method (the measure itself runs inside layout builders).
bool monthListRecommended(
  BuildContext context,
  ListRecommendationInputs inputs,
  double panelWidth,
) {
  final (:schedule, :month, :weekNumbers) = inputs;
  final width =
      (panelWidth -
          2 * (Sp.l - Sp.cellGap / 2) -
          (weekNumbers ? MonthGrid.weekNumberWidth : 0)) /
      7;
  final scaler = MediaQuery.textScalerOf(context);
  final hour12 = AppDateFormat.of(context).hour12;
  final codeStyle = context.type.cellCode;
  final timeStyle = context.type.cellTime;
  final contentWidth = width - Sp.cellGap - 2 * cellContentInset;
  var reduced = false;
  for (final day in schedule.resolveRange(month, month.lastDayOfMonth)) {
    for (final shift in day.shifts) {
      final time = shift.compactTimeRange(hour12: hour12);
      if (day.shifts.length > 1 ||
          textWidth(shift.code, codeStyle, scaler) > contentWidth ||
          (time != null && textWidth(time, timeStyle, scaler) > contentWidth)) {
        reduced = true;
        break;
      }
    }
    if (reduced) break;
  }
  return width < Sp.touch ||
      reduced ||
      scaler.scale(codeStyle.fontSize!) / codeStyle.fontSize! >= 1.5 ||
      scaler.scale(timeStyle.fontSize!) / timeStyle.fontSize! >= 1.5;
}

/// What [monthListRecommended] depends on.
typedef ListRecommendationInputs = ({
  Schedule schedule,
  CivilDate month,
  bool weekNumbers,
});

ListRecommendationInputs watchListRecommendationInputs(WidgetRef ref) => (
  schedule: ref.watch(scheduleControllerProvider.select((s) => s.schedule)),
  month: ref.watch(visibleMonthProvider),
  weekNumbers: ref.watch(preferencesProvider.select((p) => p.weekNumbers)),
);

/// «Cuadrícula | Lista» as a small segmented control in the row of the month
/// (B1, option 1A of the 31-oct canvas): smaller text than before and no
/// icons, but each half keeps a 48 dp touch target (the track is drawn
/// thinner inside it). When even the two labels do not fit side by side
/// (very large text) they stack.
///
/// [panelWidth] is the width of the month panel, for the recommendation dot;
/// without it the control measures the room it is given.
class MonthPresentationControl extends ConsumerWidget {
  const MonthPresentationControl({super.key, this.panelWidth});

  final double? panelWidth;

  /// What the track leaves above and below it inside the 48 dp target.
  static const double _trackInset = Sp.s - Sp.hair;

  /// The labels: measured in the bolder weight, so selecting a half never
  /// makes the control wider.
  static TextStyle _labelStyle(BuildContext context) =>
      context.type.meta.copyWith(fontWeight: FontWeight.w800);

  /// The width of one half for [label] (without the minimum target).
  static double _segmentWidth(BuildContext context, String label) =>
      textWidth(label, _labelStyle(context), MediaQuery.textScalerOf(context)) +
      2 * Sp.s +
      2 * Sp.hair +
      2;

  /// The width the control needs in one row, with the dot of the
  /// recommendation when [recommended]; never less than two touch targets.
  static double widthFor(BuildContext context, {required bool recommended}) {
    final l10n = context.l10n;
    return math.max(
          Sp.touch,
          _segmentWidth(context, l10n.monthPresentationGrid),
        ) +
        math.max(
          Sp.touch,
          _segmentWidth(context, l10n.monthPresentationList) +
              (recommended ? Sp.xs + Sp.cellSegmentDot : 0),
        ) +
        2;
  }

  void _choose(BuildContext context, WidgetRef ref, MonthPresentation value) {
    if (ref.read(monthPresentationProvider) == value) return;
    final month = ref.read(visibleMonthProvider);
    final today = CivilDate.fromDateTime(ref.read(clockProvider)());
    final remembered =
        ref.read(monthDayFocusProvider).date ??
        ref.read(openDayProvider) ??
        ref.read(selectionControllerProvider).first;
    final date = remembered != null && remembered.firstDayOfMonth == month
        ? remembered
        : today.firstDayOfMonth == month
        ? today
        : month;
    ref.read(monthDayFocusProvider.notifier).request(date);
    ref.read(monthPresentationProvider.notifier).choose(value);
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        value == MonthPresentation.list
            ? context.l10n.monthListSelected
            : context.l10n.monthGridSelected,
        Directionality.of(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presentation = ref.watch(monthPresentationProvider);
    final inputs = watchListRecommendationInputs(ref);
    final l10n = context.l10n;
    return LayoutBuilder(
      builder: (context, box) {
        final panel =
            panelWidth ??
            (box.maxWidth.isFinite
                ? box.maxWidth
                : MediaQuery.sizeOf(context).width);
        final recommended = monthListRecommended(context, inputs, panel);
        final inOneRow =
            !box.maxWidth.isFinite ||
            widthFor(context, recommended: recommended) <= box.maxWidth;
        final colors = context.colors;
        final segments = [
          _Segment(
            key: const ValueKey('month-presentation-grid'),
            label: l10n.monthPresentationGrid,
            selected: presentation == MonthPresentation.grid,
            onTap: () => _choose(context, ref, MonthPresentation.grid),
          ),
          Tooltip(
            message: recommended
                ? l10n.monthListRecommended
                : l10n.monthPresentationList,
            child: _Segment(
              key: const ValueKey('month-presentation-list'),
              label: l10n.monthPresentationList,
              selected: presentation == MonthPresentation.list,
              // A dot, not a colour change of the whole control: the list
              // is suggested, never imposed.
              badge: recommended
                  ? Container(
                      key: const ValueKey('month-list-recommendation'),
                      width: Sp.cellSegmentDot,
                      height: Sp.cellSegmentDot,
                      decoration: BoxDecoration(
                        color: colors.accent,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
              onTap: () => _choose(context, ref, MonthPresentation.list),
            ),
          ),
        ];
        return Stack(
          children: [
            // The track, thinner than the touch targets on top of it.
            Positioned.fill(
              top: _trackInset,
              bottom: _trackInset,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(Rad.inner),
                  border: Border.all(color: colors.border),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: inOneRow
                  ? Row(mainAxisSize: MainAxisSize.min, children: segments)
                  : IntrinsicWidth(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: segments,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// One half of the grid/list switch: the selected half sits on a raised
/// thumb with a bolder label (never colour alone), like a native segmented
/// control on iOS and Android. The whole 48 dp rectangle is the target.
class _Segment extends StatelessWidget {
  const _Segment({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ink = selected ? colors.textPrimary : colors.textSecondary;
    final radius = BorderRadius.circular(Rad.chipSmall);
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      excludeSemantics: true,
      label: label,
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: Sp.touch,
              minWidth: Sp.touch,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Sp.hair,
                vertical: MonthPresentationControl._trackInset + Sp.hair,
              ),
              child: Center(
                widthFactor: 1,
                child: AnimatedContainer(
                  duration: Motion.of(context, Motion.state),
                  curve: Motion.curve,
                  padding: const EdgeInsets.symmetric(
                    horizontal: Sp.s,
                    vertical: Sp.xs,
                  ),
                  decoration: BoxDecoration(
                    // The soft accent, not `surface`: in dark mode `surface`
                    // and the track are almost the same colour.
                    color: selected ? colors.accentSoft : Colors.transparent,
                    borderRadius: radius,
                    border: Border.all(
                      color: selected
                          ? colors.borderStrong
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          style: context.type.meta.copyWith(
                            color: ink,
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: Sp.xs),
                        badge!,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// «Seleccionar días» shares the fixed row under the month with the paint
/// scroll buttons (and, outside editing, with the floating «Pintar»).
///
/// With [underFab] the floating button sits over the end of this row, so the
/// control only gets the room before it: when the label does not fit there
/// (large text, long names such as Basque «Hautatu egunak») it shrinks to
/// its icon, with the name as tooltip and spoken label, instead of running
/// under «Pintar».
class MonthSelectDaysControl extends ConsumerWidget {
  const MonthSelectDaysControl({super.key, this.underFab = false});

  final bool underFab;

  /// Outer padding of the control on each side.
  static const double _outer = Sp.xs;

  /// Gap Material leaves between the icon and the label of a button.
  static const double _iconGap = 8;

  /// The width the floating «Pintar» takes from the end of the row: its
  /// padding, icon, gap and label (at the user's text size), and the margin
  /// the scaffold leaves at the edge.
  static double fabWidth(BuildContext context) =>
      Sp.xl +
      24 +
      Sp.m +
      textWidth(
        context.l10n.paintFab,
        context.type.button,
        MediaQuery.textScalerOf(context),
      ) +
      Sp.xxl +
      16;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = context.l10n.monthSelectDays;
    final style = context.type.meta.copyWith(fontWeight: FontWeight.w700);
    final colors = context.colors;
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        final needed =
            2 * _outer +
            2 * Sp.m +
            IconSize.button +
            _iconGap +
            textWidth(label, style, scaler);
        final room = box.maxWidth - (underFab ? fabWidth(context) : 0);
        final iconOnly = needed > room;
        final buttonStyle = OutlinedButton.styleFrom(
          minimumSize: const Size(Sp.touch, Sp.touch),
          padding: EdgeInsets.symmetric(horizontal: iconOnly ? 0 : Sp.m),
          foregroundColor: colors.textPrimary,
          backgroundColor: colors.surfaceMuted,
          side: BorderSide(color: colors.border),
          shape: RoundedRectangleBorder(borderRadius: Rad.inputRadius),
          textStyle: style,
        );
        final onPressed = ref.read(selectionControllerProvider.notifier).enter;
        final icon = Icon(AppIcons.selectDays, size: IconSize.button);
        return Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _outer),
            // A real button, not a link: in dark mode the accent text alone
            // was hard to see next to the grid (1-nov-2026).
            child: iconOnly
                ? Tooltip(
                    message: label,
                    child: Semantics(
                      label: label,
                      button: true,
                      excludeSemantics: true,
                      onTap: onPressed,
                      child: OutlinedButton(
                        key: const ValueKey('month-select-days'),
                        style: buttonStyle,
                        onPressed: onPressed,
                        child: icon,
                      ),
                    ),
                  )
                : OutlinedButton.icon(
                    key: const ValueKey('month-select-days'),
                    style: buttonStyle,
                    onPressed: onPressed,
                    icon: icon,
                    label: Text(label),
                  ),
          ),
        );
      },
    );
  }
}
