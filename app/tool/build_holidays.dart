// Builds Cuadrante's holiday bundle (assets/holidays/) from Mochila's calendar
// data. Read-only on the Mochila side.
//
//   dart run tool/build_holidays.dart                 # writes assets/holidays
//   dart run tool/build_holidays.dart --check         # fails if it is stale
//   dart run tool/build_holidays.dart --mochila <path to mochila-app/backend>
//
//   dart run tool/build_holidays.dart --manual <tool/holidays_es>
//
// Reads (all under backend/src/calendars/): manifest.json, national/{año}.json,
// regional/ES-XX/{año}.json and municipal/ES-XX/{año}.json. Only files the
// manifest marks `verified: true` and `status: complete` go in. School
// calendars (ES-XX/municipal-non-teaching-*.json) never do: their days are
// non-teaching days, not labour holidays. The INE names come from
// backend/scripts/calendars/sources/ine-municipios-es.json.
//
// On top of Mochila, the local labour holidays checked by hand in this repo
// (tool/holidays_es/{año}/ES-XX.json, one official source per municipality)
// and the Canary island holidays (tool/holidays_es/canarias-islands.json),
// which go to every municipality of their island. A hand-checked municipality
// replaces Mochila's days for that year. Format: docs/festivos.md.
//
// The output is deterministic: same inputs, same bytes. `bundleVersion` is the
// latest `retrieved` date of the included sources plus 8 hex digits of the
// content hash, so it changes whenever any file does.
//
// Format: docs/festivos.md and lib/features/holidays/data/holiday_bundle_format.dart.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:cuadrante/features/holidays/data/holiday_bundle_format.dart';
import 'package:cuadrante/features/holidays/domain/spanish_regions.dart';
import 'package:cuadrante/features/schedule/domain/civil_date.dart';

/// Result of [buildHolidayBundle]: the files to write and what was left out.
class HolidayBundleBuild {
  HolidayBundleBuild({
    required this.files,
    required this.manifest,
    required this.skipped,
    required this.notes,
  });

  /// Bundle-relative path -> bytes, `manifest.json` included.
  final Map<String, List<int>> files;
  final HolidayManifest manifest;

  /// Calendar files of the source that did not make it, with the reason.
  final List<String> skipped;
  final List<String> notes;
}

