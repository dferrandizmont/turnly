import 'dart:convert';

import '../../../core/database/app_database.dart';
import '../domain/share_feed.dart';
import '../domain/share_token.dart';

/// Keys of the `settings` table. All start with `shareLink.`, which makes
/// them **device settings** (`isDeviceSetting` in the backup): they never go
/// into a backup file and a restore leaves them as they are.
class ShareLinkKeys {
  const ShareLinkKeys._();

  static const String prefix = 'shareLink.';
  static const String token = 'shareLink.token';
  static const String calendarId = 'shareLink.calendarId';
  static const String includeRest = 'shareLink.includeRest';
  static const String includeAbsences = 'shareLink.includeAbsences';
  static const String publishedAt = 'shareLink.publishedAt';
  static const String fingerprint = 'shareLink.fingerprint';

  /// The person revoked the link but the worker has not confirmed it yet:
  /// nothing is uploaded under this token and the revocation is retried.
  static const String revokePending = 'shareLink.revokePending';

  static const List<String> all = [
    token,
    calendarId,
    includeRest,
    includeAbsences,
    publishedAt,
    fingerprint,
    revokePending,
  ];
}

/// What is stored about the shared link.
class ShareLinkSettings {
  const ShareLinkSettings({
    this.token,
    this.calendarId,
    this.options = const ShareFeedOptions(),
    this.publishedAt,
    this.fingerprint,
    this.revokePending = false,
  });

  /// `null` = nothing published (or it was revoked).
  final ShareToken? token;

  /// The calendar whose shifts the feed carries.
  final String? calendarId;
  final ShareFeedOptions options;

  /// Last upload the worker accepted (UTC). `null` with a [token] means the
  /// first upload has not gone through yet.
  final DateTime? publishedAt;

  /// [shareFeedFingerprint] of the last upload.
  final String? fingerprint;

  /// A revocation the worker has not confirmed yet (see
  /// [ShareLinkKeys.revokePending]). Only meaningful with a [token].
  final bool revokePending;

  bool get hasToken => token != null;
  bool get isPublished => token != null && publishedAt != null;

  ShareLinkSettings copyWith({
    ShareToken? token,
    String? calendarId,
    ShareFeedOptions? options,
    DateTime? publishedAt,
    String? fingerprint,
    bool? revokePending,
  }) => ShareLinkSettings(
    token: token ?? this.token,
    calendarId: calendarId ?? this.calendarId,
    options: options ?? this.options,
    publishedAt: publishedAt ?? this.publishedAt,
    fingerprint: fingerprint ?? this.fingerprint,
    revokePending: revokePending ?? this.revokePending,
  );
}

/// Reads and writes [ShareLinkSettings] in the `settings` table. A value
/// that is missing or damaged reads as «nothing»: a bad row never invents a
/// token or turns an option on.
class ShareLinkRepository {
  ShareLinkRepository(this._db);

  final AppDatabase _db;

  Future<ShareLinkSettings> load() async {
    final rows = await (_db.select(
      _db.settings,
    )..where((s) => s.key.isIn(ShareLinkKeys.all))).get();
    final values = <String, Object?>{
      for (final row in rows) row.key: _decode(row.value),
    };
    final token = values[ShareLinkKeys.token];
    final calendarId = values[ShareLinkKeys.calendarId];
    final publishedAt = values[ShareLinkKeys.publishedAt];
    final fingerprint = values[ShareLinkKeys.fingerprint];
    return ShareLinkSettings(
      token: token is String ? ShareToken.tryParse(token) : null,
      calendarId: calendarId is String && calendarId.isNotEmpty
          ? calendarId
          : null,
      options: ShareFeedOptions(
        includeRest: values[ShareLinkKeys.includeRest] == true,
        includeAbsences: values[ShareLinkKeys.includeAbsences] == true,
      ),
      publishedAt: publishedAt is int && publishedAt > 0
          ? DateTime.fromMillisecondsSinceEpoch(publishedAt, isUtc: true)
          : null,
      fingerprint: fingerprint is String ? fingerprint : null,
      revokePending: values[ShareLinkKeys.revokePending] == true,
    );
  }

  /// Stores a new link: the token and the calendar, before anything is
  /// uploaded, so a link that reached the worker can always be revoked.
  Future<void> saveNewLink(ShareToken token, String calendarId) =>
      _db.transaction(() async {
        await _delete([ShareLinkKeys.publishedAt, ShareLinkKeys.fingerprint]);
        await _write(ShareLinkKeys.token, token.value);
        await _write(ShareLinkKeys.calendarId, calendarId);
      });

  Future<void> saveCalendar(String calendarId) =>
      _write(ShareLinkKeys.calendarId, calendarId);

  Future<void> saveOptions(ShareFeedOptions options) =>
      _db.transaction(() async {
        await _write(ShareLinkKeys.includeRest, options.includeRest);
        await _write(ShareLinkKeys.includeAbsences, options.includeAbsences);
      });

  Future<void> savePublished(DateTime at, String fingerprint) =>
      _db.transaction(() async {
        await _write(
          ShareLinkKeys.publishedAt,
          at.toUtc().millisecondsSinceEpoch,
        );
        await _write(ShareLinkKeys.fingerprint, fingerprint);
      });

  /// Marks the revocation as asked for and not yet confirmed.
  Future<void> saveRevokePending() => _write(ShareLinkKeys.revokePending, true);

  /// Forgets the link (after the worker deleted it). The options stay, so a
  /// new link starts with the same choices.
  Future<void> forgetLink() => _delete([
    ShareLinkKeys.token,
    ShareLinkKeys.calendarId,
    ShareLinkKeys.publishedAt,
    ShareLinkKeys.fingerprint,
    ShareLinkKeys.revokePending,
  ]);

  Object? _decode(String raw) {
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  Future<void> _write(String key, Object value) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(key: key, value: jsonEncode(value)),
      );

  Future<void> _delete(List<String> keys) =>
      (_db.delete(_db.settings)..where((s) => s.key.isIn(keys))).go();
}
