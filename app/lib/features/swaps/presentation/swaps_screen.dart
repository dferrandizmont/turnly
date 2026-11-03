import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/app_date_format.dart';
import '../../../core/icons/app_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/content_app_bar.dart';
import '../../../core/widgets/empty_illustration.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/page_body.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/value_row.dart';
import '../../calendar/application/schedule_controller.dart';
import '../../calendar/presentation/shift_format.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../../summary/presentation/summary_format.dart';
import '../application/swaps_controller.dart';
import '../domain/shift_swap.dart';
import '../domain/swap_ledger.dart';
import 'swap_format.dart';
import 'swap_icons.dart';
import 'swap_sheet.dart';
import 'swap_stage_badge.dart';

/// «Libro de cambios» (`/cambios`, P4): the changes of shift registered with
/// the colleagues. The balance of each one («me debe», «le debo») comes
/// first, with the ones still pending in front; then the list of changes
/// with their state, and the sheet that creates or edits one.
///
/// The screen only shows what [swapLedgerProvider] computes and opens the
/// sheet; applying a change to the calendar is an action of every change.
class SwapsScreen extends ConsumerWidget {
  const SwapsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ledger = ref.watch(swapLedgerProvider);
    final hasChanges = ledger.value?.swaps.isNotEmpty ?? false;

    return Scaffold(
      appBar: ContentAppBar.adaptive(
        context,
        title: Text(l10n.swapTitle),
      ),
      body: PageBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Sp.page,
            Sp.s,
            Sp.page,
            Sp.section,
          ),
          children: [
            ...ledger.when(
              loading: () => [
                const SizedBox(
                  height: SkeletonList.placeholderHeight,
                  child: SkeletonList(header: false),
                ),
              ],
              error: (_, _) => [
                ErrorState(
                  compact: true,
                  onRetry: () => ref.invalidate(swapLedgerProvider),
                ),
              ],
              data: (data) => data.swaps.isEmpty
                  ? [
                      Padding(
                        key: const ValueKey('swap-empty'),
                        padding: const EdgeInsets.symmetric(vertical: Sp.x3),
                        child: EmptyState(
                          icon: SwapIcons.swaps,
                          illustration: const EmptyIllustration(
                            kind: EmptyIllustrationKind.calendar,
                          ),
                          title: l10n.swapEmptyTitle,
                          message: l10n.swapEmptyBody,
                          actionLabel: l10n.swapAdd,
                          actionIcon: AppIcons.add,
                          primaryAction: true,
                          onAction: () => showSwapSheet(context),
                        ),
                      ),
                    ]
                  : _ledger(context, ref, data),
            ),
          ],
        ),
      ),
      bottomNavigationBar: hasChanges ? _addBar(context) : null,
    );
  }

  /// The button that adds a change, always in sight under the list.
  Widget _addBar(BuildContext context) {
    final l10n = context.l10n;
    return Align(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Sp.maxContentWidth),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Sp.page, Sp.s, Sp.page, Sp.l),
            child: PrimaryButton(
              key: const ValueKey('swap-add'),
              label: l10n.swapAdd,
              icon: AppIcons.add,
              onPressed: () => showSwapSheet(context),
            ),
          ),
        ),
      ),
    );
  }

  /// The balances and the list of changes.
  List<Widget> _ledger(BuildContext context, WidgetRef ref, SwapLedger ledger) {
    final l10n = context.l10n;
    return [
      if (ledger.balances.isNotEmpty) ...[
        Semantics(
          header: true,
          child: Text(
            l10n.swapBalancesTitle,
            style: context.type.headline,
          ),
        ),
        const SizedBox(height: Sp.m),
        _BalanceCard(balances: ledger.balances),
        const SizedBox(height: Sp.section),
      ],
      Semantics(
        header: true,
        child: Text(
          l10n.swapChangesTitle,
          style: context.type.headline,
        ),
      ),
      const SizedBox(height: Sp.m),
      for (final swap in ledger.swaps) ...[
        _SwapRow(swap: swap),
        const SizedBox(height: Sp.card),
      ],
    ];
  }
}

/// The balance of every colleague, one card: who owes what, with the ones
/// that still have something pending in front (the logic sorts them).
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balances});

  final List<SwapBalance> balances;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      key: const ValueKey('swap-balances'),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < balances.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: Sp.l,
                endIndent: Sp.l,
                color: colors.border,
              ),
            _BalanceRow(balance: balances[i]),
          ],
        ],
      ),
    );
  }
}

