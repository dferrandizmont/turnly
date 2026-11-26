import 'dart:async';

import 'package:cuadrante/app.dart';
import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/router.dart';
import 'package:cuadrante/core/theme/spacing.dart';
import 'package:cuadrante/core/widgets/buttons.dart';
import 'package:cuadrante/core/widgets/app_snack_bar.dart';
import 'package:cuadrante/features/calendar/application/schedule_controller.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/swaps/application/swaps_controller.dart';
import 'package:cuadrante/features/swaps/application/swaps_providers.dart';
import 'package:cuadrante/features/swaps/domain/shift_swap.dart';
import 'package:cuadrante/features/swaps/presentation/swap_sheet.dart';
import 'package:cuadrante/features/swaps/presentation/swaps_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_font.dart';
import '../calendar/day_sheet_finders.dart';
import '../calendar/harness.dart';

// P4 · «Libro de cambios» (/cambios): the balance of every colleague, the
// list of changes with their state, the sheet that creates and edits one,
// marking it returned or settled, and applying it to the calendar with a
// single undo step. Demo data of `pumpCalendar` (19 Oct 2026): the rotation
// gives Noche from the 19th to the 23rd; the 21st has Mañana + Tarde by
// hand and the 22nd is cleared.

const _today = CivilDate(2026, 10, 19);
const _oct21 = CivilDate(2026, 10, 21);
const _oct24 = CivilDate(2026, 10, 24);

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(CuadranteApp)));

/// Lets the database answer (real time) and the screen draw what it got.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 15)),
    );
    // A save indicator schedules frames while the transaction is pending.
    // Advance both clocks so the database can finish while it animates.
    await tester.pump(const Duration(milliseconds: 50));
    if (i >= 7 && !tester.binding.hasScheduledFrame) return;
  }
  expect(tester.binding.hasScheduledFrame, isFalse, reason: 'Swap UI settled');
}

Finder _key(String key) => find.byKey(ValueKey(key));

/// Registers a change in the ledger of the active calendar.
Future<ShiftSwap> _register(
  WidgetTester tester, {
  String colleague = 'Marta',
  CivilDate date = _oct21,
  SwapDirection direction = SwapDirection.theyOwe,
  CivilDate? returnDate,
  List<String>? givenShiftTypeIds,
  List<String>? receivedShiftTypeIds,
  String? note,
}) async {
  final container = _container(tester);
  final swap = await tester.runAsync(
    () => container
        .read(swapLedgerProvider.notifier)
        .register(
          colleague: colleague,
          date: date,
          direction: direction,
          returnDate: returnDate,
          givenShiftTypeIds: givenShiftTypeIds,
          receivedShiftTypeIds: receivedShiftTypeIds,
          note: note,
        ),
  );
  await _settle(tester);
  return swap!;
}

/// The changes stored, straight from the repository.
Future<List<ShiftSwap>> _stored(WidgetTester tester) async {
  final repository = _container(tester).read(shiftSwapsRepositoryProvider);
  return (await tester.runAsync(() => repository.list()))!;
}

Future<void> _open(WidgetTester tester) async {
  _container(tester).read(routerProvider).go(AppRoutes.swaps);
  await _settle(tester);
}

/// Opens the menu of a change and chooses an action.
Future<void> _menu(WidgetTester tester, String swapId, String actionKey) async {
  await tester.tap(_key('swap-menu-$swapId'));
  await tester.pumpAndSettle();
  await tester.tap(_key(actionKey));
  await _settle(tester);
}

/// The shifts a day has, as the schedule resolves them.
List<String> _ids(WidgetTester tester, CivilDate date) =>
    _container(tester)
        .read(scheduleControllerProvider)
        .schedule
        .resolve(date)
        .shiftIds;

/// Opens the sheet of a new change that starts on [date].
Future<void> _openSheet(WidgetTester tester, {CivilDate date = _oct21}) async {
  unawaited(
    showSwapSheet(tester.element(find.byType(SwapsScreen)), date: date),
  );
  await _settle(tester);
}

/// Types the name, picks the shift the person gives and taps «Guardar».
Future<void> _fillAndSave(WidgetTester tester) async {
  await _fill(tester);
  await _tapSave(tester);
}

/// Types the name and picks the morning shift as the one that is given.
Future<void> _fill(WidgetTester tester) async {
  await tester.enterText(_key('swap-field-colleague'), 'Raúl');
  await tester.ensureVisible(_key('swap-given-morning'));
  await tester.tap(_key('swap-given-morning'));
  await tester.pumpAndSettle();
}

Future<void> _tapSave(WidgetTester tester) async {
  await tester.ensureVisible(_key('swap-save'));
  await tester.pumpAndSettle();
  await tester.tap(_key('swap-save'));
  await _settle(tester);
}

