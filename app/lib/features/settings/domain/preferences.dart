import 'package:flutter/material.dart' show Locale, ThemeMode;

import '../../../core/format/region_defaults.dart'
    show defaultCurrency, isCurrencyCode;
import '../../../core/theme/app_appearance.dart';

export '../../../core/theme/app_appearance.dart' show AppAccent, CellTextSize;

/// Keys of the `settings` table (JSON text values) for the preferences the
/// Settings screen edits (docs/datos.md, "Ajustes").
abstract final class PreferenceKeys {
  /// `"system"`, `"light"` or `"dark"`.
  static const themeMode = 'appearance.themeMode';

  /// `1` (Monday) or `7` (Sunday), like [DateTime.weekday].
  static const weekStart = 'calendar.weekStart';

  /// `true` once the person picked the first day of the week by hand (Ajustes
  /// › Apariencia). A missing marker next to a stored [weekStart] means it was
  /// chosen before this marker existed, so it is treated as a manual choice:
  /// picking a country never overwrites it.
  static const weekStartExplicit = 'calendar.weekStartExplicit';

  /// `true` shows the ISO week number at the left of every row of the month.
  static const weekNumbers = 'calendar.weekNumbers';

  /// `"system"` or a language code of [AppLanguage] (`"es"`, `"ca"`...).
  static const language = 'appearance.language';

  /// `"auto"`, `"24"` or `"12"` ([TimeFormatPreference]). A device setting:
  /// it never goes into a backup (see `isDeviceSetting`).
  static const timeFormat = 'appearance.timeFormat';

  /// An ISO 4217 code ("EUR", "USD"). Travels in the backup with the amounts
  /// it describes.
  static const currency = 'appearance.currency';

  /// `true` once the person picked the currency by hand (Ajustes ›
  /// Apariencia). A missing marker next to a stored [currency] means it was
  /// chosen before this marker existed, so it is treated as a manual choice:
  /// picking a country never overwrites it.
  static const currencyExplicit = 'appearance.currencyExplicit';

  /// An [AppAccent.stored] (`"indigo"`, `"blue"`...). Travels in the backup,
  /// like the theme.
  static const accent = 'appearance.accent';

  /// A [CellTextSize.stored] (`"normal"`, `"large"`, `"extraLarge"`).
  /// Travels in the backup, like the theme.
  static const cellTextSize = 'appearance.cellTextSize';

  /// The percentage of the withholding of the estimated pay (P9): `0` to
  /// `100`, whole per cent. Travels in the backup, like the currency (it
  /// describes the same amounts).
  static const withholdingPercent = 'summary.withholdingPercent';

  /// `true` writes the first line of the note of a day in its cell of the
  /// month (UX · Extras visuales). Off by default; travels in the backup.
  static const showNoteInMonth = 'calendar.showNoteInMonth';

  /// `true` plays a click of the system when a day is painted (UX · Extras
  /// visuales). Off by default; travels in the backup like the rest of the
  /// appearance.
  static const paintSound = 'calendar.paintSound';

  /// Relative path (inside the app's background folder) of the picture drawn
  /// behind the month, or absent for none (UX · Extras visuales).
  ///
  /// A device setting: it never goes into a backup (see `isDeviceSetting`),
  /// because the picture file itself does not travel: a restored copy must not
  /// point at a picture of another phone (or at nothing).
  static const calendarBackground = 'appearance.calendarBackground';
}

/// How times are written (Ajustes › Apariencia › Formato de hora).
///
/// [auto] follows the phone: a phone set to the 24 h clock gives 24 h, else
/// the usual clock of the region ("10:00 PM" in the United States, "22:00" in
/// Spain). Flutter cannot tell a phone forced to 12 h in a 24 h region from
/// one on its default, so there the person picks [h12].
enum TimeFormatPreference {
  auto('auto'),
  h24('24'),
  h12('12');

  const TimeFormatPreference(this.stored);

