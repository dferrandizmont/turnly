import 'package:collection/collection.dart';

import 'civil_date.dart';
import 'shift_type.dart';

/// The part of a [ShiftType] that decides hours and money: category, times,
/// second segment, paid minutes, night override, hourly rate, fixed plus and
/// the night and holiday pluses per hour (schema v6).
///
/// Name, code, colour, icon, alarm sound and place are only how the type looks and
/// sounds: they always apply to every day. A change of these terms is the one
/// that can rewrite months already worked and paid, so the editor asks
/// whether it is a correction (every day) or a change from today on
/// (docs/motor-de-turnos.md, «Versiones de un tipo»).
class ShiftTerms {
  const ShiftTerms({
    required this.category,
    this.startMinute,
    this.endMinute,
    this.paidMinutes,
    this.nightOverride,
    this.hourlyRateCents,
    this.fixedPlusCents,
    this.segment2StartMinute,
    this.segment2DurationMinutes,
    this.nightPlusCentsPerHour,
    this.holidayPlusCentsPerHour,
  });

  factory ShiftTerms.of(ShiftType t) => ShiftTerms(
    category: t.category,
    startMinute: t.startMinute,
    endMinute: t.endMinute,
    paidMinutes: t.paidMinutes,
    nightOverride: t.nightOverride,
    hourlyRateCents: t.hourlyRateCents,
    fixedPlusCents: t.fixedPlusCents,
    segment2StartMinute: t.segment2StartMinute,
    segment2DurationMinutes: t.segment2DurationMinutes,
    nightPlusCentsPerHour: t.nightPlusCentsPerHour,
    holidayPlusCentsPerHour: t.holidayPlusCentsPerHour,
  );

  final ShiftCategory category;
  final int? startMinute;
  final int? endMinute;
  final int? paidMinutes;
  final bool? nightOverride;
  final int? hourlyRateCents;
  final int? fixedPlusCents;
  final int? segment2StartMinute;
  final int? segment2DurationMinutes;
  final int? nightPlusCentsPerHour;
  final int? holidayPlusCentsPerHour;

  /// [type] (its id, name, code, colour, icon, sound and place) with these
  /// terms.
  ShiftType applyTo(ShiftType type) => ShiftType(
    id: type.id,
    code: type.code,
    name: type.name,
    colorValue: type.colorValue,
    icon: type.icon,
    alarmSound: type.alarmSound,
    location: type.location,
    category: category,
    startMinute: startMinute,
    endMinute: endMinute,
    paidMinutes: paidMinutes,
    nightOverride: nightOverride,
    hourlyRateCents: hourlyRateCents,
    fixedPlusCents: fixedPlusCents,
    segment2StartMinute: segment2StartMinute,
    segment2DurationMinutes: segment2DurationMinutes,
    nightPlusCentsPerHour: nightPlusCentsPerHour,
    holidayPlusCentsPerHour: holidayPlusCentsPerHour,
  );

  /// Why these terms cannot be stored (the same rules as a [ShiftType] and
  /// the database), or `null` when they are valid.
  String? get problem {
    if ((startMinute == null) != (endMinute == null)) {
      return 'start and end must be both set or both null';
    }
    for (final m in [startMinute, endMinute]) {
      if (m != null && (m < 0 || m > 1439)) return 'time out of range';
    }
    if (paidMinutes != null && paidMinutes! < 0) return 'negative paid minutes';
    final rate = hourlyRateCents;
    if (rate != null && (rate < 0 || rate > maxHourlyRateCents)) {
      return 'hourly rate out of range';
    }
    final plus = fixedPlusCents;
    if (plus != null && (plus < 0 || plus > maxFixedPlusCents)) {
      return 'fixed plus out of range';
    }
    for (final hourlyPlus in [nightPlusCentsPerHour, holidayPlusCentsPerHour]) {
      if (hourlyPlus != null &&
          (hourlyPlus < 0 || hourlyPlus > maxStoredMoneyCents)) {
        return 'hourly plus out of range';
      }
    }
    final segment2 = checkSegment2(
      startMinute: startMinute,
      endMinute: endMinute,
      segment2StartMinute: segment2StartMinute,
      segment2DurationMinutes: segment2DurationMinutes,
    );
    if (segment2 != null) return 'invalid second segment: ${segment2.name}';
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is ShiftTerms &&
      other.category == category &&
      other.startMinute == startMinute &&
      other.endMinute == endMinute &&
      other.paidMinutes == paidMinutes &&
      other.nightOverride == nightOverride &&
      other.hourlyRateCents == hourlyRateCents &&
      other.fixedPlusCents == fixedPlusCents &&
      other.segment2StartMinute == segment2StartMinute &&
      other.segment2DurationMinutes == segment2DurationMinutes &&
      other.nightPlusCentsPerHour == nightPlusCentsPerHour &&
      other.holidayPlusCentsPerHour == holidayPlusCentsPerHour;

  @override
  int get hashCode => Object.hash(
    category,
    startMinute,
    endMinute,
    paidMinutes,
    nightOverride,
    hourlyRateCents,
    fixedPlusCents,
    segment2StartMinute,
    segment2DurationMinutes,
    nightPlusCentsPerHour,
    holidayPlusCentsPerHour,
  );

  @override
  String toString() =>
      'ShiftTerms($category, $startMinute-$endMinute, '
      'paid: $paidMinutes, rate: $hourlyRateCents, plus: $fixedPlusCents)';
}

/// The terms a shift type had **up to [until]** (included), before a change
/// made «only from today on». One row per change, never one per day.
///
/// A type's versions, sorted by [until], cut time in periods: the first
/// version governs every day up to its [until], the next one the days after
/// that up to its own [until], and the type's current terms every day after
/// the last [until]. The id never changes, so rotations, days, undo, backups
/// and imports keep pointing at the same type.
class ShiftTypeVersion {
  const ShiftTypeVersion({required this.until, required this.terms});