/// The value of the sheet's «Cambiar también mi cuadrante» switch.
bool _switchOn(WidgetTester tester) =>
    tester.widget<SwitchListTile>(_key('swap-apply-switch')).value;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeLocale();
    expect(await loadRoboto(), isTrue, reason: 'Roboto from the Flutter SDK');
  });

  testWidgets('the balance and the list show what the logic computes', (
    tester,
  ) async {
    await pumpCalendar(tester, size: const Size(390, 1600));
    await _register(
      tester,
      colleague: 'Marta',
      givenShiftTypeIds: const ['morning'],
    );
    await _register(tester, colleague: 'Luis', direction: SwapDirection.iOwe);
    await _open(tester);

    expect(find.byType(SwapsScreen), findsOneWidget);
    // The balance: what each one owes.
    expect(
      find.descendant(of: _key('swap-balances'), matching: find.text('Marta')),
      findsOneWidget,
    );
    expect(find.text('Me debe 1 turno'), findsOneWidget);
    expect(find.text('Le debo 1 turno'), findsOneWidget);
    // The changes, with their state.
    expect(find.text('Pendiente'), findsNWidgets(2));
    expect(find.text('Marta · Me lo deben'), findsOneWidget);
    expect(find.text('Luis · Se lo debo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the pending ones come first in the balance', (tester) async {
    await pumpCalendar(tester, size: const Size(390, 1600));
    // A settled change does not count in the balance.
    final settled = await _register(
      tester,
      colleague: 'Ana',
      givenShiftTypeIds: const ['morning'],
    );
    await _register(tester, colleague: 'Luis', direction: SwapDirection.iOwe);
    final controller = _container(tester).read(swapLedgerProvider.notifier);
    await tester.runAsync(() => controller.settle(settled.id));
    await _settle(tester);
    await _open(tester);

    final balances = _container(tester).read(swapLedgerProvider).value!;
    expect(balances.balances.first.colleague, 'Luis');
    expect(balances.balances.last.colleague, 'Ana');
    expect(find.text('Nada pendiente'), findsOneWidget);
  });

  testWidgets('a change is created from the sheet and stored', (tester) async {
    await pumpCalendar(tester, size: const Size(390, 1600));
    await _open(tester);
    expect(_key('swap-empty'), findsOneWidget);
    expect(find.text('Todavía no hay cambios'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Añadir cambio'));
    await _settle(tester);
    expect(find.text('Nuevo cambio'), findsOneWidget);

    // Without a name the sheet says what is missing and stays. The pills
    // carry the hours now, so the sheet is taller than the view: the button
    // is brought into view first.
    await tester.ensureVisible(_key('swap-save'));
    await tester.tap(_key('swap-save'));
    await _settle(tester);
    expect(find.text('Escribe con quién es el cambio.'), findsOneWidget);
    expect(await _stored(tester), isEmpty);

    await tester.enterText(_key('swap-field-colleague'), 'Marta');
    await tester.ensureVisible(_key('swap-direction-they-owe'));
    await tester.tap(_key('swap-direction-they-owe'));
    await tester.ensureVisible(_key('swap-given-morning'));
    await tester.tap(_key('swap-given-morning'));
    await tester.enterText(_key('swap-field-note'), 'Me lo devuelve el lunes');
    // The sheet is still growing under the pills when the note is typed:
    // let it settle before bringing the button into view.
    await tester.pumpAndSettle();
    await tester.ensureVisible(_key('swap-save'));
    await tester.pumpAndSettle();
    await tester.tap(_key('swap-save'));
    await _settle(tester);

    expect(find.text('Nuevo cambio'), findsNothing);
    final stored = await _stored(tester);
    expect(stored, hasLength(1));
    expect(stored.single.colleague, 'Marta');
    expect(stored.single.direction, SwapDirection.theyOwe);
    expect(stored.single.givenShiftTypeIds, const ['morning']);
    expect(stored.single.note, 'Me lo devuelve el lunes');
    // Without a day of its own it starts today.
    expect(stored.single.date, _today);
    // And it is in the list, with the shift it gives.
    expect(find.text('Marta · Me lo deben'), findsOneWidget);
    expect(find.text('Cedes: Mañana'), findsOneWidget);
  });

  testWidgets('the sheet edits a change', (tester) async {
    await pumpCalendar(tester, size: const Size(390, 1600));
    final swap = await _register(tester, note: 'Sin más');
    await _open(tester);

    await _menu(tester, swap.id, 'swap-menu-edit');
    expect(find.text('Editar cambio'), findsOneWidget);
    await tester.enterText(_key('swap-field-note'), 'Me lo devuelve el lunes');
    await tester.ensureVisible(_key('swap-save'));
    await tester.tap(_key('swap-save'));
    await _settle(tester);

    final stored = await _stored(tester);
    expect(stored.single.note, 'Me lo devuelve el lunes');
    expect(stored.single.id, swap.id);
  });

  testWidgets('an unchanged sheet keeps calendar redo', (tester) async {
    var now = fixedNow;
    await pumpCalendar(tester, size: const Size(390, 1600), clock: () => now);
    final swap = await _register(tester);
    final container = _container(tester);
    final schedule = container.read(scheduleControllerProvider.notifier);
    schedule.clearDays([_oct21]);
    expect(schedule.undo(), isTrue);
    await _open(tester);

    now = now.add(const Duration(minutes: 1));
    await _menu(tester, swap.id, 'swap-menu-edit');
    await _tapSave(tester);

    expect((await _stored(tester)).single, swap);
    expect(schedule.undo(), isFalse);
    expect(schedule.redo(), isTrue);
  });

  group('«Guardar» stays in reach in landscape at text x2.0 (QA M3)', () {
    const size = Size(844, 390);
    const name = 'Lucía Nueva';

    /// The changes of [name] that are stored.
    Future<List<ShiftSwap>> storedOf(WidgetTester tester) async => [
      for (final swap in await _stored(tester))
        if (swap.colleague == name) swap,
    ];

    testWidgets('pinned: on screen with no swipe, and the form scrolls', (
      tester,
    ) async {
      await pumpCalendar(tester, size: size, textScale: 2);
      await _register(tester);
      await _open(tester);
      await tester.tap(_key('swap-add'));
      await _settle(tester);
      expect(find.text('Nuevo cambio'), findsOneWidget);

      // Without a single swipe: the button is on screen and answers a tap.
      final save = tester.getRect(_key('swap-save'));
      expect(save.top, greaterThanOrEqualTo(0));
      expect(save.bottom, lessThanOrEqualTo(size.height + 0.5));
      await tester.tap(_key('swap-save'));
      await _settle(tester);
      expect(find.text('Escribe con quién es el cambio.'), findsOneWidget);

      // The form still scrolls behind it, and the button does not move.
      await tester.ensureVisible(_key('swap-field-note'));
      await tester.pumpAndSettle();
      expect(tester.getRect(_key('swap-save')), save);
      await tester.enterText(_key('swap-field-colleague'), name);
      await tester.tap(_key('swap-save'));
      await _settle(tester);
      expect(find.text('Nuevo cambio'), findsNothing);
      final stored = await storedOf(tester);
      expect(stored, hasLength(1));
      expect(stored.single.date, _today);
      // The one that was there is untouched.
      expect(await _stored(tester), hasLength(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('with the keyboard up it joins the form, which scrolls to it', (
      tester,
    ) async {
      await pumpCalendar(tester, size: size, textScale: 2);
      await _register(tester);
      await _open(tester);
      await tester.tap(_key('swap-add'));
      await _settle(tester);
      // The keyboard takes most of a landscape phone: a pinned button would
      // take the little that is left, so it goes to the end of the form.
      tester.view.viewInsets = FakeViewPadding(
        bottom: 220 * tester.view.devicePixelRatio,
      );
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.enterText(_key('swap-field-colleague'), name);
      final scrollable = find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          )
          .first;
      // It is in the scroll: not on screen until the form is scrolled to it.
      expect(
        find.descendant(of: scrollable, matching: _key('swap-save')),
        findsOneWidget,
      );
      // The field that was typed in is done with: it would pull the form
      // back to itself as the view changes.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        _key('swap-save'),
        100,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      final rect = tester.getRect(_key('swap-save'));
      expect(rect.bottom, lessThanOrEqualTo(size.height - 220 + 0.5));
      await tester.tap(_key('swap-save'));
      await _settle(tester);
      expect(find.text('Nuevo cambio'), findsNothing);
      expect(await storedOf(tester), hasLength(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('editing: «Quitar» is reachable and asks first', (
      tester,
    ) async {
      await pumpCalendar(tester, size: size, textScale: 2);
      final swap = await _register(tester, colleague: name);
      await _open(tester);
      await tester.scrollUntilVisible(
        _key('swap-menu-${swap.id}'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await _menu(tester, swap.id, 'swap-menu-edit');
      expect(find.text('Editar cambio'), findsOneWidget);
      // «Guardar» is pinned, «Quitar» is at the end of the form.
      expect(
        tester.getRect(_key('swap-save')).bottom,
        lessThanOrEqualTo(size.height + 0.5),
      );
      await tester.ensureVisible(_key('swap-remove'));
      await tester.pumpAndSettle();
      await tester.tap(_key('swap-remove'));
      await _settle(tester);
      expect(find.text('¿Quitar este cambio?'), findsOneWidget);
      // Cancelling keeps it.
      await tester.tap(find.text('Cancelar'));
      await _settle(tester);
      expect(await storedOf(tester), hasLength(1));
      // Confirming removes it.
      await tester.ensureVisible(_key('swap-remove'));
      await tester.tap(_key('swap-remove'));
      await _settle(tester);
      await tester.tap(_key('swap-remove-confirm'));
      await _settle(tester);
      expect(await storedOf(tester), isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  group('the sheet leads the person to what is missing (QA M7, N20)', () {
    const size = Size(390, 560);

    /// Whether [finder] is inside the visible part of the sheet's form.
    bool inView(WidgetTester tester, Finder finder) {
      final scroll = tester.getRect(
        find
            .descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(SingleChildScrollView),
            )
            .first,
      );
      final rect = tester.getRect(finder);
      return rect.top >= scroll.top - 0.5 && rect.bottom <= scroll.bottom + 0.5;
    }

    testWidgets('save with the name empty takes you to the field', (
      tester,
    ) async {
      await pumpCalendar(tester, size: size);
      await _open(tester);
      await _openSheet(tester);
      // The person is down in the form, the name out of sight.
      await tester.ensureVisible(_key('swap-field-note'));
      await tester.pumpAndSettle();
      expect(inView(tester, _key('swap-field-colleague')), isFalse);

      await tester.tap(_key('swap-save'));
      await _settle(tester);
      await tester.pumpAndSettle();

      final error = find.text('Escribe con quién es el cambio.');
      expect(error, findsOneWidget);
      expect(inView(tester, _key('swap-field-colleague')), isTrue);
      expect(inView(tester, error), isTrue);
      final field = tester.widget<TextField>(_key('swap-field-colleague'));
      expect(field.focusNode!.hasFocus, isTrue);
      expect(find.text('Nuevo cambio'), findsOneWidget);
      expect(await _stored(tester), isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('with reduced motion it gets there without animating', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpCalendar(tester, size: size);
      await _open(tester);
      await _openSheet(tester);
      await tester.ensureVisible(_key('swap-field-note'));
      await tester.pumpAndSettle();
      await tester.tap(_key('swap-save'));
      // A few frames are enough: there is no scroll animation to wait for.
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }
      expect(inView(tester, _key('swap-field-colleague')), isTrue);
    });

    testWidgets('the name hint reads as an example, not as a filled name', (
      tester,
    ) async {
      await pumpCalendar(tester, size: size);
      await _open(tester);
      await _openSheet(tester);
      expect(find.text('Por ejemplo: Marta'), findsOneWidget);
    });

    testWidgets('a date picker closes the keyboard before it opens', (
      tester,
    ) async {
      await pumpCalendar(tester, size: size);
      await _open(tester);
      await _openSheet(tester);
      await tester.tap(_key('swap-field-colleague'));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(_key('swap-field-colleague'));
      expect(field.focusNode!.hasFocus, isTrue);

      // Straight from the button's callback: a tap would also close the
      // keyboard through the sheet's own tap-away, hiding what is tested.
      await tester.ensureVisible(_key('swap-field-return-date'));
      await tester.pumpAndSettle();
      tester
          .widget<SecondaryButton>(_key('swap-field-return-date'))
          .onPressed!();
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);

      // Cancelling does not bring the keyboard back.
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsNothing);
      expect(field.focusNode!.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
    });

    testWidgets(
      'a focused date button keeps its focus when the picker closes',
      (tester) async {
        await pumpCalendar(tester, size: size);
        await _open(tester);
        await _openSheet(tester);
        await tester.ensureVisible(_key('swap-field-return-date'));
        await tester.pumpAndSettle();
        final label = find.descendant(
          of: _key('swap-field-return-date'),
          matching: find.byType(Text),
        );
        final node = Focus.of(tester.element(label));
        node.requestFocus();
        await tester.pump();
        expect(node.hasPrimaryFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.byType(DatePickerDialog), findsOneWidget);

        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(find.byType(DatePickerDialog), findsNothing);
        expect(node.hasPrimaryFocus, isTrue);
      },
    );

    testWidgets('a note too long by UTF-16 units is refused on the note', (
      tester,
    ) async {
      await pumpCalendar(tester, size: size);
      await _open(tester);
      await _openSheet(tester);
      await tester.enterText(_key('swap-field-colleague'), 'Raúl');
      // 1,999 letters and an emoji: 2,000 characters, so the field's limit
      // lets it through, but 2,001 UTF-16 units, which the swap refuses.
      await tester.ensureVisible(_key('swap-field-note'));
      await tester.enterText(_key('swap-field-note'), '${'a' * 1999}\u{1F600}');
      await tester.pumpAndSettle();
      final note = tester.widget<TextField>(_key('swap-field-note'));
      expect(note.controller!.text.length, 2001);

      // The person is back at the top, out of sight of the note.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.ensureVisible(_key('swap-field-colleague'));
      await tester.pumpAndSettle();
      expect(inView(tester, _key('swap-field-note')), isFalse);

      await tester.tap(_key('swap-save'));
      await _settle(tester);
      await tester.pumpAndSettle();

      final error = find.text('La nota es demasiado larga. Acórtala.');
      expect(error, findsOneWidget);
      expect(inView(tester, error), isTrue);
      expect(note.focusNode!.hasFocus, isTrue);
      expect(find.text('Nuevo cambio'), findsOneWidget);
      expect(await _stored(tester), isEmpty);

      // Shortened to what fits, it saves.
      await tester.enterText(_key('swap-field-note'), 'a' * 1999);
      await tester.pumpAndSettle();
      expect(error, findsNothing);
      await _tapSave(tester);
      expect(find.text('Nuevo cambio'), findsNothing);
      final stored = (await _stored(tester)).single;
      expect(stored.note!.length, 1999);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pasting into a full note keeps the text and the cursor', (
      tester,
    ) async {
      await pumpCalendar(tester, size: size);
      await _open(tester);
      await _openSheet(tester);
      await tester.ensureVisible(_key('swap-field-note'));
      final full = String.fromCharCodes([
        for (var i = 0; i < maxSwapNoteLength; i++) 97 + i % 26,
      ]);
      await tester.enterText(_key('swap-field-note'), full);
      await tester.pumpAndSettle();
      final note = tester.widget<TextField>(_key('swap-field-note'));
      expect(note.controller!.text, full);

      // The cursor in the middle, then a letter pasted there: the field is
      // full, so the standard limit refuses the paste and keeps the whole
      // text and the cursor where they were (nothing at the end is eaten).
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: full,
          selection: const TextSelection.collapsed(offset: 5),
        ),
      );
      await tester.pump();
      expect(note.controller!.selection.baseOffset, 5);
      final pasted = '${full.substring(0, 5)}X${full.substring(5)}';
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: pasted,
          selection: const TextSelection.collapsed(offset: 6),
        ),
      );
      await tester.pump();
      expect(note.controller!.text, full);
      expect(note.controller!.selection.baseOffset, 5);
    });
  });

  testWidgets('a notice leaves room under the list (QA N33)', (tester) async {
    // The clock moves between the two changes, so the book lists them in a
    // fixed order (the newer one first) and not by their random ids.
    var now = fixedNow;
    await pumpCalendar(tester, size: const Size(390, 700), clock: () => now);
    // Raúl first, so that Marta is the newer card and Raúl's is the lower.
    final raul = await _register(
      tester,
      colleague: 'Raúl',
      givenShiftTypeIds: const ['afternoon'],
    );
    now = now.add(const Duration(minutes: 1));
    final marta = await _register(tester, givenShiftTypeIds: const ['morning']);
    await _open(tester);
    double bottomPadding() => tester
        .widget<ListView>(find.byType(ListView).first)
        .padding!
        .resolve(TextDirection.ltr)
        .bottom;
    expect(bottomPadding(), Sp.section);

    final first = _key('swap-apply-${marta.id}');
    await tester.ensureVisible(first);
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.tap(first);
    await _settle(tester);
    expect(find.text('Cambio aplicado al cuadrante'), findsOneWidget);

    final cover = _container(tester).read(snackBarCoverProvider);
    expect(cover, isNotNull);
    expect(bottomPadding(), Sp.section + cover!);

    // With the notice still up, the other change's button is in the list,
    // clear of the notice, and answers a real tap with the refusal.
    final second = _key('swap-apply-${raul.id}');
    await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Cambio aplicado al cuadrante'), findsOneWidget);
    expect(second.hitTestable(), findsOneWidget);
    await tester.tap(second);
    await _settle(tester);
    expect(
      find.textContaining('ya tiene otro cambio aplicado'),
      findsOneWidget,
    );
    expect(find.textContaining('Marta'), findsWidgets);

    // The notice goes away by itself and the room goes with it.
    await tester.pump(kSnackBarDuration + const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(_container(tester).read(snackBarCoverProvider), isNull);
    expect(bottomPadding(), Sp.section);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a change is marked as returned and as settled', (tester) async {
    await pumpCalendar(tester, size: const Size(390, 1600));
    final swap = await _register(tester);
    await _open(tester);

    // Returned: the day the favour comes back.
    await _menu(tester, swap.id, 'swap-menu-returned');
    expect(find.text('¿Qué día te lo devuelven?'), findsOneWidget);
    await tester.tap(find.text('Aceptar'));
    await _settle(tester);
    expect(find.text('Con fecha'), findsOneWidget);
    expect(
      find.text('Cedes el 21 oct 2026 y recibes el 21 oct 2026'),
      findsOneWidget,
    );
    expect((await _stored(tester)).single.returnDate, _oct21);
    expect((await _stored(tester)).single.isReturned, isFalse);

    // Settled: it leaves the pending list and the balance.
    await _menu(tester, swap.id, 'swap-menu-settle');
    await _settle(tester);
    expect(find.text('Saldado'), findsOneWidget);
    expect((await _stored(tester)).single.isReturned, isTrue);
    expect(_container(tester).read(swapLedgerProvider).value!.pending, isEmpty);

    // And it can be owed again.
    await _menu(tester, swap.id, 'swap-menu-reopen');
    await _settle(tester);
    expect(
      _container(tester).read(swapLedgerProvider).value!.pending,
      hasLength(1),
    );
  });

  testWidgets('changing the return date confirms the date was saved', (
    tester,
  ) async {
    await pumpCalendar(tester, size: const Size(390, 1600));
    final swap = await _register(tester, returnDate: _oct24);
    await _open(tester);

    await _menu(tester, swap.id, 'swap-menu-returned');
    await tester.tap(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.text('25'),
      ),
    );
    await tester.tap(find.text('Aceptar'));
    await _settle(tester);

    expect(find.text('Fecha de devolución guardada'), findsOneWidget);
    expect(find.text('Cambio marcado como devuelto'), findsNothing);
    final stored = (await _stored(tester)).single;
    expect(stored.returnDate, const CivilDate(2026, 10, 25));
    expect(stored.isReturned, isFalse);
  });

  testWidgets('a change is applied to the calendar and undone', (tester) async {
    await pumpCalendar(tester, size: const Size(390, 1600));
    final swap = await _register(
      tester,
      givenShiftTypeIds: const ['morning'],
      receivedShiftTypeIds: const ['morning'],
      returnDate: _oct24,
    );
    await _open(tester);

    // The day it gives loses the shift and the day it comes back gets it.
    expect(
      find.text('Cedes el 21 oct 2026 y recibes el 24 oct 2026'),
      findsOneWidget,
    );
    expect(_ids(tester, _oct21), const ['morning', 'afternoon']);
    expect(_ids(tester, _oct24), const ['rest']);

    await tester.tap(_key('swap-menu-${swap.id}'));
    await tester.pumpAndSettle();
    expect(_key('swap-menu-apply'), findsNothing);
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    await tester.tap(_key('swap-apply-${swap.id}'));
    await tester.tap(_key('swap-apply-${swap.id}'));
    await _settle(tester);
    expect(find.text('Cambio aplicado al cuadrante'), findsOneWidget);
    expect(_ids(tester, _oct21), const ['afternoon']);
    expect(_ids(tester, _oct24), const ['morning']);

    // «Deshacer» takes the whole change back, in one step.
    await tester.tap(find.text('Deshacer'));
    await _settle(tester);
    expect(_ids(tester, _oct21), const ['morning', 'afternoon']);
    expect(_ids(tester, _oct24), const ['rest']);
  });

  testWidgets('a change is taken off the calendar again', (tester) async {
    await pumpCalendar(tester, size: const Size(390, 1600));
    final swap = await _register(
      tester,
      givenShiftTypeIds: const ['morning'],
      receivedShiftTypeIds: const ['morning'],
      returnDate: _oct24,
    );
    await _open(tester);

    await tester.tap(_key('swap-apply-${swap.id}'));
    await _settle(tester);
    expect(_ids(tester, _oct21), const ['afternoon']);

    await _menu(tester, swap.id, 'swap-menu-unapply');
    await _settle(tester);
    expect(find.text('Cambio quitado del cuadrante'), findsOneWidget);
    expect(_ids(tester, _oct21), const ['morning', 'afternoon']);
    expect(_ids(tester, _oct24), const ['rest']);
  });

  testWidgets(
    'removing an applied swap without a snapshot preserves both days',
    (tester) async {
      await pumpCalendar(tester, size: const Size(390, 1600));
      // The old override is already present in the schedule, but there is no
      // swap application snapshot for either day.
      const givenDate = CivilDate(2026, 10, 22);
      final swap = await _register(
        tester,
        date: givenDate,
        givenShiftTypeIds: const ['morning'],
        receivedShiftTypeIds: const ['rest'],
        returnDate: _oct24,
      );
      await _open(tester);
      await _menu(tester, swap.id, 'swap-menu-unapply');
      expect(
        find.textContaining('No hay datos para recuperar los turnos'),
        findsOneWidget,
      );
      expect(_ids(tester, givenDate), isEmpty);
      expect(_ids(tester, _oct24), const ['rest']);
      expect(_key('swap-card-${swap.id}'), findsOneWidget);
    },
  );

  testWidgets('a change is removed and can be brought back', (tester) async {
    await pumpCalendar(tester, size: const Size(390, 1600));
    final swap = await _register(tester);
    await _open(tester);

    await _menu(tester, swap.id, 'swap-menu-remove');
    await _settle(tester);
    expect(await _stored(tester), isEmpty);
    expect(find.text('Cambio quitado'), findsOneWidget);

    await tester.tap(find.text('Deshacer'));
    await _settle(tester);
    expect(await _stored(tester), hasLength(1));
    expect((await _stored(tester)).single.id, swap.id);
  });

  testWidgets('the day detail shows the change of that day', (tester) async {
    await pumpCalendar(tester, size: const Size(390, 1600));
    await _register(tester);
    await _settle(tester);

    await revealCell(tester, _oct21);
    await tester.tap(cell(_oct21));
    await tester.pumpAndSettle();
    await openDayMore(tester);

    expect(_key('day-swap-section'), findsOneWidget);
    expect(find.text('CAMBIO DE TURNO'), findsOneWidget);
    expect(
      find.descendant(
        of: _key('day-swap-section'),
        matching: find.text('Marta · Me lo deben'),
      ),
      findsOneWidget,
    );
    expect(_key('day-swap-add'), findsOneWidget);

    // The section is named in the summary of «Más opciones».
    expect(
      tester.widget<Text>(_key('day-more-summary')).data,
      contains('Cambio de turno'),
    );

    // From there a change of that day can be noted. The section sits under
    // the attachments and tasks ones, so it has to be brought into view.
    await revealDayControl(tester, 'day-swap-add');
    await tester.tap(_key('day-swap-add'));
    await _settle(tester);
    expect(find.text('Nuevo cambio'), findsOneWidget);
  });

  testWidgets('the controls that are not text are labelled', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpCalendar(tester, size: const Size(390, 1600));
    final swap = await _register(tester);

    // The day detail names the change it edits.
    await revealCell(tester, _oct21);
    await tester.tap(cell(_oct21));
    await tester.pumpAndSettle();
    await openDayMore(tester);
    expect(find.byTooltip('Editar el cambio con Marta'), findsOneWidget);

    // The menu of the change has a name, and the state is said in words
    // (never with colour alone).
    await _open(tester);
    expect(find.byTooltip('Opciones del cambio'), findsOneWidget);
    expect(
      tester.getSemantics(_key('swap-card-${swap.id}')).label,
      contains('Pendiente'),
    );
    semantics.dispose();
  });

  group('saving a change and the calendar (QA M4)', () {
    testWidgets('with the switch on (the default), «Guardar» applies it', (
      tester,
    ) async {
      await pumpCalendar(tester, size: const Size(390, 1600));
      await _open(tester);
      await _openSheet(tester);
      expect(find.text('Cambiar también mi cuadrante'), findsOneWidget);
      // Nothing to apply until a shift is chosen: the switch is off.
      expect(_switchOn(tester), isFalse);

      await _fillAndSave(tester);
      expect(find.text('Nuevo cambio'), findsNothing);
      final swap = (await _stored(tester)).single;
      expect(swap.givenShiftTypeIds, const ['morning']);
      // The calendar shows the swap, and the notice says so.
      expect(_ids(tester, _oct21), const ['afternoon']);
      expect(find.text('Guardado y aplicado a tu cuadrante'), findsOneWidget);
      expect(_key('swap-application-${swap.id}'), findsOneWidget);
      expect(find.text('Aplicado'), findsOneWidget);
      expect(find.text('Sin aplicar'), findsNothing);
      expect(_key('swap-apply-${swap.id}'), findsNothing);

      // «Deshacer» takes the calendar back; the change stays in the book.
      await tester.tap(find.text('Deshacer'));
      await _settle(tester);
      expect(_ids(tester, _oct21), const ['morning', 'afternoon']);
      expect(await _stored(tester), hasLength(1));
      expect(find.text('Sin aplicar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('with the switch off nothing changes and the card applies it', (
      tester,
    ) async {
      await pumpCalendar(tester, size: const Size(390, 1600));
      await _open(tester);
      await _openSheet(tester);
      await _fill(tester);
      // Now there is something to apply: the switch comes on by itself.
      expect(_switchOn(tester), isTrue);
      await tester.ensureVisible(_key('swap-apply-switch'));
      await tester.tap(_key('swap-apply-switch'));
      await tester.pumpAndSettle();
      expect(_switchOn(tester), isFalse);
      await _tapSave(tester);

      final swap = (await _stored(tester)).single;
      expect(_ids(tester, _oct21), const ['morning', 'afternoon']);
      expect(
        find.text('Guardado. Tu cuadrante no cambia hasta que lo apliques'),
        findsOneWidget,
      );
      // The card says it apart from the debt state, with its button.
      expect(find.text('Pendiente'), findsOneWidget);
      expect(find.text('Sin aplicar'), findsOneWidget);
      final button = _key('swap-apply-${swap.id}');
      expect(button, findsOneWidget);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await _settle(tester);

      expect(_ids(tester, _oct21), const ['afternoon']);
      expect(find.text('Cambio aplicado al cuadrante'), findsOneWidget);
      expect(find.text('Aplicado'), findsOneWidget);
      expect(button, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the notice of a saved change has «Aplicar»', (tester) async {
      await pumpCalendar(tester, size: const Size(390, 1600));
      await _open(tester);
      await _openSheet(tester);
      await _fill(tester);
      await tester.ensureVisible(_key('swap-apply-switch'));
      await tester.tap(_key('swap-apply-switch'));
      await tester.pumpAndSettle();
      await _tapSave(tester);
      expect(_ids(tester, _oct21), const ['morning', 'afternoon']);

      await tester.tap(find.text('Aplicar'));
      await _settle(tester);
      expect(_ids(tester, _oct21), const ['afternoon']);
      expect(find.text('Cambio aplicado al cuadrante'), findsOneWidget);
      expect(find.text('Aplicado'), findsOneWidget);
    });

    testWidgets('the hint to choose the shifts goes once both are chosen', (
      tester,
    ) async {
      const hint =
          'Elige los turnos del cambio para poder aplicarlo al cuadrante.';
      await pumpCalendar(tester, size: const Size(390, 1600));
      await _open(tester);
      await _openSheet(tester);
      expect(find.text(hint), findsOneWidget);
      await _fill(tester);
      // Only the shift I give is chosen: the hint stays.
      expect(find.text(hint), findsOneWidget);
      await tester.ensureVisible(_key('swap-received-afternoon'));
      await tester.tap(_key('swap-received-afternoon'));
      await tester.pumpAndSettle();
      expect(find.text(hint), findsNothing);
    });

    testWidgets('a debt with no shifts says nothing about the calendar', (
      tester,
    ) async {
      await pumpCalendar(tester, size: const Size(390, 1600));
      await _open(tester);
      await _openSheet(tester);
      await tester.enterText(_key('swap-field-colleague'), 'Raúl');
      await _tapSave(tester);

      expect(await _stored(tester), hasLength(1));
      expect(_ids(tester, _oct21), const ['morning', 'afternoon']);
      expect(find.text('Sin aplicar'), findsNothing);
      expect(find.text('Aplicado'), findsNothing);
      expect(find.text('Aplicar'), findsNothing);
    });

    testWidgets('editing an applied change does not apply it twice', (
      tester,
    ) async {
      await pumpCalendar(tester, size: const Size(390, 1600));
      final swap = await _register(
        tester,
        givenShiftTypeIds: const ['morning'],
      );
      await _open(tester);
      await tester.tap(_key('swap-apply-${swap.id}'));
      await _settle(tester);
      expect(_ids(tester, _oct21), const ['afternoon']);

      // Its note changes: the days are left as they are, the switch is on
      // and disabled, and there is no notice about the calendar.
      await _menu(tester, swap.id, 'swap-menu-edit');
      expect(
        tester.widget<SwitchListTile>(_key('swap-apply-switch')).onChanged,
        isNull,
      );
      expect(_switchOn(tester), isTrue);
      await tester.enterText(_key('swap-field-note'), 'Me lo devuelve');
      await _tapSave(tester);
      expect((await _stored(tester)).single.note, 'Me lo devuelve');
      expect(_ids(tester, _oct21), const ['afternoon']);
      expect(find.text('Guardado y aplicado a tu cuadrante'), findsNothing);
      expect(find.text('Aplicado'), findsOneWidget);

      // Another shift: the first application is taken back before the new
      // one goes on, so the day does not lose both.
      await _menu(tester, swap.id, 'swap-menu-edit');
      await tester.ensureVisible(_key('swap-given-morning'));
      await tester.tap(_key('swap-given-morning'));
      await tester.ensureVisible(_key('swap-given-afternoon'));
      await tester.tap(_key('swap-given-afternoon'));
      await tester.pumpAndSettle();
      expect(_switchOn(tester), isTrue);
      await _tapSave(tester);
      expect((await _stored(tester)).single.givenShiftTypeIds, const [
        'afternoon',
      ]);
      expect(_ids(tester, _oct21), const ['morning']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('editing warns about a date that was changed by hand', (
      tester,
    ) async {
      await pumpCalendar(tester, size: const Size(390, 1600));
      final swap = await _register(
        tester,
        givenShiftTypeIds: const ['morning'],
        returnDate: _oct24,
        receivedShiftTypeIds: const ['morning'],
      );
      await _open(tester);
      await tester.tap(_key('swap-apply-${swap.id}'));
      await _settle(tester);
      final schedule = _container(tester)
          .read(scheduleControllerProvider.notifier);
      schedule.setShiftOnDays([_oct24], 'afternoon');
      await _settle(tester);

      await _menu(tester, swap.id, 'swap-menu-edit');
      await tester.ensureVisible(_key('swap-field-return-clear'));
      await tester.tap(_key('swap-field-return-clear'));
      await tester.pumpAndSettle();
      expect(_switchOn(tester), isTrue);
      await tester.ensureVisible(_key('swap-apply-switch'));
      await tester.tap(_key('swap-apply-switch'));
      await tester.pumpAndSettle();
      expect(_switchOn(tester), isFalse);
      expect(
        find.text(
          'Al guardar se recuperarán los turnos anteriores que se puedan restaurar.',
        ),
        findsOneWidget,
      );
      await _tapSave(tester);

      expect(
        find.textContaining('He conservado tu turno de 24 oct'),
        findsOneWidget,
      );
      expect((await _stored(tester)).single.returnDate, isNull);
      expect(_ids(tester, _oct24), ['afternoon']);
      expect(_ids(tester, _oct21), ['morning', 'afternoon']);
    });

    testWidgets('removing an applied change leaves the calendar as it is', (
      tester,
    ) async {
      await pumpCalendar(tester, size: const Size(390, 1600));
      final swap = await _register(
        tester,
        givenShiftTypeIds: const ['morning'],
      );
      await _open(tester);
      await tester.tap(_key('swap-apply-${swap.id}'));
      await _settle(tester);
      await _menu(tester, swap.id, 'swap-menu-remove');
      await _settle(tester);
      expect(
        find.text('Quitar el cambio y devolver tu cuadrante'),
        findsOneWidget,
      );
      await tester.tap(find.text('Quitar solo el cambio'));
      await _settle(tester);
      expect(await _stored(tester), isEmpty);
      expect(_ids(tester, _oct21), const ['afternoon']);
    });

    testWidgets('a removal stopped by one date says the swap stays whole', (
      tester,
    ) async {
      await pumpCalendar(tester, size: const Size(390, 1600));
      final swap = await _register(
        tester,
        givenShiftTypeIds: const ['morning'],
        returnDate: _oct24,
        receivedShiftTypeIds: const ['morning'],
      );
      await _open(tester);
      await tester.tap(_key('swap-apply-${swap.id}'));
      await _settle(tester);
      _container(tester)
          .read(scheduleControllerProvider.notifier)
          .setShiftOnDays([_oct24], 'afternoon');
      await _settle(tester);

      await _menu(tester, swap.id, 'swap-menu-remove');
      await tester.tap(find.text('Quitar el cambio y devolver tu cuadrante'));
      await _settle(tester);

      expect(
        find.textContaining('He conservado tu turno de 24 oct'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'No he quitado el cambio: sigue en el libro de cambios y no he '
          'tocado ninguno de sus días.',
        ),
        findsOneWidget,
      );
      expect((await _stored(tester)).single.id, swap.id);
      // The other date keeps what the swap wrote: nothing was restored.
      expect(_ids(tester, _oct21), const ['afternoon']);
      expect(_ids(tester, _oct24), const ['afternoon']);
    });
  });

  group('one applied swap per day (QA M4)', () {
    const conflict =
        'ya tiene otro cambio aplicado (con Marta): quítalo del cuadrante '
        'primero.';

    /// Marta's swap gives the morning of the 21st and is applied.
    Future<ShiftSwap> applyMarta(WidgetTester tester) async {
      final marta = await _register(
        tester,
        givenShiftTypeIds: const ['morning'],
      );
      await _open(tester);
      await tester.tap(_key('swap-apply-${marta.id}'));
      await _settle(tester);
      expect(_ids(tester, _oct21), const ['afternoon']);
      return marta;
    }

    testWidgets('the card button refuses a day another swap holds', (
      tester,
    ) async {
      await pumpCalendar(tester, size: const Size(390, 1600));
      await applyMarta(tester);
      final raul = await _register(
        tester,
        colleague: 'Raúl',
        givenShiftTypeIds: const ['afternoon'],
      );
      await _settle(tester);

      await tester.ensureVisible(_key('swap-apply-${raul.id}'));
      await tester.tap(_key('swap-apply-${raul.id}'));
      await _settle(tester);

      expect(find.textContaining(conflict), findsOneWidget);
      expect(_ids(tester, _oct21), const ['afternoon']);
      final records = await tester.runAsync(
        () => _container(tester).read(swapAppliedStoreProvider).before(raul.id),
      );
      expect(records, isEmpty);
    });

    testWidgets('the sheet switch is off and says why, and so does «Aplicar»', (
      tester,
    ) async {
      await pumpCalendar(tester, size: const Size(390, 1600));
      await applyMarta(tester);
      await _openSheet(tester);
      await tester.enterText(_key('swap-field-colleague'), 'Raúl');
      await tester.ensureVisible(_key('swap-given-afternoon'));
      await tester.tap(_key('swap-given-afternoon'));
      await tester.pumpAndSettle();

      final toggle = tester.widget<SwitchListTile>(_key('swap-apply-switch'));
      expect(toggle.value, isFalse);
      expect(toggle.onChanged, isNull);
      expect(find.textContaining(conflict), findsOneWidget);

      // Saved without applying; the notice's «Aplicar» explains the refusal.
      await _tapSave(tester);
      expect(await _stored(tester), hasLength(2));
      expect(_ids(tester, _oct21), const ['afternoon']);
      await tester.tap(find.text('Aplicar'));
      await _settle(tester);
      expect(find.textContaining(conflict), findsOneWidget);
      expect(_ids(tester, _oct21), const ['afternoon']);
    });

    testWidgets('moving an applied swap onto a held day shows both results', (
      tester,
    ) async {
      const oct23 = CivilDate(2026, 10, 23);
      await pumpCalendar(tester, size: const Size(390, 1600));
      await applyMarta(tester);
      final raul = await _register(
        tester,
        colleague: 'Raúl',
        date: oct23,
        givenShiftTypeIds: const ['night'],
        returnDate: _oct21,
      );
      await tester.ensureVisible(_key('swap-apply-${raul.id}'));
      await tester.tap(_key('swap-apply-${raul.id}'));
      await _settle(tester);
      expect(_ids(tester, oct23), isEmpty);

      // Receiving a morning on the 21st would write Marta's day.
      await _menu(tester, raul.id, 'swap-menu-edit');
      await tester.ensureVisible(_key('swap-received-morning'));
      await tester.tap(_key('swap-received-morning'));
      await tester.pumpAndSettle();

      final toggle = tester.widget<SwitchListTile>(_key('swap-apply-switch'));
      expect(toggle.value, isFalse);
      expect(toggle.onChanged, isNull);
      expect(
        find.textContaining(
          'Al guardar se recuperarán los turnos anteriores que se puedan '
          'restaurar.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining(conflict), findsOneWidget);

      await _tapSave(tester);
      expect(_ids(tester, oct23), const ['night']);
      expect(_ids(tester, _oct21), const ['afternoon']);
    });
  });

  group('layout', () {
    for (final (size, scale, brightness) in [
      (const Size(390, 844), 1.0, Brightness.light),
      (const Size(390, 844), 2.0, Brightness.dark),
      (const Size(320, 568), 1.0, Brightness.dark),
      (const Size(320, 568), 2.0, Brightness.light),
    ]) {
      testWidgets('the screen at ${size.width.toInt()}x'
          '${size.height.toInt()}, text $scale, ${brightness.name}', (
        tester,
      ) async {
        await pumpCalendar(
          tester,
          size: size,
          textScale: scale,
          brightness: brightness,
        );
        final swap = await _register(
          tester,
          givenShiftTypeIds: const ['morning'],
          receivedShiftTypeIds: const ['morning'],
          returnDate: _oct24,
          note: 'Me lo devuelve el lunes por la mañana',
        );
        await _open(tester);

        // Nothing of the card is cut off.
        for (final key in [
          'swap-balances',
          'swap-card-${swap.id}',
          'swap-date-${swap.id}',
          'swap-who-${swap.id}',
        ]) {
          await tester.ensureVisible(_key(key));
          await tester.pump();
          final rect = tester.getRect(_key(key));
          expect(rect.left, greaterThanOrEqualTo(-0.5), reason: key);
          expect(rect.right, lessThanOrEqualTo(size.width + 0.5), reason: key);
        }
        expect(tester.takeException(), isNull);

        // The sheet too (the button of the bar is always in sight).
        await tester.tap(_key('swap-add'));
        await _settle(tester);
        await tester.ensureVisible(_key('swap-field-colleague'));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(
          tester.getRect(_key('swap-field-colleague')).right,
          lessThanOrEqualTo(size.width + 0.5),
        );
      });
    }
  });
}
