import 'dart:async';
import 'dart:typed_data';

import 'package:cuadrante/core/icons/app_icons.dart';
import 'package:cuadrante/core/l10n/l10n.dart';
import 'package:cuadrante/core/theme/app_theme.dart';
import 'package:cuadrante/features/calendar/presentation/month_screen.dart';
import 'package:cuadrante/features/reports/presentation/report_share_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cuadrante/features/reports/application/report_providers.dart';
import 'package:cuadrante/features/reports/data/report_fonts.dart';
import 'package:cuadrante/features/reports/presentation/report_sheet.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/summary/domain/summary_range.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../calendar/harness.dart';

class _Sent {
  _Sent(this.bytes, this.name, this.mime, this.subject);
  final Uint8List bytes;
  final String name;
  final String mime;
  final String subject;
}

Finder _key(String key) => find.byKey(ValueKey(key));

Future<List<_Sent>> _openSheet(
  WidgetTester tester, {
  bool failSending = false,
}) async {
  final sent = <_Sent>[];
  await pumpCalendar(
    tester,
    overrides: [
      reportFontsProvider.overrideWith((ref) => ReportFonts.standard()),
      reportSenderProvider.overrideWithValue((bytes, name, mime, subject) async {
        if (failSending) throw StateError('no share sheet');
        sent.add(_Sent(bytes, name, mime, subject));
      }),
    ],
  );
  unawaited(
    showReportSheet(
      tester.element(find.byType(MonthScreen)),
      month: fixedToday,
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byType(ReportSheet), findsOneWidget);
  return sent;
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(_key(key));
  await tester.pumpAndSettle();
  await tester.tap(_key(key));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the button opens the sheet', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: Center(child: ReportShareButton(month: fixedToday)),
          ),
        ),
      ),
    );
    expect(find.byTooltip('Informe en PDF o CSV'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('report-share')));
    await tester.pumpAndSettle();
    expect(find.byType(ReportSheet), findsOneWidget);
    expect(tester.widget<Text>(_key('report-month')).data, 'Octubre 2026');
  });

  testWidgets('opens on the visible month with PDF and the private defaults', (
    tester,
  ) async {
    await _openSheet(tester);
    expect(find.text('Informe de turnos'), findsOneWidget);
    expect(tester.widget<Text>(_key('report-month')).data, 'Octubre 2026');
    // Notes and earnings off; absences as a plain «Ausencia».
    expect(tester.widget<SwitchListTile>(_key('report-notes')).value, isFalse);
    expect(
      tester.widget<SwitchListTile>(_key('report-earnings')).value,
      isFalse,
    );
    expect(
      find.descendant(
        of: _key('report-absences-generic'),
        matching: find.byIcon(AppIcons.check),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _key('report-absences-detailed'),
        matching: find.byIcon(AppIcons.check),
      ),
      findsNothing,
    );
    expect(
      find.textContaining('Una baja médica no sale con su nombre'),
      findsOneWidget,
    );
  });

  testWidgets('creates the PDF of the month and shares it', (tester) async {
    final sent = await _openSheet(tester);
    await _tap(tester, 'report-create');
    expect(sent, hasLength(1));
    final file = sent.single;
    expect(file.name, 'turnly-2026-10.pdf');
    expect(file.mime, 'application/pdf');
    expect(file.subject, 'Turnos: Octubre 2026');
    expect(String.fromCharCodes(file.bytes.take(5)), '%PDF-');
    // The sheet closes once the file is on its way.
    expect(find.byType(ReportSheet), findsNothing);
  });

  testWidgets('the CSV of the previous month', (tester) async {
    final sent = await _openSheet(tester);
    await _tap(tester, 'report-format-csv');
    await _tap(tester, 'report-previous');
    expect(tester.widget<Text>(_key('report-month')).data, 'Septiembre 2026');
    // Earnings only make sense in the PDF.
    expect(_key('report-earnings'), findsNothing);
    await _tap(tester, 'report-create');
    final file = sent.single;
    expect(file.name, 'turnly-2026-09.csv');
    expect(file.mime, 'text/csv');
    expect(file.bytes.take(3), [0xEF, 0xBB, 0xBF]);
  });

  testWidgets('the options reach the report', (tester) async {
    final sent = await _openSheet(tester);
    await _tap(tester, 'report-notes');
    await _tap(tester, 'report-absences-hidden');
    expect(tester.widget<SwitchListTile>(_key('report-notes')).value, isTrue);
    await _tap(tester, 'report-format-csv');
    await _tap(tester, 'report-create');
    final header = String.fromCharCodes(sent.single.bytes.skip(3).take(80));
    expect(header, contains('Nota'));
  });

  testWidgets('a range of dates is named after the dates', (tester) async {
    final sent = await _openSheet(tester);
    await _tap(tester, 'report-period-range');
    expect(_key('report-from'), findsOneWidget);
    expect(_key('report-to'), findsOneWidget);
    expect(_key('report-month'), findsNothing);
    // The system calendar: from the 5th (the last day stays the 31st).
    await _tap(tester, 'report-from');
    await tester.tap(find.text('5').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aceptar'));
    await tester.pumpAndSettle();
    await _tap(tester, 'report-create');
    expect(sent.single.name, 'turnly-2026-10-05_2026-10-31.pdf');
    expect(sent.single.subject, startsWith('Turnos: '));
  });

  testWidgets('says so when the report cannot be shared and stays open', (
    tester,
  ) async {
    await _openSheet(tester, failSending: true);
    await _tap(tester, 'report-create');
    expect(find.text('No se ha podido crear el informe'), findsOneWidget);
    expect(find.byType(ReportSheet), findsOneWidget);
  });

  test('file names', () {
    const month = SummaryRange(CivilDate(2026, 2, 1), CivilDate(2026, 2, 28));
    expect(reportFileName(month, ReportFormat.pdf), 'turnly-2026-02.pdf');
    const free = SummaryRange(CivilDate(2026, 2, 3), CivilDate(2026, 3, 9));
    expect(
      reportFileName(free, ReportFormat.csv),
      'turnly-2026-02-03_2026-03-09.csv',
    );
    // Almost a month is not a month.
    const nearly = SummaryRange(CivilDate(2026, 2, 1), CivilDate(2026, 2, 27));
    expect(
      reportFileName(nearly, ReportFormat.pdf),
      'turnly-2026-02-01_2026-02-27.pdf',
    );
  });
}
