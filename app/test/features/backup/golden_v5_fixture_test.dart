import 'dart:convert';
import 'dart:io';

import 'package:cuadrante/features/backup/domain/backup_codec.dart';
import 'package:cuadrante/features/backup/domain/backup_data.dart';
import 'package:cuadrante/features/backup/domain/schedule_fingerprint.dart';
import 'package:flutter_test/flutter_test.dart';

import 'backup_test_support.dart';
import 'golden_dataset.dart';
import 'golden_dataset_v4.dart';

const _regenerate = bool.fromEnvironment('REGENERATE_GOLDEN');
const _dir = 'test/fixtures/golden_backup';
final _fixture = File('$_dir/golden_v5.cuadrante');
final _expected = File('$_dir/golden_v5.expected.json');
const _appVersion = '0.12.1';

BackupData _dataset() {
  final json = buildGoldenBackupDataV4().toJson();
  json['shiftSwaps'] = [
    {
      'id': 'golden-swap',
      'calendarId': 'main',
      'date': '2026-02-12',
      'colleague': 'Marta',
      'direction': 'theyOwe',
      'givenShiftTypeIds': ['morning'],
      'returnDate': '2026-02-13',
      'receivedShiftTypeIds': ['night'],
      'status': 'pending',
      'createdAt': 1770912000000,
      'updatedAt': 1770998400000,
    },
  ];
  json['swapApplications'] = [
    for (final (date, ids) in [
      ('2026-02-12', ['morning', 'night']),
      ('2026-02-13', null),
      ('2026-02-14', <String>[]),
    ])
      {
        'swapId': 'golden-swap',
        'date': date,
        'previousShiftTypeIds': ids,
        'createdAt': 1770998400000,
      },
  ];
  return BackupData.fromJson(
    json,
    readOvertime: true,
    readSwapApplications: true,
  );
}

String _fingerprint(BackupData data) =>
    scheduleFingerprint(data, from: goldenFrom, to: goldenTo).digest;

void main() {
  const codec = BackupCodec();

  if (_regenerate) {
    test('generate the version 5 reference once', () {
      final data = _dataset();
      final bytes = codec.encode(
        data,
        appVersion: _appVersion,
        exportedAt: goldenV4ExportedAt,
      );
      _fixture.writeAsBytesSync(bytes);
      final expected = const JsonEncoder.withIndent('  ').convert({
        'checksum': BackupCodec.checksumOf(data),
        'fingerprint': _fingerprint(data),
      });
      _expected.writeAsStringSync('$expected\n');
    });
    return;
  }

  test(
    'the v5 reference keeps its canonical bytes and restores exactly',
    () async {
      final bytes = _fixture.readAsBytesSync();
      final file = codec.decode(bytes);
      final expected =
          jsonDecode(_expected.readAsStringSync()) as Map<String, Object?>;
      expect(file.schemaVersion, 5);
      expect(file.checksum, expected['checksum']);
      expect(file.data, _dataset());
      expect(
        gzip.decode(bytes),
        codec.encodeJsonBytes(
          file.data,
          appVersion: _appVersion,
          exportedAt: goldenV4ExportedAt,
        ),
      );

      final dir = makeTempDir('golden-v5');
      final db = openMemoryDatabase();
      addTearDown(db.close);
      final repository = makeRepository(db, dir);
      await repository.restore(file.data);
      final restored = await repository.readAll();
      expect(restored, file.data);
      expect(_fingerprint(restored), expected['fingerprint']);
    },
  );
}
