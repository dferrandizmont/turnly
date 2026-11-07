import 'package:cuadrante/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

/// A hint (the "Vacation" of the name of a balance, the "days" of an amount)
/// must not read as a typed value (QA 0.9.0, F6): it is `textMuted`, not the
/// near-white `textSecondary`, and still reaches AA on the field fill.
void main() {
  for (final (label, theme) in [
    ('light', AppTheme.light()),
    ('dark', AppTheme.dark()),
  ]) {
    test('the hint of a field is muted and readable in $label', () {
      final colors = theme.extension<AppColors>()!;
      final hint = theme.inputDecorationTheme.hintStyle!.color!;
      expect(hint, colors.textMuted);
      expect(hint, isNot(colors.textPrimary));
      expect(
        contrastRatio(hint, colors.surfaceMuted),
        greaterThanOrEqualTo(kTextContrast),
      );
    });
  }
}
