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
    final first = shiftsLine(l10n, format, [
      for (final id in pattern.steps.first) ?schedule.shiftTypeOn(id, date),
    ]);
    final ok = await showConfirmDialog(
      context,
      title: l10n.dayRotationRestartTitle,
      body: [
        l10n.dayRotationRestartBody(
          patternDisplayName(schedule, pattern),
          day,
          first,
        ),
        if (restartCoversOtherRuns(schedule, date))
          rotation.run!.endDate == null
              ? l10n.dayRotationRestartOthers
              : l10n.dayRotationRestartOthersUntil(
                  format.weekdayDayMonth(_at(rotation.run!.endDate!)),
                ),
        l10n.dayRotationKeeps,
      ].join(' '),
      confirmLabel: l10n.dayRotationStartConfirm,
      scrollable: true,
    );
    if (!ok || !context.mounted) return;
    onBeforeAction();
    final step = await controller.restartRunAt(date);
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
      builder: (_) => _ResumeDialog(
        date: date,
        pattern: pattern,
        schedule: schedule,
        body: [
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

/// The confirmation of «Empezar tu rotación aquí»: what changes and, when the
/// cycle has more than one day, which of them falls on [date] (the same
/// question as the rotation wizard). Pops the chosen day of the cycle, or
/// nothing when cancelled.
class _ResumeDialog extends StatefulWidget {
  const _ResumeDialog({
    required this.date,
    required this.pattern,
    required this.schedule,
    required this.body,
  });

  final CivilDate date;
  final Pattern pattern;
  final Schedule schedule;
  final String body;

  @override
  State<_ResumeDialog> createState() => _ResumeDialogState();
}

class _ResumeDialogState extends State<_ResumeDialog> {
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
              key: const ValueKey('day-rotation-resume-scroll'),
              padding: const EdgeInsets.fromLTRB(Sp.xxl, Sp.xxl, Sp.xxl, Sp.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    namesRoute: true,
                    child: Text(
                      l10n.dayRotationResumeTitle,
                      style: type.headline,
                    ),
                  ),
                  const SizedBox(height: Sp.l),
                  Text(
                    widget.body,
                    key: const ValueKey('day-rotation-resume-body'),
                    style: type.body,
                  ),
                  if (steps.length > 1) ...[
                    const SizedBox(height: Sp.l),
                    CycleStartPicker(
                      steps: steps,
                      shiftOf: (id) => shiftTypeForDisplay(widget.schedule, id),
                      offset: _offset,
                      onOffsetChanged: (offset) =>
                          setState(() => _offset = offset),
                      start: widget.date,
                      plan: null,
                      keyPrefix: 'resume-',
                      showPreview: false,
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
                  onPressed: () => Navigator.pop(context, _offset),
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
