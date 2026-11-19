import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/format/app_formats.dart';
import 'package:cuadrante/core/l10n/app_material_localizations.dart';
import 'package:cuadrante/core/theme/app_theme.dart';
import 'package:cuadrante/core/widgets/app_sheet.dart';
import 'package:cuadrante/core/widgets/confirm_dialog.dart';
import 'package:cuadrante/core/widgets/keyboard_done_bar.dart';
import 'package:cuadrante/core/widgets/minute_picker.dart';
import 'package:cuadrante/l10n/app_localizations.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_font.dart';

/// iOS QA 1.2.0 (iPhone F4, F6, F8): the time picker is the system wheel on
/// iOS, the Done bar of the number pad survives the largest text and the
/// title of a dialog never breaks inside a word.
void main() {
  setUpAll(() async {
    await initializeLocale();
    // The real font: the test one is as wide as it is tall.
    expect(await loadRoboto(), isTrue);
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  Widget app(
    Widget home, {
    double scale = 1.0,
    TargetPlatform? platform,
    bool dark = false,
    bool reduceMotion = false,
  }) => MaterialApp(
    theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
      platform: platform,
    ),
    locale: const Locale('es'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      AppMaterialLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
        disableAnimations: reduceMotion,
      ),
      child: child!,
    ),
    home: home,
  );

  group('time picker', () {
    int? result;
    Widget opener({bool hour12 = false}) => Builder(
      builder: (context) => AppFormats(
        localeName: 'es',
        hour12: hour12,
        currency: 'EUR',
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showMinutePicker(
              context,
              current: 8 * 60 + 5,
              help: 'Hora de inicio',
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );

    testWidgets('iOS: a Cupertino time picker, not the Material dial', (
      tester,
    ) async {
      result = null;
      await tester.pumpWidget(
        app(Scaffold(body: opener()), platform: TargetPlatform.iOS),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoDatePicker), findsOneWidget);
      expect(find.byType(TimePickerDialog), findsNothing);
      expect(find.text('Hora de inicio'), findsOneWidget);
      final picker = tester.widget<CupertinoDatePicker>(
        find.byType(CupertinoDatePicker),
      );
      expect(picker.mode, CupertinoDatePickerMode.time);
      expect(picker.use24hFormat, isTrue);
      expect(picker.initialDateTime.hour, 8);
      expect(picker.initialDateTime.minute, 5);

      // Done without touching the wheel returns the time it opened with.
      await tester.tap(find.byKey(const ValueKey('time-picker-done')));
      await tester.pumpAndSettle();
      expect(result, 8 * 60 + 5);
    });

    testWidgets('iOS: cancel returns null', (tester) async {
      result = -1;
      await tester.pumpWidget(
        app(Scaffold(body: opener()), platform: TargetPlatform.iOS),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('time-picker-cancel')));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoDatePicker), findsNothing);
      expect(result, isNull);
    });

    testWidgets('iOS: the 12 h clock follows the setting', (tester) async {
      await tester.pumpWidget(
        app(Scaffold(body: opener(hour12: true)), platform: TargetPlatform.iOS),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      final picker = tester.widget<CupertinoDatePicker>(
        find.byType(CupertinoDatePicker),
      );
      expect(picker.use24hFormat, isFalse);
    });

    testWidgets('Android keeps the Material dial', (tester) async {
      await tester.pumpWidget(
        app(Scaffold(body: opener()), platform: TargetPlatform.android),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      expect(find.byType(CupertinoDatePicker), findsNothing);
    });
  });

  group('Done bar of the number pad', () {
    testWidgets('at the largest text the word fits the bar and a tap works', (
      tester,
    ) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        app(
          Scaffold(
            body: Column(
              children: [
                TextField(focusNode: node, autofocus: true),
                const Spacer(),
                const KeyboardDoneBar(),
              ],
            ),
          ),
          scale: 3.1,
        ),
      );
      await tester.pumpAndSettle();
      expect(node.hasFocus, isTrue);
      final bar = tester.getRect(find.byType(KeyboardDoneBar));
      expect(bar.height, KeyboardDoneBar.height);
      final text = tester.getRect(find.text('Listo'));
      expect(text.top, greaterThanOrEqualTo(bar.top));
      expect(text.bottom, lessThanOrEqualTo(bar.bottom));
      // The button takes the whole bar height.
      final button = tester.getRect(
        find.byKey(const ValueKey('keyboard-done')),
      );
      expect(button.height, closeTo(KeyboardDoneBar.height - 1, 1.5));

      // A tap near the top edge of the bar, where the word was cut, works.
      await tester.tapAt(Offset(button.center.dx, button.top + 3));
      await tester.pumpAndSettle();
      expect(node.hasFocus, isFalse);
    });
  });

  group('title of a confirm dialog', () {
    for (final scale in [1.0, 2.35, 3.1]) {
      testWidgets('x$scale on 414 dp: no word breaks in the middle', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(414, 896);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          app(
            Builder(
              builder: (context) => TextButton(
                onPressed: () => showConfirmDialog(
                  context,
                  title: '¿Descartar la secuencia?',
                  body: 'Se pierde lo que has puesto.',
                  confirmLabel: 'Descartar',
                  cancelLabel: 'Seguir editando',
                  scrollable: true,
                ),
                child: const Text('abrir'),
              ),
            ),
            scale: scale,
          ),
        );
        await tester.tap(find.text('abrir'));
        await tester.pumpAndSettle();

        final title = find.byType(DialogTitle);
        expect(title, findsOneWidget);
        // «¿Descartar» must be whole: its width (one line, no wrapping) fits
        // the title box.
        final box = tester.getSize(title);
        final render = tester.renderObject<RenderParagraph>(
          find.descendant(of: title, matching: find.byType(RichText)),
        );
        final longest = TextPainter(
          text: render.text,
          textDirection: TextDirection.ltr,
          textScaler: render.textScaler,
        )..layout();
        expect(
          longest.minIntrinsicWidth,
          lessThanOrEqualTo(box.width + 0.5),
          reason: 'a word is wider than the title at x$scale',
        );
        longest.dispose();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('sheet with a number field', () {
    for (final reduce in [false, true]) {
      testWidgets('the field is scrolled above the pad and the Done bar'
          '${reduce ? ' (reduce motion: at once)' : ''}', (tester) async {
        tester.view.physicalSize = const Size(390, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          app(
            Builder(
              builder: (context) => TextButton(
                onPressed: () => showAppSheet<void>(
                  context: context,
                  padded: true,
                  builder: (_) => Column(
                    children: [
                      for (var i = 0; i < 10; i++)
                        const SizedBox(height: 80, child: Text('relleno')),
                      const TextField(
                        key: ValueKey('rate'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
            reduceMotion: reduce,
          ),
        );
        await tester.tap(find.text('abrir'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('rate')));
        await tester.pumpAndSettle();
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        await tester.tap(find.byKey(const ValueKey('rate')));
        if (reduce) {
          // No glide: a few frames are enough.
          await tester.pump();
          await tester.pump();
          await tester.pump();
        } else {
          await tester.pumpAndSettle(const Duration(milliseconds: 100));
        }
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('keyboard-done')), findsOneWidget);
        final field = tester.getRect(find.byKey(const ValueKey('rate')));
        final bar = tester.getRect(find.byKey(const ValueKey('keyboard-done')));
        expect(field.bottom, lessThanOrEqualTo(bar.top + 0.5));
      });
    }
  });

  group('sheet with a number field, device turned', () {
    testWidgets('portrait to landscape with the pad up: the field is brought '
        'above the pad again', (tester) async {
      tester.view.physicalSize = const Size(600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showAppSheet<void>(
                context: context,
                padded: true,
                builder: (_) => Column(
                  children: [
                    for (var i = 0; i < 4; i++)
                      const SizedBox(height: 90, child: Text('relleno')),
                    const TextField(
                      key: ValueKey('rate'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 90),
                  ],
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.tap(find.byKey(const ValueKey('rate')));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('keyboard-done')), findsOneWidget);

      // Turn the device: a wide, short window with the pad still up.
      tester.view.physicalSize = const Size(900, 420);
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      final field = tester.getRect(find.byKey(const ValueKey('rate')));
      final bar = tester.getRect(find.byKey(const ValueKey('keyboard-done')));
      expect(field.bottom, lessThanOrEqualTo(bar.top + 0.5));
      expect(field.top, greaterThanOrEqualTo(0));
    });

    testWidgets('the new size arrives with no keyboard and the pad comes back '
        'late: the field still ends above the pad', (tester) async {
      tester.view.physicalSize = const Size(600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showAppSheet<void>(
                context: context,
                padded: true,
                builder: (_) => Column(
                  children: [
                    for (var i = 0; i < 4; i++)
                      const SizedBox(height: 90, child: Text('relleno')),
                    const TextField(
                      key: ValueKey('rate'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 90),
                  ],
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.tap(find.byKey(const ValueKey('rate')));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('keyboard-done')), findsOneWidget);

      // Turn: the new window size lands in a frame with no keyboard at all.
      tester.view.physicalSize = const Size(900, 420);
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pump();
      // The pad starts to come back, and only reaches its final height after
      // the short settle time (400 ms) but before the long one (900 ms).
      tester.view.viewInsets = const FakeViewPadding(bottom: 100);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 450));
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('keyboard-done')), findsOneWidget);
      final field = tester.getRect(find.byKey(const ValueKey('rate')));
      final bar = tester.getRect(find.byKey(const ValueKey('keyboard-done')));
      expect(field.bottom, lessThanOrEqualTo(bar.top + 0.5));
      expect(field.top, greaterThanOrEqualTo(0));
    });
  });

  group('time wheel sheet', () {
    Widget opener() => Builder(
      builder: (context) => TextButton(
        onPressed: () => showMinutePicker(
          context,
          current: 8 * 60,
          help: 'Hora de inicio del bloque de horas extra',
        ),
        child: const Text('abrir'),
      ),
    );

    for (final (size, scale, dark) in [
      (const Size(320, 640), 3.1, false),
      (const Size(414, 896), 3.1, true),
      (const Size(414, 896), 1.0, false),
      (const Size(844, 390), 3.1, false),
      (const Size(844, 390), 1.0, true),
    ]) {
      testWidgets(
        '$size x$scale${dark ? ' dark' : ''}: no overflow, title and both '
        'buttons visible',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            app(
              Scaffold(body: opener()),
              platform: TargetPlatform.iOS,
              scale: scale,
              dark: dark,
            ),
          );
          await tester.tap(find.text('abrir'));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          final screen = Offset.zero & size;
          for (final key in [
            'time-picker-title',
            'time-picker-cancel',
            'time-picker-done',
          ]) {
            // The sheet scrolls in a short window: bring each into view.
            await tester.ensureVisible(find.byKey(ValueKey(key)));
            await tester.pumpAndSettle();
            final rect = tester.getRect(find.byKey(ValueKey(key)));
            expect(screen.contains(rect.topLeft), isTrue, reason: '$key $rect');
            expect(
              screen.contains(rect.bottomRight - const Offset(1, 1)),
              isTrue,
              reason: '$key $rect',
            );
          }
          // One touch target each, whatever the text size.
          for (final key in ['time-picker-cancel', 'time-picker-done']) {
            final rect = tester.getRect(find.byKey(ValueKey(key)));
            expect(rect.height, greaterThanOrEqualTo(48 - 0.5));
          }
          // The buttons do not overlap each other.
          expect(
            tester
                .getRect(find.byKey(const ValueKey('time-picker-cancel')))
                .right,
            lessThanOrEqualTo(
              tester
                  .getRect(find.byKey(const ValueKey('time-picker-done')))
                  .left,
            ),
          );
          // The themed sheet, not a bare popup.
          expect(find.byType(BottomSheet), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('«Listo» is the emphasised button', (tester) async {
      await tester.pumpWidget(
        app(Scaffold(body: opener()), platform: TargetPlatform.iOS),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      final done = tester.widget<Text>(find.text('Listo'));
      final cancel = tester.widget<Text>(find.text('Cancelar'));
      expect(
        done.style!.fontWeight!.value,
        greaterThan(cancel.style!.fontWeight?.value ?? 400),
      );
    });
  });

  group('sheet opened over a focused field', () {
    testWidgets('closing the sheet does not give the focus back to the field '
        'below (1.1.0 QA, iPhone F5)', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        app(
          Scaffold(
            body: Column(
              children: [
                TextField(key: const ValueKey('note'), focusNode: focus),
                Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showAppSheet<void>(
                      context: context,
                      padded: true,
                      builder: (sheet) => TextButton(
                        onPressed: () => Navigator.of(sheet).pop(),
                        child: const Text('guardar'),
                      ),
                    ),
                    child: const Text('abrir'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('note')));
      await tester.pump();
      expect(focus.hasPrimaryFocus, isTrue);

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('guardar'));
      await tester.pumpAndSettle();

      expect(find.text('guardar'), findsNothing);
      expect(focus.hasFocus, isFalse);
    });
  });

  group('sheet opened over a button', () {
    testWidgets('a button that had the focus gets it back when the sheet '
        'closes', (tester) async {
      final launcher = FocusNode();
      addTearDown(launcher.dispose);
      await tester.pumpWidget(
        app(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                focusNode: launcher,
                onPressed: () => showAppSheet<void>(
                  context: context,
                  padded: true,
                  builder: (sheet) => TextButton(
                    onPressed: () => Navigator.of(sheet).pop(),
                    child: const Text('guardar'),
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      launcher.requestFocus();
      await tester.pump();
      expect(launcher.hasPrimaryFocus, isTrue);

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('guardar'));
      await tester.pumpAndSettle();

      expect(launcher.hasPrimaryFocus, isTrue);
    });

    testWidgets('an unsaved note survives a nested sheet and does not take '
        'the focus back', (tester) async {
      final focus = FocusNode();
      final note = TextEditingController();
      addTearDown(focus.dispose);
      addTearDown(note.dispose);
      var lostFocus = 0;
      focus.addListener(() {
        if (!focus.hasFocus) lostFocus++;
      });
      await tester.pumpWidget(
        app(
          Scaffold(
            body: Column(
              children: [
                TextField(
                  key: const ValueKey('note'),
                  controller: note,
                  focusNode: focus,
                ),
                Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showAppSheet<void>(
                      context: context,
                      padded: true,
                      builder: (outer) => Builder(
                        builder: (outerContext) => TextButton(
                          onPressed: () => showAppSheet<void>(
                            context: outerContext,
                            padded: true,
                            builder: (inner) => TextButton(
                              onPressed: () => Navigator.of(inner).pop(),
                              child: const Text('guardar'),
                            ),
                          ),
                          child: const Text('otra'),
                        ),
                      ),
                    ),
                    child: const Text('abrir'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('note')));
      await tester.enterText(find.byKey(const ValueKey('note')), 'a medias');
      await tester.pump();

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      // The note committed on losing the focus, once.
      expect(lostFocus, 1);
      await tester.tap(find.text('otra'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('guardar'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(note.text, 'a medias');
      expect(focus.hasFocus, isFalse);
    });
  });
}
