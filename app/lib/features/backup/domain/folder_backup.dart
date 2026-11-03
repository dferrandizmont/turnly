// The automatic copy to a folder the user picks (P10,
// docs/copia-de-seguridad.md, section 11): pure rules, no platform.

/// How many automatic copies the folder keeps (the newest ones). Files that
/// are not Turnly's automatic copies are never counted, read or deleted.
const int folderBackupKeep = 10;

/// Why a folder copy is attempted; each has its own minimum gap
/// ([FolderBackupPolicy]).
enum FolderBackupTrigger {
  /// The daily background task (WorkManager), or the app doing it for it.
  daily,

  /// A good automatic copy on the phone after changes (the app is open).
  change,

  /// The user asked for it ("Copiar ahora", a folder just chosen).
  manual,
}

/// When a folder copy is due.
class FolderBackupPolicy {
  const FolderBackupPolicy({
    this.dailyGap = const Duration(hours: 20),
    this.changeGap = const Duration(hours: 6),
    this.keep = folderBackupKeep,
  });

  /// The daily task skips when the folder got a copy (or was found up to date)
  /// this recently: WorkManager may run it early or twice.
  final Duration dailyGap;

  /// Changes in the app copy to the folder at most this often, so a long
  /// editing session does not push the older copies out of the rotation.
  final Duration changeGap;

  /// Copies kept in the folder.
  final int keep;

  /// The minimum gap for [trigger]; `null` (manual) means always.
  Duration? gapFor(FolderBackupTrigger trigger) => switch (trigger) {
    FolderBackupTrigger.daily => dailyGap,
    FolderBackupTrigger.change => changeGap,
    FolderBackupTrigger.manual => null,
  };

  /// Whether a copy for [trigger] is due, given the last time the folder got
  /// a copy or was found up to date. A last time "in the future" (the clock
  /// was moved back) is not trusted: the copy is due.
  bool isDue(
    FolderBackupTrigger trigger, {
    required DateTime? lastDoneAt,
    required DateTime now,
  }) {
    final gap = gapFor(trigger);
    if (gap == null || lastDoneAt == null) return true;
    if (lastDoneAt.isAfter(now)) return true;
    return now.difference(lastDoneAt) >= gap;
  }
}

/// Why a folder copy (or a check of the folder) did not work, in the terms the
/// user can act on.
enum FolderProblem {
  /// The app no longer holds the permission (revoked in the system settings,
  /// the app data was restored on another phone, the provider dropped it).
  revoked('revoked'),

  /// The folder is gone: deleted, moved, or its provider was uninstalled.
  missing('missing'),

  /// The folder does not take new files (read-only provider or folder).
  unwritable('unwritable'),

  /// No space where the folder lives (the phone or the cloud).
  noSpace('no_space'),

  /// A file over `BackupCodec.maxImportBytes` (or over `maxFileBytes` when it is
  /// not a container).
  tooLarge('too_large'),

  /// Anything else: written badly, unreadable back, provider error.
  failed('failed'),

  /// No folder access on this system (iOS, desktop, tests without a channel).
  unsupported('unsupported'),

  /// The app's own record of the folder copy cannot be read.
  damaged('damaged');

  const FolderProblem(this.code);

  /// The code on the channel and in the state file.
  final String code;

  /// The problem for a [code]; anything unknown is [failed].
  static FolderProblem fromCode(String? code) {
    for (final p in values) {
      if (p.code == code) return p;
    }
    return failed;
  }

  /// Whether the fix is choosing the folder again (rather than retrying).
  bool get needsNewFolder =>
      this == revoked ||
      this == missing ||
      this == unwritable ||
      this == damaged;
}

/// A folder operation that failed, with the reason.
class FolderBackupException implements Exception {
  const FolderBackupException(this.problem);

  final FolderProblem problem;

  @override
  String toString() => 'FolderBackupException(${problem.code})';
}

/// One plain file directly in the chosen folder.
class FolderFile {
  const FolderFile({
    required this.id,
    required this.name,
    required this.sizeBytes,
    this.modifiedAt,
  });

  /// Opaque document id of the provider: pass it back to read or delete.
  final String id;
  final String name;
  final int sizeBytes;

  /// As the provider reports it (informational; may be missing).
  final DateTime? modifiedAt;

  @override
  String toString() => 'FolderFile($name, $sizeBytes B)';
}

final RegExp _ownName = RegExp(
  r'^turnly-auto-(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})(?:-(\d{1,3}))?\.turnly$',
);

/// Whether [name] is one of Turnly's automatic folder copies. Only those are
/// rotated (and the Kotlin side checks the same rule before writing or
/// deleting): the user's own files in the folder are never touched.
bool isFolderBackupName(String name) => _ownName.hasMatch(name);

