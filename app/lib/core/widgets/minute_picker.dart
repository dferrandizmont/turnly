import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../format/app_date_format.dart';
import '../l10n/l10n.dart';
import '../theme/theme_context.dart';
import 'app_sheet.dart';
import 'keyboard_done_bar.dart';

/// A time of day, on the clock the person chose in Ajustes › Apariencia ›
/// Formato de hora (24 h, or 12 h with AM/PM). [help] is the title. Returns
/// minutes after midnight, or `null` when dismissed.
///
/// On iOS it is the system wheel (a Cupertino time picker in a bottom
/// popup); elsewhere the Material dial (1.2.0 QA, iPhone F6).
Future<int?> showMinutePicker(
  BuildContext context, {
  required int current,
  required String help,
}) async {
  final hour12 = AppDateFormat.of(context).hour12;
  if (Theme.of(context).platform == TargetPlatform.iOS) {
    return _showWheelPicker(
      context,
      current: current,
      help: help,
      hour12: hour12,
    );
  }
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

Future<int?> _showWheelPicker(
  BuildContext context, {
  required int current,
  required String help,
  required bool hour12,
}) {
  // The one sheet of the app: themed top corners, drag handle, safe area and
  // the label of the dimmed area for TalkBack.
  return showAppSheet<int>(
    context: context,
    builder: (_) => _WheelPickerSheet(
      current: current % (24 * 60),
      help: help,
      hour12: hour12,
    ),
  );
}

class _WheelPickerSheet extends StatefulWidget {
  const _WheelPickerSheet({
    required this.current,
    required this.help,
    required this.hour12,
  });

  final int current;
  final String help;
  final bool hour12;

  @override
  State<_WheelPickerSheet> createState() => _WheelPickerSheetState();
}

class _WheelPickerSheetState extends State<_WheelPickerSheet> {
  late int _minute = widget.current;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.type;
    final media = MediaQuery.of(context);
    // The buttons keep one touch target at any text size; the title may
    // wrap on two lines.
    final actionScaler = media.textScaler.clamp(
      maxScaleFactor: KeyboardDoneBar.maxTextScale,
    );
    final wheelHeight = math.max(
      Sp.wheelMinHeight,
      math.min(Sp.wheelHeight, media.size.height * 0.4),
    );
    const buttonSize = Size(Sp.touch, Sp.touch);
    return CupertinoTheme(
      data: CupertinoThemeData(brightness: Theme.of(context).brightness),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          key: const ValueKey('time-picker-wheel'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Sp.page, 0, Sp.page, Sp.s),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    widget.help,
                    key: const ValueKey('time-picker-title'),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: type.bodyStrong,
                  ),
                ),
                MediaQuery(
                  data: media.copyWith(textScaler: actionScaler),
                  child: Row(
                    children: [
                      TextButton(
                        key: const ValueKey('time-picker-cancel'),
                        style: TextButton.styleFrom(minimumSize: buttonSize),
                        onPressed: () => Navigator.pop(context),
                        child: Text(l10n.cancel, style: type.body),
                      ),
                      const Spacer(),
                      TextButton(
                        key: const ValueKey('time-picker-done'),
                        style: TextButton.styleFrom(minimumSize: buttonSize),
                        onPressed: () => Navigator.pop(context, _minute),
                        child: Text(l10n.keyboardDone, style: type.bodyStrong),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: wheelHeight,
                  // Like the system wheel, it keeps its own size: at the largest
                  // text its columns would not fit a narrow phone.
                  child: MediaQuery(
                    data: media.copyWith(textScaler: TextScaler.noScaling),
                    child: CupertinoDatePicker(
                      key: const ValueKey('time-picker-cupertino'),
                      mode: CupertinoDatePickerMode.time,
                      use24hFormat: !widget.hour12,
                      initialDateTime: DateTime(
                        2000,
                        1,
                        1,
                        widget.current ~/ 60,
                        widget.current % 60,
                      ),
                      onDateTimeChanged: (value) =>
                          _minute = value.hour * 60 + value.minute,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
