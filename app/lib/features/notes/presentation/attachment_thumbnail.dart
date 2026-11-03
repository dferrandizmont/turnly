import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/icons/app_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../application/notes_providers.dart';
import '../data/attachment_store.dart';
import '../domain/note_attachment.dart';
import 'note_format.dart';

/// The bytes of an attachment (the file in the store of the app). `null`
/// when the file is not there (a row left without its file, a store swept
/// too early).
final attachmentBytesProvider = FutureProvider.family<Uint8List?, String>(
  (ref, relativePath) async {
    final store = await ref.watch(attachmentStoreProvider.future);
    try {
      return await store.read(relativePath);
    } on AttachmentStoreException {
      return null;
    }
  },
);

/// The thumbnail of an attachment: the picture itself when it is one (a
/// photo or a drawing), the icon of a file when it is not.
///
/// The name of the attachment is what the reader of screen says; the tile
/// itself is a button when it can be opened.
class AttachmentThumbnail extends ConsumerWidget {
  const AttachmentThumbnail({
    super.key,
    required this.attachment,
    this.onTap,
    this.onLongPress,
    this.size = Disc.xl,
  });

  final NoteAttachment attachment;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// The side of the tile (dp).
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;
    final name = attachmentName(l10n, attachment);
    final bytes = ref.watch(attachmentBytesProvider(attachment.relativePath));
    final isImage =
        attachment.kind != AttachmentKind.file ||
        attachment.mimeType.startsWith('image/');

    final tile = Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(Rad.inner),
        border: Border.all(color: colors.border),
      ),
      child: bytes.when(
        loading: () => const SizedBox.shrink(),
        error: (_, _) => _broken(colors),
        data: (data) {
          if (data == null || !isImage) return _fileIcon(colors);
          return Image.memory(
            data,
            key: ValueKey('attachment-image-${attachment.id}'),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => _fileIcon(colors),
          );
        },
      ),
    );

    final button = Semantics(
      container: true,
      button: onTap != null,
      label: onTap == null ? name : l10n.noteAttachmentOpen(name),
      // The long press is the way to take it off the day: the reader of
      // screen has to know it.
      hint: onLongPress == null ? null : l10n.noteAttachmentRemoveHint(name),
      excludeSemantics: true,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(Rad.inner),
          child: tile,
        ),
      ),
    );
    return SizedBox(width: size, height: size, child: button);
  }

  Widget _fileIcon(AppColors colors) => Center(
    child: Icon(AppIcons.file, size: IconSize.base, color: colors.textMuted),
  );

  Widget _broken(AppColors colors) => Center(
    child: Icon(AppIcons.error, size: IconSize.base, color: colors.textMuted),
  );
}
