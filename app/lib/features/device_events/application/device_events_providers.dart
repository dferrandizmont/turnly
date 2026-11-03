import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../calendar_export/application/device_calendar_providers.dart';
import '../../calendar_export/domain/device_calendar_api.dart';
import '../../schedule/domain/civil_date.dart';
import '../data/device_events_reader.dart';
import '../data/device_events_repository.dart';
import '../domain/device_event_day.dart';
import '../domain/device_event_month.dart';
import '../domain/device_events_permission.dart';
import '../domain/device_events_settings.dart';
import 'device_events.dart';

final deviceEventsRepositoryProvider = Provider<DeviceEventsRepository>(
  (ref) => DeviceEventsRepository(ref.watch(appDatabaseProvider)),
);

/// The calendars of the phone the person chose (Ajustes). Nothing chosen means
/// the feature is off.
class DeviceEventsSettingsController
    extends AsyncNotifier<DeviceEventsSettings> {
  @override
  Future<DeviceEventsSettings> build() =>
      ref.watch(deviceEventsRepositoryProvider).load();

  /// Replaces the chosen calendars. The ids keep their order and repeats are
  /// dropped; an empty list turns the feature off.
  Future<void> setCalendars(Iterable<String> calendarIds) async {
    final chosen = <String>[];
    for (final id in calendarIds) {
      if (id.isNotEmpty && !chosen.contains(id)) chosen.add(id);
    }
    final next = DeviceEventsSettings(calendarIds: List.unmodifiable(chosen));
    await ref.read(deviceEventsRepositoryProvider).save(next);
    if (ref.mounted) state = AsyncData(next);
    // What was read was read with the old choice: the screen asks again.
    ref.invalidate(deviceEventsProvider);
  }

  /// Shows none of the phone's calendars.
  Future<void> clear() => setCalendars(const []);
}

final deviceEventsSettingsProvider =
    AsyncNotifierProvider<DeviceEventsSettingsController, DeviceEventsSettings>(
      DeviceEventsSettingsController.new,
    );

/// The calendars the person can choose, Turnly's own left out. Empty when the
/// permission is not granted (nothing is asked here: only read).
final deviceEventsCalendarsProvider =
    FutureProvider.autoDispose<List<DeviceCalendarInfo>>((ref) async {
      final api = ref.watch(deviceCalendarApiProvider);
      if (await api.access() != CalendarAccess.granted) return const [];
      return selectableCalendars(api);
    });

/// How the calendar permission stands, as the card shows it. Reading only:
/// the screen's button asks for it.
final deviceEventsPermissionProvider =
    FutureProvider.autoDispose<DeviceEventsPermission>((ref) async {
      final api = ref.watch(deviceCalendarApiProvider);
      final access = await api.access();
      if (access != CalendarAccess.granted) {
        return deviceEventsPermissionOf(access, hasCalendars: false);
      }
      final calendars = await ref.watch(deviceEventsCalendarsProvider.future);
      return deviceEventsPermissionOf(
        access,
        hasCalendars: calendars.isNotEmpty,
      );
    });

/// The cache of the phone's events, one month at a time. The screen calls
/// `refreshDeviceEvents` when the app comes back to the front; tests override
/// [deviceCalendarApiProvider] and the settings row.
final deviceEventsProvider = Provider<DeviceEvents>(
  (ref) => DeviceEvents(
    api: ref.watch(deviceCalendarApiProvider),
    loadSettings: () => ref.read(deviceEventsRepositoryProvider).load(),
  ),
);

/// The phone's events of the month of [dayInMonth], by day. Kept while the
/// screen shows it.
final deviceEventMonthProvider = FutureProvider.autoDispose
    .family<DeviceEventMonth, CivilDate>(
      (ref, dayInMonth) => ref.watch(deviceEventsProvider).month(dayInMonth),
    );

/// The phone's events of [date] alone.
final deviceEventDayProvider = FutureProvider.autoDispose
    .family<DeviceEventDay, CivilDate>(
      (ref, date) => ref.watch(deviceEventsProvider).day(date),
    );

/// The phone's events of a range of days, `(from, to)` both included. Only the
/// days with something come back, in order; the months it spans are read (and
/// kept) one by one.
final deviceEventRangeProvider = FutureProvider.autoDispose
    .family<List<DeviceEventDay>, (CivilDate, CivilDate)>(
      (ref, range) => ref.watch(deviceEventsProvider).range(range.$1, range.$2),
    );

/// Forgets the phone's events already read and reads again what is on screen.
///
/// The screen calls it when the app comes back to the front: the phone's
/// calendar may have changed while it was away (and the person may have
/// granted the permission in the system settings in the meantime). Nothing is
/// read at start-up.
void refreshDeviceEvents(WidgetRef ref) {
  ref.read(deviceEventsProvider).refresh();
  ref.invalidate(deviceEventsCalendarsProvider);
  ref.invalidate(deviceEventsPermissionProvider);
  ref.invalidate(deviceEventMonthProvider);
  ref.invalidate(deviceEventDayProvider);
  ref.invalidate(deviceEventRangeProvider);
}

/// Shows the system calendar question and reloads the state with the answer.
/// The screen's button calls it when the person turns this on, never at
/// start-up.
///
/// The answer is typed ([CalendarPromptOutcome]): Android answers «denied» the
/// first time although the question can be asked again, so only reading the
/// permission back tells the two cases apart (`askForAccess`). A
/// [CalendarApiException] from the phone's calendar is left to the screen to
/// show as a problem, as the import and the export do.
Future<CalendarPromptOutcome> requestDeviceEventsPermission(
  WidgetRef ref,
) async {
  final outcome = await ref.read(deviceCalendarApiProvider).askForAccess();
  refreshDeviceEvents(ref);
  return outcome;
}
