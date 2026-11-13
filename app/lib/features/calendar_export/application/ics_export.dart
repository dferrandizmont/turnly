import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/providers.dart';
import '../../calendar/application/schedule_controller.dart';
import '../../calendars/application/calendars_controller.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../domain/ics_events.dart';
import '../domain/ics_writer.dart';
import '../../../core/platform/share_origin.dart';

bool _zonesLoaded = false;

/// The zone named [id], or Europe/Madrid (the app's default zone) when the
/// id is unknown. Loads the time zone database the first time.
tz.Location icsLocation(String? id) {
  if (!_zonesLoaded) {
    tzdata.initializeTimeZones();
    _zonesLoaded = true;
  }
  if (id != null) {
    try {
      return tz.getLocation(id);
    } catch (_) {
      // Unknown id: the default below.
    }
  }
  return tz.getLocation('Europe/Madrid');
}

/// The phone's time zone, where the shift times are read before they are
/// written in UTC. Europe/Madrid when it cannot be read. Tests override it.
final icsTimeZoneProvider = Provider<Future<tz.Location> Function()>(
  (ref) => () async {
    try {
      return icsLocation((await FlutterTimezone.getLocalTimezone()).identifier);
    } catch (_) {
      return icsLocation(null);
    }
  },
);

/// Hands a written `.ics` file to the system share sheet («Guardar en
/// Archivos», mail, Drive...). Tests override it.
typedef IcsFileSender = Future<void> Function(File file);

Future<void> _shareIcs(File file) => SharePlus.instance.share(
  ShareParams(
    files: [XFile(file.path, mimeType: 'text/calendar')],
    sharePositionOrigin: shareOrigin(),
  ),
);

final icsFileSenderProvider = Provider<IcsFileSender>((ref) => _shareIcs);

/// Folder where the file is written before it is shared. Tests override it.
final icsExportDirectoryProvider = Provider<Future<Directory> Function()>(
  (ref) =>
      () async =>
          Directory('${(await getTemporaryDirectory()).path}/ics-export'),
);

/// What [exportIcsFile] needs to know about the export.
class IcsFileRequest {
  const IcsFileRequest({
    required this.from,
    required this.to,
    this.includeRest = false,
    this.includeAbsences = false,
  });

  final CivilDate from;
  final CivilDate to;
  final bool includeRest;

  /// With their names: it is the person's own file (the export screen warns
  /// about absences, off by default).
  final bool includeAbsences;
}

/// The `.ics` text for the calendar on screen, as [exportIcsFile] writes it.
Future<String> buildIcsFileText(Ref ref, IcsFileRequest request) async {
  final scheduleState = ref.read(scheduleControllerProvider);
  final location = await ref.read(icsTimeZoneProvider)();
  final calendarName = ref
      .read(calendarsControllerProvider)
      .value
      ?.calendars
      .where((c) => c.id == scheduleState.calendarId)
      .map((c) => c.name)
      .firstOrNull;
  final events = buildIcsEvents(
    scheduleState.schedule,
    calendarId: scheduleState.calendarId,
    from: request.from,
    to: request.to,
    location: location,
    includeRest: request.includeRest,
    absences: request.includeAbsences ? IcsAbsences.full : IcsAbsences.hidden,
  );
  return const IcsWriter().write(
    events: events,
    stamp: ref.read(clockProvider)(),
    calendarName: calendarName ?? 'Turnly',
  );
}

/// Writes the shifts of the calendar on screen in [request] to an `.ics`
/// file and opens the share sheet with it. The file is deleted once the
/// sheet returns: nothing stays behind, nothing leaves unless the person
/// picks where. Returns how many events the file has.
Future<int> exportIcsFile(Ref ref, IcsFileRequest request) async {
  final text = await buildIcsFileText(ref, request);
  final count = 'BEGIN:VEVENT'.allMatches(text).length;
  final dir = await ref.read(icsExportDirectoryProvider)();
  await dir.create(recursive: true);
  final file = File(
    '${dir.path}/turnly-${request.from.toIso()}_${request.to.toIso()}.ics',
  );
  await file.writeAsString(text, flush: true);
  try {
    await ref.read(icsFileSenderProvider)(file);
  } finally {
    try {
      await file.delete();
    } catch (_) {
      // Housekeeping only: the temporary folder is cleaned by the system.
    }
  }
  return count;
}

/// What the «Guardar como archivo .ics» button is doing.
enum IcsFileStatus { idle, running, done, failed }

class IcsFileController extends Notifier<IcsFileStatus> {
  @override
  IcsFileStatus build() => IcsFileStatus.idle;

  Future<void> export(IcsFileRequest request) async {
    if (state == IcsFileStatus.running) return;
    state = IcsFileStatus.running;
    try {
      await exportIcsFile(ref, request);
      if (ref.mounted) state = IcsFileStatus.done;
    } catch (_) {
      if (ref.mounted) state = IcsFileStatus.failed;
    }
  }
}

final icsFileControllerProvider =
    NotifierProvider.autoDispose<IcsFileController, IcsFileStatus>(
      IcsFileController.new,
    );
