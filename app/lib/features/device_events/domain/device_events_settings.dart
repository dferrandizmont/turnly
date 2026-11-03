import 'package:collection/collection.dart';

/// Which calendars of the phone are shown next to the shifts (Ajustes). One
/// JSON row of the `settings` table, key `deviceEvents` (see
/// `DeviceEventsRepository`).
///
/// Only ids: they are the numbers this phone's calendar app gave out, so the
/// whole row is a **device** setting and never travels in a backup
/// (`isDeviceSetting`). Nothing chosen means the feature is off.
class DeviceEventsSettings {
  const DeviceEventsSettings({this.calendarIds = const []});

  /// Nothing chosen: nothing from the phone is shown.
  static const DeviceEventsSettings none = DeviceEventsSettings();

  /// Ids of the phone's calendars, in the order the person chose them.
  final List<String> calendarIds;

  bool get isOn => calendarIds.isNotEmpty;

  DeviceEventsSettings copyWith({List<String>? calendarIds}) =>
      DeviceEventsSettings(calendarIds: calendarIds ?? this.calendarIds);

  Map<String, Object?> toJson() => {'calendarIds': calendarIds};

  /// Reads what [toJson] wrote. Anything unreadable falls back to nothing
  /// chosen: a bad row never blocks the app and never shows a calendar the
  /// person did not pick. The ids keep their order and repeats are dropped
  /// (an empty or repeated entry can only come from a hand-edited row).
  factory DeviceEventsSettings.fromJson(Map<String, Object?> json) {
    final raw = json['calendarIds'];
    final ids = <String>[];
    if (raw is List) {
      for (final id in raw) {
        if (id is String && id.isNotEmpty && !ids.contains(id)) ids.add(id);
      }
    }
    return DeviceEventsSettings(calendarIds: ids);
  }

  @override
  bool operator ==(Object other) =>
      other is DeviceEventsSettings &&
      const ListEquality<String>().equals(other.calendarIds, calendarIds);

  @override
  int get hashCode => const ListEquality<String>().hash(calendarIds);

  @override
  String toString() => 'DeviceEventsSettings($calendarIds)';
}
