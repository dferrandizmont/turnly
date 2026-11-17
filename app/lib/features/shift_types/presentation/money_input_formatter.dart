import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../../schedule/domain/shift_type.dart' show maxHourlyRateCents;

/// Keeps an amount field to what `parseMoneyCents` accepts while it is typed:
/// digits and one decimal separator (a comma or a point, none when the
/// currency has no decimals), no leading zeros («0» then «9» is «9», not
/// «09»), as many digits before the separator as the highest amount has
/// (`maxHourlyRateCents`: 9999,99 has four, 999 999 in a currency without
/// decimals six) and [decimals] after it.
///
/// An edit that would break those rules is **refused** (the field keeps its
/// text and its caret), never trimmed: cutting digits off would change the
/// amount without the person noticing. The only changes made to an edit are
/// the ones that keep the same amount: dropping leading zeros and writing the
/// «0» before a bare separator; the caret and the selection move with them.
///
/// A paste may also carry grouping marks («1.234,56», «1,234.56», «1 234»):
/// it is read when the marks are unambiguous and refused otherwise.
class MoneyInputFormatter extends TextInputFormatter {
  const MoneyInputFormatter({this.decimals = 2, this.onAtLimit});

  final int decimals;

  /// Called when an edit that only adds digits (or the separator) is refused
  /// because the amount is already as long as it can be, so the screen can
  /// say so instead of leaving the keys looking dead (1.2.0 QA, iPhone F5).
  final VoidCallback? onAtLimit;

  /// The digits before the separator the highest amount has.
  int get maxIntegerDigits =>
      '${maxHourlyRateCents ~/ math.pow(10, decimals).toInt()}'.length;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final typed = _normalized(newValue);
    if (typed != null) return typed;
    final replaced = oldValue.selection.isValid
        ? oldValue.selection.end - oldValue.selection.start
        : 0;
    final inserted = newValue.text.length - (oldValue.text.length - replaced);
    if (inserted > 1) {
      final pasted = _pasted(newValue.text);
      if (pasted != null) {
        return TextEditingValue(
          text: pasted,
          selection: TextSelection.collapsed(offset: pasted.length),
        );
      }
    }
    if (newValue.text.length > oldValue.text.length &&
        RegExp(r'^[0-9]*[.,]?[0-9]*$').hasMatch(newValue.text)) {
      onAtLimit?.call();
    }
    return oldValue;
  }

  /// [value] with the zeros that change nothing taken out (and the «0» before
  /// a bare separator put in), the selection following; `null` when it breaks
  /// a rule.
  TextEditingValue? _normalized(TextEditingValue value) {
    final text = value.text;
    var separator = -1;
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (char.codeUnitAt(0) >= 0x30 && char.codeUnitAt(0) <= 0x39) continue;
      if ((char == ',' || char == '.') && separator < 0 && decimals > 0) {
        separator = i;
        continue;
      }
      return null;
    }
    final integer = separator < 0 ? text : text.substring(0, separator);
    final fraction = separator < 0 ? '' : text.substring(separator + 1);
    if (fraction.length > decimals) return null;
    var zeros = 0;
    while (zeros < integer.length - 1 && integer[zeros] == '0') {
      zeros++;
    }
    final whole = integer.substring(zeros);
    if (whole.length > maxIntegerDigits) return null;
    final lead = integer.isEmpty && separator >= 0 ? 1 : 0;
    final out =
        '${lead == 1 ? '0' : ''}$whole'
        '${separator < 0 ? '' : text.substring(separator)}';
    if (out == text) return value;

    int move(int offset) =>
        offset < 0 ? offset : offset - (offset < zeros ? offset : zeros) + lead;
    final selection = value.selection;
    return TextEditingValue(
      text: out,
      selection: selection.isValid
          ? selection.copyWith(
              baseOffset: move(selection.baseOffset),
              extentOffset: move(selection.extentOffset),
            )
          : selection,
    );
  }

  /// The amount in [raw] pasted from somewhere else, written as the field
  /// takes it, or `null` when it cannot be read without guessing.
  ///
  /// A mark followed by exactly three digits and then nothing is a grouping
  /// mark when the currency has fewer decimals («1.234» is 1234), the decimal
  /// mark otherwise; with both marks the last one is the decimal one.
  String? _pasted(String raw) {
    final s = raw.replaceAll(RegExp(r"[\s  '’]"), '');
    if (s.isEmpty || !RegExp(r'^[0-9.,]+$').hasMatch(s)) return null;
    final last = math.max(s.lastIndexOf('.'), s.lastIndexOf(','));
    String whole;
    var decimal = '';
    if (last < 0) {
      whole = s;
    } else {
      final mark = s[last];
      final other = mark == '.' ? ',' : '.';
      final before = s.substring(0, last);
      final after = s.substring(last + 1);
      final hasBoth = s.contains(other);
      final marksBefore = mark.allMatches(before).length;
      final asDecimal =
          decimals > 0 &&
          marksBefore == 0 &&
          after.isNotEmpty &&
          after.length <= decimals &&
          (hasBoth || !_isGrouped(s, mark));
      if (asDecimal) {
        // «1.234,56»: the other mark, if any, only groups the whole part.
        final grouped = hasBoth ? _ungroup(before, other) : before;
        if (grouped == null) return null;
        whole = grouped;
        decimal = '$mark$after';
      } else {
        // Only grouping marks, all of the same kind.
        if (hasBoth) return null;
        final grouped = _ungroup(s, mark);
        if (grouped == null) return null;
        whole = grouped;
      }
    }
    final result = _normalized(TextEditingValue(text: '$whole$decimal'));
    return result?.text;
  }

  /// Whether [s] reads as an amount grouped with [mark]: «1.234», «12.345.678».
  static bool _isGrouped(String s, String mark) => _ungroup(s, mark) != null;

  /// [s] without the grouping [mark]s, or `null` when the groups are not the
  /// usual ones (one to three digits, then groups of exactly three; no
  /// leading zero) or there is no mark at all.
  static String? _ungroup(String s, String mark) {
    if (!s.contains(mark)) return s.isEmpty ? null : s;
    final parts = s.split(mark);
    final first = parts.first;
    if (first.isEmpty || first.length > 3 || first.startsWith('0')) return null;
    for (final part in parts.skip(1)) {
      if (part.length != 3) return null;
    }
    return parts.join();
  }
}
