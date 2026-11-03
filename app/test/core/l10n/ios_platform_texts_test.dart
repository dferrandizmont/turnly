import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/theme/app_theme.dart';
import 'package:cuadrante/features/calendar_export/domain/device_calendar_api.dart';
import 'package:cuadrante/features/calendar_export/presentation/calendar_permission_card.dart';
import 'package:cuadrante/features/settings/presentation/faq_screen.dart';
import 'package:cuadrante/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// On an iPhone the texts name what an iPhone has: iCloud Drive instead of
/// Drive, and the app's own page in the system settings instead of Android's
/// «Permisos». Android keeps its texts.
void main() {
  setUpAll(initializeLocale);

  // Android's own wording, which must not reach an iPhone.
  final androidPermissions = RegExp(r'Permis|Baimenak');
  // "Drive" not preceded by "iCloud " (Google Drive).
  final plainDrive = RegExp(r'(?<!iCloud )Drive');

  for (final language in ['es', 'ca', 'gl', 'eu', 'en']) {
    test(
      '$language: the iOS texts name iCloud Drive and the app settings',
      () async {
        final l10n = await AppLocalizations.delegate.load(Locale(language));

        final ios = {
          'faqBackupAIos': l10n.faqBackupAIos,
          'backupUiWarningIos': l10n.backupUiWarningIos,
          'backupUiExportSubtitleIos': l10n.backupUiExportSubtitleIos,
        };
        for (final MapEntry(:key, :value) in ios.entries) {
          expect(value, contains('iCloud Drive'), reason: key);
          expect(value, isNot(contains(plainDrive)), reason: key);
        }
        expect(
          l10n.calExportPermissionDeniedBodyIos,
          isNot(contains(androidPermissions)),
        );
        expect(l10n.calExportPermissionDeniedBodyIos, contains('Turnly ›'));
        // App Review 2.3.10: no other platform named on iOS.
        expect(l10n.alarmsPermNotifBlockedBodyIos, isNot(contains('Android')));
        expect(l10n.alarmsPermNotifBlockedBody, contains('Android'));
        // iOS has no exact-alarm permission.
        expect(
          l10n.alarmsPermOkBodyIos.toLowerCase(),
          isNot(contains(RegExp(r'exact|zehatz'))),
        );
        expect(
          l10n.alarmsPermOkBody.toLowerCase(),
          contains(RegExp(r'exact|zehatz')),
        );

        // Android keeps Drive and «Permisos».
        for (final android in [
          l10n.faqBackupA,
          l10n.backupUiWarning,
          l10n.backupUiExportSubtitle,
        ]) {
          expect(android, contains(plainDrive));
        }
        expect(
          l10n.calExportPermissionDeniedBody,
          contains(androidPermissions),
        );
      },
    );

    test('$language: the backup FAQ answer follows the platform', () async {
      final l10n = await AppLocalizations.delegate.load(Locale(language));
      String backup(TargetPlatform platform) => faqEntries(
        l10n,
        platform: platform,
      ).singleWhere((e) => e.id == 'backup').answer;
      expect(backup(TargetPlatform.iOS), l10n.faqBackupAIos);
      expect(backup(TargetPlatform.android), l10n.faqBackupA);
    });
  }

  testWidgets(
    'the refused calendar permission points to the right settings',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CalendarPermissionCard(
              access: CalendarAccess.denied,
              purpose: CalendarPermissionPurpose.write,
              onRequest: () {},
              onOpenSettings: () {},
              onRecheck: () {},
            ),
          ),
        ),
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('es'));
      final ios = defaultTargetPlatform == TargetPlatform.iOS;
      expect(
        find.text(
          ios
              ? l10n.calExportPermissionDeniedBodyIos
              : l10n.calExportPermissionDeniedBody,
        ),
        findsOneWidget,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS)
      ..values.add(TargetPlatform.android),
  );
}
