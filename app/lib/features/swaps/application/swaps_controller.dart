import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../calendar/application/schedule_controller.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../domain/shift_swap.dart';
import '../domain/swap_ledger.dart';
import '../domain/swap_schedule_plan.dart';
import 'swaps_providers.dart';

/// The swap ledger of the ACTIVE calendar: the changes registered with the
/// colleagues («me debe / le debo») and the balance of each of them.
///
/// The state is read from the database, so it is always what is stored; the
/// screen rebuilds it when a change is registered ([SwapsController]).
class SwapsController extends AsyncNotifier<SwapLedger> {
  /// What the days of each change had before it was applied to the calendar,
  /// to put them back when undoing.
  final _applied = <String, Map<CivilDate, DayEntry?>>{};

  @override
  Future<SwapLedger> build() async {
    final calendarId = ref.watch(
      scheduleControllerProvider.select((s) => s.calendarId),
    );
    return _read(calendarId);
  }

  /// Reads the ledger again (after a restore, for instance).
  Future<void> reload() async {
    state = AsyncData(await _read(_calendarId));
  }

  /// Registers a new change in the ledger.
  ///
  /// [date] is the day whose shift I give away and [returnDate] the day I
  /// receive one (`null`: the favour is still owed, «me lo deben»). The
  /// shift types of each side are optional: without them the change still
  /// counts as one shift.
  ///
  /// Throws [ArgumentError] when the change is not valid (an empty
  /// colleague, for instance); nothing is written then.
  Future<ShiftSwap> register({
    required String colleague,
    required CivilDate date,
    required SwapDirection direction,
    CivilDate? returnDate,
    List<String>? givenShiftTypeIds,
    List<String>? receivedShiftTypeIds,
    String? note,
  }) async {
    final repository = ref.read(shiftSwapsRepositoryProvider);
    final now = ref.read(clockProvider)().millisecondsSinceEpoch;
    final swap = ShiftSwap(
      id: repository.newId(),
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
    await repository.save(swap);
    await _refresh();
    return swap;
  }

  /// Saves an edited change (its note, the day the favour comes back, the
  /// shifts of each side).
  ///
  /// Throws [ArgumentError] when the change is not valid; nothing is written
  /// then.
  Future<void> save(ShiftSwap swap) async {
    await ref.read(shiftSwapsRepositoryProvider).save(swap);
    await _refresh();
  }

  /// The item is settled: the favour was paid back. It leaves the pending
  /// list and the balance.
  Future<void> settle(String id) async {
    final now = ref.read(clockProvider)().millisecondsSinceEpoch;
    await ref.read(shiftSwapsRepositoryProvider).markReturned(id, at: now);
    await _refresh();
  }

  /// The item is owed again (a settled change undone).
  Future<void> reopen(String id) async {
    final now = ref.read(clockProvider)().millisecondsSinceEpoch;
    await ref.read(shiftSwapsRepositoryProvider).reopen(id, at: now);
    await _refresh();
  }

  /// Removes the change from the ledger.
  Future<void> remove(String id) async {
    await ref.read(shiftSwapsRepositoryProvider).delete(id);
    _applied.remove(id);
    await _refresh();
  }

  /// Applies the change to the calendar: the day I gave loses the shifts I
  /// gave and the day I receive gets the ones the colleague gives me. The
  /// days keep their note and their extras.
  ///
  /// It is **one** undo step, so the usual «Deshacer» takes the whole change
  /// back at once.
  ///
  /// Returns the step, or `null` when nothing changed: the change is of
  /// another calendar, or the days already are as the change says.
  ScheduleChange? applyToCalendar(ShiftSwap swap) {
    if (swap.calendarId != _calendarId) return null;
    final controller = ref.read(scheduleControllerProvider.notifier);
    Map<CivilDate, DayEntry?>? before;
    final change = controller.applyPlanned((current) {
      final plan = planSwapApplication(current, swap);
      before = plan.before;
      return (change: plan.change, newTypes: const <ShiftType>[]);
    });
    if (change != null && before != null) {
      // The first application is the one to undo: a second one keeps the
      // days as they were before it.
      _applied.putIfAbsent(swap.id, () => before!);
    }
    return change;
  }

  /// Takes the change back from the calendar: the days it touched go back to
  /// what they were. **One** undo step, like the application.
  ///
  /// Returns the step, or `null` when the change was not applied (or the
  /// days already are as they were).
  ScheduleChange? undoFromCalendar(ShiftSwap swap) {
    final before = _applied.remove(swap.id);
    if (before == null) return null;
    final controller = ref.read(scheduleControllerProvider.notifier);
    return controller.applyPlanned((current) {
      final plan = planSwapUndo(current, before);
      return (change: plan.change, newTypes: const <ShiftType>[]);
    });
  }

  String get _calendarId => ref.read(scheduleControllerProvider).calendarId;

  Future<SwapLedger> _read(String calendarId) async {
    final swaps = await ref
        .read(shiftSwapsRepositoryProvider)
        .list(calendarId: calendarId);
    return buildSwapLedger(swaps);
  }

  Future<void> _refresh() async {
    state = AsyncData(await _read(_calendarId));
  }
}

/// The swap ledger of the ACTIVE calendar.
final swapLedgerProvider =
    AsyncNotifierProvider<SwapsController, SwapLedger>(SwapsController.new);

/// The changes that touch [date] in the ACTIVE calendar: the ones of that
/// day and the ones that come back on it. The day detail shows them.
final swapsOfDayProvider = Provider.autoDispose
    .family<List<ShiftSwap>, CivilDate>((ref, date) {
      final ledger = ref.watch(swapLedgerProvider).value;
      if (ledger == null) return const [];
      return [
        for (final swap in ledger.swaps)
          if (swap.date == date || swap.returnDate == date) swap,
      ];
    });
