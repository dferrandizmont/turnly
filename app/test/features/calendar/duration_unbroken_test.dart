import 'dart:ui';

import 'package:cuadrante/features/calendar/presentation/shift_format.dart';
import 'package:cuadrante/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('es'));

  test('each number is glued to its unit (0.12.1 QA, C1: «10» / «h»)', () {
    expect(durationTextUnbroken(l10n, 600), '10\u00A0h');
    expect(durationTextUnbroken(l10n, 45), '45\u00A0min');
    expect(durationTextUnbroken(l10n, 220), '3\u00A0h 40\u00A0min');
    // Only number and unit stick together: «1 d» and «8 h» can still part.
    expect(durationTextUnbroken(l10n, 1920), '1\u00A0d 8\u00A0h');
  });

  test('it reads the same as durationText', () {
    for (final minutes in [1, 59, 60, 61, 600, 1440, 1500, 2880]) {
      expect(
        durationTextUnbroken(l10n, minutes).replaceAll('\u00A0', ' '),
        durationText(l10n, minutes),
      );
    }
  });
}
