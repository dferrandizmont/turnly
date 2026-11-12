import '../../schedule/domain/schedule_domain.dart';

/// Who a ready-made pattern is for: the sections of step 1 of the wizard.
enum PatternGroup { health, police, firefighters, industry, security }

/// Each preset under ONE group, so a card appears once. Order = display
/// order. (A preset not listed here still shows, under "Otros".)
const Map<PatternGroup, List<String>> patternGroupPresets = {
  PatternGroup.health: ['12h'],
  PatternGroup.police: ['pn-2-2-2-6', '6x4', '4x4'],
  PatternGroup.firefighters: ['24x72', 'guard-1-4'],
  PatternGroup.industry: ['correturnos', 'continental', 'dupont', '5x2'],
  PatternGroup.security: ['2-2-3', '2x2', '3x1'],
};

/// Presets that belong to no group of [patternGroupPresets].
List<PatternPreset> ungroupedPresets() {
  final grouped = {for (final ids in patternGroupPresets.values) ...ids};
  return [
    for (final p in patternPresets)
      if (!grouped.contains(p.id)) p,
  ];
}

/// The shift type to draw for [id]: the stored one, or the template of the
/// same key (a pattern from the catalogue whose type is not created yet).
ShiftType? shiftTypeForDisplay(Schedule schedule, String id) {
  final stored = schedule.shiftTypeById(id);
  if (stored != null) return stored;
  for (final t in shiftTemplates) {
    if (t.key == id) return t.toShiftType(id);
  }
  return null;
}

/// [type] with its name and code in the app's language when [type] is one of
/// the factory templates, and untouched otherwise. Everything else (hours,
/// colour, the job's adjustments) is kept.
///
/// While the first-use flow is open the seeded catalogue has not been
/// finalized yet: it was written when the database was created, possibly in
/// the phone's language, while the person may have chosen another on the very
/// first screen. Showing a factory type through here talks the app's language
/// without touching the stored data.
///
/// The criterion is the id alone: any type whose id is a template key is
/// shown with the factory texts, and a type with any other id (one the person
/// made or imported) is left alone. This is only the name used to draw it: the
/// stored rows are never touched here, and the real rename at the end of the
/// flow (`finalizeFactoryCatalog`) skips a catalogue the person has edited.
ShiftType factoryTextsShiftType(ShiftType type) {
  final texts = catalogTexts.templates[type.id];
  return texts == null
      ? type
      : type.copyWith(name: texts.name, code: texts.code);
}

/// [shiftTypeForDisplay], with a factory type talking the app's language
/// during the first-use flow (see [factoryTextsShiftType]).
ShiftType? shiftTypeForFirstUse(Schedule schedule, String id) {
  final type = shiftTypeForDisplay(schedule, id);
  return type == null ? null : factoryTextsShiftType(type);
}

/// Whether the first day of [steps] includes shift type [shiftTypeId].
bool startsWithShift(List<List<String>> steps, String shiftTypeId) =>
    steps.isNotEmpty && steps.first.contains(shiftTypeId);

/// Whether any day of [steps] includes shift type [shiftTypeId].
bool containsShift(List<List<String>> steps, String shiftTypeId) =>
    steps.any((step) => step.contains(shiftTypeId));

/// Pattern of the catalogue [preset], as stored when it already exists in
/// [schedule] (the same id) and built from its template keys otherwise. A
/// preset with a chosen work shift gets one deterministic id per shift
/// (`2x2-night`), so applying it again reuses the stored pattern.
Pattern presetPattern(
  Schedule schedule,
  PatternPreset preset, {
  String? workShiftId,
}) {
  if (preset.chooseWorkShift && workShiftId != null) {
    final id = '${preset.id}-$workShiftId';
    final stored = schedule.patternById(id);
    if (stored != null) return stored;
    final shift = shiftTypeForDisplay(schedule, workShiftId)?.name;
    return preset.materialize(
      {
        for (final k in preset.templateKeys)
          k: k == 'morning' ? workShiftId : k,
      },
      id: id,
      name: '${preset.name} · ${shift ?? workShiftId}',
    );
  }
  return schedule.patternById(preset.id) ??
      preset.materialize({for (final k in preset.templateKeys) k: k});
}

/// Ids of the catalogue patterns (a stored pattern with one of these ids is
/// not "custom").
Set<String> get presetPatternIds => {for (final p in patternPresets) p.id};

/// Whether [id] is a catalogue pattern: a preset's own id or the id of one
/// of its work-shift variants (`2x2-night`).
bool isCatalogPatternId(String id) =>
    presetPatternIds.contains(id) ||
    patternPresets.any((p) => p.chooseWorkShift && id.startsWith('${p.id}-'));

/// Name of [pattern] to show: a catalogue variant is named from the preset
/// and the shift in the app's current language; any other keeps its name.
String patternDisplayName(Schedule schedule, Pattern pattern) {
  for (final p in patternPresets) {
    if (!p.chooseWorkShift) continue;
    final prefix = '${p.id}-';
    if (!pattern.id.startsWith(prefix)) continue;
    final shiftId = pattern.id.substring(prefix.length);
    final shift = shiftTypeForDisplay(schedule, shiftId)?.name;
    if (shift != null) return '${p.name} · $shift';
  }
  return pattern.name;
}
