import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../schedule/domain/schedule_domain.dart';
import 'report_icons.dart';
import 'report_sheet.dart';

/// The button that opens the report sheet (PDF or CSV of a month or a period).
/// One line wherever it goes: `ReportShareButton(month: month)`. [month] is
/// any day of the month the sheet starts on.
class ReportShareButton extends StatelessWidget {
  const ReportShareButton({super.key, required this.month, this.color});

  final CivilDate month;

  /// Colour of the icon; the muted text colour of the app bars by default.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('report-share'),
      tooltip: context.l10n.reportShareTooltip,
      icon: Icon(ReportIcons.report, color: color ?? context.colors.textMuted),
      onPressed: () => showReportSheet(context, month: month),
    );
  }
}
