import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart' show getCrc32;

import 'backup_container.dart';
import 'backup_data.dart';
import 'backup_errors.dart';
import 'canonical_json.dart';

/// A decoded `.turnly` or legacy `.cuadrante` file: data and envelope fields.
class BackupFile {
  const BackupFile({
    required this.schemaVersion,
    required this.appVersion,
    required this.exportedAt,
    required this.checksum,
    required this.data,
    this.attachmentFiles = const {},
  });

  final int schemaVersion;

  /// Version of the app that wrote the file (informational).
  final String appVersion;

  /// UTC, second precision.
  final DateTime exportedAt;

  /// `sha256:<hex>` of the canonical JSON of [data] (already verified).
  final String checksum;

  final BackupData data;

  /// Attachment id -> bytes, already checked against the size and SHA-256
  /// of `data.noteAttachments` (database v6). Empty for a plain file.
  final Map<String, Uint8List> attachmentFiles;
}

/// Reads and writes the `.turnly` format (also accepted as `.cuadrante`):
/// see docs/copia-de-seguridad.md.
/// gzip-compressed UTF-8 JSON
/// `{appVersion, checksum, data, exportedAt, format, schemaVersion}` in
/// canonical form (sorted keys, no whitespace).
///
/// Pure: no database, no clock, no files. Every way a file can be unusable is
/// a [BackupException]; nothing else escapes [decode].
class BackupCodec {
  const BackupCodec({this.maxDecodedBytes = defaultMaxDecodedBytes});

  /// Most bytes a file may inflate to before it is rejected.
  final int maxDecodedBytes;

  /// Value of the `format` field.
  static const String formatName = 'cuadrante';

  /// The newest `schemaVersion` this build can read (and the one it writes).
  static const int supportedSchemaVersion = 3;

  /// Shared reader/writer caps. Large histories and notes may exceed 4 MiB;
  /// the absolute cap and ratio protection still bound untrusted input.
  ///
  /// [maxFileBytes] is the cap of a **plain** `.turnly` (gzip JSON, also the
  /// one inside a container). A container with attachments can be much
  /// bigger: [maxImportBytes] is the cap every import and export path (Dart
  /// and native) applies to a file before it is decoded.
  static const int maxFileBytes = BackupContainer.maxInnerBackupBytes;

  /// Most bytes any file the app reads or writes may have: the size of the
  /// biggest container ([BackupContainer.maxContainerBytes]).
  static const int maxImportBytes = BackupContainer.maxContainerBytes;

  /// Whether a file of [length] bytes starting with [head] (at least the
  /// first four bytes) may be read at all: up to [maxImportBytes] for a
  /// container (a ZIP), up to [maxFileBytes] for anything else. Whoever can
  /// only see the size (a listing) uses [maxImportBytes] and leaves the rest
  /// to [decode].
  static bool fitsImportLimit(int length, List<int> head) {
    if (length <= maxFileBytes) return true;
    if (length > maxImportBytes) return false;
    return head.length >= 4 &&
        head[0] == 0x50 &&
        head[1] == 0x4b &&
        head[2] == 0x03 &&
        head[3] == 0x04;
  }

  static const int defaultMaxDecodedBytes = 32 * 1024 * 1024;

  /// A file that inflates to more than this many times its own size is
  /// rejected as soon as it crosses it, without inflating the rest. Real
  /// backups inflate about 5:1; a bomb of repeated tiny objects, hundreds
  /// of times that.
  static const int maxInflateRatio = 100;

  /// The ratio only applies above this many decoded bytes, so a tiny valid
  /// file is never refused for being small.
  static const int inflateRatioFloorBytes = 64 * 1024;

  static const String _checksumPrefix = 'sha256:';

  /// `sha256:<hex>` of the canonical JSON of [data].
  static String checksumOf(BackupData data) => checksumOfJson(data.toJson());

  /// Same as [checksumOf] for a decoded `data` object.
  static String checksumOfJson(Object? dataJson) =>
      '$_checksumPrefix${sha256Hex(canonicalJsonBytes(dataJson))}';

