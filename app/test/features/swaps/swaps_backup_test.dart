import 'dart:convert';
import 'dart:typed_data';

import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/features/backup/domain/backup_codec.dart';
import 'package:cuadrante/features/backup/domain/backup_data.dart';
import 'package:cuadrante/features/backup/domain/backup_errors.dart';
import 'package:cuadrante/features/backup/domain/backup_warnings.dart';
import 'package:cuadrante/features/backup/domain/restore_summary.dart';
import 'package:cuadrante/features/schedule/data/schedule_repository.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/swaps/data/shift_swaps_repository.dart';
import 'package:cuadrante/features/swaps/data/swap_applied_store.dart';
import 'package:cuadrante/features/swaps/domain/shift_swap.dart';
import 'package:cuadrante/features/swaps/domain/swap_application.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import '../backup/backup_test_support.dart';

const _third = CivilDate(2026, 11, 3);
const _tenth = CivilDate(2026, 11, 10);
const _codec = BackupCodec();

BackupShiftSwap _legacySwap(String id) => BackupShiftSwap(
  id: id,
  calendarId: 'main',
  colleague: 'Marta',
  date: _third,
  direction: SwapDirection.theyOwe,
  createdAt: 1,
  updatedAt: 2,
);

Uint8List _envelope(int version, Map<String, Object?> data) => gzipEnvelope({
  'format': BackupCodec.formatName,
  'schemaVersion': version,
  'appVersion': testAppVersion,
  'exportedAt': '2026-11-10T00:00:00.000Z',
  'data': data,
  'checksum': BackupCodec.checksumOfJson(data),
});

ShiftSwap _swap(
  String id, {
  String colleague = 'Marta',
  SwapDirection direction = SwapDirection.theyOwe,
  SwapStatus status = SwapStatus.pending,
  int? closedAt,
}) => ShiftSwap(
  id: id,
  calendarId: 'main',
  date: _third,
  colleague: colleague,
  direction: direction,
  givenShiftTypeIds: const ['night'],
  receivedShiftTypeIds: const ['morning'],
  returnDate: _tenth,
  status: status,
  note: 'Me devuelve la noche del 10',
  createdAt: 7,
  updatedAt: 9,
  closedAt: closedAt,
);

