import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/icons/app_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/router.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/error_state.dart';
import '../../calendar/application/schedule_controller.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../application/notes_providers.dart';
import '../data/attachment_picker.dart';
import '../data/attachment_store.dart';
import '../domain/note_attachment.dart';
import 'attachment_history.dart';
import 'attachment_thumbnail.dart';
import 'note_format.dart';
import 'note_message.dart';

/// The name of the section inside «Más opciones» of the day detail, from the
/// ARB files.
String noteAttachmentsSectionName(AppLocalizations l10n) =>
    l10n.noteAttachmentsSection;

/// The section of the day detail for [date] (P2): the photos, the files and
/// the drawings of that day.
Widget noteAttachmentsSection(BuildContext context, CivilDate date) =>
    AttachmentsSection(date: date);

/// «Adjuntos» inside «Más opciones» of the day detail: the strip of
/// thumbnails of the day, the way to add one (a photo, a file or a drawing)
/// and the way to remove it (with the undo that puts it back).
class AttachmentsSection extends ConsumerStatefulWidget {
  const AttachmentsSection({super.key, required this.date});

  /// The day the attachments belong to.
  final CivilDate date;

  @override
  ConsumerState<AttachmentsSection> createState() => _AttachmentsSectionState();
}

class _AttachmentsSectionState extends ConsumerState<AttachmentsSection> {
  /// Why the last attempt failed (`null` when it worked). It stays in the
  /// section: a notice would hide behind the sheet of the day.
  String? _error;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    final calendarId = ref.watch(
      scheduleControllerProvider.select((s) => s.calendarId),
    );
    final key = DayKey(calendarId, widget.date);
    final attachments = ref.watch(dayAttachmentsProvider(key));
    // What was removed last, so the undo is right there.
    final removed = ref.watch(
      dayAttachmentHistoryProvider.select(
        (history) => history[attachmentHistoryKey(key)],
      ),
    );

    return Column(
      key: const ValueKey('day-attachments-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Sp.l),
        Semantics(
          header: true,
          child: Text(
            l10n.noteAttachmentsSection.toUpperCase(),
            style: type.label.copyWith(color: colors.textMuted),
          ),
        ),
        const SizedBox(height: Sp.s),
        attachments.when(
          loading: () => const SizedBox(
            height: Disc.l,
            child: Center(child: ButtonSpinner()),
          ),
          error: (_, _) => ErrorState(
            compact: true,
            onRetry: () => ref.invalidate(dayAttachmentsProvider(key)),
          ),
          data: (list) => list.isEmpty
              ? _EmptyAttachments(onAdd: () => _add(key))
              : _AttachmentStrip(
                  attachments: list,
                  onOpen: (attachment) => context.push(
                    AppRoutes.attachmentOf(attachment.id),
                  ),
                  onRemove: (attachment) => _remove(key, attachment),
                  onAdd: () => _add(key),
                ),
        ),
        if (_error != null)
          NoteMessage(
            key: const ValueKey('day-attachments-error'),
            text: _error!,
            isError: true,
          )
        else if (removed != null)
          NoteMessage(
            key: const ValueKey('day-attachments-undo'),
            text: l10n.noteAttachmentRemoved(
              attachmentName(l10n, removed.attachment),
            ),
            undoLabel: l10n.undo,
            undoKey: const ValueKey('day-attachments-undo-button'),
            onUndo: () => undoRemovedAttachment(ref, key),
          ),
      ],
    );
  }

  Future<void> _add(DayKey key) async {
    final choice = await showAddAttachmentSheet(context);
    if (choice == null || !mounted) return;
    switch (choice) {
      case AddAttachmentChoice.camera:
        await _pickPhoto(key, PhotoSource.camera);
      case AddAttachmentChoice.gallery:
        await _pickPhoto(key, PhotoSource.gallery);
      case AddAttachmentChoice.file:
        await _pickFile(key);
      case AddAttachmentChoice.sketch:
        await context.push(AppRoutes.sketchFor(key.date, key.calendarId));
    }
  }

  Future<void> _pickPhoto(DayKey key, PhotoSource source) async {
    final result = await ref.read(attachmentPickerProvider).pickPhoto(source);
    if (!mounted) return;
    await _afterPick(key, result, AttachmentKind.photo);
  }

  Future<void> _pickFile(DayKey key) async {
    final result = await ref.read(attachmentPickerProvider).pickFile();
    if (!mounted) return;
    await _afterPick(key, result, AttachmentKind.file);
  }

  Future<void> _afterPick(
    DayKey key,
    PickResult result,
    AttachmentKind kind,
  ) async {
    final l10n = context.l10n;
    switch (result) {
      case NothingPicked():
        return;
      case PickFailed(:final problem):
        _say(switch (problem) {
          PickProblem.tooLarge => l10n.noteAttachmentTooLarge,
          PickProblem.unreadable => l10n.noteAttachmentUnreadable,
          PickProblem.cameraDenied => l10n.noteAttachmentCameraDenied,
          PickProblem.galleryDenied => l10n.noteAttachmentGalleryDenied,
        });
      case PickedFile(:final attachment):
        try {
          await ref
              .read(dayAttachmentsProvider(key).notifier)
              .add(
                kind: kind,
                bytes: attachment.bytes,
                mimeType: attachment.mimeType,
                displayName: attachment.displayName,
              );
          _say(null);
        } on AttachmentStoreException catch (error) {
          _say(
            error.problem == AttachmentProblem.storeFull
                ? l10n.noteAttachmentStoreFull
                : l10n.noteAttachmentTooLarge,
          );
        } catch (_) {
          _say(l10n.noteAttachmentFailed);
        }
    }
  }

  /// Takes an attachment off the day (the undo puts it back).
  Future<void> _remove(DayKey key, NoteAttachment attachment) async {
    final l10n = context.l10n;
    final gone = await removeAttachment(ref, key, attachment);
    if (!gone) _say(l10n.noteAttachmentRemoveFailed);
  }

  /// Says it in the section (never throws).
  void _say(String? message) {
    if (!mounted) return;
    setState(() => _error = message);
  }
}

