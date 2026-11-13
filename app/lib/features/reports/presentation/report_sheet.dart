import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/app_date_format.dart';
import '../../../core/format/app_formats.dart';
import '../../../core/icons/app_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/choice_grid.dart';
import '../../../core/widgets/choice_pill.dart';
import '../../../core/widgets/choice_row.dart';
import '../../calendar/application/schedule_controller.dart';
import '../../calendar/presentation/shift_format.dart' show capitalize;
import '../../schedule/domain/schedule_domain.dart';
import '../../summary/domain/summary_range.dart';
import '../../summary/presentation/summary_format.dart';
import '../application/report_providers.dart';
import '../domain/report_options.dart';
import 'report_icons.dart';
import 'report_strings_l10n.dart';
import '../../../core/platform/share_origin.dart';

/// Opens the report sheet: choose the period (a month or any dates), the
/// format (PDF or CSV) and what goes in, then create and share the file.
/// [month] is any day of the month it starts on.
Future<void> showReportSheet(
  BuildContext context, {
  required CivilDate month,
}) => showAppSheet<void>(
  context: context,
  padded: true,
  builder: (_) => ReportSheet(month: month),
);

enum _Period { month, range }

class ReportSheet extends ConsumerStatefulWidget {
  const ReportSheet({super.key, required this.month});

  final CivilDate month;

