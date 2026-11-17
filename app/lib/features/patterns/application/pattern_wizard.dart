import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers.dart';
import '../../schedule/application/schedule_providers.dart';
import '../../calendar/application/schedule_controller.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../domain/pattern_application.dart';
import '../domain/pattern_catalog.dart';
import '../domain/pattern_blocks.dart';
import '../domain/weeks_per_shift.dart';
import 'post_night_provider.dart';

/// How the wizard is opened: the start day (the one long-pressed in paint
/// mode, else today) and the shift whose typical patterns go first.
typedef PatternWizardArgs = ({CivilDate? start, String? shiftId});

/// Steps of the wizard.
enum WizardStep { choose, start, end }

/// What the user has decided so far. The pattern is chosen in step 1 (a
/// catalogue preset, a pattern they saved before, or one built here), the
/// day in step 2 and the end in step 3.
class PatternWizardState {
  const PatternWizardState({
    required this.start,
    this.step = WizardStep.choose,
    this.presetId,
    this.workShiftId = 'morning',
    this.customId,
    this.building = false,
    this.weeksTemplate = false,
    this.weekShiftIds = const [],
    this.weekCounts = const [],
    this.weekMode = WeeksPerShiftMode.allDays,
    this.editingCopy = false,
    this.alignWeekdays = false,
    this.draft = const [],
    this.draftBlocks,
    this.canUndoDraft = false,
    this.openBlock,
    this.draftName = '',
    this.sameDay = false,
    this.stepOffset = 0,
    this.until,
    this.clearOverrides = false,
    this.applying = false,
  });

  final WizardStep step;
  final CivilDate start;

  /// Catalogue preset chosen.
  final String? presetId;
  final String workShiftId;

  /// Pattern saved earlier chosen.
  final String? customId;

  /// "Crear el mío": the sequence builder is open and [draft] is the choice.
  final bool building;
  final bool weeksTemplate;
  final List<String> weekShiftIds;
  final List<int> weekCounts;
  final WeeksPerShiftMode weekMode;
  final bool editingCopy;
  final bool alignWeekdays;

  /// The sequence being built: one list of shift type ids per day.
  final List<List<String>> draft;
  final List<PatternBlock>? draftBlocks;
  List<PatternBlock> get blocks => draftBlocks ?? compressSteps(draft);
  final bool canUndoDraft;
  final int? openBlock;
  final String draftName;

  /// The builder adds the next shift to the last day instead of a new day.
  final bool sameDay;

  /// Cycle step that falls on [start].
  final int stepOffset;

  /// Last day, or `null` = no end.
  final CivilDate? until;

  /// Replace the days changed by hand in the range (off = respect them).
  final bool clearOverrides;
  final bool applying;

  bool get hasChoice => building || weeksTemplate
      ? draft.isNotEmpty && draft.length <= maxPatternCycleDays
      : presetId != null || customId != null;

  PatternWizardState copyWith({
    WizardStep? step,
    CivilDate? start,
    String? presetId,
    String? workShiftId,
    String? customId,
    bool clearChoice = false,
    bool? building,
    bool? weeksTemplate,
    List<String>? weekShiftIds,
    List<int>? weekCounts,
    WeeksPerShiftMode? weekMode,
    bool? editingCopy,
    bool? alignWeekdays,
    List<List<String>>? draft,
    List<PatternBlock>? draftBlocks,
    bool? canUndoDraft,
    int? openBlock,
    bool closeBlock = false,
    String? draftName,
    bool? sameDay,
    int? stepOffset,
    CivilDate? until,
    bool clearUntil = false,
    bool? clearOverrides,
    bool? applying,
  }) => PatternWizardState(
    step: step ?? this.step,
    start: start ?? this.start,
    // With [clearChoice] the given ids replace the choice (null = none).
    presetId: clearChoice ? presetId : presetId ?? this.presetId,
    workShiftId: workShiftId ?? this.workShiftId,
    customId: clearChoice ? customId : customId ?? this.customId,
    building: building ?? this.building,
    weeksTemplate: weeksTemplate ?? this.weeksTemplate,
    weekShiftIds: weekShiftIds ?? this.weekShiftIds,
    weekCounts: weekCounts ?? this.weekCounts,
    weekMode: weekMode ?? this.weekMode,
    editingCopy: editingCopy ?? this.editingCopy,
    alignWeekdays: alignWeekdays ?? this.alignWeekdays,
    draft: draft ?? this.draft,
    draftBlocks: draftBlocks ?? this.draftBlocks,
    canUndoDraft: canUndoDraft ?? this.canUndoDraft,
    openBlock: closeBlock ? null : openBlock ?? this.openBlock,
    draftName: draftName ?? this.draftName,
    sameDay: sameDay ?? this.sameDay,
    stepOffset: stepOffset ?? this.stepOffset,
    until: clearUntil ? null : until ?? this.until,
    clearOverrides: clearOverrides ?? this.clearOverrides,
    applying: applying ?? this.applying,
  );
}

