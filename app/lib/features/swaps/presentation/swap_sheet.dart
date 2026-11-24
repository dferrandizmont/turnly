import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/app_date_format.dart';
import '../../../core/icons/app_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/choice_grid.dart';
import '../../../core/widgets/choice_pill.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../calendar/application/schedule_controller.dart';
import '../../calendar/presentation/day_cell.dart' show textHeight;
import '../../calendar/presentation/shift_format.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../../summary/presentation/summary_format.dart';
import '../application/swaps_controller.dart';
import '../application/swaps_providers.dart';
import '../domain/shift_swap.dart';
import '../domain/swap_application.dart';
import '../domain/swap_schedule_plan.dart';
import 'swap_apply.dart';

/// Opens the sheet that creates a change (when [swap] is `null`) or edits the
/// one of [swap]: with whom, who owes the shift, the day the shift is given
/// and the day it comes back, the shifts of each side, and a note.
///
/// [date] is the day the change starts on (the day of the detail when it is
/// opened from there). It saves through [swapLedgerProvider] and says so
/// when the write fails; the screen behind refreshes by itself.
Future<void> showSwapSheet(
  BuildContext context, {
  ShiftSwap? swap,
  CivilDate? date,
}) => showAppSheet<void>(
  context: context,
  // The sheet lays itself out: the form scrolls and «Guardar» stays under it
  // (see [SwapSheet]), so it is within reach however short the screen or
  // large the text (QA M3: seven swipes in landscape at x2.0).
  builder: (_) => SwapSheet(swap: swap, date: date),
);

/// The form of a change of shift.
class SwapSheet extends ConsumerStatefulWidget {
  const SwapSheet({super.key, this.swap, this.date});

  /// The change being edited; `null` for a new one.
  final ShiftSwap? swap;

  /// The day the change starts on, when it is new.
  final CivilDate? date;

  @override
  ConsumerState<SwapSheet> createState() => _SwapSheetState();
}

class _SwapSheetState extends ConsumerState<SwapSheet> {
  late final TextEditingController _colleague = TextEditingController(
    text: widget.swap?.colleague ?? '',
  );
  late final TextEditingController _note = TextEditingController(
    text: widget.swap?.note ?? '',
  );

  late SwapDirection _direction =
      widget.swap?.direction ?? SwapDirection.theyOwe;

  /// The day the shift is given (always the first day of the change).
  late CivilDate _date =
      widget.swap?.date ??
      widget.date ??
      CivilDate.fromDateTime(ref.read(clockProvider)());

  /// The day the shift comes back; `null` when nobody paid it back yet.
  late CivilDate? _returnDate = widget.swap?.returnDate;

  late final Set<String> _given = {...?widget.swap?.givenShiftTypeIds};
  late final Set<String> _received = {...?widget.swap?.receivedShiftTypeIds};

  /// Whether the person touched the shifts of each side: an untouched side
  /// keeps what was stored (an empty list means «no shift», not «not
  /// recorded»).
  bool _givenTouched = false;
  bool _receivedTouched = false;

  /// What the person chose for «Cambiar también mi cuadrante»; `null` while
  /// they have not touched it (it then follows [_applyByDefault]).
  bool? _applyChoice;
  bool _confirmingRemoval = false;

  bool _showErrors = false;
  bool _saving = false;

