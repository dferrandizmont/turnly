import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/app_date_format.dart';
import '../../../core/format/text_measure.dart';
import '../../../core/icons/app_icons.dart';
import '../../../core/icons/month_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/router.dart';
import '../../../core/theme/theme_context.dart';
import '../../onboarding/application/onboarding_providers.dart';
import '../../patterns/application/pattern_start_pick.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../application/paint_controller.dart';
import '../application/schedule_controller.dart';
import 'day_cell.dart' show textHeight;
import 'history_feedback.dart';
import 'puck_label.dart';
import 'shift_format.dart';
import 'shift_icon_glyph.dart';

/// Header of paint mode (`docs/diseno.md`, "Modo pintar"): ONE line with
/// "PINTANDO · Cambiar el turno" at the left (the word in the ink of the
/// chosen shift, the mode in the muted ink) and the pattern button and
/// "Listo" at the right. The name and hours of the chosen shift are no longer
/// repeated here: the ringed puck with its bold name says which one it is and
/// the preview of the sheet says its hours (decision 28).
///
/// The header has the same height whichever shift is chosen, so the month
/// below it never moves when the user switches tools: the label is never
/// broken, it shrinks before it does.
class PaintHeader extends ConsumerWidget {
  const PaintHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    final paint = ref.watch(paintControllerProvider);
    final palette = ref.watch(
      scheduleControllerProvider.select((s) => s.palette),
    );

    final shift = paint.shiftTypeId == null
        ? null
        : palette.where((t) => t.id == paint.shiftTypeId).firstOrNull;
    final labelColor = shift?.swatch(colors.brightness).ink ?? colors.textMuted;

    // The mode (B3), or the eraser: it has no mode, it is its own tool.
    final mode = shift == null
        ? l10n.paintEraser
        : paint.doubling
        ? l10n.paintModeAdd
        : l10n.paintModeReplace;

