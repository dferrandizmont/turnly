import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../calendar/application/schedule_controller.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../../patterns/domain/post_night.dart';
import '../domain/shift_swap.dart';
import '../domain/swap_application.dart';
import '../domain/swap_ledger.dart';
import '../domain/swap_schedule_plan.dart';
import 'swaps_providers.dart';

/// The swap ledger of the active calendar.
class SwapsController extends AsyncNotifier<SwapLedger> {
  final _busy = <String>{};

  bool isBusy(String id) => _busy.contains(id);

  @override
  Future<SwapLedger> build() async {
    final calendarId = ref.watch(
      scheduleControllerProvider.select((s) => s.calendarId),
    );
    final source = _calendarSwapsProvider(calendarId);
    ref.listen(source, (_, next) {
      if (next case AsyncData(:final value)) {
        state = AsyncData(buildSwapLedger(value));
      }
    });
    return buildSwapLedger(await ref.watch(source.future));
  }

  Future<void> reload() async {
    final calendarId = _calendarId;
    final swaps = await ref
        .read(shiftSwapsRepositoryProvider)
        .list(calendarId: calendarId);
    if (ref.mounted && calendarId == _calendarId) {
      state = AsyncData(buildSwapLedger(swaps));
    }
  }

  String newId() => ref.read(shiftSwapsRepositoryProvider).newId();

  Future<ShiftSwap> register({
    required String colleague,
    required CivilDate date,
    required SwapDirection direction,
    CivilDate? returnDate,
    List<String>? givenShiftTypeIds,
    List<String>? receivedShiftTypeIds,
    String? note,
  }) async {
    final now = ref.read(clockProvider)().millisecondsSinceEpoch;
    final swap = ShiftSwap(
      id: newId(),
      calendarId: _calendarId,
      date: date,
      colleague: colleague.trim(),
      direction: direction,
      givenShiftTypeIds: givenShiftTypeIds,
      receivedShiftTypeIds: receivedShiftTypeIds,
      returnDate: returnDate,
      note: note,
      createdAt: now,
      updatedAt: now,
    );
    await save(swap, isNew: true);
    return swap;
  }

  /// Saves the swap and, if asked, applies it. An edit first restores the
  /// old dates when the calendar fields change. A new swap stays in the
  /// ledger when its application is undone.
  ///
  /// Applying it over a day that another applied swap holds throws
  /// [SwapApplyConflict] and saves nothing.
  Future<ScheduleChange?> save(
    ShiftSwap swap, {
    bool apply = false,
    bool isNew = false,
    void Function(List<CivilDate>)? onSkipped,
  }) async {
    final problem = swap.problem;
    if (problem != null) throw ArgumentError.value(swap, 'swap', problem);
    final repository = ref.read(shiftSwapsRepositoryProvider);
    return _write(swap.calendarId, swap.id, onSkipped, (
      base,
      current,
      records,
      claims,
      reportSkipped,
    ) async {
      if (isNew) {
        if (current != null) throw StateError('Swap already exists');
      } else if (current == null) {
        throw StateError('Swap no longer exists');
      }
      final moved = current != null && swap.movesCalendarDaysFrom(current);
      final planned = planSwapSave(
        base,
        swap,
        moved: moved,
        records: records,
        apply: apply,
        claims: claims,
      );
      if (planned.conflict case final claim?) throw SwapApplyConflict(claim);
      if (isNew) await repository.save(swap);
      final skipped = planned.skipped;
      reportSkipped(skipped);
      final restoration = planned.restoration;
      final applied = planned.applied;
      final definition =
          current != null &&
              current != swap.copyWith(updatedAt: current.updatedAt)
          ? (before: current, after: swap)
          : null;
      if (definition == null && (applied == null || applied.isEmpty)) {
        return null;
      }
      return ScheduleChange(
        patch: combinePatches(
          restoration.patch,
          applied?.change.patch ?? EntriesPatch.empty,
        ),
        swap: SwapChange(
          swapId: swap.id,
          before: records,
          after: _withApplication(swap.id, moved ? skipped : records, applied),
          definition: definition,
        ),
      );
    }, days: [swap.date, swap.returnDate]);
  }

