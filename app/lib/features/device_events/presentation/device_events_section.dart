import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../schedule/domain/civil_date.dart';
import '../application/device_events_providers.dart';
import 'device_event_row.dart';

/// The appointments of the phone for [date], as a layer of the day detail
/// (`docs/ola3-pantallas.md`, U6): the name of the section and one row per
/// appointment, with its time.
///
/// Nothing is shown when the day has no appointments, or when the person has
/// not chosen any calendar of the phone: the detail of a day stays clean.
class DeviceEventsDaySection extends ConsumerWidget {
  const DeviceEventsDaySection({super.key, required this.date});

  final CivilDate date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    final day = ref.watch(deviceEventDayProvider(date)).value;
    if (day == null || day.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Sp.m),
        Semantics(
          header: true,
          child: Text(
            l10n.devEventsSectionTitle,
            key: const ValueKey('day-device-events-title'),
            style: type.label.copyWith(color: colors.textMuted),
          ),
        ),
        const SizedBox(height: Sp.xs),
        DeviceEventList(day: day),
      ],
    );
  }
}
