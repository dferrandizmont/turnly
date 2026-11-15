import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/format/money.dart';
import '../../../core/icons/app_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/choice_grid.dart';
import '../../../core/widgets/choice_pill.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/unsaved_changes_guard.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../../shift_types/domain/shift_type_draft.dart'
    show formatCentsInput, parseMoneyCents;
import '../../shift_types/presentation/money_input_formatter.dart';
import '../../shift_types/presentation/shift_color_grid.dart';
import '../application/schedule_controller.dart';
import 'overtime_format.dart';
import 'overtime_sheet.dart';

/// Opens «Tipos de horas extra» (schema v7): the types in their order, each
/// with its colour, name, how it is paid and whether it counts for the goal;
/// up and down to reorder, archive (a type is never deleted: its blocks
/// keep it) and «Nuevo tipo». The archived ones wait in «Archivados (n)».
Future<void> showOvertimeTypes(BuildContext context) => showAppSheet<void>(
  context: context,
  padded: true,
  builder: (_) => const OvertimeTypesSheet(),
);

class OvertimeTypesSheet extends ConsumerWidget {
  const OvertimeTypesSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final type = context.type;
    final colors = context.colors;
    final all = ref.watch(
      scheduleControllerProvider.select((s) => s.schedule.overtimeTypes),
    );
    final controller = ref.read(scheduleControllerProvider.notifier);
    final active = [
      for (final t in all)
        if (!t.archived) t,
    ];
    final archived = [
      for (final t in all)
        if (t.archived) t,
    ];
    void move(int from, int to) {
      final ids = [for (final t in active) t.id];
      final id = ids.removeAt(from);
      ids.insert(to, id);
      controller.reorderOvertimeTypes([...ids, for (final t in archived) t.id]);
    }

    return Column(
      key: const ValueKey('overtime-types-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.overtimeTypesTitle, style: type.headline),
        ),
        const SizedBox(height: Sp.xs),
        Text(
          l10n.overtimeTypesHelp,
          style: type.meta.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: Sp.l),
        for (final (i, t) in active.indexed)
          _TypeRow(
            type: t,
            actions: [
              IconButton(
                key: ValueKey('overtime-type-up-${t.id}'),
                tooltip: l10n.overtimeTypeMoveUp(overtimeTypeName(l10n, t)),
                icon: Icon(AppIcons.arrowUp),
                onPressed: i == 0 ? null : () => move(i, i - 1),
              ),
              IconButton(
                key: ValueKey('overtime-type-down-${t.id}'),
                tooltip: l10n.overtimeTypeMoveDown(overtimeTypeName(l10n, t)),
                icon: Icon(AppIcons.arrowDown),
                onPressed: i == active.length - 1 ? null : () => move(i, i + 1),
              ),
              // The last active type stays: a block always needs one.
              IconButton(
                key: ValueKey('overtime-type-archive-${t.id}'),
                tooltip: l10n.overtimeTypeArchiveNamed(
                  overtimeTypeName(l10n, t),
                ),
                icon: Icon(AppIcons.archive),
                onPressed: active.length == 1
                    ? null
                    : () => controller.saveOvertimeType(
                        t.copyWith(archived: true),
                      ),
              ),
            ],
          ),
        const SizedBox(height: Sp.s),
        SecondaryButton(
          key: const ValueKey('overtime-type-new'),
          icon: AppIcons.add,
          label: l10n.overtimeNewType,
          onPressed: () => editOvertimeType(context),
        ),
        if (archived.isNotEmpty) ...[
          const SizedBox(height: Sp.l),
          Semantics(
            header: true,
            child: Text(
              l10n.overtimeTypesArchived(archived.length).toUpperCase(),
              style: type.label.copyWith(color: colors.textMuted),
            ),
          ),
          const SizedBox(height: Sp.xs),
          for (final t in archived)
            _TypeRow(
              type: t,
              actions: [
                TextButton(
                  key: ValueKey('overtime-type-restore-${t.id}'),
                  onPressed: () =>
                      controller.saveOvertimeType(t.copyWith(archived: false)),
                  child: Text(l10n.overtimeTypeRestore),
                ),
              ],
            ),
        ],
      ],
    );
  }
}

