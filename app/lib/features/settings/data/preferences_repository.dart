import 'dart:convert';

import 'package:drift/drift.dart' show InsertMode;
import 'package:flutter/material.dart' show Locale, ThemeMode;

import '../../../core/database/app_database.dart';
import '../../../core/format/region_defaults.dart';
import '../domain/preferences.dart';

/// Reads and writes the [Preferences] as one JSON row each of the `settings`
/// table (`appearance.themeMode`, `calendar.weekStart`,
/// `calendar.weekNumbers`, `appearance.language`, `appearance.timeFormat`,
/// `appearance.currency`, `appearance.accent`, `appearance.cellTextSize`,
/// `summary.withholdingPercent`).
///
/// A row that is missing, is not JSON or holds a value the app does not offer
/// falls back to the default: a bad preference never blocks the app.
class PreferencesRepository {
  PreferencesRepository(this._db);

  final AppDatabase _db;

  Future<Preferences> load() async {
    final rows = await (_db.select(
      _db.settings,
    )..where((s) => s.key.isIn(_keys))).get();
    final values = {for (final row in rows) row.key: _decode(row.value)};
    const defaults = Preferences.defaults;
    final weekStart = values[PreferenceKeys.weekStart];
    final weekNumbers = values[PreferenceKeys.weekNumbers];
    final withholding = values[PreferenceKeys.withholdingPercent];
    return Preferences(
      themeMode: themeModeFromStored(values[PreferenceKeys.themeMode]),
      weekStart: weekStart is int && WeekStart.isValid(weekStart)
          ? weekStart
          : defaults.weekStart,
      weekNumbers: weekNumbers is bool ? weekNumbers : defaults.weekNumbers,
      language: AppLanguage.fromStored(values[PreferenceKeys.language]),
      timeFormat: TimeFormatPreference.fromStored(
        values[PreferenceKeys.timeFormat],
      ),
      currency: currencyFromStored(values[PreferenceKeys.currency]),
      accent: AppAccent.fromStored(values[PreferenceKeys.accent]),
      cellTextSize: CellTextSize.fromStored(
        values[PreferenceKeys.cellTextSize],
      ),
      withholdingPercent:
          withholding is int && isValidWithholdingPercent(withholding)
          ? withholding
          : defaults.withholdingPercent,
      showNoteInMonth: values[PreferenceKeys.showNoteInMonth] is bool
          ? values[PreferenceKeys.showNoteInMonth]! as bool
          : defaults.showNoteInMonth,
      paintSound: values[PreferenceKeys.paintSound] is bool
          ? values[PreferenceKeys.paintSound]! as bool
          : defaults.paintSound,
      calendarBackgroundPath:
          values[PreferenceKeys.calendarBackground] is String
          ? values[PreferenceKeys.calendarBackground]! as String
          : null,
    );
  }

  /// Gives a **new** installation the formats of the phone's region: the
  /// first day of the week and the currency of the region, and the clock
  /// following the phone. Only rows that do not exist yet are written, so a
  /// preference already stored (a restored backup, an earlier run) is never
  /// touched. Existing installations never call this: without a row they
  /// keep Monday, euros and the 24 h clock.
  Future<void> seedRegionDefaults(Iterable<Locale> phone) async {
    final region = regionOfPhone(phone);
    final rows = {
      PreferenceKeys.weekStart: weekStartForRegion(region),
      PreferenceKeys.timeFormat: TimeFormatPreference.auto.stored,
      PreferenceKeys.currency: currencyForRegion(region),
    };
    await _db.batch((b) {
      for (final row in rows.entries) {
        b.insert(
          _db.settings,
          SettingsCompanion.insert(key: row.key, value: jsonEncode(row.value)),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _write(PreferenceKeys.themeMode, themeModeToStored(mode));

  /// Throws [ArgumentError] unless [weekStart] is Monday (1) or Sunday (7).
  Future<void> setWeekStart(int weekStart) async {
    if (!WeekStart.isValid(weekStart)) {
      throw ArgumentError.value(weekStart, 'weekStart', 'must be 1 or 7');
    }
    await _write(PreferenceKeys.weekStart, weekStart);
  }

  Future<void> setWeekNumbers(bool show) =>
      _write(PreferenceKeys.weekNumbers, show);

  Future<void> setLanguage(AppLanguage language) =>
      _write(PreferenceKeys.language, language.stored);

  Future<void> setTimeFormat(TimeFormatPreference timeFormat) =>
      _write(PreferenceKeys.timeFormat, timeFormat.stored);

  /// Throws [ArgumentError] unless [currency] is an ISO 4217 code.
  Future<void> setCurrency(String currency) async {
    if (!isCurrencyCode(currency)) {
      throw ArgumentError.value(
        currency,
        'currency',
        'must be an ISO 4217 code',
      );
    }
    await _write(PreferenceKeys.currency, currency);
  }

  Future<void> setAccent(AppAccent accent) =>
      _write(PreferenceKeys.accent, accent.stored);

  Future<void> setCellTextSize(CellTextSize size) =>
      _write(PreferenceKeys.cellTextSize, size.stored);

  /// The percentage of the withholding of the estimated pay (P9). Throws
  /// [ArgumentError] unless it is a whole number between 0 and 100.
  Future<void> setWithholdingPercent(int percent) async {
    if (!isValidWithholdingPercent(percent)) {
      throw ArgumentError.value(
        percent,
        'withholdingPercent',
        'must be between 0 and 100',
      );
    }
    await _write(PreferenceKeys.withholdingPercent, percent);
  }

  /// Ajustes › Apariencia › «Ver la nota en el mes» (UX).
  Future<void> setShowNoteInMonth(bool show) =>
      _write(PreferenceKeys.showNoteInMonth, show);

  /// Ajustes › Apariencia › «Sonido al pintar» (UX).
  Future<void> setPaintSound(bool enabled) =>
      _write(PreferenceKeys.paintSound, enabled);

  /// Ajustes › Apariencia › «Imagen de fondo del calendario» (UX): the relative
  /// path of the file inside the app's background folder, or `null` to remove
  /// it. The file itself is managed by the calendar and neither the file nor
  /// the path travel in a backup (it is a device setting, `isDeviceSetting`).
  Future<void> setCalendarBackground(String? relativePath) async {
    if (relativePath == null) {
      await (_db.delete(
        _db.settings,
      )..where((s) => s.key.equals(PreferenceKeys.calendarBackground))).go();
      return;
    }
    await _write(PreferenceKeys.calendarBackground, relativePath);
  }

  static const _keys = [
    PreferenceKeys.themeMode,
    PreferenceKeys.weekStart,
    PreferenceKeys.weekNumbers,
    PreferenceKeys.language,
    PreferenceKeys.timeFormat,
    PreferenceKeys.currency,
    PreferenceKeys.accent,
    PreferenceKeys.cellTextSize,
    PreferenceKeys.withholdingPercent,
    PreferenceKeys.showNoteInMonth,
    PreferenceKeys.paintSound,
    PreferenceKeys.calendarBackground,
  ];

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
}
