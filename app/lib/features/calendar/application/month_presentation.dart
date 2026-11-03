import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../schedule/domain/civil_date.dart';
import '../data/month_view_settings_repository.dart';

enum MonthPresentation { grid, list }

final monthViewSettingsRepositoryProvider =
    Provider<MonthViewSettingsRepository>(
      (ref) => MonthViewSettingsRepository(ref.watch(appDatabaseProvider)),
    );

/// Grid or List (B7 of `docs/propuesta-mejoras.md`): survives month/calendar
/// navigation and rotation, and is remembered between openings once the
/// person chooses it. Nothing ever changes it on its own: the list is only
/// recommended (`MonthPresentationControl`), never imposed.
///
/// The stored choice is read right after the first build (the grid until
/// then); a choice made before that read finishes wins over it.
class MonthPresentationController extends Notifier<MonthPresentation> {
  bool _touched = false;

  @override
  MonthPresentation build() {
    _touched = false;
    unawaited(_load());
    return MonthPresentation.grid;
  }

  Future<void> _load() async {
    try {
      final stored = await ref
          .read(monthViewSettingsRepositoryProvider)
          .readPresentation();
      if (!ref.mounted || _touched) return;
      final value = MonthPresentation.values
          .where((v) => v.name == stored)
          .firstOrNull;
      if (value != null) state = value;
    } catch (_) {
      // No database (a bare test container) or an unreadable row: the grid.
    }
  }

  /// The person's choice: applied at once and remembered.
  void choose(MonthPresentation value) {
    _touched = true;
    if (state == value) return;
    state = value;
    unawaited(_save(value));
  }

  Future<void> _save(MonthPresentation value) async {
    try {
      await ref
          .read(monthViewSettingsRepositoryProvider)
          .writePresentation(value.name);
    } catch (_) {
      // A failed write only loses the memory of the choice, never data.
    }
  }
}

final monthPresentationProvider =
    NotifierProvider<MonthPresentationController, MonthPresentation>(
      MonthPresentationController.new,
    );

/// What the person chose for the «Hoy» card of the month (B1): `true` folded
/// to one line, `false` open, `null` never chosen (the screen then decides by
/// itself: folded when the month would not fit with the card open, decision
/// 28). Remembered between openings, read like [monthPresentationProvider].
class TodayCardCollapsedController extends Notifier<bool?> {
  bool _touched = false;

  @override
  bool? build() {
    _touched = false;
    unawaited(_load());
    return null;
  }

  Future<void> _load() async {
    try {
      final stored = await ref
          .read(monthViewSettingsRepositoryProvider)
          .readTodayCardCollapsed();
      if (!ref.mounted || _touched || stored == null) return;
      state = stored;
    } catch (_) {
      // Unreadable: the screen decides.
    }
  }

  /// The person's explicit choice: it wins over the default from then on.
  void set(bool collapsed) {
    _touched = true;
    if (state == collapsed) return;
    state = collapsed;
    unawaited(_save(collapsed));
  }

  Future<void> _save(bool collapsed) async {
    try {
      await ref
          .read(monthViewSettingsRepositoryProvider)
          .writeTodayCardCollapsed(collapsed);
    } catch (_) {
      // A failed write only loses the memory of the fold.
    }
  }
}

final todayCardCollapsedProvider =
    NotifierProvider<TodayCardCollapsedController, bool?>(
      TodayCardCollapsedController.new,
    );

/// The last day used by either presentation, plus an explicit focus request.
/// Merely rebuilding or moving the focus never announces a presentation change.
class MonthDayFocus extends Notifier<({CivilDate? date, int request})> {
  @override
  ({CivilDate? date, int request}) build() => (date: null, request: 0);

  void remember(CivilDate date) => state = (date: date, request: state.request);

  void request(CivilDate date) =>
      state = (date: date, request: state.request + 1);
}

final monthDayFocusProvider =
    NotifierProvider<MonthDayFocus, ({CivilDate? date, int request})>(
      MonthDayFocus.new,
    );
