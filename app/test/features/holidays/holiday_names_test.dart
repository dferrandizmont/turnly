import 'dart:convert';
import 'dart:io';

import 'package:cuadrante/features/holidays/domain/holiday.dart';
import 'package:cuadrante/features/holidays/presentation/holiday_names.dart';
import 'package:cuadrante/features/schedule/domain/civil_date.dart';
import 'package:cuadrante/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// H-T21-1: the names of the holidays come from the bundle in Spanish; the
/// national and the common regional ones are shown in the app's language.
void main() {
  AppLocalizations l10nOf(String code) => lookupAppLocalizations(Locale(code));

  Holiday bundled(String name) => Holiday(
    date: const CivilDate(2026, 1, 1),
    name: name,
    scope: HolidayScope.national,
  );

  // Spanish name of the bundle -> ca / gl / eu / en.
  const expected = <String, List<String>>{
    'Año Nuevo': ['Cap d’Any', 'Aninovo', 'Urte Berri eguna', 'New Year’s Day'],
    'Epifanía del Señor': ['Reis', 'Reis', 'Errege eguna', 'Epiphany'],
    'Jueves Santo': [
      'Dijous Sant',
      'Xoves Santo',
      'Ostegun Santua',
      'Maundy Thursday',
    ],
    'Viernes Santo': [
      'Divendres Sant',
      'Venres Santo',
      'Ostiral Santua',
      'Good Friday',
    ],
    'Lunes de Pascua': [
      'Dilluns de Pasqua',
      'Luns de Pascua',
      'Pazko astelehena',
      'Easter Monday',
    ],
    'Fiesta del Trabajo': [
      'Festa del Treball',
      'Festa do Traballo',
      'Langileen eguna',
      'Labour Day',
    ],
    'Asunción de la Virgen': [
      'L’Assumpció',
      'Asunción',
      'Ama Birjinaren Jasokundea',
      'Assumption Day',
    ],
    'Fiesta Nacional de España': [
      'Festa Nacional d’Espanya',
      'Festa Nacional de España',
      'Espainiako Jai Nazionala',
      'National Day of Spain',
    ],
    'Todos los Santos': [
      'Tots Sants',
      'Santos',
      'Santu Guztien eguna',
      'All Saints’ Day',
    ],
    'Día de la Constitución Española': [
      'Dia de la Constitució',
      'Día da Constitución',
      'Konstituzio eguna',
      'Constitution Day',
    ],
    'Inmaculada Concepción': [
      'La Immaculada',
      'Inmaculada Concepción',
      'Sortzez Garbiaren eguna',
      'Immaculate Conception',
    ],
    'Natividad del Señor': [
      'Nadal',
      'Nadal',
      'Eguberri eguna',
      'Christmas Day',
    ],
    'San Esteban': [
      'Sant Esteve',
      'Santo Estevo',
      'San Esteban',
      'St Stephen’s Day',
    ],
    'San José': ['Sant Josep', 'San Xosé', 'San Jose', 'St Joseph’s Day'],
    'Santiago Apóstol': [
      'Sant Jaume',
      'Santiago Apóstolo',
      'Santiago Apostolua',
      'St James’ Day',
    ],
    'Santiago Apóstol / Día Nacional de Galicia': [
      'Sant Jaume / Dia de Galícia',
      'Santiago Apóstolo / Día Nacional de Galicia',
      'Santiago Apostolua / Galiziako eguna',
      'St James’ Day / Galicia Day',
    ],
    'Diada Nacional de Cataluña': [
      'Diada Nacional de Catalunya',
      'Diada de Cataluña',
      'Kataluniako Diada',
      'Catalonia National Day',
    ],
    'San Juan': ['Sant Joan', 'San Xoán', 'San Joan', 'St John’s Day'],
    'Día de Andalucía': [
      'Dia d’Andalusia',
      'Día de Andalucía',
      'Andaluziako eguna',
      'Andalusia Day',
    ],
    'Día siguiente a Todos los Santos': [
      'Dia després de Tots Sants',
      'Día seguinte a Todos os Santos',
      'Santu Guztien biharamuna',
      'Day after All Saints’ Day',
    ],
    'Lunes siguiente al Día de la Constitución': [
      'Dilluns següent al Dia de la Constitució',
      'Luns seguinte ao Día da Constitución',
      'Konstituzio egunaren hurrengo astelehena',
      'Monday after Constitution Day',
    ],
    'San Jorge / Día de Aragón': [
      'Sant Jordi / Dia d’Aragó',
      'San Xurxo / Día de Aragón',
      'San Jorge / Aragoiko eguna',
      'St George’s Day / Aragon Day',
    ],
    'Día de Asturias': [
      'Dia d’Astúries',
      'Día de Asturias',
      'Asturiasko eguna',
      'Asturias Day',
    ],
    'Día de las Instituciones de Cantabria': [
      'Dia de les Institucions de Cantàbria',
      'Día das Institucións de Cantabria',
      'Kantabriako Erakundeen eguna',
      'Cantabria Institutions Day',
    ],
    'La Bien Aparecida': [
      'La Bien Aparecida',
      'La Bien Aparecida',
      'La Bien Aparecida',
      'La Bien Aparecida',
    ],
    'Fiesta del Sacrificio (Eidul Adha)': [
      'Festa del Sacrifici (Eid al-Adha)',
      'Festa do Sacrificio (Eid al-Adha)',
      'Sakrifizioaren jaia (Eid al-Adha)',
      'Feast of the Sacrifice (Eid al-Adha)',
    ],
    'Fiesta del Eid Fitr': [
      'Festa de l’Eid al-Fitr',
      'Festa do Eid al-Fitr',
      'Eid al-Fitr jaia',
      'Eid al-Fitr',
    ],
    'Nuestra Señora de África': [
      'Nostra Senyora d’Àfrica',
      'Nosa Señora de África',
      'Afrikako Andre Maria',
      'Our Lady of Africa',
    ],
    'Día de Ceuta': [
      'Dia de Ceuta',
      'Día de Ceuta',
      'Zeutako eguna',
      'Ceuta Day',
    ],
    'Fiesta de Castilla y León': [
      'Festa de Castella i Lleó',
      'Festa de Castela e León',
      'Gaztela eta Leongo jaia',
      'Castile and León Day',
    ],
    'Corpus Christi': [
      'Corpus Christi',
      'Corpus Christi',
      'Corpus Christi',
      'Corpus Christi',
    ],
    'Día de Canarias': [
      'Dia de Canàries',
      'Día de Canarias',
      'Kanarietako eguna',
      'Canary Islands Day',
    ],
    'Día de Extremadura': [
      'Dia d’Extremadura',
      'Día de Extremadura',
      'Extremadurako eguna',
      'Extremadura Day',
    ],
    'Día de la Región de Murcia': [
      'Dia de la Regió de Múrcia',
      'Día da Rexión de Murcia',
      'Murtziako Eskualdearen eguna',
      'Region of Murcia Day',
    ],
    'Fiesta de la Comunidad de Madrid': [
      'Festa de la Comunitat de Madrid',
      'Festa da Comunidade de Madrid',
      'Madrilgo Erkidegoaren jaia',
      'Community of Madrid Day',
    ],
    'Día de La Rioja': [
      'Dia de La Rioja',
      'Día de La Rioja',
      'Errioxako eguna',
      'La Rioja Day',
    ],
    'Día de la Comunitat Valenciana': [
      'Dia de la Comunitat Valenciana',
      'Día da Comunidade Valenciana',
      'Valentziako Erkidegoaren eguna',
      'Valencian Community Day',
    ],
    'Día de les Illes Balears': [
      'Dia de les Illes Balears',
      'Día das Illes Balears',
      'Balear Uharteetako eguna',
      'Balearic Islands Day',
    ],
    'Lunes siguiente al Día de les Illes Balears': [
      'Dilluns següent al Dia de les Illes Balears',
      'Luns seguinte ao Día das Illes Balears',
      'Balear Uharteetako egunaren hurrengo astelehena',
      'Monday after Balearic Islands Day',
    ],
    'Día de Castilla-La Mancha': [
      'Dia de Castella-la Manxa',
      'Día de Castela-A Mancha',
      'Gaztela-Mantxako eguna',
      'Castilla-La Mancha Day',
    ],
    'Sustitución del 15 de agosto': [
      'Substitució del 15 d’agost',
      'Substitución do 15 de agosto',
      'Abuztuaren 15aren ordezkoa',
      'Replacement for 15 August',
    ],
    'Lunes siguiente a la Asunción de la Virgen': [
      'Dilluns següent a l’Assumpció',
      'Luns seguinte á Asunción',
      'Jasokundearen hurrengo astelehena',
      'Monday after Assumption Day',
    ],
    'Traslado de la Asunción': [
      'Trasllat de l’Assumpció',
      'Traslado da Asunción',
      'Jasokundearen lekualdatzea',
      'Assumption Day (moved)',
    ],
    'Día de las Letras Gallegas': [
      'Dia de les Lletres Gallegues',
      'Día das Letras Galegas',
      'Galiziar Letren eguna',
      'Galician Literature Day',
    ],
    'Aniversario del primer Gobierno Vasco': [
      'Aniversari del primer Govern Basc',
      'Aniversario do primeiro Goberno Vasco',
      'Lehen Eusko Jaurlaritzaren urteurrena',
      'Anniversary of the first Basque Government',
    ],
    'Fiesta insular (Nuestra Señora del Pino)': [
      'Festa insular (Nostra Senyora del Pino)',
      'Festa insular (Nosa Señora do Pino)',
      'Uharteko jaia (Pinoko Andre Maria)',
      'Island holiday (Our Lady of Pino)',
    ],
    'Fiesta insular (Nuestra Señora de la Peña)': [
      'Festa insular (Nostra Senyora de la Peña)',
      'Festa insular (Nosa Señora da Peña)',
      'Uharteko jaia (Peñako Andre Maria)',
      'Island holiday (Our Lady of La Peña)',
    ],
    'Fiesta insular (Nuestra Señora de los Volcanes)': [
      'Festa insular (Nostra Senyora dels Volcans)',
      'Festa insular (Nosa Señora dos Volcáns)',
      'Uharteko jaia (Sumendien Andre Maria)',
      'Island holiday (Our Lady of the Volcanoes)',
    ],
    'Fiesta insular (Virgen de la Candelaria)': [
      'Festa insular (Mare de Déu de la Candelaria)',
      'Festa insular (Virxe da Candelaria)',
      'Uharteko jaia (Kandelariako Ama Birjina)',
      'Island holiday (Virgin of Candelaria)',
    ],
    'Fiesta insular (Nuestra Señora de Guadalupe)': [
      'Festa insular (Nostra Senyora de Guadalupe)',
      'Festa insular (Nosa Señora de Guadalupe)',
      'Uharteko jaia (Guadalupeko Andre Maria)',
      'Island holiday (Our Lady of Guadalupe)',
    ],
    'Fiesta insular (Nuestra Señora de las Nieves)': [
      'Festa insular (Nostra Senyora de les Neus)',
      'Festa insular (Nosa Señora das Neves)',
      'Uharteko jaia (Elurren Andre Maria)',
      'Island holiday (Our Lady of the Snows)',
    ],
    'Fiesta insular (Nuestra Señora de los Reyes)': [
      'Festa insular (Nostra Senyora dels Reis)',
      'Festa insular (Nosa Señora dos Reis)',
      'Uharteko jaia (Erregeen Andre Maria)',
      'Island holiday (Our Lady of the Kings)',
    ],
  };
  const languages = ['ca', 'gl', 'eu', 'en'];

  test('the bundle names show in ca, gl, eu and en', () {
    for (final entry in expected.entries) {
      for (final (i, code) in languages.indexed) {
        expect(
          holidayDisplayName(l10nOf(code), bundled(entry.key)),
          entry.value[i],
          reason: '${entry.key} in $code',
        );
      }
    }
  });

  test('Spanish keeps the bundle name', () {
    for (final name in expected.keys) {
      expect(holidayDisplayName(l10nOf('es'), bundled(name)), name);
    }
  });

  test('the key ignores accents, case and the variant of Catalunya', () {
    final ca = l10nOf('ca');
    expect(localizedHolidayName(ca, 'ANO NUEVO'), 'Cap d’Any');
    expect(localizedHolidayName(ca, ' viernes santo '), 'Divendres Sant');
    expect(
      localizedHolidayName(ca, 'Diada Nacional de Catalunya'),
      'Diada Nacional de Catalunya',
    );
    expect(localizedHolidayName(l10nOf('en'), 'Día de Galicia'), 'Galicia Day');
    expect(
      localizedHolidayName(l10nOf('eu'), 'Día del País Vasco'),
      'Euskadiko eguna',
    );
  });

  test('an unknown name falls back to the bundle name', () {
    for (final code in languages) {
      expect(
        holidayDisplayName(l10nOf(code), bundled('Fiesta Inventada')),
        'Fiesta Inventada',
      );
    }
    expect(localizedHolidayName(l10nOf('ca'), 'Fiesta Inventada'), isNull);
  });

  test('a holiday the person added is never translated', () {
    const own = Holiday(
      date: CivilDate(2026, 3, 20),
      name: 'Año Nuevo',
      scope: HolidayScope.local,
      source: HolidaySource.user,
    );
    for (final code in languages) {
      expect(holidayDisplayName(l10nOf(code), own), 'Año Nuevo');
    }
  });

  test('every national holiday of the bundle has a translation', () {
    for (final year in [2026, 2027]) {
      final file = File('assets/holidays/$year/es.json');
      final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      for (final h in json['national']! as List<Object?>) {
        final name = (h! as Map<String, Object?>)['name']! as String;
        for (final code in languages) {
          expect(
            localizedHolidayName(l10nOf(code), name),
            isNotNull,
            reason: '$name ($year) in $code',
          );
        }
      }
    }
  });

  test('every Spain name of the bundle (national, regional, local) is '
      'translated in ca, gl, eu and en', () {
    final names = <String>{};
    void collect(Object? node) {
      if (node is List<Object?>) {
        node.forEach(collect);
      } else if (node is Map<String, Object?>) {
        final name = node['name'];
        if (name is String) names.add(name);
        node.values.forEach(collect);
      }
    }

    final dir = Directory('assets/holidays');
    for (final file in dir.listSync(recursive: true).whereType<File>()) {
      final path = file.path.replaceAll('\\', '/');
      final isSpain =
          path.endsWith('/es.json') || path.contains('/municipal/ES-');
      if (!isSpain || !path.endsWith('.json')) continue;
      collect(jsonDecode(file.readAsStringSync()));
    }
    expect(names.length, greaterThan(50));
    for (final name in names) {
      for (final code in languages) {
        expect(
          localizedHolidayName(l10nOf(code), name),
          isNotNull,
          reason: '"$name" in $code',
        );
      }
    }
  });

  test('a local holiday keeps its place and translates the rest', () {
    expect(
      localizedHolidayName(l10nOf('en'), 'Fiesta local (Cerceda)'),
      'Local holiday (Cerceda)',
    );
    expect(
      localizedHolidayName(l10nOf('eu'), 'Fiesta local (El Boalo)'),
      'Tokiko jaia (El Boalo)',
    );
    expect(
      localizedHolidayName(l10nOf('es'), 'Fiesta local (Cerceda)'),
      'Fiesta local (Cerceda)',
    );
  });

  test('the variants of a name share one translation', () {
    final en = l10nOf('en');
    expect(
      localizedHolidayName(
        en,
        'Lunes siguiente al Día de la Constitución '
        'Española',
      ),
      localizedHolidayName(en, 'Lunes siguiente al Día de la Constitución'),
    );
    expect(
      localizedHolidayName(en, 'Fiesta del Sacrificio (Aid al Adha)'),
      localizedHolidayName(en, 'Eidul Adha (Fiesta del Sacrificio)'),
    );
  });

  test('every other country shows one language: its own bundle names', () {
    final dir = Directory('assets/holidays/2026');
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();
    expect(files.length, greaterThan(40));
    for (final file in files) {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      final cc = (json['country'] as String?) ?? 'ES';
      if (cc == 'ES') continue;
      final names = <String>[
        for (final h in json['national']! as List<Object?>)
          (h! as Map<String, Object?>)['name']! as String,
        for (final list
            in ((json['regional'] ?? <String, Object?>{})
                    as Map<String, Object?>)
                .values)
          for (final h in list! as List<Object?>)
            (h! as Map<String, Object?>)['name']! as String,
      ];
      for (final code in ['es', ...languages]) {
        for (final name in names) {
          final shown = holidayDisplayName(
            l10nOf(code),
            Holiday(
              date: const CivilDate(2026, 1, 1),
              name: name,
              scope: HolidayScope.national,
              countryCode: cc,
            ),
          );
          expect(shown, name, reason: '$cc "$name" in $code');
        }
      }
    }
  });
}