  /// Recording the first return date completes the original swap. Its
  /// previously applied side stays in place and can be restored with it.
  Future<void> markReturned(
    String id,
    CivilDate date, {
    void Function(List<CivilDate>)? onSkipped,
  }) => _edit(
    id,
    (swap, now) => swap.copyWith(returnDate: date, updatedAt: now),
    completesApplication: true,
    onSkipped: onSkipped,
  );

  Future<void> settle(String id) =>
      _edit(id, (swap, now) => swap.returned(at: now));

  Future<void> reopen(String id) =>
      _edit(id, (swap, now) => swap.reopened(at: now));

  Future<void> _edit(
    String id,
    ShiftSwap Function(ShiftSwap, int) edit, {
    bool completesApplication = false,
    void Function(List<CivilDate>)? onSkipped,
  }) async {
    final now = ref.read(clockProvider)().millisecondsSinceEpoch;
    await _write(_calendarId, id, onSkipped, (
      base,
      current,
      records,
      _,
      reportSkipped,
    ) async {
      if (current == null) return null;
      final next = edit(current, now);
      if (next.copyWith(updatedAt: current.updatedAt) == current) return null;
      final moved =
          next.movesCalendarDaysFrom(current) &&
          !(completesApplication && current.returnDate == null);
      final restored = moved ? planRecordedSwapUndo(base, records) : null;
      if (restored != null) reportSkipped(restored.skipped);
      return ScheduleChange(
        patch: restored?.change.patch ?? EntriesPatch.empty,
        swap: SwapChange(
          swapId: id,
          before: records,
          after: restored?.skipped ?? records,
          definition: (before: current, after: next),
        ),
      );
    });
  }

  Future<ScheduleChange?> remove(
    String id, {
    bool restoreCalendar = false,
    void Function(List<CivilDate>)? onSkipped,
  }) => _write(_calendarId, id, onSkipped, (
    base,
    current,
    records,
    _,
    reportSkipped,
  ) async {
    if (current == null) return null;
    final restored = restoreCalendar
        ? planRecordedSwapUndo(base, records)
        : null;
    if (restored != null && restored.skipped.isNotEmpty) {
      reportSkipped(restored.skipped);
      // The application records need their parent swap. Keep it if the
      // requested restoration cannot be completed.
      return null;
    }
    return ScheduleChange(
      patch: restored?.change.patch ?? EntriesPatch.empty,
      swap: SwapChange(
        swapId: id,
        before: records,
        after: const [],
        definition: (before: current, after: null),
      ),
    );
  });

  /// Applies the swap. Over a day that another applied swap holds it throws
  /// [SwapApplyConflict] and writes nothing.
  Future<ScheduleChange?> applyToCalendar(ShiftSwap swap) => _write(
    swap.calendarId,
    swap.id,
    null,
    (base, current, records, claims, _) async {
      if (current == null) return null;
      final plan = planSwapApplication(base, current);
      if (plan.isEmpty) return null;
      if (swapApplyConflictOf(plan, swap.id, claims) case final claim?) {
        throw SwapApplyConflict(claim);
      }
      return ScheduleChange(
        patch: plan.change.patch,
        swap: SwapChange(
          swapId: swap.id,
          before: records,
          after: _withApplication(swap.id, records, plan),
        ),
      );
    },
  );

  Future<ScheduleChange?> undoFromCalendar(
    ShiftSwap swap, {
    void Function(List<CivilDate>)? onSkipped,
  }) => _write(swap.calendarId, swap.id, onSkipped, (
    base,
    current,
    records,
    _,
    reportSkipped,
  ) async {
    if (records.isEmpty) return null;
    final restored = planRecordedSwapUndo(base, records);
    reportSkipped(restored.skipped);
    if (restored.skipped.length == records.length) return null;
    return ScheduleChange(
      patch: restored.change.patch,
      swap: SwapChange(
        swapId: swap.id,
        before: records,
        after: restored.skipped,
      ),
    );
  });

