import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../../../core/database/app_database.dart';
import '../../calendar_export/data/calendar_sync_repository.dart'
    show calendarSyncKey;
import '../../device_events/data/device_events_repository.dart'
    show deviceEventsKey;
import '../../notes/data/attachment_store.dart';
import '../../notes/domain/note_attachment.dart' show AttachmentFault;
import '../../schedule/data/overtime_store.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../../settings/domain/preferences.dart' show PreferenceKeys;
import '../domain/backup_codec.dart';
import '../domain/backup_data.dart';
import '../domain/backup_errors.dart';
import '../domain/backup_task_runner.dart';
import '../domain/backup_warnings.dart';
import '../domain/canonical_json.dart';
import '../domain/restore_summary.dart';
import '../domain/schedule_fingerprint.dart';
import 'backup_files.dart';
import 'backup_settings_repository.dart' show cloudBackupKey;

/// Number of pre-restore safety exports kept.
const int safetyCopiesToKeep = 3;

const String _safetyPrefix = 'pre-restore';

/// `holidays.source` of the rows the user created; the only holidays a
/// backup carries (bundled and remote ones are derived again).
const String userHolidaySource = 'user';

/// Settings that describe the life of this device with the app, not the
/// person's schedule (`onboarding.done`, `onboarding.profile`,
/// `onboarding.tipPending`), the "Copia en iCloud" switch ([cloudBackupKey]),
/// the app's language ([PreferenceKeys.language]) and the clock
/// ([PreferenceKeys.timeFormat]): they never go into a backup file, a file that has them (an older version wrote everything, or
/// somebody crafted it) does not bring them back, and a restore leaves the
/// device's own untouched. The iCloud switch must be a consent given on this
/// device, never one that arrives in a file; the language is how this phone
/// is set up, and restoring a copy made on another one must not change it
/// (the clock is the same: it follows the phone, not the person's schedule).
/// The currency, the week start and the other preferences do travel: the
/// amounts of the copy only make sense in their currency.
const String deviceSettingPrefix = 'onboarding.';

bool isDeviceSetting(String key) =>
    key.startsWith(deviceSettingPrefix) ||
    key == cloudBackupKey ||
    key == calendarSyncKey ||
    // Which phone calendars are shown next to the shifts: their ids belong to
    // the phone that handed them out.
    key == deviceEventsKey ||
    key == PreferenceKeys.language ||
    key == PreferenceKeys.timeFormat ||
    // The picture behind the month is not in the backup (its file does not
    // travel), so neither is its path: a restored copy must not point at a
    // picture of another phone (or at nothing).
    key == PreferenceKeys.calendarBackground ||
    // The secret of a published link (docs/compartir.md): a backup file
    // that travels must never let someone else update or delete the feed.
    key.startsWith('shareLink.');

/// A `.turnly` just encoded from the data of the phone.
class BackupEncoding {
  const BackupEncoding(this.bytes, this.data, this.warnings);

  /// The file: a container when [data] has attachments.
  final Uint8List bytes;

  /// What the file holds: the data read, without the attachments that were
  /// left out because their file is lost.
  final BackupData data;

  /// What was left out ([AttachmentsSkipped]); empty for a whole copy.
  final List<BackupWarning> warnings;
}

/// Reads the whole user database for a backup, and replaces it from one
/// (docs/copia-de-seguridad.md).
class BackupRepository {
  BackupRepository(
    this._db, {
    required this.safetyDirectory,
    required this.appVersion,
    this._codec = const BackupCodec(),
    this.attachmentStore,
    this.loadAttachmentStore,
    DateTime Function()? now,
    AppDatabase Function()? openScratchDatabase,
    Future<Uint8List> Function(File)? readSafetyCopy,
    this.readAttachmentFile,
    this._runner = runInBackgroundIsolate,
    this.keepSafetyCopies = safetyCopiesToKeep,
  }) : _now = now ?? DateTime.now,
       _openScratchDatabase = openScratchDatabase ?? _openMemoryDatabase,
       _readSafetyCopy = readSafetyCopy ?? _readSafetyFile;

  final AppDatabase _db;
  final BackupCodec _codec;
  final DateTime Function() _now;
  final AppDatabase Function() _openScratchDatabase;
  final Future<Uint8List> Function(File) _readSafetyCopy;
  final BackupTaskRunner _runner;

  /// How an attachment's file is read when it is checked (`null`: a plain
  /// read). For tests that need a read to fail. It crosses to the background
  /// isolate with the job, so it must be a top-level function or `null`.
  final AttachmentBytesReader? readAttachmentFile;

  /// The files of the attachments of the notes (the `attachments` folder of
  /// `Application Support`), when the store is already built.
  final AttachmentStore? attachmentStore;

