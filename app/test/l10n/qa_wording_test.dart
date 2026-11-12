import 'dart:convert';
import 'dart:io';

import 'package:cuadrante/l10n/app_localizations.dart';
import 'package:cuadrante/core/format/app_date_format.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wording decided after the QA campaigns T17 and T21.
void main() {
  const languages = ['es', 'ca', 'gl', 'eu', 'en'];
  AppLocalizations l10nOf(String code) => lookupAppLocalizations(Locale(code));

  test('planned hours end date reads naturally in eu, ca and gl', () {
    final end = DateTime(2026, 11, 30);
    for (final (locale, expected) in [
      ('eu', 'eta 104 h aurreikusita azaroaren 30era arte'),
      ('ca', 'i 104 h previstes fins al dl 30 nov'),
      ('gl', 'e 104 h previstas ata o luns 30 nov'),
    ]) {
      expect(
        l10nOf(locale).summaryHowPlannedRest(
          '104 h',
          AppDateFormat(locale).plannedUntilDate(end),
        ),
        expected,
      );
    }
    // The ending follows the spoken numeral, rather than a fixed suffix.
    const endings = [
      '1era',
      '2ra',
      '3ra',
      '4ra',
      '5era',
      '6ra',
      '7ra',
      '8ra',
      '9ra',
      '10era',
      '11ra',
      '12ra',
      '13ra',
      '14ra',
      '15era',
      '16ra',
      '17ra',
      '18ra',
      '19ra',
      '20ra',
      '21era',
      '22ra',
      '23ra',
      '24ra',
      '25era',
      '26ra',
      '27ra',
      '28ra',
      '29ra',
      '30era',
      '31ra',
    ];
    for (var day = 1; day <= 31; day++) {
      expect(
        const AppDateFormat('eu_ES').plannedUntilDate(DateTime(2026, 10, day)),
        'urriaren ${endings[day - 1]}',
      );
    }
  });

  test('month strip hours left read correctly with one or several hours', () {
    const wording = {
      'es': 'Por completar: {hours}',
      'ca': 'Per completar: {hours}',
      'gl': 'Por completar: {hours}',
      'eu': 'Falta dena: {hours}',
      'en': '{hours} to go',
    };
    for (final code in languages) {
      for (final hours in ['1 h', '2 h']) {
        expect(
          l10nOf(code).monthStripShort(hours),
          wording[code]!.replaceAll('{hours}', hours),
          reason: code,
        );
      }
    }
  });

  test('day detail calls the source a rotation in every language', () {
    const wording = {
      'es': ('Volver a la rotación', 'Según tu rotación: N'),
      'ca': ('Torna a la rotació', 'Segons la teva rotació: N'),
      'gl': ('Volver á rotación', 'Segundo a túa rotación: N'),
      'eu': ('Itzuli txandaketara', 'Zure txandaketaren arabera: N'),
      'en': ('Back to the rotation', 'According to your rotation: N'),
    };
    for (final code in languages) {
      final l10n = l10nOf(code);
      expect(l10n.dayDetailReset, wording[code]!.$1, reason: code);
      expect(l10n.selectionReset, wording[code]!.$1, reason: code);
      expect(l10n.dayDetailPatternGives('N'), wording[code]!.$2, reason: code);
    }
  });

  test('H-T17-5: the Settings row and its screen have the same title', () {
    for (final code in languages) {
      final l10n = l10nOf(code);
      expect(l10n.calExportRowTitle, l10n.calExportTitle, reason: code);
      expect(l10n.calExportRowTitle.length, lessThan(24), reason: code);
    }
    expect(l10nOf('es').calExportTitle, 'Exportar turnos');
    expect(l10nOf('ca').calExportTitle, 'Exporta torns');
    // The old long title lives on as the subtitle of the row.
    expect(l10nOf('es').calExportRowSubtitle, contains('calendario del móvil'));
  });

  test('H-T21-4: «widget» in every language, never «giny»', () {
    for (final code in languages) {
      final arb = File('lib/l10n/app_$code.arb').readAsStringSync();
      expect(arb.toLowerCase(), isNot(contains('giny')), reason: code);
      final json = jsonDecode(arb) as Map<String, dynamic>;
      expect(
        (json['faqWidgetQ'] as String).toLowerCase(),
        contains('widget'),
        reason: code,
      );
    }
    expect(l10nOf('ca').widgetAddTitle, 'Afegeix un widget');
  });

  test('H-T21-5: the Catalan weekdays are the two-letter ones', () {
    final ca = l10nOf('ca');
    expect(
      [
        ca.calendarWeekdayMon,
        ca.calendarWeekdayTue,
        ca.calendarWeekdayWed,
        ca.calendarWeekdayThu,
        ca.calendarWeekdayFri,
        ca.calendarWeekdaySat,
        ca.calendarWeekdaySun,
      ],
      ['dl', 'dt', 'dc', 'dj', 'dv', 'ds', 'dg'],
    );
    expect(ca.widgetWeekdayHeaders, 'dl,dt,dc,dj,dv,ds,dg');
  });
}
