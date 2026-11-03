import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../notes/domain/note_attachment.dart'
    show maxAttachmentFiles, maxAttachmentStoreBytes;
import 'backup_errors.dart';

/// The `.turnly` that carries attachment files (database v6,
/// docs/copia-de-seguridad.md, «Contenedor con adjuntos»): a ZIP archive
/// with, in this order,
///
/// - `turnly-container.json`: `{"format":"turnly-container","version":1}`;
/// - `backup.turnly`: a normal gzip `.turnly`, byte for byte what the app
///   would write without attachments (its `data` lists the attachments with
///   size and SHA-256, so the checksum covers the files too);
/// - `attachments/<id>`: the bytes of each attachment, named by its id.
///
/// Every entry is **stored** (no compression): photos and PDFs barely
/// compress, and a reader that never inflates cannot be fed a ZIP bomb; the
/// whole archive is bounded by its own size. A reader refuses compressed or
/// encrypted entries, repeated names, and entries whose bytes overlap or
/// together exceed the file (one blob listed thousands of times would
/// otherwise cost thousands of SHA-256 passes). The ZIP CRC is **not**
/// checked (the `archive` package does not): the inner file has its own
/// gzip CRC and checksum, and every attachment its SHA-256.
///
/// A copy without attachments is never a container: it is the plain gzip
/// file, which every version of the app reads.
class BackupContainer {
  const BackupContainer._();

  static const String manifestName = 'turnly-container.json';
  static const String backupName = 'backup.turnly';
  static const String attachmentsPrefix = 'attachments/';
  static const String formatName = 'turnly-container';

  /// The container version this build writes and the newest it reads.
  static const int supportedVersion = 1;

  /// Most bytes the inner backup (a plain `.turnly`) may have; also
  /// `BackupCodec.maxFileBytes`.
  static const int maxInnerBackupBytes = 8 * 1024 * 1024;

  /// What the ZIP structure (headers, central directory, manifest) may add
  /// on top of the files and the inner backup.
  static const int zipOverheadBytes = 1024 * 1024;

  /// Most bytes a container may have, and so the most any import or export
  /// path of the app accepts (`BackupCodec.maxImportBytes`, Dart and native):
  /// the whole store of attachments (`maxAttachmentStoreBytes`), plus an inner
  /// backup of up to [maxInnerBackupBytes], plus the structure. The files live in
  /// memory while they are read or written. A copy the app makes of
  /// everything it holds therefore always fits, and nothing bigger is read.
  static const int maxContainerBytes =
      maxAttachmentStoreBytes + maxInnerBackupBytes + zipOverheadBytes;

  /// Most entries besides the manifest and the backup: the most files the
  /// store can hold (`maxAttachmentFiles`), so a copy of everything always
  /// lists them all.
  static const int maxAttachmentEntries = maxAttachmentFiles;

  /// Whether [bytes] start like a ZIP archive (`PK\x03\x04`).
  static bool looksLikeContainer(Uint8List bytes) =>
      bytes.length >= 4 &&
      bytes[0] == 0x50 &&
      bytes[1] == 0x4b &&
      bytes[2] == 0x03 &&
      bytes[3] == 0x04;

