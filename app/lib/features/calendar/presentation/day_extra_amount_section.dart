import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/money.dart';
import '../../../core/icons/app_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../../settings/application/preferences_controller.dart';
import '../../shift_types/domain/shift_type_draft.dart'
    show formatCentsInput, parseMoneyCents;
import '../application/schedule_controller.dart';

/// «Importe extra» of the day detail (P9, fila 26 de `docs/paridad-pago.md`):
/// the money of one day that is not in the rate of the shift (allowances,
/// mileage, a bonus; negative for a deduction), in the currency of Ajustes.
///
/// The summary and the reports add it to the estimate of the period. It is
/// written to the day when the person stops typing ([settle]), leaves the
/// field or closes the sheet, so what is typed is ONE undo step; an empty
/// field clears it.
class DayExtraAmountSection extends ConsumerStatefulWidget {
  const DayExtraAmountSection({super.key, required this.date});

  final CivilDate date;

  /// Quiet time after the last key before the amount is written.
  static const Duration settle = Duration(milliseconds: 800);

  @override
  ConsumerState<DayExtraAmountSection> createState() =>
      DayExtraAmountSectionState();
}

class DayExtraAmountSectionState extends ConsumerState<DayExtraAmountSection> {
  late final ScheduleController _schedule;
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;

  // What was typed and is not written yet.
  bool _dirty = false;
  bool _bad = false;

  CivilDate get _date => widget.date;

  int get _decimals => currencyDecimals(ref.read(preferencesProvider).currency);

  @override
  void initState() {
    super.initState();
    _schedule = ref.read(scheduleControllerProvider.notifier);
    final stored = ref
        .read(scheduleControllerProvider)
        .schedule
        .entries[_date]
        ?.extraAmountCents;
    _controller.text = _textOf(stored);
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_dirty && !_bad) {
      final date = _date;
      final cents = _parse(_controller.text);
      final schedule = _schedule;
      // The tree is locked while it is being disposed.
      scheduleMicrotask(() => schedule.setDayExtraAmount(date, cents));
    }
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// A stored amount as the field shows it ("25", "-10,5"; "" = none).
  String _textOf(int? cents) {
    if (cents == null || cents == 0) return '';
    final text = formatCentsInput(cents.abs(), decimals: _decimals);
    return cents < 0 ? '-$text' : text;
  }

  /// The cents of [text], `null` when empty or not an amount.
  int? _parse(String text) {
    final trimmed = text.trim().replaceAll('−', '-');
    if (trimmed.isEmpty) return null;
    final negative = trimmed.startsWith('-');
    try {
      final cents = parseMoneyCents(
        negative ? trimmed.substring(1) : trimmed,
        decimals: _decimals,
      );
      return cents == null ? null : (negative ? -cents : cents);
    } on FormatException {
      return null;
    }
  }

  bool _isBad(String text) => text.trim().isNotEmpty && _parse(text) == null;

  void _commit() {
    _timer?.cancel();
    if (!_dirty || _bad) return;
    _dirty = false;
    _schedule.setDayExtraAmount(_date, _parse(_controller.text));
  }

  /// Finish the debounce before a parent action snapshots or clears the day.
  /// Once cleared, disposal must never reinsert the previous amount.
  void commitPending() => _commit();

  void _onChanged(String text) {
    _timer?.cancel();
    setState(() {
      _dirty = true;
      _bad = _isBad(text);
    });
    if (!_bad) {
      _timer = Timer(DayExtraAmountSection.settle, _commit);
    }
  }

  void _clearField() {
    _controller.clear();
    _onChanged('');
    _commit();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final symbol = currencySymbolOf(context);

    // Undo (or any change from outside) puts its amount back in the field.
    ref.listen(
      scheduleControllerProvider.select(
        (s) => s.schedule.entries[_date]?.extraAmountCents,
      ),
      (_, stored) {
        if (_dirty) return;
        final text = _textOf(stored);
        if (_parse(_controller.text) != (stored == 0 ? null : stored)) {
          _controller.text = text;
        }
      },
    );

    return Column(
      key: const ValueKey('day-extra-amount'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Sp.l),
        LabeledField(
          label: l10n.moneyExtraTitle,
          helper: l10n.moneyExtraHelper,
          child: TextField(
            key: const ValueKey('day-extra-amount-field'),
            controller: _controller,
            focusNode: _focus,
            keyboardType: TextInputType.numberWithOptions(
              decimal: _decimals > 0,
              signed: true,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(_decimals > 0 ? r'[0-9.,\-−]' : r'[0-9\-−]'),
              ),
              LengthLimitingTextInputFormatter(10),
            ],
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: l10n.moneyExtraHint,
              suffixText: symbol,
              errorText: _bad ? l10n.moneyExtraInvalid : null,
              errorMaxLines: 3,
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      key: const ValueKey('day-extra-amount-clear'),
                      tooltip: l10n.moneyExtraClear,
                      icon: Icon(
                        AppIcons.close,
                        size: IconSize.inline,
                        color: colors.textMuted,
                      ),
                      onPressed: _clearField,
                    ),
            ),
            onChanged: _onChanged,
            onSubmitted: (_) => _commit(),
          ),
        ),
      ],
    );
  }
}