  final CivilDate until;
  final ShiftTerms terms;

  @override
  bool operator ==(Object other) =>
      other is ShiftTypeVersion && other.until == until && other.terms == terms;

  @override
  int get hashCode => Object.hash(until, terms);

  @override
  String toString() => 'ShiftTypeVersion(until $until, $terms)';
}

/// Whether going from [before] to [after] changes hours or money, so the
/// editor has to ask «every day» or «from today on». Name, code, colour, icon
/// and alarm sound never need it: they apply to every day.
///
/// The terms are compared as they **count**: paid minutes as
/// `effectivePaidMinutes` (a stored 480 on an 8 h shift is the same as none),
/// and the paid minutes, night override and hourly rate only on a worked
/// shift with times (the night and holiday pluses per hour too), the fixed
/// plus only on a worked shift (the only ones the
/// summary reads them on; the editor drops them elsewhere). Category, times
/// and second segment always count.
bool shiftTypeEditNeedsScope(ShiftType before, ShiftType after) =>
    _counted(before) != _counted(after);

ShiftTerms _counted(ShiftType t) {
  final work = t.category == ShiftCategory.work;
  final pay = work && t.hasTimes;
  return ShiftTerms(
    category: t.category,
    startMinute: t.startMinute,
    endMinute: t.endMinute,
    paidMinutes: pay ? t.effectivePaidMinutes : null,
    nightOverride: pay ? t.nightOverride : null,
    hourlyRateCents: pay ? t.hourlyRateCents : null,
    fixedPlusCents: work ? t.fixedPlusCents : null,
    segment2StartMinute: t.segment2StartMinute,
    segment2DurationMinutes: t.segment2DurationMinutes,
    nightPlusCentsPerHour: pay ? t.nightPlusCentsPerHour : null,
    holidayPlusCentsPerHour: pay ? t.holidayPlusCentsPerHour : null,
  );
}

/// [current] as it was on [day]: with the terms of the first version of
/// [history] (sorted by `until`) that reaches [day], or [current] itself
/// (the very same object) when no version does.
ShiftType shiftTypeAsOf(
  ShiftType current,
  List<ShiftTypeVersion> history,
  CivilDate day,
) {
  for (final version in history) {
    if (!day.isAfter(version.until)) return version.terms.applyTo(current);
  }
  return current;
}

/// First day governed by the current terms of a type with [history]
/// (sorted), or `null` when the type has always had them.
CivilDate? currentTermsSince(List<ShiftTypeVersion> history) =>
    history.isEmpty ? null : history.last.until.addDays(1);

/// The history a type needs when its terms go from [before] (the current
/// ones) to [after] **from [from] on**: every day before [from] keeps
/// resolving exactly as it does now, and [from] and every day after it get
/// [after] (which the caller stores as the type's new current terms).
///
/// Versions that end before the day before [from] stay as they are; the one
/// that governs that day (or [before], when none does) is cut to end on it;
/// later versions are dropped, since they only governed days that now get
/// [after]. Neighbours with the same terms are merged, and a last version
/// equal to [after] is dropped (going back to the old terms from today on
/// needs no version), so the history never grows without a change.
List<ShiftTypeVersion> historyForChangeFrom(
  List<ShiftTypeVersion> history, {
  required ShiftTerms before,
  required ShiftTerms after,
  required CivilDate from,
}) {
  final cutoff = from.addDays(-1);
  final sorted = sortedVersions(history);
  final result = <ShiftTypeVersion>[
    for (final v in sorted)
      if (v.until.isBefore(cutoff)) v,
  ];
  final governing =
      sorted.firstWhereOrNull((v) => !v.until.isBefore(cutoff))?.terms ??
      before;
  result.add(ShiftTypeVersion(until: cutoff, terms: governing));
  return _normalized(result, current: after);
}

/// [history] sorted by `until`, with one version per `until` (the last one
/// listed wins).
List<ShiftTypeVersion> sortedVersions(Iterable<ShiftTypeVersion> history) {
  final byUntil = <CivilDate, ShiftTypeVersion>{
    for (final v in history) v.until: v,
  };
  return byUntil.values.toList()..sort((a, b) => a.until.compareTo(b.until));
}

/// Merges neighbours with the same terms (the later `until` stays) and drops
/// trailing versions equal to [current].
List<ShiftTypeVersion> _normalized(
  List<ShiftTypeVersion> sorted, {
  required ShiftTerms current,
}) {
  final merged = <ShiftTypeVersion>[];
  for (final v in sorted) {
    if (merged.isNotEmpty && merged.last.terms == v.terms) {
      merged.removeLast();
    }
    merged.add(v);
  }
  while (merged.isNotEmpty && merged.last.terms == current) {
    merged.removeLast();
  }
  return merged;
}

/// What is wrong with [history] as the stored versions of a type, or `null`
/// when it is fine: every terms valid and one version per `until`.
String? checkShiftTypeVersions(List<ShiftTypeVersion> history) {
  final seen = <CivilDate>{};
  for (final v in history) {
    if (!seen.add(v.until)) return 'two versions end on ${v.until.toIso()}';
    final problem = v.terms.problem;
    if (problem != null) return problem;
  }
  return null;
}
