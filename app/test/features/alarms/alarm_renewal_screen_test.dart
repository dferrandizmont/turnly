import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/format/app_date_format.dart';
import 'package:cuadrante/features/alarms/application/alarm_providers.dart';
import 'package:cuadrante/features/alarms/data/alarm_scheduler.dart';
import 'package:cuadrante/features/alarms/domain/alarm_planner.dart';
import 'package:cuadrante/features/alarms/domain/alarm_strings.dart';
import 'package:cuadrante/l10n/app_localizations.dart';
import 'package:cuadrante/features/alarms/presentation/alarms_settings_screen.dart';
import 'package:cuadrante/features/schedule/domain/civil_date.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';

// A1 in Ajustes › Alarmas: «Avisos programados hasta el…», from what the sync
// really scheduled, and the renewal notice with the texts of the ARB.
// Demo data around Monday 19 Oct 2026, 12:00 (the harness clock).

Finder _key(String key) => find.byKey(ValueKey(key));

String _day(CivilDate d) =>
    const AppDateFormat('es').weekdayDayMonth(DateTime(d.year, d.month, d.day));

void main() {
  setUpAll(initializeLocale);

  const tall = Size(390, 1800);
  late FakeAlarmScheduler scheduler;

  setUp(() => scheduler = FakeAlarmScheduler());

  Future<void> openAlarms(WidgetTester tester) async {
    final app = await AppUnderTest.pump(
      tester,
      size: tall,
      overrides: [alarmSchedulerProvider.overrideWithValue(scheduler)],
    );
    await app.openSettings();
    await tester.ensureVisible(_key('settings-alarms'));
    await tester.tap(_key('settings-alarms'));
    await tester.pumpAndSettle();
    expect(find.byType(AlarmsSettingsScreen), findsOneWidget);
  }

  Future<void> tapAndSettle(WidgetTester tester, String key) async {
    await tester.ensureVisible(_key(key));
    await tester.pumpAndSettle();
    await tester.tap(_key(key));
    await tester.pumpAndSettle();
  }

  test('every language has the renewal texts, with the date in them', () {
    const day = CivilDate(2026, 11, 12);
    for (final locale in AppLocalizations.supportedLocales) {
      final strings = AlarmStrings.fromL10n(lookupAppLocalizations(locale));
      expect(strings.renewalTitle, isNotEmpty, reason: '$locale');
      final body = strings.renewalBody!(day);
      expect(
        body,
        contains(
          AppDateFormat(locale.languageCode)
              .weekdayDayMonth(DateTime(2026, 11, 12)),
        ),
        reason: '$locale',
      );
      expect(body, contains('Turnly'), reason: '$locale');
    }
  });

  testWidgets('off: no «hasta el…» line', (tester) async {
    await openAlarms(tester);
    expect(_key('alarms-scheduled-until'), findsNothing);
  });

  testWidgets('on: the line names the day of the last scheduled alarm, and '
      'the renewal notice the evening before speaks the app language', (
    tester,
  ) async {
    await openAlarms(tester);
    await tapAndSettle(tester, 'alarms-master-switch');
    await tapAndSettle(tester, 'alarms-type-switch-night');

    final shifts = scheduler.scheduled
        .where(
          (a) => a.kind == AlarmKind.shift || a.kind == AlarmKind.dayBefore,
        )
        .toList();
    expect(shifts, isNotEmpty);
    final last = shifts.last;
    expect(
      tester.widget<Text>(_key('alarms-scheduled-until')).data,
      'Avisos programados hasta el ${_day(last.fireDate)}',
    );

    final notice = scheduler.scheduled.singleWhere(
      (a) => a.kind == AlarmKind.renewal,
    );
    expect(notice.title, 'Avisos de turno');
    expect(
      notice.body,
      'Tus avisos de turno llegan hasta el ${_day(last.fireDate)}. '
      'Abre Turnly para programar los siguientes.',
    );
    expect(notice.fireDate, last.fireDate.addDays(-1));
    expect(scheduler.scheduled.last, notice, reason: 'after the alarms');
  });

  testWidgets('without the permission nothing is scheduled: no line', (
    tester,
  ) async {
    scheduler.permission = AlarmPermission.denied;
    scheduler.permissionAfterRequest = AlarmPermission.denied;
    await openAlarms(tester);
    await tapAndSettle(tester, 'alarms-master-switch');
    await tapAndSettle(tester, 'alarms-type-switch-night');
    expect(scheduler.scheduled, isEmpty);
    expect(_key('alarms-scheduled-until'), findsNothing);
  });
}
