import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/format/app_date_format.dart';
import '../../../../core/icons/settings_icons.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/providers.dart';
import '../../../../core/router.dart';
import '../../../backup/application/backup_models.dart';
import '../../../backup/application/backup_providers.dart';
import '../../../backup/presentation/backup_format.dart';
import '../settings_widgets.dart';

/// «Copias y cambio de móvil» (design 6A): the backup, with how safe the
/// schedule is at the right. Moving to another phone is done from the same
/// screen (export a file, import it on the new phone).
class BackupSection extends StatelessWidget {
  const BackupSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: context.l10n.settingsSectionBackup,
      children: const [BackupSettingsRow()],
    );
  }
}

/// The «Copia de seguridad» row: «Última: ayer a las 22:14, comprobada»
/// (every copy of the app is read back whole when it is written, so the
/// newest one on the phone is a checked one), «Todavía no hay ninguna
/// copia», the failure of the last automatic copy, or while the copies are
/// still being read, what the screen holds.
class BackupSettingsRow extends ConsumerWidget {
  const BackupSettingsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final status = ref.watch(autoBackupStatusProvider);
    final copies = ref.watch(backupCopiesProvider).value;
    final latest = copies
        ?.where((c) => c.kind == BackupCopyKind.local)
        .firstOrNull;
    final now = ref.watch(clockProvider)();
    final String subtitle;
    if (status.failing) {
      subtitle = l10n.backupUiStatusFailedTitle;
    } else if (copies == null) {
      subtitle = l10n.backupUiRowSubtitle;
    } else if (latest == null) {
      subtitle = l10n.backupUiStatusNoneTitle;
    } else {
      subtitle = l10n.settingsBackupLast(
        backupWhen(
          l10n,
          latest.entry.modifiedAt,
          now,
          hour12: AppDateFormat.of(context).hour12,
        ),
      );
    }
    return SettingsRow(
      key: const ValueKey('settings-backup'),
      icon: SettingsIcons.backup,
      title: l10n.settingsBackupTitle,
      subtitle: subtitle,
      onTap: () => context.push(AppRoutes.settingsBackup),
    );
  }
}
