import 'dart:typed_data';

import 'package:cuadrante/features/backup/domain/backup_codec.dart';
import 'package:cuadrante/features/backup/domain/backup_data.dart';
import 'package:cuadrante/features/backup/domain/canonical_json.dart';

import 'backup_test_support.dart';

/// Format version 3, as the 0.6 – 1.0 releases wrote it, rebuilt from the
/// current model so the tests can keep proving that those files read and
/// restore the same. Production code only reads version 3; since database
/// v7 it writes version 4 (the extra hours as blocks).

/// The canonical (uncompressed) bytes of a version 3 file: [data] as it is,
/// with its old overtime minutes and without overtime types or blocks.
Uint8List v3JsonBytes(
  BackupData data, {
  required String appVersion,
  required String exportedAt,
}) => canonicalJsonBytes(_v3Envelope(data, appVersion, exportedAt));

/// A version 3 `.cuadrante` file for [data].
Uint8List v3File(
  BackupData data, {
  String appVersion = '1.0.0',
  String exportedAt = '2026-11-01T10:30:00Z',
}) => gzipEnvelope(_v3Envelope(data, appVersion, exportedAt));

Map<String, Object?> _v3Envelope(
  BackupData data,
  String appVersion,
  String exportedAt,
) {
  final json = data.toJson()
    ..remove('overtimeTypes')
    ..remove('overtimeBlocks');
  return {
    'format': BackupCodec.formatName,
    'schemaVersion': 3,
    'appVersion': appVersion,
    'exportedAt': exportedAt,
    'data': json,
    'checksum': BackupCodec.checksumOfJson(json),
  };
}
