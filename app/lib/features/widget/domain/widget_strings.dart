import 'package:flutter/widgets.dart' show Locale;
import 'package:intl/intl.dart';

import '../../../core/format/app_date_format.dart';
import '../../../l10n/app_localizations.dart';
import '../../calendar/application/off_outlook.dart';
import '../../calendar/presentation/off_outlook_text.dart';
import '../../calendar/presentation/shift_format.dart';
import '../../calendar/presentation/overtime_format.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../../summary/presentation/summary_format.dart';

/// Already-localized texts the widget snapshot needs. The caller fills them
/// from the app's localizations. Spoken descriptions reuse the app's phrases
/// and CLDR dates; initialize date formatting first, as bootstrap does.
/// The builder remains deterministic and never reads the device clock/locale.
class WidgetStrings {
  const WidgetStrings({
    this.locale = 'es',
    this.weekdaysShort = _weekdaysShortEs,
    this.weekdayHeaders = _weekdayHeadersEs,
    this.monthNames = _monthNamesEs,
    this.noShift = 'Sin turno',
    this.absence = 'Ausencia',
    this.tomorrow = 'Mañana',
    this.emptyCircular = '–',
    this.staleTitle = 'Turnly',
    this.staleBody = 'Abre Turnly para seguir al día',
    this.hour12 = false,
  });

  /// The texts of the current locale, from the ARB file (`widget*` keys). The
  /// day and month lists are comma separated there (7, 7 and 12 items); a
  /// list of the wrong length falls back to the Spanish one so the snapshot
  /// can always be built.
  ///
  /// [hour12] is the clock of Ajustes › Formato de hora: the times of the
  /// snapshot come already written, "22:00–06:00" or "10p–6a".
  factory WidgetStrings.fromL10n(AppLocalizations l10n, {bool hour12 = false}) {
    List<String> list(String raw, List<String> fallback) {
      final items = raw.split(',').map((e) => e.trim()).toList();
      return items.length == fallback.length ? items : fallback;
    }

    return WidgetStrings(
      locale: l10n.localeName,
      weekdaysShort: list(l10n.widgetWeekdaysShort, _weekdaysShortEs),
      weekdayHeaders: list(l10n.widgetWeekdayHeaders, _weekdayHeadersEs),
      monthNames: list(l10n.widgetMonthNames, _monthNamesEs),
      noShift: l10n.calendarNoShift,
      absence: l10n.shiftTypesCategoryAbsence,
      tomorrow: l10n.widgetTomorrow,
      emptyCircular: l10n.widgetEmptyCircular,
      staleTitle: l10n.widgetStaleTitle,
      staleBody: l10n.widgetStaleBody,
      hour12: hour12,
    );
  }

  /// Complete spoken labels use the same localized phrases as the app.
  AppLocalizations get _l10n => lookupAppLocalizations(Locale(locale));

  String get todayLabel => _l10n.daySemanticsToday;

  String overtimeLabel(int minutes, OvertimeType? type) {
    final duration = formatHours(_l10n, minutes);
    return type == null || (type.id == overtimeTypeId && type.name == null)
        ? _l10n.widgetOvertime(duration)
        : _l10n.widgetOvertimeType(duration, overtimeTypeName(_l10n, type));
  }

  String earlyLeaveLabel(int minutes) =>
      _l10n.widgetEarlyLeave(formatHours(_l10n, minutes));

  String sevenDayHours(int minutes) =>
      _l10n.widgetSevenDayHours(formatHours(_l10n, minutes));

  /// «Libras el jueves 5» / «Mañana libras» / «Hoy libras; vuelves el lunes 9»
  /// for the optional `nextOff` extension; `null` when no day off is known.
  String? nextOffLabel(OffOutlook outlook) =>
      nextOffText(_l10n, AppDateFormat(locale), outlook);

  String describe(
    CivilDate date,
    ResolvedDay day,
    String? holidayName, {
    bool redactAbsence = false,
    List<String> extras = const [],
  }) {
    final l10n = _l10n;
    final format = AppDateFormat(locale, hour12);
    final dateTime = DateTime.utc(date.year, date.month, date.day);
    final private =
        redactAbsence &&
        day.shifts.any((s) => s.category == ShiftCategory.absence);
    return [
      // The app's Basque date avoids CLDR's literal optional suffix markers.
      if (locale == 'eu')
        '${format.longDate(dateTime)}, ${date.year}'
      else
        DateFormat.yMMMMEEEEd(locale).format(dateTime),
      if (day.shifts.isEmpty) noShift,
      for (final shift in day.shifts)
        if (redactAbsence && shift.category == ShiftCategory.absence)
          absence
        else
          shift.spoken(l10n, format),
      if (holidayName != null) l10n.daySemanticsHoliday(holidayName),
      ...extras,
      if (!private && day.note != null && day.note!.isNotEmpty)
        l10n.daySemanticsNote,
    ].join('. ');
  }

  /// Spanish texts. Used by tests and as the
  /// fallback of the caller.
  static const WidgetStrings es = WidgetStrings();

  /// BCP 47 language code the texts are in ("es").
  final String locale;

  /// Whether the times of the snapshot are written on the 12 h clock.
  final bool hour12;

  /// "lun", "mar"... Monday first.
  final List<String> weekdaysShort;

  /// One-letter column headers of the month grid, Monday first.
  final List<String> weekdayHeaders;

  /// "enero"... "diciembre"; the builder capitalizes the first letter to build
  /// "Octubre 2026".
  final List<String> monthNames;

  /// Text for a day without shifts ("Sin turno").
  final String noShift;
  final String absence;

  /// Prefix of the next-day line ("Mañana" gives "Mañana: T 14–22").
  final String tomorrow;

  /// What the circular lock-screen widget shows on a day without shifts.
  final String emptyCircular;

  /// Shown instead of any day once the timeline is over.
  final String staleTitle;
  final String staleBody;

  /// Whether the lists have the lengths the builder relies on (7, 7 and 12).
  bool get isValid =>
      weekdaysShort.length == 7 &&
      weekdayHeaders.length == 7 &&
      monthNames.length == 12;

  Map<String, Object?> toJson() => {
    'locale': locale,
    'weekdaysShort': weekdaysShort,
    'weekdayHeaders': weekdayHeaders,
    'monthNames': monthNames,
    'noShift': noShift,
    'absence': absence,
    'tomorrow': tomorrow,
    'emptyCircular': emptyCircular,
    'staleTitle': staleTitle,
    'staleBody': staleBody,
  };
}

const _weekdaysShortEs = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
const _weekdayHeadersEs = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
const _monthNamesEs = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];
