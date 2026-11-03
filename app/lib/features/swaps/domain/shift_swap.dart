import 'package:collection/collection.dart';

import '../../schedule/domain/civil_date.dart';

/// Who owes the favour after a shift swap. The name is what is stored.
enum SwapDirection {
  /// I worked (or gave) a shift for the colleague: they owe me one.
  theyOwe,

  /// The colleague worked a shift for me: I owe them one.
  iOwe,
}

/// Whether the swap is still owed or already paid back. The name is what is
/// stored.
enum SwapStatus { pending, returned }

/// The stage of a swap in the ledger, the way the screen shows it.
///
/// The stored status has only two values ([SwapStatus]); the third stage
/// comes from the day the favour came back ([ShiftSwap.returnDate]):
///
/// - [pending]: the favour is still owed, nothing came back yet.
/// - [returned]: the favour came back (the received day is recorded) but the
///   item is still open.
/// - [settled]: the item is closed: it leaves the pending list and the
///   balance.
enum SwapStage { pending, returned, settled }

/// Which side of a swap a day belongs to.
enum SwapSide {
  /// The day whose shift I gave away.
  given,

  /// The day whose shift I receive.
  received,
}

/// The service data of one day of a swap: who works that day and what service
/// (the shift types) it is.
///
/// `day_entries` has no columns for this (no «con quién» nor «qué servicio»),
/// so it lives in the change itself: the colleague of the row and the shift
/// types of each side (see [ShiftSwap.serviceDays]).
class SwapServiceDay {
  const SwapServiceDay({
    required this.date,
    required this.side,
    required this.colleague,
    this.shiftTypeIds = const [],
  });

  final CivilDate date;
  final SwapSide side;

  /// The colleague of the change, as it was typed.
  final String colleague;

  /// The shift types of that day; empty when they were not recorded.
  final List<String> shiftTypeIds;

  @override
  bool operator ==(Object other) =>
      other is SwapServiceDay &&
      other.date == date &&
      other.side == side &&
      other.colleague == colleague &&
      const ListEquality<String>().equals(other.shiftTypeIds, shiftTypeIds);

  @override
  int get hashCode => Object.hash(
    date,
    side,
    colleague,
    const ListEquality<String>().hash(shiftTypeIds),
  );

  @override
  String toString() => 'SwapServiceDay($date, ${side.name}, $colleague)';
}

/// Longest colleague name and note of a swap.
const int maxSwapColleagueLength = 200;
const int maxSwapNoteLength = 2000;

const _ids = ListEquality<String>();

/// One line of the swap ledger («libro de cambios», a `shift_swaps` row,
/// schema v6): on [date] a shift changed hands with [colleague]. It records
/// the debt; it does not change the calendar by itself (the swap screen may
/// also write the day, through the schedule, as any other edit).
class ShiftSwap {
  const ShiftSwap({
    required this.id,
    required this.calendarId,
    required this.date,
    required this.colleague,
    required this.direction,
    required this.createdAt,
    required this.updatedAt,
    this.givenShiftTypeIds,
    this.receivedShiftTypeIds,
    this.returnDate,
    this.status = SwapStatus.pending,
    this.note,
    this.closedAt,
  });

  final String id;
  final String calendarId;

  /// The day the swap happens.
  final CivilDate date;

  /// The colleague, as typed (no contact, no account).
  final String colleague;
  final SwapDirection direction;

  /// Shift types I give away and receive (ids; `null` = not recorded).
  final List<String>? givenShiftTypeIds;
  final List<String>? receivedShiftTypeIds;

  /// The day the favour is (or was) paid back, when known.
  final CivilDate? returnDate;
  final SwapStatus status;
  final String? note;

  /// Milliseconds since the epoch (UTC). [closedAt] is set exactly when the
  /// swap is [SwapStatus.returned].
  final int createdAt;
  final int updatedAt;
  final int? closedAt;

  bool get isReturned => status == SwapStatus.returned;

  /// The stage of this swap in the ledger (see [SwapStage]).
  SwapStage get stage {
    if (status == SwapStatus.returned) return SwapStage.settled;
    return returnDate == null ? SwapStage.pending : SwapStage.returned;
  }

  /// How many shifts I gave away: the ones recorded. When they were not
  /// recorded it is one if the change says the colleague owes me (the shift I
  /// gave away is the debt) or if the favour already came back (the day it
  /// comes back is a day I give); otherwise none.
  ///
  /// Only the side the change says is the debt counts while the favour is
  /// still owed: recording a shift of the other side does not cancel it.
  int get givenCount {
    final ids = givenShiftTypeIds;
    if (returnDate == null && direction != SwapDirection.theyOwe) return 0;
    return ids?.length ?? 1;
  }

  /// How many shifts I received: the ones recorded. When they were not
  /// recorded it is one if the change says I owe them (the shift they worked
  /// for me is the debt) or if the favour already came back (the day it comes
  /// back is a day I receive); otherwise none. See [givenCount] for why the
  /// other side does not cancel the debt while it is still owed.
  int get receivedCount {
    final ids = receivedShiftTypeIds;
    if (returnDate == null && direction != SwapDirection.iOwe) return 0;
    return ids?.length ?? 1;
  }