  /// Date-only file name for callers outside the UI: `turnly-2026-11-10.turnly`.
  static String suggestedFileName(DateTime at) {
    final t = at.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'turnly-${t.year.toString().padLeft(4, '0')}-${two(t.month)}-'
        '${two(t.day)}.turnly';
  }

  /// Compressed bytes [peekAppVersion] looks at (it never inflates more than
  /// a small multiple of this, whatever the file).
  static const int peekCompressedBytes = 512;

  static final RegExp _appVersionAtStart = RegExp(
    r'^\{"appVersion":"([0-9A-Za-z][0-9A-Za-z.+_-]{0,31})"',
  );

  /// The `appVersion` of the app that wrote [bytes], read from the very
  /// start of the file without decoding or validating it (the list of copies
  /// shows it next to each one, H-T16-2). The envelope is canonical (sorted
  /// keys), so `appVersion` comes first; only the first
  /// [peekCompressedBytes] are inflated. `null` when it cannot be read: not
  /// gzip, not our layout, a version with odd characters. **Informational
  /// only**: nothing is decided from it, and a file is only trusted after
  /// [decode].
  static String? peekAppVersion(Uint8List bytes) {
    if (BackupContainer.looksLikeContainer(bytes)) {
      // The list of copies hands over only the first [peekCompressedBytes] of
      // a file, and a container (a copy with attachments) is cut there:
      // the head of the inner backup is found through the first local
      // headers of the ZIP, not by opening the whole container.
      final inner = BackupContainer.peekBackupHead(bytes);
      if (inner == null || inner.length < 2) return null;
      return inner[0] == 0x1f && inner[1] == 0x8b
          ? peekAppVersion(inner)
          : null;
    }
    if (bytes.length < 2 || bytes[0] != 0x1f || bytes[1] != 0x8b) return null;
    final inflated = BytesBuilder(copy: false);
    try {
      // The chunked decoder hands over what it has inflated as it goes; the
      // stream is cut on purpose, so it is never closed (closing a cut stream
      // throws).
      final decoder = gzip.decoder.startChunkedConversion(_HeadSink(inflated));
      decoder.add(
        Uint8List.sublistView(
          bytes,
          0,
          bytes.length < peekCompressedBytes
              ? bytes.length
              : peekCompressedBytes,
        ),
      );
    } catch (_) {
      // Whatever came out before the problem is still the start of the file.
    }
    final head = inflated.takeBytes();
    if (head.isEmpty) return null;
    final text = String.fromCharCodes(
      head.length > 128 ? head.sublist(0, 128) : head,
    );
    return _appVersionAtStart.firstMatch(text)?[1];
  }

  /// The uncompressed canonical bytes of the whole file. Same inputs, same
  /// bytes, on every platform.
  Uint8List encodeJsonBytes(
    BackupData data, {
    required String appVersion,
    required DateTime exportedAt,
  }) {
    data.validate();
    final dataJson = data.toJson();
    return canonicalJsonBytes({
      'format': formatName,
      'schemaVersion': supportedSchemaVersion,
      'appVersion': appVersion,
      'exportedAt': _formatTime(exportedAt),
      'data': dataJson,
      'checksum': checksumOfJson(dataJson),
    });
  }

  /// The file. Without attachments: [encodeJsonBytes] gzip-compressed, the
  /// format every version reads. With attachments (`data.noteAttachments`,
  /// database v6) a [BackupContainer] holding that same file and the bytes
  /// of each attachment, which [attachmentFiles] must give (id -> bytes,
  /// matching the size and SHA-256 of its row): a missing or different file
  /// is a [CorruptBackup], never a copy that silently lacks it.
  Uint8List encode(
    BackupData data, {
    required String appVersion,
    required DateTime exportedAt,
    Map<String, Uint8List> attachmentFiles = const {},
  }) {
    final plain = _encodePlain(
      data,
      appVersion: appVersion,
      exportedAt: exportedAt,
    );
    if (data.noteAttachments.isEmpty) {
      if (attachmentFiles.isNotEmpty) {
        throw ArgumentError.value(
          attachmentFiles.keys,
          'attachmentFiles',
          'files without attachment rows',
        );
      }
      return plain;
    }
    final files = <String, Uint8List>{};
    for (final a in data.noteAttachments) {
      final bytes = attachmentFiles[a.id];
      if (bytes == null) {
        throw CorruptBackup('Attachment "${a.id}" has no file');
      }
      _checkFile(a, bytes);
      files[a.id] = bytes;
    }
    return BackupContainer.encode(backup: plain, files: files);
  }

