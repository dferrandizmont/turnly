import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../calendars/data/calendars_repository.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../schedule/data/schedule_repository.dart';
import '../../schedule/data/schedule_seeding.dart';
import '../../schedule/domain/civil_date.dart';
import '../domain/preferences.dart';

/// Deletes user rows in foreign-key order, then installs the factory catalog.
/// No schema change and no filesystem deletion (especially no backups).
class ResetRepository {
  ResetRepository(this.db, {required this.now});

  final AppDatabase db;
  final DateTime Function() now;

  Future<void> clear() => db.transaction(() async {
    await db.delete(db.noteAttachments).go();
    await db.delete(db.dayTasks).go();
    await db.delete(db.shiftSwaps).go();
    await db.delete(db.dayEntries).go();
    await db.delete(db.patternRuns).go();
    await db.delete(db.absenceBalances).go();
    await db.delete(db.shiftTypeVersions).go();
    await db.delete(db.patterns).go();
    await db.delete(db.shiftTypes).go();
    await db.delete(db.calendars).go();
    await db.delete(db.holidays).go();
    await (db.delete(
      db.settings,
    )..where((s) => s.key.equals(PreferenceKeys.language).not())).go();
    await CalendarsRepository(db, now: now).ensureMain();
    await seedIfEmpty(
      ScheduleRepository(db, now: now),
      demo: false,
      today: CivilDate.fromDateTime(now()),
    );
    await OnboardingRepository(db).rememberFactoryCatalog();
    await db
        .into(db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(
            key: OnboardingSettings.resetPending,
            value: jsonEncode(true),
          ),
        );
  });
}
