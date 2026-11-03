import 'package:flutter/material.dart';

import '../../../core/format/app_date_format.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../calendars/presentation/calendar_dot.dart';
import '../domain/device_event_day.dart';
import 'device_events_format.dart';

/// One appointment of the phone: a dot with the colour of its calendar, its
/// title and, under it, its time and the calendar it comes from.
///
/// The colour only helps: the time and the title are always there, and the
/// reader of screen says the calendar too (never colour alone).
class DeviceEventRow extends StatelessWidget {
  const DeviceEventRow({super.key, required this.event});

  final DeviceDayEvent event;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    final format = AppDateFormat.of(context);
    final time = deviceEventTimeText(l10n, format, event);
    final calendar = event.calendarName.trim();

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: deviceEventSemantics(l10n, format, event),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Sp.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: Sp.xs),
              child: CalendarDot(
                colorValue: event.colorValue ?? colors.accent.toARGB32(),
              ),
            ),
            const SizedBox(width: Sp.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    // A strong body, not the bigger `bodyStrong` (the style of
                    // the big hours): the appointment reads as a title without
                    // shouting over the note and the shift of the day.
                    style: type.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: Sp.hair),
                  Row(
                    children: [
                      // The hours are never cut: at a large text size they
                      // shrink to fit in their half, and the calendar gives
                      // way first. Neither ever overflows the row.
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            time,
                            maxLines: 1,
                            style: AppTypography.tabular(
                              type.caption.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (calendar.isNotEmpty)
                        Flexible(
                          child: Text(
                            ' · $calendar',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: type.caption.copyWith(
                              color: colors.textMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The appointments of one day: the all-day ones first, then the ones with
/// an hour, in order (the day model already sorts them).
class DeviceEventList extends StatelessWidget {
  const DeviceEventList({super.key, required this.day});

  final DeviceEventDay day;

  @override
  Widget build(BuildContext context) {
    if (day.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final event in day.events)
          DeviceEventRow(
            key: ValueKey('device-event-${event.instanceId}'),
            event: event,
          ),
      ],
    );
  }
}