/// Reads Mochila's calendars and produces the bundle in memory.
///
/// [calendarsDir] is `backend/src/calendars`; [ineMunicipalities] the INE
/// code -> name JSON (skipped when null or missing); [manualDir] the
/// hand-checked local holidays (`tool/holidays_es`; skipped when null or
/// missing).
///
/// [bundledCountries] is the bundle folder that already holds the files of
/// other countries (`{year}/<cc>.json`, written by
/// `tool/export_country_holidays.py`, not by this tool): they are kept as they
/// are and listed in the manifest, with their provenance taken from
/// [countrySources] (path -> `{url, ref, published}`). Without it the
/// manifest would lose them.
HolidayBundleBuild buildHolidayBundle({
  required Directory calendarsDir,
  File? ineMunicipalities,
  Directory? manualDir,
  String? bundleVersion,
  Directory? bundledCountries,
  File? countrySources,
}) {
  final skipped = <String>[];
  final notes = <String>[];
  final files = <String, List<int>>{};
  final entries = <HolidayManifestFile>[];
  final retrieved = <String>[];

  Object? readJson(String relative) =>
      jsonDecode(File('${calendarsDir.path}/$relative').readAsStringSync());

  final sourceManifest = (readJson('manifest.json') as List)
      .cast<Map<String, Object?>>();
  final byFile = {for (final e in sourceManifest) e['file']! as String: e};

  /// Whether [file] may be bundled; otherwise records why not.
  bool usable(String file) {
    final e = byFile[file];
    if (e == null) {
      skipped.add('$file: not in the Mochila manifest');
      return false;
    }
    if (e['verified'] != true || e['status'] != 'complete') {
      skipped.add('$file: ${e['status']}, verified=${e['verified']}');
      return false;
    }
    if (!File('${calendarsDir.path}/$file').existsSync()) {
      skipped.add('$file: listed but missing on disk');
      return false;
    }
    return true;
  }

  Map<String, Object?>? sourceOf(String file) {
    final s = byFile[file]?['source'];
    if (s is! Map) return null;
    final retrievedOn = s['retrieved'];
    if (retrievedOn is String) retrieved.add(retrievedOn);
    return {'url': s['url'], 'ref': s['ref'], 'published': s['published']};
  }

  void add(
    String path,
    Object json, {
    required HolidayFileKind kind,
    int? year,
    String? region,
    Map<String, Object?>? source,
    int lineDepth = 2,
  }) {
    final bytes = utf8.encode(encodeBundleJson(json, lineDepth: lineDepth));
    files[path] = bytes;
    entries.add(
      HolidayManifestFile(
        path: path,
        kind: kind,
        year: year,
        region: region,
        sha256: sha256.convert(bytes).toString(),
        bytes: bytes.length,
        source: source,
      ),
    );
  }

  // 1. Years: those with a usable national file.
  final nationalByYear = <int, Map<String, Object?>>{};
  final nationalFile = RegExp(r'^national/(\d{4})\.json$');
  for (final file in byFile.keys.toList()..sort()) {
    final m = nationalFile.firstMatch(file);
    if (m == null || !usable(file)) continue;
    nationalByYear[int.parse(m[1]!)] = readJson(file)! as Map<String, Object?>;
  }
  final years = nationalByYear.keys.toList()..sort();

  // 2. {year}/es.json: national + regional.
  for (final year in years) {
    final national = _rows(nationalByYear[year]!, year, 'national/$year.json');
    final regional = <String, Object?>{};
    for (final region in spanishRegions.map((r) => r.code).toList()..sort()) {
      final file = 'regional/$region/$year.json';
      if (!usable(file)) continue;
      final json = readJson(file)! as Map<String, Object?>;
      sourceOf(file); // registers its retrieval date for the bundle version
      regional[region] = _rows(json, year, file, withOrigin: true);
    }
    add(
      '$year/es.json',
      {
        'schema': holidayBundleSchema,
        'year': year,
        'national': national,
        'regional': regional,
      },
      kind: HolidayFileKind.es,
      year: year,
      source: sourceOf('national/$year.json'),
    );
  }

  // 3. {year}/municipal/ES-XX.json.
  // (region, year) -> INE code -> days.
  final municipal = <(String, int), Map<String, Set<(String, String?)>>>{};
  final municipalSources = <(String, int), List<Map<String, Object?>>>{};
  void addSource((String, int) key, Map<String, Object?>? source) {
    if (source == null) return;
    final list = municipalSources.putIfAbsent(key, () => []);
    if (!list.any((s) => s['url'] == source['url'])) list.add(source);
  }

  final municipalFile = RegExp(r'^municipal/(ES-[A-Z]{2})/(\d{4})\.json$');
  final schoolFile = RegExp(
    r'^(ES-[A-Z]{2})/municipal-non-teaching-\d{4}-\d{2}\.json$',
  );
  for (final file in byFile.keys.toList()..sort()) {
    if (schoolFile.hasMatch(file)) {
      skipped.add('$file: school calendar (non-teaching days), not labour');
      continue;
    }
    final m = municipalFile.firstMatch(file);
    if (m == null || !usable(file)) continue;
    final region = m[1]!;
    final year = int.parse(m[2]!);
    final json = readJson(file)! as Map<String, Object?>;
    final target = municipal.putIfAbsent((
      region,
      year,
    ), () => <String, Set<(String, String?)>>{});
    addSource((region, year), sourceOf(file));
    for (final MapEntry(key: code, value: value) in json.entries) {
      final days = (value! as Map)['days']! as List;
      for (final d in days.cast<Map<String, Object?>>()) {
        final date = d['date']! as String;
        _checkDate(date, year, file);
        target.putIfAbsent(code, () => {}).add((
          date,
          _localName(d['label']! as String),
        ));
      }
    }
  }

  // 3b. Hand-checked local labour holidays (tool/holidays_es).
  if (manualDir != null && manualDir.existsSync()) {
    final manualFile = RegExp(r'^(\d{4})/(ES-[A-Z]{2})\.json$');
    final paths = [
      for (final e in manualDir.listSync(recursive: true))
        if (e is File) _relative(manualDir, e),
    ]..sort();
    for (final path in paths) {
      final m = manualFile.firstMatch(path);
      if (m == null) continue;
      final year = int.parse(m[1]!);
      final region = m[2]!;
      final where = 'holidays_es/$path';
      final json = jsonDecode(
        File('${manualDir.path}/$path').readAsStringSync(),
      ) as Map<String, Object?>;
      if (json['region'] != region || json['year'] != year) {
        throw FormatException('$where: region or year differ from the path');
      }
      if (json['kind'] != 'labour') {
        throw FormatException('$where: kind must be "labour"');
      }
      final sources = (json['sources']! as Map).cast<String, Object?>();
      for (final MapEntry(key: id, value: s) in sources.entries) {
        checkLabourSource(s, '$where, source $id');
      }
      final key = (region, year);
      final target = municipal.putIfAbsent(
        key,
        () => <String, Set<(String, String?)>>{},
      );
      final used = <String>{};
      final municipalities = (json['municipalities']! as Map)
          .cast<String, Object?>();
      for (final MapEntry(key: code, value: value) in municipalities.entries) {
        if (regionOfMunicipality(code)?.code != region) {
          throw FormatException('$where: $code is not in $region');
        }
        final entry = (value! as Map).cast<String, Object?>();
        final sourceId = entry['source'];
        if (sourceId is! String || !sources.containsKey(sourceId)) {
          throw FormatException('$where: $code has no known source');
        }
        used.add(sourceId);
        final days = (entry['days']! as List).cast<String>();
        if (days.isEmpty) throw FormatException('$where: $code has no days');
        for (final d in days) {
          _checkDate(d, year, where);
        }
        // Replaces whatever Mochila had for this municipality and year.
        target[code] = {for (final d in days) (d, null)};
      }
      for (final id in sources.keys.where(used.contains)) {
        final s = (sources[id]! as Map).cast<String, Object?>();
        final on = s['retrieved'];
        if (on is String) retrieved.add(on);
        addSource(key, {
          'url': s['url'],
          'ref': s['ref'],
          'published': s['published'],
        });
      }
    }

    // 3c. Canary island holidays: every municipality of the island.
    final islandsFile = File('${manualDir.path}/canarias-islands.json');
    if (islandsFile.existsSync()) {
      const where = 'holidays_es/canarias-islands.json';
      final json =
          jsonDecode(islandsFile.readAsStringSync()) as Map<String, Object?>;
      final islands = <String, List<String>>{};
      final seen = <String>{};
      for (final MapEntry(key: id, value: v)
          in (json['islands']! as Map).cast<String, Object?>().entries) {
        final codes = ((v! as Map)['municipalities']! as List).cast<String>();
        for (final code in codes) {
          if (regionOfMunicipality(code)?.code != 'ES-CN') {
            throw FormatException('$where: $code is not in ES-CN');
          }
          if (!seen.add(code)) {
            throw FormatException('$where: $code is on two islands');
          }
        }
        islands[id] = codes;
      }
      final years = (json['years']! as Map).cast<String, Object?>();
      for (final y in years.keys.toList()..sort()) {
        final year = int.parse(y);
        final entry = (years[y]! as Map).cast<String, Object?>();
        final s = (entry['source']! as Map).cast<String, Object?>();
        checkLabourSource(s, '$where, $y');
        final on = s['retrieved'];
        if (on is String) retrieved.add(on);
        final days = (entry['days']! as Map).cast<String, Object?>();
        final key = ('ES-CN', year);
        final target = municipal.putIfAbsent(
          key,
          () => <String, Set<(String, String?)>>{},
        );
        for (final MapEntry(key: id, value: codes) in islands.entries) {
          final day = days[id];
          if (day is! Map) throw FormatException('$where: $y has no $id day');
          final date = day['date']! as String;
          _checkDate(date, year, where);
          final name = '$islandHolidayPrefix (${day['name']! as String})';
          for (final code in codes) {
            final set = target.putIfAbsent(code, () => {});
            if (set.any((d) => d.$1 == date)) continue; // already local
            set.add((date, name));
          }
        }
        addSource(key, {
          'url': s['url'],
          'ref': s['ref'],
          'published': s['published'],
        });
      }
    }
  }
  final municipalKeys = municipal.keys.toList()
    ..sort((a, b) {
      final y = a.$2.compareTo(b.$2);
      return y != 0 ? y : a.$1.compareTo(b.$1);
    });
  for (final key in municipalKeys) {
    final (region, year) = key;
    if (!years.contains(year)) {
      notes.add(
        'municipal $region $year: no national file for $year, left out',
      );
      continue;
    }
    final codes = municipal[key]!.keys.toList()..sort();
    add(
      '$year/municipal/$region.json',
      {
        'schema': holidayBundleSchema,
        'year': year,
        'region': region,
        'municipalities': {
          for (final code in codes)
            code: [
              for (final (date, name)
                  in (municipal[key]![code]!.toList()..sort((a, b) {
                    final d = a.$1.compareTo(b.$1);
                    return d != 0 ? d : (a.$2 ?? '').compareTo(b.$2 ?? '');
                  })))
                {'date': date, 'name': ?name},
            ],
        },
      },
      kind: HolidayFileKind.municipal,
      year: year,
      region: region,
      source: _mergedSource(municipalSources[key]),
    );
  }

  // 4. municipalities.json.
  if (ineMunicipalities != null && ineMunicipalities.existsSync()) {
    final ine = (jsonDecode(ineMunicipalities.readAsStringSync()) as Map)
        .cast<String, String>();
    final byRegion = <String, Map<String, String>>{};
    for (final code in ine.keys.toList()..sort()) {
      final region = regionOfMunicipality(code);
      if (region == null) {
        notes.add('INE $code (${ine[code]}): unknown province, left out');
        continue;
      }
      byRegion.putIfAbsent(region.code, () => {})[code] = ine[code]!;
    }
    add('municipalities.json', {
      'schema': holidayBundleSchema,
      'regions': {
        for (final code in byRegion.keys.toList()..sort()) code: byRegion[code],
      },
    }, kind: HolidayFileKind.municipalities);
  } else {
    notes.add('municipalities.json: INE source not found, not generated');
  }

  // 5. {year}/<cc>.json of other countries: kept, not rebuilt.
  if (bundledCountries != null && bundledCountries.existsSync()) {
    final sources = countrySources != null && countrySources.existsSync()
        ? (jsonDecode(countrySources.readAsStringSync()) as Map)
              .cast<String, Object?>()
        : const <String, Object?>{};
    final countryFile = RegExp(r'^(\d{4})/([a-z]{2})\.json$');
    final found = <String, File>{};
    for (final entity in bundledCountries.listSync(recursive: true)) {
      if (entity is! File) continue;
      final relative = entity.path
          .substring(bundledCountries.path.length)
          .replaceAll('\\', '/')
          .replaceFirst(RegExp(r'^/'), '');
      final m = countryFile.firstMatch(relative);
      if (m == null || m[2] == 'es') continue;
      found[relative] = entity;
    }
    for (final relative in found.keys.toList()..sort()) {
      final m = countryFile.firstMatch(relative)!;
      final bytes = found[relative]!.readAsBytesSync();
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
      final country = (json['country'] as String?)?.toUpperCase();
      if (country != m[2]!.toUpperCase() || json['year'] != int.parse(m[1]!)) {
        throw FormatException('$relative: country/year do not match its name');
      }
      final source = sources[relative];
      if (source is! Map) {
        notes.add('$relative: no entry in the country sources file');
      } else if (source['published'] is String) {
        retrieved.add(source['published']! as String);
      }
      files[relative] = bytes;
      entries.add(
        HolidayManifestFile(
          path: relative,
          kind: HolidayFileKind.country,
          year: int.parse(m[1]!),
          country: country,
          sha256: sha256.convert(bytes).toString(),
          bytes: bytes.length,
          source: source is Map ? source.cast<String, Object?>() : null,
        ),
      );
    }
  }

  entries.sort((a, b) => a.path.compareTo(b.path));
  retrieved.sort();
  final digest = sha256
      .convert(
        utf8.encode(entries.map((e) => '${e.path}:${e.sha256}\n').join()),
      )
      .toString();
  final version =
      bundleVersion ??
      '${retrieved.isEmpty ? '0000-00-00' : retrieved.last}.${digest.substring(0, 8)}';
  final manifest = HolidayManifest(bundleVersion: version, files: entries);
  files['manifest.json'] = utf8.encode(
    encodeBundleJson(manifest.toJson(), lineDepth: 2),
  );
  return HolidayBundleBuild(
    files: Map.fromEntries(
      files.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    ),
    manifest: manifest,
    skipped: skipped..sort(),
    notes: notes,
  );
}

