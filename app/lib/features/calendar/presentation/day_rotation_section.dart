import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/app_date_format.dart';
import '../../../core/icons/app_icons.dart';
import '../../../core/icons/selection_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../patterns/domain/pattern_catalog.dart';
import '../../patterns/presentation/cycle_start_picker.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../application/schedule_controller.dart';
import '../domain/rotation_day.dart';
import 'shift_format.dart';

enum _RotationAction { restart, endHere, resume }

/// Where the shifts of [date] come from and what can be done with its
/// rotation, under the shifts of the day detail (`docs/diseno.md`, «Detalle
/// del día»):
///
/// - a quiet line: «De tu rotación «Correturnos»», «Cambiado a mano» or, on a
///   day without rotation after one ended, «Tu rotación «Correturnos» terminó
///   el…»;
/// - the «Rotación» menu, with the actions that make sense that day:
///   «Empezar la rotación aquí», «Último día de esta rotación» and «Empezar tu
///   rotación aquí» (`rotation_day.dart`).
///
/// Each action asks first, saying what changes with the dates, is ONE step of
/// the history and leaves a notice with «Deshacer». [onBeforeAction] saves
/// what is being typed in the detail; [onClose] closes it (the notice would
/// hide behind the sheet).
class DayRotationSection extends ConsumerWidget {
  const DayRotationSection({
    super.key,
    required this.date,
    required this.onBeforeAction,
    required this.onClose,
  });

  final CivilDate date;
  final VoidCallback onBeforeAction;
  final VoidCallback onClose;

