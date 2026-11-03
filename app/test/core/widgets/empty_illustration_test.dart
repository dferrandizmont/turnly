import 'package:cuadrante/core/theme/app_theme.dart';
import 'package:cuadrante/core/widgets/empty_illustration.dart';
import 'package:cuadrante/core/widgets/empty_state.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Design 8.1B: the drawings of the empty states, made of the shift discs
/// and day cells of the app in the user's colours, with their codes.
Widget _app(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: brightness == Brightness.light
          ? AppTheme.light()
          : AppTheme.dark(),
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    );

ShiftType _shift(
  String id,
  String code,
  int color, {
  ShiftCategory? category,
}) => ShiftType(
  id: id,
  code: code,
  name: id,
  colorValue: color,
  category: category ?? ShiftCategory.work,
);

List<String> _codes(WidgetTester tester) => [
  for (final t in tester.widgetList<Text>(
    find.descendant(
      of: find.byType(EmptyIllustration),
      matching: find.byType(Text),
    ),
  ))
    t.data!,
];

void main() {
  for (final brightness in Brightness.values) {
    for (final kind in EmptyIllustrationKind.values) {
      testWidgets('${kind.name} draws in ${brightness.name} with the starting '
          'codes when there are no shifts', (tester) async {
        await tester.pumpWidget(
          _app(EmptyIllustration(kind: kind), brightness: brightness),
        );
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(ValueKey('empty-illustration-${kind.name}')),
          findsOneWidget,
        );
        final codes = _codes(tester);
        expect(codes, isNotEmpty);
        // Never colour alone: every chip carries a code (M, T or N).
        expect(codes.every(['M', 'T', 'N'].contains), isTrue, reason: '$codes');
      });
    }
  }

  testWidgets('takes the codes of the user, skipping Libre, and fills the '
      'rest', (tester) async {
    await tester.pumpWidget(
      _app(
        EmptyIllustration(
          shifts: [
            _shift('rest', 'L', 0xFFE4E4E7, category: ShiftCategory.rest),
            _shift('day', 'D12', 0xFF1C7ED6),
            _shift('guard', 'G', 0xFFE5484D),
          ],
        ),
      ),
    );
    expect(_codes(tester), ['D12', 'G', 'N']);
  });

  testWidgets('is hidden from screen readers and keeps its size at x2 text', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: _app(const EmptyIllustration(width: 160)),
      ),
    );
    expect(tester.getSize(find.byType(EmptyIllustration)).width, 160);
    expect(find.bySemanticsLabel('M'), findsNothing);
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  testWidgets('EmptyState shows the drawing instead of the icon disc', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const EmptyState(
          icon: Icons.inbox,
          illustration: EmptyIllustration(kind: EmptyIllustrationKind.backup),
          title: 'Todavía no hay ninguna copia',
        ),
      ),
    );
    expect(find.byType(EmptyIllustration), findsOneWidget);
    expect(find.byIcon(Icons.inbox), findsNothing);
    expect(find.text('Todavía no hay ninguna copia'), findsOneWidget);
  });
}
