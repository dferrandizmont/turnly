import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/theme_context.dart';

/// Whether the field that has the focus is typed with a number pad: on iOS
/// that pad has no Return or Done key, so the person has no way to close it
/// (1.1.0 QA, F4).
bool numberPadHasFocus() {
  final context = FocusManager.instance.primaryFocus?.context;
  final field = context?.findAncestorWidgetOfExactType<EditableText>();
  final type = field?.keyboardType;
  return type != null && type.index == TextInputType.number.index;
}

/// The bar with «Listo» that sits right above the keyboard while a number
/// pad is up; it takes the focus away, which closes the pad.
///
/// [AppSheetBody] puts it at the bottom of every padded sheet, so the
/// number fields of all the sheets close the same way.
class KeyboardDoneBar extends StatelessWidget {
  const KeyboardDoneBar({super.key});

  /// Its height: one touch target.
  static const double height = Sp.x3 + Sp.l;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.border)),
        ),
        child: SizedBox(
          height: height,
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.s),
              child: TextButton(
                key: const ValueKey('keyboard-done'),
                onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
                child: Text(context.l10n.keyboardDone),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
