import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/app_date_format.dart';
import '../../../core/format/money.dart';
import '../../../core/icons/app_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/buttons.dart';
import '../../alarms/presentation/day_alarm_skip_row.dart';
import '../../alarms/presentation/day_reminder_row.dart';
import '../../device_events/presentation/device_events_section.dart';
import '../../holidays/application/holidays_provider.dart';
import '../../holidays/presentation/holiday_names.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../../summary/presentation/summary_format.dart';
import '../application/open_day.dart';
import '../application/schedule_controller.dart';
import 'day_extra_amount_section.dart';
import 'day_extras_section.dart';
import 'day_more_options.dart';
import 'day_palette_panel.dart';
import 'history_feedback.dart';
import 'holiday_label.dart';
import 'shift_badge.dart';
import 'shift_format.dart';

/// The detail of [date] (`turnos-spec.md`, screen 4; `docs/diseno.md`,
/// «Detalle del día», option 4A of 31 Oct), in layers:
///
/// - the date with «Deshacer» (A7: the latest change to this day);
/// - one row per shift, each with its menu (change, up, down, remove), what
///   the day comes from and «Volver al patrón»;
/// - «Añadir turno», which opens the palette in the same sheet;
/// - the note, always in sight;
/// - «Más opciones», folded, saying what it holds: extra hours, own holiday,
///   reminder, «Sin alarma este día», the sections of other features
///   ([dayMoreSectionsProvider]), «Duplicar en otro día» and «Borrar día».
///
/// Every edit is ONE undoable step of the schedule, so undo / redo in paint
/// mode reverts it too.
///
/// One widget, two places: the bottom sheet of a phone (`DayDetailSheet`),
/// as tall as its content, and the right pane of the two-pane month
/// ([inline]). [onClose] closes whichever holds it; «Duplicar en otro día»
/// and «Borrar día» call it.
class DayDetailBody extends ConsumerStatefulWidget {
  const DayDetailBody({
    super.key,
    required this.date,
    required this.onClose,
    this.inline = false,
    this.bottomRoom = 0,
  });

  final CivilDate date;
  final VoidCallback onClose;

  /// In a pane, not a sheet: it fills the room it is given (the sheet is as
  /// tall as its content), has a close button in its header and leaves
  /// [bottomRoom] free at the end of the scroll (the floating button).
  final bool inline;
  final double bottomRoom;

  @override
  ConsumerState<DayDetailBody> createState() => DayDetailBodyState();
}

