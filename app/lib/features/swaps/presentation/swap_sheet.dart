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
import '../../../core/widgets/choice_pill.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../calendar/application/schedule_controller.dart';
import '../../calendar/presentation/shift_format.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../../summary/presentation/summary_format.dart';
import '../application/swaps_controller.dart';
import '../domain/shift_swap.dart';

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
  padded: true,
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
    if (_saving) return;
    setState(() => _showErrors = true);
    final name = _colleague.text.trim();
    if (!_nameOk) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final controller = ref.read(swapLedgerProvider.notifier);
    final now = ref.read(clockProvider)().millisecondsSinceEpoch;
    final note = _note.text.trim();
    final given = _givenIds;
    final received = _receivedIds;
    setState(() => _saving = true);
    try {
      final existing = widget.swap;
      if (existing == null) {
        await controller.register(
          colleague: name,
          date: _date,
          direction: _direction,
          returnDate: _returnDate,
          givenShiftTypeIds: given,
          receivedShiftTypeIds: received,
          note: note.isEmpty ? null : note,
        );
      } else {
        await controller.save(
          existing.copyWith(
            colleague: name,
            direction: _direction,
            returnDate: _returnDate,
            clearReturnDate: _returnDate == null,
            givenShiftTypeIds: given,
            receivedShiftTypeIds: received,
            clearGivenShiftTypeIds: given == null,
            clearReceivedShiftTypeIds: received == null,
            note: note.isEmpty ? null : note,
            clearNote: note.isEmpty,
            updatedAt: now,
          ),
        );
      }
      if (navigator.mounted) navigator.pop();
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(appSnackBar(content: Text(l10n.swapSaveFailed)));
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove() async {
    final existing = widget.swap;
    if (existing == null || _saving) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final controller = ref.read(swapLedgerProvider.notifier);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.swapRemoveTitle,
      body: l10n.swapRemoveBody(
        existing.colleague,
        formatRangeDate(l10n.localeName, existing.date),
      ),
      confirmLabel: l10n.swapRemoveConfirm,
      destructive: true,
      scrollable: true,
      confirmKey: const ValueKey('swap-remove-confirm'),
    );
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    try {
      await controller.remove(existing.id);
      if (navigator.mounted) navigator.pop();
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(appSnackBar(content: Text(l10n.swapSaveFailed)));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    final locale = l10n.localeName;
    final palette = ref.watch(
      scheduleControllerProvider.select((s) => s.palette),
    );

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
          child: Wrap(
            spacing: Sp.s,
            runSpacing: Sp.s,
            children: [
              ChoicePill(
                key: const ValueKey('swap-direction-they-owe'),
                label: l10n.swapDirectionTheyOwe,
                selected: _direction == SwapDirection.theyOwe,
                onTap: () => setState(() => _direction = SwapDirection.theyOwe),
              ),
              ChoicePill(
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
          helper: l10n.swapFieldTypesHelper,
          child: _typePicker(
            palette,
            _received,
            given: false,
            keyPrefix: 'swap-received',
          ),
        ),
        const SizedBox(height: Sp.l),
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
        const SizedBox(height: Sp.xl),
        PrimaryButton(
          key: const ValueKey('swap-save'),
          label: l10n.save,
          loading: _saving,
          onPressed: _save,
        ),
        if (widget.swap != null) ...[
          const SizedBox(height: Sp.s),
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
    return Wrap(
      spacing: Sp.s,
      runSpacing: Sp.s,
      children: [
        for (final shift in palette)
          ChoicePill(
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