class PatternWizardController extends Notifier<PatternWizardState> {
  PatternWizardController(this.args);

  final PatternWizardArgs args;

  // Id the pattern gets if the user builds it here.
  final String _draftId = 'custom-${const Uuid().v4()}';
  ({
    List<PatternBlock> blocks,
    bool alignWeekdays,
    int stepOffset,
    int? openBlock,
  })?
  _undoDraft;
  List<List<String>> _openedDraft = const [];
  String _openedName = '';
  List<String> _openedWeekShiftIds = const [];
  List<int> _openedWeekCounts = const [];
  WeeksPerShiftMode _openedWeekMode = WeeksPerShiftMode.allDays;

  /// Compare the sequence and template settings with how the editor opened,
  /// ignoring the open block and undo availability. Keep that baseline when
  /// switching from the template to blocks; reverting all edits is clean again.
  bool get hasDraftChanges =>
      (state.building || state.weeksTemplate) &&
      (state.draftName != _openedName ||
          !listEquals(state.weekShiftIds, _openedWeekShiftIds) ||
          !listEquals(state.weekCounts, _openedWeekCounts) ||
          state.weekMode != _openedWeekMode ||
          state.draft.length != _openedDraft.length ||
          !List.generate(
            state.draft.length,
            (i) => listEquals(state.draft[i], _openedDraft[i]),
          ).every((same) => same));

  void _rememberOpenedDraft() {
    _openedDraft = [for (final day in state.draft) List<String>.of(day)];
    _openedName = state.draftName;
    _openedWeekShiftIds = List<String>.of(state.weekShiftIds);
    _openedWeekCounts = List<int>.of(state.weekCounts);
    _openedWeekMode = state.weekMode;
  }

  @override
  PatternWizardState build() {
    final today = CivilDate.fromDateTime(ref.read(clockProvider)());
    final shift = args.shiftId == null
        ? null
        : ref
              .read(scheduleControllerProvider)
              .schedule
              .shiftTypeById(args.shiftId!);
    return PatternWizardState(
      start: args.start ?? today,
      workShiftId: shift != null && shift.category == ShiftCategory.work
          ? shift.id
          : 'morning',
    );
  }

  // ---- step 1: the pattern ------------------------------------------------

  void selectPreset(String presetId) => state = state.copyWith(
    clearChoice: true,
    presetId: presetId,
    building: false,
    weeksTemplate: false,
    editingCopy: false,
    alignWeekdays: false,
    stepOffset: 0,
  );

  void selectCustom(String patternId) => state = state.copyWith(
    clearChoice: true,
    customId: patternId,
    building: false,
    weeksTemplate: false,
    editingCopy: false,
    alignWeekdays: false,
    stepOffset: 0,
  );

  void startBuilding() {
    _rememberOpenedDraft();
    state = state.copyWith(
      clearChoice: true,
      building: true,
      weeksTemplate: false,
      editingCopy: false,
      stepOffset: 0,
      alignWeekdays: false,
    );
  }

  void stopBuilding() {
    if (!state.building) {
      state = state.copyWith(weeksTemplate: false, editingCopy: false);
      return;
    }
    _undoDraft = null;
    state = state.copyWith(
      building: false,
      weeksTemplate: false,
      editingCopy: false,
      draft: _openedDraft,
      draftBlocks: compressSteps(_openedDraft),
      draftName: _openedName,
      canUndoDraft: false,
      closeBlock: true,
    );
  }