/// Removes an attachment and remembers it, so the section can put it back.
///
/// The bytes are read before the file goes away: the undo puts the very same
/// file back, with the very same name. Returns whether it went.
Future<bool> removeAttachment(
  WidgetRef ref,
  DayKey key,
  NoteAttachment attachment,
) async {
  final bytes = await ref.read(
    attachmentBytesProvider(attachment.relativePath).future,
  );
  try {
    await ref.read(dayAttachmentsProvider(key).notifier).remove(attachment.id);
  } catch (_) {
    return false;
  }
  if (bytes == null) {
    // The file was not there: there is nothing to put back.
    return true;
  }
  ref
      .read(dayAttachmentHistoryProvider.notifier)
      .remember(key, RemovedAttachment(attachment: attachment, bytes: bytes));
  return true;
}

/// Puts back the attachment that was removed last from the day.
Future<void> undoRemovedAttachment(WidgetRef ref, DayKey key) async {
  final history = ref.read(dayAttachmentHistoryProvider.notifier);
  final removed = history.lastOf(key);
  if (removed == null) return;
  try {
    final service = await ref.read(noteAttachmentsServiceProvider.future);
    await service.add(
      calendarId: key.calendarId,
      date: key.date,
      kind: removed.attachment.kind,
      bytes: removed.bytes,
      mimeType: removed.attachment.mimeType,
      displayName: removed.attachment.displayName,
    );
    history.forget(key);
    ref.invalidate(dayAttachmentsProvider(key));
  } catch (_) {
    // The file is gone for good: nothing else to say.
  }
}

/// The empty state of the section: what the day has not got yet and the way
/// to add the first one.
///
/// It is the plain way of the other sections of the day detail (the drawing
/// of `EmptyIllustration` is for the states that wait for shifts).
class _EmptyAttachments extends StatelessWidget {
  const _EmptyAttachments({required this.onAdd});

