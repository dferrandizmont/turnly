import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/icons/app_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/choice_pill.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../calendar/application/schedule_controller.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../../summary/presentation/summary_format.dart';
import '../application/absence_providers.dart';
import '../domain/absence_balance.dart';
import '../domain/absence_status.dart';
import 'absence_format.dart';

/// Opens the sheet that creates a balance of [year] (when [status] is
/// `null`) or edits the one of [status]: the days allowed, the manual
/// adjustment, whether what is left of the year before is carried (with its
/// cap and the day it expires) and which absence shift types spend it.
///
/// [previousBalances] are the balances of the year before of the same calendar
/// (or of another, of any series): a new balance can continue one of their
/// series (same `type`, copying its name, its types and its cap).
///
/// It saves through [absenceBalancesProvider] and shows a message when the
/// write fails; the screen behind refreshes by itself.
Future<void> showAbsenceBalanceSheet(
  BuildContext context, {
  required int year,
  AbsenceBalanceStatus? status,
  required String calendarId,
  required int nextSortOrder,
  List<AbsenceBalance> previousBalances = const [],
}) => showAppSheet<void>(
  context: context,
  padded: true,
  builder: (_) => AbsenceBalanceSheet(
    year: year,
    status: status,
    calendarId: calendarId,
    nextSortOrder: nextSortOrder,
    previousBalances: previousBalances,
  ),
);

class AbsenceBalanceSheet extends ConsumerStatefulWidget {
  const AbsenceBalanceSheet({
    super.key,
    required this.year,
    required this.status,
    required this.calendarId,
    required this.nextSortOrder,
    this.previousBalances = const [],
  });

  final int year;
  final AbsenceBalanceStatus? status;
  final String calendarId;
  final int nextSortOrder;

  /// The balances of the year before, to offer continuing their series.
  final List<AbsenceBalance> previousBalances;

  @override
  ConsumerState<AbsenceBalanceSheet> createState() =>
      _AbsenceBalanceSheetState();
}

class _AbsenceBalanceSheetState extends ConsumerState<AbsenceBalanceSheet> {
  late final AbsenceBalance? _existing = widget.status?.balance;
  late final _name = TextEditingController(text: _existing?.name ?? '');
  late final _allowed = TextEditingController(
    text: _existing == null ? '' : absenceDaysInput(_existing.allowedDays),
  );
  late final _adjustment = TextEditingController(
    text: _existing == null || _existing.adjustmentDays == 0
        ? ''
        : absenceDaysInput(_existing.adjustmentDays),
  );
  late final _cap = TextEditingController(
    text: _existing?.carryOverMaxDays == null
        ? ''
        : absenceDaysInput(_existing!.carryOverMaxDays!),
  );
  late bool _carry = _existing?.carryOver ?? false;
  late bool _workingDays = _existing?.workingDaysOnly ?? false;
  late CivilDate? _expiry = widget.status?.carryOverExpiry;
  late final Map<String, int> _types = {...?_existing?.shiftTypeQuarters};

  /// The series key the balance is stored under: a new one, or the key of a
  /// series of the year before that this one continues (so [AbsenceBalance]
  /// finds the days left to carry over).
  late String _type = _existing?.type ?? const Uuid().v4();

  bool _showErrors = false;
  bool _saving = false;

  AbsenceUnit get _unit => _existing?.unit ?? AbsenceUnit.day;

  @override
  void dispose() {
    _name.dispose();
    _allowed.dispose();
    _adjustment.dispose();
    _cap.dispose();
    super.dispose();
  }

  double? get _allowedDays {
    final days = parseAbsenceDays(_allowed.text);
    return days != null && isWholeUnits(days, _unit) ? days : null;
  }

  double? get _adjustmentDays => _adjustment.text.trim().isEmpty
      ? 0
      : parseAbsenceDays(_adjustment.text, allowNegative: true);

  /// `null` = no cap (empty); `-1` = typed but invalid.
  double? get _capDays =>
      _cap.text.trim().isEmpty ? null : (parseAbsenceDays(_cap.text) ?? -1);

