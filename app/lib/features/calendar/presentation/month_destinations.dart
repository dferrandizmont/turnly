import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/icons/app_icons.dart';
import '../../../core/icons/selection_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/router.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/content_app_bar.dart' show TopLevelDestination;
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

/// The `extra` of a route opened through the destinations (the bar, the rail,
/// the strip of the month): the screen belongs to the main destinations, so
/// with the rail beside it there is no back button. A screen reached from
/// elsewhere (Ajustes › Mis rotaciones, Año › Resumen) has no such extra and
/// keeps its back button, which returns to the screen that opened it.
class RailNavigation {
  const RailNavigation();
}

/// Opens [destination]. From the month ([from] is [MonthDestination.month])
/// the three screens open on top of it; from one of them (the rail shows on
/// all four when there are two panes) they take its place, so the back button
/// still goes to the month, and «Mes» goes back to today's month.
void openMonthDestination(
  BuildContext context,
  WidgetRef ref,
  MonthDestination destination, {
  MonthDestination from = MonthDestination.month,
  // Whether the screen being left was itself reached through the destinations;
  // if not (it was opened from Ajustes or the year), the next one is not
  // either, and keeps the way back to where it came from.
  bool viaDestinations = true,
}) {
  if (destination == from && destination != MonthDestination.month) return;
  final onTop = from != MonthDestination.month;
  final extra = viaDestinations ? const RailNavigation() : null;
  void open(String location) => onTop
      ? context.pushReplacement(location, extra: extra)
      : context.push(location, extra: extra);
  switch (destination) {
    case MonthDestination.month:
      ref.read(openDayProvider.notifier).close();
      ref.read(visibleMonthProvider.notifier).today();
      if (onTop) context.go(AppRoutes.home);
    case MonthDestination.rotation:
      final runs = ref.read(scheduleControllerProvider).schedule.runs;
      open(runs.isEmpty ? patternWizardLocation() : AppRoutes.settingsRuns);
    case MonthDestination.agenda:
      open(AppRoutes.agenda);
    case MonthDestination.summary:
      open(AppRoutes.summaryFor(ref.read(visibleMonthProvider)));
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

/// The text scale the names of the destinations stop growing at, on the
/// bottom bar and on the rail: both have a fixed size, so above this the
/// names stay as readable as they can be without breaking it (the icons and
/// the rest of the screen keep growing).
const double navNameMaxScale = 1.3;

/// The width the longest name of the destinations takes on one line, drawn at
/// the user's text size but at most [navNameMaxScale], plus its side room.
/// The one rule of both bars (`docs/diseno.md`): the names stay at any text
/// size, and the destinations keep only their icon (the name is the tooltip
/// and the spoken label) when this does not fit the room the bar has.
double _namesWidth(BuildContext context) {
  final scaler = MediaQuery.textScalerOf(context)
      .clamp(maxScaleFactor: navNameMaxScale);
  final style = context.type.caption.copyWith(fontWeight: FontWeight.w800);
  var widest = 0.0;
  for (final d in MonthDestination.values) {
    widest = math.max(
      widest,
      textWidth(_describe(context, d).label, style, scaler),
    );
  }
  return widest + 2 * Sp.xs;
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
        final names =
            _namesWidth(context) <=
            box.maxWidth / MonthDestination.values.length;
        return MediaQuery.withClampedTextScaling(
          maxScaleFactor: navNameMaxScale,
          child: DecoratedBox(
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
                  Semantics(
                    identifier: 'nav-${destination.name}',
                    child: NavigationDestination(
                      key: _destinationKeys[destination],
                      icon: Icon(_describe(context, destination).icon),
                      label: _describe(context, destination).label,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The same destinations as a rail at the start of the two-pane month, and of
/// the three screens that open from it ([DestinationRailShell]). [current] is
/// the destination on screen.
class MonthNavigationRail extends ConsumerWidget {
  const MonthNavigationRail({
    super.key,
    this.current = MonthDestination.month,
    this.viaDestinations = true,
  });

  final MonthDestination current;

  /// See [openMonthDestination].
  final bool viaDestinations;

  /// The width of the rail at normal text (Material's).
  static const double width = 80;

  /// The widest the rail grows to keep the names at a large text size; a name
  /// that needs more leaves the rail with its icons only.
  static const double maxWidth = 128;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final needed = _namesWidth(context);
    final names = needed <= maxWidth;
    final railWidth = math.max(width, math.min(needed, maxWidth));
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: navNameMaxScale,
      child: NavigationRail(
        key: const ValueKey('month-nav-rail'),
        backgroundColor: colors.background,
        minWidth: railWidth,
        groupAlignment: -1,
        selectedIndex: current.index,
        labelType: names
            ? NavigationRailLabelType.all
            : NavigationRailLabelType.none,
        onDestinationSelected: (index) => openMonthDestination(
          context,
          ref,
          MonthDestination.values[index],
          from: current,
          viaDestinations: viaDestinations,
        ),
        destinations: [
          for (final destination in MonthDestination.values)
            NavigationRailDestination(
              icon: KeyedSubtree(
                key: _destinationKeys[destination],
                child: Semantics(
                  identifier: 'nav-${destination.name}',
                  child: Icon(_describe(context, destination).icon),
                ),
              ),
              label: Text(
                _describe(context, destination).label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

/// Puts the rail of destinations beside [child], a whole screen with its own
/// app bar (Rotación, Agenda, Resumen), when the window has two panes
/// ([Adaptive.useSplit], the same cut-off as the month). With one column
/// (a phone, a tablet in portrait) it is [child] alone, as before.
class DestinationRailShell extends StatelessWidget {
  const DestinationRailShell({
    super.key,
    required this.current,
    required this.child,
    this.viaDestinations = false,
  });

  /// The destination the child is.
  final MonthDestination current;

  /// Whether it was opened through the destinations (the router reads it from
  /// the `extra` of the route). Only then it has no back button beside the
  /// rail; opened from Ajustes or the year, it keeps the way back.
  final bool viaDestinations;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!Adaptive.useSplit(MediaQuery.sizeOf(context))) return child;
    final colors = context.colors;
    return ColoredBox(
      color: colors.background,
      child: LayoutBuilder(
        builder: (context, box) => Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: math.min(box.maxWidth, Adaptive.splitMaxWidth),
            child: Row(
              children: [
                SizedBox(
                  height: box.maxHeight,
                  // The rail needs a Material to paint its ink on.
                  child: Material(
                    color: colors.background,
                    child: MonthNavigationRail(
                      current: current,
                      viaDestinations: viaDestinations,
                    ),
                  ),
                ),
                Expanded(
                  // The screen sees the window it really has beside the rail
                  // (its app bar lines up with its page column from that
                  // width), and the rail already keeps clear of the cut-out.
                  child: LayoutBuilder(
                    builder: (context, area) => MediaQuery.removePadding(
                      context: context,
                      removeLeft: true,
                      child: MediaQuery(
                        data: MediaQuery.of(
                          context,
                        ).copyWith(size: Size(area.maxWidth, area.maxHeight)),
                        // Between the main destinations the rail is the way
                        // to the other three: no back button.
                        child: viaDestinations
                            ? TopLevelDestination(child: child)
                            : child,
                      ),
                    ),
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
