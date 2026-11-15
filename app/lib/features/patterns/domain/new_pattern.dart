import 'package:uuid/uuid.dart';

import '../../schedule/domain/pattern.dart';

/// The caller supplies the ARB formatter (patternCopyName) for suffixes.
/// A new id and deeply immutable steps always leave the source pattern intact.
Pattern createNewPattern({
  required List<List<String>> steps,
  required String name,
  required Iterable<String> existingNames,
  required String Function(String name, int number) copyName,
}) {
  final base = name.trim();
  if (base.isEmpty || steps.isEmpty) {
    throw ArgumentError('A pattern needs a name and at least one day');
  }
  final names = existingNames.map((name) => name.trim()).toSet();
  var proposed = base;
  var number = 2;
  while (names.contains(proposed)) {
    proposed = copyName(base, number++);
  }
  return Pattern(
    id: 'custom-${const Uuid().v4()}',
    name: proposed,
    steps: List.unmodifiable([
      for (final step in steps) List<String>.unmodifiable(step),
    ]),
  );
}
