import '../../schedule/domain/schedule_domain.dart';

/// Starting templates of pluses by sector (propuesta 2 de
/// `docs/competencia-2026-11.md`): sanidad pública, bomberos and vigilantes
/// de seguridad privada.
///
/// A template only says **which** pluses a sector usually has and on which
/// shifts: a plus per hour of night, a plus per hour of holiday, a plus per
/// guard. It never brings an amount: the amounts change with the community,
/// the administration, the company and the year, and the app does not invent
/// salaries. Every amount starts at 0 and the user types theirs before
/// applying it. The only figure a template brings is the annual working time
/// of an agreement with one public text for all of Spain (seguridad privada),
/// and the user can change it or leave it out.
///
/// Applying a template writes the amounts into the three plus fields every
/// work shift type already has ([ShiftType.nightPlusCentsPerHour],
/// [ShiftType.holidayPlusCentsPerHour], [ShiftType.fixedPlusCents]), so the
/// summary counts them as it already does: the night plus over the night
/// hours, the holiday plus over the hours on a holiday split by calendar day
/// (a 24 h guard that crosses into a holiday counts only its hours of the
/// holiday) and the fixed plus once per shift.

/// The sector of a template.
enum PayTemplateKind {
  publicHealth('publicHealth'),
  firefighters('firefighters'),
  privateSecurity('privateSecurity');

  const PayTemplateKind(this.stored);

  final String stored;
}

/// The plus field of a shift type a concept fills.
enum PlusSlot {
  /// Money per hour of night ([ShiftType.nightPlusCentsPerHour]).
  nightPerHour,

  /// Money per hour on a holiday ([ShiftType.holidayPlusCentsPerHour]).
  holidayPerHour,

  /// Money per shift worked ([ShiftType.fixedPlusCents]).
  fixedPerShift,
}

/// The shifts a concept applies to.
enum PlusTarget {
  /// Every work shift type.
  allWork,

  /// The guards: work shift types of [guardMinMinutes] or more.
  guards,
}

/// A work shift of 17 hours or more is a guard (the 17 h guard of a weekday
/// in a hospital, the 24 h guard of a fire station or of a weekend).
const int guardMinMinutes = 17 * 60;

/// Whether any segment of [type] falls (even partly) inside the night window
/// (22:00-06:00, or all/none with [ShiftType.nightOverride]). A type without
/// times has none.
bool hasNightHours(ShiftType type) {
  if (!type.hasTimes) return false;
  const window = NightWindow();
  return ShiftOccurrence.allOf(
    const CivilDate(2026, 1, 1),
    type,
  ).any((o) => window.nightMinutes(o) > 0);
}

/// One plus of a template.
class PlusConcept {
  const PlusConcept(this.slot, this.target);

  final PlusSlot slot;
  final PlusTarget target;

  /// Whether this concept applies to [type]. The pluses per hour need the
  /// hours of the shift; the plus per shift only a work shift.
  ///
  /// The night plus only goes on types that have night hours (the same
  /// [NightWindow] the summary counts them with): writing it on a Morning
  /// would show a plus that can never pay.
  bool appliesTo(ShiftType type) {
    if (type.category != ShiftCategory.work) return false;
    if (slot != PlusSlot.fixedPerShift && !type.hasTimes) return false;
    if (slot == PlusSlot.nightPerHour && !hasNightHours(type)) return false;
    return switch (target) {
      PlusTarget.allWork => true,
      PlusTarget.guards => type.hasTimes && type.scheduledMinutes >= guardMinMinutes,
    };
  }
}

/// A starting template.
class PayTemplate {
  const PayTemplate({
    required this.kind,
    required this.concepts,
    this.annualHours,
  });

  final PayTemplateKind kind;
  final List<PlusConcept> concepts;

  /// The annual working time of the agreement, when there is one public text
  /// for the whole sector; `null` when it changes with the employer.
  final int? annualHours;
}