/// One type: colour, name and, under it, how it is paid and whether it
/// counts; tapping it edits it. [actions] go after it, on its own line with
/// large text.
class _TypeRow extends StatelessWidget {
  const _TypeRow({required this.type, required this.actions});

  final OvertimeType type;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.type;
    final colors = context.colors;
    final detail = [
      overtimeRateSummary(context, type),
      type.countsForGoal ? l10n.overtimeTypeCounts : l10n.overtimeTypeNotCounts,
    ].join(' · ');
    final info = InkWell(
      key: ValueKey('overtime-type-row-${type.id}'),
      borderRadius: BorderRadius.circular(Rad.inner),
      onTap: () => editOvertimeType(context, type: type),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Sp.touch),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Sp.s),
          child: Row(
            children: [
              OvertimeTypeSwatch(colorValue: type.colorValue, size: Sp.xl),
              const SizedBox(width: Sp.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(overtimeTypeName(l10n, type), style: text.bodyStrong),
                    Text(
                      detail,
                      style: text.meta.copyWith(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final stacked = MediaQuery.textScalerOf(context).scale(14) >= 14 * 1.6;
    final buttons = Row(mainAxisSize: MainAxisSize.min, children: actions);
    return stacked
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              info,
              Align(alignment: AlignmentDirectional.centerEnd, child: buttons),
            ],
          )
        : Row(
            children: [
              Expanded(child: info),
              buttons,
            ],
          );
  }
}

/// Opens the form of a new overtime type, or of [type].
Future<void> editOvertimeType(BuildContext context, {OvertimeType? type}) =>
    showAppSheet<void>(
      context: context,
      padded: true,
      builder: (_) => OvertimeTypeForm(type: type),
    );

/// The shortcuts of the multiplier, in basis points.
const List<int> overtimeMultiplierShortcuts = [12500, 15000, 17500, 20000];

/// Name, colour, how it is paid (as the shift, a multiplier of it with
/// ×1,25 ×1,5 ×1,75 ×2 or a free one, a rate of its own, or nothing) and
/// whether it counts for the hours goal.
class OvertimeTypeForm extends ConsumerStatefulWidget {
  const OvertimeTypeForm({super.key, this.type});

  final OvertimeType? type;

  @override
  ConsumerState<OvertimeTypeForm> createState() => _OvertimeTypeFormState();
}

class _OvertimeTypeFormState extends ConsumerState<OvertimeTypeForm> {
  late final TextEditingController _name;
  late final TextEditingController _multiplier;
  late final TextEditingController _rate;
  late OvertimeRateMode _mode = widget.type?.rateMode ?? OvertimeRateMode.shift;
  late bool _counts = widget.type?.countsForGoal ?? true;
  late int _color =
      widget.type?.colorValue ?? defaultOvertimeTypes.first.colorValue;
  bool _started = false;
  bool _nameInvalid = false;
  bool _multiplierInvalid = false;
  bool _rateInvalid = false;
  late final (String, String, String, OvertimeRateMode, bool, int) _initial;

  (String, String, String, OvertimeRateMode, bool, int) get _values =>
      (_name.text, _multiplier.text, _rate.text, _mode, _counts, _color);

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _multiplier = TextEditingController();
    _rate = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final t = widget.type;
    _name.text = t == null ? '' : overtimeTypeName(context.l10n, t);
    _multiplier.text = formatMultiplier(
      context,
      t?.multiplierBasisPoints ?? overtimeMultiplierShortcuts.first,
    );
    final rate = t?.hourlyRateCents;
    _rate.text = rate == null
        ? ''
        : formatCentsInput(rate, decimals: currencyDecimalsOf(context));
    _initial = _values;
  }

  @override
  void dispose() {
    _name.dispose();
    _multiplier.dispose();
    _rate.dispose();
    super.dispose();
  }

  void _save() {
    final l10n = context.l10n;
    final original = widget.type;
    final name = _name.text.trim();
    // A built-in type keeps the app's name (in every language) until the
    // user writes another one.
    final keepsBuiltInName =
        original != null &&
        original.name == null &&
        name == overtimeTypeName(l10n, original);
    final multiplier = parseMultiplier(_multiplier.text);
    int? rate;
    try {
      rate = parseMoneyCents(_rate.text, decimals: currencyDecimalsOf(context));
    } on FormatException {
      rate = null;
    }
    setState(() {
      _nameInvalid = name.isEmpty || name.length > maxOvertimeTypeNameLength;
      _multiplierInvalid =
          _mode == OvertimeRateMode.multiplier && multiplier == null;
      _rateInvalid = _mode == OvertimeRateMode.fixed && rate == null;
    });
    if (_nameInvalid || _multiplierInvalid || _rateInvalid) return;
    final schedule = ref.read(scheduleControllerProvider).schedule;
    final next = OvertimeType(
      id: original?.id ?? 'ot-${const Uuid().v4()}',
      name: keepsBuiltInName ? null : name,
      colorValue: _color,
      rateMode: _mode,
      multiplierBasisPoints:
          multiplier ?? original?.multiplierBasisPoints ?? multiplierOne,
      hourlyRateCents: _mode == OvertimeRateMode.fixed
          ? rate
          : original?.hourlyRateCents,
      countsForGoal: _counts,
      archived: original?.archived ?? false,
      sortOrder:
          original?.sortOrder ??
          schedule.overtimeTypes.fold(
                -1,
                (n, t) => t.sortOrder > n ? t.sortOrder : n,
              ) +
              1,
    );
    ref.read(scheduleControllerProvider.notifier).saveOvertimeType(next);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.type;
    final colors = context.colors;
    final modes = [
      (OvertimeRateMode.shift, l10n.overtimeRateShift),
      (OvertimeRateMode.multiplier, l10n.overtimeRateMultiplier),
      (OvertimeRateMode.fixed, l10n.overtimeRateFixed),
      (OvertimeRateMode.none, l10n.overtimeRateNone),
    ];
    final typed = parseMultiplier(_multiplier.text);
    return ListenableBuilder(
      listenable: Listenable.merge([_name, _multiplier, _rate]),
      builder: (context, child) =>
          UnsavedChangesGuard(hasChanges: _values != _initial, child: child!),
      child: Column(
        key: const ValueKey('overtime-type-form'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              widget.type == null
                  ? l10n.overtimeNewType
                  : l10n.overtimeEditType,
              style: type.headline,
            ),
          ),
          const SizedBox(height: Sp.l),
          LabeledField(
            label: l10n.overtimeTypeNameLabel,
            child: TextField(
              key: const ValueKey('overtime-type-name'),
              controller: _name,
              maxLength: maxOvertimeTypeNameLength,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                errorText: _nameInvalid ? l10n.overtimeTypeInvalidName : null,
              ),
              onChanged: (_) {
                if (_nameInvalid) setState(() => _nameInvalid = false);
              },
            ),
          ),
          const SizedBox(height: Sp.s),
          LabeledField(
            label: l10n.overtimeTypeColorLabel,
            child: ShiftColorGrid(
              selected: _color,
              onChanged: (c) => setState(() => _color = c),
            ),
          ),
          const SizedBox(height: Sp.l),
          LabeledField(
            label: l10n.overtimeRateLabel,
            child: ChoiceGrid.pills(
              maxColumns: 2,
              pills: [
                for (final (mode, label) in modes)
                  ChoicePill(
                    key: ValueKey('overtime-mode-${mode.name}'),
                    label: label,
                    selected: _mode == mode,
                    expand: true,
                    reserveIcon: true,
                    onTap: () => setState(() => _mode = mode),
                  ),
              ],
            ),
          ),
          if (_mode == OvertimeRateMode.shift ||
              _mode == OvertimeRateMode.multiplier)
            Padding(
              padding: const EdgeInsets.only(top: Sp.s),
              child: Text(
                l10n.overtimeRateShiftHelp,
                style: type.meta.copyWith(color: colors.textSecondary),
              ),
            ),
          if (_mode == OvertimeRateMode.multiplier) ...[
            const SizedBox(height: Sp.m),
            ChoiceGrid.pills(
              maxColumns: 4,
              sizing: ChoiceGridSizing.wholeLabel,
              pills: [
                for (final bp in overtimeMultiplierShortcuts)
                  ChoicePill(
                    key: ValueKey('overtime-multiplier-$bp'),
                    label: l10n.overtimeMultiplierShortcut(
                      formatMultiplier(context, bp),
                    ),
                    selected: typed == bp,
                    expand: true,
                    reserveIcon: true,
                    onTap: () => setState(() {
                      _multiplier.text = formatMultiplier(context, bp);
                      _multiplierInvalid = false;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: Sp.m),
            LabeledField(
              label: l10n.overtimeMultiplierField,
              child: TextField(
                key: const ValueKey('overtime-type-multiplier'),
                controller: _multiplier,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  LengthLimitingTextInputFormatter(8),
                ],
                decoration: InputDecoration(
                  prefixText: '×',
                  errorText: _multiplierInvalid
                      ? l10n.overtimeTypeInvalidMultiplier
                      : null,
                  errorMaxLines: 3,
                ),
                onChanged: (_) => setState(() => _multiplierInvalid = false),
              ),
            ),
          ],
          if (_mode == OvertimeRateMode.fixed) ...[
            const SizedBox(height: Sp.m),
            LabeledField(
              label: l10n.overtimeFixedRateField,
              child: TextField(
                key: const ValueKey('overtime-type-rate'),
                controller: _rate,
                keyboardType: TextInputType.numberWithOptions(
                  decimal: currencyDecimalsOf(context) > 0,
                ),
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  MoneyInputFormatter(decimals: currencyDecimalsOf(context)),
                ],
                decoration: InputDecoration(
                  suffixText: currencySymbolOf(context),
                  errorText: _rateInvalid ? rateRangeMessage(context) : null,
                  errorMaxLines: 3,
                ),
                onChanged: (_) {
                  if (_rateInvalid) setState(() => _rateInvalid = false);
                },
              ),
            ),
          ],
          const SizedBox(height: Sp.s),
          SwitchListTile(
            key: const ValueKey('overtime-type-counts'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.overtimeCountsForGoal),
            value: _counts,
            onChanged: (v) => setState(() => _counts = v),
          ),
          const SizedBox(height: Sp.l),
          PrimaryButton(
            key: const ValueKey('overtime-type-save'),
            label: l10n.save,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

/// Opens «Precio base por hora»: the rate the overtime types «as the shift»
/// use on a day without a priced shift. Empty removes it.
Future<void> editOvertimeBaseRate(BuildContext context) => showAppSheet<void>(
  context: context,
  padded: true,
  builder: (_) => const OvertimeBaseRateSheet(),
);

class OvertimeBaseRateSheet extends ConsumerStatefulWidget {
  const OvertimeBaseRateSheet({super.key});

  @override
  ConsumerState<OvertimeBaseRateSheet> createState() =>
      _OvertimeBaseRateSheetState();
}

class _OvertimeBaseRateSheetState extends ConsumerState<OvertimeBaseRateSheet> {
  final _field = TextEditingController();
  bool _started = false;
  bool _invalid = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final cents = ref
        .read(scheduleControllerProvider)
        .schedule
        .baseHourlyRateCents;
    _field.text = cents == null
        ? ''
        : formatCentsInput(cents, decimals: currencyDecimalsOf(context));
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _save() {
    int? cents;
    try {
      cents = parseMoneyCents(
        _field.text,
        decimals: currencyDecimalsOf(context),
      );
    } on FormatException {
      setState(() => _invalid = true);
      return;
    }
    ref.read(scheduleControllerProvider.notifier).setBaseHourlyRate(cents);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.type;
    return Column(
      key: const ValueKey('overtime-base-rate-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.overtimeBaseRateTitle, style: type.headline),
        ),
        const SizedBox(height: Sp.l),
        LabeledField(
          label: l10n.overtimeBaseRateField,
          helper: l10n.overtimeBaseRateHelp,
          child: TextField(
            key: const ValueKey('overtime-base-rate'),
            controller: _field,
            autofocus: true,
            keyboardType: TextInputType.numberWithOptions(
              decimal: currencyDecimalsOf(context) > 0,
            ),
            textInputAction: TextInputAction.done,
            inputFormatters: [
              MoneyInputFormatter(decimals: currencyDecimalsOf(context)),
            ],
            decoration: InputDecoration(
              hintText: l10n.overtimeBaseRateNone,
              suffixText: currencySymbolOf(context),
              errorText: _invalid ? rateRangeMessage(context) : null,
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
          key: const ValueKey('overtime-base-rate-save'),
          label: l10n.save,
          onPressed: _save,
        ),
      ],
    );
  }
}
