import 'package:cuadrante/features/patterns/domain/pattern_catalog.dart';
import 'package:cuadrante/features/schedule/domain/presets.dart';
import 'package:cuadrante/features/schedule/domain/shift_type.dart';
import 'package:flutter_test/flutter_test.dart';

/// H-T02-1: while the first-use flow is open the seeded catalogue may talk the
/// phone's language; the screens must show it in the language the person
/// chose, without touching the stored data.
void main() {
  test(
    'factoryTextsShiftType talks the app language, only for factory types',
    () {
      final previous = catalogTexts;
      addTearDown(() => catalogTexts = previous);
      catalogTexts = const CatalogTexts(
        templates: {'morning': (name: 'Morning', code: 'AM')},
      );

      const factory = ShiftType(
        id: 'morning',
        code: 'M',
        name: 'Mañana',
        colorValue: 0xFF000000,
        category: ShiftCategory.work,
        startMinute: 6 * 60,
        endMinute: 14 * 60,
      );
      final shown = factoryTextsShiftType(factory);
      expect(shown.name, 'Morning');
      expect(shown.code, 'AM');
      // Everything else (the hours, the colour) is kept.
      expect(shown.startMinute, 6 * 60);
      expect(shown.endMinute, 14 * 60);
      expect(shown.colorValue, 0xFF000000);
      // The original is not changed: the stored data is the user's.
      expect(factory.name, 'Mañana');
      expect(factory.code, 'M');

      // A type the person made or imported is left alone: the criterion is the
      // id, not the text.
      final own = factory.copyWith(
        id: 'custom-1',
        name: 'Mi turno',
        code: 'MT',
      );
      expect(factoryTextsShiftType(own).name, 'Mi turno');
      expect(factoryTextsShiftType(own).code, 'MT');

      // A factory type whose text was changed (same template id) is still drawn
      // with the factory texts: the stored rows are never touched here, and the
      // real rename at the end of the flow skips an edited catalogue.
      final renamed = factory.copyWith(name: 'Mi mañana', code: 'MM');
      expect(factoryTextsShiftType(renamed).name, 'Morning');
      expect(factoryTextsShiftType(renamed).code, 'AM');
      expect(renamed.name, 'Mi mañana');
    },
  );
}
