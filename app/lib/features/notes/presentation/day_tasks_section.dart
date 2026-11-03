import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/icons/app_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/error_state.dart';
import '../../calendar/application/schedule_controller.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../application/notes_providers.dart';
import '../domain/day_task.dart';
import 'note_message.dart';

/// The name of the section inside «Más opciones» of the day detail, from the
/// ARB files.
String noteTasksSectionName(AppLocalizations l10n) => l10n.noteTasksSection;

/// The section of the day detail for [date] (P2): the checklist of that day.
Widget noteTasksSection(BuildContext context, CivilDate date) =>
    DayTasksSection(date: date);

/// «Tareas» inside «Más opciones» of the day detail: the checklist of the
/// day. Every change is a step of undo ([DayTaskList] keeps the list of the
/// day before each change), so the button «Deshacer» of the header brings
/// the last one back.
class DayTasksSection extends ConsumerStatefulWidget {
  const DayTasksSection({super.key, required this.date});

  /// The day the tasks belong to.
  final CivilDate date;

  @override
  ConsumerState<DayTasksSection> createState() => _DayTasksSectionState();
}

class _DayTasksSectionState extends ConsumerState<DayTasksSection> {
  final _title = TextEditingController();

  /// Why the last attempt failed (`null` when it worked). It stays in the
  /// section: a notice would hide behind the sheet of the day.
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _add(DayKey key) async {
    final l10n = context.l10n;
    final text = _title.text.trim();
    if (text.isEmpty) {
      _say(l10n.noteTasksInvalid);
      return;
    }
    try {
      await ref.read(dayTasksProvider(key).notifier).add(text);
      _title.clear();
      _say(null);
    } catch (_) {
      _say(l10n.saveFailed);
    }
  }

  /// Says it in the section (never throws).
  void _say(String? message) {
    if (!mounted) return;
    setState(() => _error = message);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    final calendarId = ref.watch(
      scheduleControllerProvider.select((s) => s.calendarId),
    );
    final key = DayKey(calendarId, widget.date);
    final tasks = ref.watch(dayTasksProvider(key));
    final canUndo = ref.read(dayTasksProvider(key).notifier).canUndo;

    return Column(
      key: const ValueKey('day-tasks-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Sp.l),
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  l10n.noteTasksSection.toUpperCase(),
                  style: type.label.copyWith(color: colors.textMuted),
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('day-tasks-undo'),
              tooltip: l10n.noteTasksUndo,
              icon: Icon(AppIcons.undo),
              onPressed: canUndo
                  ? () => ref.read(dayTasksProvider(key).notifier).undo()
                  : null,
            ),
          ],
        ),
        const SizedBox(height: Sp.xs),
        tasks.when(
          loading: () => const SizedBox(
            height: Disc.l,
            child: Center(child: ButtonSpinner()),
          ),
          error: (_, _) => ErrorState(
            compact: true,
            onRetry: () => ref.invalidate(dayTasksProvider(key)),
          ),
          data: (list) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (list.isEmpty)
                Padding(
                  key: const ValueKey('day-tasks-empty'),
                  padding: const EdgeInsets.symmetric(vertical: Sp.s),
                  child: Text(
                    l10n.noteTasksEmpty,
                    style: type.body.copyWith(color: colors.textSecondary),
                  ),
                )
              else
                for (final (index, task) in list.indexed)
                  _TaskRow(
                    key: ValueKey('task-${task.id}'),
                    task: task,
                    isFirst: index == 0,
                    isLast: index == list.length - 1,
                    onToggle: () => ref
                        .read(dayTasksProvider(key).notifier)
                        .setDone(task.id, done: !task.done),
                    onMove: (by) => ref
                        .read(dayTasksProvider(key).notifier)
                        .move(task.id, index + by),
                    onRemove: () => ref
                        .read(dayTasksProvider(key).notifier)
                        .remove(task.id),
                  ),
              const SizedBox(height: Sp.s),
              TextField(
                key: const ValueKey('day-task-field'),
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                maxLength: maxDayTaskTitleLength,
                decoration: InputDecoration(
                  hintText: l10n.noteTasksHint,
                  counterText: '',
                  suffixIcon: IconButton(
                    key: const ValueKey('day-task-add'),
                    tooltip: l10n.noteTasksAdd,
                    icon: Icon(AppIcons.add),
                    onPressed: () => _add(key),
                  ),
                ),
                onSubmitted: (_) => _add(key),
              ),
            ],
          ),
        ),
        if (_error != null)
          NoteMessage(
            key: const ValueKey('day-tasks-error'),
            text: _error!,
            isError: true,
          ),
      ],
    );
  }
}

/// One task: its box, its text and the menu that moves it or removes it.
///
/// The box and the text are one thing for the reader of screen (the name of
/// the task and whether it is done): they are merged, so the name is not
/// read twice.
class _TaskRow extends StatelessWidget {
  const _TaskRow({
    super.key,
    required this.task,
    required this.isFirst,
    required this.isLast,
    required this.onToggle,
    required this.onMove,
    required this.onRemove,
  });

  final DayTask task;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onToggle;
  final void Function(int by) onMove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;

    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Sp.xs),
        child: Row(
          children: [
            SizedBox.square(
              dimension: Sp.touch,
              child: Center(
                child: Checkbox(
                  key: ValueKey('task-check-${task.id}'),
                  value: task.done,
                  onChanged: (_) => onToggle(),
                ),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(Rad.inner),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Sp.s),
                  child: Text(
                    task.title,
                    style: task.done
                        ? type.body.copyWith(
                            color: colors.textMuted,
                            decoration: TextDecoration.lineThrough,
                          )
                        : type.body,
                  ),
                ),
              ),
            ),
            PopupMenuButton<_TaskAction>(
              key: ValueKey('task-menu-${task.id}'),
              tooltip: l10n.noteTaskMenu,
              icon: Icon(AppIcons.more, color: colors.textSecondary),
              onSelected: (action) => switch (action) {
                _TaskAction.up => onMove(-1),
                _TaskAction.down => onMove(1),
                _TaskAction.remove => onRemove(),
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  key: ValueKey('task-menu-up-${task.id}'),
                  value: _TaskAction.up,
                  enabled: !isFirst,
                  child: Text(l10n.noteTaskMoveUp),
                ),
                PopupMenuItem(
                  key: ValueKey('task-menu-down-${task.id}'),
                  value: _TaskAction.down,
                  enabled: !isLast,
                  child: Text(l10n.noteTaskMoveDown),
                ),
                PopupMenuItem(
                  key: ValueKey('task-menu-remove-${task.id}'),
                  value: _TaskAction.remove,
                  child: Text(l10n.noteTaskRemove),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _TaskAction { up, down, remove }