  @override
  void dispose() {
    _colleague.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _nameOk {
    final name = _colleague.text.trim();
    return name.isNotEmpty && name.length <= maxSwapColleagueLength;
  }

  /// The shifts of the first day, `null` when they are not recorded.
  List<String>? get _givenIds {
    if (!_givenTouched) return widget.swap?.givenShiftTypeIds;
    return _given.isEmpty ? null : _given.toList();
  }

  /// The shifts of the second day, `null` when they are not recorded.
  List<String>? get _receivedIds {
    if (!_receivedTouched) return widget.swap?.receivedShiftTypeIds;
    return _received.isEmpty ? null : _received.toList();
  }

  /// The change as the form has it now: what would be saved, for the
  /// calendar to say whether applying it would change anything.
  ShiftSwap _draft({String id = 'draft'}) {
    final existing = widget.swap;
    final now = ref.read(clockProvider)().millisecondsSinceEpoch;
    return ShiftSwap(
      id: existing?.id ?? id,
      calendarId:
          existing?.calendarId ??
          ref.read(scheduleControllerProvider).calendarId,
      date: _date,
      colleague: _colleague.text.trim(),
      direction: _direction,
      givenShiftTypeIds: _givenIds,
      receivedShiftTypeIds: _receivedIds,
      returnDate: _returnDate,
      createdAt: existing?.createdAt ?? now,
      updatedAt: existing?.updatedAt ?? now,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      status: existing?.status ?? SwapStatus.pending,
      closedAt: existing?.closedAt,
    );
  }

  /// Whether the days or the shifts of the change are not the stored ones
  /// (always true for a new change).
  bool get _movesCalendarDays =>
      widget.swap == null || _draft().movesCalendarDaysFrom(widget.swap!);

  /// Preview the save with the same plan the controller uses
  /// ([planSwapSave]): whether applying would change the calendar, and the
  /// day another applied swap already holds, which refuses it.
  ({SwapApplication application, SwapDayClaim? conflict}) get _preview {
    final schedule = ref.read(scheduleControllerProvider).schedule;
    final existing = widget.swap;
    final draft = _draft();
    final planned = planSwapSave(
      schedule,
      draft,
      moved: existing != null && draft.movesCalendarDaysFrom(existing),
      records: _recordedDays,
      apply: true,
      claims:
          ref.read(swapDayClaimsProvider(draft.calendarId)).value ?? const [],
    );
    return (
      application: swapApplicationOf(
        schedule.apply(planned.restoration),
        draft,
        excluding: {for (final record in planned.skipped) record.date},
      ),
      conflict: planned.conflict,
    );
  }

  List<SwapApplicationRecord> get _recordedDays {
    final existing = widget.swap;
    if (existing == null) return const [];
    return ref.read(swapApplicationRecordsProvider(existing.id)).value ??
        const [];
  }

  bool get _applyByDefault => _movesCalendarDays;

  void _toggle(Set<String> set, String id, bool given) => setState(() {
    if (set.contains(id)) {
      set.remove(id);
    } else {
      set.add(id);
    }
    if (given) {
      _givenTouched = true;
    } else {
      _receivedTouched = true;
    }
  });

  Future<void> _pickDate({bool returnDate = false}) async {
    final initial = returnDate ? (_returnDate ?? _date) : _date;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: DateTime(initial.year - 2),
      lastDate: DateTime(initial.year + 3, 12, 31),
      helpText: returnDate
          ? context.l10n.swapFieldReturnDate
          : context.l10n.swapFieldDate,
    );
    if (picked == null || !mounted) return;
    setState(() {
      final date = CivilDate.fromDateTime(picked);
      if (returnDate) {
        _returnDate = date;
      } else {
        _date = date;
      }
    });
  }