  List<SwapApplicationRecord> _withApplication(
    String id,
    List<SwapApplicationRecord> records,
    SwapSchedulePlan? applied,
  ) {
    if (applied == null || applied.isEmpty) return records;
    final byDate = {for (final record in records) record.date: record};
    final now = ref.read(clockProvider)().millisecondsSinceEpoch;
    for (final MapEntry(key: date, value: change)
        in applied.change.patch.changes.entries) {
      final record = byDate[date];
      byDate[date] = SwapApplicationRecord(
        swapId: id,
        date: date,
        previousShiftTypeIds: record == null
            ? applied.before[date]?.shiftTypeIds
            : record.previousShiftTypeIds,
        createdAt: record?.createdAt ?? now,
        appliedOverride: (shiftTypeIds: change.after?.shiftTypeIds),
      );
    }
    return byDate.values.toList();
  }

  /// Plans and writes one swap step through
  /// [ScheduleController.commitSwapChange]. [plan] gets the schedule with
  /// the swap's days as stored: its current dates, the days of its records
  /// and [days] (the dates an edit moves it to), all read in the same
  /// transaction as the swap, its records and the claims of the calendar.
  Future<ScheduleChange?> _write(
    String calendarId,
    String id,
    void Function(List<CivilDate>)? onSkipped,
    Future<ScheduleChange?> Function(
      Schedule base,
      ShiftSwap? current,
      List<SwapApplicationRecord> records,
      List<SwapDayClaim> claims,
      void Function(List<SwapApplicationRecord>) reportSkipped,
    )
    plan, {
    Iterable<CivilDate?> days = const [],
  }) async {
    if (calendarId != _calendarId || !_busy.add(id)) return null;
    try {
      var skipped = const <SwapApplicationRecord>[];
      final schedule = ref.read(scheduleControllerProvider.notifier);
      final swaps = ref.read(shiftSwapsRepositoryProvider);
      final applications = ref.read(swapAppliedStoreProvider);
      final step = await schedule.commitSwapChange(
        calendarId,
        (readDays) async {
          // Only what this attempt found counts.
          skipped = const [];
          final current = await swaps.byId(id);
          if (current != null && current.calendarId != calendarId) {
            throw StateError('Swap belongs to another calendar');
          }
          final records = await applications.before(id);
          final base = await readDays({
            ?current?.date,
            ?current?.returnDate,
            for (final date in days) ?date,
            for (final record in records) record.date,
          });
          return plan(
            base,
            current,
            records,
            await applications.claims(calendarId),
            (records) => skipped = records,
          );
        },
        isRefusal: (error) => error is SwapApplyConflict,
        swapId: id,
      );
      if (skipped.isNotEmpty) {
        onSkipped?.call([for (final record in skipped) record.date]);
      }
      if (ref.mounted) await reload();
      return step;
    } finally {
      _busy.remove(id);
    }
  }

  String get _calendarId => ref.read(scheduleControllerProvider).calendarId;
}

final _calendarSwapsProvider = StreamProvider.autoDispose
    .family<List<ShiftSwap>, String>(
      (ref, id) => ref.watch(shiftSwapsRepositoryProvider).watchCalendar(id),
    );

final swapLedgerProvider = AsyncNotifierProvider<SwapsController, SwapLedger>(
  SwapsController.new,
);

final swapsOfDayProvider = Provider.autoDispose
    .family<List<ShiftSwap>, CivilDate>((ref, date) {
      final ledger = ref.watch(swapLedgerProvider).value;
      if (ledger == null) return const [];
      return [
        for (final swap in ledger.swaps)
          if (swap.date == date || swap.returnDate == date) swap,
      ];
    });
