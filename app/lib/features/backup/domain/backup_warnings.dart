import '../../notes/domain/note_attachment.dart' show BrokenAttachment;

/// Something a copy (or a restore) did that the user should know about but
/// that did not stop it. The screens translate them; nothing here is text.
sealed class BackupWarning {
  const BackupWarning();
}

/// The copy was made **without** some attachments because their files were
/// missing or damaged (a copy that is whole except for the files that were
/// already lost is better than no copy at all). Their rows stay in the
/// database until the user repairs them (`NoteAttachmentsService.repair`).
final class AttachmentsSkipped extends BackupWarning {
  const AttachmentsSkipped(this.attachments);

  /// Ids and faults of the attachments left out.
  final List<BrokenAttachment> attachments;

  @override
  bool operator ==(Object other) =>
      other is AttachmentsSkipped &&
      other.attachments.length == attachments.length &&
      [
        for (var i = 0; i < attachments.length; i++)
          attachments[i] == other.attachments[i],
      ].every((same) => same);

  @override
  int get hashCode => Object.hashAll(attachments);

  @override
  String toString() => 'AttachmentsSkipped($attachments)';
}

/// The warnings for the attachments in [broken] (none when it is empty).
List<BackupWarning> warningsFor(List<BrokenAttachment> broken) =>
    broken.isEmpty ? const [] : [AttachmentsSkipped(List.unmodifiable(broken))];

/// How many attachments the [warnings] say were left out of a copy.
int skippedAttachmentCount(List<BackupWarning> warnings) => warnings.fold(
  0,
  (sum, w) => w is AttachmentsSkipped ? sum + w.attachments.length : sum,
);
