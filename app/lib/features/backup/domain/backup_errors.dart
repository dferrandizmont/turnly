import '../../notes/domain/note_attachment.dart' show BrokenAttachment;

/// Why a `.cuadrante` file cannot be used. Every failure of reading a backup
/// is one of these, so the UI can show a clear message and nothing else is
/// touched (docs/copia-de-seguridad.md, matrix rows R6 and R7).
sealed class BackupException implements Exception {
  const BackupException(this.message);

  /// Developer-facing detail (English). The UI maps the subtype to its own
  /// localised text.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The bytes are not a Cuadrante backup at all (not gzip, or a JSON document
/// that is not ours).
class NotACuadranteFile extends BackupException {
  const NotACuadranteFile(super.message);
}

/// The file was written by a newer version of the app (R6): [found] is above
/// what this build reads ([supported]).
class NewerFormatVersion extends BackupException {
  const NewerFormatVersion({required this.found, required this.supported})
    : super('Backup format v$found is newer than the supported v$supported');

  final int found;
  final int supported;
}

/// The file is ours but damaged (R7): bad gzip, truncated, invalid JSON,
/// failed checksum or inconsistent data.
class CorruptBackup extends BackupException {
  const CorruptBackup(super.message);
}

/// A copy (or an export) cannot be made as it is because some attachments
/// have no usable file: it is missing or is not what the row says. The
/// strict paths (the manual export) refuse with this, naming which
/// attachments ([attachments]: ids and faults, never file names), instead of
/// writing a copy that lacks them silently; the automatic copies skip those
/// attachments and report them as a `BackupWarning` instead.
class BrokenAttachments extends CorruptBackup {
  BrokenAttachments(this.attachments)
    : super(
        'Attachments without a usable file: '
        '${attachments.map((a) => '${a.id} (${a.fault.name})').join(', ')}',
      );

  final List<BrokenAttachment> attachments;
}