  /// Resolves the store of the files of the attachments when it is needed
  /// (the app asks the system for its folder then, and not before: a copy of
  /// a database without attachments never touches the folder).
  final Future<AttachmentStore> Function()? loadAttachmentStore;

  Future<AttachmentStore?> _store() async {
    final store = attachmentStore;
    if (store != null) return store;
    final loader = loadAttachmentStore;
    if (loader == null) return null;
    return loader();
  }

  static Future<Uint8List> _readSafetyFile(File file) => file.readAsBytes();

  /// Where `pre-restore-<stamp>.turnly` safety exports go (Application
  /// Support / backups).
  final Directory safetyDirectory;

  /// Written into the safety exports.
  final String appVersion;

  final int keepSafetyCopies;

  /// Everything the user owns, read in **one** transaction so the parts agree
  /// with each other.
  Future<BackupData> readAll() => _readAll(_db);

  /// What restoring [data] would do: counts of the file against the current
  /// database and the range of dates it covers. Writes nothing. Throws
  /// [CorruptBackup] if [data] is inconsistent.
  Future<RestoreSummary> preview(BackupData data) async {
    data.validate();
    final current = await readAll();
    return summarizeRestore(
      data,
      BackupCounts.of(current),
      currentSettings: current.settings,
    );
  }

  /// Replaces **every** user table with [data] in one transaction: all or
  /// nothing. Before touching anything it writes the current data to
  /// `pre-restore-<stamp>.turnly` in [safetyDirectory] and keeps the
  /// newest [keepSafetyCopies]; if that copy cannot be written the restore
  /// does not start. The safety copy skips the attachments whose file is
  /// already lost (a damaged photo must not stop the user from restoring); the
  /// returned warnings say which.
  ///
  /// Bundled and remote holidays are left alone (they are derived data of
  /// this device); the holidays feature recalculates them from the restored
  /// settings.
  ///
  /// A backup with attachments (database v6) brings its files in
  /// [attachmentFiles] (id -> bytes). They are checked against the size and
  /// the SHA-256 of their rows when the file is read; pass [verified] `true`
  /// when they come from `BackupCodec.decode` (which did it, in an isolate) so
  /// they are not hashed again here. Otherwise they are hashed through the
  /// runner, never on the UI isolate. The files are written in the store
  /// **before** the rows, so a disk that cannot hold them stops the restore
  /// before anything changes; if the writing of the files fails half way, or
  /// the transaction then fails, the files that were written go away again
  /// and nothing is left behind. The files that no row points at any more
  /// (the ones of the replaced data) are deleted when the restore ends.
  Future<List<BackupWarning>> restore(
    BackupData data, {
    Map<String, Uint8List> attachmentFiles = const {},
    bool verified = false,
  }) async {
    data.validate();
    final files = await _checkedAttachmentFiles(
      data,
      attachmentFiles,
      verified: verified,
    );
    // The old overtime minutes become blocks, as the database migration does.
    final safe = _withoutForeignSounds(data).upgradedOvertime()..validate();
    final safety = await _writeSafetyCopy();
    final written = await _writeAttachmentFiles(safe, files);
    try {
      await _replaceAll(_db, safe);
    } catch (_) {
      // The rows did not go in: the files that were written for them must not
      // stay alone.
      await _deleteFiles(written);
      rethrow;
    }
    // The files the safety copy had to leave out are not swept: the copy is
    // the way back, and it does not hold them.
    await _sweepAttachmentFiles(keep: safety.skippedPaths);
    return safety.warnings;
  }

  /// The files of the attachments of [data], by id: what a copy carries next
  /// to the data (the container names the files by id). Read and checked
  /// against the size and SHA-256 of their rows in the background isolate.
  ///
  /// Throws [BrokenAttachments] (a [CorruptBackup]) naming the attachments
  /// whose file is missing or is not what its row says: a strict copy never
  /// leaves without its files. The automatic copies use [encodeCurrent]
  /// instead, which skips them and warns.
  Future<Map<String, Uint8List>> attachmentBytes(BackupData data) async {
    if (data.noteAttachments.isEmpty) return const {};
    final store = await _store();
    if (store == null) {
      throw const CorruptBackup('Attachments without a store');
    }
    final rootPath = store.root.path;
    final refs = _refsOf(data);
    final read = readAttachmentFile;
    final check = await _runner(
      () => readVerifiedAttachmentFiles(rootPath, refs, read: read),
    );
    if (check.broken.isNotEmpty) throw BrokenAttachments(check.broken);
    return check.files;
  }

