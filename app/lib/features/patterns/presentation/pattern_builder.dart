import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/app_date_format.dart';
import '../../../core/format/text_measure.dart';
import '../../../core/format/text_wrap.dart';
import '../../../core/icons/app_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../calendar/application/schedule_controller.dart';
import '../../calendar/presentation/shift_format.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../application/pattern_wizard.dart';
import '../domain/pattern_blocks.dart';
import '../domain/pattern_catalog.dart';
import 'cycle_strip.dart';
import 'pattern_block_editor.dart';

/// Keeps the palette below the scrolling blocks. With little vertical room the
/// palette joins the page so large text still leaves the sequence reachable.
class PatternBuilderViewport extends ConsumerWidget {
  const PatternBuilderViewport({super.key, required this.args, this.header});
  final PatternWizardArgs args;
  final Widget? header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(
      scheduleControllerProvider.select((s) => s.palette),
    );
    final full = ref.watch(
      patternWizardProvider(args)
          .select((s) => s.draft.length >= maxPatternCycleDays),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final regular = _PaletteLayout.of(
          context,
          palette,
          constraints.maxWidth - Sp.page * 2 - Sp.m,
        );
        final compact = constraints.maxHeight < regular.height + Sp.touch * 4;
        final layout = compact
            ? _PaletteLayout.of(
                context,
                palette,
                constraints.maxWidth - Sp.page * 2 - Sp.m,
                compact: true,
              )
            : regular;
        final heading = TextPainter(
          text: TextSpan(
            text: [
              if (full) context.l10n.patternCycleLimit,
              context.l10n.patternAddBlock,
            ].join('\n'),
            style: effectiveTextStyle(context, context.type.meta),
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth - Sp.page * 2);
        final paletteHeight = layout.height + heading.height.ceilToDouble();
        heading.dispose();
        final fixed = constraints.maxHeight >= paletteHeight + Sp.touch * 4;
        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                key: const ValueKey('pattern-step-choose'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ?header,
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Sp.page,
                        Sp.s,
                        Sp.page,
                        Sp.section,
                      ),
                      child: PatternBuilder(args: args, showPalette: !fixed),
                    ),
                  ],
                ),
              ),
            ),
            if (fixed)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Sp.page),
                child: PatternBuilderPalette(args: args, compact: compact),
              ),
          ],
        );
      },
    );
  }
}

class PatternBuilder extends ConsumerStatefulWidget {
  const PatternBuilder({
    super.key,
    required this.args,
    this.showPalette = true,
  });
  final PatternWizardArgs args;
  final bool showPalette;

  @override
  ConsumerState<PatternBuilder> createState() => _PatternBuilderState();
}

