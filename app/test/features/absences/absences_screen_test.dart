import 'package:cuadrante/app.dart';
import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/router.dart';
import 'package:cuadrante/features/absences/application/absence_providers.dart';
import 'package:cuadrante/features/absences/domain/absence_balance.dart';
import 'package:cuadrante/features/absences/presentation/absences_screen.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_font.dart';
import '../calendar/harness.dart';

// P3 · «Vacaciones y permisos» (/ajustes/ausencias): one card per balance of
// the year with what the logic computes, the sheet that edits it, the year
// switcher and the layouts. Demo data of `pumpCalendar` (19 Oct 2026): two
// vacation days planned, on 27 and 28 October.

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(CuadranteApp)));

/// Lets the database answer (real time) and the screen draw what it got:
/// the providers of these screens are built inside the fake-time zone, so
/// their reads only finish when real time and frames alternate.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 15)),
    );
    await tester.pumpAndSettle();
  }
}

Finder _key(String key) => find.byKey(ValueKey(key));

const _vacation = AbsenceBalance(
  year: 2026,
  type: 'vac',
  name: 'Vacaciones',
  allowedDays: 22,
  adjustmentDays: 1,
  carryOver: true,
  carryOverMaxDays: 5,
  shiftTypeQuarters: {'vacation': 4},
);

const _vacation2025 = AbsenceBalance(
  year: 2025,
  type: 'vac',
  name: 'Vacaciones',
  allowedDays: 22,
  shiftTypeQuarters: {'vacation': 4},
);

Future<void> _save(WidgetTester tester, AbsenceBalance balance) async {
  final container = _container(tester);
  await tester.runAsync(() async {
    // The screen keeps the balances of its year alive; a year nobody shows
    // needs a listener for the write to finish.
    final listener = container.listen(
      absenceBalancesProvider(balance.year),
      (_, _) {},
    );
    await container
        .read(absenceBalancesProvider(balance.year).notifier)
        .save(balance);
    listener.close();
  });
}

Future<void> _expiry(WidgetTester tester, CivilDate date) async {
  final container = _container(tester);
  await tester.runAsync(() async {
    final listener = container.listen(absenceBalancesProvider(2026), (_, _) {});
    await container
        .read(absenceBalancesProvider(2026).notifier)
        .setCarryOverExpiry(2026, 'vac', date);
    listener.close();
  });
}

/// The balances stored for [year], straight from the repository.
Future<List<AbsenceBalance>> _stored(WidgetTester tester, int year) async {
  final repository = _container(tester).read(absenceBalancesRepositoryProvider);
  return (await tester.runAsync(() => repository.list(year: year)))!;
}

Future<void> _open(
  WidgetTester tester, [
  String path = '/ajustes/ausencias',
]) async {
  _container(tester).read(routerProvider).go(path);
  await _settle(tester);
}

