import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'app_formats.dart';

/// Date/time formatting of the app in its language and region: the 24 h or
/// 12 h clock the person chose ([hour12]) and the short form of the app
/// ("jue 23 oct"). Needs `initializeDateFormatting` for [locale] (done in
/// `bootstrapApp` for every app language; tests call it in `setUpAll`).
///
/// The short weekday and month names come from fixed tables
/// (docs/glosario-idiomas.md §5) rather than from CLDR, which adds dots,
/// prepositions («de gen.») or four letters («sept»); the long forms come
/// from `intl`, except the Basque long date, built by hand.
class AppDateFormat {
  const AppDateFormat([this.locale = 'es', this.hour12 = false]);

  /// The formats in force in [context] (see [AppFormats]); without them the
  /// locale of `Localizations` and a 24 h clock.
  factory AppDateFormat.of(BuildContext context) {
    final formats = AppFormats.maybeOf(context);
    if (formats != null) {
      return AppDateFormat(formats.localeName, formats.hour12);
    }
    return AppDateFormat(Localizations.localeOf(context).toString());
  }

  /// Locale name: a language code ("es", "ca", "gl", "eu", "en") or the
  /// language with the region of the phone ("en_US", "es_MX"). Only the
  /// language picks the hand-made tables; `intl` takes the region into
  /// account for the rest.
  final String locale;

  /// Whether times read "10:00 PM" (12 h) instead of "22:00" (24 h).
  final bool hour12;

  /// First day of the week by default (Monday). The week the calendar shows
  /// starts where `Preferences.weekStart` says.
  static const int firstWeekday = DateTime.monday;

  String get _lang => locale.split(RegExp('[-_]')).first;

  /// "jue 23 oct" · "dj 23 oct" · "Thu Oct 23" · "urr 23, og".
  String shortDate(DateTime d) => switch (_lang) {
    'en' => '${weekdayShort(d)} ${monthShort(d)} ${d.day}',
    'eu' => '${monthShort(d)} ${d.day}, ${weekdayShort(d)}',
    _ => '${weekdayShort(d)} ${d.day} ${monthShort(d)}',
  };

  /// End date in «planned until …». Basque needs the full month and the
  /// day declined before «arte»; a suffix on the ARB placeholder cannot
  /// handle the different endings of the spoken numerals.
  String plannedUntilDate(DateTime d) {
    if (_lang != 'eu') return shortDate(d);
    const takesEra = {1, 5, 10, 15, 21, 25, 30};
    final ending = takesEra.contains(d.day) ? 'era' : 'ra';
    return '${_basqueMonths[d.month - 1]}ren ${d.day}$ending';
  }

  /// "oct", "sep": the short month name, three letters and no dot.
  String monthShort(DateTime d) {
    final table = _monthsShort[_lang];
    if (table != null) return table[d.month - 1];
    final raw = _stripDot(DateFormat.LLL(locale).format(d));
    return raw.length > 3 ? raw.substring(0, 3) : raw;
  }

  /// "19 oct 2026" · "Oct 19, 2026" · "2026 urr 19": a date with its year
  /// and the short month of the app.
  String dayMonthYear(DateTime d) => switch (_lang) {
    'en' => '${monthShort(d)} ${d.day}, ${d.year}',
    'eu' => '${d.year} ${monthShort(d)} ${d.day}',
    _ => '${d.day} ${monthShort(d)} ${d.year}',
  };

  /// "jue 23" · "Thu 23" · "og 23".
  String weekdayDay(DateTime d) => '${weekdayShort(d)} ${d.day}';

  /// The separator between the dates of a list: in Basque the short date
  /// has a comma of its own («urr 20, al»), so the examples are separated
  /// with a middle dot and it is clear where one ends and the next begins
  /// (H-T22-15).
  String get dateListSeparator => _lang == 'eu' ? ' · ' : ', ';

  /// "jueves, 23 de octubre" · "dijous, 23 d’octubre" · "Thursday,
  /// October 23" · "osteguna, urriaren 23a".
  String longDate(DateTime d) => _lang == 'eu'
      ? '${weekdayLong(d)}, ${_basqueDayOfMonth(d)}'
      : DateFormat.MMMMEEEEd(locale).format(d);

  /// "lunes 19 de octubre" (no comma in Spanish; reads well aloud). The
  /// other languages use [longDate].
  String weekdayDayMonth(DateTime d) => _lang == 'es'
      ? DateFormat("EEEE d 'de' MMMM", locale).format(d)
      : longDate(d);