class _PatternBuilderState extends ConsumerState<PatternBuilder> {
  late final TextEditingController _name;
  bool _confirming = false;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: ref.read(patternWizardProvider(widget.args)).draftName,
    );
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final wizard = ref.watch(patternWizardProvider(widget.args));
    final controller = ref.read(patternWizardProvider(widget.args).notifier);
    final schedule = ref.watch(
      scheduleControllerProvider.select((s) => s.schedule),
    );
    ShiftType? shiftOf(String id) => shiftTypeForDisplay(schedule, id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          key: const ValueKey('builder-back'),
          onPressed: () async {
            if (_confirming) return;
            _confirming = true;
            final discard = await confirmDiscardSequence(context, controller);
            if (mounted && discard) controller.stopBuilding();
            _confirming = false;
          },
          icon: Icon(AppIcons.back, size: IconSize.button),
          label: Text(l10n.patternBuilderBack),
        ),
        LabeledField(
          label: l10n.patternBuilderName,
          child: TextField(
            key: const ValueKey('builder-name'),
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 40,
            decoration: InputDecoration(
              hintText: l10n.patternBuilderDefaultName,
              counterText: '',
            ),
            onChanged: controller.setName,
          ),
        ),
        const SizedBox(height: Sp.section),
        Text(l10n.patternBuilderSequence, style: context.type.bodyStrong),
        Text(
          patternDuration(context, wizard.draft.length),
          key: const ValueKey('builder-length'),
          style: context.type.meta,
        ),
        const SizedBox(height: Sp.m),
        if (wizard.draft.isEmpty)
          Text(l10n.patternBlocksHelp, style: context.type.meta),
        for (final (i, block) in wizard.blocks.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: Sp.s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppCard(
                  expanded: wizard.openBlock == i,
                  key: ValueKey('builder-block-$i'),
                  semanticLabel: l10n.patternBlockTitle(
                    block.shiftIds.isEmpty
                        ? l10n.calendarNoShift
                        : block.shiftIds
                              .map((id) => shiftOf(id)?.name ?? id)
                              .join(' + '),
                    l10n.patternCycleDays(block.days),
                  ),
                  selected: wizard.openBlock == i,
                  borderColor: wizard.openBlock == i
                      ? context.colors.todayRing
                      : null,
                  onTap: () => controller.toggleBlock(i),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: Sp.touch),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.patternBlockTitle(
                            block.shiftIds.isEmpty
                                ? l10n.calendarNoShift
                                : block.shiftIds
                                      .map((id) => shiftOf(id)?.name ?? id)
                                      .join(' + '),
                            l10n.patternCycleDays(block.days),
                          ),
                          style: context.type.bodyStrong,
                        ),
                        for (final id in block.shiftIds)
                          if (shiftOf(id) case final shift?)
                            PatternShiftLabel(shift: shift),
                        Text(
                          patternDuration(context, block.days),
                          style: context.type.meta,
                        ),
                      ],
                    ),
                  ),
                ),
                if (wizard.openBlock == i)
                  PatternBlockControls(args: widget.args, index: i),
              ],
            ),
          ),
        Wrap(
          spacing: Sp.s,
          runSpacing: Sp.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton(
              key: const ValueKey('builder-undo'),
              tooltip: l10n.undo,
              onPressed: wizard.canUndoDraft ? controller.undoDraft : null,
              icon: Icon(AppIcons.undo),
            ),
            IconButton(
              key: const ValueKey('builder-clear'),
              tooltip: l10n.patternBuilderClear,
              onPressed: wizard.draft.isEmpty ? null : controller.clearDraft,
              icon: Icon(AppIcons.erase),
            ),
          ],
        ),
        if (wizard.draft.isNotEmpty) ...[
          const SizedBox(height: Sp.m),
          Text(l10n.patternYourCycle, style: context.type.bodyStrong),
          CycleStrip(
            steps: wizard.draft,
            shiftOf: shiftOf,
            keyPrefix: 'builder-cycle-',
          ),
        ],
        if (widget.showPalette) ...[
          const SizedBox(height: Sp.l),
          PatternBuilderPalette(args: widget.args, scrollable: false),
        ],
      ],
    );
  }
}

class _PaletteLayout {
  const _PaletteLayout(this.columns, this.rowHeight, this.rows);
  final int columns;
  final double rowHeight;
  final int rows;
  double get height => rowHeight * rows + Sp.m;
  static _PaletteLayout of(
    BuildContext context,
    List<ShiftType> palette,
    double width, {
    bool compact = false,
  }) {
    final style = context.type.caption;
    final format = AppDateFormat.of(context);
    final minWidth = palette.fold<double>(
      Sp.touch * 2,
      (value, s) => math.max(
        value,
        math.max(
              longestWordWidth(context, s.name, style),
              (s.timeRange(format) ?? context.l10n.summaryNoTimes)
                  .split(' · ')
                  .fold<double>(
                    0,
                    (width, time) =>
                        math.max(width, textWidth(context, time, style)),
                  ),
            ) +
            Sp.l,
      ),
    );
    final columns = compact
        ? 1
        : math.max(1, math.min(4, (width / minWidth).floor()));
    final cellWidth =
        width / columns - Sp.s - (compact ? Disc.toolPuck + Sp.s : 0);
    final lines = palette.fold<int>(
      1,
      (value, s) => math.max(
        value,
        textLineCount(context, s.name, style, cellWidth) +
            textLineCount(
              context,
              keepTimeRangesTogether(
                s.timeRange(format) ?? context.l10n.summaryNoTimes,
              ),
              style,
              cellWidth,
            ),
      ),
    );
    final rowHeight =
        (compact ? 0 : Disc.toolPuck) +
        Sp.l +
        lines *
            MediaQuery.textScalerOf(context).scale(style.fontSize!) *
            (style.height ?? 1);
    return _PaletteLayout(
      columns,
      math.max(Sp.touch, rowHeight),
      compact ? 1 : 2,
    );
  }
}

/// At most two rows, with an explicit vertical scrollbar when more shifts fit
/// below. The height is measured at the reader's actual font size.
class PatternBuilderPalette extends ConsumerStatefulWidget {
  const PatternBuilderPalette({
    super.key,
    required this.args,
    this.compact = false,
    this.scrollable = true,
  });
  final PatternWizardArgs args;
  final bool compact;
  final bool scrollable;
  @override
  ConsumerState<PatternBuilderPalette> createState() =>
      _PatternBuilderPaletteState();
}

