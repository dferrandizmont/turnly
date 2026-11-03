import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/providers.dart';
import '../../calendar/application/schedule_controller.dart';
import '../../calendars/application/calendars_providers.dart';
import '../../schedule/application/schedule_providers.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../data/absence_balances_repository.dart';
import '../data/absence_carry_over_store.dart';
import '../domain/absence_balance.dart';
import '../domain/absence_calculator.dart';
import '../domain/absence_status.dart';

/// The only door to the stored balances.
final absenceBalancesRepositoryProvider = Provider<AbsenceBalancesRepository>(
  (ref) => AbsenceBalancesRepository(ref.watch(appDatabaseProvider)),
);

/// Where the day the carried days expire is kept.
final absenceCarryOverStoreProvider = Provider<AbsenceCarryOverStore>(
  (ref) => AbsenceCarryOverStore(ref.watch(appDatabaseProvider)),
);

/// The absence balances of a year and what is left of each one (P3).
///
/// It reads the stored balances, the days of the calendar they belong to and
/// the expiry dates of the carried days, and computes what is used and what
/// is left (the days used are never stored).
///
/// Writing (a balance, a change, an expiry date) refreshes it at once.
final absenceBalancesProvider = AsyncNotifierProvider.autoDispose
    .family<AbsenceBalancesController, List<AbsenceBalanceStatus>, int>(
      AbsenceBalancesController.new,
    );

/// The balances of one calendar of a year, for the screen that shows a
/// calendar at a time.
final absenceBalancesForCalendarProvider = FutureProvider.autoDispose
    .family<List<AbsenceBalanceStatus>, ({String calendarId, int year})>((
      ref,
      query,
    ) async {
      final statuses = await ref.watch(
        absenceBalancesProvider(query.year).future,
      );
      return [
        for (final status in statuses)
          if (status.calendarId == query.calendarId) status,
      ];
    });

/// The balances of a year: reads them and writes them.
class AbsenceBalancesController
    extends AsyncNotifier<List<AbsenceBalanceStatus>> {
  AbsenceBalancesController(this.year);

  /// The year the balances are of.
  final int year;

  @override
  Future<List<AbsenceBalanceStatus>> build() => _read();

  Future<List<AbsenceBalanceStatus>> _read() async {
    final activeId = ref.watch(
      scheduleControllerProvider.select((s) => s.calendarId),
    );
    final activeSchedule = ref.watch(
      scheduleControllerProvider.select((s) => s.schedule),
    );
    // Only the day matters: the balances are read again when the day rolls
    // over, not every minute.
    final today = ref.watch(
      minuteClockProvider.select((now) => CivilDate.fromDateTime(now)),
    );

    final balances = await ref.read(absenceBalancesRepositoryProvider).list();
    final expiry = await ref.read(absenceCarryOverStoreProvider).load();
    final primaryId = await ref.read(calendarsRepositoryProvider).primaryId();
    final schedules = await _schedules(
      activeId: activeId,
      activeSchedule: activeSchedule,
      primaryId: primaryId,
      balances: balances,
    );

    return AbsenceBalanceCalculator(
      balances: balances,
      schedules: schedules,
      primaryCalendarId: primaryId,
      today: today,
      carryOverExpiry: expiry,
    ).statusesOf(year);
  }

  /// The schedules of the calendars the balances count: the one on screen
  /// from the editor (the freshest) and the others from the database, after
  /// the writes already queued have finished.
  Future<Map<String, Schedule>> _schedules({
    required String activeId,
    required Schedule activeSchedule,
    required String primaryId,
    required List<AbsenceBalance> balances,
  }) async {
    final needed = <String>{
      primaryId,
      for (final balance in balances) balance.calendarId ?? primaryId,
    };
    final schedules = <String, Schedule>{};
    final others = needed.where((id) => id != activeId).toList();
    if (others.isNotEmpty) {
      await ref.read(scheduleControllerProvider.notifier).pendingWrites;
    }
    for (final id in needed) {
      if (id == activeId) {
        schedules[id] = activeSchedule;
      } else {
        schedules[id] = (await ref.read(scheduleRepositoryProvider).load(id))
            .schedule;
      }
    }
    return schedules;
  }

  /// Saves [balance] (the days allowed, the types that count, the cap of the
  /// carry-over, the manual adjustments...). The balances are read again at
  /// once, and the row is stamped: a row that exists keeps the day it was
  /// created.
  Future<void> save(AbsenceBalance balance) async {
    final repository = ref.read(absenceBalancesRepositoryProvider);
    final now = ref.read(clockProvider)().toUtc().millisecondsSinceEpoch;
    final existing = await repository.find(balance.year, balance.type);
    await repository.save(
      balance.copyWith(
        createdAt: existing?.createdAt ?? balance.createdAt ?? now,
        updatedAt: now,
      ),
    );
    _refresh();
  }

  /// Removes the balance of the series [type] in [year]. Returns whether a
  /// row went.
  Future<bool> delete(int year, String type) async {
    final deleted = await ref
        .read(absenceBalancesRepositoryProvider)
        .delete(year, type);
    _refresh();
    return deleted;
  }

  /// Sets the day the days carried into [year] of the series [type] of
  /// [calendarId] expire (`null` clears it: they never expire).
  Future<void> setCarryOverExpiry(
    int year,
    String type,
    CivilDate? date, {
    String? calendarId,
  }) async {
    await ref
        .read(absenceCarryOverStoreProvider)
        .setExpiry(year, type, date, calendarId: calendarId);
    _refresh();
  }

  /// Every year is read again: a change in one of them changes the carry-over
  /// of the next.
  void _refresh() => ref.invalidate(absenceBalancesProvider);
}
