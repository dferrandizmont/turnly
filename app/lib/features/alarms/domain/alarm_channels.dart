import 'alarm_payload.dart';
import 'alarm_planner.dart' show fnv31;

/// Android channel of the shift alarms with the default sound.
const String defaultAlarmChannelId = 'shift_alarms';

/// Android channel of the note reminders (docs/alarmas.md).
const String reminderChannelId = 'note_reminders';

/// Prefix of the channels that carry a custom sound: `shift_alarm_<hash>`.
/// Deliberately not a prefix of [defaultAlarmChannelId] (`shift_alarms`
/// has an `s` where this has an underscore), so the cleanup of unused sound
/// channels can never touch the default one.
const String alarmSoundChannelPrefix = 'shift_alarm_';

/// An Android channel fixes its sound when it is created and the app cannot
/// change it afterwards, so every distinct sound gets its own channel. The id
/// is the FNV-1a hash of the sound URI in 8 hex digits: the same URI always
/// gives the same channel, on every run and device.
///
/// `null` (no custom sound) is the default channel.
String alarmSoundChannelId(String? sound) => sound == null
    ? defaultAlarmChannelId
    : '$alarmSoundChannelPrefix${fnv31(sound).toRadixString(16).padLeft(8, '0')}';

/// The sound a shift alarm really rings with: [sound] unless it is one of
/// the [unavailable] ones (the file was deleted, the media was removed), in
/// which case the default (`null`). A missing sound never reaches a channel.
String? effectiveAlarmSound(String? sound, Set<String> unavailable) =>
    sound == null || unavailable.contains(sound) ? null : sound;

/// Android channel of the mid-shift pause notices (docs/alarmas.md).
const String pauseChannelId = 'break_alerts';

/// Whether an alarm of [kind] is a plain notification (notification volume,
/// default tone, no custom sound) rather than an alarm: the reminder of a
/// note, the renewal notice (A1), which reuses the reminders' channel, and
/// the pause notice, which has its own.
bool isNoticeKind(AlarmKind kind) =>
    kind == AlarmKind.reminder ||
    kind == AlarmKind.renewal ||
    kind == AlarmKind.pause;

/// The channel an alarm of [kind] rings on. Reminders and the renewal notice
/// share their own channel (notification volume, default tone), the pause
/// notice has another one; the alarms before a shift and the evening-before
/// ones use the channel of their [sound] (already resolved with
/// [effectiveAlarmSound]).
String alarmChannelIdFor(AlarmKind kind, String? sound) => switch (kind) {
  AlarmKind.pause => pauseChannelId,
  AlarmKind.reminder || AlarmKind.renewal => reminderChannelId,
  _ => alarmSoundChannelId(sound),
};

/// The channels of [existing] that carry a custom sound and that none of the
/// [inUseSounds] needs any more: the ones to delete. Channels of the default
/// alarm, the reminders and anything else (other plugins, future channels)
/// are never listed.
Set<String> staleSoundChannelIds(
  Iterable<String> existing,
  Iterable<String> inUseSounds,
) {
  final wanted = {for (final sound in inUseSounds) alarmSoundChannelId(sound)};
  return {
    for (final id in existing)
      if (id.startsWith(alarmSoundChannelPrefix) && !wanted.contains(id)) id,
  };
}
