import 'package:cuadrante/core/bootstrap/bootstrap.dart' show initializeLocale;
import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/features/calendar_export/application/ics_export.dart';
import 'package:cuadrante/features/schedule/data/schedule_repository.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/share_link/application/share_link_controller.dart';
import 'package:cuadrante/features/share_link/data/share_link_api.dart';
import 'package:cuadrante/features/share_link/data/share_link_repository.dart';
import 'package:cuadrante/features/share_link/domain/share_token.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';

export 'package:cuadrante/core/bootstrap/bootstrap.dart' show initializeLocale;

/// The worker, in memory: records what the app sends, fails when told.
class FakeShareApi implements ShareLinkApi {
  final published = <({ShareToken token, String ics})>[];
  final revoked = <ShareToken>[];

  /// The next calls fail with this, until it is set back to null.
  ShareLinkFailure? failure;
  Duration? retryAfter;

  /// Runs inside [publish] before it answers (to look at the database).
  Future<void> Function()? onPublish;

  @override
  Uri feedUrl(ShareToken token) =>
      Uri.parse('https://share.example.test/f/${token.feedId}.ics');

  @override
  Future<void> publish(ShareToken token, String ics) async {
    await onPublish?.call();
    if (failure != null) {
      throw ShareLinkException(failure!, retryAfter: retryAfter);
    }
    published.add((token: token, ics: ics));
  }

  @override
  Future<void> revoke(ShareToken token) async {
    if (failure != null) throw ShareLinkException(failure!);
    revoked.add(token);
  }
}

List<Override> shareOverrides(FakeShareApi? api) => [
  shareLinkApiProvider.overrideWithValue(api),
  icsTimeZoneProvider.overrideWithValue(
    () async => icsLocation('Europe/Madrid'),
  ),
];

/// A vacation (an absence) two days after today, so the filter has
/// something to leave out.
Future<void> addAbsence(AppDatabase db) =>
    ScheduleRepository(db, now: () => harnessNow).apply(
      'main',
      ScheduleChange(
        patch: EntriesPatch({
          harnessToday.addDays(2): EntryChange(
            null,
            DayEntry(
              date: harnessToday.addDays(2),
              shiftTypeIds: const ['vacation'],
              note: 'Cita médica privada',
            ),
          ),
        }),
      ),
    );

Future<ShareLinkSettings> storedSettings(AppUnderTest app) =>
    app.real(() => ShareLinkRepository(app.database).load());

ShareLinkController controllerOf(AppUnderTest app) =>
    app.container.read(shareLinkControllerProvider.notifier);

ShareLinkState stateOf(AppUnderTest app) =>
    app.container.read(shareLinkControllerProvider);

Finder byKey(String key) => find.byKey(ValueKey(key));

void setUpShareTests() => setUpAll(initializeLocale);