/// The templates the app offers, in the order of the screen.
///
/// * **Sanidad pública**: nocturnidad and festivos per hour, and the guard
///   (atención continuada) per guard. The amounts and the annual working time
///   change with each health service, so none is given.
/// * **Bomberos**: the 24 h guard per guard, and nocturnidad and festivos per
///   hour. Each administration sets its own amounts and hours.
/// * **Vigilantes de seguridad privada**: nocturnidad and festivos per hour.
///   The Convenio colectivo estatal de empresas de seguridad (BOE, resolución
///   de 8 de abril de 2026; the same figure as the agreements since 2015)
///   sets 1782 hours of effective work a year. Its amounts change every year
///   in its salary tables, so none is given.
const List<PayTemplate> payTemplates = [
  PayTemplate(
    kind: PayTemplateKind.publicHealth,
    concepts: [
      PlusConcept(PlusSlot.nightPerHour, PlusTarget.allWork),
      PlusConcept(PlusSlot.holidayPerHour, PlusTarget.allWork),
      PlusConcept(PlusSlot.fixedPerShift, PlusTarget.guards),
    ],
  ),
  PayTemplate(
    kind: PayTemplateKind.firefighters,
    concepts: [
      PlusConcept(PlusSlot.fixedPerShift, PlusTarget.guards),
      PlusConcept(PlusSlot.nightPerHour, PlusTarget.allWork),
      PlusConcept(PlusSlot.holidayPerHour, PlusTarget.allWork),
    ],
  ),
  PayTemplate(
    kind: PayTemplateKind.privateSecurity,
    concepts: [
      PlusConcept(PlusSlot.nightPerHour, PlusTarget.allWork),
      PlusConcept(PlusSlot.holidayPerHour, PlusTarget.allWork),
    ],
    annualHours: 1782,
  ),
];

/// The template of [kind].
PayTemplate payTemplateOf(PayTemplateKind kind) =>
    payTemplates.firstWhere((t) => t.kind == kind);

/// The value [type] has in [slot] (`null` when it has none).
int? plusValueOf(ShiftType type, PlusSlot slot) => switch (slot) {
  PlusSlot.nightPerHour => type.nightPlusCentsPerHour,
  PlusSlot.holidayPerHour => type.holidayPlusCentsPerHour,
  PlusSlot.fixedPerShift => type.fixedPlusCents,
};

/// [type] with [cents] in [slot].
ShiftType withPlus(ShiftType type, PlusSlot slot, int cents) => switch (slot) {
  PlusSlot.nightPerHour => type.copyWith(nightPlusCentsPerHour: cents),
  PlusSlot.holidayPerHour => type.copyWith(holidayPlusCentsPerHour: cents),
  PlusSlot.fixedPerShift => type.copyWith(fixedPlusCents: cents),
};

/// The starting amount of each concept of [template] on screen: the value
/// the chosen shift types already share in that field (so opening the
/// template again shows what was applied) or 0. A template never brings an
/// amount of its own.
Map<PlusSlot, int> startingAmounts(
  PayTemplate template,
  Iterable<ShiftType> types,
) => {
  for (final concept in template.concepts)
    concept.slot: _sharedValue(concept, types) ?? 0,
};

int? _sharedValue(PlusConcept concept, Iterable<ShiftType> types) {
  int? shared;
  for (final type in types) {
    if (!concept.appliesTo(type)) continue;
    final value = plusValueOf(type, concept.slot);
    if (value == null) return null;
    if (shared != null && shared != value) return null;
    shared = value;
  }
  return shared;
}

/// The shift types of [types] that change when [template] is applied with
/// [amounts] (cents per slot; a missing slot is 0), already changed. Only the
/// types whose id is in [selected] are touched, and in them only the fields
/// of the concepts that apply to them: a plus the template does not have is
/// left as it was. A type that would end the same is not returned.
List<ShiftType> applyPayTemplate(
  PayTemplate template,
  Iterable<ShiftType> types, {
  required Map<PlusSlot, int> amounts,
  required Set<String> selected,
}) {
  final changed = <ShiftType>[];
  for (final type in types) {
    if (!selected.contains(type.id)) continue;
    var next = type;
    for (final concept in template.concepts) {
      if (!concept.appliesTo(type)) continue;
      final cents = amounts[concept.slot] ?? 0;
      if (plusValueOf(next, concept.slot) == cents) continue;
      next = withPlus(next, concept.slot, cents);
    }
    if (!identical(next, type)) changed.add(next);
  }
  return changed;
}

/// Whether [template] has something to write on [type].
bool templateAppliesTo(PayTemplate template, ShiftType type) =>
    template.concepts.any((c) => c.appliesTo(type));