  void startWeeksTemplate(String name) {
    _undoDraft = null;
    state = state.copyWith(
      clearChoice: true,
      building: false,
      weeksTemplate: true,
      editingCopy: false,
      draft: const [],
      draftBlocks: const [],
      alignWeekdays: false,
      weekShiftIds: const [],
      weekCounts: const [],
      weekMode: WeeksPerShiftMode.allDays,
      draftName: name,
      canUndoDraft: false,
      closeBlock: true,
      stepOffset: 0,
    );
    _rememberOpenedDraft();
  }

  bool toggleWeekShift(String id) {
    final ids = [...state.weekShiftIds];
    final counts = [...state.weekCounts];
    final index = ids.indexOf(id);
    if (index < 0) {
      ids.add(id);
      counts.add(1);
    } else {
      ids.removeAt(index);
      counts.removeAt(index);
    }
    return _setWeeks(ids, counts, state.weekMode);
  }

  bool setWeekCount(int index, int count) {
    if (count < 1 || count > 8) return false;
    final counts = [...state.weekCounts]..[index] = count;
    return _setWeeks(state.weekShiftIds, counts, state.weekMode);
  }

  bool setWeekMode(WeeksPerShiftMode mode) =>
      _setWeeks(state.weekShiftIds, state.weekCounts, mode);

  bool _setWeeks(List<String> ids, List<int> counts, WeeksPerShiftMode mode) {
    final steps = ids.isEmpty
        ? <List<String>>[]
        : weeksPerShift(
            shiftIds: ids,
            weeks: counts,
            mode: mode,
            restShiftId: 'rest',
          );
    if (steps.length > maxPatternCycleDays) return false;
    state = state.copyWith(
      weekShiftIds: List.unmodifiable(ids),
      weekCounts: List.unmodifiable(counts),
      weekMode: mode,
      draft: steps,
      draftBlocks: compressSteps(steps),
      alignWeekdays: mode == WeeksPerShiftMode.weekdays,
      stepOffset: mode == WeeksPerShiftMode.weekdays
          ? weeksPerShiftStepOffset(state.start)
          : 0,
    );
    return true;
  }

  void adjustWeeksByHand() {
    state = state.copyWith(
      weeksTemplate: false,
      building: true,
      canUndoDraft: false,
      closeBlock: true,
    );
  }

  /// Start from an independent draft. Neither the source nor its runs change.
  void editAsCopy(Pattern pattern) {
    _undoDraft = null;
    state = state.copyWith(
      clearChoice: true,
      building: true,
      weeksTemplate: false,
      editingCopy: true,
      draftName: pattern.name,
      alignWeekdays: false,
      draft: [for (final step in pattern.steps) List<String>.of(step)],
      draftBlocks: compressSteps(pattern.steps),
      canUndoDraft: false,
      closeBlock: true,
      stepOffset: 0,
    );
    _rememberOpenedDraft();
  }

  Future<bool> saveCopy({
    required String fallbackName,
    required String Function(String, int) copyName,
  }) async {
    if (state.applying ||
        state.draft.isEmpty ||
        state.draft.length > maxPatternCycleDays) {
      return false;
    }
    state = state.copyWith(applying: true);
    try {
      final saved = await ref
          .read(scheduleControllerProvider.notifier)
          .saveAsNewPattern(
            steps: state.draft,
            name: state.draftName.trim().isEmpty
                ? fallbackName
                : state.draftName,
            copyName: copyName,
          );
      if (!ref.mounted || saved == null) return false;
      selectCustom(saved.id);
      next();
      return true;
    } finally {
      if (ref.mounted) state = state.copyWith(applying: false);
    }
  }

  void forgetCustom(String id) {
    if (state.customId == id) {
      state = state.copyWith(clearChoice: true);
    }
  }

  void setSameDay(bool value) => state = state.copyWith(sameDay: value);

