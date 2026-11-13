import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/buttons.dart';
import '../../import/presentation/import_format.dart';
import '../../import/presentation/import_icons.dart';
import '../application/export_controller.dart';
import '../application/ics_export.dart';
import '../../../core/platform/share_origin.dart';

/// «Guardar como archivo .ics» on the export screen: the same dates and
/// switches as the export to the phone calendar, written to a file the
/// person sends or saves wherever they want. Needs no calendar permission,
/// so it shows whatever the permission says.
class IcsFileExportCard extends ConsumerWidget {
  const IcsFileExportCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    final export = ref.watch(exportControllerProvider);
    final status = ref.watch(icsFileControllerProvider);
    final running = status == IcsFileStatus.running;
    return Padding(
      padding: const EdgeInsets.only(top: Sp.section),
      child: AppCard(
        key: const ValueKey('ics-file-card'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(l10n.calExportIcsTitle, style: type.bodyStrong),
            ),
            const SizedBox(height: Sp.xs),
            Text(
              l10n.calExportIcsHelp,
              style: type.body.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: Sp.s),
            Text(
              l10n.calExportIcsRange(
                importDateText(context, export.from),
                importDateText(context, export.to),
              ),
              key: const ValueKey('ics-file-range'),
              style: type.meta.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: Sp.l),
            Builder(
              builder: (buttonContext) => SecondaryButton(
              key: const ValueKey('ics-file-button'),
              icon: ImportIcons.icsFile,
              label: running
                  ? l10n.calExportIcsRunning
                  : l10n.calExportIcsButton,
              onPressed: running || export.running
                  ? null
                  : () {
                      rememberShareOrigin(buttonContext);
                      ref
                          .read(icsFileControllerProvider.notifier)
                          .export(
                            IcsFileRequest(
                              from: export.from,
                              to: export.to,
                              includeRest: export.includeRest,
                              includeAbsences: export.includeAbsences,
                            ),
                          );
                    },
            ),
            ),
            if (status == IcsFileStatus.failed) ...[
              const SizedBox(height: Sp.s),
              Semantics(
                liveRegion: true,
                child: Text(
                  l10n.calExportIcsFailed,
                  key: const ValueKey('ics-file-failed'),
                  style: type.meta.copyWith(color: colors.danger),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
