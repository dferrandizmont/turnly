import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'confirm_dialog.dart';

/// Protects a sheet's draft when the system Back button is pressed.
class UnsavedChangesGuard extends StatelessWidget {
  const UnsavedChangesGuard({
    super.key,
    required this.hasChanges,
    required this.child,
  });

  final bool hasChanges;
  final Widget child;

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: !hasChanges,
    onPopInvokedWithResult: (didPop, _) async {
      // A nested picker or confirmation owns Back while it covers the form.
      if (didPop || ModalRoute.of(context)?.isCurrent != true) return;
      FocusScope.of(context).unfocus();
      final l10n = context.l10n;
      final discard = await showConfirmDialog(
        context,
        title: l10n.discardChangesTitle,
        body: l10n.discardChangesBody,
        confirmLabel: l10n.discardChangesConfirm,
        cancelLabel: l10n.discardChangesKeep,
        destructive: true,
        scrollable: true,
      );
      if (discard && context.mounted) Navigator.pop(context);
    },
    child: child,
  );
}
