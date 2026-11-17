import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/icons/app_icons.dart';
import '../../../core/format/app_date_format.dart';
import '../../calendar/presentation/shift_format.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/choice_grid.dart';
import '../../../core/widgets/choice_pill.dart';
import '../../../core/widgets/choice_row.dart';
import '../../../core/widgets/value_row.dart';
import '../../calendar/application/schedule_controller.dart';
import '../application/pattern_wizard.dart';
import '../domain/pattern_blocks.dart';
import 'cycle_strip.dart';

class PatternBlockControls extends ConsumerWidget {
  const PatternBlockControls({
    super.key,
    required this.args,
    required this.index,
  });
  final PatternWizardArgs args;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wizard = ref.watch(patternWizardProvider(args));
    if (index >= wizard.blocks.length) return const SizedBox.shrink();
    final block = wizard.blocks[index];
    final controller = ref.read(patternWizardProvider(args).notifier);
    final l10n = context.l10n;
    void setDays(int days) {
      if (days == block.days) return;
      if (!controller.editBlocks(setBlockDays(wizard.blocks, index, days))) {
        ScaffoldMessenger.of(context)
            .showSnackBar(appSnackBar(content: Text(l10n.patternCycleLimit)));
      }
    }

    Future<void> enterNumber() async {
      final value = await _number(
        context,
        l10n.patternConsecutiveDays,
        block.days,
        maxPatternCycleDays - wizard.draft.length + block.days,
      );
      if (value != null && context.mounted) setDays(value);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Sp.s),
        Row(
          children: [
            IconButton(
              key: const ValueKey('block-minus'),
              tooltip: l10n.patternDayLess,
              onPressed: block.days <= 1 ? null : () => setDays(block.days - 1),
              icon: Icon(AppIcons.remove),
            ),
            TextButton(
              key: const ValueKey('block-edit-number'),
              style: TextButton.styleFrom(
                minimumSize: const Size(Sp.touch, Sp.touch),
                padding: const EdgeInsets.all(Sp.xs),
              ),
              onPressed: enterNumber,
              child: Text(
                '${block.days}',
                semanticsLabel: l10n.patternCycleDays(block.days),
              ),
            ),
            IconButton(
              key: const ValueKey('block-plus'),
              tooltip: l10n.patternDayMore,
              onPressed: () => setDays(block.days + 1),
              icon: Icon(AppIcons.add),
            ),
            Expanded(
              child: TextButton(
                key: const ValueKey('block-other-number'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.all(Sp.xs),
                ),
                onPressed: enterNumber,
                child: Text(l10n.patternOtherNumber),
              ),
            ),
          ],
        ),
        ChoiceGrid.pills(
          key: const ValueKey('block-shortcuts'),
          sizing: ChoiceGridSizing.wholeLabel,
          pills: [
            for (final days in [5, 7, 14, 21, 28])
              ChoicePill(
                key: ValueKey('block-days-$days'),
                label: days == 5
                    ? l10n.patternCycleDays(days)
                    : l10n.patternWeeks(days ~/ 7),
                selected: block.days == days,
                expand: true,
                reserveIcon: true,
                onTap: () => setDays(days),
              ),
          ],
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: IconButton(
            key: const ValueKey('block-options'),
            onPressed: () => showAppSheet<void>(
              context: context,
              padded: true,
              builder: (_) => _BlockActions(args: args, index: index),
            ),
            icon: Icon(AppIcons.more),
            tooltip: l10n.dayDetailMore,
          ),
        ),
      ],
    );
  }
}

class _BlockActions extends ConsumerWidget {
  const _BlockActions({required this.args, required this.index});
  final PatternWizardArgs args;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wizard = ref.watch(patternWizardProvider(args));
    final blocks = wizard.blocks;
    if (index >= blocks.length) return const SizedBox.shrink();
    final block = blocks[index];
    final controller = ref.read(patternWizardProvider(args).notifier);
    final palette = ref.watch(
      scheduleControllerProvider.select((s) => s.palette),
    );
    final l10n = context.l10n;
    // Taken now: after the sheet closes its own context is gone.
    final messenger = ScaffoldMessenger.of(context);
    void apply(
      PatternBlockEdit edit, {
      int? openIndex,
      bool closeSheet = true,
    }) {
      if (!controller.editBlocks(edit)) {
        messenger.showSnackBar(
          appSnackBar(content: Text(l10n.patternCycleLimit)),
        );
      } else {
        controller.showBlock(
          edit.blocks.isEmpty
              ? null
              : (openIndex ?? index).clamp(0, edit.blocks.length - 1),
        );
        if (closeSheet) Navigator.pop(context);
      }
    }

