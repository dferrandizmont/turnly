import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/widgets/choice_grid.dart';
import 'package:cuadrante/core/widgets/choice_pill.dart';
import 'package:cuadrante/features/patterns/application/pattern_wizard.dart';
import 'package:cuadrante/features/patterns/domain/pattern_blocks.dart';
import 'package:cuadrante/features/patterns/presentation/pattern_wizard_screen.dart';
import 'package:cuadrante/features/patterns/presentation/pattern_block_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_font.dart';
import '../../support/text_lines.dart';
import '../calendar/harness.dart';

// QA campaign, T06: the pattern wizard broke words at x2.0 on 320 dp
// («Correturno / s», «Atr / ás», H-T06-3); the builder's row of shifts was cut
// at the edge (H-T06-5) and «Varios turnos en un día» was not explained
// (H-T06-4).

Finder _key(String key) => find.byKey(ValueKey(key));

Future<void> _openWizard(
  WidgetTester tester, {
  required Size size,
  required double scale,
  Brightness brightness = Brightness.light,
}) async {
  await pumpCalendar(
    tester,
    size: size,
    textScale: scale,
    brightness: brightness,
  );
  await enterPaintMode(tester);
  await tester.tap(_key('paint-pattern'));
  await tester.pumpAndSettle();
  expect(find.text('Aplicar patrón'), findsOneWidget);
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(_key(key));
  await tester.pumpAndSettle();
  await tester.tap(_key(key));
  await tester.pumpAndSettle();
}

Future<void> _shortcut(WidgetTester tester, int days) async {
  await _tap(tester, 'block-days-$days');
}

