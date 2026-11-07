import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/money.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/choice_pill.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../calendar/application/schedule_controller.dart';
import '../../calendar/presentation/shift_badge.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../../shift_types/domain/shift_type_draft.dart'
    show formatCentsInput, parseMoneyCents;
import '../../shift_types/presentation/shift_type_scope_dialog.dart';
import '../application/summary_providers.dart';
import '../domain/hours_goal.dart';
import '../domain/pay_templates.dart';

/// What the sheet hands back: the template, the amounts typed, the shift
/// types chosen and the annual hours (`null` = the goal is not touched).
class _TemplateChoice {
  const _TemplateChoice({
    required this.template,
    required this.amounts,
    required this.selected,
    required this.annualHours,
  });

  final PayTemplate template;
  final Map<PlusSlot, int> amounts;
  final Set<String> selected;
  final int? annualHours;
}

/// «Plantilla de pluses» (propuesta 2): picks a sector, shows the pluses it
/// usually has with an amount of 0 to fill in, and writes them into the
/// chosen work shift types. The annual hours, when typed, become the yearly
/// hours goal. A change that reaches days already gone asks, like the editor
/// of a shift, whether it corrects every day or applies from today on.
Future<void> openPayTemplate(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final palette = ref.read(scheduleControllerProvider).palette;
  final work = [
    for (final type in palette)
      if (type.category == ShiftCategory.work) type,
  ];
  // Nothing on the settings screen keeps the goal alive: hold it while the
  // template is open and written.
  final keepGoal = ref.listenManual(hoursGoalProvider, (_, _) {});
  try {
    await _openPayTemplate(context, ref, l10n, messenger, work);
  } finally {
    keepGoal.close();
  }
}

Future<void> _openPayTemplate(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l10n,
  ScaffoldMessengerState messenger,
  List<ShiftType> work,
) async {
  final goal = await ref.read(hoursGoalProvider.future);
  if (!context.mounted) return;
  final choice = await showAppSheet<_TemplateChoice>(
    context: context,
    padded: true,
    builder: (_) => _PayTemplateSheet(
      workTypes: work,
      decimals: currencyDecimalsOf(context),
      symbol: currencySymbolOf(context),
      currentAnnualHours: goal?.period == HoursGoalPeriod.year
          ? goal!.hours
          : null,
    ),
  );
  if (choice == null || !context.mounted) return;

  final controller = ref.read(scheduleControllerProvider.notifier);
  final changed = applyPayTemplate(
    choice.template,
    work,
    amounts: choice.amounts,
    selected: choice.selected,
  );
  CivilDate? onlyFrom;
  if (changed.isNotEmpty) {
    final today = CivilDate.fromDateTime(ref.read(clockProvider)());
    var changesPast = false;
    for (final type in changed) {
      if (await controller.shiftTypeEditChangesPast(type, today)) {
        changesPast = true;
        break;
      }
    }
    if (!context.mounted) return;
    if (changesPast) {
      final scope = await showShiftTypeScopeDialog(context);
      if (scope == null || !context.mounted) return;
      if (scope == ShiftTypeEditScope.fromToday) onlyFrom = today;
    }
    for (final type in changed) {
      controller.saveShiftType(type, onlyFrom: onlyFrom);
    }
  }
  final hours = choice.annualHours;
  try {
    if (hours != null && goal != HoursGoal(HoursGoalPeriod.year, hours)) {
      await ref
          .read(hoursGoalProvider.notifier)
          .set(HoursGoal(HoursGoalPeriod.year, hours));
    }
  } catch (_) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(appSnackBar(content: Text(l10n.settingsSaveFailed)));
    return;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      appSnackBar(content: Text(l10n.payTemplateApplied(changed.length))),
    );
}

class _PayTemplateSheet extends StatefulWidget {
  const _PayTemplateSheet({
    required this.workTypes,
    required this.decimals,
    required this.symbol,
    required this.currentAnnualHours,
  });