class DayDetailBodyState extends ConsumerState<DayDetailBody>
    with WidgetsBindingObserver {
  /// How long after the last keystroke the note is saved on its own.
  static const noteAutosaveDelay = Duration(milliseconds: 800);

  /// The tallest the sheet gets, as a share of the screen: a day with little
  /// in it takes only what it needs, and the month stays in sight above it.
  static const double maxHeightFactor = 0.88;

  late final ScheduleController _schedule;
  late final NoteDraftController _draft;
  final _note = TextEditingController();
  final _noteFocus = FocusNode();
  final _holidayName = TextEditingController();
  final _holidayFocus = FocusNode();
  final _extras = GlobalKey<DayExtrasSectionState>();
  final _extraAmount = GlobalKey<DayExtraAmountSectionState>();

  // The note is saved when the field loses focus, when the sheet closes, a
  // moment after the last keystroke and when the app leaves the foreground
  // (the system may kill it there, H-T19-1); a field the user never typed in
  // writes nothing.
  bool _noteDirty = false;
  Timer? _autosave;

  /// A save of this typing session was already made: the next ones join its
  /// undo step. Ends when the field loses focus.
  bool _noteSaved = false;
  bool _holidayNameShown = false;

  /// The note field has some text (typed or stored): «Borrar día» has
  /// something to clear.
  bool _noteHasText = false;

  /// The palette is open. `null`: the default, open only while the day has
  /// no shift (adding one is what an empty day is opened for).
  bool? _paletteOpen;

  /// The palette swaps the shift at this index instead of adding one.
  int? _changing;

  bool _moreOpen = false;

  CivilDate get _date => widget.date;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule = ref.read(scheduleControllerProvider.notifier);
    _draft = ref.read(noteDraftProvider.notifier);
    _note.text =
        ref.read(scheduleControllerProvider).schedule.entries[_date]?.note ??
        '';
    // The same day was being typed in the other face (sheet <-> pane on a
    // rotation): carry on from where it was.
    final draft = ref.read(noteDraftProvider);
    if (draft != null && draft.date == _date) {
      _note.text = draft.text;
      _noteDirty = true;
    }
    _noteHasText = _note.text.trim().isNotEmpty;
    final holiday = ref.read(holidaysProvider)[_date];
    if (holiday != null && holiday.isUserAdded) {
      _holidayName.text = holiday.name;
      _holidayNameShown = true;
    }
    _noteFocus.addListener(() {
      if (!_noteFocus.hasFocus) _commitNote();
    });
    _holidayFocus.addListener(() {
      if (!_holidayFocus.hasFocus) _commitHolidayName();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autosave?.cancel();
    // Closing by any route (scrim, drag, back) ends here at the latest. The
    // write waits for the end of the frame: the tree is locked right now.
    if (_noteDirty) {
      final text = _note.text;
      final date = _date;
      final schedule = _schedule;
      final draft = _draft;
      final continues = _noteSaved;
      scheduleMicrotask(() {
        schedule.setNote(date, text, continuesTyping: continues);
        draft.clear(date);
      });
    }
    _note.dispose();
    _noteFocus.dispose();
    _holidayName.dispose();
    _holidayFocus.dispose();
    super.dispose();
  }

  void _commitNote({bool endsTyping = true}) {
    _autosave?.cancel();
    if (!_noteDirty) {
      if (endsTyping) _noteSaved = false;
      return;
    }
    _noteDirty = false;
    _schedule.setNote(_date, _note.text, continuesTyping: _noteSaved);
    _draft.clear(_date);
    _noteSaved = !endsTyping;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Going to the background (a call, the home button): the system may kill
    // the app from here without any further notice.
    if (state != AppLifecycleState.resumed) _commitNote(endsTyping: false);
  }

  /// Saves what is typed now (a sheet that is about to give its day to the
  /// pane, so the old field cannot overwrite what the new one will type).
  void commitPending() {
    _extras.currentState?.commitPending();
    _extraAmount.currentState?.commitPending();
    _commitNote();
    _commitHolidayName();
  }

  void _commitHolidayName() {
    final holiday = ref.read(holidaysProvider)[_date];
    if (holiday == null || !holiday.isUserAdded) return;
    final text = _holidayName.text.trim();
    if (text.isEmpty) {
      _holidayName.text = holiday.name;
    } else if (text != holiday.name) {
      unawaited(_guard(() => _addHoliday(text)));
    }
  }

  Future<void> _addHoliday(String name) => ref
      .read(holidayControllerProvider.notifier)
      .addUserHoliday(date: _date, name: name);

  /// Runs a holiday write; a failure is told to the user, never thrown.
  Future<void> _guard(Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failed = context.l10n.saveFailed;
    try {
      await action();
    } catch (_) {
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(appSnackBar(content: Text(failed)));
    }
  }

  Future<void> _setUserHoliday(bool on) async {
    _commitNote();
    final defaultName = context.l10n.dayDetailUserHolidayDefault;
    await _guard(
      on
          ? () => _addHoliday(defaultName)
          : () => ref
                .read(holidayControllerProvider.notifier)
                .removeUserHoliday(_date),
    );
  }

  void _setShifts(List<String> ids) {
    _commitNote();
    _schedule.setDayShifts(_date, ids);
  }

  void _move(List<String> ids, int index, int by) {
    final target = index + by;
    if (target < 0 || target >= ids.length) return;
    final next = [...ids];
    final moved = next.removeAt(index);
    next.insert(target, moved);
    // The palette was swapping one of them: the index no longer holds.
    setState(() => _changing = null);
    _setShifts(next);
  }

  void _remove(List<String> ids, int index) {
    setState(() {
      // Back to the default: an emptied day opens the palette again.
      _paletteOpen = null;
      _changing = null;
    });
    _setShifts([
      for (final (i, id) in ids.indexed)
        if (i != index) id,
    ]);
  }

  /// A puck of the palette: added to the day, or in place of the shift being
  /// changed. The palette closes; the new row says what happened.
  void _pick(List<String> ids, String id, int? changing) {
    final next = [...ids];
    if (changing != null) {
      next[changing] = id;
    } else {
      next.add(id);
    }
    setState(() {
      _paletteOpen = null;
      _changing = null;
    });
    _setShifts(next);
  }

  void _openPalette({int? changing}) {
    _commitNote();
    setState(() {
      _paletteOpen = true;
      _changing = changing;
    });
  }

  void _closePalette() => setState(() {
    _paletteOpen = false;
    _changing = null;
  });

  /// «Deshacer» of the header (A7): undoes the latest step of the history
  /// when it is a change to this day only (what is being typed is saved
  /// first, so it is that). The own holiday and «Sin alarma este día» are not
  /// part of the schedule's history; they are undone with their own switch.
  void _undoLast() {
    _extras.currentState?.commitPending();
    _extraAmount.currentState?.commitPending();
    _commitNote();
    final step = _schedule.lastStepOnlyOn(_date);
    if (step == null) return;
    undoWithFeedback(context, _schedule, step: step);
    // The field shows what the day has now.
    final text =
        ref.read(scheduleControllerProvider).schedule.entries[_date]?.note ??
        '';
    if (_note.text != text) _note.text = text;
    setState(() {
      _noteHasText = text.trim().isNotEmpty;
      _paletteOpen = null;
      _changing = null;
    });
  }

  Future<void> _duplicate() async {
    _commitNote();
    final l10n = context.l10n;
    final format = AppDateFormat.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final close = widget.onClose;
    final from = DateTime(_date.year, _date.month, _date.day);
    // Calendar arithmetic, not `from + 24 h`: the day the clocks go back is
    // 25 h long and would propose the same day again.
    final next = _date.addDays(1);
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(next.year, next.month, next.day),
      firstDate: DateTime(from.year - 1),
      lastDate: DateTime(from.year + 3, 12, 31),
      helpText: l10n.dayDetailDuplicateHelp,
    );
    if (picked == null || !mounted) return;
    final to = CivilDate.fromDateTime(picked);
    if (to == _date) return;
    final schedule = _schedule;
    final step = schedule.copyDay(_date, to);
    close();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        appSnackBar(
          context: context,
          content: Text(l10n.dayDetailDuplicated(format.longDate(picked))),
          // Nothing to undo when the day already was like that. Otherwise
          // only while the copy is still the latest thing done.
          action: step == null
              ? null
              : SnackBarAction(
                  label: l10n.undo,
                  onPressed: () => schedule.undoIfLast(step),
                ),
        ),
      );
  }

  /// "Borrar día": leaves the day with nothing of its own (shifts, note,
  /// reminder, extra and missing minutes, own holiday), closes the sheet (the
  /// notice would hide behind it) and offers to undo it all, like "Duplicar
  /// en otro día".
  void _clear() {
    _extras.currentState?.commitPending();
    _extraAmount.currentState?.commitPending();
    _commitNote();
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final close = widget.onClose;
    final schedule = _schedule;
    final holidays = ref.read(holidayControllerProvider.notifier);
    final holiday = ref.read(holidaysProvider)[_date];
    final own = holiday != null && holiday.isUserAdded ? holiday : null;
    final date = _date;
    final step = schedule.clearDayCompletely(date);
    if (own != null) {
      unawaited(_guard(() => holidays.removeUserHoliday(date)));
    }
    close();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        appSnackBar(
          context: context,
          content: Text(l10n.dayDetailCleared),
          action: step == null && own == null
              ? null
              : SnackBarAction(
                  label: l10n.undo,
                  onPressed: () {
                    // Only while nothing else was done to the day; the own
                    // holiday comes back with the rest.
                    final undone = step == null || schedule.undoIfLast(step);
                    if (undone && own != null) {
                      unawaited(
                        holidays.addUserHoliday(
                          date: date,
                          name: own.name,
                          scope: own.scope,
                        ),
                      );
                    }
                  },
                ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    final format = AppDateFormat.of(context);
    final schedule = ref.watch(
      scheduleControllerProvider.select((s) => s.schedule),
    );
    final palette = ref.watch(
      scheduleControllerProvider.select((s) => s.palette),
    );
    final holiday = ref.watch(holidaysProvider.select((m) => m[_date]));
    final userHoliday = holiday != null && holiday.isUserAdded ? holiday : null;
    if (userHoliday == null) {
      _holidayNameShown = false;
    } else if (!_holidayNameShown) {
      _holidayName.text = userHoliday.name;
      _holidayNameShown = true;
    }
    final today = CivilDate.fromDateTime(ref.watch(clockProvider)());
    final alarmSkip = watchDayAlarmSkip(ref, _date);
    final sections = ref.watch(dayMoreSectionsProvider);

    final day = schedule.resolve(_date);
    final entry = schedule.entries[_date];
    final reminder = entry?.noteReminderMinute;
    final overtime = entry?.overtimeMinutes ?? 0;
    final earlyLeave = entry?.earlyLeaveMinutes ?? 0;
    final extraAmount = entry?.extraAmountCents ?? 0;
    // Anything «Borrar día» would remove: a shift, the note, its reminder,
    // the extra or missing minutes or the own holiday (H-T09-2).
    final hasContent =
        day.shifts.isNotEmpty ||
        _noteHasText ||
        reminder != null ||
        overtime > 0 ||
        earlyLeave > 0 ||
        extraAmount != 0 ||
        userHoliday != null;
    final ids = day.shiftIds;
    final isOverride = day.source == DaySource.override;
    final date = DateTime(_date.year, _date.month, _date.day);
    // A swap whose row is gone (undone, removed) falls back to adding.
    final changing = _changing != null && _changing! < day.shifts.length
        ? _changing
        : null;
    final paletteOpen =
        palette.isNotEmpty &&
        (changing != null || (_paletteOpen ?? day.shifts.isEmpty));
    final canUndo = _noteDirty || _schedule.lastStepOnlyOn(_date) != null;

    const gutter = EdgeInsets.symmetric(horizontal: Sp.page);

    final undoButton = IconButton(
      key: const ValueKey('day-undo'),
      tooltip: l10n.dayDetailUndo,
      icon: Icon(AppIcons.undo),
      onPressed: canUndo ? _undoLast : null,
    );

    // The date and the holiday stay put above the scrolling part: nothing in
    // it takes the vertical drag, so dragging them closes the sheet like
    // dragging the handle does.
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.inline)
          Semantics(
            header: true,
            child: Text(
              capitalize(format.longDate(date)),
              style: type.headline,
            ),
          ),
        if (holiday != null) ...[
          if (!widget.inline) const SizedBox(height: Sp.xs),
          Text(
            holidayLine(l10n, holidayDisplayName(l10n, holiday)),
            key: const ValueKey('day-holiday-line'),
            style: type.bodyStrong.copyWith(color: colors.holiday),
          ),
        ],
      ],
    );
    final header = Padding(
      padding: widget.inline
          ? const EdgeInsets.fromLTRB(Sp.page, Sp.xs, Sp.xs, Sp.xs)
          : const EdgeInsets.fromLTRB(Sp.page, 0, Sp.s, Sp.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: widget.inline ? Sp.s : Sp.xs),
              child: title,
            ),
          ),
          undoButton,
          // In the pane the way back to the "today" view is a button.
          if (widget.inline)
            IconButton(
              key: const ValueKey('day-pane-close'),
              tooltip: l10n.dayPaneClose,
              icon: Icon(AppIcons.close, color: colors.textMuted),
              onPressed: widget.onClose,
            ),
        ],
      ),
    );

    final shifts = <Widget>[
      if (day.shifts.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Sp.s),
          child: Text(l10n.daySheetEmpty, style: type.body),
        )
      else ...[
        for (final (index, shift) in day.shifts.indexed)
          _ShiftRow(
            key: ValueKey('day-shift-$index'),
            index: index,
            shift: shift,
            format: format,
            isFirst: index == 0,
            isLast: index == day.shifts.length - 1,
            canChange: palette.isNotEmpty,
            onChange: () => _openPalette(changing: index),
            onMoveUp: () => _move(ids, index, -1),
            onMoveDown: () => _move(ids, index, 1),
            onRemove: () => _remove(ids, index),
          ),
        Text(
          isOverride
              ? l10n.dayDetailSourceOverride
              : l10n.dayDetailSourcePattern,
          style: type.meta,
        ),
      ],
      if (isOverride) ...[
        const SizedBox(height: Sp.m),
        SecondaryButton(
          key: const ValueKey('day-reset'),
          icon: AppIcons.undo,
          label: l10n.dayDetailReset,
          expand: false,
          onPressed: () {
            _commitNote();
            setState(() => _changing = null);
            _schedule.resetToPattern(_date);
          },
        ),
        const SizedBox(height: Sp.xs),
        Text(
          l10n.dayDetailPatternGives(
            shiftsLine(l10n, format, schedule.resolvePattern(_date).shifts),
          ),
          key: const ValueKey('day-pattern-gives'),
          style: type.meta,
        ),
      ],
    ];

    final Widget? add;
    if (palette.isEmpty) {
      add = null;
    } else if (paletteOpen) {
      add = DayPalettePanel(
        title: changing != null
            ? l10n.dayDetailChangeTitle(day.shifts[changing].name)
            : (day.shifts.isEmpty ? l10n.dayDetailAdd : l10n.dayDetailDouble),
        hint: changing == null && day.shifts.isNotEmpty
            ? l10n.dayDetailChangeHint
            : null,
        palette: palette,
        taken: ids.toSet(),
        onPick: (id) => _pick(ids, id, changing),
        onClose: _closePalette,
      );
    } else {
      add = SecondaryButton(
        key: const ValueKey('day-add-open'),
        icon: AppIcons.add,
        label: l10n.dayDetailAdd,
        onPressed: _openPalette,
      );
    }

    // The clip sits on the first line of the note, lined up with the help
    // text: a `prefixIcon` would be centred in the whole (two-line) field,
    // half-way down the note.
    final noteLine = type.body.fontSize! * type.body.height!;
    final note = Semantics(
      label: l10n.daySheetNote,
      child: Stack(
        children: [
          TextField(
            key: const ValueKey('day-note'),
            controller: _note,
            focusNode: _noteFocus,
            minLines: 2,
            maxLines: 6,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: l10n.dayDetailNoteHint,
              contentPadding: const EdgeInsets.fromLTRB(
                Sp.l + IconSize.inline + Sp.s,
                Sp.l,
                Sp.l,
                Sp.l,
              ),
            ),
            onChanged: (text) {
              final wasDirty = _noteDirty;
              _noteDirty = true;
              _draft.set(_date, text);
              _autosave?.cancel();
              _autosave = Timer(
                noteAutosaveDelay,
                () => _commitNote(endsTyping: false),
              );
              final has = text.trim().isNotEmpty;
              // «Deshacer» wakes up with the first keystroke; «Borrar día»
              // follows whether there is text.
              if (has != _noteHasText || !wasDirty) {
                setState(() => _noteHasText = has);
              }
            },
          ),
          PositionedDirectional(
            start: Sp.l,
            top: Sp.l + (noteLine - IconSize.inline) / 2,
            child: IgnorePointer(
              child: Icon(
                AppIcons.note,
                size: IconSize.inline,
                color: colors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );

    String clock(int m) => format.time(DateTime(2000, 1, 1, m ~/ 60, m % 60));
    final moreSummary = [
      overtime > 0
          ? l10n.dayExtrasValue(l10n.dayMoreExtras, formatHours(l10n, overtime))
          : l10n.dayMoreExtras,
      if (earlyLeave > 0)
        l10n.dayExtrasValue(
          l10n.dayExtrasEarlyLeave,
          formatHours(l10n, earlyLeave),
        ),
      extraAmount != 0
          ? l10n.dayExtrasValue(
              l10n.moneyExtraTitle,
              formatMoneyCents(context, extraAmount),
            )
          : l10n.moneyExtraTitle,
      l10n.dayDetailUserHoliday,
      // A reminder for a day gone by could never ring: not offered then.
      if (reminder != null)
        l10n.dayExtrasValue(l10n.dayMoreReminder, clock(reminder))
      else if (!_date.isBefore(today))
        l10n.dayMoreReminder,
      if (alarmSkip != null) alarmSkip ? l10n.alarmsSkipDay : l10n.dayMoreAlarm,
      for (final section in sections) section.name(l10n),
      l10n.dayMoreDuplicate,
      l10n.dayMoreClear,
    ].join(' · ');

    final more = DayMoreOptions(
      open: _moreOpen,
      onToggle: () => setState(() => _moreOpen = !_moreOpen),
      summary: moreSummary,
      children: [
        DayExtrasSection(key: _extras, date: _date),
        DayExtraAmountSection(key: _extraAmount, date: _date),
        const SizedBox(height: Sp.s),
        SwitchListTile(
          key: const ValueKey('day-holiday-switch'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.dayDetailUserHoliday),
          value: userHoliday != null,
          onChanged: _setUserHoliday,
        ),
        if (userHoliday != null) ...[
          const SizedBox(height: Sp.xs),
          TextField(
            key: const ValueKey('day-holiday-name'),
            controller: _holidayName,
            focusNode: _holidayFocus,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: l10n.dayDetailUserHolidayNameHint,
            ),
            onSubmitted: (_) => _commitHolidayName(),
          ),
        ],
        DayReminderRow(date: _date),
        DayAlarmSkipRow(date: _date),
        for (final section in sections)
          KeyedSubtree(
            key: ValueKey('day-more-${section.id}'),
            child: section.builder(context, _date),
          ),
        const SizedBox(height: Sp.l),
        Wrap(
          spacing: Sp.s,
          runSpacing: Sp.s,
          children: [
            SecondaryButton(
              key: const ValueKey('day-duplicate'),
              icon: AppIcons.copy,
              label: l10n.dayDetailDuplicate,
              expand: false,
              onPressed: _duplicate,
            ),
            SecondaryButton(
              key: const ValueKey('day-clear'),
              icon: AppIcons.erase,
              label: l10n.dayDetailClear,
              expand: false,
              onPressed: hasContent ? _clear : null,
            ),
          ],
        ),
        const SizedBox(height: Sp.s),
      ],
    );

    final content = Padding(
      padding: gutter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...shifts,
          if (add != null) ...[const SizedBox(height: Sp.m), add],
          // The appointments of the phone for this day (P6): nothing when the
          // day has none.
          DeviceEventsDaySection(date: _date),
          const SizedBox(height: Sp.l),
          note,
          const SizedBox(height: Sp.m),
          more,
        ],
      ),
    );

    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    if (widget.inline) {
      // The pane gives the height (the screen already sits above the
      // keyboard) and scrolls what does not fit.
      return PopScope(
        onPopInvokedWithResult: (_, _) => commitPending(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            Expanded(
              child: SingleChildScrollView(
                key: const ValueKey('day-pane-scroll'),
                padding: EdgeInsets.only(bottom: Sp.l + widget.bottomRoom),
                child: content,
              ),
            ),
          ],
        ),
      );
    }
    return PopScope(
      onPopInvokedWithResult: (_, _) => commitPending(),
      child: LayoutBuilder(
        builder: (context, box) {
          // The screen below the status bar, and what the sheet gives this
          // body (less: the drag handle above it).
          final screen =
              MediaQuery.sizeOf(context).height -
              MediaQuery.paddingOf(context).top;
          final room = box.hasBoundedHeight ? box.maxHeight : screen;
          // As tall as the content, the whole sheet up to a share of the
          // screen; with the keyboard up the sheet sits above it and only
          // shrinks if it would not fit. What does not fit scrolls.
          final maxHeight = math.max(
            0.0,
            math.min(
              screen * maxHeightFactor - math.max(0.0, screen - room),
              room - keyboard,
            ),
          );
          return Padding(
            padding: EdgeInsets.only(bottom: keyboard),
            child: AnimatedSize(
              duration: Motion.of(context, Motion.state),
              curve: Motion.curve,
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                key: const ValueKey('day-sheet-body'),
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      header,
                      Flexible(
                        child: SingleChildScrollView(
                          key: const ValueKey('day-sheet-scroll'),
                          padding: const EdgeInsets.only(bottom: Sp.l),
                          child: content,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

enum _ShiftAction { change, up, down, remove }

/// One shift of the day: badge, name, times and hours, and its menu
/// (change, up, down, remove).
class _ShiftRow extends StatelessWidget {
  const _ShiftRow({
    super.key,
    required this.index,
    required this.shift,
    required this.format,
    required this.isFirst,
    required this.isLast,
    required this.canChange,
    required this.onChange,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  });

  final int index;
  final ShiftType shift;
  final AppDateFormat format;
  final bool isFirst;
  final bool isLast;
  final bool canChange;
  final VoidCallback onChange;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    final times = shift.timeRange(format);
    final paid = shift.hasTimes ? shift.effectivePaidMinutes : 0;
    final detail = times == null
        ? null
        : (paid > 0 ? '$times · ${durationText(l10n, paid)}' : times);
    final several = !(isFirst && isLast);

    PopupMenuItem<_ShiftAction> item(
      _ShiftAction action,
      String key,
      IconData icon,
      String label, {
      bool enabled = true,
    }) => PopupMenuItem(
      key: ValueKey(key),
      value: action,
      enabled: enabled,
      child: Row(
        children: [
          Icon(
            icon,
            size: IconSize.button,
            color: enabled ? colors.textSecondary : colors.disabledContent,
          ),
          const SizedBox(width: Sp.m),
          Flexible(child: Text(label)),
        ],
      ),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: Disc.l + Sp.l),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Sp.xs),
        child: Row(
          children: [
            ShiftBadge(shift: shift),
            const SizedBox(width: Sp.m),
            Expanded(
              child: Semantics(
                container: true,
                label: shift.spoken(l10n, format),
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shift.name, style: type.bodyStrong),
                    if (detail != null)
                      Text(
                        detail,
                        style: AppTypography.tabular(
                          type.body.copyWith(color: colors.textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            PopupMenuButton<_ShiftAction>(
              key: ValueKey('day-shift-menu-$index'),
              tooltip: l10n.dayDetailShiftMenu(shift.name),
              icon: Icon(AppIcons.more, color: colors.textSecondary),
              onSelected: (action) => switch (action) {
                _ShiftAction.change => onChange(),
                _ShiftAction.up => onMoveUp(),
                _ShiftAction.down => onMoveDown(),
                _ShiftAction.remove => onRemove(),
              },
              itemBuilder: (_) => [
                if (canChange)
                  item(
                    _ShiftAction.change,
                    'day-change-$index',
                    AppIcons.edit,
                    l10n.dayDetailChange,
                  ),
                if (several) ...[
                  item(
                    _ShiftAction.up,
                    'day-up-$index',
                    AppIcons.arrowUp,
                    l10n.dayDetailMoveUp,
                    enabled: !isFirst,
                  ),
                  item(
                    _ShiftAction.down,
                    'day-down-$index',
                    AppIcons.arrowDown,
                    l10n.dayDetailMoveDown,
                    enabled: !isLast,
                  ),
                ],
                item(
                  _ShiftAction.remove,
                  'day-remove-$index',
                  AppIcons.remove,
                  l10n.dayDetailRemove(shift.name),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
