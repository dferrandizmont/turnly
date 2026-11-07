import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/l10n/catalog_texts.dart';
import 'package:cuadrante/core/theme/shift_palette.dart';
import 'package:cuadrante/core/theme/shift_swatch.dart';
import 'package:cuadrante/features/onboarding/domain/profession.dart';
import 'package:cuadrante/features/patterns/domain/pattern_catalog.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_font.dart';
import '../../support/text_lines.dart';
import '../calendar/harness.dart';

/// Rotations of a corps (Policía Nacional 2-2-2-6, guard 1-4): where they are
/// listed, their texts in the five languages, their contrast and that the
/// selector holds them with large text. The sequences themselves are in
/// `schedule/domain/presets_test.dart`.
const _corps = ['pn-2-2-2-6', 'guard-1-4'];

Finder _key(String key) => find.byKey(ValueKey(key));

void main() {
  group('catalogue by corps', () {
    test('each one sits under its sector, once', () {
      expect(patternGroupPresets[PatternGroup.police], contains('pn-2-2-2-6'));
      expect(
        patternGroupPresets[PatternGroup.firefighters],
        containsAllInOrder(['24x72', 'guard-1-4']),
      );
      final all = [for (final ids in patternGroupPresets.values) ...ids];
      for (final id in _corps) {
        expect(all.where((i) => i == id), hasLength(1), reason: id);
      }
      expect(ungroupedPresets(), isEmpty);
    });

    test('the jobs of the corps offer them first', () {
      expect(Profession.police.presetIds.first, 'pn-2-2-2-6');
      expect(Profession.firefighters.presetIds, contains('guard-1-4'));
      // The first-use flow lists the job's rotations first and the rest of
      // the catalogue below: each one appears once in the whole list.
      final typical = Profession.firefighters.presetIds;
      expect(typical.toSet(), hasLength(typical.length));
    });

    test('they only use the factory shift types', () {
      final keys = {for (final t in shiftTemplates) t.key};
      for (final id in _corps) {
        expect(
          keys.containsAll(patternPresetById(id).templateKeys),
          isTrue,
          reason: id,
        );
      }
      // The Policía Nacional cycle ends its nights with the saliente.
      final pn = patternPresetById('pn-2-2-2-6').steps;
      expect(pn[5], ['night']);
      expect(pn[6], ['postNight']);
    });

    for (final brightness in Brightness.values) {
      test(
        'their shift colours keep AA text contrast (${brightness.name})',
        () {
          for (final id in _corps) {
            for (final key in patternPresetById(id).templateKeys) {
              final swatch = ShiftSwatch.forColor(
                shiftTemplateByKey(key).colorValue,
                brightness,
              );
              expect(
                contrastRatio(swatch.ink, swatch.tint),
                greaterThanOrEqualTo(kTextContrast),
                reason: '$id/$key on the cell',
              );
              expect(
                contrastRatio(swatch.ink, swatch.disc),
                greaterThanOrEqualTo(kTextContrast),
                reason: '$id/$key on the disc',
              );
            }
          }
        },
      );
    }

    for (final language in ['es', 'ca', 'gl', 'eu', 'en']) {
      test('$language: every preset has its name and description', () {
        final texts = catalogTextsFrom(
          lookupAppLocalizations(Locale(language)),
        );
        for (final preset in patternPresets) {
          final text = texts.presets[preset.id];
          expect(text, isNotNull, reason: '${preset.id} in $language');
          expect(text!.name.trim(), isNotEmpty, reason: preset.id);
          expect(text.description.trim(), isNotEmpty, reason: preset.id);
        }
        final names = [for (final t in texts.presets.values) t.name];
        expect(names.toSet(), hasLength(names.length), reason: 'names differ');
        expect(texts.presets['pn-2-2-2-6']!.name, contains('2-2-2-6'));
        expect(texts.presets['guard-1-4']!.name, contains('1-4'));
        // The 24 x 72 says it is also the 1-3.
        expect(texts.presets['24x72']!.description, contains('1-3'));
      });
    }
  });

  group('selector with large text', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await initializeLocale();
      expect(await loadRoboto(), isTrue, reason: 'Roboto from the Flutter SDK');
    });

    for (final (size, scale) in [
      (const Size(320, 640), 2.0),
      (const Size(360, 640), 1.3),
      (const Size(412, 892), 1.0),
    ]) {
      testWidgets('${size.width} dp, text $scale: cards of the corps whole', (
        tester,
      ) async {
        await pumpCalendar(tester, size: size, textScale: scale);
        await enterPaintMode(tester);
        await tester.tap(_key('paint-pattern'));
        await tester.pumpAndSettle();

        final scrollable = find.byType(Scrollable).first;
        // The brush is Mañana: the Policía Nacional one starts with it and
        // comes first, under «Empiezan por Mañana»; the guard is under
        // «Bomberos».
        for (final (group, id) in [
          (_key('pattern-group-typical'), 'pn-2-2-2-6'),
          (find.text('BOMBEROS'), 'guard-1-4'),
        ]) {
          await tester.scrollUntilVisible(
            _key('pattern-card-$id'),
            200,
            scrollable: scrollable,
          );
          await tester.pumpAndSettle();
          expect(brokenParagraphs(tester), isEmpty, reason: id);
          expect(tester.takeException(), isNull, reason: id);
          final card = _key('pattern-card-$id');
          expect(
            find.descendant(
              of: card,
              matching: find.text(patternPresetById(id).name),
            ),
            findsOneWidget,
          );
          // Under its own sector heading, not above it.
          expect(
            tester.getTopLeft(group).dy,
            lessThan(tester.getTopLeft(card).dy),
            reason: '$id under $group',
          );
        }
      });
    }
  });
}