  final List<ShiftType> workTypes;
  final int decimals;
  final String symbol;

  /// The yearly hours goal the user already has, if any.
  final int? currentAnnualHours;

  @override
  State<_PayTemplateSheet> createState() => _PayTemplateSheetState();
}

class _PayTemplateSheetState extends State<_PayTemplateSheet> {
  PayTemplate _template = payTemplates.first;
  final Map<PlusSlot, TextEditingController> _amounts = {
    for (final slot in PlusSlot.values) slot: TextEditingController(),
  };
  final _annual = TextEditingController();
  final Set<PlusSlot> _badAmounts = {};
  bool _badAnnual = false;
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _pick(payTemplates.first);
  }

  @override
  void dispose() {
    for (final controller in _amounts.values) {
      controller.dispose();
    }
    _annual.dispose();
    super.dispose();
  }

  /// The types [template] can write on.
  List<ShiftType> _applicable(PayTemplate template) => [
    for (final type in widget.workTypes)
      if (templateAppliesTo(template, type)) type,
  ];

  /// Shows [template]: its amounts (0, or what the types already share), all
  /// its types chosen and its annual hours (the agreement's, or the goal the
  /// user has, or empty).
  void _pick(PayTemplate template) {
    _template = template;
    final types = _applicable(template);
    _selected = {for (final type in types) type.id};
    final start = startingAmounts(template, types);
    for (final concept in template.concepts) {
      _amounts[concept.slot]!.text = formatCentsInput(
        start[concept.slot] ?? 0,
        decimals: widget.decimals,
      );
    }
    final hours = template.annualHours ?? widget.currentAnnualHours;
    _annual.text = hours == null ? '' : '$hours';
    _badAmounts.clear();
    _badAnnual = false;
  }

  void _apply() {
    final amounts = <PlusSlot, int>{};
    _badAmounts.clear();
    for (final concept in _template.concepts) {
      try {
        amounts[concept.slot] =
            parseMoneyCents(
              _amounts[concept.slot]!.text,
              decimals: widget.decimals,
            ) ??
            0;
      } on FormatException {
        _badAmounts.add(concept.slot);
      }
    }
    final annualText = _annual.text.trim();
    final annual = annualText.isEmpty ? null : int.tryParse(annualText);
    _badAnnual =
        annualText.isNotEmpty &&
        (annual == null || !HoursGoal(HoursGoalPeriod.year, annual).isValid);
    if (_badAmounts.isNotEmpty || _badAnnual) {
      setState(() {});
      return;
    }
    Navigator.pop(
      context,
      _TemplateChoice(
        template: _template,
        amounts: amounts,
        selected: {..._selected},
        annualHours: annual,
      ),
    );
  }

  String _templateName(AppLocalizations l10n, PayTemplateKind kind) =>
      switch (kind) {
        PayTemplateKind.publicHealth => l10n.payTemplatePublicHealth,
        PayTemplateKind.firefighters => l10n.payTemplateFirefighters,
        PayTemplateKind.privateSecurity => l10n.payTemplatePrivateSecurity,
      };

  String _conceptLabel(AppLocalizations l10n, PlusConcept concept) =>
      switch (concept.slot) {
        PlusSlot.nightPerHour => l10n.moneyNightPlusLabel,
        PlusSlot.holidayPerHour => l10n.moneyHolidayPlusLabel,
        PlusSlot.fixedPerShift =>
          concept.target == PlusTarget.guards
              ? l10n.payTemplateGuardPlus
              : l10n.shiftTypesFixedPlusLabel,
      };

  String _conceptHelper(AppLocalizations l10n, PlusConcept concept) =>
      switch (concept.slot) {
        PlusSlot.nightPerHour => l10n.moneyNightPlusHelper,
        PlusSlot.holidayPerHour => l10n.payTemplateHolidayHelper,
        PlusSlot.fixedPerShift =>
          concept.target == PlusTarget.guards
              ? l10n.payTemplateGuardHelper(guardMinMinutes ~/ 60)
              : l10n.shiftTypesFixedPlusHelper,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.type;
    final colors = context.colors;
    final applicable = _applicable(_template);
    final digits = widget.decimals > 0 ? r'[0-9.,]' : r'[0-9]';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.payTemplateTitle, style: type.headline),
        ),
        const SizedBox(height: Sp.s),
        Text(
          l10n.payTemplateIntro,
          style: type.body.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: Sp.l),
        Wrap(
          spacing: Sp.s,
          runSpacing: Sp.s,
          children: [
            for (final template in payTemplates)
              ChoicePill(
                key: ValueKey('pay-template-${template.kind.stored}'),
                label: _templateName(l10n, template.kind),
                selected: template.kind == _template.kind,
                onTap: () => setState(() => _pick(template)),
              ),
          ],
        ),
        // A plus no work type can take (a night plus when none has night
        // hours) has no field: it would write nothing.
        for (final concept in _template.concepts.where(
          (c) => widget.workTypes.any(c.appliesTo),
        )) ...[
          const SizedBox(height: Sp.xl),
          LabeledField(
            label: _conceptLabel(l10n, concept),
            helper: _conceptHelper(l10n, concept),
            child: TextField(
              key: ValueKey('pay-template-amount-${concept.slot.name}'),
              controller: _amounts[concept.slot],
              keyboardType: TextInputType.numberWithOptions(
                decimal: widget.decimals > 0,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(digits)),
                LengthLimitingTextInputFormatter(9),
              ],
              decoration: InputDecoration(
                suffixText: concept.slot == PlusSlot.fixedPerShift
                    ? widget.symbol
                    : l10n.shiftTypesRateUnit(widget.symbol),
                errorText: _badAmounts.contains(concept.slot)
                    ? l10n.shiftTypesErrorRate
                    : null,
                errorMaxLines: 3,
              ),
            ),
          ),
        ],
        const SizedBox(height: Sp.xl),
        LabeledField(
          label: l10n.payTemplateAnnualHours,
          helper: _template.annualHours == null
              ? l10n.payTemplateAnnualHoursHelper
              : l10n.payTemplateAnnualHoursSource(_template.annualHours!),
          child: TextField(
            key: const ValueKey('pay-template-annual'),
            controller: _annual,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            decoration: InputDecoration(
              hintText: l10n.payTemplateAnnualHoursNone,
              suffixText: l10n.overtimeCapHoursSuffix,
              errorText: _badAnnual
                  ? l10n.payTemplateAnnualHoursInvalid(
                      HoursGoalPeriod.year.maxHours,
                    )
                  : null,
              errorMaxLines: 3,
            ),
          ),
        ),
        const SizedBox(height: Sp.xl),
        Text(l10n.payTemplateTypes, style: type.bodyStrong),
        const SizedBox(height: Sp.xs),
        if (applicable.isEmpty)
          Text(
            l10n.payTemplateTypesNone,
            key: const ValueKey('pay-template-types-none'),
            style: type.meta.copyWith(color: colors.textSecondary),
          )
        else
          for (final shift in applicable)
            CheckboxListTile(
              key: ValueKey('pay-template-type-${shift.id}'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _selected.contains(shift.id),
              onChanged: (value) => setState(() {
                if (value ?? false) {
                  _selected.add(shift.id);
                } else {
                  _selected.remove(shift.id);
                }
              }),
              title: Row(
                children: [
                  ShiftBadge(shift: shift),
                  const SizedBox(width: Sp.s),
                  Expanded(child: Text(shift.name, style: type.body)),
                ],
              ),
            ),
        const SizedBox(height: Sp.l),
        PrimaryButton(
          key: const ValueKey('pay-template-apply'),
          label: l10n.payTemplateApply,
          onPressed: _apply,
        ),
      ],
    );
  }
}
