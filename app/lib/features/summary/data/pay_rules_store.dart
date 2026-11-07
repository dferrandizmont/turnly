import 'dart:convert';

import '../../../core/database/app_database.dart';
import '../domain/overtime_cap.dart';
import '../domain/pay_period.dart';

/// The payroll rules of the summary (propuesta 8): the closing day of the
/// month and the cap of the overtime.
class PayRules {
  const PayRules({this.closingDay, this.overtimeCap});

  static const none = PayRules();

  /// The last day of the payroll month (1-30); `null` = the calendar month.
  final int? closingDay;

  /// The cap of the overtime; `null` = none.
  final OvertimeCap? overtimeCap;

  @override
  bool operator ==(Object other) =>
      other is PayRules &&
      other.closingDay == closingDay &&
      other.overtimeCap == overtimeCap;

  @override
  int get hashCode => Object.hash(closingDay, overtimeCap);

  @override
  String toString() => 'PayRules(closing $closingDay, $overtimeCap)';
}

/// Keeps the [PayRules] as two JSON rows of the `settings` table:
/// `summary.closingDay` = `20` and `summary.overtimeCap` =
/// `{"period": "year", "hours": 80}`. That table travels in the backup whole
/// (`docs/copia-de-seguridad.md`), so both come back with a restore. A row
/// that is missing, unreadable or out of range is «none»: a bad value never
/// blocks the summary.
class PayRulesStore {
  PayRulesStore(this._db);

  static const closingDayKey = 'summary.closingDay';
  static const overtimeCapKey = 'summary.overtimeCap';

  final AppDatabase _db;

  Future<PayRules> load() async {
    final rows = await (_db.select(
      _db.settings,
    )..where((s) => s.key.isIn([closingDayKey, overtimeCapKey]))).get();
    final values = {for (final row in rows) row.key: _decode(row.value)};
    final closing = values[closingDayKey];
    return PayRules(
      closingDay: closing is int && isValidClosingDay(closing) ? closing : null,
      overtimeCap: OvertimeCap.fromJson(values[overtimeCapKey]),
    );
  }

  /// Sets the closing day (`null` = the calendar month). Throws
  /// [ArgumentError] for a day outside 1-30.
  Future<void> setClosingDay(int? day) async {
    if (day == null) return _delete(closingDayKey);
    if (!isValidClosingDay(day)) {
      throw ArgumentError.value(day, 'day', 'must be between 1 and 30');
    }
    await _write(closingDayKey, day);
  }

  /// Sets the cap of the overtime (`null` removes it). Throws [ArgumentError]
  /// for a cap out of range.
  Future<void> setOvertimeCap(OvertimeCap? cap) async {
    if (cap == null) return _delete(overtimeCapKey);
    if (!cap.isValid) throw ArgumentError.value(cap, 'cap', 'out of range');
    await _write(overtimeCapKey, cap.toJson());
  }

  Object? _decode(String raw) {
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  Future<void> _write(String key, Object value) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(key: key, value: jsonEncode(value)),
      );

  Future<void> _delete(String key) =>
      (_db.delete(_db.settings)..where((s) => s.key.equals(key))).go();
}
