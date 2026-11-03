import 'dart:io';
import 'dart:typed_data';

import 'package:cuadrante/features/calendar/application/calendar_background_service.dart';
import 'package:cuadrante/features/calendar/data/calendar_background_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_storage.dart';

/// «Imagen de fondo del calendario» (UX · Extras visuales): the picture is
/// written atomically inside its own folder of the app, a name read from the
/// database can never escape it, a replaced picture leaves no leftovers and a
/// picture that is too big is refused before anything is touched.
Uint8List _bytes(int length) => Uint8List.fromList(List<int>.filled(length, 7));

void main() {
  late Directory root;
  late CalendarBackgroundStore store;

  setUp(() {
    root = makeTempDir('calendar-background');
    store = CalendarBackgroundStore(root);
  });

  test('save writes the file and reports its name', () async {
    final name = await store.save(_bytes(10), stamp: 1000);
    expect(name, 'bg-1000.img');
    expect(isSafeCalendarBackgroundName(name), isTrue);
    expect(await store.exists(name), isTrue);
    expect(await store.file(name).readAsBytes(), equals(_bytes(10)));
  });

  test('a name that could leave the folder is never used', () async {
    for (final name in ['../secret', 'a/b', 'a\\b', '.hidden', '', 'x' * 200]) {
      expect(isSafeCalendarBackgroundName(name), isFalse, reason: name);
      expect(await store.exists(name), isFalse, reason: name);
      expect(await store.delete(name), isFalse, reason: name);
    }
  });

  test('sweep removes every file but the one kept', () async {
    final keep = await store.save(_bytes(4), stamp: 1);
    final gone = await store.save(_bytes(4), stamp: 2);
    await store.sweep(keep);
    expect(await store.exists(keep), isTrue);
    expect(await store.exists(gone), isFalse);
    // A sweep with nothing to keep clears the folder.
    await store.sweep(null);
    expect(await store.exists(keep), isFalse);
  });

  test('delete removes a stored file, once', () async {
    final name = await store.save(_bytes(4), stamp: 4);
    expect(await store.delete(name), isTrue);
    expect(await store.exists(name), isFalse);
    expect(await store.delete(name), isFalse);
  });

  test('too big is refused before anything is written', () async {
    await expectLater(
      store.save(Uint8List(maxCalendarBackgroundBytes + 1), stamp: 3),
      throwsA(
        isA<CalendarBackgroundException>().having(
          (e) => e.problem,
          'problem',
          CalendarBackgroundProblem.tooLarge,
        ),
      ),
    );
    // Nothing was written: the folder is the empty one of the test.
    expect(root.listSync(), isEmpty);
  });

  group('service', () {
    test(
      'setFromBytes saves, points the preference and sweeps the old file',
      () async {
        final old = await store.save(_bytes(3), stamp: 1);
        String? applied;
        final service = CalendarBackgroundService(
          store: store,
          now: () => DateTime.fromMillisecondsSinceEpoch(2000),
          applyPath: (path) async => applied = path,
        );

        await service.setFromBytes(_bytes(5));

        expect(applied, 'bg-2000.img');
        expect(await store.exists('bg-2000.img'), isTrue);
        expect(await store.exists(old), isFalse);
      },
    );

    test('remove clears the preference and the folder', () async {
      final name = await store.save(_bytes(3), stamp: 1);
      String? applied = 'something';
      final service = CalendarBackgroundService(
        store: store,
        now: () => DateTime.fromMillisecondsSinceEpoch(3000),
        applyPath: (path) async => applied = path,
      );

      await service.remove();

      expect(applied, isNull);
      expect(await store.exists(name), isFalse);
    });

    test('a picture that is too big leaves the stored one in place', () async {
      final name = await store.save(_bytes(3), stamp: 1);
      String? applied;
      final service = CalendarBackgroundService(
        store: store,
        now: () => DateTime.fromMillisecondsSinceEpoch(4000),
        applyPath: (path) async => applied = path,
      );

      await expectLater(
        service.setFromBytes(Uint8List(maxCalendarBackgroundBytes + 1)),
        throwsA(isA<CalendarBackgroundException>()),
      );
      expect(applied, isNull);
      expect(await store.exists(name), isTrue);
    });
  });
}