  Future<void> _save() async {
    if (_saving || _confirmingRemoval) return;
    setState(() => _showErrors = true);
    if (!_nameOk) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final controller = ref.read(swapLedgerProvider.notifier);
    final schedule = ref.read(scheduleControllerProvider.notifier);
    final preview = _preview;
    final application = preview.application;
    final apply =
        application == SwapApplication.pending &&
        preview.conflict == null &&
        (_applyChoice ?? _applyByDefault);
    final isNew = widget.swap == null;
    final draft = _draft(id: isNew ? controller.newId() : widget.swap!.id);
    final saved = !isNew && draft != widget.swap
        ? draft.copyWith(
            updatedAt: ref.read(clockProvider)().millisecondsSinceEpoch,
          )
        : draft;
    setState(() => _saving = true);
    try {
      var skipped = const <CivilDate>[];
      final step = await controller.save(
        saved,
        apply: apply,
        isNew: isNew,
        onSkipped: (days) => skipped = days,
      );
      if (navigator.mounted) navigator.pop();
      if (!messenger.mounted) return;
      if (skipped.isNotEmpty) {
        showSkippedSwapDays(messenger, l10n, schedule, skipped, step: step);
      } else if (step != null && apply) {
        showSwapUndoNotice(
          messenger,
          l10n,
          schedule,
          l10n.swapSavedApplied,
          step,
        );
      } else if (step != null && !step.patch.isEmpty) {
        showSwapUndoNotice(
          messenger,
          l10n,
          schedule,
          l10n.swapSavedUnapplied,
          step,
        );
      } else if (application == SwapApplication.pending) {
        showSwapNotice(
          messenger,
          l10n.swapSavedNotApplied,
          action: SnackBarAction(
            label: l10n.swapApplyAction,
            onPressed: () => applySwapToCalendar(
              messenger: messenger,
              l10n: l10n,
              controller: controller,
              schedule: schedule,
              swap: saved,
            ),
          ),
        );
      }
    } on SwapApplyConflict catch (conflict) {
      showSwapNotice(messenger, swapConflictMessage(l10n, conflict.claim));
      if (mounted) setState(() => _saving = false);
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(appSnackBar(content: Text(l10n.swapSaveFailed)));
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove() async {
    final existing = widget.swap;
    if (existing == null || _saving || _confirmingRemoval) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final controller = ref.read(swapLedgerProvider.notifier);
    final schedule = ref.read(scheduleControllerProvider.notifier);
    _confirmingRemoval = true;
    try {
      final records = await ref
          .read(swapAppliedStoreProvider)
          .before(existing.id);
      if (!mounted) return;
      final restore = await confirmSwapRemoval(
        context,
        existing,
        hasRecords: records.isNotEmpty,
        confirmUnapplied: true,
      );
      if (!mounted || restore == null) return;
      setState(() => _saving = true);
      var skipped = const <CivilDate>[];
      final step = await controller.remove(
        existing.id,
        restoreCalendar: restore,
        onSkipped: (days) => skipped = days,
      );
      if (skipped.isNotEmpty) {
        if (mounted) setState(() => _saving = false);
        if (messenger.mounted) {
          showSkippedSwapDays(
            messenger,
            l10n,
            schedule,
            skipped,
            removalRefused: true,
          );
        }
      } else if (navigator.mounted) {
        navigator.pop();
      }
      if (step != null && messenger.mounted) {
        showSwapUndoNotice(messenger, l10n, schedule, l10n.swapRemoved, step);
      }
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(appSnackBar(content: Text(l10n.swapSaveFailed)));
      if (mounted) setState(() => _saving = false);
    } finally {
      _confirmingRemoval = false;
    }
  }

  /// The share of the height the pinned «Guardar» may take. Past it (the
  /// keyboard up in landscape, say) it goes at the end of the form instead and
  /// scrolls with it.
  static const double _maxPinnedShare = 0.4;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final save = PrimaryButton(
      key: const ValueKey('swap-save'),
      label: l10n.save,
      loading: _saving,
      onPressed: _save,
    );
    // Same tap-to-close-the-keyboard as the standard sheet body.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Padding(
        padding: EdgeInsets.only(bottom: inset),
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, box) {
              // The button: 12 dp above and below its line, 48 dp at least,
              // plus the gutter around it.
              final button = math.max(
                Sp.touch,
                textHeight(
                      context.type.button,
                      MediaQuery.textScalerOf(context),
                    ) +
                    2 * Sp.m,
              );
              final pinned =
                  button + Sp.m + Sp.l <= box.maxHeight * _maxPinnedShare;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        Sp.page,
                        0,
                        Sp.page,
                        Sp.l,
                      ),
                      child: _form(context, save: pinned ? null : save),
                    ),
                  ),
                  if (pinned)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Sp.page,
                        Sp.m,
                        Sp.page,
                        Sp.l,
                      ),
                      child: save,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// The fields of the form, then [save] when it is not pinned, then «Quitar».
  Widget _form(BuildContext context, {required Widget? save}) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    final locale = l10n.localeName;
    final palette = ref.watch(
      scheduleControllerProvider.select((s) => s.palette),
    );
    // Recompute the preview after calendar and application changes.
    ref.watch(scheduleControllerProvider.select((s) => s.schedule));
    if (widget.swap case final existing?) {
      ref.watch(swapApplicationRecordsProvider(existing.id));
    }
    ref.watch(swapDayClaimsProvider(_draft().calendarId));
    final preview = _preview;
    final application = preview.application;
    final conflict = application == SwapApplication.pending
        ? preview.conflict
        : null;
    final applyOn =
        application == SwapApplication.pending &&
        conflict == null &&
        (_applyChoice ?? _applyByDefault);
    final restoresOnSave =
        !applyOn && _movesCalendarDays && _recordedDays.isNotEmpty;

    String dateText(CivilDate date) => formatRangeDate(locale, date);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            widget.swap == null ? l10n.swapNewTitle : l10n.swapEditTitle,
            style: type.headline,
          ),
        ),
        const SizedBox(height: Sp.l),
        Semantics(
          header: true,
          child: Text(
            l10n.swapFieldService.toUpperCase(),
            style: type.label.copyWith(color: colors.textMuted),
          ),
        ),
        const SizedBox(height: Sp.s),
        LabeledField(
          label: l10n.swapFieldColleague,
          child: TextField(
            key: const ValueKey('swap-field-colleague'),
            controller: _colleague,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              LengthLimitingTextInputFormatter(maxSwapColleagueLength),
            ],
            decoration: InputDecoration(
              hintText: l10n.swapFieldColleagueHint,
              errorText: _showErrors && !_nameOk
                  ? l10n.swapInvalidColleague
                  : null,
              errorMaxLines: 3,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: Sp.l),
        LabeledField(
          label: l10n.swapFieldDirection,
          helper: l10n.swapFieldDirectionHelper,
          child: ChoiceGrid.pills(
            sizing: ChoiceGridSizing.wholeLabel,
            maxColumns: 2,
            pills: [
              ChoicePill(
                expand: true,
                reserveIcon: true,
                key: const ValueKey('swap-direction-they-owe'),
                label: l10n.swapDirectionTheyOwe,
                selected: _direction == SwapDirection.theyOwe,
                onTap: () => setState(() => _direction = SwapDirection.theyOwe),
              ),
              ChoicePill(
                expand: true,
                reserveIcon: true,
                key: const ValueKey('swap-direction-i-owe'),
                label: l10n.swapDirectionIOwe,
                selected: _direction == SwapDirection.iOwe,
                onTap: () => setState(() => _direction = SwapDirection.iOwe),
              ),
            ],
          ),
        ),
        const SizedBox(height: Sp.l),
        LabeledField(
          label: l10n.swapFieldDate,
          child: SecondaryButton(
            key: const ValueKey('swap-field-date'),
            icon: AppIcons.calendar,
            expand: false,
            label: dateText(_date),
            onPressed: _pickDate,
          ),
        ),
        const SizedBox(height: Sp.l),
        LabeledField(
          label: l10n.swapFieldReturnDate,
          child: Wrap(
            spacing: Sp.s,
            runSpacing: Sp.s,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SecondaryButton(
                key: const ValueKey('swap-field-return-date'),
                icon: AppIcons.calendar,
                expand: false,
                label: _returnDate == null
                    ? l10n.swapFieldReturnNone
                    : dateText(_returnDate!),
                onPressed: () => _pickDate(returnDate: true),
              ),
              if (_returnDate != null)
                TextButton(
                  key: const ValueKey('swap-field-return-clear'),
                  onPressed: () => setState(() => _returnDate = null),
                  child: Text(l10n.swapFieldReturnClear),
                ),
            ],
          ),
        ),
        const SizedBox(height: Sp.l),
        LabeledField(
          label: l10n.swapFieldGivenTypes,
          child: _typePicker(
            palette,
            _given,
            given: true,
            keyPrefix: 'swap-given',
          ),
        ),
        const SizedBox(height: Sp.l),
        LabeledField(
          label: l10n.swapFieldReceivedTypes,
          // The hint goes once both shifts are chosen (QA M4: it stayed).
          helper: _given.isNotEmpty && _received.isNotEmpty
              ? null
              : l10n.swapFieldTypesHelper,
          child: _typePicker(
            palette,
            _received,
            given: false,
            keyPrefix: 'swap-received',
          ),
        ),
        const SizedBox(height: Sp.s),
        SwitchListTile(
          key: const ValueKey('swap-apply-switch'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.swapApplyToggle),
          subtitle: Text(
            conflict != null
                // Both consequences of Save: the old dates still come back.
                ? [
                    if (restoresOnSave) l10n.swapRestoreOnSave,
                    swapConflictMessage(l10n, conflict),
                  ].join('\n')
                : restoresOnSave
                ? l10n.swapRestoreOnSave
                : switch (application) {
                    SwapApplication.nothing => l10n.swapApplyToggleNone,
                    SwapApplication.applied => l10n.swapApplyToggleDone,
                    SwapApplication.pending =>
                      applyOn
                          ? l10n.swapApplyToggleOn
                          : l10n.swapApplyToggleOff,
                  },
          ),
          value: application == SwapApplication.applied || applyOn,
          onChanged: application == SwapApplication.pending && conflict == null
              ? (on) => setState(() => _applyChoice = on)
              : null,
        ),
        const SizedBox(height: Sp.s),
        LabeledField(
          label: l10n.swapFieldNote,
          child: TextField(
            key: const ValueKey('swap-field-note'),
            controller: _note,
            minLines: 2,
            maxLines: 4,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [
              LengthLimitingTextInputFormatter(maxSwapNoteLength),
            ],
            decoration: InputDecoration(hintText: l10n.swapNoteHint),
          ),
        ),
        if (save != null) ...[const SizedBox(height: Sp.xl), save],
        if (widget.swap != null) ...[
          SizedBox(height: save == null ? Sp.xl : Sp.s),
          SecondaryButton(
            key: const ValueKey('swap-remove'),
            label: l10n.swapRemove,
            onPressed: _saving ? null : _remove,
          ),
        ],
      ],
    );
  }

  /// The shifts of one side of the change, as pills. Each pill carries the
  /// shift's colour (a swatch), its code and its hours, so a shift is never
  /// told by colour alone. An empty palette says so instead of showing
  /// nothing.
  Widget _typePicker(
    List<ShiftType> palette,
    Set<String> selected, {
    required bool given,
    required String keyPrefix,
  }) {
    final l10n = context.l10n;
    if (palette.isEmpty) {
      return Text(
        l10n.swapFieldTypesHelper,
        style: context.type.body.copyWith(color: context.colors.textSecondary),
      );
    }
    final format = AppDateFormat.of(context);
    return ChoiceGrid.pills(
      leadingSize: IconSize.inline,
      pills: [
        for (final shift in palette)
          ChoicePill(
            expand: true,
            reserveIcon: true,
            key: ValueKey('$keyPrefix-${shift.id}'),
            label: _typePillLabel(shift, format),
            leading: _ShiftSwatchDot(shift: shift),
            selected: selected.contains(shift.id),
            onTap: () => _toggle(selected, shift.id, given),
          ),
      ],
    );
  }
}

/// The label of a shift pill: code, name and, when it has them, its hours.
String _typePillLabel(ShiftType shift, AppDateFormat format) {
  final times = shift.timeRange(format);
  final base = '${shift.code} · ${shift.name}';
  return times == null ? base : '$base · $times';
}

/// The colour of a shift as a small dot, before its code and name in a pill:
/// the same colour the month draws, never the only thing that names it.
class _ShiftSwatchDot extends StatelessWidget {
  const _ShiftSwatchDot({required this.shift});

  final ShiftType shift;

  @override
  Widget build(BuildContext context) {
    final swatch = shift.swatch(context.colors.brightness);
    return ExcludeSemantics(
      child: Container(
        width: IconSize.inline,
        height: IconSize.inline,
        decoration: BoxDecoration(
          color: swatch.bar,
          borderRadius: Rad.squareRadius(IconSize.inline),
        ),
      ),
    );
  }
}