  /// "octubre".
  String monthName(DateTime d) => DateFormat.LLLL(locale).format(d);

  /// "octubre 2026".
  String monthYear(DateTime d) => DateFormat('LLLL y', locale).format(d);

  /// "jueves".
  String weekdayLong(DateTime d) => DateFormat.EEEE(locale).format(d);

  /// "jue" · "dj" · "Thu" · "og": three letters (two in Catalan and Basque)
  /// and no dot.
  String weekdayShort(DateTime d) {
    final table = _weekdaysShort[_lang];
    if (table != null) return table[d.weekday - 1];
    return _stripDot(DateFormat.E(locale).format(d));
  }

  /// "18:30" on the 24 h clock, "6:30 PM" on the 12 h one (the AM/PM marks
  /// are the ones of the locale: "6:30 p. m." in Spanish).
  String time(DateTime d) =>
      DateFormat(hour12 ? 'h:mm a' : 'HH:mm', locale).format(d);

  /// The short form of a time of day for the tight places (the cell of the
  /// month, the lock-screen line of the widget): the minutes only when they
  /// are not :00. 24 h: "22", "07:30". 12 h: "10p", "7:30a" (a = AM, p = PM
  /// in every language, so "10p–6a" reads as 22:00–06:00 and fits where the
  /// 24 h form does). [minute] is minutes after midnight; 1440 wraps to 0.
  static String compactClock(int minute, {bool hour12 = false}) {
    final h = (minute ~/ 60) % 24;
    final m = minute % 60;
    if (!hour12) {
      String two(int n) => n.toString().padLeft(2, '0');
      return m == 0 ? two(h) : '${two(h)}:${two(m)}';
    }
    final shown = h % 12 == 0 ? 12 : h % 12;
    final mark = h < 12 ? 'a' : 'p';
    return m == 0
        ? '$shown$mark'
        : '$shown:${m.toString().padLeft(2, '0')}$mark';
  }

  /// Like [compactClock] but without the minutes: "09" or "9a" (for the cell
  /// that has no room for "09:30").
  static String compactClockHour(int minute, {bool hour12 = false}) =>
      compactClock(minute - minute % 60, hour12: hour12);

  /// "09:00–16:30" or just "09:00".
  String timeRange(DateTime start, DateTime? end) {
    if (end == null) return time(start);
    return '${time(start)}–${time(end)}';
  }

  /// "vie 23 oct – lun 26 oct".
  String shortDateRange(DateTime start, DateTime end) =>
      '${shortDate(start)} – ${shortDate(end)}';

  static String _stripDot(String s) =>
      s.endsWith('.') ? s.substring(0, s.length - 1) : s;

  /// "urriaren 20a": genitive of the month (every Basque month name ends in
  /// -a, so it takes -ren) and the day with the article -a, which 11 and 31
  /// (hamaika, hogeita hamaika: already ending in -a) do not take.
  static String _basqueDayOfMonth(DateTime d) {
    final month = _basqueMonths[d.month - 1];
    final article = d.day == 11 || d.day == 31 ? '' : 'a';
    return '${month}ren ${d.day}$article';
  }
}

const _weekdaysShort = {
  'es': ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'],
  'ca': ['dl', 'dt', 'dc', 'dj', 'dv', 'ds', 'dg'],
  'gl': ['luns', 'mar', 'mér', 'xov', 'ven', 'sáb', 'dom'],
  'eu': ['al', 'ar', 'az', 'og', 'or', 'lr', 'ig'],
  'en': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
};

const _monthsShort = {
  'es': [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun', //
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ],
  'ca': [
    'gen', 'feb', 'mar', 'abr', 'mai', 'jun', //
    'jul', 'ago', 'set', 'oct', 'nov', 'des',
  ],
  'gl': [
    'xan', 'feb', 'mar', 'abr', 'mai', 'xuñ', //
    'xul', 'ago', 'set', 'out', 'nov', 'dec',
  ],
  'eu': [
    'urt', 'ots', 'mar', 'api', 'mai', 'eka', //
    'uzt', 'abu', 'ira', 'urr', 'aza', 'abe',
  ],
  'en': [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ],
};

const _basqueMonths = [
  'urtarrila', 'otsaila', 'martxoa', 'apirila', 'maiatza', 'ekaina', //
  'uztaila', 'abuztua', 'iraila', 'urria', 'azaroa', 'abendua',
];
