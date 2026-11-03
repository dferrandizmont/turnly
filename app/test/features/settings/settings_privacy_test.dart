import 'package:cuadrante/core/config.dart';
import 'package:cuadrante/core/providers.dart';
import 'package:cuadrante/core/theme/app_theme.dart';
import 'package:cuadrante/features/settings/presentation/sections/help_section.dart';
import 'package:cuadrante/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  const config = AppConfig(
    privacyUrl: 'https://example.test/privacidad/',
    privacyUrlEn: 'https://example.test/privacy/',
  );
  final row = find.byKey(const ValueKey('settings-privacy'));

  Future<void> pumpHelp(
    WidgetTester tester, {
    String language = 'es',
    AppConfig buildConfig = config,
  }) => tester.pumpWidget(
    ProviderScope(
      overrides: [appConfigProvider.overrideWithValue(buildConfig)],
      child: MaterialApp(
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light(),
        home: const Scaffold(body: HelpSection()),
      ),
    ),
  );

  test('default URLs match both website languages', () {
    const defaults = AppConfig();
    expect(
      defaults.privacyUrlFor('es'),
      'https://turnly.mainshai.com/privacy/',
    );
    expect(
      defaults.privacyUrlFor('en'),
      'https://turnly.mainshai.com/en/privacy/',
    );
  });

  for (final language in ['es', 'ca', 'gl', 'eu', 'en']) {
    testWidgets('$language: opens the correct external URL only after a tap', (
      tester,
    ) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return true;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );

      await pumpHelp(tester, language: language);
      await tester.pumpAndSettle();
      expect(row, findsOneWidget);
      expect(calls, isEmpty);
      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(calls, hasLength(1));
      expect(calls.single.method, 'launch');
      final arguments = calls.single.arguments as Map;
      expect(arguments['url'], config.privacyUrlFor(language));
      expect(arguments['useSafariVC'], isFalse);
      expect(arguments['useWebView'], isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  for (final failure in [
    'false',
    'exception',
    'missing-plugin',
    'invalid-url',
  ]) {
    testWidgets('$failure: shows a localised failure and keeps Settings', (
      tester,
    ) async {
      var calls = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls++;
        if (failure == 'exception') throw PlatformException(code: 'failed');
        if (failure == 'missing-plugin') throw MissingPluginException();
        return false;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await pumpHelp(
        tester,
        buildConfig: failure == 'invalid-url'
            ? const AppConfig(privacyUrl: 'file:///private')
            : config,
      );
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(calls, failure == 'invalid-url' ? 0 : 1);
      expect(row, findsOneWidget);
      expect(
        find.text(
          'No se ha podido abrir la política de privacidad. '
          'Prueba otra vez.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
