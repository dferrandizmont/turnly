import 'package:flutter/material.dart';

import '../../../core/theme/theme_context.dart';

/// The line inside a section of the day detail that says what happened: the
/// error of a failed write, or what was removed with the «Deshacer» that puts
/// it back.
///
/// A notice (`SnackBar`) would hide behind the sheet of the day (the app
/// closes the sheet when it needs one), so the message stays where the
/// action was.
class NoteMessage extends StatelessWidget {
  const NoteMessage({
    super.key,
    required this.text,
    this.onUndo,
    this.undoLabel,
    this.undoKey,
    this.isError = false,
  });

  /// What it says.
  final String text;

  /// Puts back what was removed (`null` when there is nothing to undo).
  final VoidCallback? onUndo;

  /// The label of the undo («Deshacer»).
  final String? undoLabel;

  /// The key of the undo button.
  final Key? undoKey;

  /// Whether the message is a failure (it says in red).
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Padding(
      padding: const EdgeInsets.only(top: Sp.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              text,
              style: type.meta.copyWith(
                color: isError ? colors.danger : colors.textSecondary,
              ),
            ),
          ),
          if (onUndo != null && undoLabel != null) ...[
            const SizedBox(width: Sp.s),
            TextButton(
              key: undoKey,
              onPressed: onUndo,
              child: Text(undoLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
