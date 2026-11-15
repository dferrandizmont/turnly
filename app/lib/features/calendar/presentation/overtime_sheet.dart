import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/icons/app_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/button_row.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/choice_grid.dart';
import '../../../core/widgets/choice_pill.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/minute_picker.dart';
import '../../../core/widgets/unsaved_changes_guard.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../application/schedule_controller.dart';
import 'overtime_format.dart';
import 'overtime_types_sheet.dart';

/// Opens the sheet that adds a block of extra hours to [date], or edits
/// [block] (schema v7, docs/datos.md).
Future<void> editOvertimeBlock(
  BuildContext context,
  CivilDate date, {
  OvertimeBlock? block,
}) => showAppSheet<void>(
  context: context,
  padded: true,
  builder: (_) => OvertimeBlockSheet(date: date, block: block),
);

/// The clock minute a new block starts at on a day without a work shift
/// with a schedule.
const int defaultFreeDayOvertimeStart = 9 * 60;

/// «Añadir horas extra» / «Editar horas extra»: the type (in a grid of
/// pills, with its colour and name), the start and the end with the clock
/// picker of the app (on a work day the start is the end of the shift,
/// «Justo después del turno», and «+1 h» to «+4 h» set the end), the unpaid
/// break, a short note and, live, what it adds up to («2 h × 18,75 € =
/// 37,50 €»). The length never carries over from the last block.
class OvertimeBlockSheet extends ConsumerStatefulWidget {
  const OvertimeBlockSheet({super.key, required this.date, this.block});

  final CivilDate date;

  /// The block being edited; `null` adds a new one.
  final OvertimeBlock? block;

  @override
  ConsumerState<OvertimeBlockSheet> createState() => _OvertimeBlockSheetState();
}

class _OvertimeBlockSheetState extends ConsumerState<OvertimeBlockSheet> {
  late final String _id = widget.block?.id ?? const Uuid().v4();
  late int _start;
  late int _end;
  String? _typeId;
  late final TextEditingController _break;
  late final TextEditingController _note;
  bool _breakInvalid = false;
  late final (int, int, String?, String, String) _initial;

  (int, int, String?, String, String) get _values =>
      (_start, _end, _typeId, _break.text, _note.text);

  @override
  void initState() {
    super.initState();
    final schedule = ref.read(scheduleControllerProvider).schedule;
    final day = schedule.resolve(widget.date);
    final block = widget.block;
    if (block != null) {
      _start = block.startMinute;
      _end = block.endMinute;
      _typeId = block.typeId;
    } else {
      _start = (lastWorkEndMinute(day) ?? defaultFreeDayOvertimeStart) % 1440;
      _end = (_start + 60) % 1440;
      final worksToday = day.shifts.any(
        (s) => s.category == ShiftCategory.work,
      );
      final active = [
        for (final t in schedule.overtimeTypes)
          if (!t.archived) t,
      ];
      final preferred = worksToday ? overtimeTypeId : otherWorkTypeId;
      _typeId = active.any((t) => t.id == preferred)
          ? preferred
          : active.firstOrNull?.id;
    }
    _break = TextEditingController(
      text: block == null || block.breakMinutes == 0
          ? ''
          : '${block.breakMinutes}',
    );
    _note = TextEditingController(text: block?.note ?? '');
    _initial = _values;
  }

  @override
  void dispose() {
    _break.dispose();
    _note.dispose();
    super.dispose();
  }

  int get _breakMinutes => int.tryParse(_break.text.trim()) ?? 0;

  OvertimeBlock _draft() {
    final note = _note.text.trim();
    return OvertimeBlock(
      id: _id,
      date: widget.date,
      typeId: _typeId ?? '',
      startMinute: _start,
      endMinute: _end,
      breakMinutes: _breakMinutes,
      note: note.isEmpty ? null : note,
    );
  }

  Future<void> _pick({required bool start}) async {
    final l10n = context.l10n;
    final minute = await showMinutePicker(
      context,
      current: start ? _start : _end,
      help: start ? l10n.shiftTypesPickStart : l10n.shiftTypesPickEnd,
    );
    if (minute == null || !mounted) return;
    setState(() {
      if (start) {
        _start = minute;
      } else {
        _end = minute;
      }
    });
  }

  List<OvertimeBlock> get _others => [
    for (final b
        in ref
                .read(scheduleControllerProvider)
                .schedule
                .entries[widget.date]
                ?.overtimeBlocks ??
            const <OvertimeBlock>[])
      if (b.id != _id) b,
  ];

  void _save() {
    final block = _draft();
    if (block.problem == 'break') {
      setState(() => _breakInvalid = true);
      return;
    }
    if (block.problem != null) return;
    ref.read(scheduleControllerProvider.notifier).setOvertimeBlocks(
      widget.date,
      [..._others, block],
    );
    Navigator.pop(context);
  }