  @override
  ConsumerState<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<ReportSheet> {
  ReportFormat _format = ReportFormat.pdf;
  _Period _period = _Period.month;
  late CivilDate _month = widget.month.firstDayOfMonth;
  late SummaryRange _range = SummaryRange.month(widget.month);
  bool _clamped = false;
  ReportOptions _options = const ReportOptions();

  SummaryRange get _effectiveRange =>
      _period == _Period.month ? SummaryRange.month(_month) : _range;

  DateTime _dateTime(CivilDate d) => DateTime(d.year, d.month, d.day);

  void _stepMonth(int delta) {
    var m = _month;
    for (var i = 0; i < delta.abs(); i++) {
      m = delta > 0 ? m.addDays(m.daysInMonth) : m.addDays(-1).firstDayOfMonth;
    }
    setState(() => _month = m);
  }

  Future<void> _pickDate({required bool start}) async {
    final l10n = context.l10n;
    final current = start ? _range.from : _range.to;
    final limit = _range.from.addDays(maxSummaryRangeDays - 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateTime(current),
      firstDate: start ? DateTime(2000) : _dateTime(_range.from),
      lastDate: start ? DateTime(2100) : _dateTime(limit),
      helpText: start ? l10n.summaryRangeFrom : l10n.summaryRangeTo,
    );
    if (picked == null || !mounted) return;
    final day = CivilDate.fromDateTime(picked);
    final result = start ? _range.withFrom(day) : _range.withTo(day);
    setState(() {
      _range = result.range;
      _clamped = result.clamped;
    });
  }

  Future<void> _create() async {
    final l10n = context.l10n;
    final format = AppDateFormat.of(context);
    final currency = currencyOf(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final range = _effectiveRange;
    final period = _period == _Period.month
        ? capitalize(format.monthYear(DateTime(_month.year, _month.month)))
        : formatRange(format.locale, range.from, range.to);
    // The extra money of the days (P9) gets its column and its line only
    // when the period has some, so a report without it stays as it was.
    final hasExtras = ref
        .read(scheduleControllerProvider)
        .schedule
        .entries
        .values
        .any(
          (e) =>
              (e.extraAmountCents ?? 0) != 0 &&
              !e.date.isBefore(range.from) &&
              !e.date.isAfter(range.to),
        );
    final strings = reportStringsFor(
      l10n,
      localeName: format.locale,
      currency: currency,
      hour12: format.hour12,
      colExtra: hasExtras ? l10n.moneyReportExtraColumn : null,
      extrasAmount: hasExtras ? l10n.moneyReportExtraTotal : null,
    );
    final outcome = await ref
        .read(reportExporterProvider.notifier)
        .export(
          format: _format,
          range: range,
          options: _options,
          strings: strings,
          subject: l10n.reportSubject(period),
        );
    if (!mounted) return;
    if (outcome == ReportOutcome.failed) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(appSnackBar(content: Text(l10n.reportFailed)));
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.type;
    final colors = context.colors;
    final format = AppDateFormat.of(context);
    final busy = ref.watch(reportExporterProvider);

    final monthLabel = capitalize(
      format.monthYear(DateTime(_month.year, _month.month)),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.reportSheetTitle, style: type.headline),
        ),
        const SizedBox(height: Sp.xs),
        Text(
          l10n.reportSheetIntro,
          style: type.meta.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: Sp.l),
        ChoiceGrid.pills(
          maxColumns: 2,
          pills: [
            ChoicePill(
              expand: true,
              reserveIcon: true,
              key: const ValueKey('report-format-pdf'),
              label: l10n.reportFormatPdf,
              icon: ReportIcons.report,
              selected: _format == ReportFormat.pdf,
              onTap: () => setState(() => _format = ReportFormat.pdf),
            ),
            ChoicePill(
              expand: true,
              reserveIcon: true,
              key: const ValueKey('report-format-csv'),
              label: l10n.reportFormatCsv,
              icon: ReportIcons.report,
              selected: _format == ReportFormat.csv,
              onTap: () => setState(() => _format = ReportFormat.csv),
            ),
          ],
        ),
        const SizedBox(height: Sp.l),
        ChoiceGrid.pills(
          sizing: ChoiceGridSizing.wholeLabel,
          maxColumns: 2,
          pills: [
            ChoicePill(
              expand: true,
              reserveIcon: true,
              key: const ValueKey('report-period-month'),
              label: l10n.summaryModeMonth,
              selected: _period == _Period.month,
              onTap: () => setState(() => _period = _Period.month),
            ),
            ChoicePill(
              expand: true,
              reserveIcon: true,
              key: const ValueKey('report-period-range'),
              label: l10n.summaryModeRange,
              selected: _period == _Period.range,
              onTap: () => setState(() => _period = _Period.range),
            ),
          ],
        ),
        const SizedBox(height: Sp.s),
        if (_period == _Period.month)
          Row(
            children: [
              IconButton(
                key: const ValueKey('report-previous'),
                tooltip: l10n.calendarPreviousMonth,
                icon: Icon(AppIcons.chevronLeft),
                onPressed: () => _stepMonth(-1),
              ),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      monthLabel,
                      key: const ValueKey('report-month'),
                      style: AppTypography.tabular(type.title),
                    ),
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('report-next'),
                tooltip: l10n.calendarNextMonth,
                icon: Icon(AppIcons.chevronRight),
                onPressed: () => _stepMonth(1),
              ),
            ],
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  key: const ValueKey('report-from'),
                  label:
                      '${l10n.summaryRangeFrom}: '
                      '${formatRangeDate(format.locale, _range.from)}',
                  onPressed: () => _pickDate(start: true),
                ),
              ),
              const SizedBox(width: Sp.s),
              Expanded(
                child: SecondaryButton(
                  key: const ValueKey('report-to'),
                  label:
                      '${l10n.summaryRangeTo}: '
                      '${formatRangeDate(format.locale, _range.to)}',
                  onPressed: () => _pickDate(start: false),
                ),
              ),
            ],
          ),
          if (_clamped) ...[
            const SizedBox(height: Sp.xs),
            Text(
              l10n.summaryRangeClamped(maxSummaryRangeDays),
              style: type.meta.copyWith(color: colors.textMuted),
            ),
          ],
        ],
        const SizedBox(height: Sp.l),
        Semantics(
          header: true,
          child: Text(l10n.reportIncludeTitle, style: type.bodyStrong),
        ),
        SwitchListTile(
          key: const ValueKey('report-notes'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.reportIncludeNotes),
          value: _options.includeNotes,
          onChanged: (on) =>
              setState(() => _options = _options.copyWith(includeNotes: on)),
        ),
        if (_format == ReportFormat.pdf)
          SwitchListTile(
            key: const ValueKey('report-earnings'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.reportIncludeEarnings),
            value: _options.includeEarnings,
            onChanged: (on) => setState(
              () => _options = _options.copyWith(includeEarnings: on),
            ),
          ),
        const SizedBox(height: Sp.xs),
        Semantics(
          header: true,
          child: Text(l10n.reportAbsencesTitle, style: type.bodyStrong),
        ),
        for (final (mode, label) in [
          (ReportAbsenceMode.hidden, l10n.reportAbsencesHidden),
          (ReportAbsenceMode.generic, l10n.reportAbsencesGeneric),
          (ReportAbsenceMode.detailed, l10n.reportAbsencesDetailed),
        ])
          ChoiceRow(
            key: ValueKey('report-absences-${mode.name}'),
            label: label,
            selected: _options.absences == mode,
            onTap: () =>
                setState(() => _options = _options.copyWith(absences: mode)),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.xs),
          child: Text(
            l10n.reportAbsencesHint,
            style: type.meta.copyWith(color: colors.textMuted),
          ),
        ),
        const SizedBox(height: Sp.xl),
        Builder(
          builder: (buttonContext) => PrimaryButton(
            key: const ValueKey('report-create'),
            label: l10n.reportCreate,
            icon: AppIcons.share,
            loading: busy,
            onPressed: () {
              rememberShareOrigin(buttonContext);
              _create();
            },
          ),
        ),
      ],
    );
  }
}