  /// The shifts the colleague still owes me: positive when they owe me,
  /// negative when I owe them.
  ///
  /// While the favour is still owed ([returnDate] `null`) only the side the
  /// change says is the debt counts; both sides count once it came back, so
  /// what came back cancels what was owed.
  int get netShifts => givenCount - receivedCount;

  /// The days the change touches, with the service data of each: the
  /// colleague and the shift types of that day.
  ///
  /// The day I give comes first; the day I receive only when it is known
  /// (a change can be «me lo deben», with no day to receive it yet).
  List<SwapServiceDay> get serviceDays {
    final received = returnDate;
    return [
      SwapServiceDay(
        date: date,
        side: SwapSide.given,
        colleague: colleague,
        shiftTypeIds: givenShiftTypeIds ?? const [],
      ),
      if (received != null)
        SwapServiceDay(
          date: received,
          side: SwapSide.received,
          colleague: colleague,
          shiftTypeIds: receivedShiftTypeIds ?? const [],
        ),
    ];
  }

  /// The same change with some fields replaced. The `clear...` flags take a
  /// field back to `null` (a `null` in an argument means "keep what it was").
  ShiftSwap copyWith({
    String? calendarId,
    CivilDate? date,
    String? colleague,
    SwapDirection? direction,
    List<String>? givenShiftTypeIds,
    List<String>? receivedShiftTypeIds,
    CivilDate? returnDate,
    SwapStatus? status,
    String? note,
    int? updatedAt,
    int? closedAt,
    bool clearGivenShiftTypeIds = false,
    bool clearReceivedShiftTypeIds = false,
    bool clearReturnDate = false,
    bool clearNote = false,
    bool clearClosedAt = false,
  }) => ShiftSwap(
    id: id,
    calendarId: calendarId ?? this.calendarId,
    date: date ?? this.date,
    colleague: colleague ?? this.colleague,
    direction: direction ?? this.direction,
    givenShiftTypeIds: clearGivenShiftTypeIds
        ? null
        : givenShiftTypeIds ?? this.givenShiftTypeIds,
    receivedShiftTypeIds: clearReceivedShiftTypeIds
        ? null
        : receivedShiftTypeIds ?? this.receivedShiftTypeIds,
    returnDate: clearReturnDate ? null : returnDate ?? this.returnDate,
    status: status ?? this.status,
    note: clearNote ? null : note ?? this.note,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    closedAt: clearClosedAt ? null : closedAt ?? this.closedAt,
  );

  /// Why this swap cannot be stored, or `null` when it is valid (the same
  /// rules as the table and the backup).
  String? get problem {
    if (id.isEmpty) return 'empty id';
    if (calendarId.isEmpty) return 'no calendar';
    if (colleague.trim().isEmpty) return 'no colleague';
    if (colleague.length > maxSwapColleagueLength) return 'colleague too long';
    final text = note;
    if (text != null && text.length > maxSwapNoteLength) return 'note too long';
    if ((status == SwapStatus.returned) != (closedAt != null)) {
      return 'closedAt must be set exactly when returned';
    }
    return null;
  }

  /// This swap paid back at [at] (milliseconds, UTC).
  ShiftSwap returned({required int at}) => _with(
    status: SwapStatus.returned,
    closedAt: at,
    updatedAt: at,
  );

  /// This swap owed again (a «devuelto» undone) at [at].
  ShiftSwap reopened({required int at}) =>
      _with(status: SwapStatus.pending, closedAt: null, updatedAt: at);

  ShiftSwap _with({
    required SwapStatus status,
    required int? closedAt,
    required int updatedAt,
  }) => ShiftSwap(
    id: id,
    calendarId: calendarId,
    date: date,
    colleague: colleague,
    direction: direction,
    givenShiftTypeIds: givenShiftTypeIds,
    receivedShiftTypeIds: receivedShiftTypeIds,
    returnDate: returnDate,
    status: status,
    note: note,
    createdAt: createdAt,
    updatedAt: updatedAt,
    closedAt: closedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is ShiftSwap &&
      other.id == id &&
      other.calendarId == calendarId &&
      other.date == date &&
      other.colleague == colleague &&
      other.direction == direction &&
      _nullableIdsEqual(other.givenShiftTypeIds, givenShiftTypeIds) &&
      _nullableIdsEqual(other.receivedShiftTypeIds, receivedShiftTypeIds) &&
      other.returnDate == returnDate &&
      other.status == status &&
      other.note == note &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.closedAt == closedAt;

  static bool _nullableIdsEqual(List<String>? a, List<String>? b) =>
      a == null ? b == null : b != null && _ids.equals(a, b);

  @override
  int get hashCode => Object.hash(
    id,
    calendarId,
    date,
    colleague,
    direction,
    givenShiftTypeIds == null ? null : _ids.hash(givenShiftTypeIds),
    receivedShiftTypeIds == null ? null : _ids.hash(receivedShiftTypeIds),
    returnDate,
    status,
    note,
    createdAt,
    updatedAt,
    closedAt,
  );

  @override
  String toString() =>
      'ShiftSwap($id, $calendarId $date, ${direction.name}, ${status.name})';
}
