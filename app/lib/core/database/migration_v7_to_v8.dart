import 'dart:convert';

import 'package:drift/drift.dart';

import '../../features/swaps/domain/swap_application.dart';
import 'app_database.steps.dart';

Future<void> migrateFrom7To8(
  Migrator m,
  Schema8 schema,
) => m.database.transaction(() async {
  final db = m.database;
  await m.createTable(schema.swapApplications);
  await m.createIndex(schema.idxSwapApplicationsDay);
  final setting = await db
      .customSelect(
        'SELECT value FROM settings WHERE key = ?',
        variables: [const Variable(legacySwapApplicationsKey)],
      )
      .getSingleOrNull();
  if (setting == null) return;
  final swaps = await db
      .customSelect('SELECT id, calendar_id, updated_at FROM shift_swaps')
      .get();
  final calendarOf = {
    for (final swap in swaps)
      swap.read<String>('id'): swap.read<String>('calendar_id'),
  };
  final conversion = readLegacySwapApplications(setting.read<String>('value'), {
    for (final swap in swaps)
      swap.read<String>('id'): swap.read<int>('updated_at'),
  });
  // One applied swap per calendar and day: a later overlapping swap goes to
  // recovery whole instead of breaking the unique index.
  final perDay = keepOneSwapPerDay(conversion.records, calendarOf);
  for (final record in perDay.kept) {
    await db.customStatement(
      'INSERT INTO swap_applications '
      '(swap_id, calendar_id, date, previous_shift_type_ids, created_at) '
      'VALUES (?, ?, ?, ?, ?)',
      [
        record.swapId,
        calendarOf[record.swapId],
        record.date.toIso(),
        record.previousShiftTypeIds == null
            ? null
            : jsonEncode(record.previousShiftTypeIds),
        record.createdAt,
      ],
    );
  }
  Future<void> recover(String value) async {
    final settings = await db.customSelect('SELECT key FROM settings').get();
    await db.customStatement(
      'INSERT INTO settings (key, value) VALUES (?, ?)',
      [
        availableSwapApplicationRecoveryKey(
          settings.map((row) => row.read<String>('key')),
        ),
        value,
      ],
    );
  }

  if (conversion.rejectedJson case final rejected?) await recover(rejected);
  if (perDay.dropped.isNotEmpty) {
    await recover(encodeOverlappingSwapApplications(perDay.dropped));
  }
  await db.customStatement('DELETE FROM settings WHERE key = ?', [
    legacySwapApplicationsKey,
  ]);
});