  static List<AttachmentFileRef> _refsOf(BackupData data) => [
    for (final a in data.noteAttachments)
      (
        id: a.id,
        relativePath: a.relativePath,
        sizeBytes: a.sizeBytes,
        sha256: a.sha256,
      ),
  ];

  /// The `.turnly` of [data] (what [readAll] gave) as of [at]: a container
  /// with the files of its attachments when it has any. The files are read,
  /// checked and the whole file encoded in the background isolate, in one
  /// job (the bytes cross isolates once).
  ///
  /// With [strict] a missing or damaged file throws [BrokenAttachments] and
  /// nothing is written. Without it those attachments are **left out** of the
  /// copy (their rows stay in the database) and come back in
  /// [BackupEncoding.warnings]: a copy that lacks a photo that is already lost
  /// is better than no copy at all (the safety copy before a restore and the
  /// automatic copies must not stop for it).
  Future<BackupEncoding> encodeCurrent(
    BackupData data, {
    required DateTime at,
    bool strict = false,
    String? appVersion,
  }) async {
    final codec = _codec;
    final version = appVersion ?? this.appVersion;
    if (data.noteAttachments.isEmpty) {
      final bytes = await _runner(
        () => codec.encode(data, appVersion: version, exportedAt: at),
      );
      return BackupEncoding(bytes, data, const []);
    }
    final store = await _store();
    if (store == null) {
      throw const CorruptBackup('Attachments without a store');
    }
    final rootPath = store.root.path;
    final refs = _refsOf(data);
    final read = readAttachmentFile;
    final job = await _runner(() {
      final check = readVerifiedAttachmentFiles(rootPath, refs, read: read);
      if (check.broken.isNotEmpty && strict) {
        return (bytes: null, broken: check.broken);
      }
      final kept = data.withoutAttachments({
        for (final b in check.broken) b.id,
      });
      final bytes = codec.encode(
        kept,
        appVersion: version,
        exportedAt: at,
        attachmentFiles: check.files,
      );
      return (bytes: bytes, broken: check.broken);
    });
    final bytes = job.bytes;
    if (bytes == null) throw BrokenAttachments(job.broken);
    return BackupEncoding(
      bytes,
      data.withoutAttachments({for (final b in job.broken) b.id}),
      warningsFor(job.broken),
    );
  }

  /// The files of [data] checked against its rows: every attachment must
  /// bring its file, of the right size and (unless [verified]) with the right
  /// SHA-256, which is then checked through the runner.
  Future<Map<String, Uint8List>> _checkedAttachmentFiles(
    BackupData data,
    Map<String, Uint8List> files, {
    required bool verified,
  }) async {
    for (final a in data.noteAttachments) {
      final bytes = files[a.id];
      if (bytes == null) {
        throw CorruptBackup('Attachment "${a.id}" has no file');
      }
      if (bytes.length != a.sizeBytes) {
        throw CorruptBackup('Attachment "${a.id}" does not match its size');
      }
    }
    if (!verified && data.noteAttachments.isNotEmpty) {
      final expected = {for (final a in data.noteAttachments) a.id: a.sha256};
      final wrong = await _runner(() {
        for (final MapEntry(:key, :value) in expected.entries) {
          if (sha256Hex(files[key]!) != value) return key;
        }
        return null;
      });
      if (wrong != null) {
        throw CorruptBackup('Attachment "$wrong" does not match its SHA-256');
      }
    }
    return files;
  }

  /// Writes the files of the attachments in the store and returns the paths
  /// that were written (the ones that were already there are left alone).
  ///
  /// If a file cannot be written (a store that is full, a file that is not
  /// what its path says), the files that were written for this restore go
  /// away again: a restore that fails leaves no trash.
  Future<List<String>> _writeAttachmentFiles(
    BackupData data,
    Map<String, Uint8List> files,
  ) async {
    if (data.noteAttachments.isEmpty) return const [];
    final store = await _store();
    if (store == null) {
      throw const CorruptBackup('Attachments without a store');
    }
    final written = <String>[];
    try {
      for (final a in data.noteAttachments) {
        final bytes = files[a.id];
        if (bytes == null) {
          throw CorruptBackup('Attachment "${a.id}" has no file');
        }
        // The bytes are the verified content of the row and its path is
        // the one of that hash, so a file there that is not them is damaged:
        // it is replaced (it could not be read back anyway).
        if (await store.writeAt(a.relativePath, bytes, replaceDamaged: true)) {
          written.add(a.relativePath);
        }
      }
    } catch (_) {
      // The files written for the rows that did not go in must not stay
      // alone: the restore did not happen.
      await _deleteFiles(written);
      rethrow;
    }
    return written;
  }

