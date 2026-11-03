import 'dart:typed_data';

import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/router.dart';
import 'package:cuadrante/features/notes/application/notes_providers.dart';
import 'package:cuadrante/features/notes/data/attachment_picker.dart';
import 'package:cuadrante/features/notes/data/sketch_png.dart';
import 'package:cuadrante/features/notes/domain/note_attachment.dart';
import 'package:cuadrante/features/notes/domain/sketch.dart';
import 'package:cuadrante/features/notes/presentation/attachment_viewer_screen.dart';
import 'package:cuadrante/features/notes/presentation/sketch_screen.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_attachment_store.dart';
import '../../support/real_font.dart';
import '../calendar/day_sheet_finders.dart';
import '../calendar/harness.dart';

// P2 · Notas con fotos, dibujo y tareas: the sections of the day detail (the
// strip of attachments and the checklist of the day) and the canvas of the
// drawing. Demo data of `pumpCalendar` (19 Oct 2026).
//
// The files of the attachments are in memory (`FakeAttachmentStore`): a test
// of a widget never writes a file (the fake time and the E/S of the system
// do not mix).

const _today = CivilDate(2026, 10, 19);

Finder _key(String value) => find.byKey(ValueKey(value));

/// A picker that always gives the same file (there is no camera in a test).
class _FakePicker implements AttachmentPicker {
  _FakePicker(this.result);

  final PickResult result;
  PhotoSource? lastSource;

  @override
  Future<PickResult> pickPhoto(PhotoSource source) async {
    lastSource = source;
    return result;
  }

  @override
  Future<PickResult> pickFile() async => result;
}

/// The store of the files of the attachments, in memory.
Override _storeOverride() =>
    attachmentStoreProvider.overrideWith((ref) => FakeAttachmentStore());

/// Lets the pending work (the database, the providers) finish and draws it.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pumpAndSettle();
  }
}

/// The bytes of a small PNG (the smallest valid one).
Uint8List _pngBytes() =>
    SketchPng.encode(const Sketch(width: 4, height: 4));

Future<void> _openDay(WidgetTester tester, CivilDate date) async {
  await revealCell(tester, date);
  await tester.tap(cell(date));
  await tester.pumpAndSettle();
  await openDayMore(tester);
}

/// Taps the «Añadir» of the empty state (it can be out of the screen).
Future<void> _tapAdd(WidgetTester tester) async {
  final add = _key('day-attachments-add-empty');
  await tester.ensureVisible(add);
  await tester.pumpAndSettle();
  await tester.tap(add);
  await tester.pumpAndSettle();
}

/// The attachments stored for the day.
Future<List<NoteAttachment>> _attachments(
  WidgetTester tester,
  ProviderContainer container,
) async {
  final repository = container.read(noteAttachmentsRepositoryProvider);
  return (await tester.runAsync(
    () => repository.forDay('main', _today),
  ))!;
}

