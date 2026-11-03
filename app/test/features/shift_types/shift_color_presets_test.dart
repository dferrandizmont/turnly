import 'dart:ui' show Brightness;

import 'package:cuadrante/core/theme/shift_palette.dart';
import 'package:cuadrante/core/theme/shift_swatch.dart';
import 'package:cuadrante/features/schedule/domain/shift_type.dart';
import 'package:cuadrante/features/shift_types/domain/shift_color_presets.dart';
import 'package:flutter_test/flutter_test.dart';

/// «Paletas preparadas» (UX · Extras visuales, docs/ola3-pantallas.md): a
/// prepared set gives one colour to every default role of the specification,
/// never touches a colour the person chose or «Libre», and every colour it
/// offers keeps the code readable (AA on the cell tint and the disc) in both
/// themes.
ShiftType _type(
  String id,
  int colorValue, {
  ShiftCategory category = ShiftCategory.work,
}) => ShiftType(
  id: id,
  code: 'A',
  name: id,
  colorValue: colorValue,
  category: category,
);

void main() {
  test('five prepared sets, one colour per default role, unique ids', () {
    expect(shiftColorPresets, hasLength(5));
    final ids = shiftColorPresets.map((p) => p.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
    expect(ids, containsAll(['sunset', 'sea', 'forest', 'candy', 'nocturnal']));
    for (final preset in shiftColorPresets) {
      expect(
        preset.colors,
        hasLength(ShiftPalette.defaults.length),
        reason: preset.id,
      );
    }
    expect(shiftColorPresetById('sunset')?.id, 'sunset');
    expect(shiftColorPresetById('nope'), isNull);
  });

  test('a default role takes the colour the set gives it', () {
    for (final preset in shiftColorPresets) {
      for (var i = 0; i < ShiftPalette.defaults.length; i++) {
        final type = _type('role$i', ShiftPalette.defaults[i].toARGB32());
        final next = withPresetColor(preset, type);
        final wanted = preset.colors[i].toARGB32();
        if (wanted == type.colorValue) {
          expect(next, isNull, reason: '${preset.id}[$i] equals the default');
        } else {
          expect(next?.colorValue, wanted, reason: '${preset.id}[$i]');
        }
      }
    }
  });

  test('a custom colour and «Libre» are never touched', () {
    final preset = shiftColorPresetById('sea')!;
    final custom = _type('custom', 0xFF123456);
    expect(withPresetColor(preset, custom), isNull);

    final rest = _type(
      'rest',
      ShiftPalette.rest.toARGB32(),
      category: ShiftCategory.rest,
    );
    expect(withPresetColor(preset, rest), isNull);

    // Applying keeps the order and leaves the untouched ones as they were.
    final types = [
      custom,
      _type('morning', ShiftPalette.morning.toARGB32()),
      rest,
    ];
    final applied = applyShiftColorPreset(preset, types);
    expect(applied, hasLength(types.length));
    expect(applied[0], custom);
    expect(applied[1].colorValue, preset.colors[0].toARGB32());
    expect(applied[2], rest);
  });

  group('contrast', () {
    for (final preset in shiftColorPresets) {
      for (final brightness in Brightness.values) {
        final target = brightness == Brightness.dark
            ? kDarkInkContrast
            : kTextContrast;
        test('${preset.id} in ${brightness.name}: ink >= $target', () {
          for (final color in preset.colors) {
            final swatch = ShiftSwatch.forColor(color.toARGB32(), brightness);
            final hex = color.toARGB32().toRadixString(16);
            expect(
              contrastRatio(swatch.ink, swatch.tint),
              greaterThanOrEqualTo(target),
              reason: '${preset.id} $hex on the tint',
            );
            expect(
              contrastRatio(swatch.ink, swatch.disc),
              greaterThanOrEqualTo(target),
              reason: '${preset.id} $hex on the disc',
            );
          }
        });
      }
    }
  });
}
