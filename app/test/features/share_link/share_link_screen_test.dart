import 'package:cuadrante/features/share_link/data/share_link_api.dart';
import 'package:cuadrante/features/share_link/presentation/share_link_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../support/app_harness.dart';
import 'share_link_support.dart';

const _size = Size(390, 2600);

Future<AppUnderTest> openShare(
  WidgetTester tester,
  FakeShareApi? api, {
  List<String>? shared,
}) async {
  final app = await AppUnderTest.pump(
    tester,
    size: _size,
    overrides: [
      ...shareOverrides(api),
      shareLinkTextSenderProvider.overrideWithValue((text) async {
        shared?.add(text);
      }),
    ],
  );
  await app.openSettings();
  await tester.ensureVisible(byKey('settings-share-link'));
  await tester.pumpAndSettle();
  await tester.tap(byKey('settings-share-link'));
  await tester.pumpAndSettle();
  return app;
}

void main() {
  setUpShareTests();

  testWidgets('the row opens the screen; with no worker it says so', (
    tester,
  ) async {
    await openShare(tester, null);
    expect(find.text('Compartir por enlace'), findsWidgets);
    expect(byKey('share-unavailable'), findsOneWidget);
    expect(find.text('Todavía no disponible'), findsOneWidget);
    expect(byKey('share-publish'), findsNothing);
  });

  testWidgets('before publishing: switches off and what goes out', (
    tester,
  ) async {
    final api = FakeShareApi();
    await openShare(tester, api);
    expect(byKey('share-publish'), findsOneWidget);
    expect(byKey('share-privacy'), findsOneWidget);
    final rest = tester.widget<Switch>(byKey('share-include-rest-switch'));
    final absences = tester.widget<Switch>(
      byKey('share-include-absences-switch'),
    );
    expect(rest.value, isFalse);
    expect(absences.value, isFalse);
    expect(byKey('share-qr'), findsNothing);
    expect(api.published, isEmpty);
  });

  testWidgets('cancelling the question publishes nothing', (tester) async {
    final api = FakeShareApi();
    await openShare(tester, api);
    await tester.tap(byKey('share-publish'));
    await tester.pumpAndSettle();
    expect(find.text('¿Publicar tus turnos?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(api.published, isEmpty);
    expect(byKey('share-qr'), findsNothing);
  });

  testWidgets('publish, copy, share and revoke', (tester) async {
    final api = FakeShareApi();
    final shared = <String>[];
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final app = await openShare(tester, api, shared: shared);

    await tester.tap(byKey('share-publish'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('share-publish-confirm'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();

    expect(api.published, hasLength(1));
    final url = stateOf(app).url.toString();
    expect(url, startsWith('https://share.example.test/f/'));
    expect(byKey('share-qr'), findsOneWidget);
    expect(tester.widget<QrImageView>(find.byType(QrImageView)), isNotNull);
    expect(find.text(url), findsOneWidget);
    expect(find.textContaining('Última publicación: '), findsOneWidget);
    expect(
      find.text('Se comparten los turnos de «Mi cuadrante».'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Código QR con el enlace de tus turnos'),
      findsOneWidget,
    );

    await tester.tap(byKey('share-copy'));
    await tester.pumpAndSettle();
    expect(copied, url);
    expect(find.text('Enlace copiado'), findsOneWidget);

    await tester.tap(byKey('share-share'));
    await tester.pumpAndSettle();
    expect(shared.single, contains(url));

    await tester.tap(byKey('share-revoke'));
    await tester.pumpAndSettle();
    expect(find.text('¿Revocar el enlace?'), findsOneWidget);
    await tester.tap(byKey('share-revoke-confirm'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(api.revoked, hasLength(1));
    expect(byKey('share-qr'), findsNothing);
    expect(byKey('share-publish'), findsOneWidget);
  });

  testWidgets('a failed publish shows the problem and no QR', (tester) async {
    final api = FakeShareApi()..failure = ShareLinkFailure.network;
    await openShare(tester, api);
    await tester.tap(byKey('share-publish'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('share-publish-confirm'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(byKey('share-problem'), findsOneWidget);
    expect(find.text('Todavía no se ha podido publicar.'), findsOneWidget);
    expect(byKey('share-qr'), findsNothing);
    expect(byKey('share-revoke'), findsOneWidget);
  });

  testWidgets('a revoked link says so and offers to publish again', (
    tester,
  ) async {
    final api = FakeShareApi()..failure = ShareLinkFailure.revoked;
    await openShare(tester, api);
    await tester.tap(byKey('share-publish'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('share-publish-confirm'));
    await tester.pumpAndSettle();
    expect(byKey('share-problem'), findsOneWidget);
    expect(find.textContaining('Este enlace se revocó'), findsOneWidget);
    expect(byKey('share-publish'), findsOneWidget);
    expect(byKey('share-revoke'), findsNothing);
    expect(byKey('share-qr'), findsNothing);
  });

  testWidgets('a pending revocation hides the link and blocks updates', (
    tester,
  ) async {
    final api = FakeShareApi();
    final app = await AppUnderTest.pump(
      tester,
      size: _size,
      overrides: shareOverrides(api),
    );
    await app.real(() => controllerOf(app).publish('main'));
    api.failure = ShareLinkFailure.rateLimited;
    await app.real(() => controllerOf(app).revoke());
    await app.openSettings();
    await tester.ensureVisible(byKey('settings-share-link'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('settings-share-link'));
    await tester.pumpAndSettle();
    expect(find.textContaining('La revocación está pendiente'), findsOneWidget);
    expect(byKey('share-qr'), findsNothing);
    expect(byKey('share-copy'), findsNothing);
    final refresh = tester.widget<OutlinedButton>(
      find.descendant(
        of: byKey('share-refresh'),
        matching: find.byWidgetPredicate((w) => w is OutlinedButton),
      ),
    );
    expect(refresh.onPressed, isNull);
    expect(byKey('share-revoke'), findsOneWidget);
  });

  testWidgets('dark mode keeps the QR on a light panel', (tester) async {
    final api = FakeShareApi();
    final app = await AppUnderTest.pump(
      tester,
      size: _size,
      platformBrightness: Brightness.dark,
      overrides: shareOverrides(api),
    );
    await app.real(() => controllerOf(app).publish('main'));
    await app.openSettings();
    await tester.ensureVisible(byKey('settings-share-link'));
    await tester.pumpAndSettle();
    expect(find.text('Enlace publicado'), findsOneWidget);
    await tester.tap(byKey('settings-share-link'));
    await tester.pumpAndSettle();
    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    expect(qr.backgroundColor.computeLuminance(), greaterThan(0.8));
    expect(qr.dataModuleStyle.color!.computeLuminance(), lessThan(0.2));
  });
}