void main() {
  test(
    'the ledger and applications travel through the codec and restore matrix',
    () async {
      final dir = makeTempDir('swaps-backup');
      final source = openMemoryDatabase();
      addTearDown(source.close);

      final repository = ShiftSwapsRepository(source);
      final pending = _swap('swap-1');
      final settled = _swap(
        'swap-2',
        colleague: 'Luis',
        direction: SwapDirection.iOwe,
        status: SwapStatus.returned,
        closedAt: 9,
      );
      await repository.save(pending);
      await repository.save(settled);
      final schedule = ScheduleRepository(source);
      for (final id in ['morning', 'night']) {
        await schedule.saveShiftType(shiftTemplateByKey(id).toShiftType(id));
      }
      final sourceBackup = makeRepository(source, dir);
      final withLedgerOnly = await sourceBackup.readAll();
      final v4 = _codec.decode(
        _codec.encode(
          withLedgerOnly,
          appVersion: testAppVersion,
          exportedAt: DateTime.utc(2026, 11, 10),
        ),
      );
      expect(v4.schemaVersion, 4);
      expect(v4.data, withLedgerOnly);
      expect(v4.data.toJson(), isNot(contains('swapApplications')));

      // Null, an explicit empty day, and a handwritten override all travel.
      await source.batch((batch) {
        batch.insertAll(source.dayEntries, [
          for (final date in [_third, _tenth, _tenth.addDays(1)])
            DayEntriesCompanion.insert(
              calendarId: pending.calendarId,
              date: date,
              shiftTypeIds: const Value(['morning']),
              updatedAt: 11,
            ),
        ]);
        batch.insertAll(source.swapApplications, [
          for (final (date, ids, applied) in [
            (_third, ['morning', 'night'], '[]'),
            (_tenth, null, 'null'),
            (_tenth.addDays(1), <String>[], '["morning"]'),
          ])
            SwapApplicationsCompanion.insert(
              swapId: pending.id,
              calendarId: pending.calendarId,
              date: date,
              createdAt: 11,
              previousShiftTypeIds: Value(ids),
              appliedOverride: Value(applied),
            ),
        ]);
      });

      final data = await sourceBackup.readAll();
      expect(data.shiftSwaps, hasLength(2));
      final bytes = const BackupCodec().encode(
        data,
        appVersion: testAppVersion,
        exportedAt: DateTime.utc(2026, 11, 10),
      );
      final file = const BackupCodec().decode(bytes);
      expect(file.schemaVersion, 5);
      expect(file.data, data);
      expect(
        await sourceBackup.verifyRestore(bytes, today: _tenth),
        isA<VerificationPassed>(),
      );

      final target = openMemoryDatabase();
      addTearDown(target.close);
      final targetBackup = makeRepository(target, dir);
      await targetBackup.restore(file.data);
      expect(await targetBackup.readAll(), data);

      final restored = await ShiftSwapsRepository(target).list();
      expect(restored, hasLength(2));
      expect(restored, contains(pending));
      expect(restored, contains(settled));
      // The record comes back with the change: it can still be taken off.
      final records = await SwapAppliedStore(target).before('swap-1');
      expect(
        {
          for (final record in records)
            record.date: record.previousShiftTypeIds,
        },
        {
          _third: ['morning', 'night'],
          _tenth: null,
          _tenth.addDays(1): [],
        },
      );
      expect(records.map((r) => r.createdAt), everyElement(11));
      expect(records.map((r) => r.appliedOverride?.shiftTypeIds), [
        [],
        null,
        ['morning'],
      ]);
      expect(records.map((r) => r.appliedOverride), everyElement(isNotNull));
      expect(await SwapAppliedStore(target).before('swap-2'), isEmpty);
    },
  );

  test(
    'a version 4 copy migrates the settings record when restored or verified',
    () async {
      final dir = makeTempDir('swaps-backup-legacy');
      final target = openMemoryDatabase();
      addTearDown(target.close);
      final repository = makeRepository(target, dir);
      final json = BackupData(
        shiftSwaps: [_legacySwap('legacy')],
        settings: {
          'swaps.applied': '{"legacy":{"2026-11-03":[],"2026-11-10":null}}',
        },
      ).toJson();
      final bytes = _envelope(4, json);
      expect(
        await repository.verifyRestore(bytes, today: _tenth),
        isA<VerificationPassed>(),
      );
      await repository.restore(const BackupCodec().decode(bytes).data);
      final records = await SwapAppliedStore(target).before('legacy');
      expect(records.map((r) => r.previousShiftTypeIds), [[], null]);
      expect(records.map((r) => r.appliedOverride), everyElement(isNull));
      expect(
        (await repository.readAll()).settings,
        isNot(contains('swaps.applied')),
      );
    },
  );

  test(
    'v5 accepts absent and empty application lists and rejects bad values',
    () {
      final base = BackupData().toJson();
      for (final json in [
        base,
        {...base, 'swapApplications': []},
      ]) {
        final file = _codec.decode(_envelope(5, json));
        expect(file.data.swapApplications, isEmpty);
      }
      for (final bad in [
        null,
        {},
        [{}],
      ]) {
        final json = {...base, 'swapApplications': bad};
        expect(
          () => _codec.decode(_envelope(5, json)),
          throwsA(isA<CorruptBackup>()),
        );
      }
    },
  );

  for (final unreadable in [false, true]) {
    test(
      'restore keeps and reports rejected legacy data (unreadable: $unreadable)',
      () async {
        final dir = makeTempDir('swaps-backup-recovery');
        final target = openMemoryDatabase();
        addTearDown(target.close);
        final repository = makeRepository(target, dir);
        final rejected = {
          'damaged': {
            '2026-11-03': <String>[],
            '2026-11-10': [3],
          },
        };
        final raw = unreadable
            ? '{"damaged":'
            : jsonEncode({
                'valid': {'2026-11-03': <String>[]},
                ...rejected,
              });
        final json = BackupData(
          shiftSwaps: [_legacySwap('valid'), _legacySwap('damaged')],
          settings: {legacySwapApplicationsKey: raw},
        ).toJson();
        final bytes = _envelope(4, json);

        expect(
          await repository.verifyRestore(bytes, today: _tenth),
          isA<VerificationIncomplete>(),
        );
        expect(await repository.restore(_codec.decode(bytes).data), [
          isA<SwapApplicationsSkipped>(),
        ]);
        final restored = await repository.readAll();
        expect(
          restored.swapApplications.map((entry) => entry.record.swapId),
          unreadable ? isEmpty : ['valid'],
        );
        expect(restored.settings, {
          swapApplicationRecoveryKey: unreadable ? raw : jsonEncode(rejected),
        });

        final reexport = _codec.encode(
          restored,
          appVersion: testAppVersion,
          exportedAt: DateTime.utc(2026, 11, 10),
        );
        expect(_codec.decode(reexport).data.settings, restored.settings);
        expect(
          await repository.verifyRestore(reexport, today: _tenth),
          isA<VerificationIncomplete>(),
        );
      },
    );
  }
}