/// `[{date, name[, origin]}]` sorted by date then name, Spanish labels only.
List<Map<String, Object?>> _rows(
  Map<String, Object?> json,
  int year,
  String file, {
  bool withOrigin = false,
}) {
  final rows = <Map<String, Object?>>[];
  for (final h in (json['holidays']! as List).cast<Map<String, Object?>>()) {
    final date = h['date']! as String;
    _checkDate(date, year, file);
    final name = (h['label']! as Map)['es']! as String;
    if (withOrigin) {
      final origin = h['origin'];
      if (origin != 'regional' && origin != 'national-optional') {
        throw FormatException('$file: unknown origin $origin on $date');
      }
      rows.add({'date': date, 'name': name, 'origin': origin});
    } else {
      rows.add({'date': date, 'name': name});
    }
  }
  rows.sort((a, b) {
    final d = (a['date']! as String).compareTo(b['date']! as String);
    return d != 0 ? d : (a['name']! as String).compareTo(b['name']! as String);
  });
  return rows;
}

/// Words that give away a school calendar (non-teaching days, terms) rather
/// than the labour holidays of a municipality. A local holiday never comes
/// from one (Murcia's did until October 2026). Not «Educación» alone: the
/// Valencian ministry that publishes the local labour holidays has it in its
/// name.
final schoolSourcePattern = RegExp(
  r'escolar|\blectiv|non-teaching|curso\s+\d{4}|ensenyament|ikasturte',
  caseSensitive: false,
);

