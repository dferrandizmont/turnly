import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers.dart';
import '../../backup/application/backup_providers.dart' show exportCacheProvider;
import '../../calendar/application/schedule_controller.dart';
import '../../calendars/application/calendars_controller.dart';
import '../../holidays/application/holidays_provider.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../../settings/application/preferences_controller.dart';
import '../../summary/domain/summary_range.dart';
import '../data/csv_writer.dart';
import '../data/pdf_renderer.dart';
import '../data/report_fonts.dart';
import '../domain/report_model.dart';
import '../domain/report_options.dart';
import '../domain/report_strings.dart';
import '../../../core/platform/share_origin.dart';

/// The two files a report can be.
enum ReportFormat { pdf, csv }

/// Hands a finished file to the system share sheet. Tests override it.
typedef ReportSender = Future<void> Function(
  Uint8List bytes,
  String fileName,
  String mimeType,
  String subject,
);

/// The fonts embedded in the PDF. Tests override it (the asset bundle of a
/// widget test is not the one of the app).
final reportFontsProvider = FutureProvider<ReportFonts>(
  (ref) => loadReportFonts(),
);

/// Writes the file to the export cache folder, opens the share sheet and
/// deletes the file once it has returned (a report holds the schedule, with
/// the absences the user chose to show, so it must not stay in the cache:
/// `ExportCache`).
final reportSenderProvider = Provider<ReportSender>(
  (ref) => (bytes, fileName, mimeType, subject) async {
    final cache = await ref.read(exportCacheProvider.future);
    await cache.share(
      bytes,
      fileName,
      (file) => SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: mimeType)],
          subject: subject,
          sharePositionOrigin: shareOrigin(),
        ),
      ),
    );
  },
);

/// Name of the active calendar, empty while it is not known.
final reportCalendarNameProvider = Provider<String>((ref) {
  final activeId = ref.watch(
    scheduleControllerProvider.select((s) => s.calendarId),
  );
  final calendars = ref.watch(calendarsControllerProvider).value?.calendars;
  if (calendars == null) return '';
  for (final calendar in calendars) {
    if (calendar.id == activeId) return calendar.name;
  }
  return '';
});

/// The report of [range] for the ACTIVE calendar, with the holidays of the
/// chosen place, the week start of the preferences and today from the app's
/// clock.
ReportModel buildActiveReport(
  Ref ref,
  SummaryRange range,
  ReportOptions options,
) {
  final weekStart = ref.read(preferencesProvider).weekStart;
  return buildReport(
    schedule: ref.read(scheduleControllerProvider).schedule,
    range: range,
    calendarName: ref.read(reportCalendarNameProvider),
    holidays: ref.read(holidaysProvider),
    today: CivilDate.fromDateTime(ref.read(clockProvider)()),
    options: options.copyWith(weekStart: weekStart),
  );
}

/// "turnly-2026-10.pdf" for a whole month, "turnly-2026-10-05_2026-10-19.csv"
/// for any other period. Only letters, digits and dashes: it is a file name.
String reportFileName(SummaryRange range, ReportFormat format) {
  final from = range.from;
  final to = range.to;
  final wholeMonth =
      from.day == 1 &&
      to == to.lastDayOfMonth &&
      from.year == to.year &&
      from.month == to.month;
  final base = wholeMonth
      ? 'turnly-${from.year}-${from.month.toString().padLeft(2, '0')}'
      : 'turnly-${from.toIso()}_${to.toIso()}';
  return '$base.${format == ReportFormat.pdf ? 'pdf' : 'csv'}';
}

/// What `ReportExporter.export` did.
enum ReportOutcome { shared, failed }

/// Builds the report of the active calendar, renders it and opens the share
/// sheet. The state is true while it works, so a second tap does nothing.
class ReportExporter extends Notifier<bool> {
  @override
  bool build() => false;

  Future<ReportOutcome> export({
    required ReportFormat format,
    required SummaryRange range,
    required ReportOptions options,
    required ReportStrings strings,
    required String subject,
  }) async {
    if (state) return ReportOutcome.shared;
    state = true;
    try {
      final model = buildActiveReport(ref, range, options);
      final Uint8List bytes;
      switch (format) {
        case ReportFormat.pdf:
          final fonts = await ref.read(reportFontsProvider.future);
          bytes = await renderReportPdf(model, strings, fonts);
        case ReportFormat.csv:
          bytes = writeReportCsv(model, strings);
      }
      await ref.read(reportSenderProvider)(
        bytes,
        reportFileName(range, format),
        format == ReportFormat.pdf ? 'application/pdf' : 'text/csv',
        subject,
      );
      return ReportOutcome.shared;
    } catch (_) {
      return ReportOutcome.failed;
    } finally {
      if (ref.mounted) state = false;
    }
  }
}

final reportExporterProvider = NotifierProvider<ReportExporter, bool>(
  ReportExporter.new,
);
