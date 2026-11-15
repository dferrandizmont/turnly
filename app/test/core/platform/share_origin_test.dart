import 'package:cuadrante/core/platform/share_origin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  rememberTests();
  testWidgets('fallback is a non-zero rect inside the view', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final rect = shareOrigin();
    expect(rect.isEmpty, isFalse);
    expect(rect.center, const Offset(200, 300));
    expect(const Rect.fromLTWH(0, 0, 400, 600).contains(rect.topLeft), isTrue);
    expect(
      const Rect.fromLTWH(0, 0, 400, 600).contains(rect.bottomRight),
      isTrue,
    );
  });

  testWidgets('uses the global rect of the given context', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 30, top: 50),
            child: SizedBox(key: key, width: 100, height: 40),
          ),
        ),
      ),
    );
    final rect = shareOrigin(key.currentContext);
    expect(rect, const Rect.fromLTWH(30, 50, 100, 40));
  });

  testWidgets('falls back when the context is not laid out', (tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          captured = context;
          return const SizedBox.shrink();
        },
      ),
    );
    await tester.pumpWidget(const SizedBox());
    final rect = shareOrigin(captured);
    expect(rect.isEmpty, isFalse);
  });
}

void rememberTests() {
  testWidgets('remembered button rect is used once, then fallback', (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 10, top: 20),
            child: SizedBox(key: key, width: 60, height: 30),
          ),
        ),
      ),
    );
    rememberShareOrigin(key.currentContext!);
    expect(shareOrigin(), const Rect.fromLTWH(10, 20, 60, 30));
    final second = shareOrigin();
    expect(second.isEmpty, isFalse);
    expect(second, isNot(const Rect.fromLTWH(10, 20, 60, 30)));
  });

  testWidgets('remembered rect outside a resized view falls back', (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.bottomRight,
          child: SizedBox(key: key, width: 60, height: 30),
        ),
      ),
    );
    rememberShareOrigin(key.currentContext!);
    tester.view.physicalSize = const Size(200, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final rect = shareOrigin();
    expect(const Rect.fromLTWH(0, 0, 200, 200).overlaps(rect), isTrue);
    expect(rect.center, const Offset(100, 100));
  });
}