  /// A tap on a shift of the builder: a new day, or (with [sameDay]) one
  /// more shift on the last day. Returns false if the builder limit rejects it.
  bool appendShift(String shiftTypeId) {
    if (!state.sameDay) {
      final blocks = state.blocks;
      final int index;
      final PatternBlockEdit edit;
      if (blocks.isNotEmpty &&
          blocks.last.shiftIds.length == 1 &&
          blocks.last.shiftIds.single == shiftTypeId) {
        index = blocks.length - 1;
        edit = setBlockDays(blocks, index, blocks.last.days + 1);
      } else {
        index = blocks.length;
        edit = insertBlock(
          blocks,
          index,
          PatternBlock(shiftIds: [shiftTypeId], days: 1),
        );
      }
      if (!editBlocks(edit)) return false;
      state = state.copyWith(openBlock: index);
      return true;
    }
    if ((!state.sameDay || state.draft.isEmpty) &&
        state.draft.length >= maxPatternCycleDays) {
      return false;
    }
    final draft = [for (final s in state.draft) List<String>.of(s)];
    if (state.sameDay && draft.isNotEmpty) {
      if (!draft.last.contains(shiftTypeId)) draft.last.add(shiftTypeId);
    } else {
      draft.add([shiftTypeId]);
    }
    return replaceBlocks(compressSteps(draft));
  }

  /// Keeps block boundaries (including a split) while the saved pattern stays
  /// the same flat list of days. One accepted operation is one undo step.
  bool editBlocks(PatternBlockEdit edit) =>
      !edit.exceedsLimit && replaceBlocks(edit.blocks);

  void toggleBlock(int index) => state = state.copyWith(
    openBlock: index,
    closeBlock: state.openBlock == index,
  );

  void showBlock(int? index) =>
      state = state.copyWith(openBlock: index, closeBlock: index == null);

  bool replaceBlocks(List<PatternBlock> blocks) {
    if (exceedsPatternCycleLimit(blocks)) return false;
    final before = state.blocks;
    if (before.length == blocks.length &&
        List.generate(
          blocks.length,
          (i) => before[i] == blocks[i],
        ).every((same) => same)) {
      return true;
    }
    _undoDraft = (
      blocks: before,
      alignWeekdays: state.alignWeekdays,
      stepOffset: state.stepOffset,
      openBlock: state.openBlock,
    );
    state = state.copyWith(
      draftBlocks: List.unmodifiable(blocks),
      draft: expandBlocks(blocks),
      canUndoDraft: true,
      alignWeekdays: false,
      stepOffset: 0,
    );
    return true;
  }

  void undoDraft() {
    final before = _undoDraft;
    if (before == null) return;
    _undoDraft = null;
    final openBlock = before.blocks.isEmpty
        ? null
        : before.openBlock?.clamp(0, before.blocks.length - 1);
    state = state.copyWith(
      draftBlocks: before.blocks,
      draft: expandBlocks(before.blocks),
      canUndoDraft: false,
      openBlock: openBlock,
      closeBlock: openBlock == null,
      alignWeekdays: before.alignWeekdays,
      stepOffset: before.alignWeekdays
          ? weeksPerShiftStepOffset(state.start)
          : before.stepOffset,
    );
  }

  /// Takes back the last tap: the last shift of the last day, and the day
  /// when it was the only one.
  void removeLast() {
    if (state.draft.isEmpty) return;
    final draft = [for (final s in state.draft) List<String>.of(s)];
    if (draft.last.length > 1) {
      draft.last.removeLast();
    } else {
      draft.removeLast();
    }
    replaceBlocks(compressSteps(draft));
  }

  void clearDraft() {
    if (state.draft.isNotEmpty) replaceBlocks(const []);
  }

  void setName(String name) => state = state.copyWith(draftName: name);

  // ---- step 2: the start --------------------------------------------------

  void setStart(CivilDate date) => state = state.copyWith(
    start: date,
    stepOffset: state.alignWeekdays
        ? weeksPerShiftStepOffset(date)
        : state.stepOffset,
    // An end before the start is no end at all.
    clearUntil: state.until != null && state.until!.isBefore(date),
  );

  void setStepOffset(int index) => state = state.copyWith(stepOffset: index);

  void setWorkShift(String id) => state = state.copyWith(workShiftId: id);

  // ---- step 3: the end ----------------------------------------------------

  void setEndless() => state = state.copyWith(clearUntil: true);

  void setUntil(CivilDate date) => state = state.copyWith(
    until: date.isBefore(state.start) ? state.start : date,
  );

  void setClearOverrides(bool value) =>
      state = state.copyWith(clearOverrides: value);

  // ---- navigation ---------------------------------------------------------

