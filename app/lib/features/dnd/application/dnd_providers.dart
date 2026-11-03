import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/diagnostics/crash_reporting.dart';
import '../../../core/providers.dart';
import '../../alarms/application/alarm_providers.dart';
import '../../alarms/data/alarm_scheduler.dart' show AsyncMutex;
import '../../calendar/application/schedule_controller.dart';
import '../../calendars/application/primary_schedule.dart';
import '../data/dnd_channel.dart';
import '../data/dnd_settings_repository.dart';
import '../domain/dnd_settings.dart';
import 'dnd_sync.dart';

/// The channel of the silence windows: Android only (iOS: Focus is not
/// programmable by apps, so there is nothing to silence). Tests override it
/// with a [FakeDndChannel].
final dndChannelProvider = Provider<DndChannel>(
  (ref) => Platform.isAndroid ? PlatformDndChannel() : const NoDndChannel(),
);

/// Whether this platform has silence windows at all (Android). iOS has no
/// programmable Focus, so the screens hide the whole feature there.
final dndSupportedProvider = Provider<bool>(
  (ref) => ref.watch(dndChannelProvider).supported,
);

final dndSettingsRepositoryProvider = Provider<DndSettingsRepository>(
  (ref) => DndSettingsRepository(ref.watch(appDatabaseProvider)),
);

/// The stored silence settings. [DndSettingsController.save] persists them;
/// the host reschedules when they change.
class DndSettingsController extends AsyncNotifier<DndSettings> {
  // Edits are read-modify-write: one at a time, or two quick taps would both
  // start from the same stored value and the second would undo the first.
  final AsyncMutex _edits = AsyncMutex();

  @override
  Future<DndSettings> build() =>
      ref.watch(dndSettingsRepositoryProvider).load();

  Future<void> save(DndSettings settings) async {
    await ref.read(dndSettingsRepositoryProvider).save(settings);
    state = AsyncData(settings);
  }

  /// Applies [change] to the latest settings and saves the result.
  Future<void> edit(DndSettings Function(DndSettings current) change) =>
      _edits.run(() async {
        final current = state.value ?? await future;
        final next = change(current);
        if (next != current) await save(next);
      });

  /// The global switch: with it off nothing is silenced.
  Future<void> setEnabled(bool enabled) =>
      edit((s) => s.copyWith(enabled: enabled));

  /// The interruption filter the phone is put in while a shift lasts.
  Future<void> setFilter(DndFilter filter) =>
      edit((s) => s.copyWith(filter: filter));

  /// Replaces the choices of one shift type.
  Future<void> setShiftType(String shiftTypeId, DndTypeSettings settings) =>
      edit((s) => s.withShiftType(shiftTypeId, settings));
}

final dndSettingsProvider =
    AsyncNotifierProvider<DndSettingsController, DndSettings>(
      DndSettingsController.new,
    );

/// What the system lets the app do with the interruption filter right now.
/// Never prompts: the permission is given in the system settings
/// ([DndChannel.openPermissionSettings]).
final dndPermissionProvider = FutureProvider.autoDispose<DndPermission>((
  ref,
) async {
  return ref.watch(dndChannelProvider).permissionStatus();
});

/// The sync that keeps the device in step with the plan. It reads the
/// settings and the schedule fresh on every run, so it never plans from a
/// stale copy.
final dndSyncProvider = Provider<DndSync>((ref) {
  final sync = DndSync(
    channel: ref.watch(dndChannelProvider),
    loadSettings: () => ref.read(dndSettingsRepositoryProvider).load(),
    readSchedule: () => readPrimarySchedule(ref),
    now: ref.watch(clockProvider),
    // The horizon of the shift alarms: both run out at the same time.
    horizonDays: () async =>
        (await ref.read(alarmSettingsRepositoryProvider).load()).horizonDays,
    onError: (error, stack) {
      if (!ref.mounted) return;
      final reporter = ref.read(crashReporterProvider);
      unawaited(
        reporter
            .record(redactError(error), stack, fatal: false)
            .catchError((Object _) {}),
      );
    },
  );
  ref.onDispose(sync.dispose);
  return sync;
});

/// Keeps the silence windows of the device in step with the app (the host
/// watches it). It replans when:
/// - the schedule changes (a day painted, a rotation changed);
/// - the silence settings change;
/// - the clock moves (the zone or the time): the windows are wall-clock
///   times, so they have to be placed again on the new zone.
///
/// It also runs a first pass when it is created (the app starts), so the
/// windows of a phone that was off for a while are armed again.
final dndSyncRunnerProvider = Provider<void>((ref) {
  final sync = ref.watch(dndSyncProvider);

  ref.listen(scheduleControllerProvider, (previous, next) {
    // Only a different schedule matters (not undo/redo availability).
    if (!identical(previous?.schedule, next.schedule)) {
      sync.requestResync();
    }
  });
  ref.listen(dndSettingsProvider, (previous, next) {
    final before = previous?.asData?.value;
    final after = next.asData?.value;
    if (after != null && before != null && before != after) {
      sync.resync();
    }
  });
  // H-T11-4: the zone or the time changed while the app is alive. The
  // windows are wall-clock times, so they have to be placed again.
  final clock = ref.watch(alarmSystemProvider).clockChanges;
  final subscription = clock.listen((_) => sync.resync());
  ref.onDispose(subscription.cancel);

  unawaited(sync.resync());
});
