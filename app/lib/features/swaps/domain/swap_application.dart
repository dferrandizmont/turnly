import 'dart:convert';

import '../../schedule/domain/civil_date.dart';
import 'shift_swap.dart';

/// The original override of a day the swap actually changed.
class SwapApplicationRecord {
  const SwapApplicationRecord({
    required this.swapId,
    required this.date,
    required this.previousShiftTypeIds,
    required this.createdAt,
    this.appliedOverride,
  });

  final String swapId;
  final CivilDate date;
  final List<String>? previousShiftTypeIds;
  final int createdAt;

  /// The override written by the swap. A missing snapshot means an older
  /// record cannot prove what it wrote. A snapshot can itself hold null
  /// (follow the rotation) or an empty list (explicitly free).
  final ({List<String>? shiftTypeIds})? appliedOverride;
}

/// The part of an undo step that belongs to the swap book.
class SwapChange {
  const SwapChange({
    required this.swapId,
    required this.before,
    required this.after,
    this.definition,
  });

  final String swapId;
  final List<SwapApplicationRecord> before;
  final List<SwapApplicationRecord> after;
  final ({ShiftSwap? before, ShiftSwap? after})? definition;

  SwapChange inverse() => SwapChange(
    swapId: swapId,
    before: after,
    after: before,
    definition: definition == null
        ? null
        : (before: definition!.after, after: definition!.before),
  );
}

const legacySwapApplicationsKey = 'swaps.applied';
const swapApplicationRecoveryKey = 'swaps.applied.recovery';

bool isSwapApplicationRecoveryKey(String key) =>
    key == swapApplicationRecoveryKey ||
    key.startsWith('$swapApplicationRecoveryKey.');

String availableSwapApplicationRecoveryKey(Iterable<String> keys) {
  var key = swapApplicationRecoveryKey;
  var suffix = 1;
  while (keys.contains(key)) {
    key = '$swapApplicationRecoveryKey.${suffix++}';
  }
  return key;
}

/// Read the v7 setting, also found inside older backup files. A malformed
/// swap is skipped as a whole, since restoring just some of its days would
/// be unsafe. Return the rejected records, or the exact raw setting when
/// the whole value is unreadable. An absent setting has no rejected data.
({List<SwapApplicationRecord> records, String? rejectedJson})
readLegacySwapApplications(String? json, Map<String, int> swapTimestamps) {
  if (json == null) return (records: const [], rejectedJson: null);
  final Object? all;
  try {
    all = jsonDecode(json);
  } on FormatException {
    return (records: const [], rejectedJson: json);
  }
  if (all is! Map<String, Object?>) {
    return (records: const [], rejectedJson: json);
  }
  final records = <SwapApplicationRecord>[];
  final rejected = <String, Object?>{};
  for (final MapEntry(key: id, value: days) in all.entries) {
    final createdAt = swapTimestamps[id];
    if (createdAt == null || days is! Map<String, Object?>) {
      rejected[id] = days;
      continue;
    }
    try {
      records.addAll([
        for (final MapEntry(key: iso, value: ids) in days.entries)
          _legacyRecord(id, iso, ids, createdAt),
      ]);
    } on FormatException {
      rejected[id] = days;
    }
  }
  return (
    records: records,
    rejectedJson: rejected.isEmpty ? null : jsonEncode(rejected),
  );
}

SwapApplicationRecord _legacyRecord(
  String id,
  String iso,
  Object? ids,
  int createdAt,
) {
  final date = CivilDate.parse(iso);
  if (date.toIso() != iso ||
      (ids != null && (ids is! List || ids.any((id) => id is! String)))) {
    throw const FormatException('Invalid swap application');
  }
  return SwapApplicationRecord(
    swapId: id,
    date: date,
    previousShiftTypeIds: ids == null
        ? null
        : List<String>.unmodifiable(ids as List),
    createdAt: createdAt,
  );
}

/// At most one applied swap per calendar and day, as the database requires
/// (`idx_swap_applications_day`). Used where records arrive that the app did
/// not write itself: the v7 setting and backup files.
///
/// The swaps are taken in order of their earliest record ([createdAt], then
/// id). A swap whose days are all free keeps every record; one that shares
/// a day with a swap already kept is dropped **as a whole**, since taking
/// only some of its days off the calendar would be unsafe. A record whose
/// swap has no known calendar is kept (the caller rejects it).
({List<SwapApplicationRecord> kept, List<SwapApplicationRecord> dropped})
keepOneSwapPerDay(
  Iterable<SwapApplicationRecord> records,
  Map<String, String> calendarOfSwap,
) {
  final bySwap = <String, List<SwapApplicationRecord>>{};
  for (final record in records) {
    (bySwap[record.swapId] ??= []).add(record);
  }
  int firstWrite(List<SwapApplicationRecord> list) =>
      list.map((r) => r.createdAt).reduce((a, b) => a < b ? a : b);
  final order = bySwap.keys.toList()
    ..sort((a, b) {
      final byTime = firstWrite(bySwap[a]!).compareTo(firstWrite(bySwap[b]!));
      return byTime != 0 ? byTime : a.compareTo(b);
    });
  final claimed = <(String, CivilDate)>{};
  final kept = <SwapApplicationRecord>[];
  final dropped = <SwapApplicationRecord>[];
  for (final id in order) {
    final swapRecords = bySwap[id]!;
    final calendar = calendarOfSwap[id];
    if (calendar == null) {
      kept.addAll(swapRecords);
      continue;
    }
    final days = {for (final r in swapRecords) (calendar, r.date)};
    if (days.any(claimed.contains)) {
      dropped.addAll(swapRecords);
    } else {
      claimed.addAll(days);
      kept.addAll(swapRecords);
    }
  }
  return (kept: kept, dropped: dropped);
}

/// The records [keepOneSwapPerDay] dropped, as the value of a recovery
/// setting ([availableSwapApplicationRecoveryKey]): nothing is lost.
String encodeOverlappingSwapApplications(List<SwapApplicationRecord> records) =>
    jsonEncode({
      'overlapping': [
        for (final record in records)
          {
            'swapId': record.swapId,
            'date': record.date.toIso(),
            'previousShiftTypeIds': record.previousShiftTypeIds,
            'createdAt': record.createdAt,
            if (record.appliedOverride case final override?)
              'appliedOverride': override.shiftTypeIds,
          },
      ],
    });