/// `turnly-auto-20261031-031000.turnly` (local time), with `-2`, `-3`... when
/// another copy has the same second. Different from the exports
/// (`turnly-2026-10-31-031000.turnly`) and from the copies on the phone, so
/// the rotation can never take a file the user put there.
String folderBackupFileName(DateTime at, {int counter = 1}) {
  final t = at.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  final stamp =
      '${t.year.toString().padLeft(4, '0')}${two(t.month)}${two(t.day)}-'
      '${two(t.hour)}${two(t.minute)}${two(t.second)}';
  return counter <= 1
      ? 'turnly-auto-$stamp.turnly'
      : 'turnly-auto-$stamp-$counter.turnly';
}

/// The order key of an own name: the moment (local, from the name) and the
/// counter; `null` for anything else.
({DateTime at, int counter})? folderBackupNameKey(String name) {
  final m = _ownName.firstMatch(name);
  if (m == null) return null;
  int g(int i) => int.parse(m.group(i)!);
  final at = DateTime(g(1), g(2), g(3), g(4), g(5), g(6));
  // A date that does not exist (month 13) rolls over in DateTime: not ours.
  if (at.year != g(1) || at.month != g(2) || at.day != g(3)) return null;
  return (at: at, counter: m.group(7) == null ? 1 : g(7));
}

/// A name for a copy at [at] that no file in [existing] has.
String freeFolderBackupName(DateTime at, Iterable<String> existing) {
  final taken = existing.toSet();
  for (var counter = 1; counter < 1000; counter++) {
    final name = folderBackupFileName(at, counter: counter);
    if (!taken.contains(name)) return name;
  }
  // A thousand copies in one second cannot happen; the provider dedups.
  return folderBackupFileName(at);
}

/// How far in the future a name's date may be and still count: a name dated
/// later was not written by this clock (another device, a planted file) and is
/// left out of the rotation and of "Probar", so it can neither push the real
/// copies out nor pass for the newest one.
const Duration folderBackupFutureSlack = Duration(days: 1);

/// Turnly's own copies in [files], newest first (by the moment in the name,
/// then the counter). Everything else is left out, and with [now] also the
/// names dated after `now + folderBackupFutureSlack`.
List<FolderFile> ownFolderCopies(Iterable<FolderFile> files, {DateTime? now}) {
  final limit = now?.add(folderBackupFutureSlack);
  final own = [
    for (final f in files)
      if (folderBackupNameKey(f.name) case final key?)
        if (limit == null || !key.at.isAfter(limit)) (file: f, key: key),
  ];
  own.sort((a, b) {
    final byTime = b.key.at.compareTo(a.key.at);
    return byTime != 0 ? byTime : b.key.counter.compareTo(a.key.counter);
  });
  return [for (final e in own) e.file];
}

/// The own copies to delete so that [keep] remain, never [keepId] (the copy
/// just written) whatever its name says. Names dated in the future (see
/// [ownFolderCopies]) are neither counted nor deleted.
List<FolderFile> folderCopiesToRotate(
  Iterable<FolderFile> files, {
  required int keep,
  required DateTime now,
  String? keepId,
}) {
  final own = ownFolderCopies(files, now: now);
  final kept = <String>{?keepId};
  final drop = <FolderFile>[];
  for (final f in own) {
    if (kept.contains(f.id)) continue;
    if (kept.length < keep) {
      kept.add(f.id);
    } else {
      drop.add(f);
    }
  }
  return drop;
}

/// What the app remembers about the folder copy: the folder, and how the last
/// attempts went. Kept in a small file of its own
/// (`folder_backup/state.json` in Application Support), never in the
/// database, so it never travels in a `.turnly` file and the background task
/// can write it without opening the database for writing.
class FolderBackupState {
  const FolderBackupState({
    this.uri,
    this.name,
    this.lastAttemptAt,
    this.lastSuccessAt,
    this.lastCheckedAt,
    this.lastFileName,
    this.lastFileId,
    this.lastFileSize,
    this.lastChecksum,
    this.lastProblem,
    this.lastProblemAt,
    this.damaged = false,
  });

  /// The state file exists but cannot be read: the screen says so (never a
  /// silent "no folder") and choosing the folder again writes a good one.
  const FolderBackupState.damaged() : this(damaged: true);

  /// The tree URI the system picker returned (persistable permission held),
  /// or `null`: no folder copy.
  final String? uri;

  /// The folder's name as the provider shows it ("Turnly", "Copias").
  final String? name;

  /// The newest attempt, whatever its end.
  final DateTime? lastAttemptAt;

  /// When the newest copy was written to the folder (UTC).
  final DateTime? lastSuccessAt;

