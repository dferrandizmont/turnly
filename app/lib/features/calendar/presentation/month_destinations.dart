import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/icons/app_icons.dart';
import '../../../core/icons/selection_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/router.dart';
import '../../../core/theme/theme_context.dart';
import '../../patterns/application/pattern_start_pick.dart';
import '../application/open_day.dart';
import '../application/schedule_controller.dart';
import '../application/visible_month.dart';
import 'day_cell.dart' show textWidth;

/// The four destinations of the month (B1, option 1A of the 31-oct canvas),
/// always with their name: a bottom bar on a phone in portrait and a rail
/// beside the month with two panes (`docs/diseno.md`, «Barra de destinos»).
///
/// «Mes» is this screen: tapping it brings back today's month. The other
/// three open their screen on top, with its back button, as before:
/// - «Rotación»: «Mis rotaciones» (end or remove a rotation); with none yet,
///   the pattern wizard, which is where a rotation is created. The year view
///   is not a rotation: it opens from the title of the month.
/// - «Agenda»: upcoming notes and search.
/// - «Resumen»: the summary of the month on screen.
enum MonthDestination { month, rotation, agenda, summary }

/// Keys kept from the old header buttons, so tests and QA scenarios still
/// find «Agenda» and «Resumen».
const _destinationKeys = {
  MonthDestination.month: ValueKey('nav-month'),
  MonthDestination.rotation: ValueKey('open-rotation'),
  MonthDestination.agenda: ValueKey('open-agenda'),
  MonthDestination.summary: ValueKey('open-summary'),
};

void openMonthDestination(
  BuildContext context,
  WidgetRef ref,
  MonthDestination destination,
) {
  switch (destination) {
    case MonthDestination.month:
      ref.read(openDayProvider.notifier).close();
      ref.read(visibleMonthProvider.notifier).today();
    case MonthDestination.rotation:
      final runs = ref.read(scheduleControllerProvider).schedule.runs;
      context.push(
        runs.isEmpty ? patternWizardLocation() : AppRoutes.settingsRuns,
      );
    case MonthDestination.agenda:
      context.push(AppRoutes.agenda);
    case MonthDestination.summary:
      context.push(AppRoutes.summaryFor(ref.read(visibleMonthProvider)));
  }
}

({IconData icon, String label}) _describe(
  BuildContext context,
  MonthDestination destination,
) {
  final l10n = context.l10n;
  return switch (destination) {
    MonthDestination.month => (
      icon: AppIcons.calendar,
      label: l10n.monthNavMonth,
    ),
    MonthDestination.rotation => (
      icon: AppIcons.pattern,
      label: l10n.monthNavRotation,
    ),
    MonthDestination.agenda => (
      icon: SelectionIcons.agenda,
      label: l10n.monthNavAgenda,
    ),
    MonthDestination.summary => (
      icon: AppIcons.summary,
      label: l10n.monthNavSummary,
    ),
  };
}

/// Text from ×1.6, or a name wider than its slot, leaves the destinations
/// with their icon only and the name as tooltip and spoken label, like the
/// other bars with names under each button (`docs/diseno.md`).
bool _namesFit(BuildContext context, double slotWidth) {
  final scaler = MediaQuery.textScalerOf(context);
  if (scaler.scale(10) / 10 >= 1.6) return false;
  final style = context.type.caption.copyWith(fontWeight: FontWeight.w800);
  return MonthDestination.values.every(
    (d) =>
        textWidth(_describe(context, d).label, style, scaler) <=
        slotWidth - 2 * Sp.xs,
  );
}

/// The bottom bar of the month in one column.
class MonthNavigationBar extends ConsumerWidget {
  const MonthNavigationBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final type = context.type;
    return LayoutBuilder(
      builder: (context, box) {
        final names = _namesFit(
          context,
          box.maxWidth / MonthDestination.values.length,
        );
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.border)),
          ),
          child: NavigationBar(
            key: const ValueKey('month-nav-bar'),
            backgroundColor: colors.surface,
            selectedIndex: MonthDestination.month.index,
            labelBehavior: names
                ? NavigationDestinationLabelBehavior.alwaysShow
                : NavigationDestinationLabelBehavior.alwaysHide,
            labelTextStyle: WidgetStateProperty.resolveWith(
              (states) => type.caption.copyWith(
                overflow: TextOverflow.ellipsis,
                color: states.contains(WidgetState.selected)
                    ? colors.textPrimary
                    : colors.textMuted,
                fontWeight: states.contains(WidgetState.selected)
                    ? FontWeight.w800
                    : FontWeight.w600,
              ),
            ),
            onDestinationSelected: (index) => openMonthDestination(
              context,
              ref,
              MonthDestination.values[index],
            ),
            destinations: [
              for (final destination in MonthDestination.values)
                NavigationDestination(
                  key: _destinationKeys[destination],
                  icon: Icon(_describe(context, destination).icon),
                  label: _describe(context, destination).label,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The same destinations as a rail at the start of the two-pane month.
class MonthNavigationRail extends ConsumerWidget {
  const MonthNavigationRail({super.key});

  /// The width of the rail (Material's).
  static const double width = 80;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final names = _namesFit(context, width);
    return NavigationRail(
      key: const ValueKey('month-nav-rail'),
      backgroundColor: colors.background,
      minWidth: width,
      groupAlignment: -1,
      selectedIndex: MonthDestination.month.index,
      labelType: names
          ? NavigationRailLabelType.all
          : NavigationRailLabelType.none,
      onDestinationSelected: (index) =>
          openMonthDestination(context, ref, MonthDestination.values[index]),
      destinations: [
        for (final destination in MonthDestination.values)
          NavigationRailDestination(
            icon: KeyedSubtree(
              key: _destinationKeys[destination],
              child: Icon(_describe(context, destination).icon),
            ),
            label: Text(_describe(context, destination).label),
          ),
      ],
    );
  }
}
