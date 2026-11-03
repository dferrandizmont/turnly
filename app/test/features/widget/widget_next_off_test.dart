import 'dart:convert';

import 'package:cuadrante/core/bootstrap/bootstrap.dart' show initializeLocale;
import 'package:cuadrante/features/holidays/domain/holiday.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/widget/domain/widget_snapshot.dart';
import 'package:cuadrante/features/widget/domain/widget_snapshot_builder.dart';
import 'package:cuadrante/features/widget/domain/widget_strings.dart';
import 'package:cuadrante/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../schedule/domain/fixtures.dart';

/// The optional `nextOff` extension of the snapshot (C1,
/// `docs/widget-contrato.md`): for each day of the timeline, the next day off
/// seen from it.
void main() {
  setUpAll(initializeLocale);

  const first = CivilDate(2026, 10, 19); // Monday

  // Mon 19 - Wed 21 night, Thu 22 rest, Fri 23 vacation, Sat 24 - Sun 25
  // nothing annotated but work after it, Mon 26 morning, then nothing.
  Schedule schedule() => Schedule(
    shiftTypes: allTypes,
    entries: {
      for (var i = 0; i < 3; i++)
        first.addDays(i): DayEntry(
          date: first.addDays(i),
          shiftTypeIds: const ['night'],
        ),
      first.addDays(3): DayEntry(
        date: first.addDays(3),
        shiftTypeIds: const ['rest'],
      ),
      first.addDays(4): DayEntry(
        date: first.addDays(4),
        shiftTypeIds: const ['vacation'],
      ),
      first.addDays(7): DayEntry(
        date: first.addDays(7),
        shiftTypeIds: const ['morning'],
      ),
    },
  );

  WidgetSnapshot build({
    Schedule? from,
    WidgetStrings strings = WidgetStrings.es,
    int days = 10,
  }) => buildWidgetSnapshot(
    schedule: from ?? schedule(),
    holidays: const <CivilDate, Holiday>{},
    today: first,
    timeZone: 'Europe/Madrid',
    strings: strings,
    days: days,
    generatedAt: DateTime.utc(2026, 10, 19, 8),
  );

  test('each day gets the next day off seen from it', () {
    final next = build().nextOff!;
    expect(next['2026-10-19']!.date, '2026-10-22');
    expect(next['2026-10-19']!.label, 'Libras el jueves 22');
    expect(next['2026-10-21']!.label, 'Mañana libras');
    // On the rest day itself, and when work resumes.
    expect(next['2026-10-22']!.date, '2026-10-22');
    expect(next['2026-10-22']!.label, 'Hoy libras; vuelves el lunes 26');
    // A vacation day is a day off as well.
    expect(next['2026-10-23']!.label, 'Hoy libras; vuelves el lunes 26');
    // A gap between annotated days is taken as off; the Monday is work and
    // nothing is annotated after it, so no next day off from there.
    expect(next['2026-10-24']!.date, '2026-10-24');
    expect(next['2026-10-26'], isNull);
    expect(next['2026-10-27'], isNull);
  });

  test('the absence is never named: no vacation, no kind', () {
    final text = jsonEncode(build().toJson()['nextOff']);
    expect(text, isNot(contains('Vacaciones')));
    expect(text, isNot(contains('absence')));
    expect(text, isNot(contains('baja')));
  });

  test('without any annotated day the extension is absent', () {
    final snapshot = build(from: Schedule(shiftTypes: allTypes));
    expect(snapshot.nextOff, isNull);
    expect(snapshot.toJson().containsKey('nextOff'), isFalse);
  });

  test('it survives encode and decode, and is part of the hash', () {
    final snapshot = build();
    final decoded = WidgetSnapshot.decode(snapshot.encode());
    expect(decoded.nextOff!.keys, snapshot.nextOff!.keys);
    expect(
      decoded.nextOff!['2026-10-19']!.label,
      snapshot.nextOff!['2026-10-19']!.label,
    );
    expect(decoded.contentHash, snapshot.contentHash);
    expect(decoded.computeContentHash(), snapshot.contentHash);
    final without = WidgetSnapshot.decode(
      jsonEncode(
        (jsonDecode(snapshot.encode()) as Map<String, Object?>)
          ..remove('nextOff'),
      ),
    );
    expect(without.nextOff, isNull, reason: 'older snapshots still decode');
    expect(without.computeContentHash(), isNot(snapshot.contentHash));
  });

  test('a v1 snapshot (no extension, no displayDays) still decodes', () {
    final snapshot = build();
    final json = jsonDecode(snapshot.encode()) as Map<String, Object?>
      ..['v'] = 1
      ..remove('nextOff')
      ..remove('displayDays')
      ..remove('noShift');
    final decoded = WidgetSnapshot.decode(jsonEncode(json));
    expect(decoded.version, 1);
    expect(decoded.nextOff, isNull);
  });

  test('the same schedule always gives the same extension', () {
    expect(build().contentHash, build().contentHash);
    expect(
      jsonEncode(build().toJson()['nextOff']),
      jsonEncode(build().toJson()['nextOff']),
    );
  });

  test('it does not grow the spoken descriptions or the days', () {
    final snapshot = build();
    // Timeline (10) + the Monday-to-28-days auxiliary range (UW: four weeks).
    expect(snapshot.days, hasLength(10));
    final lastExpected = first.addDays(9 + 27);
    for (final key in snapshot.descriptions!.days.keys) {
      expect(
        CivilDate.parse(key).isAfter(lastExpected),
        isFalse,
        reason: '$key is past the auxiliary range',
      );
    }
  });

  test('the full 60-day timeline adds only a few KB and stays under limit', () {
    final snapshot = build(days: kWidgetDays);
    expect(snapshot.nextOff, isNotNull);
    final body = snapshot.toJson();
    final extension = utf8.encode(jsonEncode(body['nextOff'])).length;
    expect(extension, lessThan(10 * 1024));
    expect(
      utf8.encode(snapshot.encode()).length,
      lessThan(kWidgetSnapshotMaxBytes),
    );
  });

  for (final locale in ['es', 'ca', 'gl', 'eu', 'en']) {
    test('labels in $locale', () {
      final l10n = lookupAppLocalizations(Locale(locale));
      final snapshot = build(strings: WidgetStrings.fromL10n(l10n));
      final next = snapshot.nextOff!;
      expect(next['2026-10-21']!.label, l10n.offTomorrow);
      expect(
        next['2026-10-22']!.label,
        startsWith(l10n.offToday.split(';').first),
      );
      expect(next['2026-10-19']!.label, contains('22'));
      for (final entry in next.values) {
        expect(entry.label, isNot(contains('{')));
      }
    });
  }
}