  static DateTime _at(CivilDate d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    final format = AppDateFormat.of(context);
    final schedule = ref.watch(
      scheduleControllerProvider.select((s) => s.schedule),
    );
    final day = schedule.resolve(date);
    final rotation = rotationDayOf(schedule, date);

    final String? source;
    if (day.source == DaySource.override) {
      // An emptied day already says «Este día no tiene turno».
      source = day.shifts.isEmpty ? null : l10n.dayDetailSourceOverride;
    } else if (rotation.pattern case final pattern?) {
      source = l10n.dayDetailSourcePattern(
        patternDisplayName(schedule, pattern),
      );
    } else if (rotation.endedPattern case final pattern?) {
      source = l10n.dayRotationEnded(
        patternDisplayName(schedule, pattern),
        format.weekdayDayMonth(_at(rotation.ended!.endDate!)),
      );
    } else {
      source = null;
    }
    if (source == null && !rotation.hasActions) return const SizedBox.shrink();

    PopupMenuItem<_RotationAction> item(
      _RotationAction action,
      String key,
      IconData icon,
      String label,
    ) => PopupMenuItem(
      key: ValueKey(key),
      value: action,
      child: Row(
        children: [
          Icon(icon, size: IconSize.button, color: colors.textSecondary),
          const SizedBox(width: Sp.m),
          Flexible(child: Text(label)),
        ],
      ),
    );

    final link = type.meta.copyWith(
      color: colors.accentText,
      fontWeight: FontWeight.w700,
    );
    return Wrap(
      key: const ValueKey('day-rotation'),
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: Sp.s,
      children: [
        if (source != null)
          Text(source, key: const ValueKey('day-source'), style: type.meta),
        if (rotation.hasActions)
          PopupMenuButton<_RotationAction>(
            key: const ValueKey('day-rotation-menu'),
            // The button says what it is; no second label for the reader.
            tooltip: '',
            onSelected: (action) => switch (action) {
              _RotationAction.restart => _restart(context, ref),
              _RotationAction.endHere => _endHere(context, ref),
              _RotationAction.resume => _resume(context, ref),
            },
            itemBuilder: (_) => [
              if (rotation.canRestart)
                item(
                  _RotationAction.restart,
                  'day-rotation-restart',
                  AppIcons.pattern,
                  l10n.dayRotationRestart,
                ),
              if (rotation.canEndHere)
                item(
                  _RotationAction.endHere,
                  'day-rotation-end',
                  SelectionIcons.endRun,
                  l10n.dayRotationEndHere,
                ),
              if (rotation.canResume)
                item(
                  _RotationAction.resume,
                  'day-rotation-resume',
                  AppIcons.pattern,
                  l10n.dayRotationResume,
                ),
            ],
            child: Semantics(
              button: true,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: Sp.touch),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      SelectionIcons.rotations,
                      size: IconSize.inline,
                      color: colors.accentText,
                    ),
                    const SizedBox(width: Sp.xs),
                    Flexible(child: Text(l10n.dayRotationMenu, style: link)),
                    Icon(
                      AppIcons.arrowDown,
                      size: IconSize.inline,
                      color: colors.accentText,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Closes the detail and tells what was done, with «Deshacer» while it is
  /// still the latest thing done.
  void _done(
    BuildContext context,
    WidgetRef ref,
    ScheduleController controller,
    ScheduleChange step,
    String message,
  ) {
    showTrackedSnackBar(
      ref,
      context,
      content: Text(message),
      action: SnackBarAction(
        label: context.l10n.undo,
        onPressed: () => controller.undoIfLast(step),
      ),
    );
    onClose();
  }

  Future<void> _restart(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final format = AppDateFormat.of(context);
    final controller = ref.read(scheduleControllerProvider.notifier);
    final schedule = ref.read(scheduleControllerProvider).schedule;
    final rotation = rotationDayOf(schedule, date);
    final pattern = rotation.pattern;
    if (pattern == null || !rotation.canRestart) return;
    final day = format.weekdayDayMonth(_at(date));
    final name = patternDisplayName(schedule, pattern);
    final tail = [
      if (restartCoversOtherRuns(schedule, date))
        rotation.run!.endDate == null
            ? l10n.dayRotationRestartOthers
            : l10n.dayRotationRestartOthersUntil(
                format.weekdayDayMonth(_at(rotation.run!.endDate!)),
              ),
      l10n.dayRotationKeeps,
    ];
    final offset = await showDialog<int>(
      context: context,
      builder: (_) => _StartHereDialog(
        date: date,
        pattern: pattern,
        schedule: schedule,
        title: l10n.dayRotationRestartTitle,
        keyPrefix: 'restart-',
        // Choosing the day that already falls on [date] changes nothing.
        unchangedOffset: rotation.stepIndex,
        bodyFor: (offset) {
          final shifts = shiftsLine(l10n, format, [
            for (final id in pattern.steps[offset])
              ?_shiftTypeOn(schedule, date, id),
          ]);
          return [
            offset == 0
                ? l10n.dayRotationRestartBody(name, day, shifts)
                : l10n.dayRotationRestartBodyStep(
                    name,
                    day,
                    offset + 1,
                    shifts,
                  ),
            ...tail,
          ].join(' ');
        },
      ),
    );
    if (offset == null || !context.mounted) return;
    onBeforeAction();
    final step = await controller.restartRunAt(date, stepOffset: offset);
    if (step == null || !context.mounted) return;
    _done(context, ref, controller, step, l10n.dayRotationStartDone(day));
  }

  Future<void> _endHere(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final format = AppDateFormat.of(context);
    final controller = ref.read(scheduleControllerProvider.notifier);
    final schedule = ref.read(scheduleControllerProvider).schedule;
    final plan = planEndRunOn(schedule, date);
    if (plan == null) return;
    String name(PatternRun run) {
      final pattern = schedule.patternById(run.patternId);
      return pattern == null
          ? run.patternId
          : patternDisplayName(schedule, pattern);
    }

    final day = format.weekdayDayMonth(_at(date));
    final after = format.weekdayDayMonth(_at(date.addDays(1)));
    final next = plan.next;
    final ok = await showConfirmDialog(
      context,
      title: l10n.dayRotationEndTitle,
      body: [
        l10n.dayRotationEndBody(name(plan.run), day),
        next == null
            ? l10n.dayRotationEndThenNone(after)
            : l10n.dayRotationEndThenOther(after, name(next)),
        l10n.dayRotationEndKeepsOthers,
        l10n.dayRotationKeeps,
      ].join(' '),
      confirmLabel: l10n.selectionRunsEnd,
      scrollable: true,
    );
    if (!ok || !context.mounted) return;
    onBeforeAction();
    final step = controller.endRunOn(date);
    if (step == null) return;
    _done(context, ref, controller, step, l10n.selectionRunsEndDone(day));
  }

  Future<void> _resume(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final format = AppDateFormat.of(context);
    final controller = ref.read(scheduleControllerProvider.notifier);
    final schedule = ref.read(scheduleControllerProvider).schedule;
    final rotation = rotationDayOf(schedule, date);
    final pattern = rotation.endedPattern;
    if (pattern == null) return;
    final day = format.weekdayDayMonth(_at(date));
    final until = rotation.resumeUntil;
    final name = patternDisplayName(schedule, pattern);
    final offset = await showDialog<int>(
      context: context,
      builder: (_) => _StartHereDialog(
        date: date,
        pattern: pattern,
        schedule: schedule,
        title: l10n.dayRotationResumeTitle,
        keyPrefix: 'resume-',
        bodyFor: (_) => [
          until == null
              ? l10n.dayRotationResumeBody(name, day)
              : l10n.dayRotationResumeBodyUntil(
                  name,
                  day,
                  format.weekdayDayMonth(_at(until)),
                ),
          l10n.dayRotationKeeps,
        ].join(' '),
      ),
    );
    if (offset == null || !context.mounted) return;
    onBeforeAction();
    final step = await controller.resumeRunAt(date, stepOffset: offset);
    if (step == null || !context.mounted) return;
    _done(context, ref, controller, step, l10n.dayRotationStartDone(day));
  }
}

/// The shift type [id] as it was on [date] (its hours then), the same for the
/// text of the dialog and for its strip; the displayed one when the calendar
/// has no such type yet.
ShiftType? _shiftTypeOn(Schedule schedule, CivilDate date, String id) =>
    schedule.shiftTypeOn(id, date) ?? shiftTypeForDisplay(schedule, id);

/// The confirmation of «Empezar tu rotación aquí» and «Empezar la rotación
/// aquí»: what changes and, when the cycle has more than one day, which of
/// them falls on [date] (the same question as the rotation wizard). Pops the
/// chosen day of the cycle, or nothing when cancelled.
///
/// [bodyFor] gives the text for the day of the cycle chosen now. [keyPrefix]
/// is the picker's (`resume-`, `restart-`) and also names the scroll and the
/// body. With [unchangedOffset], choosing that day disables the confirm
/// button: it is the one that already falls on [date], nothing would change.
class _StartHereDialog extends StatefulWidget {
  const _StartHereDialog({
    required this.date,
    required this.pattern,
    required this.schedule,
    required this.title,
    required this.bodyFor,
    required this.keyPrefix,
    this.unchangedOffset,
  });

  final CivilDate date;
  final Pattern pattern;
  final Schedule schedule;
  final String title;
  final String Function(int offset) bodyFor;
  final String keyPrefix;
  final int? unchangedOffset;

  @override
  State<_StartHereDialog> createState() => _StartHereDialogState();
}

class _StartHereDialogState extends State<_StartHereDialog> {
  int _offset = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final steps = widget.pattern.steps;
    final type = context.type;
    // A plain [Dialog], not an `AlertDialog`: that one asks its content how
    // wide it would like to be, and the picker lays itself out from the room
    // it is given (it cannot answer).
    return Dialog(
      // Closer to the edges than a plain dialog: on a narrow phone with
      // large text the picker needs the width for its longest words.
      insetPadding: const EdgeInsets.symmetric(
        horizontal: Sp.l,
        vertical: Sp.xxl,
      ),
      constraints: const BoxConstraints(
        minWidth: Sp.dialogMinWidth,
        maxWidth: Sp.dialogMaxWidth,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              key: ValueKey('day-rotation-${widget.keyPrefix}scroll'),
              padding: const EdgeInsets.fromLTRB(Sp.xxl, Sp.xxl, Sp.xxl, Sp.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    namesRoute: true,
                    child: Text(widget.title, style: type.headline),
                  ),
                  const SizedBox(height: Sp.l),
                  Text(
                    widget.bodyFor(_offset),
                    key: ValueKey('day-rotation-${widget.keyPrefix}body'),
                    style: type.body,
                  ),
                  if (steps.length > 1) ...[
                    const SizedBox(height: Sp.l),
                    CycleStartPicker(
                      steps: steps,
                      shiftOf: (id) =>
                          _shiftTypeOn(widget.schedule, widget.date, id),
                      offset: _offset,
                      onOffsetChanged: (offset) =>
                          setState(() => _offset = offset),
                      start: widget.date,
                      plan: null,
                      keyPrefix: widget.keyPrefix,
                      showPreview: false,
                      // A day changed by hand keeps what the person put there:
                      // the line says what the rotation would give.
                      resultText:
                          widget.schedule.entries[widget.date]?.shiftTypeIds !=
                              null
                          ? l10n.dayDetailPatternGives
                          : null,
                      // A dialog is `surface`, not the page background.
                      fadeColor: context.colors.surface,
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.l, 0, Sp.l, Sp.l),
            child: OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: Sp.s,
              overflowAlignment: OverflowBarAlignment.end,
              children: [
                TextButton(
                  key: const ValueKey('confirm-cancel'),
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  key: const ValueKey('confirm-ok'),
                  onPressed: _offset == widget.unchangedOffset
                      ? null
                      : () => Navigator.pop(context, _offset),
                  child: Text(l10n.dayRotationStartConfirm),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
