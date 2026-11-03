import 'dart:convert';

import 'package:cuadrante/features/calendar_export/domain/ics_writer.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('escapeText', () {
    test('escapes backslash, semicolon, comma and new lines', () {
      expect(IcsWriter.escapeText(r'a\b;c,d'), r'a\\b\;c\,d');
      expect(
        IcsWriter.escapeText('one\ntwo\r\nthree\rfour'),
        r'one\ntwo\nthree\nfour',
      );
    });

    test('drops C1 controls and the Unicode line separators', () {
      expect(
        IcsWriter.escapeText('a\u0080b\u0085c\u009fd\u2028e\u2029f'),
        'abcdef',
      );
      // Just outside the C1 range stays.
      expect(IcsWriter.escapeText('\u00a0\u00e9'), '\u00a0\u00e9');
    });

    test('drops control characters but keeps tabs and accents', () {
      expect(IcsWriter.escapeText('a\u0000b\u0007c\u007f'), 'abc');
      expect(IcsWriter.escapeText('Mañana\t· M'), 'Mañana\t· M');
    });
  });

  group('foldLine', () {
    test('leaves short lines alone', () {
      expect(IcsWriter.foldLine('SUMMARY:Noche · N'), 'SUMMARY:Noche · N');
    });

    test('folds at 75 octets without splitting a character', () {
      final line = 'SUMMARY:${'ñ' * 100}';
      final folded = IcsWriter.foldLine(line);
      final parts = folded.split('\r\n');
      expect(parts.length, greaterThan(1));
      for (final (i, p) in parts.indexed) {
        expect(utf8.encode(p).length, lessThanOrEqualTo(75));
        if (i > 0) expect(p.startsWith(' '), isTrue);
      }
      // Unfolding gives the original line back.
      expect(folded.replaceAll('\r\n ', ''), line);
    });

    test('folds emoji-sized characters too', () {
      final line = 'X-NAME:${'\u{1F600}' * 40}';
      final folded = IcsWriter.foldLine(line);
      for (final p in folded.split('\r\n')) {
        expect(utf8.encode(p).length, lessThanOrEqualTo(75));
      }
      expect(folded.replaceAll('\r\n ', ''), line);
    });
  });

  group('formats', () {
    test('UTC instants, dates and durations', () {
      expect(
        IcsWriter.formatUtc(DateTime.utc(2026, 10, 31, 5, 7, 9)),
        '20261031T050709Z',
      );
      expect(IcsWriter.formatDate(const CivilDate(2027, 1, 2)), '20270102');
      expect(IcsWriter.formatDuration(const Duration(hours: 6)), 'PT6H');
      expect(IcsWriter.formatDuration(const Duration(days: 2)), 'P2D');
      expect(
        IcsWriter.formatDuration(const Duration(hours: 1, minutes: 30)),
        'PT1H30M',
      );
      expect(IcsWriter.formatDuration(Duration.zero), 'PT0M');
    });
  });

  group('write', () {
    final stamp = DateTime.utc(2026, 10, 31, 12);
    final doc = const IcsWriter().write(
      stamp: stamp,
      calendarName: 'Mi cuadrante, casa',
      refreshInterval: const Duration(hours: 6),
      events: [
        IcsEvent.timed(
          uid: 'a@turnly',
          summary: 'Noche · N',
          start: DateTime.utc(2026, 10, 31, 21),
          end: DateTime.utc(2026, 11, 1, 5),
        ),
        IcsEvent.allDay(
          uid: 'b@turnly',
          summary: 'Libre · L',
          date: const CivilDate(2026, 12, 31),
        ),
      ],
    );

    test('is one VCALENDAR with CRLF line ends', () {
      expect(doc.startsWith('BEGIN:VCALENDAR\r\nVERSION:2.0\r\n'), isTrue);
      expect(doc.endsWith('END:VCALENDAR\r\n'), isTrue);
      expect(doc.replaceAll('\r\n', '').contains('\n'), isFalse);
      expect('BEGIN:VEVENT'.allMatches(doc).length, 2);
      expect('END:VEVENT'.allMatches(doc).length, 2);
    });

    test('has the calendar headers', () {
      expect(doc, contains('PRODID:-//Turnly//Turnly//ES\r\n'));
      expect(doc, contains(r'X-WR-CALNAME:Mi cuadrante\, casa'));
      expect(doc, contains('REFRESH-INTERVAL;VALUE=DURATION:PT6H\r\n'));
      expect(doc, contains('X-PUBLISHED-TTL:PT6H\r\n'));
    });

    test('timed events in UTC, all-day with an exclusive end', () {
      expect(doc, contains('DTSTART:20261031T210000Z\r\n'));
      expect(doc, contains('DTEND:20261101T050000Z\r\n'));
      expect(doc, contains('DTSTART;VALUE=DATE:20261231\r\n'));
      expect(doc, contains('DTEND;VALUE=DATE:20270101\r\n'));
      expect('DTSTAMP:20261031T120000Z'.allMatches(doc).length, 2);
      expect(doc, contains('TRANSP:OPAQUE'));
      expect(doc, contains('TRANSP:TRANSPARENT'));
    });

    test('a local DateTime is written as its UTC instant', () {
      final local = DateTime(2026, 7, 1, 8);
      final text = const IcsWriter().write(
        stamp: stamp,
        events: [
          IcsEvent.timed(uid: 'x', summary: 's', start: local, end: local),
        ],
      );
      expect(text, contains('DTSTART:${IcsWriter.formatUtc(local.toUtc())}'));
    });

    test('a blank calendar name is left out', () {
      final text = const IcsWriter().write(
        stamp: stamp,
        calendarName: '  ',
        events: const [],
      );
      expect(text, isNot(contains('X-WR-CALNAME')));
      expect(text, isNot(contains('REFRESH-INTERVAL')));
    });
  });
}