    final label = Semantics(
      // «Pintando, cambiar el turno»: one natural phrase, not the pieces
      // with their separator.
      label: '${l10n.paintHeader}, $mode',
      excludeSemantics: true,
      child: Align(
        alignment: Alignment.centerLeft,
        // One line, whatever the size: it shrinks before it breaks.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.paintHeader.toUpperCase(),
                key: const ValueKey('paint-label'),
                maxLines: 1,
                softWrap: false,
                style: type.label.copyWith(color: labelColor),
              ),
              Text(
                ' · ${mode.toUpperCase()}',
                key: const ValueKey('paint-mode-label'),
                maxLines: 1,
                softWrap: false,
                style: type.label.copyWith(color: colors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.page, Sp.s, Sp.page, 0),
      child: Semantics(
        header: true,
        child: Row(
          children: [
            Expanded(child: label),
            const SizedBox(width: Sp.s),
            IconButton(
              key: const ValueKey('paint-pattern'),
              tooltip: l10n.patternButton,
              icon: Icon(AppIcons.pattern),
              onPressed: () => context.push(
                patternWizardLocation(shiftTypeId: paint.shiftTypeId),
              ),
            ),
            const SizedBox(width: Sp.xs),
            FilledButton(
              key: const ValueKey('paint-done'),
              onPressed: ref.read(paintControllerProvider.notifier).exit,
              child: Text(l10n.paintDone),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet of paint mode (B3): the two modes «Cambiar el turno | Añadir
/// otro turno», the preview of what a tap does with round undo / redo beside
/// it, and a round puck per shift (disc + ink code, name below, the selected
/// one ringed) with the eraser. Long-pressing a puck starts "aplicar patrón desde este día":
/// the next day tapped is where the pattern wizard begins.
///
/// The sheet takes what the month leaves (decision 28): the month screen
/// lays the rows of the month out first and gives the sheet the rest as
/// [maxHeight], never less than [minHeight]. The modes and the preview with
/// undo / redo stay fixed; only the area of the pucks scrolls, vertically,
/// with a fade at the edge that has more. The first time, a tip sits above
/// the modes.
class PaintBar extends ConsumerWidget {
  const PaintBar({super.key, this.card = false, this.maxHeight});

  /// In the pane of the two-pane month: a rounded card with the margin of the
  /// other cards of the pane, not a bar stuck to the bottom of the screen.
  final bool card;

  /// The most height the sheet may take, or null for the fallback of a screen
  /// where not even [minHeight] is left (large text, short phones): the
  /// sheet is as tall as its tools need, the pucks scrolling within a share
  /// of the screen, and the month scrolls above it.
  final double? maxHeight;

  /// The most of the screen height the pucks may take in the fallback.
  static const double _toolsMaxHeightShare = 0.25;

  /// The tip line of the first use: 48 dp of line and the margin above it.
  static const double _tipHeight = Sp.xs + Sp.touch;

  /// The modes switch: its segments (a touch target each) and the frame.
  static const double _modesHeight = Sp.s + Sp.touch + 2 * Sp.hair + 2;

  /// The least height the sheet can have and still show the modes, the
  /// preview with undo / redo and one row of pucks (about 250 dp on a phone
  /// at the normal size), with the system inset under it. With large text the
  /// modes scroll with the pucks and do not count.
  static double minHeight(BuildContext context, {bool tip = false}) {
    final scaler = MediaQuery.textScalerOf(context);
    final largeText = scaler.scale(10) / 10 >= 1.6;
    final label = textHeight(context.type.caption, scaler);
    final puckRow =
        Sp.xs + // padding of the area
        Sp.s +
        Disc.toolPuck +
        Sp.s +
        label +
        Sp.xs +
        Sp.l;
    return (tip ? _tipHeight : 0) +
        (largeText ? 0 : _modesHeight) +
        Sp.hair +
        Disc.round + // the preview row
        puckRow +
        MediaQuery.paddingOf(context).bottom;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;
    final paint = ref.watch(paintControllerProvider);
    final history = ref.watch(scheduleControllerProvider);
    final paintController = ref.read(paintControllerProvider.notifier);
    final scheduleController = ref.read(scheduleControllerProvider.notifier);
    final shiftTypes = history.palette;
    final format = AppDateFormat.of(context);

    // The first stroke ends: the tip has done its job.
    ref.listen(scheduleControllerProvider.select((s) => s.strokeDays.isEmpty), (
      previous,
      empty,
    ) {
      if (previous == false && empty && ref.read(onboardingTipProvider)) {
        unawaited(ref.read(onboardingTipProvider.notifier).dismiss());
      }
    });

    void patternFrom(String? shiftTypeId) =>
        ref.read(patternStartPickProvider.notifier).begin(shiftTypeId);

    // From ×1.6 the two modes move into the scrolling area and the preview
    // keeps only its cells (`docs/diseno.md`, «Modo pintar»).
    final largeText = MediaQuery.textScalerOf(context).scale(10) / 10 >= 1.6;
    final modes = _ModeSwitch(
      doubling: paint.doubling,
      enabled: !paint.erasing,
      onChanged: paintController.setDoubling,
    );

    ButtonStyle roundStyle() => IconButton.styleFrom(
      fixedSize: const Size.square(Disc.round),
      backgroundColor: colors.surfaceRaised,
      disabledBackgroundColor: colors.surfaceRaised,
      foregroundColor: colors.textPrimary,
      disabledForegroundColor: colors.textMuted,
      shape: RoundedRectangleBorder(borderRadius: Rad.squareRadius(Disc.round)),
    );

    final limited = maxHeight != null && !card;

    final sheet = Semantics(
      container: true,
      label: l10n.paintToolsLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.border),
          borderRadius: card
              ? const BorderRadius.all(Radius.circular(Rad.sheet))
              : const BorderRadius.vertical(top: Radius.circular(Rad.sheet)),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: card ? null : 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Sp.maxContentWidth),
              child: Column(
                mainAxisSize: card ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  const _PaintTip(),
                  // «Cambiar el turno | Añadir otro turno» (B3, option 3A of
                  // the 31-oct canvas), replacing the old «Doblar» chip.
                  // With large text it scrolls with the pucks, so the sheet
                  // never takes the month's room.
                  if (!largeText)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Sp.page - Sp.s,
                        Sp.s,
                        Sp.page - Sp.s,
                        0,
                      ),
                      child: modes,
                    ),
                  // What a tap does, drawn with real cells, beside undo and
                  // redo (always in view).
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Sp.page,
                      Sp.hair,
                      Sp.page,
                      0,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _PaintPreview(
                            paint: paint,
                            palette: shiftTypes,
                            compact: largeText,
                          ),
                        ),
                        const SizedBox(width: Sp.s),
                        IconButton(
                          key: const ValueKey('undo'),
                          tooltip: l10n.undo,
                          style: roundStyle(),
                          icon: Icon(AppIcons.undo),
                          onPressed: history.canUndo
                              ? () => undoWithFeedback(
                                  context,
                                  scheduleController,
                                )
                              : null,
                        ),
                        const SizedBox(width: Sp.s),
                        IconButton(
                          key: const ValueKey('redo'),
                          tooltip: l10n.redo,
                          style: roundStyle(),
                          icon: Icon(AppIcons.redo),
                          onPressed: history.canRedo
                              ? () => redoWithFeedback(
                                  context,
                                  scheduleController,
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                  // The tools wrap onto as many lines as they need, never a
                  // single row cut mid-word (H-T17-3, H-T21-9); when they
                  // do not fit the area scrolls vertically: in the room the
                  // sheet was given, or in a share of the screen.
                  _PaletteArea(
                    expanded: card,
                    flexible: limited,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: card || limited
                            ? double.infinity
                            : MediaQuery.sizeOf(context).height *
                                  _toolsMaxHeightShare,
                      ),
                      child: _PuckScroll(
                        scrollKey: const ValueKey('paint-tools-scroll'),
                        padding: const EdgeInsets.fromLTRB(
                          Sp.page - Sp.s,
                          Sp.xs,
                          Sp.page - Sp.s,
                          Sp.l,
                        ),
                        child: _WithModes(
                          modes: largeText ? modes : null,
                          child: Wrap(
                            key: const ValueKey('paint-tools-wrap'),
                            alignment: card
                                ? WrapAlignment.spaceEvenly
                                : WrapAlignment.start,
                            runSpacing: card ? Sp.l : 0,
                            spacing: Sp.xs,
                            crossAxisAlignment: WrapCrossAlignment.start,
                            children: [
                              _Puck(
                                key: const ValueKey('tool-eraser'),
                                label: l10n.paintEraser,
                                selected: paint.erasing,
                                disc: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: colors.surfaceMuted,
                                    borderRadius: Rad.squareRadius(
                                      Disc.toolPuck,
                                    ),
                                    border: Border.all(
                                      color: colors.borderStrong,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      AppIcons.erase,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ),
                                onTap: paintController.selectEraser,
                                onLongPress: () => patternFrom(null),
                              ),
                              for (final shift in shiftTypes)
                                _Puck(
                                  key: ValueKey('tool-${shift.id}'),
                                  label: shift.name,
                                  // The chosen one reads its hours too.
                                  spoken: paint.shiftTypeId == shift.id
                                      ? _spokenTool(l10n, format, shift)
                                      : null,
                                  selected: paint.shiftTypeId == shift.id,
                                  disc: _ShiftDisc(shift: shift),
                                  onTap: () =>
                                      paintController.selectShift(shift.id),
                                  onLongPress: () {
                                    paintController.selectShift(shift.id);
                                    patternFrom(shift.id);
                                  },
                                ),
                              _Puck(
                                key: const ValueKey('tool-edit-types'),
                                label: l10n.shiftTypesEditEntry,
                                selected: false,
                                disc: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: Rad.squareRadius(
                                      Disc.toolPuck,
                                    ),
                                    border: Border.all(
                                      color: colors.borderStrong,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      AppIcons.edit,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ),
                                onTap: () => context.push(AppRoutes.shiftTypes),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return maxHeight == null || card
        ? sheet
        : ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight!),
            child: sheet,
          );
  }

  /// «Mañana, 06:00–14:00»: the name and the hours the chosen puck is read
  /// with; just the name when the shift has no hours.
  static String _spokenTool(
    AppLocalizations l10n,
    AppDateFormat format,
    ShiftType shift,
  ) {
    final times = shift.timeRange(format);
    return times == null ? shift.name : l10n.paintToolSpoken(shift.name, times);
  }
}

/// The one-time tip of the first use, as a line of the sheet (decision 28):
/// the brush, «Elige un turno y arrastra.» and the cross that closes it for
/// good. It also goes away by itself when the first stroke ends.
class _PaintTip extends ConsumerWidget {
  const _PaintTip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(onboardingTipProvider)) return const SizedBox.shrink();
    final l10n = context.l10n;
    final colors = context.colors;
    return Padding(
      key: const ValueKey('onboarding-tip'),
      padding: const EdgeInsets.fromLTRB(Sp.page, Sp.xs, Sp.xs, 0),
      child: Row(
        children: [
          Icon(AppIcons.paint, size: IconSize.inline, color: colors.accentText),
          const SizedBox(width: Sp.s),
          Expanded(
            child: Semantics(
              // The visible line is short; a screen reader hears the whole
              // tip (the title and what it explains).
              label: '${l10n.onboardingTipTitle}. ${l10n.onboardingTipBody}',
              excludeSemantics: true,
              child: Text(
                l10n.monthTipPaint,
                style: context.type.meta.copyWith(color: colors.textSecondary),
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('onboarding-tip-close'),
            tooltip: l10n.onboardingTipClose,
            icon: Icon(
              AppIcons.close,
              size: IconSize.button,
              color: colors.textSecondary,
            ),
            onPressed: ref.read(onboardingTipProvider.notifier).dismiss,
          ),
        ],
      ),
    );
  }
}

/// The area of the pucks: it scrolls vertically and fades at the edge that
/// has more to show, so it is clear there is more below (or above).
class _PuckScroll extends StatefulWidget {
  const _PuckScroll({
    required this.scrollKey,
    required this.padding,
    required this.child,
  });

  final Key scrollKey;

  final EdgeInsets padding;
  final Widget child;

  @override
  State<_PuckScroll> createState() => _PuckScrollState();
}

class _PuckScrollState extends State<_PuckScroll> {
  final _controller = ScrollController();
  bool _more = false;
  bool _before = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _update(ScrollMetrics metrics) {
    final before = metrics.pixels > 0.5;
    final more = metrics.extentAfter > 0.5;
    if (before != _before || more != _more) {
      // The metrics arrive while the tree is laying out.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _before = before;
          _more = more;
        });
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget fade({required bool top}) => Positioned(
      left: 0,
      right: 0,
      top: top ? 0 : null,
      bottom: top ? null : 0,
      height: Sp.l,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: top ? Alignment.topCenter : Alignment.bottomCenter,
              end: top ? Alignment.bottomCenter : Alignment.topCenter,
              colors: [colors.surface, colors.surface.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
    return Stack(
      children: [
        NotificationListener<ScrollMetricsNotification>(
          onNotification: (n) => _update(n.metrics),
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) => _update(n.metrics),
            child: SingleChildScrollView(
              key: widget.scrollKey,
              controller: _controller,
              padding: widget.padding,
              child: widget.child,
            ),
          ),
        ),
        if (_before) fade(top: true),
        if (_more) fade(top: false),
      ],
    );
  }
}

/// The pucks, with the two modes above them when they scroll together.
class _WithModes extends StatelessWidget {
  const _WithModes({required this.modes, required this.child});

  final Widget? modes;
  final Widget child;

  @override
  Widget build(BuildContext context) => modes == null
      ? child
      : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            modes!,
            const SizedBox(height: Sp.s),
            child,
          ],
        );
}

/// The pane gives the palette all the room between header and actions; the
/// sheet gives it what its height leaves after the fixed parts.
class _PaletteArea extends StatelessWidget {
  const _PaletteArea({
    required this.expanded,
    required this.flexible,
    required this.child,
  });
  final bool expanded;
  final bool flexible;
  final Widget child;

  @override
  Widget build(BuildContext context) => expanded
      ? Expanded(child: child)
      : flexible
      ? Flexible(child: child)
      : child;
}

/// A round 48 dp tool with its name below. The selected one gets a 2.5 dp
/// ring in `todayRing`, 3 dp away, and a bolder name (not colour alone). When
/// it becomes the chosen one (or is the chosen one as the sheet opens) it
/// scrolls itself into view in the area of the pucks.
class _Puck extends StatefulWidget {
  const _Puck({
    super.key,
    required this.label,
    required this.selected,
    required this.disc,
    required this.onTap,
    this.spoken,
    this.onLongPress,
  });

  final String label;
  final bool selected;

  /// What a screen reader says instead of [label] (name and hours of the
  /// chosen shift).
  final String? spoken;

  /// Content of the 48 dp circle.
  final Widget disc;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  static const double _minWidth = Disc.toolPuck + 2 * Sp.s;

  @override
  State<_Puck> createState() => _PuckState();
}

class _PuckState extends State<_Puck> {
  @override
  void initState() {
    super.initState();
    if (widget.selected) _reveal();
  }

  @override
  void didUpdateWidget(_Puck old) {
    super.didUpdateWidget(old);
    if (widget.selected && !old.selected) _reveal();
  }

  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || Scrollable.maybeOf(context) == null) return;
      unawaited(
        Scrollable.ensureVisible(
          context,
          duration: Motion.of(context, Motion.state),
          curve: Motion.curve,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.label;
    final selected = widget.selected;
    final disc = widget.disc;
    final onTap = widget.onTap;
    final onLongPress = widget.onLongPress;
    final colors = context.colors;
    final type = context.type;
    final labelStyle = type.caption.copyWith(
      color: selected ? colors.textPrimary : colors.textMuted,
      fontWeight: selected ? FontWeight.w800 : null,
    );
    // Grows with the text size and the name: never abbreviated, never stuck
    // to the next puck.
    final width = puckWidth(
      context,
      label: label,
      style: labelStyle.copyWith(fontWeight: FontWeight.w800),
      minWidth: _Puck._minWidth,
    );
    const ringOutset = Sp.selectionGap + Sp.selectionRing / 2;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      excludeSemantics: true,
      label: widget.spoken ?? label,
      onTap: onTap,
      onLongPress: onLongPress,
      child: InkWell(
        customBorder: RoundedRectangleBorder(borderRadius: Rad.inputRadius),
        onTap: onTap,
        onLongPress: onLongPress,
        child: SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: Sp.s),
              SizedBox.square(
                dimension: Disc.toolPuck,
                child: Stack(
                  clipBehavior: Clip.none,
                  fit: StackFit.expand,
                  children: [
                    disc,
                    if (selected)
                      Positioned(
                        left: -ringOutset,
                        top: -ringOutset,
                        right: -ringOutset,
                        bottom: -ringOutset,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: Rad.squareRadius(
                                Disc.toolPuck + 2 * ringOutset,
                              ),
                              border: Border.all(
                                color: colors.todayRing,
                                width: Sp.selectionRing,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Sp.s),
              PuckLabel(label: label, style: labelStyle),
              const SizedBox(height: Sp.xs),
            ],
          ),
        ),
      ),
    );
  }
}

/// The shift's `disc` with its code in the `ink`.
class _ShiftDisc extends StatelessWidget {
  const _ShiftDisc({required this.shift});

  final ShiftType shift;

  @override
  Widget build(BuildContext context) {
    final swatch = shift.swatch(context.colors.brightness);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: swatch.disc,
        borderRadius: Rad.squareRadius(Disc.toolPuck),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(Sp.s),
            child: ShiftCodeWithIcon(
              shift: shift,
              style: context.type.headline.copyWith(color: swatch.ink),
            ),
          ),
        ),
      ),
    );
  }
}

/// «Cambiar el turno | Añadir otro turno» (B3): the two modes of the brush
/// as a segmented control across the sheet. «Doblar», the word of the trade,
/// stays in the spoken name of the second half and in the preview. With the
/// eraser neither mode applies: the control is dimmed and disabled.
class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({
    required this.doubling,
    required this.enabled,
    required this.onChanged,
  });