  Future<void> _deleteFiles(List<String> paths) async {
    final store = await _store();
    if (store == null) return;
    for (final path in paths) {
      try {
        await store.delete(path);
      } on AttachmentStoreException {
        // The file stays; the next sweep removes it.
      }
    }
  }

  /// Deletes the files that no row points at any more, except the paths in
  /// [keep].
  Future<void> _sweepAttachmentFiles({Set<String> keep = const {}}) async {
    final store = await _store();
    if (store == null) return;
    final rows = await _db.select(_db.noteAttachments).get();
    await store.sweep({for (final row in rows) row.relativePath, ...keep});
  }

  /// [data] without the alarm sounds that are not the system's
  /// ([BackupData.sanitized]); the log says how many, never which.
  static BackupData _withoutForeignSounds(BackupData data) {
    final dropped = data.foreignAlarmSoundCount;
    if (dropped > 0) {
      debugPrint(
        'Backup: dropped $dropped alarm sound(s) of an unknown source',
      );
    }
    return data.sanitized();
  }

  /// "Probar restauración": a dry run of [bytes] (a `.turnly` file) that
  /// touches nothing. It decodes the file, rebuilds it in a scratch in-memory
  /// database, and compares fingerprints over the 730 days around [today]:
  /// the rebuilt data must equal the file ([VerificationPassed]; otherwise
  /// [VerificationMismatch] with the first differing day), and the result
  /// says whether it also equals what the phone holds now.
  Future<RestoreVerification> verifyRestore(
    Uint8List bytes, {
    required CivilDate today,
  }) async {
    final BackupFile file;
    try {
      file = _codec.decode(bytes);
    } on BackupException catch (e) {
      return VerificationFailed(e);
    }
    try {
      final window = defaultFingerprintWindow(today);
      ScheduleFingerprint fingerprint(BackupData data) =>
          scheduleFingerprint(data, from: window.from, to: window.to);

      final data = file.data.sanitized().upgradedOvertime()..validate();
      final expected = fingerprint(data);
      final scratch = _openScratchDatabase();
      final BackupData rebuilt;
      try {
        await _replaceAll(scratch, data);
        rebuilt = await _readAll(scratch);
      } finally {
        await scratch.close();
      }
      final actual = fingerprint(rebuilt);
      if (actual != expected) {
        return VerificationMismatch(
          expected: expected,
          actual: actual,
          firstDifferingDay: expected.firstDayDifferingFrom(actual),
        );
      }

      final live = fingerprint(await readAll());
      final matches = live == expected;
      return VerificationPassed(
        fingerprint: expected,
        matchesLive: matches,
        firstDayDifferingFromLive: matches
            ? null
            : expected.firstDayDifferingFrom(live),
      );
    } catch (e) {
      return VerificationFailed(e);
    }
  }

  /// Makes the safety copy that a restore needs before it changes anything.
  /// Returns what it left out as warnings and the store paths of those
  /// attachments, which the restore must not sweep.
  ///
  /// The safety copy carries the attachments too: a restore that goes wrong
  /// must be undoable, files included. The ones whose file is already lost
  /// ([AttachmentFault.missing]) or does not match its row
  /// ([AttachmentFault.damaged]) are left out (and reported): they would stop
  /// every restore otherwise. A file that is there but **could not be read**
  /// ([AttachmentFault.unreadable]) is different: it may be perfectly good,
  /// and the replaced data's files are deleted when the restore ends, so
  /// going on would lose it for good. That restore is refused before anything
  /// is written or changed ([BrokenAttachments]); trying again once the file
  /// reads works.
  Future<({List<BackupWarning> warnings, Set<String> skippedPaths})>
  _writeSafetyCopy() async {
    final now = _now();
    final current = await readAll();
    final codec = _codec;
    final encoding = await encodeCurrent(current, at: now);
    final unreadable = [
      for (final warning in encoding.warnings)
        if (warning is AttachmentsSkipped)
          for (final b in warning.attachments)
            if (b.fault == AttachmentFault.unreadable) b,
    ];
    if (unreadable.isNotEmpty) throw BrokenAttachments(unreadable);
    final skippedIds = {
      for (final warning in encoding.warnings)
        if (warning is AttachmentsSkipped)
          for (final b in warning.attachments) b.id,
    };
    final skippedPaths = {
      for (final a in current.noteAttachments)
        if (skippedIds.contains(a.id)) a.relativePath,
    };
    final data = encoding.data;
    final file = await newBackupFile(safetyDirectory, _safetyPrefix, now);
    await writeFileAtomically(file, encoding.bytes);
    // Verify the file actually persisted, not the in-memory buffer. Neither
    // the live database nor older recovery copies may change on failure.
    final persisted = await _readSafetyCopy(file);
    await _runner(() {
      final verified = codec.decode(persisted);
      // The writer gives old overtime minutes as blocks (format version 4).
      if (verified.data != data.upgradedOvertime()) {
        throw const CorruptBackup('Safety copy differs from current data');
      }
    });
    await pruneBackupFiles(
      safetyDirectory,
      backupNamePattern(_safetyPrefix),
      keepSafetyCopies,
    );
    return (warnings: encoding.warnings, skippedPaths: skippedPaths);
  }

