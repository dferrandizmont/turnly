import 'package:flutter/cupertino.dart'
    show CupertinoPicker, CupertinoPickerDefaultSelectionOverlay;
import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/choice_sheet.dart';
import '../../../core/widgets/minute_picker.dart';
import '../../calendar/presentation/shift_format.dart';
import '../domain/alarm_settings.dart';

/// Leads offered in the list, in minutes; anything else is "Personalizado".
const List<int> alarmLeadPresets = [30, 60, 90, 120];

/// Value of the "Personalizado" option of the lead list.
const int _customLead = -1;

/// "Al empezar" / "30 min" / "1 h 30 min".
String alarmLeadText(AppLocalizations l10n, int minutes) =>
    minutes <= 0 ? l10n.alarmsBeforeAtStart : durationText(l10n, minutes);

/// Asks how long before the shift the alarm rings: the presets, or a custom
/// duration with a picker. Null when dismissed.
Future<int?> pickAlarmLead(BuildContext context, {required int current}) async {
  final l10n = context.l10n;
  final custom = !alarmLeadPresets.contains(current);
  final picked = await showChoiceSheet<int>(
    context: context,
    title: l10n.alarmsBeforeSheetTitle,
    selected: custom ? _customLead : current,
    options: [
      for (final m in alarmLeadPresets) ChoiceOption(m, alarmLeadText(l10n, m)),
      ChoiceOption(
        _customLead,
        custom
            ? '${l10n.alarmsBeforeCustom} · ${alarmLeadText(l10n, current)}'
            : l10n.alarmsBeforeCustom,
      ),
    ],
  );
  if (picked == null || !context.mounted) return null;
  if (picked != _customLead) return picked;
  return showAppSheet<int>(
    context: context,
    padded: true,
    builder: (_) => _CustomLeadSheet(initial: current),
  );
}

/// "After the start" times offered by the pause notice list, in minutes;
/// anything else is "Personalizado".
const List<int> pauseAfterPresets = [60, 120, 180, 240, 300, 360];

/// Value of the "A mitad del turno" option of the pause list.
const int _pauseMid = -2;

/// "A mitad del turno" or "2 h después de empezar": how the pause notice of
/// [pause] reads in the shift editor.
String pauseTimingText(AppLocalizations l10n, PauseAlertSettings pause) =>
    pause.timing == PauseTiming.midShift
    ? l10n.shiftTypesPauseMid
    : l10n.shiftTypesPauseAfter(durationText(l10n, pause.afterMinutes));

/// Asks when the pause notice rings: halfway through the shift, or a time
/// after it starts (presets or a custom duration with a picker). Null when
/// dismissed; otherwise [current] with the new timing.
Future<PauseAlertSettings?> pickPauseTiming(
  BuildContext context, {
  required PauseAlertSettings current,
}) async {
  final l10n = context.l10n;
  final after = current.afterMinutes;
  final custom =
      current.timing == PauseTiming.afterStart &&
      !pauseAfterPresets.contains(after);
  final picked = await showChoiceSheet<int>(
    context: context,
    title: l10n.shiftTypesPauseSheetTitle,
    selected: current.timing == PauseTiming.midShift
        ? _pauseMid
        : custom
        ? _customLead
        : after,
    options: [
      ChoiceOption(_pauseMid, l10n.shiftTypesPauseMid),
      for (final m in pauseAfterPresets)
        ChoiceOption(m, l10n.shiftTypesPauseAfter(durationText(l10n, m))),
      ChoiceOption(
        _customLead,
        custom
            ? '${l10n.alarmsBeforeCustom} · ${durationText(l10n, after)}'
            : l10n.alarmsBeforeCustom,
      ),
    ],
  );
  if (picked == null || !context.mounted) return null;
  if (picked == _pauseMid) {
    return current.copyWith(timing: PauseTiming.midShift);
  }
  if (picked != _customLead) {
    return current.copyWith(
      timing: PauseTiming.afterStart,
      afterMinutes: picked,
    );
  }
  final minutes = await showAppSheet<int>(
    context: context,
    padded: true,
    builder: (_) => _CustomLeadSheet(
      initial: after,
      title: l10n.shiftTypesPauseCustomTitle,
      help: l10n.shiftTypesPauseCustomHelp,
      minMinutes: PauseAlertSettings.minAfterMinutes,
      maxMinutes: PauseAlertSettings.maxAfterMinutes,
      pickerKey: const ValueKey('pause-after-picker'),
      applyKey: const ValueKey('pause-after-apply'),
    ),
  );
  if (minutes == null) return null;
  return current.copyWith(
    timing: PauseTiming.afterStart,
    afterMinutes: minutes,
  );
}

/// Hours and minutes wheel ([DurationWheel], which looks the same on every
/// platform and has no Material equivalent) with an "Aceptar" button.
class _CustomLeadSheet extends StatefulWidget {
  const _CustomLeadSheet({
    required this.initial,
    this.title,
    this.help,
    this.minMinutes = 0,
    this.maxMinutes = AlarmTypeSettings.maxMinutesBefore,
    this.pickerKey = const ValueKey('alarms-lead-picker'),
    this.applyKey = const ValueKey('alarms-lead-apply'),
  });

  final int initial;

  /// Texts of the sheet; null = those of the lead before the shift.
  final String? title;
  final String? help;
  final int minMinutes;
  final int maxMinutes;
  final Key pickerKey;
  final Key applyKey;

  @override
  State<_CustomLeadSheet> createState() => _CustomLeadSheetState();
}