  void _delete() {
    ref
        .read(scheduleControllerProvider.notifier)
        .setOvertimeBlocks(widget.date, _others);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.type;
    final colors = context.colors;
    final schedule = ref.watch(
      scheduleControllerProvider.select((s) => s.schedule),
    );
    final day = schedule.resolve(widget.date);
    final types = [
      for (final t in schedule.overtimeTypes)
        if (!t.archived || t.id == _typeId) t,
    ];
    final selected = schedule.overtimeTypeById(_typeId ?? '');
    final draft = _draft();
    final shiftEnd = lastWorkEndMinute(day);
    final afterShift = shiftEnd != null && _start == shiftEnd % 1440;
    final nextDay = overtimeOnNextDay(draft, day);
    final paid = (draft.durationMinutes - _breakMinutes).clamp(0, 1440);
    final rateUnits = selected == null
        ? null
        : overtimeRateUnits(selected, day, schedule.baseHourlyRateCents);
    final starts = l10n.shiftTypesStarts(overtimeClock(context, _start));
    final ends = l10n.shiftTypesEnds(overtimeClock(context, _end));

    return ListenableBuilder(
      listenable: Listenable.merge([_break, _note]),
      builder: (context, child) =>
          UnsavedChangesGuard(hasChanges: _values != _initial, child: child!),
      child: Column(
        key: const ValueKey('overtime-sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              widget.block == null
                  ? l10n.overtimeSheetAdd
                  : l10n.overtimeSheetEdit,
              style: type.headline,
            ),
          ),
          const SizedBox(height: Sp.l),
          LabeledField(
            label: l10n.overtimeTypeLabel,
            child: ChoiceGrid.pills(
              leadingSize: overtimeSwatchSize,
              pills: [
                for (final t in types)
                  ChoicePill(
                    key: ValueKey('overtime-type-${t.id}'),
                    label: overtimeTypeName(l10n, t),
                    detail: overtimeRateSummary(context, t),
                    selected: t.id == _typeId,
                    expand: true,
                    reserveIcon: true,
                    leading: OvertimeTypeSwatch(colorValue: t.colorValue),
                    onTap: () => setState(() => _typeId = t.id),
                  ),
              ],
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const ValueKey('overtime-manage-types'),
              onPressed: () => showOvertimeTypes(context),
              child: Text(l10n.overtimeManageTypes),
            ),
          ),
          const SizedBox(height: Sp.s),
          AdaptiveButtonRow(
            items: [
              ButtonRowItem(
                label: starts,
                hasIcon: true,
                child: SecondaryButton(
                  key: const ValueKey('overtime-start'),
                  icon: AppIcons.schedule,
                  label: starts,
                  onPressed: () => _pick(start: true),
                ),
              ),
              ButtonRowItem(
                label: ends,
                hasIcon: true,
                child: SecondaryButton(
                  key: const ValueKey('overtime-end'),
                  icon: AppIcons.schedule,
                  label: ends,
                  onPressed: () => _pick(start: false),
                ),
              ),
            ],
          ),
          if (afterShift || nextDay || draft.crossesMidnight)
            Padding(
              padding: const EdgeInsets.only(top: Sp.s),
              child: Text(
                [
                  if (afterShift) l10n.overtimeAfterShift,
                  // The morning after a shift that ends past midnight.
                  if (nextDay)
                    l10n.overtimeOnNextDay
                  else if (draft.crossesMidnight)
                    l10n.overtimeNextDay,
                ].join(' · '),
                key: const ValueKey('overtime-times-note'),
                style: type.meta.copyWith(color: colors.textSecondary),
              ),
            ),
          const SizedBox(height: Sp.l),
          LabeledField(
            label: l10n.overtimeQuickLabel,
            child: ChoiceGrid.pills(
              maxColumns: 4,
              sizing: ChoiceGridSizing.wholeLabel,
              pills: [
                for (final hours in const [1, 2, 3, 4])
                  ChoicePill(
                    key: ValueKey('overtime-quick-$hours'),
                    label: l10n.overtimeQuickHours(hours),
                    selected: draft.durationMinutes == hours * 60,
                    expand: true,
                    reserveIcon: true,
                    onTap: () =>
                        setState(() => _end = (_start + hours * 60) % 1440),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Sp.l),
          LabeledField(
            label: l10n.overtimeBreakLabel,
            child: TextField(
              key: const ValueKey('overtime-break'),
              controller: _break,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              decoration: InputDecoration(
                suffixText: l10n.overtimeBreakUnit,
                errorText: _breakInvalid ? l10n.overtimeBreakTooLong : null,
                errorMaxLines: 3,
              ),
              onChanged: (_) => setState(() => _breakInvalid = false),
            ),
          ),
          const SizedBox(height: Sp.l),
          LabeledField(
            label: l10n.overtimeNoteLabel,
            child: TextField(
              key: const ValueKey('overtime-note'),
              controller: _note,
              maxLength: maxOvertimeNoteLength,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          const SizedBox(height: Sp.s),
          Semantics(
            liveRegion: true,
            child: Text(
              overtimePreviewText(
                context,
                paidMinutes: paid,
                rateUnits: rateUnits,
              ),
              key: const ValueKey('overtime-preview'),
              style: type.bodyStrong,
            ),
          ),
          const SizedBox(height: Sp.l),
          PrimaryButton(
            key: const ValueKey('overtime-save'),
            label: l10n.save,
            onPressed: selected == null ? null : _save,
          ),
          if (widget.block != null) ...[
            const SizedBox(height: Sp.s),
            TextButton(
              key: const ValueKey('overtime-delete'),
              style: TextButton.styleFrom(foregroundColor: colors.danger),
              onPressed: _delete,
              child: Text(l10n.delete),
            ),
          ],
        ],
      ),
    );
  }
}

/// Side of the colour square of an overtime type in the pills and rows.
const double overtimeSwatchSize = 16;

/// The colour of an overtime type: a small rounded square (never alone: it
/// always goes with the type's name).
class OvertimeTypeSwatch extends StatelessWidget {
  const OvertimeTypeSwatch({
    super.key,
    required this.colorValue,
    this.size = overtimeSwatchSize,
  });

  final int colorValue;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Color(colorValue),
        borderRadius: Rad.squareRadius(size),
      ),
    ),
  );
}