  final bool doubling;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final labelStyle = context.type.meta.copyWith(fontWeight: FontWeight.w800);
    return LayoutBuilder(
      builder: (context, box) {
        // The icons only repeat the labels: they go when a label and its icon
        // would not share one line in its half, so the labels wrap as little
        // as possible (and from ×1.6 always).
        final half = (box.maxWidth - 2 * Sp.hair - 2) / 2;
        final icons =
            MediaQuery.textScalerOf(context).scale(10) / 10 < 1.6 &&
            [l10n.paintModeReplace, l10n.paintModeAdd].every(
              (label) =>
                  textWidth(context, label, labelStyle) +
                      IconSize.inline +
                      Sp.xs +
                      2 * Sp.s +
                      2 <=
                  half,
            );
        return _track(context, colors, l10n, icons);
      },
    );
  }

  Widget _track(
    BuildContext context,
    AppColors colors,
    AppLocalizations l10n,
    bool icons,
  ) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: BorderRadius.circular(Rad.button),
          border: Border.all(color: colors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Sp.hair),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _ModeSegment(
                    key: const ValueKey('paint-mode-replace'),
                    icon: icons ? MonthIcons.replaceShift : null,
                    label: l10n.paintModeReplace,
                    spoken: l10n.paintModeReplace,
                    selected: enabled && !doubling,
                    enabled: enabled,
                    onTap: () => onChanged(false),
                  ),
                ),
                Expanded(
                  child: _ModeSegment(
                    key: const ValueKey('tool-double'),
                    icon: icons ? MonthIcons.addShift : null,
                    label: l10n.paintModeAdd,
                    spoken: l10n.paintModeAddSpoken,
                    selected: enabled && doubling,
                    enabled: enabled,
                    onTap: () => onChanged(true),
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

/// One half of [_ModeSwitch]: the chosen one on the soft accent with a bolder
/// label and a border (never colour alone). Its label wraps between words
/// with large text; it is never cut.
class _ModeSegment extends StatelessWidget {
  const _ModeSegment({
    super.key,
    required this.icon,
    required this.label,
    required this.spoken,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final IconData? icon;
  final String label;
  final String spoken;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ink = selected ? colors.textPrimary : colors.textSecondary;
    final radius = Rad.innerRadius;
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      excludeSemantics: true,
      label: spoken,
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.state),
        curve: Motion.curve,
        decoration: BoxDecoration(
          color: selected ? colors.accentSoft : Colors.transparent,
          borderRadius: radius,
          border: Border.all(
            color: selected ? colors.borderStrong : Colors.transparent,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: enabled ? onTap : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: Sp.touch),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Sp.s,
                  vertical: Sp.xs,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: IconSize.inline, color: ink),
                      const SizedBox(width: Sp.xs),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: context.type.meta.copyWith(
                          color: ink,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// «Al tocar un día: [M] → [N]» (B3): what a tap does with the chosen brush,
/// drawn with small cells in the real colours, code and bar. It changes as
/// soon as another shift, the eraser or the other mode is chosen:
/// - change: [M] → [N], «Sustituye al que haya»;
/// - add (doblar): [M] → [M N], «Se suma al que ya hay»;
/// - eraser: [M] → [ ], «Deja el día vacío».
/// The day before is an example: the first other shift of the palette (the
/// chosen one when it is the only one).
class _PaintPreview extends StatelessWidget {
  const _PaintPreview({
    required this.paint,
    required this.palette,
    this.compact = false,
  });

  /// With large text: the cells alone (the title and the effect are still
  /// read aloud), so the row stays as tall as undo and redo.
  final bool compact;

  final PaintState paint;
  final List<ShiftType> palette;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    final chosen = paint.shiftTypeId == null
        ? null
        : palette.where((t) => t.id == paint.shiftTypeId).firstOrNull;
    final others = palette.where((t) => t.id != chosen?.id);
    final example =
        others
            .where((t) => t.category == ShiftCategory.work)
            .followedBy(others)
            .firstOrNull ??
        chosen;
    if (example == null) return const SizedBox.shrink();

    final adding = chosen != null && paint.doubling;
    final after = chosen == null
        ? const <ShiftType>[]
        : adding
        ? [example, chosen]
        : [chosen];
    final title = adding
        ? l10n.paintPreviewTitleDouble
        : l10n.paintPreviewTitle;
    final effect = chosen == null
        ? l10n.paintPreviewErase
        : adding
        ? l10n.paintPreviewAdd
        : l10n.paintPreviewReplace;
    // The hours of the chosen shift: they moved here from the header
    // (decision 28), «Al tocar un día: Tarde → Mañana, 06:00–14:00».
    final times = chosen?.timeRange(AppDateFormat.of(context));
    final afterNames = after.isEmpty
        ? l10n.paintPreviewEmpty
        : after.map((s) => s.name).join(' + ');
    final spoken = times == null
        ? l10n.paintPreviewSpoken(title, example.name, afterNames, effect)
        : l10n.paintPreviewSpokenTimes(
            title,
            example.name,
            afterNames,
            times,
            effect,
          );

    return Semantics(
      key: const ValueKey('paint-preview'),
      container: true,
      label: spoken,
      excludeSemantics: true,
      child: AnimatedSwitcher(
        duration: Motion.of(context, Motion.state),
        switchInCurve: Motion.curve,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.centerLeft,
          children: [...previous, ?current],
        ),
        child: LayoutBuilder(
          // A new example, brush or mode fades in.
          key: ValueKey((example.id, chosen?.id, adding)),
          builder: (context, box) {
            final effectStyle = type.meta.copyWith(color: colors.textSecondary);
            final cells = [
              _MiniCell(
                key: const ValueKey('paint-preview-before'),
                shifts: [example],
              ),
              const SizedBox(width: Sp.s),
              Icon(
                MonthIcons.becomes,
                size: IconSize.inline,
                color: colors.textMuted,
              ),
              const SizedBox(width: Sp.s),
              _MiniCell(
                key: const ValueKey('paint-preview-after'),
                shifts: after,
              ),
            ];
            // The line gives up its parts from the last: the cells and the
            // hours of the shift are what matters, then «Al tocar un día»,
            // then the effect. Each shows only when it fits on the one line
            // (never cut, and the row never grows).
            final cellsWidth =
                _MiniCell.widthOf(context, [example]) +
                _MiniCell.widthOf(context, after) +
                IconSize.inline +
                2 * Sp.s;
            final timesStyle = AppTypography.tabular(
              type.meta.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            );
            final timesWidth = times == null
                ? 0.0
                : Sp.s + textWidth(context, times, timesStyle);
            final showTimes =
                times != null && cellsWidth + timesWidth <= box.maxWidth;
            var used = cellsWidth + (showTimes ? timesWidth : 0);
            final titleStyle = type.caption.copyWith(color: colors.textMuted);
            final titleWidth = textWidth(context, title, titleStyle) + Sp.s;
            final showTitle = !compact && used + titleWidth <= box.maxWidth;
            if (showTitle) used += titleWidth;
            final showEffect =
                used + Sp.s + textWidth(context, effect, effectStyle) <=
                box.maxWidth;
            // A window too narrow even for the two cells (split screen):
            // they wrap instead of overflowing.
            if (cellsWidth > box.maxWidth) {
              return Wrap(
                spacing: Sp.s,
                runSpacing: Sp.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final cell in cells)
                    if (cell is! SizedBox) cell,
                ],
              );
            }
            final row = Row(
              children: [
                if (showTitle) ...[
                  Text(
                    title,
                    key: const ValueKey('paint-preview-title'),
                    maxLines: 1,
                    softWrap: false,
                    style: titleStyle,
                  ),
                  const SizedBox(width: Sp.s),
                ],
                ...cells,
                if (showTimes) ...[
                  const SizedBox(width: Sp.s),
                  Text(
                    times,
                    key: const ValueKey('paint-preview-times'),
                    maxLines: 1,
                    softWrap: false,
                    style: timesStyle,
                  ),
                ],
                if (showEffect) ...[
                  const SizedBox(width: Sp.s),
                  Text(
                    effect,
                    key: const ValueKey('paint-preview-effect'),
                    maxLines: 1,
                    softWrap: false,
                    style: effectStyle,
                  ),
                ],
              ],
            );
            return row;
          },
        ),
      ),
    );
  }
}

/// A small day cell of the preview: the `tint` of the (first) shift, the
/// codes in their `ink` and the bottom bar in their `bar`, in equal segments
/// with two shifts, like the cells of the month. No shift: an empty day
/// (`surface` with a border).
class _MiniCell extends StatelessWidget {
  const _MiniCell({super.key, required this.shifts});

  final List<ShiftType> shifts;

  static TextStyle _style(BuildContext context) =>
      context.type.caption.copyWith(fontWeight: FontWeight.w800);

  /// The width the cell of [shifts] takes.
  static double widthOf(BuildContext context, List<ShiftType> shifts) {
    var codes = 0.0;
    for (var i = 0; i < shifts.length; i++) {
      codes += textWidth(context, shifts[i].code, _style(context));
      if (i > 0) codes += Sp.xs;
    }
    return math.max(Disc.m, codes + 2 * Sp.xs);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final brightness = colors.brightness;
    final swatches = [for (final s in shifts) s.swatch(brightness)];
    final style = _style(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: swatches.isEmpty ? colors.surface : swatches.first.tint,
        borderRadius: Rad.chipSmallRadius,
        border: swatches.isEmpty
            ? Border.all(color: colors.borderStrong)
            : null,
      ),
      child: ClipRRect(
        borderRadius: Rad.chipSmallRadius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: Disc.m,
            minHeight: Disc.m,
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Sp.xs,
                  Sp.xs,
                  Sp.xs,
                  Sp.xs + Sp.xs,
                ),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < shifts.length; i++) ...[
                        if (i > 0) const SizedBox(width: Sp.xs),
                        Text(
                          shifts[i].code,
                          maxLines: 1,
                          style: style.copyWith(color: swatches[i].ink),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (swatches.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: Sp.xs,
                  child: Row(
                    children: [
                      for (final swatch in swatches)
                        Expanded(child: ColoredBox(color: swatch.bar)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