/// Throws unless [source] is `{url, ref, published}` with an http(s) url and
/// nothing in it that looks like a school calendar ([schoolSourcePattern]).
void checkLabourSource(Object? source, String where) {
  if (source is! Map) throw FormatException('$where: no source');
  final url = source['url'];
  final ref = source['ref'];
  if (url is! String || !RegExp(r'^https?://').hasMatch(url)) {
    throw FormatException('$where: bad url $url');
  }
  if (ref is! String || ref.trim().isEmpty) {
    throw FormatException('$where: no ref');
  }
  if (source['published'] is! String) {
    throw FormatException('$where: no published date');
  }
  if (schoolSourcePattern.hasMatch('$url $ref')) {
    throw FormatException('$where: looks like a school calendar ($ref)');
  }
}

/// One manifest `source` for a municipal file built from several acts: the
/// first one, plus the rest under `also` (in the order they were read).
Map<String, Object?>? _mergedSource(List<Map<String, Object?>>? sources) {
  if (sources == null || sources.isEmpty) return null;
  if (sources.length == 1) return sources.single;
  return {...sources.first, 'also': sources.skip(1).toList()};
}

void _checkDate(String date, int year, String file) {
  final parsed = CivilDate.parse(date);
  if (parsed.year != year) {
    throw FormatException('$file: $date is not in $year');
  }
}

