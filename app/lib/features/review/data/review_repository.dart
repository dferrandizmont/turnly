import 'dart:convert';

import '../../../core/database/app_database.dart';
import '../domain/review_policy.dart';

/// Key of the review counters in the `settings` table (JSON value). A device
/// setting (`isDeviceSetting`, prefix `review.`): it never goes into a backup
/// and a restore leaves it alone, so a restored copy cannot reset the count.
const String reviewStateKey = 'review.state';

/// Prefix of every review row, for `isDeviceSetting`.
const String reviewSettingPrefix = 'review.';

class ReviewRepository {
  ReviewRepository(this._db);

  final AppDatabase _db;

  /// What is stored, or an empty state when there is nothing or it cannot be
  /// read.
  Future<ReviewState> load() async {
    final row = await (_db.select(
      _db.settings,
    )..where((s) => s.key.equals(reviewStateKey))).getSingleOrNull();
    if (row == null) return ReviewState.empty;
    try {
      final json = jsonDecode(row.value);
      if (json is Map) {
        return ReviewState.fromJson(json.cast<String, Object?>());
      }
    } on Object {
      // Unreadable: start again from nothing.
    }
    return ReviewState.empty;
  }

  Future<void> save(ReviewState state) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(
          key: reviewStateKey,
          value: jsonEncode(state.toJson()),
        ),
      );
}
