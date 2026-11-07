import '../../holidays/domain/holiday_country.dart';
import '../../schedule/domain/schedule_domain.dart';

/// "¿A qué te dedicas?" (turnos-spec.md section 4, first use). The choice
/// preloads the shift types and the patterns typical of the job.
///
/// Spain gets the list of the Spanish sector (TCAE, Guardia Civil...); any
/// other country a neutral one ([professionsFor]). The names come from
/// `ProfessionText` and follow the same country.
enum Profession {
  nursing,
  medicine,
  police,
  firefighters,
  industry,
  security,
  hospitality,

  /// Only outside Spain (in Spain it is part of «Hostelería y comercio»).
  commerce,

  /// Only outside Spain.
  transport,
  other;

  /// The value stored in the `onboarding.profile` setting.
  String get stored => name;

  /// The profession of a stored value, or `null` (absent or unknown).
  static Profession? fromStored(Object? value) {
    for (final p in values) {
      if (p.name == value) return p;
    }
    return null;
  }

  /// Hours this profession works on the shift types the app already has
  /// (template keys, see [shiftTemplates]); never new types. Anything not
  /// listed keeps the hours of the standard palette.
  List<ProfessionHours> get hours => switch (this) {
    Profession.nursing => const [
      ProfessionHours('morning', 8, 15),
      ProfessionHours('afternoon', 15, 22),
      ProfessionHours('night', 22, 8),
    ],
    Profession.medicine => const [ProfessionHours('morning', 8, 15)],
    Profession.police => const [
      ProfessionHours('morning', 7, 15),
      ProfessionHours('afternoon', 15, 23),
      ProfessionHours('night', 23, 7),
    ],
    Profession.hospitality => const [
      ProfessionHours('morning', 8, 16),
      ProfessionHours('afternoon', 16, 0),
    ],
    Profession.commerce => const [
      ProfessionHours('morning', 9, 15),
      ProfessionHours('afternoon', 15, 21),
    ],
    // Firefighters (G 24 h), industry and transport (M 06-14, T 14-22,
    // N 22-06), private security (D / N 12 h) and "other" already match the
    // standard palette.
    Profession.firefighters ||
    Profession.industry ||
    Profession.transport ||
    Profession.security ||
    Profession.other => const [],
  };

  /// Shift types (template keys) this job uses most, in the order the paint
  /// bar should offer them; the rest follow in their current order.
  List<String> get paletteFirst => switch (this) {
    Profession.nursing => const [
      'morning',
      'afternoon',
      'night',
      'postNight',
      'rest',
      'vacation',
      'personalDay',
    ],
    Profession.medicine => const [
      'morning',
      'guard24',
      'postNight',
      'rest',
      'personalDay',
      'vacation',
    ],
    Profession.police => const [
      'morning',
      'afternoon',
      'night',
      'rest',
      'postNight',
      'personalDay',
      'vacation',
    ],
    Profession.firefighters => const [
      'guard24',
      'rest',
      'personalDay',
      'vacation',
    ],
    Profession.industry => const [
      'morning',
      'afternoon',
      'night',
      'rest',
      'vacation',
      'personalDay',
    ],
    Profession.security => const [
      'day12',
      'night12',
      'rest',
      'postNight',
      'vacation',
      'personalDay',
    ],
    Profession.hospitality => const [
      'morning',
      'afternoon',
      'rest',
      'personalDay',
      'vacation',
    ],
    Profession.commerce => const [
      'morning',
      'afternoon',
      'rest',
      'vacation',
      'personalDay',
    ],
    Profession.transport => const [
      'morning',
      'afternoon',
      'night',
      'rest',
      'vacation',
      'personalDay',
    ],
    Profession.other => const [],
  };

  /// Catalogue presets (`patternPresets` ids) typical of this job, first
  /// the likeliest. The rest of the catalogue is offered below them.
  List<String> get presetIds => switch (this) {
    Profession.nursing => const ['12h', 'correturnos', 'continental', '5x2'],
    Profession.medicine => const ['5x2', '24x72', '12h'],
    Profession.police => const [
      'pn-2-2-2-6',
      '6x4',
      '4x4',
      'correturnos',
      '5x2',
    ],
    Profession.firefighters => const ['24x72', 'guard-1-4', '4x4', '6x4'],
    Profession.industry => const [
      'correturnos',
      'continental',
      'dupont',
      '5x2',
    ],
    Profession.security => const ['2-2-3', '12h', '4x4', '6x4'],
    Profession.hospitality => const ['5x2', '6x4', 'correturnos'],
    Profession.commerce => const ['5x2', '6x4'],
    Profession.transport => const ['6x4', '4x4', 'continental', '5x2'],
    Profession.other => const [],
  };
}

