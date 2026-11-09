import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/choice_grid.dart';
import '../../../core/widgets/choice_pill.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../settings/presentation/settings_widgets.dart';
import '../application/summary_providers.dart';
import '../domain/overtime_cap.dart';
import '../domain/pay_period.dart';

/// What a sheet of the payroll rules returns: the new value, or a removal.
class _Picked<T> {
  const _Picked(this.value);

  /// `null` = remove it.
  final T? value;
}

/// Opens the sheet of the «Día de cierre» (propuesta 8): the last day of the
/// payroll month, or empty for the calendar month.
Future<void> editClosingDay(BuildContext context, WidgetRef ref) async {
  final current = await ref.read(payRulesProvider.future);
  if (!context.mounted) return;
  final picked = await showAppSheet<_Picked<int>>(
    context: context,
    padded: true,
    builder: (_) => _ClosingDaySheet(initial: current.closingDay),
  );
  if (picked == null || !context.mounted) return;
  await saveSetting(
    context,
    () => ref.read(payRulesProvider.notifier).setClosingDay(picked.value),
  );
}

/// Opens the sheet of the «Tope de horas extra» (propuesta 8).
Future<void> editOvertimeCap(BuildContext context, WidgetRef ref) async {
  final current = await ref.read(payRulesProvider.future);
  if (!context.mounted) return;
  final picked = await showAppSheet<_Picked<OvertimeCap>>(
    context: context,
    padded: true,
    builder: (_) => _OvertimeCapSheet(initial: current.overtimeCap),
  );
  if (picked == null || !context.mounted) return;
  await saveSetting(
    context,
    () => ref.read(payRulesProvider.notifier).setOvertimeCap(picked.value),
  );
}

class _ClosingDaySheet extends StatefulWidget {
  const _ClosingDaySheet({required this.initial});

  final int? initial;

  @override
  State<_ClosingDaySheet> createState() => _ClosingDaySheetState();
}

class _ClosingDaySheetState extends State<_ClosingDaySheet> {
  late final _field = TextEditingController(
    text: widget.initial == null ? '' : '${widget.initial}',
  );
  bool _invalid = false;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _save() {
    final text = _field.text.trim();
    if (text.isEmpty) {
      Navigator.pop(context, const _Picked<int>(null));
      return;
    }
    final day = int.tryParse(text);
    // 31 is the calendar month: no closing day.
    if (day == 31) {
      Navigator.pop(context, const _Picked<int>(null));
      return;
    }
    if (day == null || !isValidClosingDay(day)) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.pop(context, _Picked(day));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.type;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.closingDayTitle, style: type.headline),
        ),
        const SizedBox(height: Sp.l),
        LabeledField(
          label: l10n.closingDayField,
          helper: l10n.closingDayHelper,
          child: TextField(
            key: const ValueKey('closing-day-field'),
            controller: _field,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
            decoration: InputDecoration(
              hintText: l10n.closingDayNone,
              errorText: _invalid ? l10n.closingDayInvalid : null,
              errorMaxLines: 3,
            ),
            onChanged: (_) {
              if (_invalid) setState(() => _invalid = false);
            },
            onSubmitted: (_) => _save(),
          ),
        ),
        const SizedBox(height: Sp.l),
        PrimaryButton(
          key: const ValueKey('closing-day-save'),
          label: l10n.save,
          onPressed: _save,
        ),
      ],
    );
  }
}

class _OvertimeCapSheet extends StatefulWidget {
  const _OvertimeCapSheet({required this.initial});

  final OvertimeCap? initial;

  @override
  State<_OvertimeCapSheet> createState() => _OvertimeCapSheetState();
}

class _OvertimeCapSheetState extends State<_OvertimeCapSheet> {
  // A new cap starts on the legal maximum (ET art. 35.2): 80 h a year.
  late OvertimeCapPeriod _period =
      widget.initial?.period ?? OvertimeCapPeriod.year;
  late final _field = TextEditingController(
    text: '${widget.initial?.hours ?? legalOvertimeHoursPerYear}',
  );
  bool _invalid = false;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _save() {
    final hours = int.tryParse(_field.text.trim());
    final cap = hours == null ? null : OvertimeCap(_period, hours);
    if (cap == null || !cap.isValid) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.pop(context, _Picked(cap));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.type;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.overtimeCapTitle, style: type.headline),
        ),
        const SizedBox(height: Sp.s),
        Text(
          l10n.overtimeCapIntro,
          style: type.body.copyWith(color: context.colors.textSecondary),
        ),
        const SizedBox(height: Sp.l),
        ChoiceGrid.pills(
          sizing: ChoiceGridSizing.wholeLabel,
          maxColumns: 2,
          pills: [
            ChoicePill(
              expand: true,
              reserveIcon: true,
              key: const ValueKey('overtime-cap-year'),
              label: l10n.overtimeCapPerYear,
              selected: _period == OvertimeCapPeriod.year,
              onTap: () => setState(() {
                _period = OvertimeCapPeriod.year;
                _invalid = false;
              }),
            ),
            ChoicePill(
              expand: true,
              reserveIcon: true,
              key: const ValueKey('overtime-cap-month'),
              label: l10n.overtimeCapPerMonth,
              selected: _period == OvertimeCapPeriod.month,
              onTap: () => setState(() {
                _period = OvertimeCapPeriod.month;
                _invalid = false;
              }),
            ),
          ],
        ),
        const SizedBox(height: Sp.l),
        LabeledField(
          label: l10n.overtimeCapField,
          child: TextField(
            key: const ValueKey('overtime-cap-field'),
            controller: _field,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            decoration: InputDecoration(
              suffixText: l10n.overtimeCapHoursSuffix,
              errorText: _invalid
                  ? l10n.overtimeCapInvalid(_period.maxHours)
                  : null,
              errorMaxLines: 3,
            ),
            onChanged: (_) {
              if (_invalid) setState(() => _invalid = false);
            },
            onSubmitted: (_) => _save(),
          ),
        ),
        const SizedBox(height: Sp.l),
        PrimaryButton(
          key: const ValueKey('overtime-cap-save'),
          label: l10n.save,
          onPressed: _save,
        ),
        if (widget.initial != null) ...[
          const SizedBox(height: Sp.s),
          SecondaryButton(
            key: const ValueKey('overtime-cap-remove'),
            label: l10n.overtimeCapRemove,
            onPressed: () =>
                Navigator.pop(context, const _Picked<OvertimeCap>(null)),
          ),
        ],
      ],
    );
  }
}
