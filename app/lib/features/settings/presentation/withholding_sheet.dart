import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/labeled_field.dart';
import '../application/preferences_controller.dart';
import '../domain/preferences.dart';
import 'settings_widgets.dart';

/// Opens the sheet where the person sets the withholding of their pay (P9):
/// a whole percentage between 0 and 100 that the summary uses for the net
/// estimate. A write that fails says so (the controller puts the previous
/// value back).
Future<void> editWithholding(BuildContext context, WidgetRef ref) async {
  final current = ref.read(preferencesProvider).withholdingPercent;
  final picked = await showAppSheet<int>(
    context: context,
    padded: true,
    builder: (_) => _WithholdingSheet(initial: current),
  );
  if (picked == null || !context.mounted) return;
  await saveSetting(
    context,
    () => ref.read(preferencesProvider.notifier).setWithholdingPercent(picked),
  );
}

class _WithholdingSheet extends StatefulWidget {
  const _WithholdingSheet({required this.initial});

  final int initial;

  @override
  State<_WithholdingSheet> createState() => _WithholdingSheetState();
}

class _WithholdingSheetState extends State<_WithholdingSheet> {
  late final _field = TextEditingController(
    text: widget.initial == 0 ? '' : '${widget.initial}',
  );
  bool _invalid = false;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _save() {
    // Empty means no withholding.
    final text = _field.text.trim();
    final percent = text.isEmpty ? 0 : int.tryParse(text);
    if (percent == null || !isValidWithholdingPercent(percent)) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.pop(context, percent);
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
          child: Text(l10n.moneyWithholdingTitle, style: type.headline),
        ),
        const SizedBox(height: Sp.l),
        LabeledField(
          label: l10n.moneyWithholdingField,
          helper: l10n.moneyWithholdingHelper,
          child: TextField(
            key: const ValueKey('withholding-field'),
            controller: _field,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            decoration: InputDecoration(
              hintText: l10n.moneyWithholdingNone,
              suffixText: '%',
              errorText: _invalid ? l10n.moneyWithholdingInvalid : null,
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
          key: const ValueKey('withholding-save'),
          label: l10n.save,
          onPressed: _save,
        ),
      ],
    );
  }
}