/// The professions of step 1 in Spain, in order: those of the Spanish sector.
const List<Profession> spainProfessions = [
  Profession.nursing,
  Profession.medicine,
  Profession.police,
  Profession.firefighters,
  Profession.industry,
  Profession.security,
  Profession.hospitality,
  Profession.other,
];

/// The professions of step 1 anywhere else, in order: neutral names, no
/// Guardia Civil, TCAE or medicine on its own (it is part of health care).
const List<Profession> neutralProfessions = [
  Profession.nursing,
  Profession.security,
  Profession.police,
  Profession.firefighters,
  Profession.industry,
  Profession.hospitality,
  Profession.commerce,
  Profession.transport,
  Profession.other,
];

/// What step 1 offers to someone working in [countryCode].
List<Profession> professionsFor(String countryCode) =>
    countryCode == spainCountryCode ? spainProfessions : neutralProfessions;

/// [profession] in the list of [countryCode]: itself when that list has it,
/// otherwise the closest one there (medicine is health care abroad; commerce
/// is «Hostelería y comercio» in Spain; transport is «Otro»). Used when the
/// country changes after step 1.
Profession professionForCountry(Profession profession, String countryCode) {
  if (professionsFor(countryCode).contains(profession)) return profession;
  return switch (profession) {
    Profession.medicine => Profession.nursing,
    Profession.commerce => Profession.hospitality,
    _ => Profession.other,
  };
}

/// A shift type of the standard palette (by template key) and the hours a
/// profession works on it. [endHour] 0 is midnight.
class ProfessionHours {
  const ProfessionHours(this.key, this.startHour, this.endHour);

  final String key;
  final int startHour;
  final int endHour;

  int get startMinute => startHour * 60;
  int get endMinute => endHour * 60;
}

/// The shift types of [schedule] that [profession] changes, already changed.
///
/// Only touches types that still have the hours of the standard palette: one
/// the user has edited (or deleted) is left alone. Never adds a type, so the
/// palette never gets duplicates.
List<ShiftType> professionShiftTypes(Schedule schedule, Profession profession) {
  final changed = <ShiftType>[];
  for (final hours in profession.hours) {
    final type = schedule.shiftTypeById(hours.key);
    if (type == null) continue;
    final template = shiftTemplateByKey(hours.key);
    final pristine =
        type.startMinute == template.startMinute &&
        type.endMinute == template.endMinute;
    if (!pristine) continue;
    changed.add(
      type.copyWith(startMinute: hours.startMinute, endMinute: hours.endMinute),
    );
  }
  return changed;
}

/// [schedule] as it will be once the wizard finishes for [profession]: the
/// shift types the job changes, already changed.
///
/// The wizard previews (what "that day" gives in step 4, the summary) read
/// this schedule and `finish` writes [professionShiftTypes], so the hours the
/// person sees are the ones the calendar gets. [profession] `null` leaves it
/// as is.
Schedule scheduleWithProfession(Schedule schedule, Profession? profession) {
  if (profession == null) return schedule;
  final changed = {
    for (final t in professionShiftTypes(schedule, profession)) t.id: t,
  };
  if (changed.isEmpty) return schedule;
  return schedule.copyWith(
    shiftTypes: [for (final t in schedule.shiftTypes) changed[t.id] ?? t],
  );
}

/// [palette] ids with [profession]'s first ("paletteFirst" that exist), then
/// every other one in its current order. Same ids, no duplicates.
List<String> professionPaletteOrder(
  List<ShiftType> palette,
  Profession profession,
) {
  final ids = [for (final t in palette) t.id];
  final first = [
    for (final id in profession.paletteFirst)
      if (ids.contains(id)) id,
  ];
  return [
    ...first,
    for (final id in ids)
      if (!first.contains(id)) id,
  ];
}
