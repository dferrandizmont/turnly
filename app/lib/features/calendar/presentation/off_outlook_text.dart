import '../../../core/format/app_date_format.dart';
import '../../../l10n/app_localizations.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../application/off_outlook.dart';

/// The texts of the next day off (C1 of `docs/propuesta-mejoras.md`), shared by
/// the «Hoy» card and the widget snapshot so both say the same thing.

DateTime _at(CivilDate d) => DateTime(d.year, d.month, d.day);

/// «jueves 5»: long weekday and day of the month.
String offDayLabel(AppDateFormat format, CivilDate d) =>
    '${format.weekdayLong(_at(d))} ${d.day}';

/// «Libras el jueves 5», «Mañana libras», «Hoy libras» or «Hoy libras; vuelves
/// el lunes 9». `null` when no day off is known.
String? nextOffText(
  AppLocalizations l10n,
  AppDateFormat format,
  OffOutlook outlook,
) {
  final next = outlook.nextOff;
  if (next == null) return null;
  if (next.daysAway == 0) {
    final back = outlook.returnDate;
    return back == null
        ? l10n.offToday
        : l10n.offTodayBack(offDayLabel(format, back));
  }
  if (next.daysAway == 1) return l10n.offTomorrow;
  return l10n.offOn(offDayLabel(format, next.date));
}

/// «Fin de semana libre: 14–15 nov» (or «31 oct – 1 nov» across months).
/// `null` when there is none.
String? freeWeekendText(
  AppLocalizations l10n,
  AppDateFormat format,
  OffOutlook outlook,
) {
  final weekend = outlook.freeWeekend;
  if (weekend == null) return null;
  return l10n.offWeekend(weekendRange(format, weekend));
}

/// «14–15 nov» · «31 oct – 1 nov» · «Nov 14–15» · «Oct 31 – Nov 1».
String weekendRange(AppDateFormat format, FreeWeekend weekend) {
  final sat = _at(weekend.saturday);
  final sun = _at(weekend.sunday);
  final monthFirst =
      format.locale.split(RegExp('[-_]')).first == 'en' ||
      format.locale.split(RegExp('[-_]')).first == 'eu';
  String dayMonth(DateTime d) => monthFirst
      ? '${format.monthShort(d)} ${d.day}'
      : '${d.day} ${format.monthShort(d)}';
  if (sat.month == sun.month) {
    return monthFirst
        ? '${format.monthShort(sat)} ${sat.day}–${sun.day}'
        : '${sat.day}–${sun.day} ${format.monthShort(sat)}';
  }
  return '${dayMonth(sat)} – ${dayMonth(sun)}';
}

/// «Llevas 5 días seguidos; te quedan 2», only from [kStreakShownFrom] days;
/// `null` otherwise.
String? streakText(AppLocalizations l10n, OffOutlook outlook) {
  final worked = outlook.workedStreak;
  if (worked < kStreakShownFrom) return null;
  final left = outlook.workDaysLeft;
  if (left == null || left < 1) return l10n.offStreak(worked);
  return l10n.offStreakLeft(worked, left);
}
