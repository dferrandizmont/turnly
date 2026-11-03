import 'package:cuadrante/app.dart';
import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/router.dart';
import 'package:cuadrante/features/calendar/application/schedule_controller.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/swaps/application/swaps_controller.dart';
import 'package:cuadrante/features/swaps/application/swaps_providers.dart';
import 'package:cuadrante/features/swaps/domain/shift_swap.dart';
import 'package:cuadrante/features/swaps/presentation/swaps_screen.dart';
import 'package:flutter/material.dart';
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
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 15)),
    );
    await tester.pumpAndSettle();
  }
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
    () => container.read(swapLedgerProvider.notifier).register(
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
Future<void> _menu(
  WidgetTester tester,
  String swapId,
  String actionKey,
) async {
  await tester.tap(_key('swap-menu-$swapId'));
  await tester.pumpAndSettle();
  await tester.tap(_key(actionKey));
  await tester.pumpAndSettle();
}

/// The shifts a day has, as the schedule resolves them.
List<String> _ids(WidgetTester tester, CivilDate date) =>
    _container(tester)
        .read(scheduleControllerProvider)
        .schedule
        .resolve(date)
        .shiftIds;

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
    await _register(
      tester,
      colleague: 'Luis',
      direction: SwapDirection.iOwe,
    );
    await _open(tester);

    expect(find.byType(SwapsScreen), findsOneWidget);
    // The balance: what each one owes.
    expect(
      find.descendant(
        of: _key('swap-balances'),
        matching: find.text('Marta'),
      ),
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
    await _register(
      tester,
      colleague: 'Luis',
      direction: SwapDirection.iOwe,
    );
    await _container(tester).read(swapLedgerProvider.notifier).settle(
      settled.id,
    );
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
    await tester.tap(_key('swap-direction-they-owe'));
    await tester.ensureVisible(_key('swap-given-morning'));
    await tester.tap(_key('swap-given-morning'));
    await tester.enterText(_key('swap-field-note'), 'Me lo devuelve el lunes');
    await tester.ensureVisible(_key('swap-save'));
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

  testWidgets('a change is marked as returned and as settled', (tester) async {
    await pumpCalendar(tester, size: const Size(390, 1600));
    final swap = await _register(tester);
    await _open(tester);

    // Returned: the day the favour comes back.
    await _menu(tester, swap.id, 'swap-menu-returned');
    expect(find.text('¿Qué día te lo devuelven?'), findsOneWidget);
    await tester.tap(find.text('Aceptar'));
    await _settle(tester);
    expect(find.text('Devuelto'), findsOneWidget);
    expect((await _stored(tester)).single.returnDate, isNotNull);
    expect((await _stored(tester)).single.isReturned, isFalse);

    // Settled: it leaves the pending list and the balance.
    await _menu(tester, swap.id, 'swap-menu-settle');
    await _settle(tester);
    expect(find.text('Saldado'), findsOneWidget);
    expect((await _stored(tester)).single.isReturned, isTrue);
    expect(
      _container(tester).read(swapLedgerProvider).value!.pending,
      isEmpty,
    );

    // And it can be owed again.
    await _menu(tester, swap.id, 'swap-menu-reopen');
    await _settle(tester);
    expect(
      _container(tester).read(swapLedgerProvider).value!.pending,
      hasLength(1),
    );
  });

  testWidgets('a change is applied to the calendar and undone', (
    tester,
  ) async {
    await pumpCalendar(tester, size: const Size(390, 1600));
    final swap = await _register(
      tester,
      givenShiftTypeIds: const ['morning'],
      receivedShiftTypeIds: const ['morning'],
      returnDate: _oct24,
    );
    await _open(tester);

    // The day it gives loses the shift and the day it comes back gets it.
    expect(_ids(tester, _oct21), const ['morning', 'afternoon']);
    expect(_ids(tester, _oct24), const ['rest']);

    await _menu(tester, swap.id, 'swap-menu-apply');
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

    await _menu(tester, swap.id, 'swap-menu-apply');
    await _settle(tester);
    expect(_ids(tester, _oct21), const ['afternoon']);

    await _menu(tester, swap.id, 'swap-menu-unapply');
    await _settle(tester);
    expect(find.text('Cambio quitado del cuadrante'), findsOneWidget);
    expect(_ids(tester, _oct21), const ['morning', 'afternoon']);
    expect(_ids(tester, _oct24), const ['rest']);
  });

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