Future<void> _seedAndOpen(WidgetTester tester) async {
  await _save(tester, _vacation2025);
  await _save(tester, _vacation);
  await _open(tester);
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(_key(key)).data!;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeLocale();
    expect(await loadRoboto(), isTrue, reason: 'Roboto from the Flutter SDK');
  });

  testWidgets('shows the figures the logic computes', (tester) async {
    await pumpCalendar(tester, size: const Size(390, 1600));
    await _seedAndOpen(tester);

    expect(find.byType(AbsencesScreen), findsOneWidget);
    expect(_text(tester, 'absence-year'), '2026');
    final status = _container(tester)
        .read(absenceBalancesProvider(2026))
        .value!
        .single;
    // 22 allowed + 5 carried (capped) + 1 adjustment - 2 planned.
    expect(status.remainingDays, 26);

    expect(_text(tester, 'absence-left-vac'), '26');
    expect(find.text('VACACIONES'), findsOneWidget);
    expect(_text(tester, 'absence-allowed-vac-value'), '22 días');
    expect(_text(tester, 'absence-carried-vac-value'), '5 días');
    expect(_text(tester, 'absence-carried-vac-detail'), 'Sin caducidad');
    expect(_text(tester, 'absence-adjustment-vac-value'), '+1 día');
    expect(_text(tester, 'absence-enjoyed-vac-value'), '0 días');
    expect(_text(tester, 'absence-planned-vac-value'), '2 días');
    expect(find.text('días que te quedan'), findsOneWidget);
    // Nothing to warn about without an expiry date.
    expect(_key('absence-warning-expiring-vac'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the warnings of the logic are shown as notices', (tester) async {
    await pumpCalendar(tester, size: const Size(390, 1600));
    await _save(tester, _vacation2025);
    await _save(tester, _vacation);
    await _expiry(tester, const CivilDate(2026, 12, 31));
    await _open(tester);

    expect(
      _text(tester, 'absence-carried-vac-detail'),
      'Caducan el 31 dic 2026',
    );
    expect(_key('absence-warning-expiring-vac'), findsOneWidget);
    // The two vacation days planned in October spend the carried days first
    // (H1), so 5 - 2 = 3 are left to expire.
    expect(
      find.text(
        'Te quedan 3 días del año anterior que caducan el 31 dic 2026.',
      ),
      findsOneWidget,
    );

    // More planned than available: the second warning.
    await _save(
      tester,
      _vacation.copyWith(
        allowedDays: 1,
        adjustmentDays: 0,
        carryOver: false,
        clearCarryOverMaxDays: true,
      ),
    );
    await _settle(tester);
    expect(_key('absence-warning-planned-vac'), findsOneWidget);
    expect(
      find.text(
        'Has planificado más de los que tienes: 2 días planificados y '
        '1 día disponibles.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the semantics of a card say what is left', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpCalendar(tester, size: const Size(390, 1600));
    await _seedAndOpen(tester);
    expect(
      find.bySemanticsLabel('Vacaciones: te quedan 26 días'),
      findsOneWidget,
    );
    expect(find.byTooltip('Editar Vacaciones'), findsOneWidget);
    expect(find.byTooltip('Año anterior'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('the year switcher reads another year', (tester) async {
    await pumpCalendar(tester, size: const Size(390, 1600));
    await _seedAndOpen(tester);

    await tester.tap(_key('absence-next'));
    await _settle(tester);
    expect(_text(tester, 'absence-year'), '2027');
    expect(_key('absence-empty'), findsOneWidget);
    expect(find.text('Aún no hay saldos'), findsOneWidget);

    await tester.tap(_key('absence-previous'));
    await _settle(tester);
    await tester.tap(_key('absence-previous'));
    await _settle(tester);
    expect(_text(tester, 'absence-year'), '2025');
    expect(_text(tester, 'absence-left-vac'), '22');
  });

  testWidgets('a balance is created from the sheet and stored', (tester) async {
    await pumpCalendar(tester, size: const Size(390, 1600));
    await _open(tester);
    expect(_key('absence-empty'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Añadir saldo'));
    await _settle(tester);
    expect(find.text('Nuevo saldo'), findsOneWidget);

    // Nothing typed: the sheet says what is missing and stays.
    await tester.tap(_key('absence-save'));
    await _settle(tester);
    expect(find.text('Ponle un nombre (máximo 100 letras).'), findsOneWidget);
    expect(
      find.text('Escribe un número de días válido, por ejemplo 22.'),
      findsOneWidget,
    );

    await tester.enterText(_key('absence-field-name'), 'Vacaciones');
    await tester.enterText(_key('absence-field-allowed'), '22');
    await tester.enterText(_key('absence-field-adjustment'), '-1');
    await tester.ensureVisible(_key('absence-type-vacation'));
    await tester.tap(_key('absence-type-vacation'));
    await _settle(tester);
    await tester.ensureVisible(_key('absence-save'));
    await tester.tap(_key('absence-save'));
    await _settle(tester);

    final stored = await _stored(tester, 2026);
    expect(stored, hasLength(1));
    expect(stored.single.name, 'Vacaciones');
    expect(stored.single.allowedDays, 22);
    expect(stored.single.adjustmentDays, -1);
    expect(stored.single.shiftTypeQuarters, {'vacation': 4});
    expect(stored.single.calendarId, 'main');
    // 22 - 1 adjustment - the 2 planned days of the demo data.
    expect(_text(tester, 'absence-left-${stored.single.type}'), '19');
    expect(find.text('Nuevo saldo'), findsNothing);
  });

  testWidgets('a new balance can continue the series of the year before', (
    tester,
  ) async {
    await pumpCalendar(tester, size: const Size(390, 1600));
    await _save(tester, _vacation2025);
    await _open(tester);
    expect(_key('absence-empty'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Añadir saldo'));
    await _settle(tester);
    // The series of the year before is offered to be continued (H2).
    expect(find.text('Continuar una serie'), findsOneWidget);
    await tester.tap(_key('absence-continue-vac'));
    await _settle(tester);
    // The name and the types come from the year before.
    expect(
      tester.widget<TextField>(_key('absence-field-name')).controller!.text,
      'Vacaciones',
    );

    await tester.enterText(_key('absence-field-allowed'), '22');
    await tester.ensureVisible(_key('absence-save'));
    await tester.tap(_key('absence-save'));
    await _settle(tester);

    final stored = (await _stored(tester, 2026)).single;
    expect(
      stored.type,
      'vac',
      reason: 'the series key is the one of the year before, so it carries',
    );
    expect(stored.name, 'Vacaciones');
    expect(stored.shiftTypeQuarters, {'vacation': 4});
    expect(stored.carryOver, isTrue);
    // What was left of 2025 is carried into the new balance.
    expect(_text(tester, 'absence-carried-vac-value'), '22 días');
  });

  testWidgets('a balance is copied to the next year', (tester) async {
    await pumpCalendar(tester, size: const Size(390, 1600));
    await _seedAndOpen(tester);

    await tester.tap(_key('absence-edit-vac'));
    await _settle(tester);
    await tester.ensureVisible(_key('absence-copy-next'));
    await tester.tap(_key('absence-copy-next'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    expect(find.byType(SnackBar), findsOneWidget);
    final texts = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data)
        .toList();
    expect(texts, contains('Saldo copiado a 2027.'));
    await _settle(tester);

    final copy = (await _stored(tester, 2027)).single;
    expect(copy.type, 'vac');
    expect(copy.name, 'Vacaciones');
    expect(copy.allowedDays, 22);
    expect(copy.adjustmentDays, 1);
    expect(copy.carryOver, isTrue);
    expect(copy.carryOverMaxDays, 5);
    expect(copy.shiftTypeQuarters, {'vacation': 4});
  });

  testWidgets('the sheet edits the days allowed and the carry-over', (
    tester,
  ) async {
    await pumpCalendar(tester, size: const Size(390, 1600));
    await _seedAndOpen(tester);

    await tester.tap(_key('absence-edit-vac'));
    await _settle(tester);
    expect(find.text('Editar saldo'), findsOneWidget);
    expect(
      tester.widget<TextField>(_key('absence-field-allowed')).controller!.text,
      '22',
    );

    await tester.enterText(_key('absence-field-allowed'), '25');
    await tester.enterText(_key('absence-field-cap'), '2,5');
    // A quarter-day step is fine; 0,3 is not.
    await tester.enterText(_key('absence-field-adjustment'), '0,3');
    await tester.ensureVisible(_key('absence-save'));
    await tester.tap(_key('absence-save'));
    await _settle(tester);
    expect(
      find.text('Escribe días en pasos de un cuarto, por ejemplo -1 o 0,5.'),
      findsOneWidget,
    );

    await tester.enterText(_key('absence-field-adjustment'), '0,5');
    await tester.tap(_key('absence-save'));
    await _settle(tester);

    final stored = (await _stored(tester, 2026)).single;
    expect(stored.allowedDays, 25);
    expect(stored.carryOverMaxDays, 2.5);
    expect(stored.adjustmentDays, 0.5);
    expect(stored.carryOver, isTrue);
    // 25 + 2.5 carried + 0.5 - 2 planned.
    expect(_text(tester, 'absence-left-vac'), '26');
  });

  testWidgets('the expiry date of the carried days is stored', (tester) async {
    await pumpCalendar(tester, size: const Size(390, 1600));
    await _seedAndOpen(tester);

    await tester.tap(_key('absence-edit-vac'));
    await _settle(tester);
    await tester.ensureVisible(_key('absence-field-expiry'));
    await tester.tap(_key('absence-field-expiry'));
    await _settle(tester);
    // The date picker opens on 31 March; accept it.
    await tester.tap(find.text('Aceptar'));
    await _settle(tester);
    expect(find.text('31 mar 2026'), findsOneWidget);
    await tester.ensureVisible(_key('absence-save'));
    await tester.tap(_key('absence-save'));
    await _settle(tester);

    final store = _container(tester).read(absenceCarryOverStoreProvider);
    final expiry = (await tester.runAsync(store.load))!;
    // The key carries the calendar of the balance, so two calendars can hold
    // the same series without clashing (L1).
    expect(expiry['main|2026:vac'], const CivilDate(2026, 3, 31));
    // Today (19 Oct) is after it: the carried days are lost.
    expect(
      _text(tester, 'absence-carried-vac-detail'),
      'Caducaron el 31 mar 2026',
    );
    expect(_text(tester, 'absence-carried-vac-value'), '0 días');
  });

  testWidgets('a balance is removed after confirming', (tester) async {
    await pumpCalendar(tester, size: const Size(390, 1600));
    await _seedAndOpen(tester);

    await tester.tap(_key('absence-edit-vac'));
    await _settle(tester);
    await tester.ensureVisible(_key('absence-remove'));
    await tester.tap(_key('absence-remove'));
    await _settle(tester);
    expect(find.text('¿Quitar este saldo?'), findsOneWidget);

    // Cancelling keeps it.
    await tester.tap(find.text('Cancelar'));
    await _settle(tester);
    expect(await _stored(tester, 2026), hasLength(1));

    await tester.tap(_key('absence-remove'));
    await _settle(tester);
    await tester.tap(_key('absence-remove-confirm'));
    await _settle(tester);
    expect(await _stored(tester, 2026), isEmpty);
    expect(_key('absence-empty'), findsOneWidget);
  });

  group('layout', () {
    for (final (size, scale, brightness) in [
      (const Size(390, 844), 1.0, Brightness.light),
      (const Size(390, 844), 2.0, Brightness.dark),
      (const Size(320, 568), 1.0, Brightness.dark),
      (const Size(320, 568), 2.0, Brightness.light),
    ]) {
      testWidgets('the screen and its sheet at ${size.width.toInt()}x'
          '${size.height.toInt()}, text $scale, ${brightness.name}', (
        tester,
      ) async {
        await pumpCalendar(
          tester,
          size: size,
          textScale: scale,
          brightness: brightness,
        );
        await _save(tester, _vacation2025);
        await _save(
          tester,
          _vacation.copyWith(name: 'Asuntos propios y libre disposición'),
        );
        await _expiry(tester, const CivilDate(2026, 12, 31));
        await _open(tester);

        // Everything of the card is on screen width, nothing cut.
        for (final key in [
          'absence-left-vac',
          'absence-allowed-vac',
          'absence-carried-vac',
          'absence-planned-vac',
          'absence-warning-expiring-vac',
        ]) {
          await tester.ensureVisible(_key(key));
          await tester.pump();
          final rect = tester.getRect(_key(key));
          expect(rect.left, greaterThanOrEqualTo(-0.5), reason: key);
          expect(rect.right, lessThanOrEqualTo(size.width + 0.5), reason: key);
        }
        expect(tester.takeException(), isNull);

        await tester.drag(find.byType(Scrollable).first, const Offset(0, 5000));
        await tester.pumpAndSettle();
        await tester.tap(_key('absence-edit-vac'));
        await _settle(tester);
        await tester.ensureVisible(_key('absence-save'));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(
          tester.getRect(_key('absence-save')).right,
          lessThanOrEqualTo(size.width + 0.5),
        );
      });
    }
  });
}