/// One colleague: their name and what they owe (or what is owed to them).
class _BalanceRow extends StatelessWidget {
  const _BalanceRow({required this.balance});

  final SwapBalance balance;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final text = swapBalanceText(context.l10n, balance);
    final pending = !balance.isSettled;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: Sp.touch),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Sp.l, vertical: Sp.m),
        child: ValueRow(
          title: Text(
            balance.colleague,
            style: type.bodyStrong,
          ),
          value: Text(
            text,
            style: type.body.copyWith(
              color: pending ? colors.accentText : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// One change: the day, with whom, who owes it, its state and the shifts of
/// each side. The menu holds the actions (edit, mark it returned or settled,
/// apply it to the calendar, remove it).
class _SwapRow extends ConsumerWidget {
  const _SwapRow({required this.swap});

  final ShiftSwap swap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    final palette = ref.watch(
      scheduleControllerProvider.select((s) => s.palette),
    );

    List<ShiftType> typesOf(List<String>? ids) {
      if (ids == null || ids.isEmpty) return const [];
      return [
        for (final id in ids) ...palette.where((t) => t.id == id).take(1),
      ];
    }

    final given = typesOf(swap.givenShiftTypeIds);
    final received = typesOf(swap.receivedShiftTypeIds);

    // What the row says, in one go for the reader: the day, with whom, which
    // side owes it and its state (never colour alone).
    final label = [
      formatRangeDate(l10n.localeName, swap.date),
      swap.colleague,
      swapDirectionText(l10n, swap.direction),
      swapStageText(l10n, swap.stage),
    ].join(' · ');

    return AppCard(
      key: ValueKey('swap-card-${swap.id}'),
      semanticLabel: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The state sits on the first line (the date); the menu is centred
          // on the height of the card.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatRangeDate(l10n.localeName, swap.date),
                        key: ValueKey('swap-date-${swap.id}'),
                        style: type.bodyStrong,
                      ),
                      const SizedBox(height: Sp.hair),
                      Text(
                        '${swap.colleague} · ${swapDirectionText(l10n, swap.direction)}',
                        key: ValueKey('swap-who-${swap.id}'),
                        style: type.meta.copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Sp.s),
                Align(
                  alignment: Alignment.topLeft,
                  child: SwapStageBadge(stage: swap.stage, swapId: swap.id),
                ),
                Align(
                  alignment: Alignment.center,
                  child: _SwapMenu(swap: swap),
                ),
              ],
            ),
          ),
          if (given.isNotEmpty || received.isNotEmpty) ...[
            const SizedBox(height: Sp.s),
            Wrap(
              key: ValueKey('swap-shifts-${swap.id}'),
              spacing: Sp.xs,
              runSpacing: Sp.xs,
              children: [
                for (final shift in given)
                  _SwapShiftPill(
                    label: '${l10n.swapGivesLabel}: ${shift.name}',
                    shift: shift,
                  ),
                for (final shift in received)
                  _SwapShiftPill(
                    label: '${l10n.swapReceivesLabel}: ${shift.name}',
                    shift: shift,
                  ),
              ],
            ),
          ],
          if (swap.note != null && swap.note!.trim().isNotEmpty) ...[
            const SizedBox(height: Sp.xs),
            Text(
              swap.note!,
              key: ValueKey('swap-note-${swap.id}'),
              style: type.meta.copyWith(color: colors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// A shift of a change: its colour, its code and its hours, as the month
/// draws it (never colour alone). The label says which side of the change it
/// names («Cedes: Mañana»).
class _SwapShiftPill extends StatelessWidget {
  const _SwapShiftPill({required this.label, required this.shift});

  final String label;
  final ShiftType shift;

  @override
  Widget build(BuildContext context) {
    final swatch = shift.swatch(context.colors.brightness);
    final caption = context.type.caption;
    final times = shift.timeRange(AppDateFormat.of(context));
    return DecoratedBox(
      decoration: BoxDecoration(
        color: swatch.disc,
        borderRadius: Rad.chipSmallRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Sp.s, vertical: Sp.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  shift.code,
                  style: caption.copyWith(
                    color: swatch.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: Sp.xs),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: caption.copyWith(
                      color: swatch.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (times != null)
              Text(
                times,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.tabular(
                  caption.copyWith(color: swatch.ink),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// What can be done with a change.
enum _SwapAction { edit, markReturned, settle, reopen, apply, unapply, remove }

/// The menu of a change.
class _SwapMenu extends ConsumerWidget {
  const _SwapMenu({required this.swap});

  final ShiftSwap swap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;

    PopupMenuItem<_SwapAction> item(
      _SwapAction action,
      String key,
      IconData icon,
      String label,
    ) => PopupMenuItem(
          key: ValueKey(key),
          value: action,
          child: Row(
            children: [
              Icon(icon, size: IconSize.button, color: colors.textSecondary),
              const SizedBox(width: Sp.m),
              Flexible(child: Text(label)),
            ],
          ),
        );

    return PopupMenuButton<_SwapAction>(
      key: ValueKey('swap-menu-${swap.id}'),
      tooltip: l10n.swapMenuTooltip,
      icon: Icon(AppIcons.more, color: colors.textSecondary),
      onSelected: (action) => _run(context, ref, action),
      itemBuilder: (_) => [
        item(
          _SwapAction.edit,
          'swap-menu-edit',
          AppIcons.edit,
          l10n.swapEditTooltip(swap.colleague),
        ),
        if (!swap.isReturned) ...[
          item(
            _SwapAction.markReturned,
            'swap-menu-returned',
            SwapIcons.returned,
            l10n.swapMarkReturned,
          ),
          item(
            _SwapAction.settle,
            'swap-menu-settle',
            AppIcons.check,
            l10n.swapMarkSettled,
          ),
        ] else
          item(
            _SwapAction.reopen,
            'swap-menu-reopen',
            AppIcons.undo,
            l10n.swapReopen,
          ),
        item(
          _SwapAction.apply,
          'swap-menu-apply',
          AppIcons.paint,
          l10n.swapApplyToCalendar,
        ),
        item(
          _SwapAction.unapply,
          'swap-menu-unapply',
          AppIcons.erase,
          l10n.swapUndoFromCalendar,
        ),
        item(
          _SwapAction.remove,
          'swap-menu-remove',
          AppIcons.remove,
          l10n.swapRemove,
        ),
      ],
    );
  }

  /// Runs the action and tells how it went. Every action that touches the
  /// calendar is one undo step, so «Deshacer» takes it back.
  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    _SwapAction action,
  ) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(swapLedgerProvider.notifier);
    final schedule = ref.read(scheduleControllerProvider.notifier);
    switch (action) {
      case _SwapAction.edit:
        await showSwapSheet(context, swap: swap);
      case _SwapAction.markReturned:
        final date = await _pickReturnDate(context, swap);
        if (date == null) return;
        await controller.save(
          swap.copyWith(
            returnDate: date,
            updatedAt: ref.read(clockProvider)().millisecondsSinceEpoch,
          ),
        );
        _say(messenger, l10n.swapMarkedReturned);
      case _SwapAction.settle:
        await controller.settle(swap.id);
        _say(messenger, l10n.swapMarkedSettled);
      case _SwapAction.reopen:
        await controller.reopen(swap.id);
        _say(messenger, l10n.swapReopened);
      case _SwapAction.apply:
        final step = controller.applyToCalendar(swap);
        if (step == null) {
          _say(messenger, l10n.swapNothingToApply);
          return;
        }
        _say(
          messenger,
          l10n.swapApplied,
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => schedule.undoIfLast(step),
          ),
        );
      case _SwapAction.unapply:
        final step = controller.undoFromCalendar(swap);
        if (step == null) {
          _say(messenger, l10n.swapNotApplied);
          return;
        }
        _say(
          messenger,
          l10n.swapUnapplied,
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => schedule.undoIfLast(step),
          ),
        );
      case _SwapAction.remove:
        await controller.remove(swap.id);
        _say(
          messenger,
          l10n.swapRemoved,
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => controller.save(swap),
          ),
        );
    }
  }
}

/// The day the favour comes back, chosen in the picker.
Future<CivilDate?> _pickReturnDate(BuildContext context, ShiftSwap swap) async {
  final initial = swap.returnDate ?? swap.date;
  final picked = await showDatePicker(
    context: context,
    initialDate: DateTime(initial.year, initial.month, initial.day),
    firstDate: DateTime(initial.year - 2),
    lastDate: DateTime(initial.year + 3, 12, 31),
    helpText: context.l10n.swapMarkReturnedTitle,
  );
  if (picked == null) return null;
  return CivilDate.fromDateTime(picked);
}

/// A notice of the screen, with «Deshacer» when there is something to undo.
void _say(
  ScaffoldMessengerState messenger,
  String message, {
  SnackBarAction? action,
}) => messenger
  ..hideCurrentSnackBar()
  ..showSnackBar(
    appSnackBar(
      context: messenger.context,
      content: Text(message),
      action: action,
    ),
  );