  static AppDatabase _openMemoryDatabase() {
    // A scratch database next to the real one is on purpose.
    final previous = driftRuntimeOptions.dontWarnAboutMultipleDatabases;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    try {
      return AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
    } finally {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = previous;
    }
  }

  static Future<BackupData> _readAll(AppDatabase db) => db.transaction(
    () async {
      final calendars = await db.select(db.calendars).get();
      final types =
          await (db.select(db.shiftTypes)..orderBy([
                (t) => OrderingTerm.asc(t.sortOrder),
                (t) => OrderingTerm.asc(t.id),
              ]))
              .get();
      // Insertion order (rowid): patterns have no sort column and the app
      // shows them in this order.
      final patterns =
          await (db.select(db.patterns)..orderBy([
                (_) => OrderingTerm.asc(const CustomExpression<int>('rowid')),
              ]))
              .get();
      final runs = await db.select(db.patternRuns).get();
      final entries = await db.select(db.dayEntries).get();
      final holidays = await (db.select(
        db.holidays,
      )..where((h) => h.source.equals(userHolidaySource))).get();
      final balances = await db.select(db.absenceBalances).get();
      final settings = await db.select(db.settings).get();
      final attachments = await db.select(db.noteAttachments).get();
      final tasks = await db.select(db.dayTasks).get();
      final swaps = await db.select(db.shiftSwaps).get();
      final versionRows = await db.select(db.shiftTypeVersions).get();
      final versionsByType = <String, List<ShiftTypeVersionRow>>{};
      for (final v in versionRows) {
        (versionsByType[v.shiftTypeId] ??= []).add(v);
      }

      final overtimeTypes = await db.select(db.overtimeTypes).get();
      final overtimeBlocks = await db.select(db.overtimeBlocks).get();
      // The two built-in types, untouched and unused, are what every
      // database has: the backup leaves them out, so data that never used
      // the extra hours is what it always was (and restores them).
      final builtInOnly =
          overtimeBlocks.isEmpty &&
          overtimeTypes.length == defaultOvertimeTypes.length &&
          overtimeTypes.every((t) => defaultOvertimeTypes.contains(t.toType()));
      return BackupData(
        overtimeTypes: [
          if (!builtInOnly)
            for (final t in overtimeTypes)
              BackupOvertimeType(
                id: t.id,
                name: t.name,
                colorValue: t.colorValue,
                rateMode: t.rateMode,
                multiplierBasisPoints: t.multiplierBasisPoints,
                hourlyRateCents: t.hourlyRateCents,
                countsForGoal: t.countsForGoal,
                archived: t.archived,
                sortOrder: t.sortOrder,
              ),
        ],
        overtimeBlocks: [
          for (final b in overtimeBlocks)
            BackupOvertimeBlock(
              calendarId: b.calendarId,
              date: b.date,
              id: b.id,
              typeId: b.typeId,
              startMinute: b.startMinute,
              endMinute: b.endMinute,
              breakMinutes: b.breakMinutes,
              note: b.note,
            ),
        ],
        calendars: [
          for (final c in calendars)
            BackupCalendar(
              id: c.id,
              name: c.name,
              colorValue: c.colorValue,
              sortOrder: c.sortOrder,
              archived: c.archived,
              createdAt: c.createdAt,
              updatedAt: c.updatedAt,
            ),
        ],
        shiftTypes: [
          for (final t in types)
            BackupShiftType(
              id: t.id,
              code: t.code,
              name: t.name,
              colorValue: t.colorValue,
              category: t.category,
              startMinute: t.startMinute,
              endMinute: t.endMinute,
              paidMinutes: t.paidMinutes,
              nightOverride: t.nightOverride,
              hourlyRateCents: t.hourlyRateCents,
              fixedPlusCents: t.fixedPlusCents,
              icon: ShiftIcon.fromKey(t.icon),
              alarmSound: t.alarmSound,
              segment2StartMinute: t.segment2StartMinute,
              segment2DurationMinutes: t.segment2DurationMinutes,
              location: t.location,
              nightPlusCentsPerHour: t.nightPlusCentsPerHour,
              holidayPlusCentsPerHour: t.holidayPlusCentsPerHour,
              sortOrder: t.sortOrder,
              archived: t.archived,
              createdAt: t.createdAt,
              updatedAt: t.updatedAt,
              pastVersions: [
                for (final v in [
                  ...?versionsByType[t.id],
                ]..sort((a, b) => a.untilDate.compareTo(b.untilDate)))
                  BackupShiftTypeVersion(
                    until: v.untilDate,
                    category: v.category,
                    startMinute: v.startMinute,
                    endMinute: v.endMinute,
                    paidMinutes: v.paidMinutes,
                    nightOverride: v.nightOverride,
                    hourlyRateCents: v.hourlyRateCents,
                    fixedPlusCents: v.fixedPlusCents,
                    segment2StartMinute: v.segment2StartMinute,
                    segment2DurationMinutes: v.segment2DurationMinutes,
                    nightPlusCentsPerHour: v.nightPlusCentsPerHour,
                    holidayPlusCentsPerHour: v.holidayPlusCentsPerHour,
                    createdAt: v.createdAt,
                  ),
              ],
            ),
        ],
        patterns: [
          for (final r in patterns)
            BackupPattern(
              id: r.id,
              name: r.name,
              steps: r.steps,
              createdAt: r.createdAt,
              updatedAt: r.updatedAt,
            ),
        ],
        patternRuns: [
          for (final r in runs)
            BackupPatternRun(
              id: r.id,
              calendarId: r.calendarId,
              patternId: r.patternId,
              startDate: r.startDate,
              endDate: r.endDate,
              stepOffset: r.stepOffset,
              seq: r.seq,
              createdAt: r.createdAt,
            ),
        ],
        dayEntries: [
          for (final e in entries)
            BackupDayEntry(
              calendarId: e.calendarId,
              date: e.date,
              shiftTypeIds: e.shiftTypeIds,
              note: e.note,
              noteReminderMinute: e.noteReminderMinute,
              overtimeMinutes: e.overtimeMinutes,
              earlyLeaveMinutes: e.earlyLeaveMinutes,
              extraAmountCents: e.extraAmountCents,
              updatedAt: e.updatedAt,
            ),
        ],
        holidays: [
          for (final h in holidays)
            BackupHoliday(
              date: CivilDate.parse(h.date),
              scope: h.scope,
              name: h.name,
              regionCode: h.regionCode,
              municipalityCode: h.municipalityCode,
            ),
        ],
        absenceBalances: [
          for (final b in balances)
            BackupAbsenceBalance(
              year: b.year,
              type: b.type,
              allowedDays: b.allowedDays,
              calendarId: b.calendarId,
              name: b.name,
              periodStart: b.periodStart,
              periodEnd: b.periodEnd,
              unit: b.unit,
              shiftTypeQuarters: b.shiftTypeQuarters ?? const {},
              carryOver: b.carryOver,
              carryOverMaxDays: b.carryOverMaxDays,
              adjustmentDays: b.adjustmentDays,
              sortOrder: b.sortOrder,
              createdAt: b.createdAt,
              updatedAt: b.updatedAt,
            ),
        ],
        settings: {
          for (final s in settings)
            if (!isDeviceSetting(s.key)) s.key: s.value,
        },
        noteAttachments: [
          for (final a in attachments)
            BackupNoteAttachment(
              id: a.id,
              calendarId: a.calendarId,
              date: a.date,
              kind: a.kind,
              relativePath: a.relativePath,
              mimeType: a.mimeType,
              sizeBytes: a.sizeBytes,
              sha256: a.sha256,
              displayName: a.displayName,
              sortOrder: a.sortOrder,
              createdAt: a.createdAt,
            ),
        ],
        dayTasks: [
          for (final t in tasks)
            BackupDayTask(
              id: t.id,
              calendarId: t.calendarId,
              date: t.date,
              title: t.title,
              done: t.done,
              sortOrder: t.sortOrder,
              createdAt: t.createdAt,
              updatedAt: t.updatedAt,
            ),
        ],
        shiftSwaps: [
          for (final s in swaps)
            BackupShiftSwap(
              id: s.id,
              calendarId: s.calendarId,
              date: s.date,
              colleague: s.colleague,
              direction: s.direction,
              givenShiftTypeIds: s.givenShiftTypeIds,
              receivedShiftTypeIds: s.receivedShiftTypeIds,
              returnDate: s.returnDate,
              status: s.status,
              note: s.note,
              createdAt: s.createdAt,
              updatedAt: s.updatedAt,
              closedAt: s.closedAt,
            ),
        ],
      );
    },
  );

