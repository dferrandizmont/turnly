import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:cuadrante/features/holidays/data/holiday_bundle_format.dart';
import 'package:cuadrante/features/holidays/data/holiday_bundle_loader.dart';
import 'package:cuadrante/features/holidays/domain/holiday.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/build_holidays.dart';
import '../../support/test_storage.dart' show makeTempDir;
import 'bundle_support.dart';

Map<String, Object?> _holiday(String date, String es, {String? origin}) => {
  'date': date,
  'label': {'ca': '$es ca', 'es': es, 'en': '$es en'},
  'origin': ?origin,
};

Map<String, Object?> _source(String name, String retrieved) => {
  'url': 'https://example.org/$name',
  'ref': 'Ref $name',
  'published': '2026-01-01',
  'retrieved': retrieved,
};

/// A small Mochila `src/calendars` tree: a verified year, one region, a
/// pending file, an unverified one and a Murcia school file (never bundled).
Directory _fixture() {
  final dir = makeTempDir('calendars');
  void write(String path, Object json) {
    final file = File('${dir.path}/$path')..createSync(recursive: true);
    file.writeAsStringSync(jsonEncode(json));
  }

  write('manifest.json', [
    {
      'file': 'national/2026.json',
      'verified': true,
      'status': 'complete',
      'source': _source('national', '2026-10-01'),
    },
    {
      'file': 'regional/ES-CT/2026.json',
      'verified': true,
      'status': 'complete',
      'source': _source('ct', '2026-10-05'),
    },
    {
      'file': 'regional/ES-MD/2026.json',
      'verified': false,
      'status': 'partial',
      'source': null,
    },
    {
      'file': 'municipal/ES-CT/2026.json',
      'verified': true,
      'status': 'complete',
      'source': _source('ct-local', '2026-10-07'),
    },
    {
      'file': 'municipal/ES-CT/2027.json',
      'verified': false,
      'status': 'pending',
      'source': null,
    },
    {
      'file': 'ES-MC/municipal-non-teaching-2026-27.json',
      'verified': true,
      'status': 'complete',
      'source': _source('mc', '2026-10-03'),
    },
  ]);
  write('national/2026.json', {
    'holidays': [
      _holiday('2026-12-25', 'Natividad del Señor'),
      _holiday('2026-01-01', 'Año Nuevo'),
    ],
  });
  write('regional/ES-CT/2026.json', {
    'holidays': [
      _holiday('2026-12-26', 'San Esteban', origin: 'regional'),
      _holiday('2026-01-06', 'Epifanía del Señor', origin: 'national-optional'),
    ],
  });
  write('municipal/ES-CT/2026.json', {
    '08019': {
      'name': 'Barcelona',
      'days': [
        {'date': '2026-09-24', 'label': 'Festa local'},
        {'date': '2026-05-25', 'label': 'Festa local'},
      ],
    },
    '08002': {
      'name': 'Aguilar',
      'days': [
        {'date': '2026-05-04', 'label': 'Fiesta local (El Pueblo)'},
      ],
    },
  });
  write('ES-MC/municipal-non-teaching-2026-27.json', {
    'municipalities': {
      '30001': {
        'name': 'Abanilla',
        'local_holidays': ['2026-09-14', '2027-05-03'],
        'other_non_teaching': ['2027-03-30'],
      },
    },
  });
  final ine = File('${dir.path}/ine.json')
    ..writeAsStringSync(jsonEncode({'08019': 'Barcelona', '99999': 'Nowhere'}));
  expect(ine.existsSync(), isTrue);
  return dir;
}

HolidayBundleBuild _build(Directory dir, {Directory? manual}) =>
    buildHolidayBundle(
      calendarsDir: dir,
      ineMunicipalities: File('${dir.path}/ine.json'),
      manualDir: manual,
    );

Map<String, Object?> _labourSource(String name, {String? ref}) => {
  'url': 'https://example.org/$name',
  'ref': ref ?? 'Boletín $name — fiestas laborales locales',
  'published': '2026-07-01',
  'retrieved': '2026-10-31',
};

