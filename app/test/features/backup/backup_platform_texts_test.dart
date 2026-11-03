import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/features/backup/data/platform_backup_channel.dart';
import 'package:cuadrante/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import 'backup_ui_support.dart';

/// The backup screen tells an iPhone to save the file to iCloud Drive, and
/// Android to Drive (the warning); the export line is the same on both.
void main() {
  setUpAll(initializeLocale);

  Finder key(String k) => find.byKey(ValueKey(k));

  testWidgets(
    'the warning names the drive of the platform; the export help is shared',
    (tester) async {
      final h = BackupUiHarness(tester);
      h.channel.system = SystemBackupState.off;
      final app = await AppUnderTest.pump(tester, overrides: h.overrides);
      await app.openSettings();
      await tapIo(tester, key('settings-backup'), until: key('backup-status'));

      final l10n = await AppLocalizations.delegate.load(const Locale('es'));
      final ios = defaultTargetPlatform == TargetPlatform.iOS;
      expect(
        textOf(tester, key('backup-warning')),
        ios ? l10n.backupUiWarningIos : l10n.backupUiWarning,
      );
      // B9: the export is the main button, with one line for every platform
      // («En tu nube, en otro dispositivo o por correo...»); the row that
      // named the drive is gone.
      expect(
        textOf(tester, key('backup-export-help')),
        l10n.backupUiSaveOutsideHelp,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS)
      ..values.add(TargetPlatform.android),
  );
}