/// The tasks stored for the day.
Future<int> _taskCount(WidgetTester tester, ProviderContainer container) async {
  final repository = container.read(dayTasksRepositoryProvider);
  return (await tester.runAsync(
    () => repository.forDay('main', _today),
  ))!.length;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeLocale();
    expect(await loadRoboto(), isTrue, reason: 'Roboto from the Flutter SDK');
  });

  group('the attachments of the day', () {
    testWidgets('the empty state and the sheet that adds one', (tester) async {
      await pumpCalendar(
        tester,
        size: const Size(390, 1600),
        overrides: [
          _storeOverride(),
          attachmentPickerProvider.overrideWithValue(
            _FakePicker(
              PickedFile(
                PickedAttachment(bytes: _pngBytes(), mimeType: 'image/png'),
              ),
            ),
          ),
        ],
      );
      await _openDay(tester, _today);

      expect(_key('day-attachments-section'), findsOneWidget);
      expect(_key('day-attachments-empty'), findsOneWidget);
      expect(find.text('Todavía no hay fotos ni archivos'), findsOneWidget);

      // The sheet offers the four ways of adding something.
      await _tapAdd(tester);
      expect(find.text('Hacer una foto'), findsOneWidget);
      expect(find.text('Elegir de la galería'), findsOneWidget);
      expect(find.text('Elegir un archivo'), findsOneWidget);
      expect(find.text('Dibujar'), findsOneWidget);
    });

    testWidgets('a photo of the gallery is stored and shown', (tester) async {
      final picker = _FakePicker(
        PickedFile(
          PickedAttachment(bytes: _pngBytes(), mimeType: 'image/png'),
        ),
      );
      await pumpCalendar(
        tester,
        size: const Size(390, 1600),
        overrides: [
          _storeOverride(),
          attachmentPickerProvider.overrideWithValue(picker),
        ],
      );
      final container = containerOf(tester);
      await _openDay(tester, _today);

      await _tapAdd(tester);
      await tester.tap(_key('add-gallery'));
      await _settle(tester);

      expect(picker.lastSource, PhotoSource.gallery);
      final stored = await _attachments(tester, container);
      expect(stored, hasLength(1));
      expect(stored.single.kind, AttachmentKind.photo);
      expect(stored.single.calendarId, 'main');
      expect(stored.single.date, _today);
      // The strip shows it.
      expect(_key('day-attachments-strip'), findsOneWidget);
      expect(_key('attachment-${stored.single.id}'), findsOneWidget);
    });

    testWidgets('a file keeps its name and its type', (tester) async {
      final picker = _FakePicker(
        PickedFile(
          PickedAttachment(
            bytes: Uint8List.fromList([1, 2, 3]),
            mimeType: 'application/pdf',
            displayName: 'nomina.pdf',
          ),
        ),
      );
      await pumpCalendar(
        tester,
        size: const Size(390, 1600),
        overrides: [
          _storeOverride(),
          attachmentPickerProvider.overrideWithValue(picker),
        ],
      );
      final container = containerOf(tester);
      await _openDay(tester, _today);

      await _tapAdd(tester);
      await tester.tap(_key('add-file'));
      await _settle(tester);

      final stored = await _attachments(tester, container);
      expect(stored, hasLength(1));
      expect(stored.single.kind, AttachmentKind.file);
      expect(stored.single.displayName, 'nomina.pdf');
      expect(stored.single.mimeType, 'application/pdf');
    });

    testWidgets('a file that is too big is not stored', (tester) async {
      final picker = _FakePicker(const PickFailed(PickProblem.tooLarge));
      await pumpCalendar(
        tester,
        size: const Size(390, 1600),
        overrides: [
          _storeOverride(),
          attachmentPickerProvider.overrideWithValue(picker),
        ],
      );
      final container = containerOf(tester);
      await _openDay(tester, _today);

      await _tapAdd(tester);
      await tester.tap(_key('add-file'));
      await _settle(tester);

      expect(await _attachments(tester, container), isEmpty);
      expect(
        find.text('Ese archivo es demasiado grande (el máximo son 50 MB).'),
        findsOneWidget,
      );
    });

    testWidgets('a denied permission is said inside the section', (
      tester,
    ) async {
      final picker = _FakePicker(
        const PickFailed(PickProblem.cameraDenied),
      );
      await pumpCalendar(
        tester,
        size: const Size(390, 1600),
        overrides: [
          _storeOverride(),
          attachmentPickerProvider.overrideWithValue(picker),
        ],
      );
      final container = containerOf(tester);
      await _openDay(tester, _today);

      await _tapAdd(tester);
      await tester.tap(_key('add-photo'));
      await _settle(tester);

      expect(picker.lastSource, PhotoSource.camera);
      expect(await _attachments(tester, container), isEmpty);
      expect(
        find.text('Sin el permiso no podemos abrir la cámara.'),
        findsOneWidget,
      );
      expect(_key('day-attachments-error'), findsOneWidget);
    });

    testWidgets('the attachment is removed and the undo brings it back', (
      tester,
    ) async {
      await pumpCalendar(
        tester,
        size: const Size(390, 1600),
        overrides: [
          _storeOverride(),
          attachmentPickerProvider.overrideWithValue(
            _FakePicker(
              PickedFile(
                PickedAttachment(bytes: _pngBytes(), mimeType: 'image/png'),
              ),
            ),
          ),
        ],
      );
      final container = containerOf(tester);
      await _openDay(tester, _today);
      await _tapAdd(tester);
      await tester.tap(_key('add-gallery'));
      await _settle(tester);

      final stored = await _attachments(tester, container);
      expect(stored, hasLength(1));

      // A long press on the thumbnail takes it away, with the undo next to
      // the strip (a notice would hide behind the sheet of the day).
      await tester.longPress(_key('attachment-${stored.single.id}'));
      await _settle(tester);
      expect(await _attachments(tester, container), isEmpty);
      expect(_key('day-attachments-undo'), findsOneWidget);
      expect(find.text('Se quitó Foto'), findsOneWidget);

      await tester.tap(_key('day-attachments-undo-button'));
      await _settle(tester);
      final back = await _attachments(tester, container);
      expect(back, hasLength(1));
      expect(back.single.kind, AttachmentKind.photo);
      expect(back.single.sizeBytes, _pngBytes().length);
      expect(_key('day-attachments-undo'), findsNothing);
    });

    testWidgets('the full screen opens the attachment and takes it away', (
      tester,
    ) async {
      await pumpCalendar(
        tester,
        size: const Size(390, 844),
        overrides: [
          _storeOverride(),
          attachmentPickerProvider.overrideWithValue(
            _FakePicker(
              PickedFile(
                PickedAttachment(bytes: _pngBytes(), mimeType: 'image/png'),
              ),
            ),
          ),
        ],
      );
      final container = containerOf(tester);
      await _openDay(tester, _today);
      await _tapAdd(tester);
      await tester.tap(_key('add-gallery'));
      await _settle(tester);

      final stored = await _attachments(tester, container);
      expect(stored, hasLength(1));

      // The thumbnail opens it full screen.
      await tester.tap(_key('attachment-${stored.single.id}'));
      await _settle(tester);
      expect(find.byType(AttachmentViewerScreen), findsOneWidget);
      expect(_key('attachment-view-image'), findsOneWidget);

      // «Quitar» takes it off the day and comes back to the detail, which
      // offers the undo.
      await tester.tap(_key('attachment-remove'));
      await _settle(tester);
      expect(await _attachments(tester, container), isEmpty);
      expect(_key('day-attachments-undo'), findsOneWidget);
    });
  });

  group('the tasks of the day', () {
    testWidgets('a task is written, ticked, moved and removed', (tester) async {
      await pumpCalendar(tester, size: const Size(390, 1600));
      final container = containerOf(tester);
      await _openDay(tester, _today);

      expect(_key('day-tasks-section'), findsOneWidget);
      expect(_key('day-tasks-empty'), findsOneWidget);
      expect(find.text('Este día no tiene tareas.'), findsOneWidget);

      // Two tasks.
      for (final title in ['Comprar pan', 'Llamar al hospital']) {
        await tester.enterText(_key('day-task-field'), title);
        await tester.tap(_key('day-task-add'));
        await _settle(tester);
      }
      expect(await _taskCount(tester, container), 2);
      expect(find.text('Comprar pan'), findsOneWidget);
      expect(find.text('Llamar al hospital'), findsOneWidget);

      // The list is in the order it was written in.
      final repository = container.read(dayTasksRepositoryProvider);
      final tasks = (await tester.runAsync(
        () => repository.forDay('main', _today),
      ))!;
      expect(tasks.first.title, 'Comprar pan');
      expect(tasks.last.title, 'Llamar al hospital');

      // Ticking one keeps it in the list.
      await tester.tap(_key('task-check-${tasks.first.id}'));
      await _settle(tester);
      final ticked = (await tester.runAsync(
        () => repository.forDay('main', _today),
      ))!;
      expect(ticked.first.done, isTrue);

      // Moving it down puts it after the other one.
      await tester.tap(_key('task-menu-${tasks.first.id}'));
      await tester.pumpAndSettle();
      await tester.tap(_key('task-menu-down-${tasks.first.id}'));
      await _settle(tester);
      final moved = (await tester.runAsync(
        () => repository.forDay('main', _today),
      ))!;
      expect(moved.first.title, 'Llamar al hospital');
      expect(moved.last.title, 'Comprar pan');

      // The undo of the header takes the last change back.
      await tester.tap(_key('day-tasks-undo'));
      await _settle(tester);
      final undone = (await tester.runAsync(
        () => repository.forDay('main', _today),
      ))!;
      expect(undone.first.title, 'Comprar pan');

      // And removing it takes it out of the list.
      await tester.tap(_key('task-menu-${tasks.first.id}'));
      await tester.pumpAndSettle();
      await tester.tap(_key('task-menu-remove-${tasks.first.id}'));
      await _settle(tester);
      expect(await _taskCount(tester, container), 1);
      expect(find.text('Comprar pan'), findsNothing);
    });

    testWidgets('an empty task is not written', (tester) async {
      await pumpCalendar(tester, size: const Size(390, 1600));
      final container = containerOf(tester);
      await _openDay(tester, _today);

      await tester.tap(_key('day-task-add'));
      await _settle(tester);
      expect(await _taskCount(tester, container), 0);
      expect(find.text('Escribe qué hay que hacer.'), findsOneWidget);
    });
  });

  group('the drawing', () {
    testWidgets('a stroke is saved as an attachment of the day', (
      tester,
    ) async {
      await pumpCalendar(
        tester,
        size: const Size(390, 844),
        overrides: [_storeOverride()],
      );
      final container = containerOf(tester);
      container.read(routerProvider).go(AppRoutes.sketchFor(_today, 'main'));
      await _settle(tester);

      expect(find.byType(SketchScreen), findsOneWidget);
      expect(_key('sketch-canvas'), findsOneWidget);

      // A stroke on the canvas.
      final canvas = tester.getRect(_key('sketch-canvas'));
      await tester.dragFrom(
        Offset(canvas.left + 40, canvas.top + 40),
        const Offset(120, 90),
      );
      await tester.pumpAndSettle();
      expect(_key('sketch-empty-hint'), findsNothing);

      await tester.tap(_key('sketch-save'));
      await _settle(tester);

      final stored = await _attachments(tester, container);
      expect(stored, hasLength(1));
      expect(stored.single.kind, AttachmentKind.sketch);
      expect(stored.single.mimeType, 'image/png');
      // The PNG carries the strokes: the drawing can be reopened.
      final store = container.read(attachmentStoreProvider).value;
      expect(store, isNotNull);
      final bytes = await tester.runAsync(
        () => store!.read(stored.single.relativePath),
      );
      final sketch = SketchPng.decode(bytes!);
      expect(sketch, isNotNull);
      expect(sketch!.strokes, isNotEmpty);
    });

    testWidgets('the undo and the redo of the canvas', (tester) async {
      await pumpCalendar(tester, size: const Size(390, 844));
      final container = containerOf(tester);
      container.read(routerProvider).go(AppRoutes.sketchFor(_today, 'main'));
      await _settle(tester);

      final canvas = tester.getRect(_key('sketch-canvas'));
      await tester.dragFrom(
        Offset(canvas.left + 40, canvas.top + 40),
        const Offset(100, 60),
      );
      await tester.pumpAndSettle();
      expect(_key('sketch-empty-hint'), findsNothing);

      // Undo takes the stroke away, redo brings it back.
      await tester.tap(_key('sketch-undo'));
      await tester.pumpAndSettle();
      expect(_key('sketch-empty-hint'), findsOneWidget);
      await tester.tap(_key('sketch-redo'));
      await tester.pumpAndSettle();
      expect(_key('sketch-empty-hint'), findsNothing);

      // And the eraser takes the strokes it passes over.
      await tester.tap(find.text('Borrador'));
      await tester.pumpAndSettle();
      await tester.dragFrom(
        Offset(canvas.left + 40, canvas.top + 40),
        const Offset(140, 100),
      );
      await tester.pumpAndSettle();
      expect(_key('sketch-empty-hint'), findsOneWidget);
    });
  });

  group('the labels of the reader of screen', () {
    testWidgets('the controls that are not text are named', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpCalendar(
        tester,
        size: const Size(390, 1600),
        overrides: [
          _storeOverride(),
          attachmentPickerProvider.overrideWithValue(
            _FakePicker(
              PickedFile(
                PickedAttachment(bytes: _pngBytes(), mimeType: 'image/png'),
              ),
            ),
          ),
        ],
      );
      final container = containerOf(tester);
      await _openDay(tester, _today);

      // The thumbnail says what it opens and how to take it off the day.
      await _tapAdd(tester);
      await tester.tap(_key('add-gallery'));
      await _settle(tester);
      final stored = await _attachments(tester, container);
      expect(stored, hasLength(1));
      final tile = find.bySemanticsLabel(RegExp('Abrir Foto'));
      expect(tile, findsOneWidget);
      expect(tester.getSemantics(tile).label, contains('Abrir Foto'));
      expect(tester.getSemantics(tile).hint, contains('Mantén pulsado'));

      // The tools of the canvas say what they are.
      container.read(routerProvider).go(AppRoutes.sketchFor(_today, 'main'));
      await _settle(tester);
      expect(find.byTooltip('Deshacer el trazo'), findsOneWidget);
      expect(find.byTooltip('Rehacer el trazo'), findsOneWidget);
      expect(find.byTooltip('Borrar el dibujo'), findsOneWidget);
      semantics.dispose();
    });
  });

  group('layout', () {
    for (final (size, scale, brightness) in [
      (const Size(390, 844), 1.0, Brightness.light),
      (const Size(390, 844), 2.0, Brightness.dark),
      (const Size(320, 568), 1.0, Brightness.dark),
      (const Size(320, 568), 2.0, Brightness.light),
    ]) {
      testWidgets('the sections at ${size.width.toInt()}x'
          '${size.height.toInt()}, text $scale, ${brightness.name}', (
        tester,
      ) async {
        await pumpCalendar(
          tester,
          size: size,
          textScale: scale,
          brightness: brightness,
          overrides: [
            _storeOverride(),
            attachmentPickerProvider.overrideWithValue(
              _FakePicker(
                PickedFile(
                  PickedAttachment(bytes: _pngBytes(), mimeType: 'image/png'),
                ),
              ),
            ),
          ],
        );
        final container = containerOf(tester);
        await _openDay(tester, _today);
        expect(tester.takeException(), isNull);

        // The strip of the attachments and the checklist fit.
        await _tapAdd(tester);
        await tester.tap(_key('add-gallery'));
        await _settle(tester);
        expect(tester.takeException(), isNull);

        await tester.enterText(_key('day-task-field'), 'Comprar pan');
        await tester.ensureVisible(_key('day-task-add'));
        await tester.pumpAndSettle();
        await tester.tap(_key('day-task-add'));
        await _settle(tester);
        expect(tester.takeException(), isNull);

        // The canvas fits too.
        container.read(routerProvider).go(AppRoutes.sketchFor(_today, 'main'));
        await _settle(tester);
        expect(find.byType(SketchScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