  Uint8List _encodePlain(
    BackupData data, {
    required String appVersion,
    required DateTime exportedAt,
  }) {
    final raw = encodeJsonBytes(
      data,
      appVersion: appVersion,
      exportedAt: exportedAt,
    );
    if (raw.length > maxDecodedBytes) {
      throw const CorruptBackup('Decompressed content is too large');
    }
    var bytes = _gzip(raw);
    // Long repeated notes are legitimate. Store without compression rather
    // than produce a file our bomb protection would refuse to read.
    if (raw.length > inflateRatioFloorBytes &&
        raw.length > bytes.length * maxInflateRatio) {
      bytes = _gzip(raw, level: 0);
    }
    if (bytes.length > maxFileBytes) {
      throw const CorruptBackup('File is too large');
    }
    return bytes;
  }

  /// Reads [bytes] or throws a [BackupException]:
  /// - [NotACuadranteFile]: not gzip, or not our JSON.
  /// - [NewerFormatVersion]: written by a newer app (R6). Checked before the
  ///   rest of the content is looked at, since a newer file may differ.
  /// - [CorruptBackup]: truncated or damaged (R7), failed checksum or
  ///   inconsistent data.
  ///
  /// A [BackupContainer] (attachments, database v6) is opened first: its
  /// inner file is read as below and every attachment it lists must come
  /// with its file, of the right size and SHA-256. A plain file that lists
  /// attachments is a [CorruptBackup] (their files would be missing).
  BackupFile decode(Uint8List bytes) {
    if (BackupContainer.looksLikeContainer(bytes)) {
      return _decodeContainer(bytes);
    }
    final file = _decodePlain(bytes);
    if (file.data.noteAttachments.isNotEmpty) {
      throw const CorruptBackup('Attachments without their files');
    }
    return file;
  }

  BackupFile _decodeContainer(Uint8List bytes) {
    final ({Uint8List backup, Map<String, Uint8List> files}) opened;
    try {
      opened = BackupContainer.decode(bytes);
    } on BackupException {
      rethrow;
    } catch (e) {
      throw CorruptBackup('Invalid container: $e');
    }
    if (!(opened.backup.length >= 2 &&
        opened.backup[0] == 0x1f &&
        opened.backup[1] == 0x8b)) {
      throw const CorruptBackup('The container holds no backup');
    }
    final inner = _decodePlain(opened.backup);
    final declared = inner.data.noteAttachments.fold<int>(
      0,
      (sum, a) => sum + a.sizeBytes,
    );
    if (declared > bytes.length) {
      throw const CorruptBackup('Attachments larger than the file');
    }
    final files = <String, Uint8List>{};
    for (final a in inner.data.noteAttachments) {
      final file = opened.files[a.id];
      if (file == null) {
        throw CorruptBackup('Attachment "${a.id}" has no file');
      }
      _checkFile(a, file);
      files[a.id] = file;
    }
    return BackupFile(
      schemaVersion: inner.schemaVersion,
      appVersion: inner.appVersion,
      exportedAt: inner.exportedAt,
      checksum: inner.checksum,
      data: inner.data,
      attachmentFiles: Map.unmodifiable(files),
    );
  }

  static void _checkFile(BackupNoteAttachment a, Uint8List bytes) {
    if (bytes.length != a.sizeBytes) {
      throw CorruptBackup('Attachment "${a.id}" has the wrong size');
    }
    if (sha256Hex(bytes) != a.sha256) {
      throw CorruptBackup('Attachment "${a.id}" does not match its SHA-256');
    }
  }