/// `null` for a plain local holiday (the format's default name).
String? _localName(String raw) {
  if (raw == 'Festa local' || raw == 'Fiesta local') return null;
  final m = RegExp(r'^(?:Fiesta local|Festa local) (\(.+\))$').firstMatch(raw);
  return m != null ? 'Fiesta local ${m[1]}' : raw;
}

/// JSON with the first [lineDepth] levels of objects (and lists) one entry per
/// line, everything deeper compact. Keys keep their insertion order, so the
/// output is as deterministic as the data fed in. Ends with a newline.
String encodeBundleJson(Object? value, {int lineDepth = 1}) =>
    '${_encode(value, 0, lineDepth)}\n';

String _encode(Object? value, int depth, int lineDepth) {
  if (depth < lineDepth && value is Map) {
    final lines = [
      for (final MapEntry(key: k, value: v) in value.entries)
        '${jsonEncode(k)}:${_encode(v, depth + 1, lineDepth)}',
    ];
    return lines.isEmpty ? '{}' : '{\n${lines.join(',\n')}\n}';
  }
  if (depth < lineDepth && value is List) {
    final lines = [for (final v in value) _encode(v, depth + 1, lineDepth)];
    return lines.isEmpty ? '[]' : '[\n${lines.join(',\n')}\n]';
  }
  return jsonEncode(value);
}

/// Writes [build] into [out], removing stale `.json` files of an older bundle.
/// Returns the paths that changed.
List<String> writeHolidayBundle(Directory out, HolidayBundleBuild build) {
  final changed = <String>[];
  out.createSync(recursive: true);
  for (final entity in out.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.json')) continue;
    final relative = _relative(out, entity);
    if (!build.files.containsKey(relative)) {
      entity.deleteSync();
      changed.add('$relative (removed)');
    }
  }
  for (final MapEntry(key: path, value: bytes) in build.files.entries) {
    final file = File('${out.path}/$path');
    if (file.existsSync() && _same(file.readAsBytesSync(), bytes)) continue;
    file.createSync(recursive: true);
    file.writeAsBytesSync(bytes);
    changed.add(path);
  }
  // Drop folders left empty (a year that is gone).
  for (final entity in out.listSync(recursive: true).reversed) {
    if (entity is Directory && entity.listSync().isEmpty) entity.deleteSync();
  }
  return changed;
}

