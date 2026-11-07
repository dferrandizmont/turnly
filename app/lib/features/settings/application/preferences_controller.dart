import 'dart:async';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../data/preferences_repository.dart';
import '../domain/preferences.dart';

final preferencesRepositoryProvider = Provider<PreferencesRepository>(
  (ref) => PreferencesRepository(ref.watch(appDatabaseProvider)),
);

/// The preferences `bootstrapApp` loaded before the first frame, so the app
/// opens in the right theme without a flash. `main` overrides it. Left
/// `null` (tests, the QA harness), the controller starts on the defaults and
/// reads the stored values right after.
final initialPreferencesProvider = Provider<Preferences?>((ref) => null);

/// The user's preferences. The state changes at once; the write follows. If
/// it fails the previous value comes back and the error reaches the caller.
class PreferencesController extends Notifier<Preferences> {
  // A change made before the first read finished wins over that read.
  bool _touched = false;

  @override
  Preferences build() {
    _touched = false;
    final initial = ref.read(initialPreferencesProvider);
    if (initial != null) return initial;
    unawaited(_loadInitial());
    return Preferences.defaults;
  }

  Future<void> _loadInitial() async {
    try {
      final stored = await ref.read(preferencesRepositoryProvider).load();
      if (ref.mounted && !_touched) state = stored;
    } catch (_) {
      // Unreadable preferences: keep the defaults.
    }
  }

  /// Reads the stored preferences again (after a restore replaced them).
  Future<void> reload() async {
    final stored = await ref.read(preferencesRepositoryProvider).load();
    if (ref.mounted) state = stored;
  }

  Future<void> setThemeMode(ThemeMode mode) => _change(
    state.copyWith(themeMode: mode),
    (repository) => repository.setThemeMode(mode),
  );

  /// [weekStart] is [WeekStart.monday] or [WeekStart.sunday]. Choosing the
  /// value you already have still writes the explicit marker ([force]): a
  /// country picked later must not change a hand-made choice.
  Future<void> setWeekStart(int weekStart) => _change(
    state.copyWith(weekStart: weekStart),
    (repository) => repository.setWeekStart(weekStart),
    force: true,
  );

  /// Picking a country applies the formats of that country (its first day of
  /// the week and its currency) to whatever the person has not chosen by hand
  /// ([region] is an ISO 3166 alpha-2 code, or `null` when unknown). Called
  /// from the first use and from Ajustes › Festivos.
  Future<void> applyRegionDefaults(String? region) async {
    final previous = state;
    _touched = true;
    try {
      final next = await ref
          .read(preferencesRepositoryProvider)
          .applyRegionDefaults(region);
      if (ref.mounted) state = next;
    } catch (_) {
      if (ref.mounted) state = previous;
      rethrow;
    }
  }

  Future<void> setWeekNumbers(bool show) => _change(
    state.copyWith(weekNumbers: show),
    (repository) => repository.setWeekNumbers(show),
  );

  /// Applied at once through `MaterialApp.locale` (see `CuadranteApp`).
  Future<void> setLanguage(AppLanguage language) => _change(
    state.copyWith(language: language),
    (repository) => repository.setLanguage(language),
  );

  /// Ajustes › Apariencia › Formato de hora; applied at once.
  Future<void> setTimeFormat(TimeFormatPreference timeFormat) => _change(
    state.copyWith(timeFormat: timeFormat),
    (repository) => repository.setTimeFormat(timeFormat),
  );

  /// Ajustes › Apariencia › Moneda ([currency] is an ISO 4217 code). The
  /// amounts already stored are not converted (`money.dart`). Choosing the
  /// value you already have still writes the explicit marker ([force]).
  Future<void> setCurrency(String currency) => _change(
    state.copyWith(currency: currency),
    (repository) => repository.setCurrency(currency),
    force: true,
  );

  /// Ajustes › Apariencia › Color de acento; the whole app repaints at once
  /// (`CuadranteApp` builds the theme with it).
  Future<void> setAccent(AppAccent accent) => _change(
    state.copyWith(accent: accent),
    (repository) => repository.setAccent(accent),
  );

  /// Ajustes › Apariencia › Tamaño del turno en el mes; applied at once.
  Future<void> setCellTextSize(CellTextSize size) => _change(
    state.copyWith(cellTextSize: size),
    (repository) => repository.setCellTextSize(size),
  );

  /// Ajustes › Apariencia › «Fondo negro»; the dark theme repaints at once.
  Future<void> setPureBlack(bool enabled) => _change(
    state.copyWith(pureBlack: enabled),
    (repository) => repository.setPureBlack(enabled),
  );

  /// The percentage of the withholding of the estimated pay (P9): a whole
  /// number between 0 and 100.
  Future<void> setWithholdingPercent(int percent) => _change(
    state.copyWith(withholdingPercent: percent),
    (repository) => repository.setWithholdingPercent(percent),
  );

  /// Ajustes › Apariencia › «Ver la nota en el mes»: applied at once.
  Future<void> setShowNoteInMonth(bool show) => _change(
    state.copyWith(showNoteInMonth: show),
    (repository) => repository.setShowNoteInMonth(show),
  );

  /// Ajustes › Apariencia › «Sonido al pintar»: applied at once.
  Future<void> setPaintSound(bool enabled) => _change(
    state.copyWith(paintSound: enabled),
    (repository) => repository.setPaintSound(enabled),
  );

  /// Ajustes › Apariencia › «Imagen de fondo del calendario»: `null` removes
  /// it. The controller does not touch the file: the background screen does.
  Future<void> setCalendarBackground(String? relativePath) => _change(
    state.copyWith(
      calendarBackgroundPath: relativePath,
      clearCalendarBackground: relativePath == null,
    ),
    (repository) => repository.setCalendarBackground(relativePath),
  );

  /// [force] writes even when [next] equals the current state: a few choices
  /// (the week start and the currency) also store a marker, so re-choosing the
  /// same value by hand still has to be written.
  Future<void> _change(
    Preferences next,
    Future<void> Function(PreferencesRepository repository) write, {
    bool force = false,
  }) async {
    final previous = state;
    if (!force && next == previous) return;
    _touched = true;
    state = next;
    try {
      await write(ref.read(preferencesRepositoryProvider));
    } catch (_) {
      if (ref.mounted && state == next) state = previous;
      rethrow;
    }
  }
}

final preferencesProvider =
    NotifierProvider<PreferencesController, Preferences>(
      PreferencesController.new,
    );