  BackupFile _decodePlain(Uint8List bytes) {
    if (bytes.length < 2 || bytes[0] != 0x1f || bytes[1] != 0x8b) {
      throw const NotACuadranteFile('Not a gzip file');
    }
    if (bytes.length > maxFileBytes) {
      throw const CorruptBackup('File is too large');
    }
    final raw = _gunzip(bytes);

    final Object? envelope;
    try {
      envelope = jsonDecode(utf8.decode(raw));
    } on FormatException {
      throw const NotACuadranteFile('Not a JSON document');
    }
    if (envelope is! Map<String, Object?> || envelope['format'] != formatName) {
      throw const NotACuadranteFile('Not a Cuadrante document');
    }

    final version = envelope['schemaVersion'];
    if (version is! int || version < 1) {
      throw const CorruptBackup('Invalid schemaVersion');
    }
    if (version > supportedSchemaVersion) {
      throw NewerFormatVersion(
        found: version,
        supported: supportedSchemaVersion,
      );
    }

    try {
      return switch (version) {
        1 => _decodeV1(envelope),
        2 => _decodeV2(envelope),
        3 => _decodeV3(envelope),
        _ => throw CorruptBackup('No reader for schemaVersion $version'),
      };
    } on BackupException {
      rethrow;
    } catch (e) {
      // FormatException from the typed readers, TypeError, StackOverflowError
      // on absurdly nested content...
      throw CorruptBackup('Invalid content: $e');
    }
  }

  /// The reader of `schemaVersion` 1 (releases 0.1 and 0.2, before calendars).
  /// The checksum is checked against the file as written; the data is then
  /// read into the version 2 model: everything goes to the calendar `main`
  /// (created with the export time as its timestamps) and no shift type has a
  /// rate. Another version adds its own reader beside this one; this one must
  /// never change what it accepts, and files it reads must restore as they
  /// always did (`golden_v1.cuadrante`).
  BackupFile _decodeV1(Map<String, Object?> envelope) {
    final env = _readEnvelope(envelope);
    final exportedAt = _parseTime(env.exportedAt);
    final data = BackupData.fromJsonV1(
      env.dataJson,
      migratedAt: exportedAt.millisecondsSinceEpoch,
    )..validate();
    return BackupFile(
      schemaVersion: 1,
      appVersion: env.appVersion,
      exportedAt: exportedAt,
      checksum: env.checksum,
      data: data,
    );
  }

  /// The reader of `schemaVersion` 2 (releases 0.3 to 0.5): calendars,
  /// `calendarId` on runs and days, `hourlyRateCents` on shift types. It
  /// never changes: the version 3 fields (icon, alarm sound, second segment,
  /// reminder, overtime, early leave) are `null` in what it returns, even if
  /// a file of this version somehow carried them.
  BackupFile _decodeV2(Map<String, Object?> envelope) {
    final env = _readEnvelope(envelope);
    final data = BackupData.fromJsonV2(env.dataJson)..validate();
    return BackupFile(
      schemaVersion: 2,
      appVersion: env.appVersion,
      exportedAt: _parseTime(env.exportedAt),
      checksum: env.checksum,
      data: data,
    );
  }

  /// The reader of `schemaVersion` 3 (release 0.6): version 2 plus the icon,
  /// alarm sound and second segment of shift types and the note reminder,
  /// overtime and early leave of days. The optional fixedPlusCents extension
  /// keeps this format version: older v3 readers ignore unknown keys.
  BackupFile _decodeV3(Map<String, Object?> envelope) {
    final env = _readEnvelope(envelope);
    final data = BackupData.fromJson(env.dataJson)..validate();
    return BackupFile(
      schemaVersion: 3,
      appVersion: env.appVersion,
      exportedAt: _parseTime(env.exportedAt),
      checksum: env.checksum,
      data: data,
    );
  }

