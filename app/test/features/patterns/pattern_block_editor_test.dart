import 'package:cuadrante/app.dart';
import 'package:cuadrante/features/patterns/application/pattern_wizard.dart';
import 'package:cuadrante/features/patterns/domain/pattern_blocks.dart';
import 'package:cuadrante/features/patterns/presentation/pattern_block_editor.dart';
import 'package:cuadrante/features/patterns/presentation/pattern_wizard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../calendar/harness.dart';

Finder _key(String key) => find.byKey(ValueKey(key));
ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(CuadranteApp)));

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(_key(key));
  await tester.pumpAndSettle();
  await tester.tap(_key(key));
  await tester.pumpAndSettle();
}

Future<PatternWizardArgs> _open(WidgetTester tester) async {
  await pumpCalendar(tester);
  await enterPaintMode(tester);
  await _tap(tester, 'paint-pattern');
  await _tap(tester, 'pattern-create-own');
  final screen = tester.widget<PatternWizardScreen>(
    find.byType(PatternWizardScreen),
  );
  final args = PatternWizardArgs(start: screen.start, shiftId: screen.shiftId);
  final wizard = _container(tester).read(patternWizardProvider(args).notifier);
  wizard.replaceBlocks([
    for (final id in ['morning', 'night', 'afternoon'])
      PatternBlock(shiftIds: [id], days: 2),
  ]);
  wizard.showBlock(1);
  await tester.pumpAndSettle();
  return args;
}

void main() {
  testWidgets(
    'Other number selects the duration and validates the signed input',
    (tester) async {
      final args = await _open(tester);
      await _tap(tester, 'block-other-number');
      final field = _key('block-number');
      final controller = tester.widget<TextField>(field).controller!;
      expect(controller.text, '2');
      expect(
        controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 1),
      );
      expect(tester.testTextInput.editingState!['selectionBase'], 0);
      expect(tester.testTextInput.editingState!['selectionExtent'], 1);

      for (final invalid in ['-', '-2', '0', '368', '999']) {
        await tester.enterText(field, invalid);
        await tester.pumpAndSettle();
        expect(controller.text, invalid);
        expect(
          tester.widget<TextField>(field).decoration!.errorText,
          'Escribe un número entre 1 y 367.',
        );
        expect(
          tester.widget<TextButton>(_key('block-number-confirm')).onPressed,
          isNull,
        );
      }
      await tester.enterText(field, '12');
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).decoration!.errorText, isNull);
      await _tap(tester, 'block-number-confirm');
      expect(
        _container(tester).read(patternWizardProvider(args)).blocks[1].days,
        12,
      );
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  for (final operation in ['remove', 'clear', 'append']) {
    testWidgets('undo restores the open block after $operation', (
      tester,
    ) async {
      final args = await _open(tester);
      final provider = patternWizardProvider(args);
      final wizard = _container(tester).read(provider.notifier);
      final before = _container(tester).read(provider).blocks;
      switch (operation) {
        case 'remove':
          await _tap(tester, 'block-options');
          await _tap(tester, 'block-remove');
        case 'clear':
          await _tap(tester, 'builder-clear');
        case 'append':
          wizard.appendShift('rest');
          await tester.pumpAndSettle();
      }
      await _tap(tester, 'builder-undo');
      expect(_container(tester).read(provider).blocks, before);
      expect(_container(tester).read(provider).openBlock, 1);
      expect(
        tester
            .widget<PatternBlockControls>(find.byType(PatternBlockControls))
            .index,
        1,
      );
      expect(_container(tester).read(provider).canUndoDraft, isFalse);

      wizard.showBlock(null);
      wizard.editBlocks(setBlockDays(before, 0, 3));
      wizard.showBlock(0);
      wizard.undoDraft();
      await tester.pumpAndSettle();
      expect(_container(tester).read(provider).openBlock, isNull);
      expect(find.byType(PatternBlockControls), findsNothing);
    });
  }
}
