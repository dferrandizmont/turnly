import 'package:flutter/material.dart';

import '../../../core/format/currencies.dart';
import '../../../core/format/money.dart';
import '../../../core/format/text_fold.dart';
import '../../../core/icons/selection_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/choice_row.dart';

/// Ajustes › Apariencia › Moneda: a tall sheet with a search field and the
/// currencies, the common ones first (euro, dollar, the money of Latin
/// America...) and then the rest alphabetically. Searching matches the code
/// or the symbol ("usd", "$", "r$"). Returns the ISO 4217 code, or `null`
/// when dismissed.
///
/// Keys: `currency-search`, `currency-option-EUR`.
Future<String?> showCurrencySheet({
  required BuildContext context,
  required String selected,
  required String locale,
}) {
  return showAppSheet<String>(
    context: context,
    builder: (ctx) {
      final media = MediaQuery.of(ctx);
      final height =
          (media.size.height - media.padding.top - media.viewInsets.bottom) *
          0.9;
      return Padding(
        padding: EdgeInsets.fromLTRB(
          Sp.page,
          0,
          Sp.page,
          media.viewInsets.bottom,
        ),
        child: SizedBox(
          height: height,
          child: CurrencyPicker(
            selected: selected,
            locale: locale,
            onSelected: (code) => Navigator.pop(ctx, code),
          ),
        ),
      );
    },
  );
}

/// The title, the note about not converting, the search and the list. Fills
/// the height its parent gives it.
class CurrencyPicker extends StatefulWidget {
  const CurrencyPicker({
    super.key,
    required this.selected,
    required this.locale,
    required this.onSelected,
  });

  final String selected;

  /// The locale the symbols are shown in ("es_MX").
  final String locale;
  final ValueChanged<String> onSelected;

  @override
  State<CurrencyPicker> createState() => _CurrencyPickerState();
}

class _CurrencyPickerState extends State<CurrencyPicker> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// The currencies whose code or symbol contains [text]; with no text, all
  /// of them. Codes that start with the text go first.
  List<String> _filter(List<String> codes, String text) {
    final q = foldSpanish(text.trim());
    if (q.isEmpty) return codes;
    String symbolOf(String code) =>
        foldSpanish(currencySymbol(widget.locale, code));
    bool starts(String code) =>
        foldSpanish(code).startsWith(q) || symbolOf(code).startsWith(q);
    bool has(String code) =>
        foldSpanish(code).contains(q) || symbolOf(code).contains(q);
    return [
      ...codes.where(starts),
      ...codes.where((c) => !starts(c) && has(c)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    // The chosen currency is always in the list, also when it is not one of
    // the offered (an older build or a backup stored it).
    final extra = allCurrencies.contains(widget.selected)
        ? const <String>[]
        : [widget.selected];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: Sp.xs),
          child: Semantics(
            header: true,
            child: Text(l10n.settingsCurrencyTitle, style: type.headline),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: Sp.m),
          child: Text(
            l10n.settingsCurrencyNote,
            key: const ValueKey('currency-note'),
            style: type.meta.copyWith(color: colors.textMuted),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: Sp.s),
          child: TextField(
            key: const ValueKey('currency-search'),
            controller: _query,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l10n.settingsCurrencySearchHint,
              prefixIcon: Icon(SelectionIcons.search, color: colors.textMuted),
            ),
          ),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: _query,
            builder: (context, _) {
              final searching = _query.text.trim().isNotEmpty;
              final common = _filter([
                ...extra,
                ...commonCurrencies,
              ], _query.text);
              final others = _filter(otherCurrencies, _query.text);
              if (common.isEmpty && others.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(Sp.l),
                    child: Text(
                      l10n.settingsCurrencyNone,
                      textAlign: TextAlign.center,
                      style: type.body.copyWith(color: colors.textMuted),
                    ),
                  ),
                );
              }
              // Headings only while browsing: a search is a single list.
              // Each entry is (text, isHeading).
              final entries = <(String, bool)>[
                if (!searching && common.isNotEmpty)
                  (l10n.settingsCurrencyCommon, true),
                for (final code in common) (code, false),
                if (!searching && others.isNotEmpty)
                  (l10n.settingsCurrencyAll, true),
                for (final code in others) (code, false),
              ];
              return ListView.builder(
                itemCount: entries.length,
                itemBuilder: (context, i) {
                  final (text, isHeading) = entries[i];
                  return isHeading ? _Heading(text) : _row(text);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _row(String code) {
    final symbol = currencySymbol(widget.locale, code);
    return ChoiceRow(
      key: ValueKey('currency-option-$code'),
      label: code,
      subtitle: symbol == code ? null : symbol,
      selected: code == widget.selected,
      onTap: () => widget.onSelected(code),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Sp.xs, Sp.m, Sp.xs, Sp.xs),
    child: Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        style: context.type.label.copyWith(color: context.colors.textMuted),
      ),
    ),
  );
}