  /// The start of the inner backup (`backup.turnly`, a gzip file) taken from
  /// the **first bytes** of a container, which may be cut anywhere (the list
  /// of copies reads only the head of each file): the local headers are
  /// walked from the start (the manifest, then the backup; at most four
  /// headers), and what is in [head] of the backup's bytes is returned.
  /// `null` when [head] is not the start of one of our containers (not ZIP, a
  /// compressed entry, an entry whose size is not in its local header, the
  /// backup not reached yet). Nothing is decoded and nothing is trusted: the
  /// caller only peeks at it.
  static Uint8List? peekBackupHead(Uint8List head) {
    final data = ByteData.sublistView(head);
    var offset = 0;
    for (var i = 0; i < 4; i++) {
      if (offset < 0 || offset + 30 > head.length) return null;
      if (data.getUint32(offset, Endian.little) != 0x04034b50) return null;
      final flags = data.getUint16(offset + 6, Endian.little);
      final method = data.getUint16(offset + 8, Endian.little);
      final size = data.getUint32(offset + 18, Endian.little);
      final nameLength = data.getUint16(offset + 26, Endian.little);
      final extraLength = data.getUint16(offset + 28, Endian.little);
      // Stored, and with its size in this header (no data descriptor).
      if (method != 0 || flags & 0x8 != 0) return null;
      final nameStart = offset + 30;
      final dataStart = nameStart + nameLength + extraLength;
      if (dataStart > head.length) return null;
      final name = String.fromCharCodes(
        head.sublist(nameStart, nameStart + nameLength),
      );
      if (name == backupName) {
        final end = dataStart + size;
        return Uint8List.sublistView(
          head,
          dataStart,
          end > head.length ? head.length : end,
        );
      }
      offset = dataStart + size;
    }
    return null;
  }

  /// Entry name of the attachment [id].
  static String entryNameOf(String id) => '$attachmentsPrefix$id';

  /// The archive of [backup] (a plain `.turnly`) and [files] (attachment id
  /// -> bytes), entries sorted by name with a fixed date, so the same input
  /// gives the same bytes.
  static Uint8List encode({
    required Uint8List backup,
    required Map<String, Uint8List> files,
  }) {
    if (files.length > maxAttachmentEntries) {
      throw const CorruptBackup('Too many attachments');
    }
    final archive = Archive();
    void add(String name, Uint8List bytes) {
      archive.add(
        ArchiveFile.noCompress(name, bytes.length, bytes)
          ..lastModTime = _fixedTime,
      );
    }

    add(
      manifestName,
      Uint8List.fromList(
        utf8.encode(
          jsonEncode({'format': formatName, 'version': supportedVersion}),
        ),
      ),
    );
    add(backupName, backup);
    for (final id in files.keys.toList()..sort()) {
      add(entryNameOf(id), files[id]!);
    }
    final bytes = ZipEncoder().encodeBytes(
      archive,
      level: 0,
      modified: DateTime.utc(1980),
    );
    if (bytes.length > maxContainerBytes) {
      throw const CorruptBackup('File is too large');
    }
    return bytes;
  }

  /// Opens a container: the inner plain `.turnly` and every
  /// `attachments/<id>` entry. Checks only the container itself (the caller
  /// decodes the backup and matches the files against it). Throws:
  /// - [NotACuadranteFile]: not a ZIP, or not our manifest;
  /// - [NewerFormatVersion]: a container version this build does not know;
  /// - [CorruptBackup]: anything else wrong (too big, compressed or
  ///   encrypted entries, repeated names, missing backup).
  static ({Uint8List backup, Map<String, Uint8List> files}) decode(
    Uint8List bytes,
  ) {
    if (!looksLikeContainer(bytes)) {
      throw const NotACuadranteFile('Not a ZIP archive');
    }
    if (bytes.length > maxContainerBytes) {
      throw const CorruptBackup('File is too large');
    }
    final decoder = ZipDecoder();
    final Archive archive;
    try {
      // Parses the directory only; no entry is read yet.
      archive = decoder.decodeBytes(bytes);
    } catch (e) {
      throw CorruptBackup('Bad container: $e');
    }
    _checkLayout(bytes, decoder.directory.fileHeaders);
    final entries = <String, ArchiveFile>{
      for (final entry in archive.files)
        if (entry.isFile) entry.name: entry,
    };

    final manifest = entries[manifestName];
    if (manifest == null) {
      throw const NotACuadranteFile('Not a Turnly container');
    }
    final Object? meta;
    try {
      meta = jsonDecode(utf8.decode(_read(manifest, maxBytes: 4096)));
    } on FormatException {
      throw const NotACuadranteFile('Not a Turnly container');
    }
    if (meta is! Map<String, Object?> || meta['format'] != formatName) {
      throw const NotACuadranteFile('Not a Turnly container');
    }
    final version = meta['version'];
    if (version is! int || version < 1) {
      throw const CorruptBackup('Invalid container version');
    }
    if (version > supportedVersion) {
      throw NewerFormatVersion(found: version, supported: supportedVersion);
    }

    final backupEntry = entries[backupName];
    if (backupEntry == null) {
      throw const CorruptBackup('The container has no backup');
    }
    final files = <String, Uint8List>{};
    for (final MapEntry(key: name, value: entry) in entries.entries) {
      if (!name.startsWith(attachmentsPrefix)) continue;
      if (files.length >= maxAttachmentEntries) {
        throw const CorruptBackup('Too many attachments');
      }
      files[name.substring(attachmentsPrefix.length)] = _read(entry);
    }
    return (backup: _read(backupEntry), files: files);
  }

