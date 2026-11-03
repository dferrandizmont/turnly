import 'package:cuadrante/features/calendar/presentation/paint_feedback.dart';
import 'package:cuadrante/features/settings/application/preferences_controller.dart';
import 'package:cuadrante/features/settings/domain/preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// «Sonido al pintar» (UX · Extras visuales): the click of the system plays
/// only when the preference is on; the silent mode of the phone is kept (the
/// system sound is the one the platform plays, or none) and a device without a
/// sound never breaks the stroke.
void main() {
  for (final (enabled, expected) in [(false, 0), (true, 1)]) {
    testWidgets(
      '«Sonido al pintar» $enabled: $expected click(s) of the system',
      (tester) async {
        final calls = <MethodCall>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            calls.add(call);
            return null;
          },
        );
        addTearDown(() {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          );
        });

        // Pumps a minimal tree and runs `playPaintSound` on its real WidgetRef.
        late WidgetRef captured;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              initialPreferencesProvider.overrideWithValue(
                Preferences(paintSound: enabled),
              ),
            ],
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, _) {
                  captured = ref;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );
        await tester.pump();

        playPaintSound(captured);
        await tester.pump();
        await tester.idle();

        expect(
          calls.where((c) => c.method == 'SystemSound.play').length,
          expected,
        );
      },
    );
  }
}
