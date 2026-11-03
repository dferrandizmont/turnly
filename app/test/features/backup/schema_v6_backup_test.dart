import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/features/absences/domain/absence_balance.dart';
import 'package:cuadrante/features/backup/domain/backup_codec.dart';
import 'package:cuadrante/features/backup/domain/backup_container.dart';
import 'package:cuadrante/features/backup/domain/backup_data.dart';
import 'package:cuadrante/features/backup/domain/backup_errors.dart';
import 'package:cuadrante/features/backup/domain/canonical_json.dart';
import 'package:cuadrante/features/backup/domain/restore_summary.dart';
import 'package:cuadrante/features/backup/domain/schedule_fingerprint.dart';
import 'package:cuadrante/features/notes/domain/note_attachment.dart';
import 'package:cuadrante/features/schedule/data/schedule_repository.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/swaps/domain/shift_swap.dart';
import 'package:flutter_test/flutter_test.dart';

import 'backup_test_support.dart';
import 'golden_dataset_v3.dart';

final _photo = Uint8List.fromList(List.generate(3000, (i) => i * 7 % 256));
final _pdf = Uint8List.fromList(utf8.encode('%PDF-1.4 nómina'));

BackupNoteAttachment _attachment(
  String id,
  Uint8List bytes, {
  String calendarId = 'main',
  String? path,
  AttachmentKind kind = AttachmentKind.photo,
  String mime = 'image/jpeg',
  String? name,
}) => BackupNoteAttachment(
  id: id,
  calendarId: calendarId,
  date: const CivilDate(2026, 3, 12),
  kind: kind,
  relativePath:
      path ?? '${sha256Hex(bytes).substring(0, 2)}/${sha256Hex(bytes)}',
  mimeType: mime,
  sizeBytes: bytes.length,
  sha256: sha256Hex(bytes),
  displayName: name,
  createdAt: 1767254400000,
);

/// [base] with a value in every database v6 field and table. Attachments
/// only when [withAttachments].
BackupData _withV6({bool withAttachments = false, BackupData? base}) {
  final golden = base ?? buildGoldenBackupDataV3();
  return BackupData(
    calendars: golden.calendars,
    shiftTypes: [
      for (final t in golden.shiftTypes)
        t.id == 'night'
            ? BackupShiftType.fromJson({
                ...t.toJson(),
                'location': 'UCI, planta 3',
                'nightPlusCentsPerHour': 250,
                'holidayPlusCentsPerHour': 5000000,
                'fixedPlusCents': 2500,
                'pastVersions': [
                  {
                    'until': '2026-03-31',
                    'category': 'work',
                    'startMinute': 1260,
                    'endMinute': 300,
                    'nightPlusCentsPerHour': 100,
                    'holidayPlusCentsPerHour': 200,
                    'createdAt': 1,
                  },
                ],
              })
            : t,
    ],
    patterns: golden.patterns,
    patternRuns: golden.patternRuns,
    dayEntries: [
      for (final e in golden.dayEntries)
        e.date == const CivilDate(2026, 3, 13) && e.calendarId == 'main'
            ? BackupDayEntry.fromJson({
                ...e.toJson(),
                'extraAmountCents': -1550,
              })
            : e,
    ],
    holidays: golden.holidays,
    absenceBalances: [
      ...golden.absenceBalances,
      const BackupAbsenceBalance(year: 2025, type: 'legacy', allowedDays: 3),
      const BackupAbsenceBalance(
        year: 2027,
        type: 'vac-main',
        allowedDays: 22.5,
        calendarId: 'cal-pareja',
        name: 'Vacaciones',
        periodStart: CivilDate(2027, 4, 1),
        periodEnd: CivilDate(2028, 3, 31),
        unit: AbsenceUnit.half,
        shiftTypeQuarters: {'vacation': 4, 'half-vac': 2},
        carryOver: true,
        carryOverMaxDays: 5,
        adjustmentDays: -1.5,
        sortOrder: 2,
        createdAt: 10,
        updatedAt: 11,
      ),
    ],
    settings: golden.settings,
    noteAttachments: withAttachments
        ? [
            _attachment('att-photo', _photo),
            _attachment(
              'att-pdf',
              _pdf,
              calendarId: 'cal-pareja',
              kind: AttachmentKind.file,
              mime: 'application/pdf',
              name: 'nómina marzo.pdf',
            ),
          ]
        : const [],
    dayTasks: const [
      BackupDayTask(
        id: 'task-b',
        calendarId: 'main',
        date: CivilDate(2026, 3, 12),
        title: 'Llevar la bata',
        done: true,
        sortOrder: 1,
        createdAt: 5,
        updatedAt: 6,
      ),
      BackupDayTask(
        id: 'task-a',
        calendarId: 'cal-pareja',
        date: CivilDate(2026, 3, 12),
        title: 'Recoger a los niños',
        createdAt: 5,
        updatedAt: 5,
      ),
    ],
    shiftSwaps: const [
      BackupShiftSwap(
        id: 'swap-1',
        calendarId: 'main',
        date: CivilDate(2026, 3, 14),
        colleague: 'Marta',
        direction: SwapDirection.theyOwe,
        givenShiftTypeIds: ['night'],
        receivedShiftTypeIds: [],
        returnDate: CivilDate(2026, 4, 2),
        status: SwapStatus.returned,
        note: 'Me devuelve la noche del 2',
        createdAt: 7,
        updatedAt: 9,
        closedAt: 9,
      ),
      BackupShiftSwap(
        id: 'swap-2',
        calendarId: 'main',
        date: CivilDate(2026, 3, 20),
        colleague: 'Luis',
        direction: SwapDirection.iOwe,
        createdAt: 8,
        updatedAt: 8,
      ),
    ],
  );
}