  /// Adds the first attachment of the day.
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    return Column(
      key: const ValueKey('day-attachments-empty'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.noteAttachmentsEmptyTitle, style: type.bodyStrong),
        const SizedBox(height: Sp.hair),
        Text(
          l10n.noteAttachmentsEmptyBody,
          style: type.body.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: Sp.s),
        SecondaryButton(
          key: const ValueKey('day-attachments-add-empty'),
          icon: AppIcons.add,
          label: l10n.noteAttachmentsAdd,
          onPressed: onAdd,
        ),
      ],
    );
  }
}

/// The strip of thumbnails of the day, with the tile that adds one.
class _AttachmentStrip extends StatelessWidget {
  const _AttachmentStrip({
    required this.attachments,
    required this.onOpen,
    required this.onRemove,
    required this.onAdd,
  });

  final List<NoteAttachment> attachments;
  final void Function(NoteAttachment attachment) onOpen;
  final void Function(NoteAttachment attachment) onRemove;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    return SizedBox(
      height: Disc.xl,
      child: ListView.separated(
        key: const ValueKey('day-attachments-strip'),
        scrollDirection: Axis.horizontal,
        itemCount: attachments.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: Sp.s),
        itemBuilder: (context, index) {
          if (index == attachments.length) {
            return Semantics(
              container: true,
              button: true,
              label: l10n.noteAttachmentsAdd,
              excludeSemantics: true,
              onTap: onAdd,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  key: const ValueKey('day-attachments-add'),
                  onTap: onAdd,
                  borderRadius: BorderRadius.circular(Rad.inner),
                  child: Container(
                    width: Disc.xl,
                    height: Disc.xl,
                    decoration: BoxDecoration(
                      color: colors.surfaceMuted,
                      borderRadius: BorderRadius.circular(Rad.inner),
                      border: Border.all(color: colors.borderStrong),
                    ),
                    child: Icon(
                      AppIcons.add,
                      size: IconSize.base,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }
          final attachment = attachments[index];
          return AttachmentThumbnail(
            key: ValueKey('attachment-${attachment.id}'),
            attachment: attachment,
            onTap: () => onOpen(attachment),
            onLongPress: () => onRemove(attachment),
          );
        },
      ),
    );
  }
}

/// What the person chose to attach to the day.
enum AddAttachmentChoice { camera, gallery, file, sketch }

/// The sheet that asks what to attach to the day.
Future<AddAttachmentChoice?> showAddAttachmentSheet(BuildContext context) =>
    showAppSheet<AddAttachmentChoice>(
      context: context,
      padded: true,
      builder: (context) => const _AddAttachmentSheet(),
    );

/// The sheet with the four ways of adding something to a day.
class _AddAttachmentSheet extends StatelessWidget {
  const _AddAttachmentSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.type;
    final colors = context.colors;

    Widget option(
      IconData icon,
      String label,
      String key,
      AddAttachmentChoice choice,
    ) => InkWell(
      key: ValueKey(key),
      onTap: () => Navigator.of(context).pop(choice),
      borderRadius: BorderRadius.circular(Rad.inner),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Sp.touch),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Sp.m),
          child: Row(
            children: [
              Icon(icon, size: IconSize.base, color: colors.textSecondary),
              const SizedBox(width: Sp.m),
              Expanded(child: Text(label, style: type.bodyStrong)),
            ],
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.noteAttachmentsAdd,
            style: type.title,
          ),
        ),
        const SizedBox(height: Sp.m),
        AppCard.tinted(
          child: Column(
            children: [
              option(
                AppIcons.camera,
                l10n.noteAttachmentsAddPhoto,
                'add-photo',
                AddAttachmentChoice.camera,
              ),
              Divider(height: 1, color: colors.border),
              option(
                AppIcons.gallery,
                l10n.noteAttachmentsAddGallery,
                'add-gallery',
                AddAttachmentChoice.gallery,
              ),
              Divider(height: 1, color: colors.border),
              option(
                AppIcons.file,
                l10n.noteAttachmentsAddFile,
                'add-file',
                AddAttachmentChoice.file,
              ),
              Divider(height: 1, color: colors.border),
              option(
                AppIcons.paint,
                l10n.noteAttachmentsAddSketch,
                'add-sketch',
                AddAttachmentChoice.sketch,
              ),
            ],
          ),
        ),
        const SizedBox(height: Sp.l),
      ],
    );
  }
}