String _relative(Directory root, File file) {
  final r = root.absolute.path.replaceAll('\\', '/');
  final f = file.absolute.path.replaceAll('\\', '/');
  return f.substring(r.endsWith('/') ? r.length : r.length + 1);
}

bool _same(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// The asset folders `pubspec.yaml` has to declare for [build] (Flutter does
/// not scan sub-folders).
List<String> requiredAssetFolders(HolidayBundleBuild build) {
  final folders = <String>{};
  for (final path in build.files.keys) {
    final slash = path.lastIndexOf('/');
    folders.add(
      slash < 0
          ? 'assets/holidays/'
          : 'assets/holidays/${path.substring(0, slash)}/',
    );
  }
  return folders.toList()..sort();
}

Future<void> main(List<String> args) async {
  exitCode = await _run(args);
}

Future<int> _run(List<String> args) async {
  var mochila = '../../mochila-app/backend';
  var manual = 'tool/holidays_es';
  var out = 'assets/holidays';
  var check = false;
  String? version;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--mochila':
        mochila = args[++i];
      case '--manual':
        manual = args[++i];
      case '--out':
        out = args[++i];
      case '--bundle-version':
        version = args[++i];
      case '--check':
        check = true;
      default:
        stdout.writeln(
          'Uso: dart run tool/build_holidays.dart [--mochila <backend>] '
          '[--manual <tool/holidays_es>] [--out <carpeta>] '
          '[--bundle-version <v>] [--check]',
        );
        return args[i] == '--help' ? 0 : 64;
    }
  }
  final calendars = Directory('$mochila/src/calendars');
  if (!calendars.existsSync()) {
    stderr.writeln('No encuentro ${calendars.path} (usa --mochila).');
    return 66;
  }
  final build = buildHolidayBundle(
    calendarsDir: calendars,
    ineMunicipalities: File(
      '$mochila/scripts/calendars/sources/ine-municipios-es.json',
    ),
    manualDir: Directory(manual),
    bundleVersion: version,
    bundledCountries: Directory(out),
    countrySources: File('tool/country_holidays_sources.json'),
  );

  final outDir = Directory(out);
  if (check) {
    final stale = <String>[
      for (final MapEntry(key: path, value: bytes) in build.files.entries)
        if (!File('$out/$path').existsSync() ||
            !_same(File('$out/$path').readAsBytesSync(), bytes))
          path,
    ];
    if (stale.isNotEmpty) {
      stderr.writeln('El paquete está desactualizado: ${stale.join(', ')}');
      return 1;
    }
    stdout.writeln('El paquete está al día (${build.manifest.bundleVersion}).');
    return 0;
  }

  final changed = writeHolidayBundle(outDir, build);
  stdout.writeln('bundleVersion ${build.manifest.bundleVersion}');
  for (final f in build.manifest.files) {
    stdout.writeln(
      '  ${f.path.padRight(34)} ${f.bytes.toString().padLeft(7)} B',
    );
  }
  final total = build.files.values.fold<int>(0, (n, b) => n + b.length);
  stdout.writeln(
    '${build.files.length} archivos, $total B; '
    '${changed.isEmpty ? 'sin cambios' : '${changed.length} escritos'}',
  );
  if (build.skipped.isNotEmpty) {
    stdout.writeln('Omitidos (no verificados o sin publicar):');
    for (final s in build.skipped) {
      stdout.writeln('  $s');
    }
  }
  for (final n in build.notes) {
    stdout.writeln('Nota: $n');
  }
  final pubspec = File('pubspec.yaml');
  if (pubspec.existsSync()) {
    final text = pubspec.readAsStringSync();
    final missing = [
      for (final folder in requiredAssetFolders(build))
        if (!text.contains('- $folder')) folder,
    ];
    if (missing.isNotEmpty) {
      stdout.writeln('AVISO: faltan en pubspec.yaml (flutter: assets:):');
      for (final m in missing) {
        stdout.writeln('    - $m');
      }
    }
  }
  return 0;
}