  /// When the folder was last found up to date without writing (the data had
  /// not changed since [lastSuccessAt]).
  final DateTime? lastCheckedAt;

  /// The newest copy written: its name, the provider's document id, its size
  /// and the checksum of its data. "Probar" tests exactly that file, and "no
  /// changes" needs the same id, name and size still in the folder.
  final String? lastFileName;
  final String? lastFileId;
  final int? lastFileSize;
  final String? lastChecksum;

  /// Why the newest attempt failed, and when; `null` after a success.
  final FolderProblem? lastProblem;
  final DateTime? lastProblemAt;

  /// See [FolderBackupState.damaged].
  final bool damaged;

  bool get configured => uri != null;

  /// The later of [lastSuccessAt] and [lastCheckedAt]: what the gaps of the
  /// policy count from.
  DateTime? get lastDoneAt {
    final a = lastSuccessAt;
    final b = lastCheckedAt;
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  /// Whether [files] still hold the newest copy written, unchanged: same id
  /// and name, and the same size when the provider reports one (0 means it
  /// does not).
  bool lastCopyIn(Iterable<FolderFile> files) {
    final fileName = lastFileName;
    if (fileName == null) return false;
    return files.any(
      (f) =>
          f.name == fileName &&
          (lastFileId == null || f.id == lastFileId) &&
          (f.sizeBytes == 0 ||
              lastFileSize == null ||
              f.sizeBytes == lastFileSize),
    );
  }

  /// A new folder: the history of the old one does not apply.
  FolderBackupState withFolder(String uri, String? name) =>
      FolderBackupState(uri: uri, name: name);

  FolderBackupState succeeded(DateTime at, FolderFile file, String checksum) =>
      FolderBackupState(
        uri: uri,
        name: name,
        lastAttemptAt: at,
        lastSuccessAt: at,
        lastCheckedAt: lastCheckedAt,
        lastFileName: file.name,
        lastFileId: file.id,
        lastFileSize: file.sizeBytes,
        lastChecksum: checksum,
      );

  FolderBackupState checked(DateTime at) => FolderBackupState(
    uri: uri,
    name: name,
    lastAttemptAt: at,
    lastSuccessAt: lastSuccessAt,
    lastCheckedAt: at,
    lastFileName: lastFileName,
    lastFileId: lastFileId,
    lastFileSize: lastFileSize,
    lastChecksum: lastChecksum,
  );

  FolderBackupState failed(DateTime at, FolderProblem problem) =>
      FolderBackupState(
        uri: uri,
        name: name,
        lastAttemptAt: at,
        lastSuccessAt: lastSuccessAt,
        lastCheckedAt: lastCheckedAt,
        lastFileName: lastFileName,
        lastFileId: lastFileId,
        lastFileSize: lastFileSize,
        lastChecksum: lastChecksum,
        lastProblem: problem,
        lastProblemAt: at,
      );

  Map<String, Object?> toJson() => {
    'v': 1,
    'uri': uri,
    'name': name,
    'lastAttemptAt': lastAttemptAt?.toUtc().toIso8601String(),
    'lastSuccessAt': lastSuccessAt?.toUtc().toIso8601String(),
    'lastCheckedAt': lastCheckedAt?.toUtc().toIso8601String(),
    'lastFileName': lastFileName,
    'lastFileId': lastFileId,
    'lastFileSize': lastFileSize,
    'lastChecksum': lastChecksum,
    'lastProblem': lastProblem?.code,
    'lastProblemAt': lastProblemAt?.toUtc().toIso8601String(),
  };

  /// Reads what [toJson] wrote. Not a JSON object:
  /// [FolderBackupState.damaged]. Inside one, a field of the wrong shape is
  /// dropped (an unreadable date counts as missing).
  static FolderBackupState fromJson(Object? json) {
    if (json is! Map) return const FolderBackupState.damaged();
    String? text(String key) {
      final v = json[key];
      return v is String && v.isNotEmpty ? v : null;
    }

    DateTime? time(String key) {
      final v = text(key);
      return v == null ? null : DateTime.tryParse(v)?.toUtc();
    }

    final problem = text('lastProblem');
    final size = json['lastFileSize'];
    return FolderBackupState(
      uri: text('uri'),
      name: text('name'),
      lastAttemptAt: time('lastAttemptAt'),
      lastSuccessAt: time('lastSuccessAt'),
      lastCheckedAt: time('lastCheckedAt'),
      lastFileName: text('lastFileName'),
      lastFileId: text('lastFileId'),
      lastFileSize: size is int && size >= 0 ? size : null,
      lastChecksum: text('lastChecksum'),
      lastProblem: problem == null ? null : FolderProblem.fromCode(problem),
      lastProblemAt: time('lastProblemAt'),
    );
  }
}