/// Whole screen, scrolled to the top and then down to the end: nothing
/// breaks inside a word.
Future<void> _expectWholeWords(WidgetTester tester, String where) async {
  final scrollable = find.byType(Scrollable).first;
  final position = tester.state<ScrollableState>(scrollable).position;
  position.jumpTo(0);
  for (var i = 0; i < 30; i++) {
    await tester.pump();
    expect(brokenParagraphs(tester), isEmpty, reason: '$where (scroll $i)');
    if (position.pixels >= position.maxScrollExtent) break;
    position.jumpTo(
      (position.pixels + 300).clamp(0, position.maxScrollExtent).toDouble(),
    );
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeLocale();
    expect(await loadRoboto(), isTrue, reason: 'Roboto from the Flutter SDK');
  });

  for (final width in [320.0, 360.0, 412.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      final size = Size(width, width < 400 ? 640 : 892);
      final where = '$width dp, text $scale';

      testWidgets('$where: step 1 (the patterns)', (tester) async {
        await _openWizard(tester, size: size, scale: scale);
        await _expectWholeWords(tester, 'paso 1, $where');
        expect(tester.takeException(), isNull);
      });

      testWidgets('$where: steps 2 and 3, with «Atrás» and the main button', (
        tester,
      ) async {
        await _openWizard(tester, size: size, scale: scale);
        await _tap(tester, 'pattern-card-correturnos');
        await _tap(tester, 'pattern-next');
        expect(_key('pattern-back'), findsOneWidget);
        await _expectWholeWords(tester, 'paso 2, $where');
        await _tap(tester, 'pattern-next');
        expect(_key('pattern-apply'), findsOneWidget);
        await _expectWholeWords(tester, 'paso 3, $where');
        expect(tester.takeException(), isNull);
      });

      testWidgets('$where: «Crear el mío»', (tester) async {
        await _openWizard(tester, size: size, scale: scale);
        await _tap(tester, 'pattern-create-own');
        await _tap(tester, 'builder-add-morning');
        await _tap(tester, 'builder-add-night');
        await _expectWholeWords(tester, 'crear el mío, $where');

        // Every shift is there to tap, inside the screen (H-T06-5).
        final pucks = find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('builder-add-'),
        );
        expect(pucks, findsWidgets);
        for (final element in pucks.evaluate()) {
          final rect = tester.getRect(find.byWidget(element.widget));
          expect(rect.left, greaterThanOrEqualTo(0), reason: '$rect');
          expect(rect.right, lessThanOrEqualTo(width + 0.01), reason: '$rect');
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  group('H-T06-3: the buttons of the wizard', () {
    testWidgets('x2.0 on 320 dp: «Siguiente» on top, «Atrás» under it, both '
        'full width', (tester) async {
      await _openWizard(tester, size: const Size(320, 640), scale: 2.0);
      await _tap(tester, 'pattern-card-correturnos');
      await _tap(tester, 'pattern-next');
      final back = tester.getRect(_key('pattern-back'));
      final next = tester.getRect(_key('pattern-next'));
      expect(next.bottom, lessThanOrEqualTo(back.top));
      expect(back.width, closeTo(next.width, 0.5));
    });

    testWidgets('x1.0 on 412 dp: side by side, «Siguiente» wider', (
      tester,
    ) async {
      await _openWizard(tester, size: const Size(412, 892), scale: 1.0);
      await _tap(tester, 'pattern-card-correturnos');
      await _tap(tester, 'pattern-next');
      final back = tester.getRect(_key('pattern-back'));
      final next = tester.getRect(_key('pattern-next'));
      expect(back.right, lessThan(next.left));
      expect(back.top, closeTo(next.top, 0.5));
      expect(next.width, greaterThan(back.width));
    });
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      '320 dp, text $scale: palette adds three days and stays put when fixed',
      (tester) async {
        await _openWizard(tester, size: const Size(320, 640), scale: scale);
        await _tap(tester, 'pattern-create-own');
        final puck = _key('builder-add-morning');
        await tester.ensureVisible(puck);
        await tester.pumpAndSettle();
        final point = tester.getCenter(puck);
        final fixed = find
            .descendant(
              of: _key('pattern-step-choose'),
              matching: _key('builder-palette'),
            )
            .evaluate()
            .isEmpty;
        for (var i = 0; i < 3; i++) {
          if (fixed) {
            await tester.tapAt(point);
          } else {
            await _tap(tester, 'builder-add-morning');
          }
          await tester.pump();
          if (fixed) expect(tester.getCenter(puck), point);
        }
        expect(_key('builder-block-0'), findsOneWidget);
        expect(find.text('Mañana × 3 días'), findsOneWidget);
        expect(find.text('3 días'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '320 dp, text $scale: last preview row scrolls above fixed buttons',
      (tester) async {
        await _openWizard(tester, size: const Size(320, 640), scale: scale);
        await _tap(tester, 'pattern-card-correturnos');
        await _tap(tester, 'pattern-next');
        await _tap(tester, 'pattern-next');
        final scrollable = find.descendant(
          of: _key('pattern-step-end'),
          matching: find.byType(Scrollable),
        );
        final position = tester.state<ScrollableState>(scrollable).position;
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();
        final lastDay = tester.getRect(_key('preview-2026-11-30'));
        final viewport = tester.getRect(_key('pattern-step-end'));
        final apply = tester.getRect(_key('pattern-apply'));
        expect(lastDay.top, greaterThanOrEqualTo(viewport.top));
        expect(lastDay.bottom, lessThanOrEqualTo(viewport.bottom));
        expect(lastDay.bottom, lessThan(apply.top));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'builder rejects day 372 but still allows another shift on day 371',
    (tester) async {
      await _openWizard(tester, size: const Size(390, 844), scale: 1);
      await _tap(tester, 'pattern-create-own');
      final screen = tester.widget<PatternWizardScreen>(
        find.byType(PatternWizardScreen),
      );
      final args = (start: screen.start, shiftId: screen.shiftId);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PatternWizardScreen)),
      );
      final controller = container.read(patternWizardProvider(args).notifier);
      for (var day = 0; day < 371; day++) {
        expect(controller.appendShift('morning'), isTrue);
      }
      final before = container.read(patternWizardProvider(args)).draft;
      expect(controller.appendShift('morning'), isFalse);
      expect(container.read(patternWizardProvider(args)).draft, same(before));
      controller.setSameDay(true);
      expect(controller.appendShift('night'), isTrue);
      expect(container.read(patternWizardProvider(args)).draft, hasLength(371));
      expect(container.read(patternWizardProvider(args)).draft.last, [
        'morning',
        'night',
      ]);
    },
  );

  for (final (size, scale) in [
    (const Size(360, 640), 1.0),
    (const Size(360, 640), 2.0),
    (const Size(320, 568), 2.0),
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'inline shortcuts scroll above the palette at $size x$scale $brightness',
        (tester) async {
          await _openWizard(
            tester,
            size: size,
            scale: scale,
            brightness: brightness,
          );
          await _tap(tester, 'pattern-create-own');
          await _tap(tester, 'builder-add-morning');
          final controls = find.byType(PatternBlockControls);
          expect(
            find.descendant(of: controls, matching: find.byType(ChoiceGrid)),
            findsOneWidget,
          );
          expect(
            find.descendant(of: controls, matching: find.byType(ChoicePill)),
            findsNWidgets(5),
          );
          final palette = tester.getRect(_key('builder-palette'));
          final viewport = tester.getRect(_key('pattern-step-choose'));
          final fixed = find
              .descendant(
                of: _key('pattern-step-choose'),
                matching: _key('builder-palette'),
              )
              .evaluate()
              .isEmpty;
          for (final key in [
            'block-plus',
            'block-days-5',
            'block-days-7',
            'block-days-14',
            'block-days-21',
            'block-days-28',
            'block-options',
          ]) {
            await tester.ensureVisible(_key(key));
            await tester.pumpAndSettle();
            final rect = tester.getRect(_key(key));
            expect(rect.top, greaterThanOrEqualTo(viewport.top));
            expect(rect.bottom, lessThanOrEqualTo(viewport.bottom));
            expect(_key(key).hitTestable(), findsOneWidget);
            if (fixed) {
              expect(rect.bottom, lessThanOrEqualTo(palette.top));
              expect(tester.getRect(_key('builder-palette')), palette);
            }
            expect(brokenParagraphs(tester), isEmpty);
          }
          if (fixed) {
            expect(
              palette.bottom,
              lessThanOrEqualTo(tester.getTopLeft(_key('pattern-next')).dy),
            );
          }
          await tester.ensureVisible(_key('builder-add-morning'));
          await tester.pumpAndSettle();
          expect(_key('builder-add-morning').hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final (size, scale) in [
    (const Size(390, 844), 1.0),
    (const Size(320, 640), 1.0),
    (const Size(414, 896), 3.1),
  ]) {
    testWidgets(
      'a block just added is scrolled fully above the palette at $size x$scale',
      (tester) async {
        await _openWizard(tester, size: size, scale: scale);
        await _tap(tester, 'pattern-create-own');
        for (final id in [
          'morning',
          'afternoon',
          'night',
          'morning',
          'afternoon',
          'night',
        ]) {
          await _tap(tester, 'builder-add-$id');
          await tester.pumpAndSettle();
          final viewport = tester.getRect(_key('pattern-step-choose'));
          final fixed = find
              .descendant(
                of: _key('pattern-step-choose'),
                matching: _key('builder-palette'),
              )
              .evaluate()
              .isEmpty;
          for (final key in [
            'block-minus',
            'block-plus',
            'block-other-number',
          ]) {
            final rect = tester.getRect(_key(key));
            expect(
              rect.top,
              greaterThanOrEqualTo(viewport.top - 0.5),
              reason: '$key above the viewport after adding $id',
            );
            expect(
              rect.bottom,
              lessThanOrEqualTo(viewport.bottom + 0.5),
              reason: '$key below the viewport after adding $id',
            );
            if (fixed) {
              expect(
                rect.bottom,
                lessThanOrEqualTo(
                  tester.getRect(_key('builder-palette')).top + 0.5,
                ),
                reason: '$key under the pinned palette',
              );
            }
          }
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('at the largest text the palette joins the page', (tester) async {
    await _openWizard(tester, size: const Size(414, 896), scale: 3.1);
    await _tap(tester, 'pattern-create-own');
    // Not pinned under the sequence: it scrolls with the blocks.
    expect(
      find.descendant(
        of: _key('pattern-step-choose'),
        matching: _key('builder-palette'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('M N T for three weeks each takes six taps and gives 63 days', (
    tester,
  ) async {
    await _openWizard(tester, size: const Size(360, 640), scale: 1);
    await _tap(tester, 'pattern-create-own');
    final screen = tester.widget<PatternWizardScreen>(
      find.byType(PatternWizardScreen),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PatternWizardScreen)),
    );
    final provider = patternWizardProvider((
      start: screen.start,
      shiftId: screen.shiftId,
    ));
    final semantics = tester.ensureSemantics();
    for (final id in ['morning', 'night', 'afternoon']) {
      await _tap(tester, 'builder-add-$id');
      await _shortcut(tester, 21);
      final pill = tester.widget<ChoicePill>(_key('block-days-21'));
      expect(pill.selected, isTrue);
      expect(pill.expand, isTrue);
      expect(pill.reserveIcon, isTrue);
      expect(
        tester.getSemantics(_key('block-days-21')),
        matchesSemantics(
          isButton: true,
          isSelected: true,
          isEnabled: true,
          hasEnabledState: true,
          hasSelectedState: true,
          hasTapAction: true,
          label: '3 semanas',
        ),
      );
    }
    final draft = container.read(provider).draft;
    expect(draft, hasLength(63));
    for (final (index, id) in ['morning', 'night', 'afternoon'].indexed) {
      expect(draft.sublist(index * 21, (index + 1) * 21), everyElement([id]));
    }
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('same-day shifts are edited on the block sheet', (tester) async {
    await _openWizard(tester, size: const Size(390, 844), scale: 1);
    await _tap(tester, 'pattern-create-own');
    await _tap(tester, 'builder-add-morning');
    await _tap(tester, 'block-options');
    await _tap(tester, 'block-same-day');
    await _tap(tester, 'block-add-night');
    expect(_key('builder-block-0'), findsOneWidget);
    expect(_key('builder-block-1'), findsNothing);
    expect(find.text('Mañana + Noche × 1 día'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final (size, scale) in [
    (const Size(320, 568), 2.0),
    (const Size(390, 844), 1.0),
  ]) {
    testWidgets(
      'blocks: shortcuts set days, repeat is atomic and undo restores at $size',
      (tester) async {
        await _openWizard(tester, size: size, scale: scale);
        await _tap(tester, 'pattern-create-own');
        final screen = tester.widget<PatternWizardScreen>(
          find.byType(PatternWizardScreen),
        );
        final args = (start: screen.start, shiftId: screen.shiftId);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(PatternWizardScreen)),
        );
        final provider = patternWizardProvider(args);
        final controller = container.read(provider.notifier);

        for (var i = 0; i < 3; i++) {
          await _tap(tester, 'builder-add-morning');
        }
        expect(find.text('Mañana × 3 días'), findsOneWidget);
        expect(container.read(provider).blocks, hasLength(1));
        await _shortcut(tester, 21);
        expect(container.read(provider).draft, hasLength(21));
        await _shortcut(tester, 21);
        expect(
          container.read(provider).draft,
          hasLength(21),
          reason: 'a shortcut sets, never adds',
        );
        expect(find.text('21 días · 3 semanas'), findsWidgets);
        await _shortcut(tester, 7);
        await _tap(tester, 'builder-add-night');
        await _shortcut(tester, 7);
        await _tap(tester, 'builder-add-afternoon');
        await _shortcut(tester, 7);
        expect(container.read(provider).draft, hasLength(21));
        await _tap(tester, 'builder-block-0');
        await _tap(tester, 'block-options');
        await _tap(tester, 'block-repeat');
        // The «Más» sheet is gone while the dialog is open (iPad QA F3).
        expect(_key('block-up'), findsNothing);
        expect(_key('repeat-confirm'), findsOneWidget);
        await _tap(tester, 'repeat-plus');
        await _tap(tester, 'repeat-plus');
        expect(find.text('3 veces en total · 63 días'), findsOneWidget);
        await _tap(tester, 'repeat-confirm');
        expect(container.read(provider).draft, hasLength(63));
        expect(container.read(provider).blocks, hasLength(9));
        expect(find.text('63 días · 9 semanas'), findsOneWidget);
        await _tap(tester, 'builder-undo');
        expect(container.read(provider).draft, hasLength(21));
        expect(container.read(provider).blocks, hasLength(3));
        expect(container.read(provider).canUndoDraft, isFalse);
        expect(container.read(provider).openBlock, 0);
        expect(tester.takeException(), isNull);

        controller.replaceBlocks([
          PatternBlock(shiftIds: ['morning'], days: 200),
        ]);
        await tester.pumpAndSettle();
        await _tap(tester, 'block-options');
        await _tap(tester, 'block-repeat');
        await _tap(tester, 'repeat-plus');
        expect(find.text('1 vez en total · 200 días'), findsOneWidget);
        expect(
          find.text('El ciclo puede tener hasta 371 días.'),
          findsOneWidget,
        );
        await _tap(tester, 'repeat-plus');
        expect(find.text('1 vez en total · 200 días'), findsOneWidget);
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(find.text('Cerrar'), findsNothing);
        expect(_key('block-up'), findsNothing);

        controller.replaceBlocks([
          PatternBlock(shiftIds: ['morning'], days: maxPatternCycleDays),
        ]);
        await tester.pumpAndSettle();
        expect(controller.appendShift('night'), isFalse);
        expect(container.read(provider).draft, hasLength(maxPatternCycleDays));
        expect(
          tester.widget<InkWell>(_key('builder-add-morning')).onTap,
          isNull,
        );
        await _expectWholeWords(tester, 'full builder');
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'number, split, reorder, duplicate, remove and no shift preserve the draft',
    (tester) async {
      await _openWizard(tester, size: const Size(390, 844), scale: 1);
      await _tap(tester, 'pattern-create-own');
      final screen = tester.widget<PatternWizardScreen>(
        find.byType(PatternWizardScreen),
      );
      final args = (start: screen.start, shiftId: screen.shiftId);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PatternWizardScreen)),
      );
      final provider = patternWizardProvider(args);
      List<PatternBlock> blocks() => container.read(provider).blocks;

      await _tap(tester, 'builder-add-morning');
      await _tap(tester, 'block-other-number');
      await tester.enterText(_key('block-number'), '0');
      await tester.pump();
      final decoration = tester
          .widget<TextField>(_key('block-number'))
          .decoration!;
      expect(decoration.helperText, isNull);
      expect(decoration.errorText, isNotNull);
      expect(
        tester.widget<TextButton>(_key('block-number-confirm')).onPressed,
        isNull,
      );
      await tester.enterText(_key('block-number'), '10');
      await _tap(tester, 'block-number-confirm');
      expect(blocks().single.days, 10);
      await _tap(tester, 'block-options');
      await _tap(tester, 'block-split');
      await tester.enterText(_key('block-number'), '3');
      await _tap(tester, 'block-number-confirm');
      expect(blocks().map((b) => b.days), [3, 7]);
      // Both blocks keep their own controls even though the shifts match.
      await _tap(tester, 'builder-add-night');
      await _tap(tester, 'block-options');
      await _tap(tester, 'block-up');
      expect(blocks().map((b) => b.shiftIds.single), [
        'morning',
        'night',
        'morning',
      ]);
      // Open whichever block is collapsed after the move.
      if (container.read(provider).openBlock != 1) {
        await _tap(tester, 'builder-block-1');
      }
      await _tap(tester, 'block-options');
      await _tap(tester, 'block-duplicate');
      expect(blocks().map((b) => b.shiftIds.single), [
        'morning',
        'night',
        'night',
        'morning',
      ]);
      await _tap(tester, 'builder-undo');
      expect(blocks(), hasLength(3));
      expect(container.read(provider).openBlock, 1);
      await _tap(tester, 'block-options');
      await _tap(tester, 'block-down');
      expect(blocks().map((b) => b.shiftIds.single), [
        'morning',
        'morning',
        'night',
      ]);
      await _tap(tester, 'block-options');
      await _tap(tester, 'block-remove');
      expect(blocks(), hasLength(2));
      expect(blocks().map((b) => b.shiftIds.single), ['morning', 'morning']);
      await _tap(tester, 'builder-undo');
      expect(blocks(), hasLength(3));
      await _tap(tester, 'builder-block-0');
      await _tap(tester, 'block-options');
      await _tap(tester, 'block-change-shift');
      await _tap(tester, 'block-no-shift');
      expect(blocks().first.shiftIds, isEmpty);
      expect(blocks().first.days, 3);
      expect(find.text('Sin turno × 3 días'), findsOneWidget);
      await _tap(tester, 'builder-undo');
      expect(blocks().first.shiftIds, ['morning']);
      expect(tester.takeException(), isNull);
    },
  );
}
