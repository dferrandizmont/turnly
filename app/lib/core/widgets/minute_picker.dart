import 'package:flutter/material.dart';

import '../format/app_date_format.dart';

/// A time of day with the Material picker, on the clock the person chose in
/// Ajustes › Apariencia › Formato de hora (24 h, or 12 h with AM/PM).
/// [help] is the title. Returns minutes after midnight, or `null` when
/// dismissed.
Future<int?> showMinutePicker(
  BuildContext context, {
  required int current,
  required String help,
}) async {
  final hour12 = AppDateFormat.of(context).hour12;
  final picked = await showTimePicker(
    context: context,
    helpText: help,
    initialTime: TimeOfDay(hour: current ~/ 60 % 24, minute: current % 60),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: !hour12),
      child: child!,
    ),
  );
  return picked == null ? null : picked.hour * 60 + picked.minute;
}
