import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/shift_types/domain/shift_type_draft.dart';
import 'package:flutter_test/flutter_test.dart';

const _morning = ShiftType(
  id: 'morning',
  code: 'M',
  name: 'Mañana',
  colorValue: 0xFFF5A524,
  category: ShiftCategory.work,
  startMinute: 360,
  endMinute: 840,
);

/// No lone surrogate: every high half is followed by its low half.
bool _wellFormed(String text) {
  final units = text.codeUnits;
  for (var i = 0; i < units.length; i++) {
    final u = units[i];
    if (u >= 0xD800 && u <= 0xDBFF) {
      if (i + 1 >= units.length ||
          units[i + 1] < 0xDC00 ||
          units[i + 1] > 0xDFFF) {
        return false;
      }
      i++;
    } else if (u >= 0xDC00 && u <= 0xDFFF) {
      return false;
    }
  }
  return true;
}

void main() {
  group('parseMoneyCents', () {
    test('accepts comma and dot decimals and whole euros', () {
      expect(parseMoneyCents('12,50'), 1250);
      expect(parseMoneyCents('12.50'), 1250);
      expect(parseMoneyCents('12,5'), 1250);
      expect(parseMoneyCents('12'), 1200);
      expect(parseMoneyCents('0,05'), 5);
      expect(parseMoneyCents('  7,25 '), 725);
      expect(parseMoneyCents('9999,99'), 999999);
    });

    test('a blank text is no rate', () {
      expect(parseMoneyCents(''), isNull);
      expect(parseMoneyCents('   '), isNull);
    });

    test('rejects what is not an amount', () {
      for (final bad in [
        'abc',
        '12,555',
        '-3',
        '1,2,3',
        ',50',
        '12,',
        '1e3',
        '10000',
        '12 €',
      ]) {
        expect(() => parseMoneyCents(bad), throwsFormatException, reason: bad);
      }
    });

    test('no floating point rounding: 0,29 is 29 cents', () {
      expect(parseMoneyCents('0,29'), 29);
      expect(parseMoneyCents('1,15'), 115);
      expect(parseMoneyCents('4,35'), 435);
    });
  });

  group('money with the decimals of the currency', () {
    test('2 decimals is the default', () {
      expect(parseMoneyCents('12,5', decimals: 2), 1250);
      expect(
        () => parseMoneyCents('12,555', decimals: 2),
        throwsFormatException,
      );
    });

    test('0 decimals (yen, won): whole units, no decimal part', () {
      expect(parseMoneyCents('1500', decimals: 0), 1500);
      expect(parseMoneyCents(' 999999 ', decimals: 0), 999999);
      expect(parseMoneyCents('0', decimals: 0), 0);
      for (final bad in ['15,5', '15.5', '15,', '1000000', '-1', 'x']) {
        expect(
          () => parseMoneyCents(bad, decimals: 0),
          throwsFormatException,
          reason: bad,
        );
      }
      expect(parseMoneyCents('', decimals: 0), isNull);
    });

    test('3 decimals (dinar): thousandths', () {
      expect(parseMoneyCents('12,345', decimals: 3), 12345);
      expect(parseMoneyCents('12,5', decimals: 3), 12500);
      expect(parseMoneyCents('12', decimals: 3), 12000);
      expect(parseMoneyCents('0,001', decimals: 3), 1);
      expect(parseMoneyCents('999,999', decimals: 3), 999999);
      expect(
        () => parseMoneyCents('12,3456', decimals: 3),
        throwsFormatException,
      );
      expect(() => parseMoneyCents('1000', decimals: 3), throwsFormatException);
    });

    test('formatCentsInput is the inverse for every number of decimals', () {
      for (final decimals in [0, 2, 3]) {
        for (final cents in [0, 1, 99, 100, 101, 1250, 12345, 999999]) {
          expect(
            parseMoneyCents(
              formatCentsInput(cents, decimals: decimals),
              decimals: decimals,
            ),
            cents,
            reason: '$cents with $decimals decimals',
          );
        }
      }
      expect(formatCentsInput(1500, decimals: 0), '1500');
      expect(formatCentsInput(12500, decimals: 3), '12,500');
      expect(formatCentsInput(12000, decimals: 3), '12');
    });

    test('the draft validates and converts with its decimals', () {
      const yen = ShiftTypeDraft(
        code: 'M',
        name: 'Mañana',
        rateText: '1500',
        fixedPlusText: '2000',
        moneyDecimals: 0,
      );
      expect(yen.validate(), isEmpty);
      final type = yen.toShiftType('m');
      expect(type.hourlyRateCents, 1500);
      expect(type.fixedPlusCents, 2000);

      const decimalInYen = ShiftTypeDraft(
        code: 'M',
        name: 'Mañana',
        rateText: '15,5',
        moneyDecimals: 0,
      );
      expect(decimalInYen.validate().keys, contains(ShiftTypeField.rate));

      const dinar = ShiftTypeDraft(
        code: 'M',
        name: 'Mañana',
        rateText: '3,125',
        moneyDecimals: 3,
      );
      expect(dinar.validate(), isEmpty);
      expect(dinar.toShiftType('m').hourlyRateCents, 3125);
    });

    test('a stored amount is shown with the decimals of the currency', () {
      final stored = _morning.copyWith(
        hourlyRateCents: 1250,
        fixedPlusCents: 3000,
      );
      final euro = ShiftTypeDraft.fromShiftType(stored);
      expect(euro.rateText, '12,50');
      expect(euro.fixedPlusText, '30');
      final yen = ShiftTypeDraft.fromShiftType(stored, moneyDecimals: 0);
      expect(yen.rateText, '1250');
      expect(yen.fixedPlusText, '3000');
      expect(yen.moneyDecimals, 0);
      // Round trip: nothing changes by opening and saving.
      expect(yen.toShiftType(stored.id).hourlyRateCents, 1250);
      expect(euro.toShiftType(stored.id).hourlyRateCents, 1250);
    });

    test('the decimals take part in the equality of drafts', () {
      const a = ShiftTypeDraft(rateText: '12');
      expect(a == a.copyWith(moneyDecimals: 0), isFalse);
      expect(a.copyWith(moneyDecimals: 0).moneyDecimals, 0);
      expect(a.copyWith(code: 'X').moneyDecimals, 2);
    });
  });

  test('formatCentsInput is the inverse of parseMoneyCents', () {
    expect(formatCentsInput(1250), '12,50');
    expect(formatCentsInput(1200), '12');
    expect(formatCentsInput(5), '0,05');
    for (final cents in [0, 1, 99, 100, 101, 1250, 999999]) {
      expect(parseMoneyCents(formatCentsInput(cents)), cents);
    }
  });

  group('validate', () {
    ShiftTypeDraft valid() => const ShiftTypeDraft(code: 'X', name: 'Extra');

    test('a complete draft is valid', () {
      expect(valid().validate(), isEmpty);
    });

    test('code: required, and unique among the others (any case)', () {
      expect(
        valid().copyWith(code: ' ').validate()[ShiftTypeField.code]?.issue,
        ShiftTypeIssue.codeEmpty,
      );
      final taken = valid()
          .copyWith(code: 'm')
          .validate(others: const [_morning])[ShiftTypeField.code];
      expect(taken?.issue, ShiftTypeIssue.codeTaken);
      expect(taken?.other, 'Mañana');
      expect(
        valid().copyWith(code: 'MX').validate(others: const [_morning]),
        isEmpty,
      );
    });

    test('name is required', () {
      expect(
        valid().copyWith(name: '  ').validate()[ShiftTypeField.name]?.issue,
        ShiftTypeIssue.nameEmpty,
      );
    });

    test('the unpaid break must be shorter than the shift', () {
      // 08:00-16:00 = 480 min.
      Map<ShiftTypeField, ShiftTypeProblem> check(String text) =>
          valid().copyWith(unpaidBreakText: text).validate();
      expect(check('30'), isEmpty);
      expect(check('479'), isEmpty);
      expect(
        check('480')[ShiftTypeField.unpaidBreak]?.issue,
        ShiftTypeIssue.breakTooLong,
      );
      expect(check('abc'), contains(ShiftTypeField.unpaidBreak));
    });

    test('the rate must be an amount', () {
      expect(valid().copyWith(rateText: '12,50').validate(), isEmpty);
      expect(
        valid()
            .copyWith(rateText: 'doce')
            .validate()[ShiftTypeField.rate]
            ?.issue,
        ShiftTypeIssue.rateInvalid,
      );
    });

    test('pay fields are ignored when they do not apply', () {
      final rest = valid().copyWith(
        category: ShiftCategory.rest,
        rateText: 'doce',
        unpaidBreakText: '9999',
      );
      expect(rest.validate(), isEmpty);
      final noTimes = valid().copyWith(hasTimes: false, rateText: 'doce');
      expect(noTimes.validate(), isEmpty);
    });
  });

  group('times', () {
    test('08:00-08:00 is 24 hours and ends the next day', () {
      final draft = const ShiftTypeDraft().copyWith(
        startMinute: 480,
        endMinute: 480,
      );
      expect(draft.durationMinutes, 1440);
      expect(draft.isTwentyFourHours, isTrue);
      expect(draft.endsNextDay, isTrue);
    });

    test('22:00-06:00 crosses midnight: 8 hours', () {
      final draft = const ShiftTypeDraft().copyWith(
        startMinute: 22 * 60,
        endMinute: 6 * 60,
      );
      expect(draft.durationMinutes, 480);
      expect(draft.endsNextDay, isTrue);
      expect(draft.isTwentyFourHours, isFalse);
    });

    test('06:00-14:00 stays in the day', () {
      final draft = const ShiftTypeDraft().copyWith(
        startMinute: 360,
        endMinute: 840,
      );
      expect(draft.durationMinutes, 480);
      expect(draft.endsNextDay, isFalse);
    });

    test('without times there is no duration', () {
      expect(const ShiftTypeDraft(hasTimes: false).durationMinutes, 0);
    });
  });

  group('toShiftType', () {
    test('paid minutes = duration - unpaid break (null without break)', () {
      const night = ShiftTypeDraft(
        code: 'N',
        name: 'Noche',
        startMinute: 22 * 60,
        endMinute: 6 * 60,
        unpaidBreakText: '30',
        nightOverride: true,
        rateText: '12,50',
      );
      final type = night.toShiftType('night');
      expect(type.paidMinutes, 450);
      expect(type.effectivePaidMinutes, 450);
      expect(type.nightOverride, isTrue);
      expect(type.hourlyRateCents, 1250);
      expect(
        night.copyWith(unpaidBreakText: '').toShiftType('n').paidMinutes,
        isNull,
      );
      expect(
        night.copyWith(unpaidBreakText: '0').toShiftType('n').paidMinutes,
        isNull,
      );
    });

    test('a shift without times stores no times and no pay fields', () {
      final type = const ShiftTypeDraft(
        code: 'L',
        name: 'Libre',
        hasTimes: false,
        category: ShiftCategory.rest,
        nightOverride: true,
        rateText: '10',
        unpaidBreakText: '15',
      ).toShiftType('rest');
      expect(type.hasTimes, isFalse);
      expect(type.startMinute, isNull);
      expect(type.paidMinutes, isNull);
      expect(type.nightOverride, isNull);
      expect(type.hourlyRateCents, isNull);
    });

    test('a 24 h shift keeps 08:00-08:00', () {
      final type = const ShiftTypeDraft(
        code: 'G',
        name: 'Guardia',
        startMinute: 480,
        endMinute: 480,
      ).toShiftType('guard');
      expect(type.startMinute, 480);
      expect(type.endMinute, 480);
      expect(type.durationMinutes, 1440);
      expect(type.crossesMidnight, isTrue);
    });

    test('code and name are trimmed', () {
      final type = const ShiftTypeDraft(
        code: ' T ',
        name: ' Tarde ',
      ).toShiftType('t');
      expect(type.code, 'T');
      expect(type.name, 'Tarde');
    });

    test('fromShiftType -> toShiftType gives back the same shift', () {
      const original = ShiftType(
        id: 'night',
        code: 'N',
        name: 'Noche',
        colorValue: 0xFF4B4FD1,
        category: ShiftCategory.work,
        startMinute: 1320,
        endMinute: 360,
        paidMinutes: 450,
        nightOverride: false,
        hourlyRateCents: 1275,
      );
      final draft = ShiftTypeDraft.fromShiftType(original);
      expect(draft.unpaidBreakText, '30');
      expect(draft.rateText, '12,75');
      expect(draft.validate(), isEmpty);
      expect(draft.toShiftType('night'), original);
      expect(
        ShiftTypeDraft.fromShiftType(_morning).toShiftType('morning'),
        _morning,
      );
    });
  });

  group('suggestShiftCode', () {
    test('the first letter in capitals', () {
      expect(suggestShiftCode('mañana', const []), 'M');
      expect(suggestShiftCode('  tarde larga', const []), 'T');
    });

    test('grows to two or three letters while the code is taken', () {
      expect(suggestShiftCode('Mañana', ['m']), 'MA');
      expect(suggestShiftCode('Mañana', ['M', 'ma']), 'MAÑ');
      expect(suggestShiftCode('Mañana', ['M', 'MA', 'MAÑ']), 'M');
    });

    test('nothing to suggest without letters', () {
      expect(suggestShiftCode('', const []), '');
      expect(suggestShiftCode(' - ', const []), '');
    });

    test('never cuts a character made of two UTF-16 units in half', () {
      // Mathematical bold letters are letters outside the BMP.
      final suggestion = suggestShiftCode('𝐚𝐛𝐜', const []);
      expect(_wellFormed(suggestion), isTrue);
      expect(suggestion.runes.length, 1);
      expect(suggestion.length, lessThanOrEqualTo(maxShiftCodeLength));
      expect(
        suggestShiftCode('𝐚𝐛𝐜', [suggestion]).length,
        lessThanOrEqualTo(maxShiftCodeLength),
      );
    });
  });

  group('shift code length (UTF-16 units, as the engine and the backup '
      'count it)', () {
    ShiftTypeDraft draft(String code) =>
        ShiftTypeDraft(code: code, name: 'Extra');

    test('validate: more than three UTF-16 units is codeTooLong', () {
      for (final code in ['ABCD', '🙂🙂', ' ABCD ']) {
        expect(
          draft(code).validate()[ShiftTypeField.code]?.issue,
          ShiftTypeIssue.codeTooLong,
          reason: code,
        );
      }
      for (final code in ['A', 'AB+', '+/-', ' ABC ', '🙂']) {
        expect(draft(code).validate(), isEmpty, reason: code);
      }
    });

    test('fitShiftCode keeps whole characters within three units', () {
      expect(fitShiftCode('AB'), 'AB');
      expect(fitShiftCode(' ABCDE '), 'ABC');
      expect(fitShiftCode('🙂🙂'), '🙂');
      expect(fitShiftCode('A🙂🙂'), 'A🙂');
      expect(fitShiftCode('AB🙂'), 'AB');
      expect(fitShiftCode(''), '?');
      expect(fitShiftCode('   '), '?');
      expect(fitShiftCode('', fallback: 'X'), 'X');
      for (final code in ['🙂🙂🙂', 'AB🙂C', 'ÁÉÍÓ', '𝐚𝐛𝐜']) {
        final fitted = fitShiftCode(code);
        expect(fitted.length, lessThanOrEqualTo(maxShiftCodeLength));
        expect(_wellFormed(fitted), isTrue, reason: code);
      }
    });

    test('isShiftCodeChar: letters, digits and simple symbols only', () {
      for (final c in ['A', 'z', 'ñ', 'Á', '7', '+', '/', '-', '.', '*', '#']) {
        expect(isShiftCodeChar(c.runes.first), isTrue, reason: c);
      }
      for (final c in ['🙂', ' ', '\n', '\t', '€', '❤', '‍']) {
        expect(isShiftCodeChar(c.runes.first), isFalse, reason: c);
      }
    });

    test('sanitizeShiftCode filters and cuts what is typed or pasted', () {
      expect(sanitizeShiftCode('AB🙂C'), 'ABC');
      expect(sanitizeShiftCode('🙂🙂'), '');
      expect(sanitizeShiftCode('a b'), 'ab');
      expect(sanitizeShiftCode('ABCDE'), 'ABC');
      expect(sanitizeShiftCode('+/1x'), '+/1');
    });
  });
}
