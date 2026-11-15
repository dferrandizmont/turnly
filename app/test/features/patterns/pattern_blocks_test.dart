import 'dart:math';

import 'package:cuadrante/features/patterns/domain/pattern_blocks.dart';
import 'package:flutter_test/flutter_test.dart';

PatternBlock block(String id, int days) =>
    PatternBlock(shiftIds: id.isEmpty ? [] : [id], days: days);

void main() {
  test('compress respects order, empty days and explicit Libre', () {
    final steps = <List<String>>[
      [],
      [],
      ['rest'],
      ['M', 'T'],
      ['M', 'T'],
      ['T', 'M'],
    ];
    final blocks = compressSteps(steps);
    expect(blocks.map((b) => b.days), [2, 1, 2, 1]);
    expect(expandBlocks(blocks), steps);
    expect(compressSteps([]), isEmpty);
  });

  test('round trip for seeded random sequences, including long cycles', () {
    final random = Random(3614);
    const choices = <List<String>>[
      [],
      ['rest'],
      ['M'],
      ['M', 'T'],
      ['T', 'M'],
    ];
    for (var trial = 0; trial < 200; trial++) {
      final steps = [
        for (var day = 0, n = random.nextInt(800); day < n; day++)
          choices[random.nextInt(choices.length)],
      ];
      expect(expandBlocks(compressSteps(steps)), steps, reason: 'trial $trial');
    }
  });

  test('block owns immutable ids, value equality and a positive duration', () {
    final ids = ['M', 'T'];
    final original = PatternBlock(shiftIds: ids, days: 2);
    ids.clear();
    expect(original.shiftIds, ['M', 'T']);
    expect(() => original.shiftIds.add('N'), throwsUnsupportedError);
    expect(original, PatternBlock(shiftIds: ['M', 'T'], days: 2));
    expect(
      original.hashCode,
      PatternBlock(shiftIds: ['M', 'T'], days: 2).hashCode,
    );
    expect(() => block('M', 0), throwsArgumentError);
    expect(() => block('M', -1), throwsArgumentError);
  });

  test('all edits preserve the input and return normal immutable blocks', () {
    final blocks = [block('M', 3), block('', 2), block('rest', 1)];
    final before = [...blocks];
    expect(setBlockDays(blocks, 0, 5).blocks, [
      block('M', 5),
      ...blocks.skip(1),
    ]);
    expect(insertBlock(blocks, 1, block('N', 2)).blocks, [
      blocks[0],
      block('N', 2),
      ...blocks.skip(1),
    ]);
    expect(insertBlock([], 0, block('N', 1)).blocks, [block('N', 1)]);
    expect(removeBlock(blocks, 1).blocks, [blocks[0], blocks[2]]);
    expect(removeBlock([blocks[0]], 0).blocks, isEmpty);
    expect(moveBlock(blocks, 0, 1).blocks, [blocks[1], blocks[0], blocks[2]]);
    expect(moveBlock(blocks, 2, 1).blocks, [blocks[0], blocks[2], blocks[1]]);
    expect(duplicateBlock(blocks, 0).blocks, [blocks[0], ...blocks]);
    final split = splitBlock(blocks, 0, 1).blocks;
    expect(split, [block('M', 1), block('M', 2), ...blocks.skip(1)]);
    expect(expandBlocks(split), expandBlocks(blocks));
    expect(blocks, before);
    expect(() => split.clear(), throwsUnsupportedError);
  });

  test('repeatFrom counts the original and repeats only the tail', () {
    final blocks = [block('N', 1), block('M', 2), block('M', 1)];
    expect(repeatFrom(blocks, 1, 1).blocks, blocks);
    final repeated = repeatFrom(blocks, 1, 3).blocks;
    expect(repeated, [
      blocks[0],
      for (var i = 0; i < 3; i++) ...blocks.skip(1),
    ]);
    expect(compressSteps(expandBlocks(repeated)), [
      block('N', 1),
      block('M', 9),
    ]);
    expect(repeatFrom(blocks, 0, 2).blocks, [...blocks, ...blocks]);
    expect(repeatFrom(blocks, 2, 3).blocks, [
      blocks[0],
      blocks[1],
      blocks[2],
      blocks[2],
      blocks[2],
    ]);
  });

  test('371 allowed; over-limit edits keep the original contents', () {
    expect(maxPatternCycleDays, 371);
    final blocks = [block('M', 370), block('N', 1)];
    expect(exceedsPatternCycleLimit(blocks), isFalse);
    expect(setBlockDays(blocks, 0, 370).exceedsLimit, isFalse);
    final rejected = [
      setBlockDays(blocks, 0, 371),
      insertBlock(blocks, 0, block('', 1)),
      duplicateBlock(blocks, 1),
      repeatFrom(blocks, 1, 2),
      repeatFrom(blocks, 0, 1000000000),
    ];
    for (final edit in rejected) {
      expect(edit.exceedsLimit, isTrue);
      expect(edit.requestedDays, greaterThan(371));
      expect(edit.blocks, blocks);
    }
    expect(repeatFrom([block('M', 7)], 0, 53).requestedDays, 371);
    expect(repeatFrom([block('M', 7)], 0, 53).exceedsLimit, isFalse);
    final long = [block('M', 500)];
    expect(expandBlocks(long), hasLength(500));
    expect(setBlockDays(long, 0, 371).exceedsLimit, isFalse);
  });

  test('invalid arguments fail without mutating the draft', () {
    final blocks = [block('M', 2)];
    expect(() => setBlockDays(blocks, 0, 0), throwsArgumentError);
    expect(() => insertBlock(blocks, 2, block('N', 1)), throwsRangeError);
    expect(() => removeBlock(blocks, -1), throwsRangeError);
    expect(() => moveBlock(blocks, 0, 1), throwsRangeError);
    expect(() => splitBlock(blocks, 0, 0), throwsRangeError);
    expect(() => splitBlock(blocks, 0, 2), throwsRangeError);
    expect(() => splitBlock([block('M', 1)], 0, 1), throwsRangeError);
    expect(() => repeatFrom(blocks, 0, 0), throwsArgumentError);
    expect(() => repeatFrom(blocks, 1, 2), throwsRangeError);
    expect(blocks, [block('M', 2)]);
  });
}
