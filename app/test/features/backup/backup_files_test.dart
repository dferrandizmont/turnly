import 'package:cuadrante/features/backup/data/backup_files.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('automatic names accept both extensions and the legacy prefix', () {
    final pattern = backupNamePattern('turnly');
    for (final prefix in ['turnly', 'cuadrante']) {
      for (final extension in ['turnly', 'cuadrante']) {
        final match = pattern.firstMatch(
          '$prefix-20261030-123456-10.$extension',
        );
        expect(match, isNotNull);
        expect(match![1], '20261030-123456');
        expect(match[2], '10');
        expect(pattern.hasMatch('$prefix-20261030-123456.$extension'), isTrue);
      }
    }
    for (final name in [
      'pre-restore-20261030-123456.turnly',
      'notes-20261030-123456.turnly',
      'turnly-20261030-123456.turnly.tmp',
      '../turnly-20261030-123456.turnly',
      'turnly-20261030-123456.turnly/other',
    ]) {
      expect(pattern.hasMatch(name), isFalse, reason: name);
    }
  });

  test(
    'safety names accept both extensions, separate from automatic copies',
    () {
      final pattern = backupNamePattern('pre-restore');
      for (final extension in ['turnly', 'cuadrante']) {
        expect(
          pattern.hasMatch('pre-restore-20261030-123456.$extension'),
          isTrue,
        );
        expect(
          pattern.hasMatch('pre-restore-20261030-123456-2.$extension'),
          isTrue,
        );
        expect(
          pattern.hasMatch('cuadrante-20261030-123456.$extension'),
          isFalse,
        );
        expect(pattern.hasMatch('turnly-20261030-123456.$extension'), isFalse);
      }
    },
  );

  test('new names follow the highest legacy or current counter', () {
    expect(
      nextBackupName('turnly', DateTime.utc(2026, 10, 30, 12, 34, 56), [
        'cuadrante-20261030-123456.cuadrante',
        'cuadrante-20261030-123456-9.cuadrante',
        'turnly-20261030-123456-10.turnly',
        'pre-restore-20261030-123456-99.turnly',
        'cuadrante-20261029-123456-99.cuadrante',
      ]),
      'turnly-20261030-123456-11.turnly',
    );
  });
}
