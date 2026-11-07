import 'dart:convert';
import 'dart:io';

import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/features/alarms/data/alarm_settings_repository.dart';
import 'package:cuadrante/features/alarms/domain/alarm_settings.dart';
import 'package:cuadrante/features/backup/domain/backup_codec.dart';
import 'package:cuadrante/features/backup/domain/backup_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'backup_test_support.dart';
import 'golden_dataset.dart';

// The pause notice of a shift type («Aviso de pausa», docs/alarmas.md) lives
// inside the `alarms` row of the `settings` table, so it travels in the backup
// with the rest of the alarm settings: this checks the whole trip, file
// included.

const _settings = AlarmSettings(
  enabled: true,
  byShiftType: {
    'night': AlarmTypeSettings(
      enabled: true,
      minutesBefore: 60,
      pause: PauseAlertSettings(enabled: true),
    ),
    'morning': AlarmTypeSettings(
      pause: PauseAlertSettings(
        enabled: true,
        timing: PauseTiming.afterStart,
        afterMinutes: 195,
      ),
    ),
    // Turned off again after being set: the choice of "when" is kept.
    'afternoon': AlarmTypeSettings(
      pause: PauseAlertSettings(
        timing: PauseTiming.afterStart,
        afterMinutes: 90,
      ),
    ),
  },
);

void main() {
  const codec = BackupCodec();
  late AppDatabase db;
  late Directory dir;

  setUp(() {
    db = openMemoryDatabase();
    addTearDown(db.close);
    dir = makeTempDir('pause-alert-backup');
  });

  BackupData withAlarms(AlarmSettings settings) {
    final golden = buildGoldenBackupData();
    return BackupData.fromJson({
      ...golden.toJson(),
      'settings': {
        ...golden.settings,
        alarmSettingsKey: jsonEncode(settings.toJson()),
      },
    });
  }

  test('database -> file -> fresh database gives back the same pause '
      'notices', () async {
    final data = withAlarms(_settings);
    final repo = makeRepository(db, dir);
    await repo.restore(data);
    expect(await AlarmSettingsRepository(db).load(), _settings);

    // Out to a file and back, through the codec.
    final bytes = codec.encode(
      await repo.readAll(),
      appVersion: testAppVersion,
      exportedAt: DateTime.utc(2026, 11, 6),
    );
    final decoded = codec.decode(bytes);
    final other = openMemoryDatabase();
    addTearDown(other.close);
    final otherRepo = makeRepository(other, Directory('${dir.path}/other'));
    await otherRepo.restore(decoded.data);

    final restored = await AlarmSettingsRepository(other).load();
    expect(restored, _settings);
    expect(restored.forShiftType('night').pause.enabled, isTrue);
    expect(
      restored.forShiftType('morning').pause,
      const PauseAlertSettings(
        enabled: true,
        timing: PauseTiming.afterStart,
        afterMinutes: 195,
      ),
    );
    expect(restored.forShiftType('afternoon').pause.enabled, isFalse);
    expect(restored.forShiftType('afternoon').pause.afterMinutes, 90);

    // And exporting what was restored gives the very same file.
    final again = codec.encode(
      await otherRepo.readAll(),
      appVersion: testAppVersion,
      exportedAt: DateTime.utc(2026, 11, 6),
    );
    expect(again, bytes);
  });

  test('a backup written before the pause notice restores with it off, and '
      'replaces what the phone had', () async {
    final repo = makeRepository(db, dir);
    await repo.restore(withAlarms(_settings));
    expect(
      (await AlarmSettingsRepository(
        db,
      ).load()).forShiftType('night').pause.enabled,
      isTrue,
    );

    // The old golden file has an `alarms` row of an older shape.
    await repo.restore(buildGoldenBackupData());
    final after = await AlarmSettingsRepository(db).load();
    expect(after.byShiftType.values.every((t) => !t.pause.enabled), isTrue);
  });

  test('a file whose pause entry is damaged still restores', () async {
    final data = BackupData.fromJson({
      ...buildGoldenBackupData().toJson(),
      'settings': {
        ...buildGoldenBackupData().settings,
        alarmSettingsKey:
            '{"version":2,"enabled":true,"types":{"night":{"enabled":true,'
            '"pause":{"enabled":"si","timing":7,"afterMinutes":"tres"}}}}',
      },
    });
    await makeRepository(db, dir).restore(data);
    final loaded = await AlarmSettingsRepository(db).load();
    expect(loaded.forShiftType('night').enabled, isTrue);
    expect(loaded.forShiftType('night').pause, PauseAlertSettings.off);
  });

  test('the row of the settings is a plain JSON text with the pause under '
      'its type', () {
    final json = jsonDecode(jsonEncode(_settings.toJson())) as Map;
    final types = json['types'] as Map;
    expect((types['morning'] as Map)['pause'], {
      'enabled': true,
      'timing': 'after',
      'afterMinutes': 195,
    });
    // A type that never touched it does not carry the key at all.
    expect(
      const AlarmSettings(byShiftType: {'x': AlarmTypeSettings(enabled: true)})
          .toJson()['types'],
      {
        'x': {
          'enabled': true,
          'minutesBefore': 90,
          'dayBefore': false,
          'dayBeforeMinute': 1200,
        },
      },
    );
  });
}
