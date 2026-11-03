import '../../schedule/domain/civil_date.dart';
import 'absence_balance.dart';

/// What is left of one absence balance: the days of one series (vacaciones,
/// asuntos propios...) of one year of one calendar.
///
/// Every figure is in **days** (steps of a quarter of a day), whatever the
/// unit of the balance ([AbsenceUnit]): two balances can always be added.
/// Pure Dart: the screen only shows what is here.
///
/// The days used are never stored (docs/datos.md, «Saldos de ausencias»):
/// they are counted from the days of the calendar (see
/// `AbsenceBalanceCalculator`).
class AbsenceBalanceStatus {
  const AbsenceBalanceStatus({
    required this.balance,
    required this.calendarId,
    required this.allowedDays,
    required this.carriedDays,
    required this.expiredDays,
    required this.adjustmentDays,
    required this.usedDays,
    required this.enjoyedDays,
    required this.plannedDays,
    required this.carriedLeftDays,
    this.carryOverExpiry,
    this.warnings = const [],
  });

  /// The row this status is about (what is allowed, the unit, the period...).
  final AbsenceBalance balance;

  /// The calendar whose days count (the balance of the primary calendar when
  /// it has none).
  final String calendarId;

  /// The days allowed in the period (the row).
  final double allowedDays;

  /// The days carried from the year before (already capped by the row's cap).
  final double carriedDays;

  /// The carried days that are no longer in force (their expiry has passed):
  /// they are lost and do not count in [availableDays].
  final double expiredDays;

  /// The days added (or taken) by hand (the row).
  final double adjustmentDays;

  /// The days used: [enjoyedDays] + [plannedDays].
  final double usedDays;

  /// The days used before today (disfrutados).
  final double enjoyedDays;

  /// The days used today and after (planificados).
  final double plannedDays;

  /// The carried days not used yet: what will be lost when they expire.
  final double carriedLeftDays;

  /// The day the carried days expire (they never expire without one).
  final CivilDate? carryOverExpiry;

  /// What the user should know about this balance (typed: the screen
  /// translates it).
  final List<AbsenceWarning> warnings;

  /// The carried days that still count.
  double get carriedInForceDays => carriedDays - expiredDays;

  /// The days there are: the allowed ones, the carried ones still in force
  /// and the manual adjustments.
  double get availableDays => allowedDays + carriedInForceDays + adjustmentDays;

  /// What is left: what there are minus what is used (negative when more was
  /// used than there was).
  double get remainingDays => availableDays - usedDays;

  /// The days there were before the planned ones: what was left to plan.
  double get leftBeforePlanning => availableDays - enjoyedDays;

  /// The carried days have expired and are lost.
  bool get carryOverExpired => expiredDays > 0;

  /// Whether there is something to tell the user.
  bool get hasWarnings => warnings.isNotEmpty;

  /// The name to show (the row's name, or its series key).
  String get displayName => balance.displayName;

  @override
  String toString() =>
      'AbsenceBalanceStatus($calendarId ${balance.year}/${balance.type}: '
      '$availableDays days, $usedDays used, $remainingDays left)';
}

/// Something the user should know about a balance. Typed, so the screen can
/// translate it (there are no texts here).
sealed class AbsenceWarning {
  const AbsenceWarning();

  @override
  String toString() => '$runtimeType';
}

/// «Te quedan N días que caducan el …»: [days] carried from the year before
/// are still there and will be lost on [expiryDate].
final class CarryOverExpiring extends AbsenceWarning {
  const CarryOverExpiring({required this.days, required this.expiryDate});

  /// The carried days that will be lost.
  final double days;

  /// The day they expire.
  final CivilDate expiryDate;

  @override
  bool operator ==(Object other) =>
      other is CarryOverExpiring &&
      other.days == days &&
      other.expiryDate == expiryDate;

  @override
  int get hashCode => Object.hash(days, expiryDate);

  @override
  String toString() => 'CarryOverExpiring($days days, until $expiryDate)';
}

/// «Has planificado más de los que tienes»: [plannedDays] of absence are
/// planned and only [leftDays] were left to plan them.
final class PlannedExceedsAvailable extends AbsenceWarning {
  const PlannedExceedsAvailable({
    required this.plannedDays,
    required this.leftDays,
  });

  /// The days of absence planned (today and after).
  final double plannedDays;

  /// The days that were left before planning them.
  final double leftDays;

  @override
  bool operator ==(Object other) =>
      other is PlannedExceedsAvailable &&
      other.plannedDays == plannedDays &&
      other.leftDays == leftDays;

  @override
  int get hashCode => Object.hash(plannedDays, leftDays);

  @override
  String toString() =>
      'PlannedExceedsAvailable($plannedDays planned, $leftDays left)';
}