  /// Deletes the user tables and writes [data], in one transaction on [db].
  /// Children before parents when deleting, parents before children when
  /// inserting (foreign keys are on).
  static Future<void> _replaceAll(AppDatabase db, BackupData data) =>
      db.transaction(() async {
        // Device settings survive: read before the table is emptied.
        final device = [
          for (final row in await db.select(db.settings).get())
            if (isDeviceSetting(row.key)) row,
        ];
        await db.delete(db.overtimeBlocks).go();
        await db.delete(db.overtimeTypes).go();
        await db.delete(db.patternRuns).go();
        await db.delete(db.dayEntries).go();
        await db.delete(db.noteAttachments).go();
        await db.delete(db.dayTasks).go();
        await db.delete(db.shiftSwaps).go();
        await db.delete(db.absenceBalances).go();
        await db.delete(db.calendars).go();
        await db.delete(db.patterns).go();
        await db.delete(db.shiftTypeVersions).go();
        await db.delete(db.shiftTypes).go();
        await (db.delete(
          db.holidays,
        )..where((h) => h.source.equals(userHolidaySource))).go();
        await db.delete(db.settings).go();

        await db.batch((b) {
          b.insertAll(db.calendars, [
            for (final c in data.calendars)
              CalendarsCompanion.insert(
                id: c.id,
                name: c.name,
                colorValue: c.colorValue,
                sortOrder: c.sortOrder,
                archived: Value(c.archived),
                createdAt: c.createdAt,
                updatedAt: c.updatedAt,
              ),
          ]);
          b.insertAll(db.shiftTypes, [
            for (final t in data.shiftTypes)
              ShiftTypesCompanion.insert(
                id: t.id,
                code: t.code,
                name: t.name,
                colorValue: t.colorValue,
                category: t.category,
                startMinute: Value(t.startMinute),
                endMinute: Value(t.endMinute),
                paidMinutes: Value(t.paidMinutes),
                nightOverride: Value(t.nightOverride),
                hourlyRateCents: Value(t.hourlyRateCents),
                fixedPlusCents: Value(t.fixedPlusCents),
                icon: Value(t.icon?.key),
                alarmSound: Value(t.alarmSound),
                segment2StartMinute: Value(t.segment2StartMinute),
                segment2DurationMinutes: Value(t.segment2DurationMinutes),
                location: Value(t.location),
                nightPlusCentsPerHour: Value(t.nightPlusCentsPerHour),
                holidayPlusCentsPerHour: Value(t.holidayPlusCentsPerHour),
                sortOrder: t.sortOrder,
                archived: Value(t.archived),
                createdAt: t.createdAt,
                updatedAt: t.updatedAt,
              ),
          ]);
          b.insertAll(db.shiftTypeVersions, [
            for (final t in data.shiftTypes)
              for (final v in t.pastVersions)
                ShiftTypeVersionsCompanion.insert(
                  shiftTypeId: t.id,
                  untilDate: v.until,
                  category: v.category,
                  startMinute: Value(v.startMinute),
                  endMinute: Value(v.endMinute),
                  paidMinutes: Value(v.paidMinutes),
                  nightOverride: Value(v.nightOverride),
                  hourlyRateCents: Value(v.hourlyRateCents),
                  fixedPlusCents: Value(v.fixedPlusCents),
                  segment2StartMinute: Value(v.segment2StartMinute),
                  segment2DurationMinutes: Value(v.segment2DurationMinutes),
                  nightPlusCentsPerHour: Value(v.nightPlusCentsPerHour),
                  holidayPlusCentsPerHour: Value(v.holidayPlusCentsPerHour),
                  createdAt: v.createdAt,
                ),
          ]);
          // In the order given: it is the insertion (rowid) order.
          b.insertAll(db.patterns, [
            for (final p in data.patterns)
              PatternsCompanion.insert(
                id: p.id,
                name: p.name,
                steps: p.steps,
                createdAt: p.createdAt,
                updatedAt: p.updatedAt,
              ),
          ]);
          b.insertAll(db.patternRuns, [
            for (final r in data.patternRuns)
              PatternRunsCompanion.insert(
                id: r.id,
                calendarId: r.calendarId,
                patternId: r.patternId,
                startDate: r.startDate,
                endDate: Value(r.endDate),
                stepOffset: Value(r.stepOffset),
                seq: r.seq,
                createdAt: r.createdAt,
              ),
          ]);
          b.insertAll(db.dayEntries, [
            for (final e in data.dayEntries)
              DayEntriesCompanion.insert(
                calendarId: e.calendarId,
                date: e.date,
                shiftTypeIds: Value(e.shiftTypeIds),
                note: Value(e.note),
                noteReminderMinute: Value(e.noteReminderMinute),
                overtimeMinutes: Value(e.overtimeMinutes),
                earlyLeaveMinutes: Value(e.earlyLeaveMinutes),
                extraAmountCents: Value(e.extraAmountCents),
                updatedAt: e.updatedAt,
              ),
          ]);
          b.insertAll(db.noteAttachments, [
            for (final a in data.noteAttachments)
              NoteAttachmentsCompanion.insert(
                id: a.id,
                calendarId: a.calendarId,
                date: a.date,
                kind: a.kind,
                relativePath: a.relativePath,
                mimeType: a.mimeType,
                sizeBytes: a.sizeBytes,
                sha256: a.sha256,
                displayName: Value(a.displayName),
                sortOrder: Value(a.sortOrder),
                createdAt: a.createdAt,
              ),
          ]);
          b.insertAll(db.dayTasks, [
            for (final t in data.dayTasks)
              DayTasksCompanion.insert(
                id: t.id,
                calendarId: t.calendarId,
                date: t.date,
                title: t.title,
                done: Value(t.done),
                sortOrder: Value(t.sortOrder),
                createdAt: t.createdAt,
                updatedAt: t.updatedAt,
              ),
          ]);
          b.insertAll(db.shiftSwaps, [
            for (final s in data.shiftSwaps)
              ShiftSwapsCompanion.insert(
                id: s.id,
                calendarId: s.calendarId,
                date: s.date,
                colleague: s.colleague,
                direction: s.direction,
                givenShiftTypeIds: Value(s.givenShiftTypeIds),
                receivedShiftTypeIds: Value(s.receivedShiftTypeIds),
                returnDate: Value(s.returnDate),
                status: Value(s.status),
                note: Value(s.note),
                createdAt: s.createdAt,
                updatedAt: s.updatedAt,
                closedAt: Value(s.closedAt),
              ),
          ]);
          b.insertAll(db.holidays, [
            for (final h in data.holidays)
              HolidaysCompanion.insert(
                date: h.date.toIso(),
                scope: h.scope,
                name: h.name,
                regionCode: Value(h.regionCode),
                municipalityCode: Value(h.municipalityCode),
                source: userHolidaySource,
              ),
          ]);
          b.insertAll(db.absenceBalances, [
            for (final a in data.absenceBalances)
              AbsenceBalancesCompanion.insert(
                year: a.year,
                type: a.type,
                allowedDays: a.allowedDays,
                calendarId: Value(a.calendarId),
                name: Value(a.name),
                periodStart: Value(a.periodStart),
                periodEnd: Value(a.periodEnd),
                unit: Value(a.unit),
                shiftTypeQuarters: Value(
                  a.shiftTypeQuarters.isEmpty ? null : a.shiftTypeQuarters,
                ),
                carryOver: Value(a.carryOver),
                carryOverMaxDays: Value(a.carryOverMaxDays),
                adjustmentDays: Value(a.adjustmentDays),
                sortOrder: Value(a.sortOrder),
                createdAt: Value(a.createdAt),
                updatedAt: Value(a.updatedAt),
              ),
          ]);
          b.insertAll(db.settings, [
            for (final s in data.settings.entries)
              if (!isDeviceSetting(s.key))
                SettingsCompanion.insert(key: s.key, value: s.value),
            for (final row in device)
              SettingsCompanion.insert(key: row.key, value: row.value),
          ]);
        });
        // Database v7: types before the blocks that point at them. Data
        // without types (it never used the extra hours, or an older format)
        // gets the two built-in ones, like a new database.
        final overtimeTypes = data.overtimeTypes.isNotEmpty
            ? data.overtimeTypes
            : [for (final t in defaultOvertimeTypes) BackupOvertimeType.of(t)];
        await db.batch((b) {
          b.insertAll(db.overtimeTypes, [
            for (final t in overtimeTypes)
              OvertimeTypesCompanion.insert(
                id: t.id,
                name: Value(t.name),
                colorValue: t.colorValue,
                rateMode: t.rateMode,
                multiplierBasisPoints: Value(t.multiplierBasisPoints),
                hourlyRateCents: Value(t.hourlyRateCents),
                countsForGoal: t.countsForGoal,
                archived: Value(t.archived),
                sortOrder: Value(t.sortOrder),
              ),
          ]);
          b.insertAll(db.overtimeBlocks, [
            for (final o in data.overtimeBlocks)
              OvertimeBlocksCompanion.insert(
                calendarId: o.calendarId,
                date: o.date,
                id: o.id,
                typeId: o.typeId,
                startMinute: o.startMinute,
                endMinute: o.endMinute,
                breakMinutes: Value(o.breakMinutes),
                note: Value(o.note),
              ),
          ]);
        });
      });
}