  void next() {
    if (state.step == WizardStep.choose && !state.hasChoice) return;
    if (state.step == WizardStep.end) return;
    state = state.copyWith(step: WizardStep.values[state.step.index + 1]);
  }

  void back() {
    if (state.step == WizardStep.choose) return;
    state = state.copyWith(step: WizardStep.values[state.step.index - 1]);
  }

  void setApplying(bool value) => state = state.copyWith(applying: value);

  // ---- result -------------------------------------------------------------

  /// The chosen pattern, or `null` while there is none. A built one is named
  /// [fallbackName] when the user left the name empty.
  Pattern? chosenPattern(Schedule schedule, {String fallbackName = ''}) {
    final s = state;
    if (s.building || s.weeksTemplate) {
      if (s.draft.isEmpty) return null;
      final name = s.draftName.trim();
      return Pattern(
        id: _draftId,
        name: name.isEmpty ? fallbackName : name,
        steps: [for (final step in s.draft) List<String>.of(step)],
      );
    }
    if (s.presetId != null) {
      return presetPattern(
        schedule,
        patternPresetById(s.presetId!),
        workShiftId: s.workShiftId,
      );
    }
    if (s.customId != null) return schedule.patternById(s.customId!);
    return null;
  }

  /// What the wizard would apply now, or `null` without a chosen pattern.
  PatternRequest? request(Schedule schedule, {String fallbackName = ''}) {
    final pattern = chosenPattern(schedule, fallbackName: fallbackName);
    if (pattern == null) return null;
    return PatternRequest(
      pattern: pattern,
      from: state.start,
      until: state.until,
      stepOffset: state.stepOffset % pattern.lengthDays,
      clearOverrides: state.clearOverrides,
    );
  }

  /// Applies the pattern ([ScheduleController.applyPatternRun]: one undoable
  /// step). Returns that step (for `undoIfLast`), or `null` when nothing was
  /// applied.
  Future<ScheduleChange?> apply({String fallbackName = ''}) async {
    if (state.applying) return null;
    final controller = ref.read(scheduleControllerProvider.notifier);
    final request = this.request(
      ref.read(scheduleControllerProvider).schedule,
      fallbackName: fallbackName,
    );
    if (request == null) return null;
    state = state.copyWith(applying: true);
    var applied = false;
    try {
      final change = await controller.applyPatternRun(request);
      applied = change != null;
      return change;
    } finally {
      // A successful apply is terminal: the screen is still consuming the
      // remaining taps before it closes. Failures can be retried.
      if (!applied && ref.mounted) state = state.copyWith(applying: false);
    }
  }
}

final patternWizardProvider = NotifierProvider.autoDispose
    .family<PatternWizardController, PatternWizardState, PatternWizardArgs>(
      PatternWizardController.new,
    );

/// The library is shared by calendars. Read after queued edits so removal is
/// offered only for patterns no rotation uses, including archived calendars.
final usedPatternIdsProvider = FutureProvider.autoDispose<Set<String>>((
  ref,
) async {
  final schedule = ref.watch(scheduleControllerProvider).schedule;
  final repository = ref.watch(scheduleRepositoryProvider);
  await ref.read(scheduleControllerProvider.notifier).pendingWrites;
  return {
    ...await repository.usedPatternIds(),
    for (final run in schedule.runs) run.patternId,
  };
});

/// What applying the wizard's choices now would do (the live preview), or
/// `null` while no pattern is chosen. Same planner as the real application.
final patternPreviewProvider = Provider.autoDispose
    .family<PatternApplication?, PatternWizardArgs>((ref, args) {
      // Watched so the preview follows every choice of the wizard.
      ref.watch(patternWizardProvider(args));
      final controller = ref.read(patternWizardProvider(args).notifier);
      final schedule = ref.watch(
        scheduleControllerProvider.select((s) => s.schedule),
      );
      final palette = ref.watch(
        scheduleControllerProvider.select((s) => s.palette),
      );
      final auto = ref.watch(postNightAutoProvider);
      final request = controller.request(schedule);
      if (request == null) return null;
      return planPatternApplication(
        schedule,
        request,
        seq: schedule.runs.fold(0, (m, r) => r.seq > m ? r.seq : m) + 1,
        postNightAuto: auto,
        palette: palette,
      );
    });
