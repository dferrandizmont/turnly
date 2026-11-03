import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../import/data/import_file_picker.dart' show deleteIfCached;
import '../domain/note_attachment.dart';

/// Where a photo comes from.
enum PhotoSource {
  /// The camera of the system.
  camera,

  /// The gallery of the system (a photo already taken).
  gallery,
}

/// A file the user picked to attach to a day: its bytes, its type and the
/// name it had (photos and drawings have none).
class PickedAttachment {
  const PickedAttachment({
    required this.bytes,
    required this.mimeType,
    this.displayName,
  });

  final Uint8List bytes;

  /// The type of the file, always one the database accepts
  /// ([isAttachmentMimeType]).
  final String mimeType;

  /// The name of the file, when the user picked one (`null` for a photo).
  final String? displayName;
}

/// Why a file could not be attached.
enum PickProblem {
  /// The file is bigger than an attachment may be.
  tooLarge,

  /// The file could not be read.
  unreadable,

  /// The camera of the system said no (the permission was denied).
  cameraDenied,

  /// The gallery of the system said no (the permission was denied).
  galleryDenied,
}

/// What a pick ended with.
sealed class PickResult {
  const PickResult();
}

/// The file the user picked.
class PickedFile extends PickResult {
  const PickedFile(this.attachment);

  final PickedAttachment attachment;
}

/// The user backed out: nothing happened.
class NothingPicked extends PickResult {
  const NothingPicked();
}

/// The file could not be attached.
class PickFailed extends PickResult {
  const PickFailed(this.problem);

  final PickProblem problem;
}

/// The picker of the system: the camera, the gallery and the files.
///
/// Tests replace it (there is no camera in a test): see
/// [attachmentPickerProvider].
abstract class AttachmentPicker {
  /// A photo of the camera or of the gallery.
  Future<PickResult> pickPhoto(PhotoSource source);

  /// Any file.
  Future<PickResult> pickFile();
}

/// The picker in use. Tests override it.
final attachmentPickerProvider = Provider<AttachmentPicker>(
  (ref) => const SystemAttachmentPicker(),
);

/// The picker of the system.
///
/// The photos come from `image_picker` (the official plugin of flutter.dev)
/// and the files from `file_selector` (already in the project): the camera
/// and the gallery of the system do the work, the app never asks for a
/// permission of its own.
class SystemAttachmentPicker implements AttachmentPicker {
  const SystemAttachmentPicker();

  @override
  Future<PickResult> pickPhoto(PhotoSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source == PhotoSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
      );
      if (file == null) return const NothingPicked();
      return await _read(file, mimeType: file.mimeType, name: null);
    } on PlatformException {
      // The system refused (the permission was denied): it says so instead
      // of falling.
      return PickFailed(
        source == PhotoSource.camera
            ? PickProblem.cameraDenied
            : PickProblem.galleryDenied,
      );
    } catch (_) {
      return const PickFailed(PickProblem.unreadable);
    }
  }

  @override
  Future<PickResult> pickFile() async {
    // No filter: any file may be what the user wants to keep with the day
    // (a PDF, a payslip, a photo...).
    final file = await openFile(acceptedTypeGroups: const []);
    if (file == null) return const NothingPicked();
    return _read(file, mimeType: mimeTypeOfName(file.name), name: file.name);
  }

  Future<PickResult> _read(
    XFile file, {
    required String? mimeType,
    required String? name,
  }) async {
    try {
      final length = await file.length();
      if (length > maxAttachmentBytes) {
        return const PickFailed(PickProblem.tooLarge);
      }
      final bytes = await file.readAsBytes();
      if (bytes.length > maxAttachmentBytes) {
        return const PickFailed(PickProblem.tooLarge);
      }
      return PickedFile(
        PickedAttachment(
          bytes: bytes,
          mimeType: safeMimeType(mimeType),
          displayName: attachmentDisplayName(name),
        ),
      );
    } catch (_) {
      return const PickFailed(PickProblem.unreadable);
    } finally {
      // The copy the system leaves in the cache of the app is not ours to
      // keep (it can be 12 MB of a photo).
      await deleteIfCached(file.path, getTemporaryDirectory);
    }
  }
}

/// The type of a file the database accepts: the one the system said, or
/// `application/octet-stream` when it said nothing useful.
String safeMimeType(String? mimeType) {
  final lower = mimeType?.trim().toLowerCase();
  if (lower == null || lower.isEmpty) return 'application/octet-stream';
  return isAttachmentMimeType(lower) ? lower : 'application/octet-stream';
}

/// The name of a picked file, or `null` when there is none to show.
///
/// Android ends every file whose type it does not know with «.bin»; that
/// name is made up, so the app does not repeat it to the user (the same as
/// in the import).
String? attachmentDisplayName(String? name) {
  final trimmed = name?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  if (trimmed.toLowerCase().endsWith('.bin')) return null;
  if (trimmed.length > maxAttachmentNameLength) {
    return trimmed.substring(0, maxAttachmentNameLength);
  }
  return trimmed;
}

/// The type of a file from its name, when the system does not say it.
String mimeTypeOfName(String name) {
  final lower = name.toLowerCase();
  final dot = lower.lastIndexOf('.');
  if (dot < 0 || dot == lower.length - 1) return 'application/octet-stream';
  return switch (lower.substring(dot + 1)) {
    'pdf' => 'application/pdf',
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'heic' => 'image/heic',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    'txt' => 'text/plain',
    'csv' => 'text/csv',
    'ics' => 'text/calendar',
    'doc' => 'application/msword',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls' => 'application/vnd.ms-excel',
    'xlsx' =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'zip' => 'application/zip',
    _ => 'application/octet-stream',
  };
}
