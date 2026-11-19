import 'package:cuadrante/core/platform/window_controls.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/window_controls');

  void answer(Object? Function() handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => handler());
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<EdgeInsets> padding(WidgetTester tester) async {
    late EdgeInsets seen;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          padding: EdgeInsets.only(top: 10, bottom: 20),
          viewPadding: EdgeInsets.only(top: 10, bottom: 20),
        ),
        child: WindowControlsInset(
          channel: channel,
          child: Builder(
            builder: (context) {
              seen = MediaQuery.paddingOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pump();
    return seen;
  }

  testWidgets('raises the top padding to clear the window controls', (
    tester,
  ) async {
    answer(() => 53.0);
    final seen = await padding(tester);
    expect(seen.top, 53);
    expect(seen.bottom, 20);
  });

  testWidgets('leaves the padding alone when there are no controls', (
    tester,
  ) async {
    answer(() => 0.0);
    expect((await padding(tester)).top, 10);
  });

  testWidgets('never lowers a bigger safe area', (tester) async {
    answer(() => 6.0);
    expect((await padding(tester)).top, 10);
  });

  testWidgets('a failing channel changes nothing', (tester) async {
    answer(() => throw PlatformException(code: 'x'));
    expect((await padding(tester)).top, 10);
  });

  Future<void> pushFromNative(WidgetTester tester, double? top) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(MethodCall('topInset', top)),
      (_) {},
    );
    await tester.pump();
  }

  testWidgets('a push from Swift moves the padding, and back', (tester) async {
    answer(() => 0.0);
    late EdgeInsets seen;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          padding: EdgeInsets.only(top: 10),
          viewPadding: EdgeInsets.only(top: 10),
        ),
        child: WindowControlsInset(
          channel: channel,
          child: Builder(
            builder: (context) {
              seen = MediaQuery.paddingOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(seen.top, 10);

    await pushFromNative(tester, 53);
    expect(seen.top, 53);

    await pushFromNative(tester, 0);
    expect(seen.top, 10);
  });

  testWidgets('padding is the view padding minus what the keyboard covers', (
    tester,
  ) async {
    answer(() => 53.0);
    late MediaQueryData seen;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          padding: EdgeInsets.only(top: 10),
          viewPadding: EdgeInsets.only(top: 10),
          viewInsets: EdgeInsets.only(top: 20),
        ),
        child: WindowControlsInset(
          channel: channel,
          child: Builder(
            builder: (context) {
              seen = MediaQuery.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(seen.viewPadding.top, 53);
    expect(seen.padding.top, 33);
  });
}