/// A small `tool/holidays_es`: Barcelona checked by hand (it replaces
/// Mochila's days), Murcia city, and two Canary islands.
Directory _manualFixture() {
  final dir = makeTempDir('holidays_es');
  void write(String path, Object json) {
    File('${dir.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(json));
  }

  write('2026/ES-CT.json', {
    'region': 'ES-CT',
    'year': 2026,
    'kind': 'labour',
    'sources': {'s1': _labourSource('dogc')},
    'municipalities': {
      '08019': {
        'name': 'Barcelona',
        'days': ['2026-09-24', '2026-05-26'],
        'source': 's1',
      },
    },
  });
  write('2026/ES-MC.json', {
    'region': 'ES-MC',
    'year': 2026,
    'kind': 'labour',
    'sources': {'s1': _labourSource('borm'), 's2': _labourSource('unused')},
    'municipalities': {
      '30030': {
        'name': 'Murcia',
        'days': ['2026-09-15', '2026-04-07'],
        'source': 's1',
      },
    },
  });
  write('2026/ES-CN.json', {
    'region': 'ES-CN',
    'year': 2026,
    'kind': 'labour',
    'sources': {'s1': _labourSource('boc')},
    'municipalities': {
      '35016': {
        'name': 'Las Palmas de Gran Canaria',
        'days': ['2026-02-17', '2026-09-08'],
        'source': 's1',
      },
    },
  });
  write('canarias-islands.json', {
    'islands': {
      'GC': {
        'name': 'Gran Canaria',
        'municipalities': ['35016', '35026'],
      },
      'TF': {
        'name': 'Tenerife',
        'municipalities': ['38038'],
      },
    },
    'years': {
      '2026': {
        'source': _labourSource('decreto'),
        'days': {
          'GC': {'date': '2026-09-08', 'name': 'Nuestra Señora del Pino'},
          'TF': {'date': '2026-02-02', 'name': 'Virgen de la Candelaria'},
        },
      },
    },
  });
  return dir;
}

/// INE codes of the 50 province capitals.
const _provinceCapitals = [
  '01059', '02003', '03014', '04013', '05019', '06015', '07040', '08019', //
  '09059', '10037', '11012', '12040', '13034', '14021', '15030', '16078', //
  '17079', '18087', '19130', '20069', '21041', '22125', '23050', '24089', //
  '25120', '26089', '27028', '28079', '29067', '30030', '31201', '32054', //
  '33044', '34120', '35016', '36038', '37274', '38038', '39075', '40194', //
  '41091', '42173', '43148', '44216', '45168', '46250', '47186', '48020', //
  '49275', '50297',
];

void main() {
  group('tool/build_holidays.dart', () {
    test('only verified and complete files go in; the rest is listed', () {
      final build = _build(_fixture());

      expect(build.files.keys, [
        '2026/es.json',
        '2026/municipal/ES-CT.json',
        'manifest.json',
        'municipalities.json',
      ]);
      expect(
        build.skipped,
        containsAll([
          contains('regional/ES-MD/2026.json'),
          contains('municipal/ES-CT/2027.json: pending'),
          // A school calendar lists non-teaching days, not labour holidays.
          contains('municipal-non-teaching-2026-27.json: school calendar'),
        ]),
      );
      expect(build.notes, contains(contains('99999')));
    });

    test('rows are sorted, in Spanish, and read back with the app parser', () {
      final build = _build(_fixture());
      Map<String, Object?> json(String path) =>
          jsonDecode(utf8.decode(build.files[path]!)) as Map<String, Object?>;

      final es = parseEsFile(json('2026/es.json'));
      expect(
        [
          for (final e in es)
            '${e.date} ${e.scope.name} ${e.regionCode} ${e.name}',
        ],
        [
          '2026-01-01 national null Año Nuevo',
          '2026-12-25 national null Natividad del Señor',
          '2026-01-06 national ES-CT Epifanía del Señor',
          '2026-12-26 regional ES-CT San Esteban',
        ],
      );

      final local = parseMunicipalFile(json('2026/municipal/ES-CT.json'));
      expect(
        [for (final e in local) '${e.municipalityCode} ${e.date} ${e.name}'],
        [
          '08002 2026-05-04 Fiesta local (El Pueblo)',
          '08019 2026-05-25 Fiesta local',
          '08019 2026-09-24 Fiesta local',
        ],
      );

      expect(build.files.containsKey('2026/municipal/ES-MC.json'), isFalse);

      final index = MunicipalityIndex.fromJson(json('municipalities.json'));
      expect(index.byCode('08019')?.name, 'Barcelona');
      expect(index.length, 1);
    });

    test('the manifest lists every file with its real sha256 and size', () {
      final build = _build(_fixture());
      expect([
        for (final f in build.manifest.files) f.path,
      ], build.files.keys.where((p) => p != 'manifest.json'));
      for (final f in build.manifest.files) {
        final bytes = build.files[f.path]!;
        expect(f.sha256, sha256.convert(bytes).toString(), reason: f.path);
        expect(f.bytes, bytes.length, reason: f.path);
      }
      // The version is the latest retrieval date plus a content hash.
      expect(build.manifest.bundleVersion, startsWith('2026-10-07.'));
      expect(
        HolidayManifest.fromJson(
          jsonDecode(utf8.decode(build.files['manifest.json']!))
              as Map<String, Object?>,
        ).bundleVersion,
        build.manifest.bundleVersion,
      );
    });

    test('same input, same bytes; writing twice changes nothing', () {
      final dir = _fixture();
      final a = _build(dir);
      final b = _build(dir);
      expect(a.files.keys, b.files.keys);
      for (final path in a.files.keys) {
        expect(a.files[path], b.files[path], reason: path);
      }

      final out = makeTempDir('bundle');
      expect(writeHolidayBundle(out, a), hasLength(a.files.length));
      expect(writeHolidayBundle(out, b), isEmpty);
    });

    test('the version changes when the content does', () {
      final dir = _fixture();
      final before = _build(dir).manifest.bundleVersion;
      File('${dir.path}/national/2026.json').writeAsStringSync(
        jsonEncode({
          'holidays': [_holiday('2026-01-01', 'Año Nuevo!')],
        }),
      );
      expect(_build(dir).manifest.bundleVersion, isNot(before));
    });

    test('stale files and empty folders of an older bundle are removed', () {
      final out = makeTempDir('bundle');
      File('${out.path}/2024/es.json')
        ..createSync(recursive: true)
        ..writeAsStringSync('{}');
      final changed = writeHolidayBundle(out, _build(_fixture()));
      expect(changed, contains('2024/es.json (removed)'));
      expect(Directory('${out.path}/2024').existsSync(), isFalse);
    });

    test(
      'country files of the bundle folder are kept, listed with their source',
      () {
        final out = makeTempDir('bundle-countries');
        final bytes = utf8.encode(
          '{"schema":1,"year":2026,"country":"DE",'
          '"national":[{"date":"2026-10-03","name":"Tag der Deutschen Einheit"}]}\n',
        );
        File('${out.path}/2026/de.json')
          ..createSync(recursive: true)
          ..writeAsBytesSync(bytes);
        // Outside the bundle folder: writing the bundle removes stray .json.
        final sources =
            File('${makeTempDir('bundle-sources').path}/sources.json')
              ..writeAsStringSync(
                jsonEncode({
                  '2026/de.json': {
                    'url': 'https://example.org/holidays',
                    'ref': 'python-holidays x',
                    'published': '2026-10-31',
                  },
                }),
              );
        HolidayBundleBuild build() => buildHolidayBundle(
          calendarsDir: _fixture(),
          ineMunicipalities: null,
          bundledCountries: out,
          countrySources: sources,
        );

        final first = build();
        expect(first.files['2026/de.json'], bytes, reason: 'kept as it is');
        final line = first.manifest.files.singleWhere(
          (f) => f.path == '2026/de.json',
        );
        expect(line.kind, HolidayFileKind.country);
        expect(line.country, 'DE');
        expect(line.year, 2026);
        expect(line.sha256, sha256.convert(bytes).toString());
        expect(line.bytes, bytes.length);
        expect(line.source!['ref'], 'python-holidays x');
        expect(first.manifest.countries, containsAll(['DE', 'ES']));
        expect(requiredAssetFolders(first), contains('assets/holidays/2026/'));

        // Writing the bundle over that folder does not delete the file, and
        // the manifest survives a round trip through the loader's parser.
        writeHolidayBundle(out, first);
        expect(File('${out.path}/2026/de.json').existsSync(), isTrue);
        final again = build();
        expect(again.manifest.bundleVersion, first.manifest.bundleVersion);
        expect(
          parseCountryFile(
            jsonDecode(utf8.decode(first.files['2026/de.json']!))
                as Map<String, Object?>,
          ),
          hasLength(1),
        );
      },
    );

    test('a country file whose name and content disagree is an error', () {
      final out = makeTempDir('bundle-countries-bad');
      File('${out.path}/2026/fr.json')
        ..createSync(recursive: true)
        ..writeAsStringSync('{"schema":1,"year":2026,"country":"DE"}');
      expect(
        () =>
            buildHolidayBundle(calendarsDir: _fixture(), bundledCountries: out),
        throwsFormatException,
      );
    });

    test('a date outside its year is an error, not silently bundled', () {
      final dir = _fixture();
      File('${dir.path}/national/2026.json').writeAsStringSync(
        jsonEncode({
          'holidays': [_holiday('2027-01-01', 'Año Nuevo')],
        }),
      );
      expect(() => _build(dir), throwsFormatException);
    });

    test('the JSON encoder puts one entry per line, only that deep', () {
      expect(
        encodeBundleJson({
          'a': 1,
          'b': {
            'x': [1, 2],
            'y': {'z': 3},
          },
        }, lineDepth: 2),
        '{\n"a":1,\n"b":{\n"x":[1,2],\n"y":{"z":3}\n}\n}\n',
      );
    });

    test('the pubspec folders are derived from the file paths', () {
      expect(requiredAssetFolders(_build(_fixture())), [
        'assets/holidays/',
        'assets/holidays/2026/',
        'assets/holidays/2026/municipal/',
      ]);
    });
  });

  group('hand-checked locals (tool/holidays_es)', () {
    Map<String, Object?> json(HolidayBundleBuild build, String path) =>
        jsonDecode(utf8.decode(build.files[path]!)) as Map<String, Object?>;
    List<String> days(HolidayBundleBuild build, String path) => [
      for (final e in parseMunicipalFile(json(build, path)))
        '${e.municipalityCode} ${e.date} ${e.name}',
    ];

    test('a checked municipality replaces Mochila; the rest stays', () {
      final build = _build(_fixture(), manual: _manualFixture());
      expect(days(build, '2026/municipal/ES-CT.json'), [
        '08002 2026-05-04 Fiesta local (El Pueblo)',
        '08019 2026-05-26 Fiesta local',
        '08019 2026-09-24 Fiesta local',
      ]);
      // Murcia is back, from the labour calendar, not the school one.
      expect(days(build, '2026/municipal/ES-MC.json'), [
        '30030 2026-04-07 Fiesta local',
        '30030 2026-09-15 Fiesta local',
      ]);
      // Both acts are credited; an unused source is not.
      final ct = build.manifest.files.firstWhere(
        (f) => f.path == '2026/municipal/ES-CT.json',
      );
      expect(ct.source!['url'], 'https://example.org/ct-local');
      expect(ct.source!['also'], [
        {
          'url': 'https://example.org/dogc',
          'ref': 'Boletín dogc — fiestas laborales locales',
          'published': '2026-07-01',
        },
      ]);
      final mc = build.manifest.files.firstWhere(
        (f) => f.path == '2026/municipal/ES-MC.json',
      );
      expect(mc.source!['url'], 'https://example.org/borm');
      expect(mc.source!.containsKey('also'), isFalse);
      // The newest retrieval date drives the version.
      expect(build.manifest.bundleVersion, startsWith('2026-10-31.'));
    });

    test('an island holiday goes to every municipality of its island', () {
      final build = _build(_fixture(), manual: _manualFixture());
      expect(days(build, '2026/municipal/ES-CN.json'), [
        // Las Palmas already has 8 September as a local day: not twice.
        '35016 2026-02-17 Fiesta local',
        '35016 2026-09-08 Fiesta local',
        '35026 2026-09-08 Fiesta insular (Nuestra Señora del Pino)',
        '38038 2026-02-02 Fiesta insular (Virgen de la Candelaria)',
      ]);
      expect(
        isIslandHolidayName('Fiesta insular (Virgen de la Candelaria)'),
        isTrue,
      );
      expect(isIslandHolidayName('Fiesta local'), isFalse);
      expect(isIslandHolidayName('Fiesta insularidad'), isFalse);
    });

    test('a school calendar is never a source of local holidays', () {
      final manual = _manualFixture();
      final file = File('${manual.path}/2026/ES-MC.json');
      final data = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      (data['sources']! as Map)['s1'] = _labourSource(
        'borm',
        ref:
            'BORM — Resolución por la que se establece el período lectivo '
            'del curso escolar 2026-2027',
      );
      file.writeAsStringSync(jsonEncode(data));
      expect(() => _build(_fixture(), manual: manual), throwsFormatException);
    });

    test('the school words are spotted, the labour acts are not', () {
      for (final ref in [
        'Calendario escolar 2026-2027',
        'días no lectivos del curso 2026-2027',
        'Departament d’Ensenyament',
        '2026-2027 ikasturtea',
      ]) {
        expect(
          () => checkLabourSource({
            'url': 'https://x.es',
            'ref': ref,
            'published': '2026-01-01',
          }, ref),
          throwsFormatException,
          reason: ref,
        );
      }
      for (final ref in [
        'DOGV — Conselleria de Educación, Cultura, Universidades y Empleo: '
            'calendario de fiestas locales para el año 2026',
        'BORM — convenio colectivo, calendario de fiestas laborales',
      ]) {
        expect(
          () => checkLabourSource({
            'url': 'https://x.es',
            'ref': ref,
            'published': '2026-01-01',
          }, ref),
          returnsNormally,
          reason: ref,
        );
      }
    });

    test('broken files are errors, not silently bundled', () {
      void expectBroken(void Function(Map<String, Object?> data) change) {
        final manual = _manualFixture();
        final file = File('${manual.path}/2026/ES-MC.json');
        final data =
            jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
        change(data);
        file.writeAsStringSync(jsonEncode(data));
        expect(() => _build(_fixture(), manual: manual), throwsFormatException);
      }

      Map<String, Object?> murcia(Map<String, Object?> data) =>
          ((data['municipalities']! as Map)['30030']! as Map)
              .cast<String, Object?>();
      // A municipality of another region.
      expectBroken(
        (d) => (d['municipalities']! as Map)['08019'] = {
          'name': 'Barcelona',
          'days': ['2026-05-25'],
          'source': 's1',
        },
      );
      expectBroken((d) => murcia(d)['source'] = 'nope');
      expectBroken((d) => murcia(d)['days'] = ['2027-04-07']);
      expectBroken((d) => murcia(d)['days'] = <String>[]);
      expectBroken((d) => d['kind'] = 'school');
      expectBroken((d) => d['year'] = 2027);
      expectBroken(
        (d) => (d['sources']! as Map)['s1'] = {
          'url': 'ftp://x',
          'ref': 'r',
          'published': '2026-01-01',
        },
      );
    });

    test('an island municipality must be Canarian and on one island', () {
      final manual = _manualFixture();
      final file = File('${manual.path}/canarias-islands.json');
      final data = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      ((data['islands']! as Map)['TF']! as Map)['municipalities'] = [
        '38038',
        '35026',
      ];
      file.writeAsStringSync(jsonEncode(data));
      expect(() => _build(_fixture(), manual: manual), throwsFormatException);
    });
  });

  group('shipped bundle (assets/holidays)', () {
    test('every file matches the manifest hash and size', () {
      final files = shippedBundleFiles();
      final manifest = HolidayManifest.fromJson(
        jsonDecode(utf8.decode(files['assets/holidays/manifest.json']!))
            as Map<String, Object?>,
      );
      expect(manifest.files, isNotEmpty);
      for (final f in manifest.files) {
        final bytes = files['assets/holidays/${f.path}'];
        expect(bytes, isNotNull, reason: '${f.path} is missing');
        expect(bytes!.length, f.bytes, reason: f.path);
        expect(sha256.convert(bytes).toString(), f.sha256, reason: f.path);
      }
      // Nothing in the folder that the manifest does not list.
      expect(
        files.keys.map((k) => k.replaceFirst('assets/holidays/', '')).toSet(),
        {
          'manifest.json',
          'NOTICE', // licence of the other countries' data
          ...manifest.files.map((f) => f.path),
        },
      );
    });

    test('every asset folder is declared in the pubspec', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final folders = {
        for (final key in shippedBundleFiles().keys)
          key.substring(0, key.lastIndexOf('/') + 1),
      };
      for (final folder in folders) {
        expect(pubspec, contains('- $folder'), reason: folder);
      }
    });

    test('is small and covers 2026 and 2027', () {
      final files = shippedBundleFiles();
      final total = files.values.fold<int>(0, (n, b) => n + b.length);
      // Spain (~320 KB) plus the 42 files of 21 other countries (~116 KB).
      expect(total, lessThan(512 * 1024));
      expect(
        files['assets/holidays/municipalities.json']!.length,
        lessThan(300 * 1024),
      );
      expect(
        files.keys,
        containsAll([
          'assets/holidays/2026/es.json',
          'assets/holidays/2027/es.json',
        ]),
      );
    });

    test('the 50 province capitals have their 2026 local holidays', () async {
      final entries = await shippedEntries();
      for (final code in _provinceCapitals) {
        final days = {
          for (final e in entries)
            if (isBundledLocalOf(e, code) && e.date.year == 2026) e.date,
        };
        expect(days.length, 2, reason: '$code: $days');
      }
      // Ceuta and Melilla have theirs too.
      for (final code in ['51001', '52001']) {
        expect(
          entries.where((e) => isBundledLocalOf(e, code)),
          hasLength(2),
          reason: code,
        );
      }
    });

    test('no local holiday comes from a school calendar', () {
      final files = shippedBundleFiles();
      final manifest = HolidayManifest.fromJson(
        jsonDecode(utf8.decode(files['assets/holidays/manifest.json']!))
            as Map<String, Object?>,
      );
      final municipal = manifest.files.where(
        (f) => f.kind == HolidayFileKind.municipal,
      );
      expect(municipal, isNotEmpty);
      for (final f in municipal) {
        expect(f.source, isNotNull, reason: f.path);
        checkLabourSource(f.source, f.path);
        for (final also in (f.source!['also'] as List? ?? const [])) {
          checkLabourSource(also, '${f.path} (also)');
        }
      }
      // And every hand-checked file says it is labour, with known sources.
      final manual = Directory('tool/holidays_es');
      final checked = manual
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (f) => RegExp(r'\d{4}[/\\]ES-[A-Z]{2}\.json$').hasMatch(f.path),
          );
      expect(checked, isNotEmpty);
      for (final file in checked) {
        final data =
            jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
        expect(data['kind'], 'labour', reason: file.path);
        final sources = (data['sources']! as Map).cast<String, Object?>();
        for (final MapEntry(key: id, value: s) in sources.entries) {
          checkLabourSource(s, '${file.path} $id');
        }
        for (final m in (data['municipalities']! as Map).values) {
          expect(sources.keys, contains((m as Map)['source']));
        }
      }
    });

    test('Murcia: all 45 municipalities, both years', () async {
      final entries = await shippedEntries();
      for (final year in [2026, 2027]) {
        final codes = {
          for (final e in entries)
            if (e.regionCode == 'ES-MC' &&
                e.scope == HolidayScope.local &&
                e.date.year == year)
              e.municipalityCode,
        };
        expect(codes, hasLength(45), reason: '$year');
      }
    });

    test('every Canary municipality has its island holiday', () async {
      final entries = await shippedEntries();
      final index = await HolidayBundleLoader(bundle: shippedBundle())
          .loadMunicipalities();
      final canarian = index!.inRegion('ES-CN').map((m) => m.code).toList();
      expect(canarian, hasLength(88));
      for (final year in [2026, 2027]) {
        for (final code in canarian) {
          final island = entries.where(
            (e) =>
                e.municipalityCode == code &&
                e.date.year == year &&
                isIslandHolidayName(e.name),
          );
          // Las Palmas de Gran Canaria and Santa Cruz de Tenerife have their
          // own local days, and none of them is the island's.
          expect(island, hasLength(1), reason: '$code $year');
        }
      }
    });

    test('building from the real data twice gives the shipped bytes', () {
      const backend = '../../mochila-app/backend';
      final calendars = Directory('$backend/src/calendars');
      if (!calendars.existsSync()) {
        markTestSkipped('Mochila is not next to this repository');
        return;
      }
      HolidayBundleBuild build() => buildHolidayBundle(
        calendarsDir: calendars,
        ineMunicipalities: File(
          '$backend/scripts/calendars/sources/ine-municipios-es.json',
        ),
        manualDir: Directory('tool/holidays_es'),
      );
      final a = build();
      final b = build();
      expect(a.manifest.bundleVersion, b.manifest.bundleVersion);
      for (final path in a.files.keys) {
        expect(a.files[path], b.files[path], reason: path);
      }
      // A change in tool/holidays_es without rebuilding the bundle fails here
      // (the manifest is left out: other countries' files are added to it).
      final shipped = shippedBundleFiles();
      for (final path in a.files.keys.where((p) => p != 'manifest.json')) {
        expect(
          shipped['assets/holidays/$path'],
          a.files[path],
          reason: '$path: run dart run tool/build_holidays.dart',
        );
      }
    });
  });
}