class _PatternBuilderPaletteState extends ConsumerState<PatternBuilderPalette> {
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final wizard = ref.watch(patternWizardProvider(widget.args));
    final controller = ref.read(patternWizardProvider(widget.args).notifier);
    final palette = ref.watch(
      scheduleControllerProvider.select((s) => s.palette),
    );
    final full = wizard.draft.length >= maxPatternCycleDays;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (full) Text(l10n.patternCycleLimit, style: context.type.meta),
        Text(l10n.patternAddBlock, style: context.type.meta),
        LayoutBuilder(
          builder: (context, constraints) {
            final layout = _PaletteLayout.of(
              context,
              palette,
              constraints.maxWidth - Sp.m,
              compact: widget.compact,
            );
            final tiles = Wrap(
              runSpacing: Sp.xs,
              children: [
                for (final shift in palette)
                  Builder(
                    builder: (context) {
                      final swatch = shift.swatch(context.colors.brightness);
                      final VoidCallback? addBlock = full
                          ? null
                          : () {
                              if (!controller.appendShift(shift.id)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  appSnackBar(
                                    content: Text(l10n.patternCycleLimit),
                                  ),
                                );
                              }
                            };
                      final labelStyle = context.type.caption.copyWith(
                        color: full ? context.colors.disabledContent : null,
                      );
                      final badge = Container(
                        width: Disc.toolPuck,
                        height: Disc.toolPuck,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: full
                              ? context.colors.surfaceRaised
                              : swatch.disc,
                          borderRadius: Rad.squareRadius(Disc.toolPuck),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            shift.code,
                            style: context.type.bodyStrong.copyWith(
                              color: full
                                  ? context.colors.disabledContent
                                  : swatch.ink,
                            ),
                          ),
                        ),
                      );
                      final labels = Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: widget.compact
                            ? CrossAxisAlignment.start
                            : CrossAxisAlignment.center,
                        children: [
                          Text(
                            shift.name,
                            style: labelStyle,
                            textAlign: widget.compact
                                ? TextAlign.start
                                : TextAlign.center,
                          ),
                          Text(
                            keepTimeRangesTogether(
                              shift.timeRange(AppDateFormat.of(context)) ??
                                  l10n.summaryNoTimes,
                            ),
                            style: labelStyle,
                            textAlign: widget.compact
                                ? TextAlign.start
                                : TextAlign.center,
                          ),
                        ],
                      );
                      return SizedBox(
                        width: (constraints.maxWidth - Sp.m) / layout.columns,
                        height: layout.rowHeight,
                        child: Semantics(
                          button: true,
                          enabled: !full,
                          onTap: addBlock,
                          label: l10n.patternBuilderAdd(
                            shift.nameWithTimes(
                              l10n,
                              AppDateFormat.of(context),
                            ),
                          ),
                          excludeSemantics: true,
                          child: InkWell(
                            key: ValueKey('builder-add-${shift.id}'),
                            borderRadius: Rad.inputRadius,
                            onTap: addBlock,
                            child: widget.compact
                                ? Row(
                                    children: [
                                      badge,
                                      const SizedBox(width: Sp.s),
                                      Expanded(child: labels),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      badge,
                                      const SizedBox(height: Sp.xs),
                                      labels,
                                    ],
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            );
            if (!widget.scrollable) {
              return Padding(
                key: const ValueKey('builder-palette'),
                padding: const EdgeInsets.only(right: Sp.m),
                child: tiles,
              );
            }
            return SizedBox(
              height: layout.height,
              child: Scrollbar(
                controller: _scroll,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  key: const ValueKey('builder-palette'),
                  controller: _scroll,
                  padding: const EdgeInsets.only(right: Sp.m),
                  child: tiles,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Shared by system/app-bar Back and the builder's return to the catalogue.
Future<bool> confirmDiscardSequence(
  BuildContext context,
  PatternWizardController controller,
) async {
  if (!controller.hasDraftChanges) return true;
  FocusScope.of(context).unfocus();
  final l10n = context.l10n;
  return showConfirmDialog(
    context,
    title: l10n.patternDiscardTitle,
    confirmLabel: l10n.discardChangesConfirm,
    cancelLabel: l10n.discardChangesKeep,
    destructive: true,
    scrollable: true,
  );
}
