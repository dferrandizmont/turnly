import 'package:flutter/painting.dart';

import '../../../core/theme/shift_palette.dart';
import '../../schedule/domain/shift_type.dart';

/// A prepared set of colours for the shift types (UX · Extras visuales): four
/// or five palettes the person applies at once, in one undoable step.
///
/// Each set gives one colour to every **default role** of the specification
/// ([ShiftPalette.defaults], in that order): a shift type whose stored colour
/// is a default one takes the colour the set gives that role, so "Mañana,
/// Tarde, Noche..." keep their meaning. A type with a custom colour of its own
/// keeps it, and "Libre" (special, no tint) is never touched.
///
/// Every colour of every set draws with an ink of at least 4.5:1 on its tint
/// and its disc in both themes ([ShiftSwatch] derives it; the contrast test
/// proves it).
class ShiftColorPreset {
  const ShiftColorPreset(this.id, this.colors);

  /// Stable id (also the suffix of its name in the ARB: `colorsPresetName`).
  final String id;

  /// One colour per default role, in the order of [ShiftPalette.defaults].
  final List<Color> colors;
}

/// The prepared sets, in display order.
const List<ShiftColorPreset> shiftColorPresets = [
  ShiftColorPreset('sunset', [
    Color(0xFFF7A072), // Mañana
    Color(0xFFE85D04), // Tarde
    Color(0xFF6A4C93), // Noche
    Color(0xFFD62828), // Guardia
    Color(0xFF9D4EDD), // Saliente
    Color(0xFF2A9D8F), // Vacaciones
    Color(0xFFE76F51), // Asuntos propios
  ]),
  ShiftColorPreset('sea', [
    Color(0xFF48CAE4),
    Color(0xFF0077B6),
    Color(0xFF023E8A),
    Color(0xFF0096C7),
    Color(0xFF5E60CE),
    Color(0xFF2A9D8F),
    Color(0xFF00B4D8),
  ]),
  ShiftColorPreset('forest', [
    Color(0xFFB5E48C),
    Color(0xFF52B788),
    Color(0xFF2D6A4F),
    Color(0xFFE76F51),
    Color(0xFF74C69D),
    Color(0xFF40916C),
    Color(0xFF95D5B2),
  ]),
  ShiftColorPreset('candy', [
    Color(0xFFFFB3C1),
    Color(0xFFFF8FAB),
    Color(0xFF9D4EDD),
    Color(0xFFFF4776),
    Color(0xFFB388FF),
    Color(0xFF64DFDF),
    Color(0xFFFAA6FF),
  ]),
  ShiftColorPreset('nocturnal', [
    Color(0xFF8E9AAF),
    Color(0xFF5C677D),
    Color(0xFF3A0CA3),
    Color(0xFF7209B7),
    Color(0xFF4361EE),
    Color(0xFF4CC9F0),
    Color(0xFF9D4EDD),
  ]),
];

/// The set whose id is [id], or `null` (a name read from outside the app).
ShiftColorPreset? shiftColorPresetById(String id) {
  for (final preset in shiftColorPresets) {
    if (preset.id == id) return preset;
  }
  return null;
}

/// [type] with the colour [preset] gives its role, or `null` when the type
/// must not change: its stored colour is not a default one (a custom colour of
/// its own) or the preset gives it the same colour it already has.
ShiftType? withPresetColor(ShiftColorPreset preset, ShiftType type) {
  final role = ShiftPalette.defaults.indexWhere(
    (c) => c.toARGB32() == type.colorValue,
  );
  if (role < 0) return null;
  final next = preset.colors[role].toARGB32();
  if (next == type.colorValue) return null;
  return type.copyWith(colorValue: next);
}

/// The types of [types] with the colours of [preset] applied, in the same
/// order; the ones it does not change are left as they are.
List<ShiftType> applyShiftColorPreset(
  ShiftColorPreset preset,
  Iterable<ShiftType> types,
) => [for (final type in types) withPresetColor(preset, type) ?? type];
