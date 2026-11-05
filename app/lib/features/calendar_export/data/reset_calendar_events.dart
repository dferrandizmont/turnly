import 'package:flutter/services.dart';

import '../domain/export_events.dart';

/// The reset reads event rows rather than expanding recurring instances over
/// years of personal calendars. Identification is exactly the export parser,
/// including legacy markers. Android supplies id/description only; no titles,
/// accounts or dates cross the channel. The Mac channel may be absent for now.
class ResetCalendarEvents {
  const ResetCalendarEvents({
    this.onError,
    this.channel = const MethodChannel('app.cuadrante/reset_calendar'),
    this.calendarWasUsed = true,
  });

  final MethodChannel channel;
  final void Function(Object, StackTrace)? onError;

  /// Whether «Mantener al día» was ever set up. Without it and without
  /// calendar permission Turnly cannot have written any event, so a refused
  /// permission is not a failure to warn about (found on a OnePlus 10 Pro: a
  /// phone that never synced got «Algunos eventos… no se han podido quitar»).
  /// With it, a permission revoked later leaves events behind: still a
  /// warning.
  final bool calendarWasUsed;

  Future<void> deleteAppEvents() async {
    var failed = false;
    try {
      final candidates = await channel.invokeListMethod<Object?>('list');
      for (final candidate in candidates ?? const []) {
        if (candidate is! Map) continue;
        final id = candidate['id'];
        final description = candidate['description'];
        if (id is! String || description is! String) continue;
        if (ExportTag.parse(description) == null) continue;
        try {
          await channel.invokeMethod<void>('delete', {
            'id': id,
            'description': description,
          });
        } catch (error, stack) {
          failed = true;
          // The native channel returns only fixed error codes, no event data.
          // The injected reporter redacts again before recording the failure.
          try {
            onError?.call(error, stack);
          } catch (_) {}
        }
      }
    } on MissingPluginException {
      // iOS implementation is a Mac task.
      return;
    } on PlatformException catch (error) {
      if (error.code == 'permissionDenied' && !calendarWasUsed) return;
      rethrow;
    }
    if (failed) throw const ResetCalendarCleanupFailure();
  }
}

class ResetCalendarCleanupFailure implements Exception {
  const ResetCalendarCleanupFailure();
}
