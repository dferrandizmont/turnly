import 'package:collection/collection.dart';

/// Builder limit only. Stored/imported patterns and the engine have no such cap.
const int maxPatternCycleDays = 371;
const _idsEquality = ListEquality<String>();

/// Consecutive identical days. Empty [shiftIds] means no shift, not Libre.
class PatternBlock {
  PatternBlock({required List<String> shiftIds, required this.days})
    : shiftIds = List.unmodifiable(shiftIds) {
    if (days < 1) throw ArgumentError.value(days, 'days', 'must be positive');
  }

  final List<String> shiftIds;
  final int days;

  @override
  bool operator ==(Object other) =>
      other is PatternBlock &&
      days == other.days &&
      _idsEquality.equals(shiftIds, other.shiftIds);

  @override
  int get hashCode => Object.hash(days, _idsEquality.hash(shiftIds));
}

List<PatternBlock> compressSteps(List<List<String>> steps) {
  final blocks = <PatternBlock>[];
  for (final step in steps) {
    if (blocks.isNotEmpty && _idsEquality.equals(blocks.last.shiftIds, step)) {
      final last = blocks.removeLast();
      blocks.add(PatternBlock(shiftIds: last.shiftIds, days: last.days + 1));
    } else {
      blocks.add(PatternBlock(shiftIds: step, days: 1));
    }
  }
  return List.unmodifiable(blocks);
}

List<List<String>> expandBlocks(List<PatternBlock> blocks) =>
    List.unmodifiable([
      for (final block in blocks)
        for (var day = 0; day < block.days; day++) block.shiftIds,
    ]);

int patternCycleDays(List<PatternBlock> blocks) =>
    blocks.fold(0, (days, block) => days + block.days);

bool exceedsPatternCycleLimit(List<PatternBlock> blocks) =>
    patternCycleDays(blocks) > maxPatternCycleDays;

/// A rejected edit returns the original contents and the attempted length,
/// allowing the UI to explain the limit without losing the draft.
class PatternBlockEdit {
  PatternBlockEdit._(List<PatternBlock> blocks, this.requestedDays)
    : blocks = List.unmodifiable(blocks);

  final List<PatternBlock> blocks;
  final int requestedDays;
  bool get exceedsLimit => requestedDays > maxPatternCycleDays;
}

PatternBlockEdit _edit(
  List<PatternBlock> before,
  int requestedDays,
  List<PatternBlock> Function() build,
) => PatternBlockEdit._(
  requestedDays > maxPatternCycleDays ? before : build(),
  requestedDays,
);

PatternBlockEdit setBlockDays(List<PatternBlock> blocks, int index, int days) {
  final replacement = PatternBlock(
    shiftIds: blocks[index].shiftIds,
    days: days,
  );
  return _edit(
    blocks,
    patternCycleDays(blocks) - blocks[index].days + days,
    () {
      return [...blocks]..[index] = replacement;
    },
  );
}

/// Insert before [index]; `blocks.length` appends.
PatternBlockEdit insertBlock(
  List<PatternBlock> blocks,
  int index,
  PatternBlock block,
) {
  RangeError.checkValueInInterval(index, 0, blocks.length, 'index');
  return _edit(blocks, patternCycleDays(blocks) + block.days, () {
    return [...blocks]..insert(index, block);
  });
}

PatternBlockEdit removeBlock(List<PatternBlock> blocks, int index) {
  final days = blocks[index].days;
  return _edit(blocks, patternCycleDays(blocks) - days, () {
    return [...blocks]..removeAt(index);
  });
}

/// Moves a block to its final index. Up/down use `index - 1` / `index + 1`.
PatternBlockEdit moveBlock(List<PatternBlock> blocks, int index, int toIndex) {
  final block = blocks[index];
  RangeError.checkValidIndex(toIndex, blocks, 'toIndex');
  return _edit(blocks, patternCycleDays(blocks), () {
    return [...blocks]
      ..removeAt(index)
      ..insert(toIndex, block);
  });
}

PatternBlockEdit duplicateBlock(List<PatternBlock> blocks, int index) =>
    insertBlock(blocks, index + 1, blocks[index]);

/// Splits after [afterDays] days (1 through days - 1), preserving the sequence.
PatternBlockEdit splitBlock(
  List<PatternBlock> blocks,
  int index,
  int afterDays,
) {
  final block = blocks[index];
  RangeError.checkValueInInterval(afterDays, 1, block.days - 1, 'afterDays');
  return _edit(
    blocks,
    patternCycleDays(blocks),
    () => [
      ...blocks.take(index),
      PatternBlock(shiftIds: block.shiftIds, days: afterDays),
      PatternBlock(shiftIds: block.shiftIds, days: block.days - afterDays),
      ...blocks.skip(index + 1),
    ],
  );
}

/// Replaces the tail with [totalTimes] copies, including the original.
/// No persistent groups and no implicit merging of adjacent blocks.
PatternBlockEdit repeatFrom(
  List<PatternBlock> blocks,
  int fromIndex,
  int totalTimes,
) {
  RangeError.checkValidIndex(fromIndex, blocks, 'fromIndex');
  if (totalTimes < 1) {
    throw ArgumentError.value(totalTimes, 'totalTimes', 'must be positive');
  }
  final tail = blocks.sublist(fromIndex);
  final days =
      patternCycleDays(blocks) + patternCycleDays(tail) * (totalTimes - 1);
  return _edit(
    blocks,
    days,
    () => [
      ...blocks.take(fromIndex),
      for (var time = 0; time < totalTimes; time++) ...tail,
    ],
  );
}
