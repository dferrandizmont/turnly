import 'package:flutter/material.dart';

import '../../../core/icons/app_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/value_row.dart';
import '../../alarms/domain/alarm_settings.dart';
import '../../alarms/presentation/alarm_pickers.dart' show pauseTimingText;
import '../../calendar/presentation/shift_format.dart';

/// «Aviso de pausa» section of the shift-type form (docs/alarmas.md): a switch
/// and, when it is on, when the notice rings (halfway through the shift or a
/// time after it starts). It looks like the rows of Ajustes › Alarmas.
///
/// Off by default. The helper under the switch suggests it for shifts of 8
/// hours or more ([suggested], with their [duration] in minutes); the notes
/// below say what the notice does with a split shift, when the time chosen
/// does not fit inside the shift ([outside]) and when the alarms are off in
/// Ajustes ([alarmsOff]), which silences it.
class ShiftPauseSection extends StatelessWidget {
  const ShiftPauseSection({
    super.key,
    required this.pause,
    required this.onChanged,
    required this.onPickTiming,
    required this.suggested,
    required this.duration,
    required this.split,
    required this.outside,
    required this.alarmsOff,
  });

  final PauseAlertSettings pause;
  final ValueChanged<bool> onChanged;
  final VoidCallback onPickTiming;
  final bool suggested;
  final int duration;
  final bool split;
  final bool outside;
  final bool alarmsOff;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    Widget note(String text, {Color? color, Key? key}) => Padding(
      padding: const EdgeInsets.only(top: Sp.xs),
      child: Text(
        text,
        key: key,
        style: type.meta.copyWith(color: color ?? colors.textMuted),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Padding(
            padding: const EdgeInsets.only(bottom: Sp.s),
            child: Text(
              l10n.shiftTypesPauseSection.toUpperCase(),
              style: type.label.copyWith(color: colors.textMuted),
            ),
          ),
        ),
        SwitchListTile(
          key: const ValueKey('shift-pause'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.shiftTypesPauseSwitch),
          subtitle: Text(
            suggested
                ? l10n.shiftTypesPauseHelperLong(durationText(l10n, duration))
                : l10n.shiftTypesPauseHelperShort,
          ),
          value: pause.enabled,
          onChanged: onChanged,
        ),
        if (pause.enabled) ...[
          Semantics(
            button: true,
            child: InkWell(
              key: const ValueKey('shift-pause-when'),
              onTap: onPickTiming,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: Sp.touch),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ValueRow(
                    title: Text(l10n.shiftTypesPauseWhen, style: type.body),
                    value: Text(
                      pauseTimingText(l10n, pause),
                      style: type.body.copyWith(color: colors.textMuted),
                    ),
                    trailing: Icon(
                      AppIcons.chevronRight,
                      size: IconSize.inline,
                      color: colors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (split)
            note(
              l10n.shiftTypesPauseSplitNote,
              key: const ValueKey('shift-pause-split'),
            ),
          if (outside)
            note(
              l10n.shiftTypesPauseOutside,
              color: colors.danger,
              key: const ValueKey('shift-pause-outside'),
            ),
          if (alarmsOff)
            note(
              l10n.shiftTypesPauseAlarmsOff,
              key: const ValueKey('shift-pause-alarms-off'),
            ),
        ],
      ],
    );
  }
}