Map<String, Uint8List> get _files => {'att-photo': _photo, 'att-pdf': _pdf};

/// The `data` JSON as an app that only knows the keys before database v6
/// reads it: every key it does not know dropped.
Map<String, Object?> _asOldAppSees(Map<String, Object?> data) {
  const v6Data = {'noteAttachments', 'dayTasks', 'shiftSwaps'};
  const v6Type = {
    'location',
    'nightPlusCentsPerHour',
    'holidayPlusCentsPerHour',
  };
  const v6Version = {'nightPlusCentsPerHour', 'holidayPlusCentsPerHour'};
  const oldBalance = {'year', 'type', 'allowedDays'};
  Map<String, Object?> without(Object? o, Set<String> keys) => {
    for (final e in (o! as Map<String, Object?>).entries)
      if (!keys.contains(e.key)) e.key: e.value,
  };
  return {
    for (final e in data.entries)
      if (!v6Data.contains(e.key))
        e.key: switch (e.key) {
          'shiftTypes' => [
            for (final t in e.value! as List)
              without(t, v6Type)..updateAll(
                (k, v) => k == 'pastVersions'
                    ? [for (final p in v! as List) without(p, v6Version)]
                    : v,
              ),
          ],
          'dayEntries' => [
            for (final d in e.value! as List) without(d, {'extraAmountCents'}),
          ],
          'absenceBalances' => [
            for (final b in e.value! as List)
              {for (final k in oldBalance) k: (b! as Map<String, Object?>)[k]},
          ],
          _ => e.value,
        },
  };
}

