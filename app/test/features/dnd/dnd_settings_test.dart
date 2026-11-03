import 'package:cuadrante/features/dnd/domain/dnd_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the defaults', () {
    test('are everything off', () {
      const settings = DndSettings.disabled;
      expect(settings.enabled, isFalse);
      expect(settings.filter, DndFilter.priority);
      expect(settings.byShiftType, isEmpty);
      expect(settings.anyActive, isFalse);
      expect(settings.forShiftType('night').enabled, isFalse);
      expect(settings.isEnabledFor('night'), isFalse);
    });

    test('the global switch is needed for a type to silence the phone', () {
      const settings = DndSettings(
        byShiftType: {'night': DndTypeSettings(enabled: true)},
      );
      expect(settings.anyActive, isFalse);
      expect(settings.isEnabledFor('night'), isFalse);
      expect(settings.copyWith(enabled: true).isEnabledFor('night'), isTrue);
      expect(settings.copyWith(enabled: true).anyActive, isTrue);
    });
  });

  group('the JSON', () {
    test('goes in and comes out the same', () {
      const settings = DndSettings(
        enabled: true,
        filter: DndFilter.none,
        byShiftType: {
          'night': DndTypeSettings(enabled: true),
          'morning': DndTypeSettings(enabled: false),
        },
      );
      final json = settings.toJson();
      expect(json['version'], DndSettings.jsonVersion);
      expect(DndSettings.fromJson(json), settings);
    });

    test('a stored filter we do not know reads as "priority"', () {
      final settings = DndSettings.fromJson({
        'enabled': true,
        'filter': 'silence',
      });
      expect(settings.filter, DndFilter.priority);
      expect(settings.enabled, isTrue);
    });

    test('malformed parts fall back to the defaults', () {
      final settings = DndSettings.fromJson({
        'enabled': 'yes',
        'filter': 42,
        'types': 'night',
      });
      expect(settings.enabled, isFalse);
      expect(settings.filter, DndFilter.priority);
      expect(settings.byShiftType, isEmpty);
    });

    test('a type that is not an object is skipped', () {
      final settings = DndSettings.fromJson({
        'enabled': true,
        'types': {'night': true, 'morning': {'enabled': true}},
      });
      expect(settings.byShiftType.keys, ['morning']);
      expect(settings.forShiftType('morning').enabled, isTrue);
    });

    test('a type whose "enabled" is not true reads as off', () {
      final settings = DndSettings.fromJson({
        'enabled': true,
        'types': {'night': {'enabled': 'yes'}},
      });
      expect(settings.forShiftType('night').enabled, isFalse);
    });
  });

  group('the version', () {
    test('a value without a version is read as the current one', () {
      final settings = DndSettings.fromJson({
        'enabled': true,
        'types': {'night': {'enabled': true}},
      });
      expect(settings.enabled, isTrue);
      expect(settings.forShiftType('night').enabled, isTrue);
    });

    test('a version we do not know reads as nothing configured', () {
      // The phone is never silenced because of a value we do not understand.
      final settings = DndSettings.fromJson({
        'version': 0,
        'enabled': true,
        'filter': 'none',
        'types': {'night': {'enabled': true}},
      });
      expect(settings.enabled, isFalse);
      expect(settings.filter, DndFilter.priority);
      expect(settings.byShiftType, isEmpty);
      expect(settings.anyActive, isFalse);
    });

    test('a newer version is read with the parts we know', () {
      final settings = DndSettings.fromJson({
        'version': 99,
        'enabled': true,
        'filter': 'alarms',
        'types': {'night': {'enabled': true}},
        'somethingElse': true,
      });
      expect(settings.enabled, isTrue);
      expect(settings.filter, DndFilter.alarms);
      expect(settings.forShiftType('night').enabled, isTrue);
    });
  });

  group('the value', () {
    test('is equal to another with the same contents', () {
      const a = DndSettings(
        enabled: true,
        filter: DndFilter.none,
        byShiftType: {'night': DndTypeSettings(enabled: true)},
      );
      const b = DndSettings(
        enabled: true,
        filter: DndFilter.none,
        byShiftType: {'night': DndTypeSettings(enabled: true)},
      );
      const c = DndSettings(
        enabled: true,
        filter: DndFilter.priority,
        byShiftType: {'night': DndTypeSettings(enabled: true)},
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    test('replaces the choices of one type', () {
      const settings = DndSettings(enabled: true);
      final next = settings.withShiftType(
        'night',
        const DndTypeSettings(enabled: true),
      );
      expect(next.forShiftType('night').enabled, isTrue);
      expect(settings.forShiftType('night').enabled, isFalse);
    });
  });
}
