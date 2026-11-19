import 'dart:io';

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

void main() {
  setUpAll(initializeLocale);
  const today = CivilDate(2026, 10, 19);
  const tomorrow = CivilDate(2026, 10, 20);

  WidgetSnapshot build(String locale) => buildWidgetSnapshot(
    schedule: Schedule(
      shiftTypes: allTypes,
      entries: {
        today: DayEntry(
          date: today,
          shiftTypeIds: const ['morning', 'night'],
          note: 'NOTA_DEL_DIA',
        ),
        tomorrow: DayEntry(
          date: tomorrow,
          shiftTypeIds: const ['vacation'],
          note: 'PRIVATE_HEALTH_NOTE',
        ),
      },
    ),
    holidays: {
      today: Holiday(date: today, name: 'Fiesta', scope: HolidayScope.national),
    },
    today: today,
    timeZone: 'Europe/Madrid',
    strings: WidgetStrings.fromL10n(lookupAppLocalizations(Locale(locale))),
    generatedAt: DateTime.utc(2026, 10, 19),
  );

  for (final locale in ['es', 'ca', 'gl', 'eu', 'en']) {
    test('complete descriptions and localized states in $locale', () {
      final snapshot = build(locale);
      final l10n = lookupAppLocalizations(Locale(locale));
      final descriptions = snapshot.descriptions!;
      final label = descriptions.days[today.toIso()]!;
      expect(label, contains('2026'));
      expect(label, contains('19'));
      expect(
        label,
        contains(l10n.daySemanticsShift('Mañana', '06:00', '14:00')),
      );
      expect(
        label,
        contains(l10n.daySemanticsShift('Noche', '22:00', '06:00')),
      );
      expect(label, contains(l10n.daySemanticsNote));
      expect(label, contains(l10n.daySemanticsHoliday('Fiesta')));
      expect(descriptions.today, l10n.daySemanticsToday);
      expect(
        descriptions.days[today.addDays(2).toIso()],
        contains(l10n.calendarNoShift),
      );
      final redacted = descriptions.absences[tomorrow.toIso()]!;
      expect(redacted, contains(l10n.shiftTypesCategoryAbsence));
      expect(redacted, isNot(contains('Vacaciones')));
      expect(redacted, isNot(contains(l10n.daySemanticsNote)));
      final encoded = snapshot.encode();
      // A normal note's first line travels in the optional `notes` extension
      // for the four-week widget, but it never enters the spoken descriptions,
      // and a health-day note leaves the phone in no shape at all.
      expect(snapshot.notes!['2026-10-19'], 'NOTA_DEL_DIA');
      expect(label, isNot(contains('NOTA_DEL_DIA')));
      expect(encoded, isNot(contains('PRIVATE_HEALTH_NOTE')));
      expect(encoded, isNot(contains('PRIVATE_')));
      final decoded = WidgetSnapshot.decode(encoded);
      expect(decoded.descriptions!.toJson(), descriptions.toJson());
      expect(decoded.computeContentHash(), snapshot.contentHash);
      // Every actionable date, including neighboring months and the day-60 strip,
      // has a shared complete description, independent of the current native day.
      for (final day in snapshot.days) {
        for (final cell in day.medium.cells) {
          expect(descriptions.days, contains(cell.date));
        }
      }
      for (final month in snapshot.months) {
        for (final cell in month.cells) {
          expect(descriptions.days, contains(cell.date));
        }
      }
    });
  }

  for (final locale in ['es', 'ca', 'gl', 'eu', 'en']) {
    test(
      'the spoken tomorrow names the shifts, not their codes, in $locale',
      () {
        final snapshot = WidgetSnapshot.decode(build(locale).encode());
        final l10n = lookupAppLocalizations(Locale(locale));
        final tomorrows = snapshot.descriptions!.tomorrow;
        // One line for every day of the timeline, keyed by the day it follows.
        for (final day in snapshot.days) {
          expect(tomorrows, contains(day.date));
        }
        // The day after today is a vacation (no times): its name.
        final line = tomorrows[today.toIso()]!;
        expect(
          line,
          startsWith(
            '${snapshot.days.first.small.tomorrow.split(':').first}: ',
          ),
        );
        expect(line, contains('Vacaciones'));
        // The day after tomorrow has no shift.
        expect(tomorrows[tomorrow.toIso()], endsWith(l10n.calendarNoShift));
        // The visible line keeps its codes; only the spoken one changes.
        expect(snapshot.days.first.small.tomorrow, isNot(equals(line)));
      },
    );
  }

  test('a tomorrow with times is spoken with names and hours', () {
    final snapshot = buildWidgetSnapshot(
      schedule: Schedule(
        shiftTypes: allTypes,
        entries: {
          tomorrow: DayEntry(
            date: tomorrow,
            shiftTypeIds: const ['morning', 'night'],
          ),
        },
      ),
      holidays: const {},
      today: today,
      timeZone: 'Europe/Madrid',
      strings: WidgetStrings.fromL10n(
        lookupAppLocalizations(const Locale('en')),
      ),
      generatedAt: DateTime.utc(2026, 10, 19),
    );
    final l10n = lookupAppLocalizations(const Locale('en'));
    final line = snapshot.descriptions!.tomorrow[today.toIso()]!;
    expect(line, contains(l10n.daySemanticsShift('Mañana', '06:00', '14:00')));
    expect(line, contains(l10n.daySemanticsShift('Noche', '22:00', '06:00')));
    expect(line, startsWith(l10n.widgetTomorrow));
  });

  test('a v3 snapshot written before the tomorrow lines keeps its hash', () {
    // Historical bytes (the Kotlin fixture of 5e14366d): it has
    // `descriptions` but no `tomorrow`.
    const path = 'test/fixtures/widget/snapshot_v3_before_tomorrow.json';
    const hash =
        '488ca84bb11c3bf8dc32bf4364b39d40e2c9cd99e6fb2150c7d1c00fd2cc9bb5';
    final raw = File(path).readAsStringSync();
    final decoded = WidgetSnapshot.decode(raw);
    expect(decoded.descriptions, isNotNull);
    expect(decoded.descriptions!.tomorrow, isEmpty);
    expect(decoded.contentHash, hash);
    expect(decoded.computeContentHash(), hash);
    expect(
      decoded.toJson()['descriptions'] as Map,
      isNot(contains('tomorrow')),
    );
    expect(WidgetSnapshot.decode(decoded.encode()).computeContentHash(), hash);

    // An explicit empty map canonicalizes as the absent key.
    final body = decoded.toJson();
    (body['descriptions'] as Map)['tomorrow'] = <String, String>{};
    final explicit = WidgetSnapshot.fromJson(body);
    expect(explicit.descriptions!.tomorrow, isEmpty);
    expect(explicit.computeContentHash(), hash);
    expect(
      explicit.toJson()['descriptions'] as Map,
      isNot(contains('tomorrow')),
    );
  });

  test('old v1 and v2 JSON without descriptions remain readable with stable hashes', () {
    // Historical bytes, not a new builder output with a field removed.
    // v2 is the Android fixture from 2d8cc9a^ (before descriptions).
    const fixtures = {
      1: (
        'android/app/src/test/resources/widget_snapshot_v1.json',
        '2aed5b1c441a181edbdc3a5c9cb6fae72870c68722554a35633faebc86cdc16f',
      ),
      2: (
        'test/fixtures/widget/snapshot_v2_before_descriptions.json',
        '767dced93f1b646ed791d68596165ca39ad1d2932ae10e3edf800bf58a560e1b',
      ),
    };
    for (final MapEntry(key: version, value: (path, hash))
        in fixtures.entries) {
      final decoded = WidgetSnapshot.decode(File(path).readAsStringSync());
      expect(decoded.descriptions, isNull);
      expect(decoded.days.first.date, today.toIso());
      expect(decoded.version, version);
      expect(decoded.contentHash, hash);
      expect(decoded.computeContentHash(), hash);
      expect(
        WidgetSnapshot.decode(decoded.encode()).computeContentHash(),
        hash,
      );
      expect(decoded.toJson().containsKey('descriptions'), isFalse);
    }
  });

  test('descriptions contribute to contentHash', () {
    final original = build('es');
    final body = original.toJson();
    (body['descriptions'] as Map)['today'] = 'changed';
    final changed = WidgetSnapshot.fromJson(body);
    expect(changed.computeContentHash(), isNot(original.computeContentHash()));
  });
}
