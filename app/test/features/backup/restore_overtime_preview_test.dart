import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/features/backup/data/platform_backup_channel.dart';
import 'package:cuadrante/features/backup/domain/backup_codec.dart';
import 'package:cuadrante/features/backup/domain/backup_data.dart';
import 'package:cuadrante/features/backup/domain/restore_summary.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'backup_ui_support.dart';
import 'golden_dataset_v4.dart';

// 1.1.0 QA, F9: the restore preview said nothing about the blocks of extra
// hours although the restore brings them back.

BackupOvertimeBlock _block(String id) => BackupOvertimeBlock(
  calendarId: 'main',
  date: const CivilDate(2026, 4, 2),
  id: id,
  typeId: overtimeTypeId,
  startMinute: 600,
  endMinute: 660,
);

void main() {
  setUpAll(initializeLocale);

  group('the counts', () {
    test('count the blocks of extra hours', () {
      final data = BackupData(overtimeBlocks: [_block('a'), _block('b')]);
      expect(BackupCounts.of(data).overtimeBlocks, 2);
      expect(BackupCounts.of(BackupData()).overtimeBlocks, 0);
    });

    test('two backups that differ only in their blocks differ', () {
      final one = BackupCounts.of(BackupData(overtimeBlocks: [_block('a')]));
      final two = BackupCounts.of(
        BackupData(overtimeBlocks: [_block('a'), _block('b')]),
      );
      expect(one, isNot(two));
      expect(one.hashCode, isNot(two.hashCode));
    });

    test(
      'the summary says how many the file brings and how many there are',
      () {
        final summary = summarizeRestore(
          BackupData(overtimeBlocks: [_block('a'), _block('b'), _block('c')]),
          BackupCounts.of(BackupData(overtimeBlocks: [_block('x')])),
        );
        expect(summary.incoming.overtimeBlocks, 3);
        expect(summary.current.overtimeBlocks, 1);
      },
    );

    test('a version 4 file counts its blocks', () {
      final data = buildGoldenBackupDataV4();
      expect(data.overtimeBlocks, isNotEmpty);
      expect(BackupCounts.of(data).overtimeBlocks, data.overtimeBlocks.length);
    });
  });

  group('the preview screen', () {
    Finder key(String k) => find.byKey(ValueKey(k));

    testWidgets('lists the blocks of extra hours like the other items', (
      tester,
    ) async {
      final h = BackupUiHarness(tester);
      await h.open();
      final file = BackupUiHarness.fileOf(buildGoldenBackupDataV4());
      h.picked = IncomingFile.bytes(file);
      await tapIo(tester, key('backup-import'), until: key('restore-preview'));
      final data = const BackupCodec().decode(file).data;
      expect(
        textOf(tester, key('restore-overtime')),
        '${data.overtimeBlocks.length}',
      );
      expect(find.text('Bloques de horas extra'), findsOneWidget);
    });
  });
}
