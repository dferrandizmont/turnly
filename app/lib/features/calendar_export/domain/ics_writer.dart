import 'dart:convert';

import '../../schedule/domain/civil_date.dart';

/// One event of an iCalendar file (RFC 5545), already decided: what it is
/// called, when it is and how it is identified. [IcsWriter] only formats.
///
/// A timed event carries **instants** ([start] and [end] in UTC); an all-day
/// event carries **dates** ([startDate] and the exclusive [endDate]). See
/// `docs/compartir.md`, «Zona horaria», for why times go out in UTC.
class IcsEvent {
  /// A timed event from [start] to [end] (converted to UTC when written).
  IcsEvent.timed({
    required this.uid,
    required this.summary,
    required DateTime start,
    required DateTime end,
    this.description,
    this.categories = const [],
    this.transparent = false,
  }) : start = start.toUtc(),
       end = end.toUtc(),
       startDate = null,
       endDate = null,
       assert(!end.isBefore(start));

  /// An all-day event on [date] (or from [date] to [last], both included).
  IcsEvent.allDay({
    required this.uid,
    required this.summary,
    required CivilDate date,
    CivilDate? last,
    this.description,
    this.categories = const [],
    this.transparent = true,
  }) : start = null,
       end = null,
       startDate = date,
       endDate = (last ?? date).addDays(1);

  /// Stable across exports and publications, so a calendar that subscribes
  /// to the feed (or imports the file twice) updates instead of duplicating.
  final String uid;
  final String summary;
  final String? description;
  final List<String> categories;

  /// `TRANSP:TRANSPARENT`: the event does not make the person look busy.
  final bool transparent;

  final DateTime? start;
  final DateTime? end;
  final CivilDate? startDate;

  /// Exclusive, as RFC 5545 wants for `DTEND;VALUE=DATE`.
  final CivilDate? endDate;

  bool get allDay => startDate != null;
}

/// Formats [IcsEvent]s as an iCalendar (`text/calendar`) document.
///
/// What it guarantees, and the tests check:
/// - CRLF line ends and lines folded at 75 octets of UTF-8 without cutting a
///   character in two (RFC 5545 §3.1);
/// - TEXT values escaped (`\\`, `;`, `,`, new lines) (§3.3.11);
/// - timed events in UTC (`DTSTART:20261031T050000Z`), so no `VTIMEZONE`
///   is needed and every client places them at the right instant, also on
///   the days the clocks change;
/// - all-day events as `VALUE=DATE` with an exclusive end;
/// - a `DTSTAMP` on every event (required by §3.6.1).
class IcsWriter {
  const IcsWriter({this.productId = '-//Turnly//Turnly//ES'});

  /// `PRODID` of the calendar.
  final String productId;

  /// The whole document.
  ///
  /// [calendarName] becomes `X-WR-CALNAME` (the name clients show for a
  /// subscribed calendar). [refreshInterval], when given, adds
  /// `REFRESH-INTERVAL` (RFC 7986) and `X-PUBLISHED-TTL` so subscribers ask
  /// for updates that often. [stamp] is the `DTSTAMP` of every event.
  String write({
    required Iterable<IcsEvent> events,
    required DateTime stamp,
    String? calendarName,
    Duration? refreshInterval,
  }) {
    final out = StringBuffer();
    void line(String text) => out.write('${foldLine(text)}\r\n');

    line('BEGIN:VCALENDAR');
    line('VERSION:2.0');
    line('PRODID:${escapeText(productId)}');
    line('CALSCALE:GREGORIAN');
    if (calendarName != null && calendarName.trim().isNotEmpty) {
      line('X-WR-CALNAME:${escapeText(calendarName.trim())}');
    }
    if (refreshInterval != null) {
      final d = formatDuration(refreshInterval);
      line('REFRESH-INTERVAL;VALUE=DURATION:$d');
      line('X-PUBLISHED-TTL:$d');
    }
    final dtStamp = formatUtc(stamp);
    for (final e in events) {
      line('BEGIN:VEVENT');
      line('UID:${escapeText(e.uid)}');
      line('DTSTAMP:$dtStamp');
      if (e.allDay) {
        line('DTSTART;VALUE=DATE:${formatDate(e.startDate!)}');
        line('DTEND;VALUE=DATE:${formatDate(e.endDate!)}');
      } else {
        line('DTSTART:${formatUtc(e.start!)}');
        line('DTEND:${formatUtc(e.end!)}');
      }
      line('SUMMARY:${escapeText(e.summary)}');
      if (e.description != null && e.description!.isNotEmpty) {
        line('DESCRIPTION:${escapeText(e.description!)}');
      }
      if (e.categories.isNotEmpty) {
        line('CATEGORIES:${e.categories.map(escapeText).join(',')}');
      }
      line('TRANSP:${e.transparent ? 'TRANSPARENT' : 'OPAQUE'}');
      line('END:VEVENT');
    }
    line('END:VCALENDAR');
    return out.toString();
  }

  /// RFC 5545 §3.3.11: backslash, semicolon, comma and new lines. Other
  /// control characters are dropped (they are not allowed in a TEXT value):
  /// C0 but the tab, DEL, C1 (U+0080-U+009F) and the line and paragraph
  /// separators U+2028/U+2029, which some clients read as line breaks.
  static String escapeText(String text) {
    final out = StringBuffer();
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    for (final rune in normalized.runes) {
      switch (rune) {
        case 0x5C: // \
          out.write(r'\\');
        case 0x3B: // ;
          out.write(r'\;');
        case 0x2C: // ,
          out.write(r'\,');
        case 0x0A: // new line
          out.write(r'\n');
        default:
          if (rune < 0x20 && rune != 0x09 ||
              (rune >= 0x7F && rune <= 0x9F) ||
              rune == 0x2028 ||
              rune == 0x2029) {
            continue;
          }
          out.writeCharCode(rune);
      }
    }
    return out.toString();
  }

  /// RFC 5545 §3.1: lines longer than 75 octets go on in a new line that
  /// starts with a space. Never cuts inside a UTF-8 character.
  static String foldLine(String text) {
    const limit = 75;
    if (utf8.encode(text).length <= limit) return text;
    final out = StringBuffer();
    var used = 0;
    var first = true;
    for (final rune in text.runes) {
      final size = utf8.encode(String.fromCharCode(rune)).length;
      // Continuation lines start with a space, which counts.
      final room = first ? limit : limit - 1;
      if (used + size > room) {
        out.write('\r\n ');
        used = 0;
        first = false;
      }
      out.writeCharCode(rune);
      used += size;
    }
    return out.toString();
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// `20261031T050000Z`.
  static String formatUtc(DateTime instant) {
    final u = instant.toUtc();
    return '${u.year.toString().padLeft(4, '0')}${_two(u.month)}${_two(u.day)}'
        'T${_two(u.hour)}${_two(u.minute)}${_two(u.second)}Z';
  }

  /// `20261031`.
  static String formatDate(CivilDate d) =>
      '${d.year.toString().padLeft(4, '0')}${_two(d.month)}${_two(d.day)}';

  /// `PT6H`, `P1D`, `PT30M`: whole minutes only.
  static String formatDuration(Duration d) {
    final minutes = d.inMinutes;
    if (minutes <= 0) return 'PT0M';
    if (minutes % 1440 == 0) return 'P${minutes ~/ 1440}D';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return 'PT${h > 0 ? '${h}H' : ''}${m > 0 ? '${m}M' : ''}';
  }
}