    void shifts(List<String> ids) {
      controller.replaceBlocks([
        ...blocks.take(index),
        PatternBlock(shiftIds: ids, days: block.days),
        ...blocks.skip(index + 1),
      ]);
      Navigator.pop(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.patternDuration(
            l10n.patternConsecutiveDays,
            patternDuration(context, block.days),
          ),
          style: context.type.bodyStrong,
        ),
        _ActionRow(
          key: const ValueKey('block-change-shift'),
          onTap: () => showAppSheet<void>(
            context: context,
            padded: true,
            builder: (sheetContext) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.patternChangeShift, style: context.type.bodyStrong),
                for (final shift in palette)
                  ChoiceRow(
                    key: ValueKey('block-replace-${shift.id}'),
                    selected:
                        block.shiftIds.length == 1 &&
                        block.shiftIds.single == shift.id,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      shifts([shift.id]);
                    },
                    label: '${shift.code} · ${shift.name}',
                    subtitle:
                        shift.timeRange(AppDateFormat.of(context)) ??
                        l10n.summaryNoTimes,
                  ),
                _ActionRow(
                  key: const ValueKey('block-no-shift'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    shifts([]);
                  },
                  label: l10n.calendarNoShift,
                ),
              ],
            ),
          ),
          label: l10n.patternChangeShift,
        ),
        _ActionRow(
          key: const ValueKey('block-same-day'),
          onTap: () => showAppSheet<void>(
            context: context,
            padded: true,
            builder: (sheetContext) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.patternBuilderSameDay,
                  style: context.type.bodyStrong,
                ),
                for (final shift in palette)
                  if (!block.shiftIds.contains(shift.id))
                    ChoiceRow(
                      key: ValueKey('block-add-${shift.id}'),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        shifts([...block.shiftIds, shift.id]);
                      },
                      label: '${shift.code} · ${shift.name}',
                      subtitle:
                          shift.timeRange(AppDateFormat.of(context)) ??
                          l10n.summaryNoTimes,
                    ),
              ],
            ),
          ),
          label: l10n.patternBuilderSameDay,
        ),
        _ActionRow(
          key: const ValueKey('block-up'),
          onTap: index == 0
              ? null
              : () => apply(
                  moveBlock(blocks, index, index - 1),
                  openIndex: index - 1,
                ),
          label: l10n.patternBlockUp,
        ),
        _ActionRow(
          key: const ValueKey('block-down'),
          onTap: index == blocks.length - 1
              ? null
              : () => apply(
                  moveBlock(blocks, index, index + 1),
                  openIndex: index + 1,
                ),
          label: l10n.patternBlockDown,
        ),
        _ActionRow(
          key: const ValueKey('block-duplicate'),
          onTap: () =>
              apply(duplicateBlock(blocks, index), openIndex: index + 1),
          label: l10n.patternBlockDuplicate,
        ),
        _ActionRow(
          key: const ValueKey('block-split'),
          onTap: block.days < 2
              ? null
              : () async {
                  final after = await _number(
                    context,
                    l10n.patternBlockSplitAfter,
                    block.days ~/ 2,
                    block.days - 1,
                  );
                  if (after != null && context.mounted) {
                    apply(splitBlock(blocks, index, after));
                  }
                },
          label: l10n.patternBlockSplit,
        ),
        _ActionRow(
          key: const ValueKey('block-repeat'),
          onTap: () async {
            // The sheet closes first: it stayed dimmed behind the dialog until
            // the dialog was answered (1.2.0 QA, iPad F3). The navigator's own
            // context outlives the sheet.
            final navigator = Navigator.of(context);
            final dialogContext = navigator.context;
            navigator.pop();
            final times = await showDialog<int>(
              context: dialogContext,
              builder: (_) => _RepeatDialog(blocks: blocks, index: index),
            );
            if (times != null && times > 1) {
              apply(repeatFrom(blocks, index, times), closeSheet: false);
            }
          },
          label: l10n.patternRepeatFrom,
        ),
        _ActionRow(
          key: const ValueKey('block-remove'),
          destructive: true,
          onTap: () => apply(removeBlock(blocks, index)),
          label: l10n.patternBlockRemove,
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    super.key,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });
  final String label;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = onTap == null
        ? context.colors.disabledContent
        : destructive
        ? context.colors.danger
        : context.colors.textPrimary;
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: Rad.rowRadius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: ChoiceRow.minHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Sp.xs,
              vertical: Sp.s,
            ),
            child: ValueRow(
              title: Text(
                label,
                style: context.type.body.copyWith(color: color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RepeatDialog extends StatefulWidget {
  const _RepeatDialog({required this.blocks, required this.index});
  final List<PatternBlock> blocks;
  final int index;
  @override
  State<_RepeatDialog> createState() => _RepeatDialogState();
}

class _RepeatDialogState extends State<_RepeatDialog> {
  int _times = 1;
  bool _limit = false;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final edit = repeatFrom(widget.blocks, widget.index, _times);
    return AlertDialog(
      scrollable: true,
      title: Text(l10n.patternRepeatFrom),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.patternRepeatHelp),
          const SizedBox(height: Sp.m),
          Row(
            children: [
              IconButton(
                key: const ValueKey('repeat-minus'),
                tooltip: l10n.patternRepeatLess,
                onPressed: _times == 1
                    ? null
                    : () => setState(() {
                        _times--;
                        _limit = false;
                      }),
                icon: Icon(AppIcons.remove),
              ),
              Expanded(
                child: Text(
                  '$_times',
                  textAlign: TextAlign.center,
                  style: context.type.bodyStrong,
                ),
              ),
              IconButton(
                key: const ValueKey('repeat-plus'),
                tooltip: l10n.patternRepeatMore,
                onPressed: () => setState(() {
                  final next = repeatFrom(
                    widget.blocks,
                    widget.index,
                    _times + 1,
                  );
                  _limit = next.exceedsLimit;
                  if (!_limit) _times++;
                }),
                icon: Icon(AppIcons.add),
              ),
            ],
          ),
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.patternRepeatTotal(
                _times,
                l10n.patternCycleDays(edit.requestedDays),
              ),
              key: const ValueKey('repeat-total'),
            ),
          ),
          if (_limit)
            Semantics(liveRegion: true, child: Text(l10n.patternCycleLimit)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(
          key: const ValueKey('repeat-confirm'),
          onPressed: _times == 1 ? null : () => Navigator.pop(context, _times),
          child: Text(l10n.patternRepeatConfirm),
        ),
      ],
    );
  }
}

Future<int?> _number(
  BuildContext context,
  String title,
  int initial,
  int max,
) => showDialog<int>(
  context: context,
  builder: (_) => _NumberDialog(title: title, initial: initial, max: max),
);

class _NumberDialog extends StatefulWidget {
  const _NumberDialog({
    required this.title,
    required this.initial,
    required this.max,
  });
  final String title;
  final int initial;
  final int max;
  @override
  State<_NumberDialog> createState() => _NumberDialogState();
}

class _NumberDialogState extends State<_NumberDialog> {
  late final _text = TextEditingController(text: '${widget.initial}');
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = int.tryParse(_text.text);
    final valid = value != null && value >= 1 && value <= widget.max;
    final l10n = context.l10n;
    return AlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: TextField(
        key: const ValueKey('block-number'),
        controller: _text,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: l10n.patternConsecutiveDays,
          helperText: valid ? l10n.patternNumberRange(widget.max) : null,
          helperMaxLines: 3,
          errorText: valid ? null : l10n.patternNumberRange(widget.max),
          errorMaxLines: 3,
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: valid ? (_) => Navigator.pop(context, value) : null,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(
          key: const ValueKey('block-number-confirm'),
          onPressed: valid ? () => Navigator.pop(context, value) : null,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