  /// The stored value (`"auto"`, `"24"`, `"12"`).
  final String stored;

  /// The preference of a stored value; anything unknown is [h24], what the
  /// app did before this was a preference.
  static TimeFormatPreference fromStored(Object? value) {
    for (final option in values) {
      if (option.stored == value) return option;
    }
    return h24;
  }

  /// Whether times show on the 12 h clock. [phoneUses24Hour] is
  /// `MediaQuery.alwaysUse24HourFormat`; [localeUses12Hour] whether the
  /// locale (language and region) writes "h:mm a" by default.
  bool resolve({
    required bool phoneUses24Hour,
    required bool localeUses12Hour,
  }) => switch (this) {
    h24 => false,
    h12 => true,
    auto => !phoneUses24Hour && localeUses12Hour,
  };
}

/// The language the user picked in Ajustes › Apariencia › Idioma.
/// [system] follows the phone and falls back to Spanish when the phone's
/// language is not one the app has.
enum AppLanguage {
  system,
  es,
  ca,
  gl,
  eu,
  en;

  /// The locale to force, or `null` to follow the phone.
  Locale? get locale => this == system ? null : Locale(name);

  /// The stored value (`"system"`, `"es"`...).
  String get stored => name;

  /// The language of a stored value; anything unknown is [system].
  static AppLanguage fromStored(Object? value) {
    for (final language in values) {
      if (language.name == value) return language;
    }
    return system;
  }
}

/// The first day of the week the user can pick.
abstract final class WeekStart {
  static const int monday = DateTime.monday;
  static const int sunday = DateTime.sunday;

  /// Whether [value] is one the app offers.
  static bool isValid(int value) => value == monday || value == sunday;
}

/// The biggest withholding the app accepts (100 %: everything withheld).
const int maxWithholdingPercent = 100;

/// Whether [percent] is a withholding the app offers (0 to 100).
bool isValidWithholdingPercent(int percent) =>
    percent >= 0 && percent <= maxWithholdingPercent;

/// What the Settings screen lets the user change about how the app looks and
/// how the month is laid out. Defaults: follow the system theme and language,
/// weeks start on Monday, no week numbers, 24 h clock, euros, the Índigo
/// accent and the normal size of the shift in the cells.
///
/// These defaults are what an installation that predates a preference keeps
/// (a missing row means the behaviour of the version before). A *new*
/// installation is given the formats of its region when it is seeded
/// (`PreferencesRepository.seedRegionDefaults`).
class Preferences {
  const Preferences({
    this.themeMode = ThemeMode.system,
    this.weekStart = WeekStart.monday,
    this.weekNumbers = false,
    this.language = AppLanguage.system,
    this.timeFormat = TimeFormatPreference.h24,
    this.currency = defaultCurrency,
    this.accent = AppAccent.defaultAccent,
    this.cellTextSize = CellTextSize.normal,
    this.withholdingPercent = 0,
    this.showNoteInMonth = false,
    this.paintSound = false,
    this.calendarBackgroundPath,
  }) : assert(weekStart == WeekStart.monday || weekStart == WeekStart.sunday),
       assert(
         withholdingPercent >= 0 && withholdingPercent <= maxWithholdingPercent,
         'The withholding is a percentage between 0 and 100',
       );

  static const Preferences defaults = Preferences();

  final ThemeMode themeMode;

  /// [WeekStart.monday] or [WeekStart.sunday].
  final int weekStart;
  final bool weekNumbers;
  final AppLanguage language;
  final TimeFormatPreference timeFormat;

  /// ISO 4217 code of the money ("EUR").
  final String currency;

  /// Ajustes › Apariencia › Color de acento.
  final AppAccent accent;

  /// Ajustes › Apariencia › Tamaño del turno en el mes.
  final CellTextSize cellTextSize;