  /// The envelope fields every version has, with the checksum verified.
  ({
    Map<String, Object?> dataJson,
    String checksum,
    String appVersion,
    String exportedAt,
  })
  _readEnvelope(Map<String, Object?> envelope) {
    final dataJson = envelope['data'];
    final checksum = envelope['checksum'];
    final appVersion = envelope['appVersion'];
    final exportedAt = envelope['exportedAt'];
    if (dataJson is! Map<String, Object?>) {
      throw const CorruptBackup('Missing data');
    }
    if (checksum is! String || appVersion is! String || exportedAt is! String) {
      throw const CorruptBackup('Missing envelope fields');
    }
    if (checksumOfJson(dataJson) != checksum) {
      throw const CorruptBackup('Checksum mismatch');
    }
    return (
      dataJson: dataJson,
      checksum: checksum,
      appVersion: appVersion,
      exportedAt: exportedAt,
    );
  }

  // Time: UTC ISO-8601 with second precision, `2026-11-10T09:30:00Z`.

  static String _formatTime(DateTime t) {
    final u = t.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${u.year.toString().padLeft(4, '0')}-${two(u.month)}-${two(u.day)}'
        'T${two(u.hour)}:${two(u.minute)}:${two(u.second)}Z';
  }

  static DateTime _parseTime(String text) {
    final t = DateTime.parse(text);
    if (!t.isUtc) throw FormatException('exportedAt must be UTC', text);
    return t;
  }

  // Gzip. The container is written by hand around dart:io's deflate so that
  // (1) the header is the same on every platform (the OS byte differs
  // otherwise) and (2) a truncated stream is always detected: the chunked
  // decoder of dart:io hands back the partial output without complaining, so
  // the trailer (CRC-32 and length) is checked here.

  static Uint8List _gzip(Uint8List raw, {int level = 9}) {
    final out = Uint8List.fromList(GZipCodec(level: level).encode(raw));
    out[9] = 0xff; // OS = unknown
    return out;
  }

  Uint8List _gunzip(Uint8List input) {
    if (input.length < 18) {
      throw const CorruptBackup('Truncated gzip stream');
    }
    // Whichever bites first: the absolute cap, or the inflate ratio.
    final ratioLimit = input.length * maxInflateRatio;
    final sink = _LimitedSink(
      maxDecodedBytes,
      ratioLimit: ratioLimit < inflateRatioFloorBytes
          ? inflateRatioFloorBytes
          : ratioLimit,
    );
    try {
      final conversion = gzip.decoder.startChunkedConversion(sink);
      conversion.add(input);
      conversion.close();
    } on BackupException {
      rethrow;
    } catch (e) {
      throw CorruptBackup('Bad gzip stream: $e');
    }
    final out = sink.takeBytes();
    final trailer = ByteData.sublistView(input, input.length - 8);
    final crc = trailer.getUint32(0, Endian.little);
    final size = trailer.getUint32(4, Endian.little);
    if (size != out.length & 0xffffffff || crc != getCrc32(out)) {
      throw const CorruptBackup('Truncated or damaged gzip stream');
    }
    return out;
  }
}

/// Collects what the decoder produces and refuses to grow past [limit].
class _LimitedSink implements Sink<List<int>> {
  _LimitedSink(this.limit, {required this.ratioLimit});

  final int limit;

  /// Most bytes the compressed size allows (see `maxInflateRatio`).
  final int ratioLimit;
  final BytesBuilder _bytes = BytesBuilder(copy: false);
  int _length = 0;

  @override
  void add(List<int> data) {
    _length += data.length;
    if (_length > limit) {
      throw const CorruptBackup('Decompressed content is too large');
    }
    if (_length > ratioLimit) {
      throw const CorruptBackup('Decompression ratio is implausible');
    }
    _bytes.add(Uint8List.fromList(data));
  }

  Uint8List takeBytes() => _bytes.takeBytes();

  @override
  void close() {}
}

/// Collects what the decoder inflates for [BackupCodec.peekAppVersion].
class _HeadSink implements Sink<List<int>> {
  _HeadSink(this._into);

  final BytesBuilder _into;

  @override
  void add(List<int> data) => _into.add(data);

  @override
  void close() {}
}
