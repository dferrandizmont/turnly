import 'package:intl/intl.dart';

import '../../../core/l10n/l10n.dart';
import '../domain/note_attachment.dart';

/// The name of a kind of attachment, in words («Foto», «Archivo», «Dibujo»).
String attachmentKindName(AppLocalizations l10n, AttachmentKind kind) =>
    switch (kind) {
      AttachmentKind.photo => l10n.noteAttachmentKindPhoto,
      AttachmentKind.file => l10n.noteAttachmentKindFile,
      AttachmentKind.sketch => l10n.noteAttachmentKindSketch,
    };

/// The name the person recognises: the name of the file when it has one
/// («Nómina.pdf»), the kind of the attachment otherwise («Foto», «Dibujo»).
String attachmentName(AppLocalizations l10n, NoteAttachment attachment) {
  final name = attachment.displayName?.trim();
  if (name == null || name.isEmpty) {
    return attachmentKindName(l10n, attachment.kind);
  }
  return name;
}

/// "12 KB" / "1,3 MB".
String attachmentSize(int bytes, String locale) {
  if (bytes < 1024 * 1024) {
    final kb = (bytes / 1024).ceil().clamp(1, 1023);
    return '$kb KB';
  }
  return '${NumberFormat('0.0', locale).format(bytes / (1024 * 1024))} MB';
}
