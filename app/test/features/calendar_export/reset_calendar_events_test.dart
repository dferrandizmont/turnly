import 'package:cuadrante/features/calendar_export/data/reset_calendar_events.dart';
import 'package:cuadrante/features/calendar_export/domain/export_events.dart';
import 'package:cuadrante/features/schedule/domain/civil_date.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.cuadrante/reset_calendar');
  const cleaner = ResetCalendarEvents();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('only complete current and legacy export tags are deleted', () async {
    final deleted = <Object?>[];
    final tag = exportTag(
      'old-calendar',
      const CivilDate(2001, 1, 1),
      'night',
      0,
    );
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'list') {
        return [
          {'id': '1', 'description': '$exportMarkerLine\n$tag'},
          {'id': '2', 'description': '${legacyExportMarkerLines.single}\n$tag'},
          {'id': '3', 'description': tag},
          {'id': '4', 'description': '$exportMarkerLine\ninvalid'},
          {'id': '5', 'description': 'Personal note\n$tag'},
        ];
      }
      expect(call.method, 'delete');
      deleted.add(call.arguments);
      return null;
    });
    await cleaner.deleteAppEvents();
    expect(deleted, [
      {'id': '1', 'description': '$exportMarkerLine\n$tag'},
      {'id': '2', 'description': '${legacyExportMarkerLines.single}\n$tag'},
    ]);
  });

  test('missing channel (Mac pending) is inert', () async {
    await cleaner.deleteAppEvents();
  });

  test(
    'listing failures reach the reset warning, including revoked permission',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: 'permissionDenied'),
      );
      await expectLater(
        cleaner.deleteAppEvents(),
        throwsA(isA<PlatformException>()),
      );
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: 'calendarFailed'),
      );
      await expectLater(
        cleaner.deleteAppEvents(),
        throwsA(isA<PlatformException>()),
      );
    },
  );
  test(
    'no permission and «Mantener al día» never used: nothing to warn',
    () async {
      // Found on a OnePlus 10 Pro: a phone that never synced to its calendar
      // was told some events could not be removed.
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: 'permissionDenied'),
      );
      await ResetCalendarEvents(
        channel: channel,
        calendarWasUsed: false,
      ).deleteAppEvents();
      // Any other failure still warns, used or not.
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: 'calendarFailed'),
      );
      await expectLater(
        ResetCalendarEvents(
          channel: channel,
          calendarWasUsed: false,
        ).deleteAppEvents(),
        throwsA(isA<PlatformException>()),
      );
    },
  );

  test(
    'one undeletable event is reported and does not stop the next',
    () async {
      final attempts = <String>[];
      final reports = <Object>[];
      final tag = exportTag('old', const CivilDate(2001, 1, 1), 'night', 0);
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'list') {
          return [
            for (final id in ['1', '2', '3'])
              {'id': id, 'description': '$exportMarkerLine\n$tag'},
          ];
        }
        final id = (call.arguments as Map)['id'] as String;
        attempts.add(id);
        if (id == '2') {
          throw PlatformException(code: 'calendarFailed');
        }
        return null;
      });
      await expectLater(
        ResetCalendarEvents(onError: (e, _) => reports.add(e))
            .deleteAppEvents(),
        throwsA(isA<ResetCalendarCleanupFailure>()),
      );
      expect(attempts, ['1', '2', '3']);
      expect(reports, hasLength(1));
    },
  );
}
