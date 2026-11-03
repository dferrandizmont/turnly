import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _langs = ['es', 'ca', 'gl', 'eu', 'en'];

Set<String> _stringsKeys(String path) {
  final text = File(path).readAsStringSync();
  final keys = <String>{};
  for (final line in text.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    final m = RegExp(r'^"(\w+)" = ".*";$').firstMatch(trimmed);
    expect(m, isNotNull, reason: 'Bad line in $path: $trimmed');
    keys.add(m!.group(1)!);
  }
  return keys;
}

void main() {
  final plist = File('ios/Runner/Info.plist').readAsStringSync();
  final pbx = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();

  test('every language has an InfoPlist.strings with the same keys', () {
    final es = _stringsKeys('ios/Runner/es.lproj/InfoPlist.strings');
    expect(es, isNotEmpty);
    for (final l in _langs) {
      final path = 'ios/Runner/$l.lproj/InfoPlist.strings';
      expect(File(path).existsSync(), isTrue, reason: path);
      expect(_stringsKeys(path), es, reason: path);
    }
  });

  test('every localized key exists in Info.plist', () {
    for (final key in _stringsKeys('ios/Runner/es.lproj/InfoPlist.strings')) {
      expect(plist.contains('<key>$key</key>'), isTrue, reason: key);
    }
  });

  test('Info.plist lists the five localizations', () {
    final m = RegExp(
      r'<key>CFBundleLocalizations</key>\s*<array>(.*?)</array>',
      dotAll: true,
    ).firstMatch(plist);
    expect(m, isNotNull);
    final found = RegExp(r'<string>(\w+)</string>')
        .allMatches(m!.group(1)!)
        .map((e) => e.group(1)!)
        .toList();
    expect(found, _langs);
  });

  test('project.pbxproj registers the files and the regions', () {
    for (final l in _langs) {
      expect(pbx.contains('path = $l.lproj/InfoPlist.strings;'), isTrue,
          reason: l);
    }
    final m = RegExp(r'knownRegions = \((.*?)\);', dotAll: true)
        .firstMatch(pbx);
    expect(m, isNotNull);
    final regions = RegExp(r'(\w+),')
        .allMatches(m!.group(1)!)
        .map((e) => e.group(1)!)
        .toSet();
    expect(regions, containsAll([..._langs, 'Base']));
  });
}