void main() {
  const codec = BackupCodec();
  final at = DateTime.utc(2026, 11, 1);
  late AppDatabase db;
  late Directory dir;

  setUp(() {
    db = openMemoryDatabase();
    addTearDown(db.close);
    dir = makeTempDir('schema-v6-backup');
  });

  group('format', () {
    test('every v6 field survives codec, database, safety copy and '
        '«Probar restauración»', () async {
      final data = _withV6();
      data.validate();
      final bytes = codec.encode(data, appVersion: 'test', exportedAt: at);
      expect(bytes.take(2), [0x1f, 0x8b], reason: 'no files: plain gzip');
      final file = codec.decode(bytes);
      expect(file.schemaVersion, 3);
      expect(file.data, data);
      expect(file.attachmentFiles, isEmpty);

      final repo = makeRepository(db, dir);
      await repo.restore(file.data);
      expect(await repo.readAll(), data);
      final schedule = (await ScheduleRepository(db).load('main')).schedule;
      final night = schedule.shiftTypeById('night')!;
      expect(night.location, 'UCI, planta 3');
      expect(night.nightPlusCentsPerHour, 250);
      expect(night.holidayPlusCentsPerHour, 5000000);
      expect(night.fixedPlusCents, 2500);
      expect(
        schedule.versionsOf('night').single.terms.holidayPlusCentsPerHour,
        200,
      );
      expect(
        schedule.entries[const CivilDate(2026, 3, 13)]!.extraAmountCents,
        -1550,
      );
      expect(
        await repo.verifyRestore(bytes, today: const CivilDate(2026, 11, 1)),
        isA<VerificationPassed>(),
      );

      // A restore over it keeps it all in the safety copy.
      await repo.restore(buildGoldenBackupDataV3());
      expect(await repo.readAll(), buildGoldenBackupDataV3());
      final safety = dir.listSync().whereType<File>().map(
        (f) => codec.decode(f.readAsBytesSync()).data,
      );
      expect(safety.any((d) => d == data), isTrue);
    });

    test('data without v6 values writes no v6 key: the golden bytes, '
        'checksum and fingerprint stay', () {
      final plain = buildGoldenBackupDataV3();
      final json = canonicalJson(plain.toJson());
      for (final key in [
        'noteAttachments',
        'dayTasks',
        'shiftSwaps',
        'location',
        'nightPlusCentsPerHour',
        'holidayPlusCentsPerHour',
        'extraAmountCents',
        'unit',
        'carryOver',
        'periodStart',
      ]) {
        expect(json, isNot(contains('"$key')), reason: key);
      }
      final old = codec.decode(
        File('test/fixtures/golden_backup/golden_v3.cuadrante')
            .readAsBytesSync(),
      );
      expect(BackupCodec.checksumOf(old.data), old.checksum);
      expect(old.data.noteAttachments, isEmpty);
      expect(old.data.dayTasks, isEmpty);
      expect(old.data.shiftSwaps, isEmpty);
    });

    test('an app from before v6 still reads every day of a v6 file: only '
        'the new keys are unknown to it', () {
      final data = _withV6();
      final json =
          jsonDecode(canonicalJson(data.toJson())) as Map<String, Object?>;
      final seen = _asOldAppSees(json);
      // What it reads is exactly the data with the v6 values taken out:
      // the same calendars, types, rotations and days.
      final stripped = BackupData.fromJson(seen);
      expect(stripped.dayEntries.length, data.dayEntries.length);
      expect(
        [for (final e in stripped.dayEntries) e.toEntry().withoutExtra()],
        [for (final e in data.dayEntries) e.toEntry().withoutExtra()],
      );
      expect(stripped.patternRuns, data.patternRuns);
      expect(stripped.calendars, data.calendars);
      expect(
        [for (final t in stripped.shiftTypes) t.id],
        [for (final t in data.shiftTypes) t.id],
      );
      // The balances keep the three keys every version requires, and
      // (year, type) is still unique.
      for (final b in json['absenceBalances']! as List) {
        final map = b! as Map<String, Object?>;
        expect(map['year'], isA<int>());
        expect(map['type'], isA<String>());
        expect(map['allowedDays'], isA<num>());
      }
      stripped.validate();
      // And the schema version is the one it knows.
      final bytes = codec.encode(data, appVersion: 'test', exportedAt: at);
      expect(readEnvelope(bytes)['schemaVersion'], 3);
    });

    test('a balance from before v6 writes only its three keys', () {
      const legacy = BackupAbsenceBalance(
        year: 2025,
        type: 'legacy',
        allowedDays: 3,
      );
      expect(legacy.toJson(), {
        'year': 2025,
        'type': 'legacy',
        'allowedDays': 3.0,
      });
      expect(BackupAbsenceBalance.fromJson(legacy.toJson()), legacy);
    });

    test('version 1 and 2 readers ignore the v6 keys of a balance', () {
      final full = _withV6().absenceBalances.firstWhere(
        (b) => b.type == 'vac-main',
      );
      final read = BackupAbsenceBalance.fromJson(
        full.toJson(),
        readExtensions: false,
      );
      expect(
        read,
        const BackupAbsenceBalance(
          year: 2027,
          type: 'vac-main',
          allowedDays: 22.5,
        ),
      );
    });

    test('the extra amount of a day changes the fingerprint; days without '
        'one keep their line', () {
      final window = defaultFingerprintWindow(const CivilDate(2026, 11, 1));
      final plain = buildGoldenBackupDataV3();
      final withExtra = _withV6();
      final a = scheduleFingerprint(plain, from: window.from, to: window.to);
      final b = scheduleFingerprint(
        withExtra,
        from: window.from,
        to: window.to,
      );
      expect(a, isNot(b));
      final day = const CivilDate(2026, 3, 13);
      final linesA = resolvedDayLines(
        plain.toSchedule(),
        from: window.from,
        to: window.to,
      );
      final linesB = resolvedDayLines(
        withExtra.toSchedule(),
        from: window.from,
        to: window.to,
      );
      final index = day.differenceInDays(window.from);
      for (var i = 0; i < linesA.length; i++) {
        if (i == index) {
          expect(linesB[i], contains('"extraAmountCents":-1550'));
        } else {
          expect(linesB[i], linesA[i]);
        }
      }
    });

    test('the counts of the restore preview include the v6 tables', () async {
      final data = _withV6(withAttachments: true);
      final counts = BackupCounts.of(data);
      expect(counts.noteAttachments, 2);
      expect(counts.dayTasks, 2);
      expect(counts.shiftSwaps, 2);
      final repo = makeRepository(db, dir);
      final summary = await repo.preview(data);
      expect(summary.incoming, counts);
      expect(summary.current.dayTasks, 0);
    });
  });

  group('validate', () {
    void expectRejected(BackupData Function(BackupData) mutate, String why) {
      expect(
        () => mutate(_withV6(withAttachments: true)).validate(),
        throwsA(isA<CorruptBackup>()),
        reason: why,
      );
    }

    BackupData withAttachments(
      BackupData d,
      List<BackupNoteAttachment> attachments,
    ) => _rebuild(d, noteAttachments: attachments);

    test('accepts the full data', () {
      _withV6(withAttachments: true).validate();
    });

    test('attachments that could name a file outside the folder', () {
      for (final path in [
        '../cuadrante.sqlite',
        'main/../../x',
        '/data/data/es.cuadrante.app/x',
        'main\\x',
        '.hidden',
        'main/.x',
        '',
        'a//b',
        'main/ x',
        'x' * 600,
      ]) {
        expectRejected(
          (d) => withAttachments(d, [_attachment('att-x', _photo, path: path)]),
          path,
        );
      }
      for (final id in ['', '../x', 'a/b', 'a b', 'x' * 65]) {
        expectRejected(
          (d) => withAttachments(d, [_attachment(id, _photo, path: 'p.bin')]),
          'id $id',
        );
      }
    });

    test('other broken attachments, tasks, swaps and balances', () {
      expectRejected(
        (d) => withAttachments(d, [
          _attachment('a', _photo, path: 'same.bin'),
          _attachment('b', _photo, path: 'same.bin'),
        ]),
        'shared path',
      );
      expectRejected(
        (d) => withAttachments(d, [
          _attachment('a', _photo, path: 'one.bin'),
          _attachment('a', _photo, path: 'two.bin'),
        ]),
        'duplicate id',
      );
      expectRejected(
        (d) =>
            withAttachments(d, [_attachment('a', _photo, calendarId: 'ghost')]),
        'missing calendar',
      );
      expectRejected(
        (d) => withAttachments(d, [_attachment('a', _photo, mime: 'JPEG')]),
        'bad MIME',
      );
      expectRejected(
        (d) => _rebuild(
          d,
          dayTasks: [
            const BackupDayTask(
              id: 't',
              calendarId: 'main',
              date: CivilDate(2026, 1, 1),
              title: '   ',
              createdAt: 1,
              updatedAt: 1,
            ),
          ],
        ),
        'blank task',
      );
      expectRejected(
        (d) => _rebuild(
          d,
          dayTasks: [
            const BackupDayTask(
              id: 't',
              calendarId: 'ghost',
              date: CivilDate(2026, 1, 1),
              title: 'x',
              createdAt: 1,
              updatedAt: 1,
            ),
          ],
        ),
        'task without calendar',
      );
      expectRejected(
        (d) => _rebuild(
          d,
          shiftSwaps: [
            const BackupShiftSwap(
              id: 's',
              calendarId: 'main',
              date: CivilDate(2026, 1, 1),
              colleague: 'Ana',
              direction: SwapDirection.iOwe,
              status: SwapStatus.returned,
              createdAt: 1,
              updatedAt: 1,
            ),
          ],
        ),
        'returned without closedAt',
      );
      expectRejected(
        (d) => _rebuild(
          d,
          shiftSwaps: [
            const BackupShiftSwap(
              id: 's',
              calendarId: 'main',
              date: CivilDate(2026, 1, 1),
              colleague: '',
              direction: SwapDirection.iOwe,
              createdAt: 1,
              updatedAt: 1,
            ),
          ],
        ),
        'swap without colleague',
      );
      for (final balance in [
        const BackupAbsenceBalance(
          year: 2027,
          type: 'x',
          allowedDays: 1,
          calendarId: 'ghost',
        ),
        const BackupAbsenceBalance(
          year: 2027,
          type: 'x',
          allowedDays: 1,
          periodStart: CivilDate(2027, 1, 1),
        ),
        const BackupAbsenceBalance(
          year: 2027,
          type: 'x',
          allowedDays: 1,
          periodStart: CivilDate(2027, 5, 1),
          periodEnd: CivilDate(2027, 4, 1),
        ),
        const BackupAbsenceBalance(
          year: 2027,
          type: 'x',
          allowedDays: 1,
          shiftTypeQuarters: {'vacation': 5},
        ),
        const BackupAbsenceBalance(
          year: 2027,
          type: 'x',
          allowedDays: 1,
          adjustmentDays: 0.3,
        ),
        const BackupAbsenceBalance(
          year: 2027,
          type: 'x',
          allowedDays: 1,
          carryOverMaxDays: -1,
        ),
        const BackupAbsenceBalance(
          year: 2027,
          type: 'x',
          allowedDays: 1,
          name: ' ',
        ),
      ]) {
        expectRejected(
          (d) => _rebuild(d, absenceBalances: [balance]),
          balance.toString(),
        );
      }
    });

    test('a place or a plus out of range, an extra amount too big', () {
      for (final extra in <String, Object?>{
        'location': '',
        'nightPlusCentsPerHour': -1,
        'holidayPlusCentsPerHour': maxStoredMoneyCents + 1,
      }.entries) {
        expectRejected(
          (d) => _rebuild(
            d,
            shiftTypes: [
              for (final t in d.shiftTypes)
                BackupShiftType.fromJson({
                  ...t.toJson(),
                  extra.key: extra.value,
                }),
            ],
          ),
          extra.key,
        );
      }
      expectRejected(
        (d) => _rebuild(
          d,
          shiftTypes: [
            for (final t in d.shiftTypes)
              BackupShiftType.fromJson({
                ...t.toJson(),
                'location': 'x' * (maxShiftLocationLength + 1),
              }),
          ],
        ),
        'long place',
      );
      expectRejected(
        (d) => _rebuild(
          d,
          dayEntries: [
            for (final e in d.dayEntries)
              BackupDayEntry.fromJson({
                ...e.toJson(),
                'extraAmountCents': -maxStoredMoneyCents - 1,
              }),
          ],
        ),
        'extra amount',
      );
    });

    test('the most negative integer is not mistaken for a small amount', () {
      expectRejected(
        (d) => _rebuild(
          d,
          dayEntries: [
            for (final e in d.dayEntries)
              BackupDayEntry.fromJson({
                ...e.toJson(),
                'extraAmountCents': -9223372036854775807 - 1,
              }),
          ],
        ),
        '-2^63',
      );
    });

    test('paths that differ only in case would be one file on iOS', () {
      expectRejected(
        (d) => _rebuild(
          d,
          noteAttachments: [
            _attachment('a', _photo, path: 'main/Foto.jpg'),
            _attachment('b', _pdf, path: 'main/foto.JPG'),
          ],
        ),
        'case',
      );
      expectRejected(
        (d) => _rebuild(
          d,
          noteAttachments: [_attachment('a', _photo, path: 'main/a..b.jpg')],
        ),
        '.. inside a name',
      );
    });

    test('a v6 balance is whole units and not negative; a balance with only '
        'the three old keys keeps the old rule', () {
      for (final balance in [
        const BackupAbsenceBalance(
          year: 2027,
          type: 'x',
          allowedDays: -1,
          name: 'Vacaciones',
        ),
        const BackupAbsenceBalance(
          year: 2027,
          type: 'x',
          allowedDays: 2.5,
          calendarId: 'main',
        ),
        const BackupAbsenceBalance(
          year: 2027,
          type: 'x',
          allowedDays: 2.25,
          unit: AbsenceUnit.half,
        ),
      ]) {
        expectRejected(
          (d) => _rebuild(d, absenceBalances: [balance]),
          balance.toString(),
        );
      }
      for (final ok in [
        const BackupAbsenceBalance(year: 2025, type: 'old', allowedDays: 2.5),
        const BackupAbsenceBalance(year: 2025, type: 'neg', allowedDays: -1),
        const BackupAbsenceBalance(
          year: 2027,
          type: 'half',
          allowedDays: 2.5,
          unit: AbsenceUnit.half,
        ),
      ]) {
        _rebuild(_withV6(), absenceBalances: [ok]).validate();
      }
    });

    test('an old file that never had them is still valid', () {
      final old = codec.decode(
        File('test/fixtures/golden_backup/golden_v3.cuadrante')
            .readAsBytesSync(),
      );
      old.data.validate();
    });
  });

  group('container', () {
    test('a copy with attachments is a ZIP with the plain file and the '
        'bytes; it reads back the same and checks every file', () {
      final data = _withV6(withAttachments: true);
      final bytes = codec.encode(
        data,
        appVersion: 'test',
        exportedAt: at,
        attachmentFiles: _files,
      );
      expect(BackupContainer.looksLikeContainer(bytes), isTrue);
      final archive = ZipDecoder().decodeBytes(bytes);
      expect(
        [for (final f in archive.files) f.name],
        [
          BackupContainer.manifestName,
          BackupContainer.backupName,
          'attachments/att-pdf',
          'attachments/att-photo',
        ],
      );
      // The inner file is a normal plain `.turnly`.
      final inner = archive.find(BackupContainer.backupName)!.readBytes()!;
      expect(inner.take(2), [0x1f, 0x8b]);
      expect(readEnvelope(inner)['schemaVersion'], 3);

      final file = codec.decode(bytes);
      expect(file.data, data);
      expect(file.attachmentFiles.keys.toSet(), {'att-photo', 'att-pdf'});
      expect(file.attachmentFiles['att-photo'], _photo);
      expect(file.attachmentFiles['att-pdf'], _pdf);
      expect(BackupCodec.peekAppVersion(bytes), 'test');
      // Same input, same bytes.
      expect(
        codec.encode(
          data,
          appVersion: 'test',
          exportedAt: at,
          attachmentFiles: _files,
        ),
        bytes,
      );
    });

    Uint8List zip(Map<String, List<int>> entries, {bool compress = false}) {
      final archive = Archive();
      for (final e in entries.entries) {
        archive.add(
          compress
              ? ArchiveFile.bytes(e.key, e.value)
              : ArchiveFile.noCompress(e.key, e.value.length, e.value),
        );
      }
      return ZipEncoder().encodeBytes(archive);
    }

    Map<String, List<int>> goodEntries() {
      final data = _withV6(withAttachments: true);
      final bytes = codec.encode(
        data,
        appVersion: 'test',
        exportedAt: at,
        attachmentFiles: _files,
      );
      return {
        for (final f in ZipDecoder().decodeBytes(bytes).files)
          f.name: f.readBytes()!,
      };
    }

    test('a damaged, missing, compressed or unknown container is refused', () {
      final good = goodEntries();
      final flipped = [...good['attachments/att-photo']!];
      flipped[10] ^= 1;
      final tampered = Map.of(good)..['attachments/att-photo'] = flipped;
      expect(
        () => codec.decode(zip(tampered)),
        throwsA(isA<CorruptBackup>()),
        reason: 'a file that does not match its SHA-256',
      );
      final shorter = Map.of(good)..['attachments/att-pdf'] = [1, 2, 3];
      expect(() => codec.decode(zip(shorter)), throwsA(isA<CorruptBackup>()));
      final missing = Map.of(good)..remove('attachments/att-pdf');
      expect(() => codec.decode(zip(missing)), throwsA(isA<CorruptBackup>()));
      final noBackup = Map.of(good)..remove(BackupContainer.backupName);
      expect(() => codec.decode(zip(noBackup)), throwsA(isA<CorruptBackup>()));
      expect(
        () => codec.decode(zip(good, compress: true)),
        throwsA(isA<CorruptBackup>()),
        reason: 'only stored entries are read',
      );
      final noManifest = Map.of(good)..remove(BackupContainer.manifestName);
      expect(
        () => codec.decode(zip(noManifest)),
        throwsA(isA<NotACuadranteFile>()),
      );
      final otherZip = {'hello.txt': utf8.encode('hi')};
      expect(
        () => codec.decode(zip(otherZip)),
        throwsA(isA<NotACuadranteFile>()),
      );
      final newer = Map.of(good)
        ..[BackupContainer.manifestName] = utf8.encode(
          '{"format":"turnly-container","version":2}',
        );
      expect(
        () => codec.decode(zip(newer)),
        throwsA(isA<NewerFormatVersion>()),
      );
      final nested = Map.of(good)..[BackupContainer.backupName] = zip(good);
      expect(() => codec.decode(zip(nested)), throwsA(isA<CorruptBackup>()));
      // A cut file.
      final whole = zip(good);
      expect(
        () => codec.decode(Uint8List.sublistView(whole, 0, whole.length - 30)),
        throwsA(isA<BackupException>()),
      );
    });

    test('a hand-made ZIP with the real entries is read (the layout '
        'checks accept it)', () {
      final good = goodEntries();
      final names = good.keys.toList();
      final bytes = _rawZip(
        [for (final n in names) (n, good[n]!)],
        [for (final (i, n) in names.indexed) (n, i)],
      );
      expect(codec.decode(bytes).attachmentFiles, hasLength(2));
    });

    test('directory records that share the bytes of one entry are refused '
        'before reading anything', () {
      final good = goodEntries();
      final names = good.keys.toList();
      final photo = names.indexOf('attachments/att-photo');
      final manifest = names.indexOf(BackupContainer.manifestName);
      final locals = [for (final n in names) (n, good[n]!)];
      final central = [for (final (i, n) in names.indexed) (n, i)];
      // One more name over the (small) manifest: the sizes still fit in the
      // file, the overlap is what gives it away.
      expect(
        () => codec.decode(
          _rawZip(locals, [...central, ('attachments/extra', manifest)]),
        ),
        throwsA(
          isA<CorruptBackup>().having(
            (e) => e.message,
            'message',
            contains('Overlapping'),
          ),
        ),
      );
      // Thousands of names over the same photo: refused by the sizes before
      // even sorting the ranges, and never hashed.
      expect(
        () => codec.decode(
          _rawZip(locals, [
            ...central,
            for (var i = 0; i < 1900; i++) ('attachments/copy-$i', photo),
          ]),
        ),
        throwsA(
          isA<CorruptBackup>().having(
            (e) => e.message,
            'message',
            anyOf(contains('Overlapping'), contains('larger than the file')),
          ),
        ),
      );
    });

    test('two entries with the same name are refused (archive would keep '
        'the first one silently)', () {
      final good = goodEntries();
      final names = good.keys.toList();
      final other = goodEntries()
        ..[BackupContainer.backupName] = gzipEnvelope(
          readEnvelope(Uint8List.fromList(good[BackupContainer.backupName]!)),
        );
      final bytes = _rawZip(
        [
          for (final n in names) (n, good[n]!),
          (BackupContainer.backupName, other[BackupContainer.backupName]!),
        ],
        [
          for (final (i, n) in names.indexed) (n, i),
          (BackupContainer.backupName, names.length),
        ],
      );
      expect(
        () => codec.decode(bytes),
        throwsA(
          isA<CorruptBackup>().having(
            (e) => e.message,
            'message',
            contains('Repeated entry'),
          ),
        ),
      );
    });

    test('attachments that claim more bytes than the file are refused', () {
      final data = _rebuild(
        _withV6(),
        noteAttachments: [
          BackupNoteAttachment(
            id: 'att-big',
            calendarId: 'main',
            date: const CivilDate(2026, 3, 12),
            kind: AttachmentKind.file,
            relativePath: 'ff/${'f' * 64}',
            mimeType: 'application/octet-stream',
            sizeBytes: 40 * 1024 * 1024,
            sha256: 'f' * 64,
            createdAt: 1,
          ),
        ],
      );
      final inner = gzipEnvelope({
        'appVersion': 'test',
        'checksum': BackupCodec.checksumOf(data),
        'data': data.toJson(),
        'exportedAt': '2026-11-01T00:00:00Z',
        'format': 'cuadrante',
        'schemaVersion': 3,
      });
      final bytes = _rawZip(
        [
          (
            BackupContainer.manifestName,
            utf8.encode('{"format":"turnly-container","version":1}'),
          ),
          (BackupContainer.backupName, inner),
          ('attachments/att-big', [1, 2, 3]),
        ],
        [
          (BackupContainer.manifestName, 0),
          (BackupContainer.backupName, 1),
          ('attachments/att-big', 2),
        ],
      );
      expect(
        () => codec.decode(bytes),
        throwsA(
          isA<CorruptBackup>().having(
            (e) => e.message,
            'message',
            contains('larger than the file'),
          ),
        ),
      );
    });

    test('an entry nobody lists is ignored', () {
      final extra = goodEntries()..['attachments/stray'] = [1, 2, 3];
      final archive = Archive();
      for (final e in extra.entries) {
        archive.add(ArchiveFile.noCompress(e.key, e.value.length, e.value));
      }
      final file = codec.decode(ZipEncoder().encodeBytes(archive));
      expect(file.attachmentFiles.keys, isNot(contains('stray')));
    });

    test('a plain file that lists attachments is refused: their files '
        'would be missing', () {
      final data = _withV6(withAttachments: true);
      final env = readEnvelope(
        codec
            .encode(
              data,
              appVersion: 'test',
              exportedAt: at,
              attachmentFiles: _files,
            )
            .let(
              (b) => ZipDecoder()
                  .decodeBytes(b)
                  .find(BackupContainer.backupName)!
                  .readBytes()!,
            ),
      );
      expect(
        () => codec.decode(gzipEnvelope(env)),
        throwsA(isA<CorruptBackup>()),
      );
    });

    test('writing refuses an attachment without its file or with another '
        'one, and files without rows', () {
      final data = _withV6(withAttachments: true);
      expect(
        () => codec.encode(data, appVersion: 'test', exportedAt: at),
        throwsA(isA<CorruptBackup>()),
      );
      expect(
        () => codec.encode(
          data,
          appVersion: 'test',
          exportedAt: at,
          attachmentFiles: {..._files, 'att-pdf': _photo},
        ),
        throwsA(isA<CorruptBackup>()),
      );
      expect(
        () => codec.encode(
          _withV6(),
          appVersion: 'test',
          exportedAt: at,
          attachmentFiles: _files,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('«Probar restauración» checks a container; restoring one needs the '
        'files of its attachments', () async {
      final repo = makeRepository(db, dir);
      final data = _withV6(withAttachments: true);
      final bytes = codec.encode(
        data,
        appVersion: 'test',
        exportedAt: at,
        attachmentFiles: _files,
      );
      final result = await repo.verifyRestore(
        bytes,
        today: const CivilDate(2026, 11, 1),
      );
      expect(result, isA<VerificationPassed>());
      final before = await dumpAllTables(db);
      // Without the files of the attachments the restore does not start: the
      // rows would point at files that are not there.
      await expectLater(repo.restore(data), throwsA(isA<CorruptBackup>()));
      expect(await dumpAllTables(db), before);
      expect(fileNames(dir), isEmpty, reason: 'not even a safety copy');
    });
  });
}

BackupData _rebuild(
  BackupData d, {
  List<BackupShiftType>? shiftTypes,
  List<BackupDayEntry>? dayEntries,
  List<BackupAbsenceBalance>? absenceBalances,
  List<BackupNoteAttachment>? noteAttachments,
  List<BackupDayTask>? dayTasks,
  List<BackupShiftSwap>? shiftSwaps,
}) => BackupData(
  calendars: d.calendars,
  shiftTypes: shiftTypes ?? d.shiftTypes,
  patterns: d.patterns,
  patternRuns: d.patternRuns,
  dayEntries: dayEntries ?? d.dayEntries,
  holidays: d.holidays,
  absenceBalances: absenceBalances ?? d.absenceBalances,
  settings: d.settings,
  noteAttachments: noteAttachments ?? d.noteAttachments,
  dayTasks: dayTasks ?? d.dayTasks,
  shiftSwaps: shiftSwaps ?? d.shiftSwaps,
);

extension on DayEntry {
  DayEntry withoutExtra() => copyWith(clearExtraAmount: true);
}

/// A ZIP written by hand: [locals] are stored one after the other (name,
/// bytes) and [central] lists (name, index of the local entry it points to),
/// so a test can make two records share bytes or two names repeat.
Uint8List _rawZip(
  List<(String, List<int>)> locals,
  List<(String, int)> central,
) {
  final out = BytesBuilder();
  void u16(int v) => out.add([v & 0xff, v >> 8 & 0xff]);
  void u32(int v) =>
      out.add([v & 0xff, v >> 8 & 0xff, v >> 16 & 0xff, v >> 24 & 0xff]);
  final offsets = <int>[];
  for (final (name, data) in locals) {
    offsets.add(out.length);
    final n = utf8.encode(name);
    u32(0x04034b50);
    u16(20);
    u16(0);
    u16(0);
    u16(0);
    u16(0);
    u32(getCrc32(data));
    u32(data.length);
    u32(data.length);
    u16(n.length);
    u16(0);
    out.add(n);
    out.add(data);
  }
  final cdStart = out.length;
  for (final (name, index) in central) {
    final data = locals[index].$2;
    final n = utf8.encode(name);
    u32(0x02014b50);
    u16(20);
    u16(20);
    u16(0);
    u16(0);
    u16(0);
    u16(0);
    u32(getCrc32(data));
    u32(data.length);
    u32(data.length);
    u16(n.length);
    u16(0);
    u16(0);
    u16(0);
    u16(0);
    u32(0);
    u32(offsets[index]);
    out.add(n);
  }
  final cdSize = out.length - cdStart;
  u32(0x06054b50);
  u16(0);
  u16(0);
  u16(central.length);
  u16(central.length);
  u32(cdSize);
  u32(cdStart);
  u16(0);
  return out.takeBytes();
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
