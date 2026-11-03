import 'package:cuadrante/core/bootstrap/bootstrap.dart' show initializeLocale;
import 'package:cuadrante/core/format/app_date_format.dart';
import 'package:cuadrante/features/calendar/application/off_outlook.dart';
import 'package:cuadrante/features/calendar/presentation/off_outlook_text.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _today = CivilDate(2026, 10, 19); // Monday

OffOutlook _outlook({
  NextOff? nextOff,
  CivilDate? returnDate,
  FreeWeekend? weekend,
  int streak = 0,
  int? left,
}) => OffOutlook(
  today: _today,
  todayKind: streak > 0 ? DayKind.work : DayKind.rest,
  nextOff: nextOff,
  returnDate: returnDate,
  freeWeekend: weekend,
  workedStreak: streak,
  workDaysLeft: left,
);

NextOff _off(int daysAway) => NextOff(
  date: _today.addDays(daysAway),
  kind: DayKind.rest,
  daysAway: daysAway,
  inferred: false,
);

void main() {
  setUpAll(initializeLocale);

  AppLocalizations l10nOf(String l) => lookupAppLocalizations(Locale(l));

  group('es', () {
    final l10n = l10nOf('es');
    const format = AppDateFormat('es');

    test('the four ways of saying the next day off', () {
      expect(
        nextOffText(l10n, format, _outlook(nextOff: _off(3))),
        'Libras el jueves 22',
      );
      expect(
        nextOffText(l10n, format, _outlook(nextOff: _off(1))),
        'Mañana libras',
      );
      expect(
        nextOffText(l10n, format, _outlook(nextOff: _off(0))),
        'Hoy libras',
      );
      expect(
        nextOffText(
          l10n,
          format,
          _outlook(nextOff: _off(0), returnDate: _today.addDays(6)),
        ),
        'Hoy libras; vuelves el domingo 25',
      );
    });

    test('nothing to say without a next day off', () {
      expect(nextOffText(l10n, format, _outlook()), isNull);
      expect(freeWeekendText(l10n, format, _outlook()), isNull);
      expect(streakText(l10n, _outlook()), isNull);
    });

    test('the free weekend, in one month and across two', () {
      expect(
        freeWeekendText(
          l10n,
          format,
          _outlook(
            weekend: const FreeWeekend(
              saturday: CivilDate(2026, 11, 14),
              sunday: CivilDate(2026, 11, 15),
            ),
          ),
        ),
        'Fin de semana libre: 14–15 nov',
      );
      expect(
        freeWeekendText(
          l10n,
          format,
          _outlook(
            weekend: const FreeWeekend(
              saturday: CivilDate(2026, 10, 31),
              sunday: CivilDate(2026, 11, 1),
            ),
          ),
        ),
        'Fin de semana libre: 31 oct – 1 nov',
      );
    });

    test('the streak shows from three days, with the days left', () {
      expect(streakText(l10n, _outlook(streak: 2, left: 3)), isNull);
      expect(
        streakText(l10n, _outlook(streak: 3, left: 4)),
        'Llevas 3 días seguidos; te quedan 4',
      );
      expect(
        streakText(l10n, _outlook(streak: 5, left: 1)),
        'Llevas 5 días seguidos; te queda 1',
      );
      expect(
        streakText(l10n, _outlook(streak: 5, left: 0)),
        'Llevas 5 días seguidos',
      );
      expect(streakText(l10n, _outlook(streak: 5)), 'Llevas 5 días seguidos');
    });
  });

  test('the weekend range follows the month-first order of en and eu', () {
    const weekend = FreeWeekend(
      saturday: CivilDate(2026, 11, 14),
      sunday: CivilDate(2026, 11, 15),
    );
    const across = FreeWeekend(
      saturday: CivilDate(2026, 10, 31),
      sunday: CivilDate(2026, 11, 1),
    );
    expect(weekendRange(const AppDateFormat('en'), weekend), 'Nov 14–15');
    expect(weekendRange(const AppDateFormat('en'), across), 'Oct 31 – Nov 1');
    expect(weekendRange(const AppDateFormat('eu'), weekend), 'aza 14–15');
    expect(weekendRange(const AppDateFormat('ca'), weekend), '14–15 nov');
  });

  for (final locale in ['es', 'ca', 'gl', 'eu', 'en']) {
    test('every text is complete in $locale', () {
      final l10n = l10nOf(locale);
      final format = AppDateFormat(locale);
      final outlook = _outlook(
        nextOff: _off(3),
        returnDate: _today.addDays(6),
        weekend: const FreeWeekend(
          saturday: CivilDate(2026, 11, 14),
          sunday: CivilDate(2026, 11, 15),
        ),
        streak: 4,
        left: 2,
      );
      final texts = [
        nextOffText(l10n, format, outlook),
        nextOffText(l10n, format, _outlook(nextOff: _off(1))),
        nextOffText(l10n, format, _outlook(nextOff: _off(0))),
        nextOffText(
          l10n,
          format,
          _outlook(nextOff: _off(0), returnDate: _today.addDays(6)),
        ),
        freeWeekendText(l10n, format, outlook),
        streakText(l10n, outlook),
        streakText(l10n, _outlook(streak: 4, left: 1)),
        streakText(l10n, _outlook(streak: 4)),
      ];
      for (final text in texts) {
        expect(text, isNotNull);
        expect(text, isNotEmpty);
        expect(text, isNot(contains('{')), reason: text);
        expect(text, isNot(contains('}')), reason: text);
      }
      // The date, or the number, reaches the text.
      expect(texts[0], contains('22'));
      expect(texts[3], contains('25'));
      expect(texts[4], contains('14'));
      expect(texts[5], allOf(contains('4'), contains('2')));
    });
  }
}