  /// Checks the central directory before any entry is read: at most
  /// [maxAttachmentEntries] + 2 entries, no name twice (`archive` would keep
  /// the first one silently), only stored and unencrypted entries, each one's
  /// local header where the directory says and its bytes inside the file,
  /// no two entries sharing bytes, and all of them adding up to no more
  /// than the file.
  static void _checkLayout(Uint8List bytes, List<ZipFileHeader> headers) {
    if (headers.length > maxAttachmentEntries + 2) {
      throw const CorruptBackup('Too many entries');
    }
    final names = <String>{};
    final ranges = <(int, int)>[];
    var total = 0;
    final data = ByteData.sublistView(bytes);
    for (final h in headers) {
      if (!names.add(h.filename)) {
        throw CorruptBackup('Repeated entry "${h.filename}"');
      }
      if (h.compressionMethod != 0 || h.generalPurposeBitFlag & 1 != 0) {
        throw CorruptBackup('Compressed or encrypted entry "${h.filename}"');
      }
      if (h.compressedSize != h.uncompressedSize) {
        throw CorruptBackup('Damaged entry "${h.filename}"');
      }
      final start = h.localHeaderOffset;
      if (start < 0 || start + 30 > bytes.length) {
        throw CorruptBackup('Entry "${h.filename}" is outside the file');
      }
      if (data.getUint32(start, Endian.little) != 0x04034b50) {
        throw CorruptBackup('Entry "${h.filename}" has no local header');
      }
      final nameLength = data.getUint16(start + 26, Endian.little);
      final extraLength = data.getUint16(start + 28, Endian.little);
      final end = start + 30 + nameLength + extraLength + h.compressedSize;
      if (h.compressedSize < 0 || end > bytes.length) {
        throw CorruptBackup('Entry "${h.filename}" is outside the file');
      }
      total += h.compressedSize;
      ranges.add((start, end));
    }
    if (total > bytes.length) {
      throw const CorruptBackup('Entries larger than the file');
    }
    ranges.sort((a, b) => a.$1.compareTo(b.$1));
    for (var i = 1; i < ranges.length; i++) {
      if (ranges[i].$1 < ranges[i - 1].$2) {
        throw const CorruptBackup('Overlapping entries');
      }
    }
  }

  /// The bytes of a stored entry, refusing anything that would need
  /// inflating or decrypting, or that is bigger than declared or than
  /// [maxBytes].
  static Uint8List _read(ArchiveFile entry, {int? maxBytes}) {
    final compression = entry.compression;
    if (compression != null && compression != CompressionType.none) {
      throw CorruptBackup('Compressed entry "${entry.name}"');
    }
    if (maxBytes != null && entry.size > maxBytes) {
      throw CorruptBackup('Entry "${entry.name}" is too large');
    }
    final Uint8List? bytes;
    try {
      bytes = entry.readBytes();
    } catch (e) {
      throw CorruptBackup('Unreadable entry "${entry.name}": $e');
    }
    if (bytes == null || bytes.length != entry.size) {
      throw CorruptBackup('Damaged entry "${entry.name}"');
    }
    return bytes;
  }

  /// 1980-01-01 00:00:00 UTC, the first instant a ZIP date can hold.
  static const int _fixedTime = 315532800;
}