class _CustomLeadSheetState extends State<_CustomLeadSheet> {
  late int _minutes = widget.initial.clamp(
    widget.minMinutes,
    widget.maxMinutes,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.type;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            widget.title ?? l10n.alarmsBeforeCustomTitle,
            style: type.headline,
          ),
        ),
        const SizedBox(height: Sp.xs),
        Text(widget.help ?? l10n.alarmsBeforeCustomHelp, style: type.meta),
        const SizedBox(height: Sp.m),
        SizedBox(
          height: 180,
          child: DurationWheel(
            key: widget.pickerKey,
            initial: Duration(minutes: _minutes),
            maxMinutes: widget.maxMinutes,
            onChanged: (d) => _minutes = d.inMinutes.clamp(
              widget.minMinutes,
              widget.maxMinutes,
            ),
          ),
        ),
        const SizedBox(height: Sp.m),
        PrimaryButton(
          key: widget.applyKey,
          label: l10n.alarmsBeforeCustomApply,
          onPressed: () => Navigator.pop(context, _minutes),
        ),
      ],
    );
  }
}

/// Asks for the time of day of the day-before reminder (24 h clock). Returns
/// minutes after midnight, or null when dismissed.
Future<int?> pickDayBeforeTime(BuildContext context, {required int current}) =>
    pickMinuteOfDay(
      context,
      current: current,
      help: context.l10n.alarmsDayBeforeTimeTitle,
    );

/// A time of day on the clock of Ajustes (see [showMinutePicker]); [help] is
/// the title. Returns minutes after midnight, or null when dismissed.
Future<int?> pickMinuteOfDay(
  BuildContext context, {
  required int current,
  required String help,
}) => showMinutePicker(context, current: current, help: help);

/// Asks for the custom text of the notification. Returns the new text (empty
/// = back to the default one), or null when dismissed.
Future<String?> pickAlarmLabel(
  BuildContext context, {
  required String? current,
}) => showAppSheet<String>(
  context: context,
  padded: true,
  builder: (_) => _LabelSheet(initial: current ?? ''),
);

class _LabelSheet extends StatefulWidget {
  const _LabelSheet({required this.initial});

  final String initial;

  @override
  State<_LabelSheet> createState() => _LabelSheetState();
}

class _LabelSheetState extends State<_LabelSheet> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.type;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.alarmsLabelTitle, style: type.headline),
        ),
        const SizedBox(height: Sp.m),
        TextField(
          key: const ValueKey('alarms-label-field'),
          controller: _text,
          autofocus: true,
          maxLength: 60,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(hintText: l10n.alarmsLabelHint),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        const SizedBox(height: Sp.m),
        PrimaryButton(
          key: const ValueKey('alarms-label-apply'),
          label: l10n.alarmsLabelApply,
          onPressed: () => Navigator.pop(context, _text.text),
        ),
        const SizedBox(height: Sp.s),
        SecondaryButton(
          key: const ValueKey('alarms-label-reset'),
          label: l10n.alarmsLabelReset,
          onPressed: () => Navigator.pop(context, ''),
        ),
      ],
    );
  }
}

/// Hours and minutes wheels of a duration, with unpadded hours ("4") and
/// two-digit minutes ("05"), like a clock. [onChanged] reports every change
/// (not clamped: the caller bounds it). Hours go from 0 to [maxMinutes] ~/ 60.
///
/// Not a `CupertinoTimerPicker`: that one takes its digits from the locale
/// and showed padded hours next to unpadded minutes ("04 hours 0 min").
class DurationWheel extends StatefulWidget {
  const DurationWheel({
    super.key,
    required this.initial,
    required this.maxMinutes,
    required this.onChanged,
  });

  final Duration initial;
  final int maxMinutes;
  final ValueChanged<Duration> onChanged;

  @override
  State<DurationWheel> createState() => _DurationWheelState();
}

class _DurationWheelState extends State<DurationWheel> {
  static const double _itemExtent = 40;

  late int _hours = widget.initial.inHours;
  late int _minutes = widget.initial.inMinutes % 60;
  late final FixedExtentScrollController _hoursController =
      FixedExtentScrollController(initialItem: _hours);
  late final FixedExtentScrollController _minutesController =
      FixedExtentScrollController(initialItem: _minutes);

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  void _emit() => widget.onChanged(Duration(hours: _hours, minutes: _minutes));

  Widget _wheel({
    required Key key,
    required FixedExtentScrollController controller,
    required int count,
    required String Function(int) label,
    required String unit,
    required ValueChanged<int> onSelected,
  }) {
    final type = context.type;
    final colors = context.colors;
    return Expanded(
      child: Row(
        children: [
          Expanded(
            child: CupertinoPicker(
              key: key,
              scrollController: controller,
              itemExtent: _itemExtent,
              selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                background: colors.surfaceMuted,
              ),
              onSelectedItemChanged: onSelected,
              children: [
                for (var i = 0; i < count; i++)
                  Center(
                    child: Text(
                      label(i),
                      style: AppTypography.tabular(
                        type.title.copyWith(color: colors.textPrimary),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Text(unit, style: type.body.copyWith(color: colors.textSecondary)),
          const SizedBox(width: Sp.s),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        _wheel(
          key: const ValueKey('duration-wheel-hours'),
          controller: _hoursController,
          count: widget.maxMinutes ~/ 60 + 1,
          label: (h) => '$h',
          unit: l10n.durationWheelHours,
          onSelected: (h) {
            _hours = h;
            _emit();
          },
        ),
        _wheel(
          key: const ValueKey('duration-wheel-minutes'),
          controller: _minutesController,
          count: 60,
          label: (m) => m.toString().padLeft(2, '0'),
          unit: l10n.durationWheelMinutes,
          onSelected: (m) {
            _minutes = m;
            _emit();
          },
        ),
      ],
    );
  }
}