  /// Percentage of the withholding of the estimated pay (P9): 0 (none) to
  /// 100. The app does not know the payroll of anybody, so the net it shows
  /// is an estimate of the estimate.
  final int withholdingPercent;

  /// Ajustes › Apariencia › «Ver la nota en el mes»: writes the first line of
  /// the note in the cell of the month.
  final bool showNoteInMonth;

  /// Ajustes › Apariencia › «Sonido al pintar»: a click of the system when a
  /// day is painted.
  final bool paintSound;

  /// Ajustes › Apariencia › «Imagen de fondo del calendario»: the picture
  /// drawn behind the month. Relative path inside the app's background
  /// folder, or `null`. A device setting: neither the file nor its path travel
  /// in a backup, so a restored copy never points at a picture of another
  /// phone.
  final String? calendarBackgroundPath;

  Preferences copyWith({
    ThemeMode? themeMode,
    int? weekStart,
    bool? weekNumbers,
    AppLanguage? language,
    TimeFormatPreference? timeFormat,
    String? currency,
    AppAccent? accent,
    CellTextSize? cellTextSize,
    int? withholdingPercent,
    bool? showNoteInMonth,
    bool? paintSound,
    String? calendarBackgroundPath,
    bool clearCalendarBackground = false,
  }) => Preferences(
    themeMode: themeMode ?? this.themeMode,
    weekStart: weekStart ?? this.weekStart,
    weekNumbers: weekNumbers ?? this.weekNumbers,
    language: language ?? this.language,
    timeFormat: timeFormat ?? this.timeFormat,
    currency: currency ?? this.currency,
    accent: accent ?? this.accent,
    cellTextSize: cellTextSize ?? this.cellTextSize,
    withholdingPercent: withholdingPercent ?? this.withholdingPercent,
    showNoteInMonth: showNoteInMonth ?? this.showNoteInMonth,
    paintSound: paintSound ?? this.paintSound,
    calendarBackgroundPath: clearCalendarBackground
        ? null
        : calendarBackgroundPath ?? this.calendarBackgroundPath,
  );

  @override
  bool operator ==(Object other) =>
      other is Preferences &&
      other.themeMode == themeMode &&
      other.weekStart == weekStart &&
      other.weekNumbers == weekNumbers &&
      other.language == language &&
      other.timeFormat == timeFormat &&
      other.currency == currency &&
      other.accent == accent &&
      other.cellTextSize == cellTextSize &&
      other.withholdingPercent == withholdingPercent &&
      other.showNoteInMonth == showNoteInMonth &&
      other.paintSound == paintSound &&
      other.calendarBackgroundPath == calendarBackgroundPath;

  @override
  int get hashCode => Object.hash(
    themeMode,
    weekStart,
    weekNumbers,
    language,
    timeFormat,
    currency,
    accent,
    cellTextSize,
    withholdingPercent,
    showNoteInMonth,
    paintSound,
    calendarBackgroundPath,
  );

  @override
  String toString() =>
      'Preferences(${themeMode.name}, weekStart $weekStart, '
      'weekNumbers $weekNumbers, language ${language.name}, '
      'timeFormat ${timeFormat.stored}, currency $currency, '
      'accent ${accent.stored}, cellTextSize ${cellTextSize.stored}, '
      'withholding $withholdingPercent%, '
      'showNoteInMonth $showNoteInMonth, paintSound $paintSound, '
      'calendarBackground $calendarBackgroundPath)';
}

/// The stored name of a theme mode.
String themeModeToStored(ThemeMode mode) => mode.name;

/// The theme mode of a stored value; anything unknown is "system".
ThemeMode themeModeFromStored(Object? value) {
  for (final mode in ThemeMode.values) {
    if (mode.name == value) return mode;
  }
  return ThemeMode.system;
}

/// The currency of a stored value; anything that is not an ISO 4217 code is
/// the euro.
String currencyFromStored(Object? value) =>
    value is String && isCurrencyCode(value) ? value : defaultCurrency;
