import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/icons/app_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/content_app_bar.dart';
import '../../../core/widgets/error_state.dart';
import '../application/notes_providers.dart';
import '../domain/note_attachment.dart';
import 'attachment_thumbnail.dart';
import 'attachments_section.dart';
import 'note_format.dart';

/// The row of the attachment, by its id.
final attachmentByIdProvider = FutureProvider.family<NoteAttachment?, String>(
  (ref, id) => ref.watch(noteAttachmentsRepositoryProvider).byId(id),
);

/// «Adjunto» of a day (`/dia/adjunto?id=<id>`): the attachment full screen.
///
/// A photo or a drawing fills it; a file that is not a picture shows its
/// name and its size. The «Quitar» of the bar takes it away from the day:
/// the day detail is left with the undo that brings it back.
class AttachmentViewerScreen extends ConsumerWidget {
  const AttachmentViewerScreen({super.key, required this.id});

  /// The id of the attachment (`note_attachments.id`).
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final attachment = ref.watch(attachmentByIdProvider(id));
    final found = attachment.value;

    return Scaffold(
      appBar: ContentAppBar.adaptive(
        context,
        title: Text(
          found == null
              ? l10n.noteAttachmentsViewerTitle
              : attachmentName(l10n, found),
        ),
        actions: [
          if (found != null)
            IconButton(
              key: const ValueKey('attachment-remove'),
              tooltip: l10n.noteAttachmentRemove(attachmentName(l10n, found)),
              icon: Icon(AppIcons.erase),
              onPressed: () => _remove(context, ref, found),
            ),
        ],
      ),
      body: attachment.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorState(
          onRetry: () => ref.invalidate(attachmentByIdProvider(id)),
        ),
        data: (row) {
          if (row == null) {
            return ErrorState(
              onRetry: () => ref.invalidate(attachmentByIdProvider(id)),
            );
          }
          final bytes = ref.watch(attachmentBytesProvider(row.relativePath));
          final isImage =
              row.kind != AttachmentKind.file ||
              row.mimeType.startsWith('image/');
          return bytes.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => ErrorState(
              onRetry: () =>
                  ref.invalidate(attachmentBytesProvider(row.relativePath)),
            ),
            data: (data) {
              if (data == null || !isImage) {
                return _FileCard(attachment: row);
              }
              return Center(
                child: InteractiveViewer(
                  child: Image.memory(
                    data,
                    key: const ValueKey('attachment-view-image'),
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => _FileCard(attachment: row),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    NoteAttachment attachment,
  ) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final key = DayKey(attachment.calendarId, attachment.date);
    final gone = await removeAttachment(ref, key, attachment);
    if (!gone) {
      // The notice is visible here: this screen has its own scaffold.
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(appSnackBar(content: Text(l10n.noteAttachmentFailed)));
      return;
    }
    if (!context.mounted) return;
    // The day detail shows the undo (a notice would hide behind its sheet).
    context.pop();
  }
}

/// A file that is not a picture: its icon, its name and its size.
class _FileCard extends StatelessWidget {
  const _FileCard({required this.attachment});

  final NoteAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Sp.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.file, size: IconSize.hero, color: colors.textMuted),
            const SizedBox(height: Sp.l),
            Semantics(
              header: true,
              child: Text(
                attachmentName(l10n, attachment),
                key: const ValueKey('attachment-file-name'),
                style: type.title,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: Sp.xs),
            Text(
              attachmentSize(attachment.sizeBytes, l10n.localeName),
              key: const ValueKey('attachment-file-size'),
              style: type.meta,
            ),
          ],
        ),
      ),
    );
  }
}