  bool get _nameOk {
    final name = _name.text.trim();
    return name.isNotEmpty && name.length <= maxAbsenceBalanceNameLength;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _showErrors = true);
    final allowed = _allowedDays;
    final adjustment = _adjustmentDays;
    final cap = _capDays;
    if (!_nameOk ||
        allowed == null ||
        adjustment == null ||
        (_carry && cap == -1)) {
      return;
    }
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final controller = ref.read(absenceBalancesProvider(widget.year).notifier);
    final base =
        _existing ??
        AbsenceBalance(
          year: widget.year,
          type: _type,
          allowedDays: 0,
          calendarId: widget.calendarId,
          sortOrder: widget.nextSortOrder,
        );
    final balance = base.copyWith(
      name: _name.text.trim(),
      allowedDays: allowed,
      adjustmentDays: adjustment,
      carryOver: _carry,
      carryOverMaxDays: _carry ? cap : null,
      clearCarryOverMaxDays: !_carry || cap == null,
      shiftTypeQuarters: {..._types},
      workingDaysOnly: _workingDays,
    );
    setState(() => _saving = true);
    try {
      await controller.save(balance);
      await controller.setCarryOverExpiry(
        balance.year,
        balance.type,
        _carry ? _expiry : null,
        calendarId: widget.calendarId,
      );
      if (navigator.mounted) navigator.pop();
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(appSnackBar(content: Text(l10n.absenceSaveFailed)));
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Continues the series of [previous] (the same `type`, so what is left of
  /// it carries over): its name, its types and its cap are copied.
  void _continueSeries(AbsenceBalance previous) => setState(() {
    _type = previous.type;
    if (previous.name != null) _name.text = previous.name!;
    _types
      ..clear()
      ..addAll(previous.shiftTypeQuarters);
    final cap = previous.carryOverMaxDays;
    _cap.text = cap == null ? '' : absenceDaysInput(cap);
    // Continuing a series means receiving what is left of the year before.
    _carry = true;
    _workingDays = previous.workingDaysOnly;
  });

  /// Stops continuing the series: a new balance starts a brand-new one.
  void _newSeries() => setState(() => _type = const Uuid().v4());

  void _toggleSeries(AbsenceBalance previous) {
    if (_type == previous.type) {
      _newSeries();
    } else {
      _continueSeries(previous);
    }
  }

  /// Creates the balance of the next year with the same series and the values
  /// of the form (the same days, the same types, the same cap), so a series is
  /// set up once and copied year after year.
  Future<void> _copyToNextYear() async {
    final existing = _existing;
    if (existing == null || _saving) return;
    setState(() => _showErrors = true);
    final allowed = _allowedDays;
    final adjustment = _adjustmentDays;
    final cap = _capDays;
    if (!_nameOk ||
        allowed == null ||
        adjustment == null ||
        (_carry && cap == -1)) {
      return;
    }
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final nextYear = existing.year + 1;
    final copy = existing.copyWith(
      year: nextYear,
      name: _name.text.trim(),
      allowedDays: allowed,
      adjustmentDays: adjustment,
      carryOver: _carry,
      carryOverMaxDays: _carry ? cap : null,
      clearCarryOverMaxDays: !_carry || cap == null,
      shiftTypeQuarters: {..._types},
      workingDaysOnly: _workingDays,
      sortOrder: 0,
      clearCreatedAt: true,
      clearUpdatedAt: true,
    );
    setState(() => _saving = true);
    // The balances of the next year are not on screen yet, so nothing keeps
    // that provider alive: without a listener it would be disposed in the
    // middle of the write, which would fail. It is closed when it is done.
    final keepAlive = ref.listenManual(
      absenceBalancesProvider(nextYear),
      (_, _) {},
    );
    try {
      await ref.read(absenceBalancesProvider(nextYear).notifier).save(copy);
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          appSnackBar(content: Text(l10n.absenceCopiedNextYear(nextYear))),
        );
      if (navigator.mounted) navigator.pop();
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(appSnackBar(content: Text(l10n.absenceSaveFailed)));
      if (mounted) setState(() => _saving = false);
    } finally {
      keepAlive.close();
    }
  }

  Future<void> _remove() async {
    final existing = _existing;
    if (existing == null || _saving) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final controller = ref.read(absenceBalancesProvider(widget.year).notifier);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.absenceRemoveTitle,
      body: l10n.absenceRemoveBody(existing.displayName, existing.year),
      confirmLabel: l10n.absenceRemoveConfirm,
      destructive: true,
      scrollable: true,
      confirmKey: const ValueKey('absence-remove-confirm'),
    );
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    try {
      await controller.delete(existing.year, existing.type);
      await controller.setCarryOverExpiry(
        existing.year,
        existing.type,
        null,
        calendarId: widget.calendarId,
      );
      if (navigator.mounted) navigator.pop();
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(appSnackBar(content: Text(l10n.absenceSaveFailed)));
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickExpiry() async {
    final initial = _expiry ?? CivilDate(widget.year, 3, 31);
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: DateTime(widget.year),
      lastDate: DateTime(widget.year + 1, 12, 31),
      helpText: context.l10n.absenceFieldExpiry,
    );
    if (picked == null || !mounted) return;
    setState(() => _expiry = CivilDate.fromDateTime(picked));
  }

  void _toggleType(String id) => setState(() {
    if (_types.containsKey(id)) {
      _types.remove(id);
    } else {
      // A whole day, whatever the unit (4 quarters fits every unit).
      _types[id] = 4;
    }
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    final absenceTypes = [
      for (final t in ref.watch(
        scheduleControllerProvider.select((s) => s.palette),
      ))
        if (t.category == ShiftCategory.absence) t,
    ];
    final locale = l10n.localeName;
    final days = l10n.absenceDaysSuffix;

    String? error(bool bad, String message) =>
        _showErrors && bad ? message : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            _existing == null ? l10n.absenceNewTitle : l10n.absenceEditTitle,
            style: type.headline,
          ),
        ),
        if (_existing == null && widget.previousBalances.isNotEmpty) ...[
          const SizedBox(height: Sp.l),
          Semantics(
            header: true,
            child: Text(l10n.absenceContinueSeries, style: type.meta),
          ),
          const SizedBox(height: Sp.xs),
          Text(l10n.absenceContinueSeriesHelper, style: type.meta),
          const SizedBox(height: Sp.s),
          Wrap(
            spacing: Sp.s,
            runSpacing: Sp.s,
            children: [
              for (final previous in widget.previousBalances)
                ChoicePill(
                  key: ValueKey('absence-continue-${previous.type}'),
                  label: '${previous.displayName} · ${previous.year}',
                  selected: _type == previous.type,
                  onTap: () => _toggleSeries(previous),
                ),
            ],
          ),
        ],
        const SizedBox(height: Sp.l),
        LabeledField(
          label: l10n.absenceFieldName,
          child: TextField(
            key: const ValueKey('absence-field-name'),
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              LengthLimitingTextInputFormatter(maxAbsenceBalanceNameLength),
            ],
            decoration: InputDecoration(
              hintText: l10n.absenceFieldNameHint,
              errorText: error(
                !_nameOk,
                l10n.absenceInvalidName(maxAbsenceBalanceNameLength),
              ),
              errorMaxLines: 3,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: Sp.l),
        LabeledField(
          label: l10n.absenceFieldAllowed,
          helper: l10n.absenceFieldAllowedHelper,
          child: TextField(
            key: const ValueKey('absence-field-allowed'),
            controller: _allowed,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              LengthLimitingTextInputFormatter(7),
            ],
            decoration: InputDecoration(
              hintText: days,
              suffixText: days,
              errorText: error(
                _allowedDays == null,
                l10n.absenceInvalidAllowed,
              ),
              errorMaxLines: 3,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: Sp.l),
        LabeledField(
          label: l10n.absenceFieldAdjustment,
          helper: l10n.absenceFieldAdjustmentHelper,
          child: TextField(
            key: const ValueKey('absence-field-adjustment'),
            controller: _adjustment,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-−]')),
              LengthLimitingTextInputFormatter(8),
            ],
            decoration: InputDecoration(
              hintText: days,
              suffixText: days,
              errorText: error(
                _adjustmentDays == null,
                l10n.absenceInvalidAdjustment,
              ),
              errorMaxLines: 3,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: Sp.s),
        SwitchListTile(
          key: const ValueKey('absence-field-working-days'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.absenceFieldWorkingDays),
          subtitle: Text(l10n.absenceFieldWorkingDaysHelper),
          value: _workingDays,
          onChanged: (value) => setState(() => _workingDays = value),
        ),
        SwitchListTile(
          key: const ValueKey('absence-field-carry'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.absenceFieldCarry),
          value: _carry,
          onChanged: (value) => setState(() => _carry = value),
        ),
        if (_carry) ...[
          const SizedBox(height: Sp.s),
          LabeledField(
            label: l10n.absenceFieldCarryCap,
            helper: l10n.absenceFieldCarryCapHelper,
            child: TextField(
              key: const ValueKey('absence-field-cap'),
              controller: _cap,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                LengthLimitingTextInputFormatter(7),
              ],
              decoration: InputDecoration(
                hintText: days,
                suffixText: days,
                errorText: error(_capDays == -1, l10n.absenceInvalidCap),
                errorMaxLines: 3,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: Sp.l),
          Semantics(
            header: true,
            child: Text(l10n.absenceFieldExpiry, style: type.meta),
          ),
          const SizedBox(height: Sp.s),
          Wrap(
            spacing: Sp.s,
            runSpacing: Sp.s,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SecondaryButton(
                key: const ValueKey('absence-field-expiry'),
                icon: AppIcons.calendar,
                expand: false,
                label: _expiry == null
                    ? l10n.absenceFieldExpiryNone
                    : formatRangeDate(locale, _expiry!),
                onPressed: _pickExpiry,
              ),
              if (_expiry != null)
                TextButton(
                  key: const ValueKey('absence-field-expiry-clear'),
                  onPressed: () => setState(() => _expiry = null),
                  child: Text(l10n.absenceFieldExpiryClear),
                ),
            ],
          ),
        ],
        const SizedBox(height: Sp.l),
        Semantics(
          header: true,
          child: Text(l10n.absenceFieldTypes, style: type.meta),
        ),
        const SizedBox(height: Sp.s),
        if (absenceTypes.isEmpty)
          Text(
            l10n.absenceFieldTypesNone,
            key: const ValueKey('absence-types-none'),
            style: type.body.copyWith(color: colors.textSecondary),
          )
        else
          Wrap(
            spacing: Sp.s,
            runSpacing: Sp.s,
            children: [
              for (final t in absenceTypes)
                ChoicePill(
                  key: ValueKey('absence-type-${t.id}'),
                  label: '${t.code} · ${t.name}',
                  selected: _types.containsKey(t.id),
                  onTap: () => _toggleType(t.id),
                ),
            ],
          ),
        const SizedBox(height: Sp.xs),
        Text(l10n.absenceFieldTypesHelper, style: type.meta),
        const SizedBox(height: Sp.xl),
        PrimaryButton(
          key: const ValueKey('absence-save'),
          label: l10n.save,
          loading: _saving,
          onPressed: _save,
        ),
        if (_existing != null) ...[
          const SizedBox(height: Sp.s),
          SecondaryButton(
            key: const ValueKey('absence-copy-next'),
            icon: AppIcons.copy,
            label: l10n.absenceCopyNextYear,
            onPressed: _saving ? null : _copyToNextYear,
          ),
          const SizedBox(height: Sp.s),
          SecondaryButton(
            key: const ValueKey('absence-remove'),
            label: l10n.absenceRemove,
            onPressed: _saving ? null : _remove,
          ),
        ],
      ],
    );
  }
}
