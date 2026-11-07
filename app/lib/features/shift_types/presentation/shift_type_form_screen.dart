import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/format/money.dart';
import '../../../core/icons/app_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../core/router.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/choice_pill.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/content_app_bar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/minute_picker.dart';
import '../../../core/widgets/page_body.dart';
import '../../alarms/application/alarm_providers.dart';
import '../../settings/application/preferences_controller.dart';
import '../../settings/presentation/settings_widgets.dart' show saveSetting;
import '../../alarms/data/alarm_sounds.dart' show AlarmSoundChoice;
import '../../alarms/domain/alarm_planner.dart' show canShiftTypeRing;
import '../../alarms/domain/alarm_settings.dart' show PauseAlertSettings;
import '../../alarms/presentation/alarm_pickers.dart' show pickPauseTiming;
import '../../calendar/application/schedule_controller.dart';
import '../../calendar/presentation/shift_format.dart';
import '../../dnd/application/dnd_providers.dart';
import '../../dnd/domain/dnd_planner.dart' show canSilenceDuring;
import '../../dnd/domain/dnd_settings.dart' show DndTypeSettings;
import '../../schedule/domain/schedule_domain.dart';
import '../domain/shift_type_draft.dart';
import 'shift_code_formatter.dart';
import 'shift_color_grid.dart';
import 'shift_color_picker.dart';
import 'shift_icon_picker.dart';
import 'shift_pause_section.dart';
import 'shift_type_preview.dart';
import 'shift_type_scope_dialog.dart';
import 'shift_type_times_section.dart';

/// Form of one shift type (`turnos-spec.md`, "Ajustes > Mis turnos"): code,
/// name, colour with a live preview in light and dark, category, times, and
/// for worked shifts the unpaid break, night override and hourly rate. A new
/// shift when [shiftTypeId] is null, otherwise the stored one is edited.
class ShiftTypeFormScreen extends ConsumerStatefulWidget {
  const ShiftTypeFormScreen({super.key, this.shiftTypeId});

  final String? shiftTypeId;

  @override
  ConsumerState<ShiftTypeFormScreen> createState() =>
      _ShiftTypeFormScreenState();
}

class _ShiftTypeFormScreenState extends ConsumerState<ShiftTypeFormScreen> {
  late final ShiftType? _editing;
  late final bool _missing;
  late ShiftTypeDraft _draft;

  // The draft as the form opened: leaving with anything else asks first.
  late ShiftTypeDraft _initial;

  final _code = TextEditingController();
  final _name = TextEditingController();
  final _unpaidBreak = TextEditingController();
  final _rate = TextEditingController();
  final _fixedPlus = TextEditingController();
  final _nightPlus = TextEditingController();
  final _holidayPlus = TextEditingController();
  final _location = TextEditingController();
  final _codeFocus = FocusNode();
  final _nameFocus = FocusNode();
  final _breakFocus = FocusNode();
  final _rateFocus = FocusNode();
  final _fixedPlusFocus = FocusNode();
  final _nightPlusFocus = FocusNode();
  final _holidayPlusFocus = FocusNode();
  final _locationFocus = FocusNode();

  // The text of a plus per hour that is not an amount (the draft keeps the
  // last good value; saving waits until it is fixed).
  bool _nightPlusBad = false;
  bool _holidayPlusBad = false;

  // The suggested code follows the name until the user types a code.
  bool _codeTouched = false;
  bool _showErrors = false;

  // Display name of the chosen alarm sound and whether it is gone (read from
  // the phone, so it arrives a moment after the form opens).
  String? _soundTitle;
  bool _soundMissing = false;

  /// The system picker is open: the row is off until it answers (or fails).
  bool _pickingSound = false;

  /// Looking at the days gone before saving: a second tap does nothing.
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final state = ref.read(scheduleControllerProvider);
    final id = widget.shiftTypeId;
    _editing = id == null ? null : state.schedule.shiftTypeById(id);
    _missing = id != null && _editing == null;
    // The rate and the plus are typed in the currency of Ajustes, with its
    // decimals (none for the yen).
    final decimals = currencyDecimals(ref.read(preferencesProvider).currency);
    if (_editing != null) {
      _draft = ShiftTypeDraft.fromShiftType(
        _editing,
        moneyDecimals: decimals,
      );
      _codeTouched = true;
    } else {
      _draft = ShiftTypeDraft(
        colorValue: _firstUnusedColor(state.palette),
        moneyDecimals: decimals,
      );
    }
    _initial = _draft;
    _code.text = _draft.code;
    _name.text = _draft.name;
    _unpaidBreak.text = _draft.unpaidBreakText;
    _rate.text = _draft.rateText;
    _fixedPlus.text = _draft.fixedPlusText;
    _nightPlus.text = _centsText(_draft.nightPlusCentsPerHour);
    _holidayPlus.text = _centsText(_draft.holidayPlusCentsPerHour);
    _location.text = _draft.location ?? '';
    _loadSoundInfo();
    _loadDnd();
    _loadPause();
  }

  /// Reads the stored «No molestar» choice (P13) once the settings arrive and
  /// adopts it if the user has not touched the switch yet. The draft is
  /// seeded before the settings load, so without this an already-on switch
  /// would show as off (and a plain save would turn it off).
  Future<void> _loadDnd() async {
    if (_editing == null || !ref.read(dndSupportedProvider)) return;
    final bool stored;
    try {
      stored = (await ref.read(dndSettingsProvider.future))
          .forShiftType(_editing.id)
          .enabled;
    } catch (_) {
      // The provider reports the failure; the switch just stays off.
      return;
    }
    if (!mounted || _draft.dndEnabled == stored) return;
    // Only adopt it while the user has not touched the switch.
    if (_draft.dndEnabled != _initial.dndEnabled) return;
    setState(() {
      _draft = _draft.copyWith(dndEnabled: stored);
      _initial = _initial.copyWith(dndEnabled: stored);
    });
  }

  /// Reads the stored pause notice of the shift (it lives with the alarm
  /// settings) and adopts it unless the user already touched it: the draft is
  /// seeded before the settings arrive, so without this an already-on notice
  /// would show as off and a plain save would turn it off.
  Future<void> _loadPause() async {
    if (_editing == null) return;
    final PauseAlertSettings stored;
    try {
      stored = (await ref.read(alarmSettingsProvider.future))
          .forShiftType(_editing.id)
          .pause;
    } catch (_) {
      // The provider reports the failure; the switch just stays off.
      return;
    }
    if (!mounted || _draft.pause == stored) return;
    if (_draft.pause != _initial.pause) return;
    setState(() {
      _draft = _draft.copyWith(pause: stored);
      _initial = _initial.copyWith(pause: stored);
    });
  }

  /// A stored plus per hour as the field shows it ("1,5"; "" = none).
  String _centsText(int? cents) => cents == null
      ? ''
      : formatCentsInput(cents, decimals: _draft.moneyDecimals);

  /// Reads the name of the stored sound and whether it can still be played.
  Future<void> _loadSoundInfo() async {
    final uri = _draft.alarmSound;
    final sounds = ref.read(alarmSoundsProvider);
    if (uri == null || !sounds.supported) return;
    final title = await sounds.title(uri);
    final available = await sounds.isAvailable(uri);
    if (!mounted || _draft.alarmSound != uri) return;
    setState(() {
      _soundTitle = title;
      _soundMissing = !available;
    });
  }

  Future<void> _pickSound() async {
    if (_pickingSound) return;
    setState(() => _pickingSound = true);
    AlarmSoundChoice? choice;
    try {
      choice = await ref
          .read(alarmSoundsProvider)
          .pick(current: _draft.alarmSound);
    } catch (_) {
      // The picker failed (the Activity went away, no picker on this phone):
      // the same as going back, and the row must not stay off.
      choice = null;
    } finally {
      if (mounted) setState(() => _pickingSound = false);
    }
    if (choice == null || !mounted) return;
    final picked = choice;
    setState(() {
      _soundTitle = picked.uri == null ? null : picked.title;
      _soundMissing = false;
      _draft = picked.uri == null
          ? _draft.copyWith(clearAlarmSound: true)
          : _draft.copyWith(alarmSound: picked.uri);
    });
  }

  /// The switch of the pause notice. Turning it on with the alarms on also
  /// makes sure the phone lets the app post notifications (never at launch).
  void _setPause(bool on) {
    _update(_draft.copyWith(pause: _draft.pause.copyWith(enabled: on)));
    if (on) unawaited(_ensurePauseNotifications());
  }

  Future<void> _ensurePauseNotifications() async {
    try {
      final alarms = await ref.read(alarmSettingsProvider.future);
      if (!alarms.enabled) return;
      await ref
          .read(alarmSettingsProvider.notifier)
          .ensureNotificationPermission();
    } catch (_) {
      // Only a courtesy: the alarms screen shows the permission state.
    }
  }

  Future<void> _pickPauseTiming() async {
    final picked = await pickPauseTiming(context, current: _draft.pause);
    if (picked == null || !mounted) return;
    _update(_draft.copyWith(pause: picked));
  }

  void _resetSound() => setState(() {
    _soundTitle = null;
    _soundMissing = false;
    _draft = _draft.copyWith(clearAlarmSound: true);
  });

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _unpaidBreak.dispose();
    _rate.dispose();
    _fixedPlus.dispose();
    _nightPlus.dispose();
    _holidayPlus.dispose();
    _location.dispose();
    _nightPlusFocus.dispose();
    _holidayPlusFocus.dispose();
    _locationFocus.dispose();
    _codeFocus.dispose();
    _nameFocus.dispose();
    _breakFocus.dispose();
    _rateFocus.dispose();
    _fixedPlusFocus.dispose();
    super.dispose();
  }

  /// The first colour of the grid no shift of the palette wears yet.
  static int _firstUnusedColor(List<ShiftType> palette) {
    final used = {for (final t in palette) t.colorValue};
    for (final c in ShiftPalette.editorChoices) {
      if (!used.contains(c.toARGB32())) return c.toARGB32();
    }
    return ShiftPalette.editorChoices.first.toARGB32();
  }

  List<ShiftType> _others(List<ShiftType> palette) => [
    for (final t in palette)
      if (t.id != _editing?.id) t,
  ];

  void _update(ShiftTypeDraft draft) => setState(() => _draft = draft);

  /// «Partido 09–13 / 17–21»: the times of [splitShiftTemplate], and its name
  /// (with the code that follows) when the name is still empty.
  void _useSplitTemplate(List<ShiftType> palette) {
    final t = splitShiftTemplate;
    _update(
      _draft.copyWith(
        hasTimes: true,
        startMinute: t.startMinute,
        endMinute: t.endMinute,
        segment2StartMinute: t.segment2StartMinute,
        segment2DurationMinutes: t.segment2DurationMinutes,
      ),
    );
    if (_name.text.trim().isEmpty) {
      _name.text = t.name;
      _onName(t.name, palette);
    }
  }

  void _onName(String text, List<ShiftType> palette) {
    var draft = _draft.copyWith(name: text);
    if (!_codeTouched) {
      final code = suggestShiftCode(text, [
        for (final t in _others(palette)) t.code,
      ]);
      _code.text = code;
      draft = draft.copyWith(code: code);
    }
    _update(draft);
  }

  /// Picks one of the four times: the start or the end of the first segment,
  /// or of the second one ([second], a split shift).
  Future<void> _pickTime({required bool start, bool second = false}) async {
    final current = second
        ? (start ? _draft.segment2StartMinute : _draft.segment2EndMinute) ?? 0
        : (start ? _draft.startMinute : _draft.endMinute);
    final l10n = context.l10n;
    final minute = await showMinutePicker(
      context,
      current: current,
      help: second
          ? (start
                ? l10n.shiftTypesPickSecondStart
                : l10n.shiftTypesPickSecondEnd)
          : (start ? l10n.shiftTypesPickStart : l10n.shiftTypesPickEnd),
    );
    if (minute == null || !mounted) return;
    if (second) {
      // The end is a clock time; the draft keeps start + duration, so the end
      // is applied against the (possibly new) start.
      _update(
        start
            ? _draft.copyWith(
                segment2StartMinute: minute,
                // Keep the same end: the duration follows the new start.
                segment2EndMinute: _draft.segment2EndMinute,
              )
            : _draft.copyWith(segment2EndMinute: minute),
      );
      return;
    }
    _update(
      start
          ? _draft.copyWith(startMinute: minute)
          : _draft.copyWith(endMinute: minute),
    );
  }

  /// «Más colores…»: any colour, with the preview of the cell inside.
  Future<void> _pickFreeColor() async {
    final picked = await showShiftColorPicker(
      context,
      shift: _previewShift,
      initial: _draft.colorValue,
    );
    if (picked == null || !mounted) return;
    _update(_draft.copyWith(colorValue: picked));
  }

  bool get _dirty => _draft != _initial;

  /// Back with changes not saved: asks before throwing them away (H-T05-1).
  Future<void> _confirmDiscard() async {
    // A picker/dialog owns Back while it covers the editor (H-T23-4).
    // Ignore any blocked-pop notification delivered to the underlying page.
    if (ModalRoute.of(context)?.isCurrent != true) return;
    FocusScope.of(context).unfocus();
    final l10n = context.l10n;
    final discard = await showConfirmDialog(
      context,
      title: l10n.shiftTypesDiscardTitle,
      body: l10n.shiftTypesDiscardBody,
      confirmLabel: l10n.shiftTypesDiscardConfirm,
      cancelLabel: l10n.shiftTypesDiscardKeep,
      destructive: true,
      scrollable: true,
      confirmKey: const ValueKey('shift-discard-confirm'),
    );
    if (!discard || !mounted) return;
    _leave();
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.shiftTypes);
    }
  }

  /// A plus per hour typed in the night or holiday field (P9): an amount in
  /// the currency of Ajustes, or empty for none.
  void _onPlus({required bool night, required String text}) {
    int? cents;
    var bad = false;
    if (text.trim().isNotEmpty) {
      try {
        cents = parseMoneyCents(text, decimals: _draft.moneyDecimals);
      } on FormatException {
        bad = true;
      }
    }
    setState(() {
      if (night) {
        _nightPlusBad = bad;
      } else {
        _holidayPlusBad = bad;
      }
      if (bad) return;
      _draft = night
          ? (cents == null
                ? _draft.copyWith(clearNightPlus: true)
                : _draft.copyWith(nightPlusCentsPerHour: cents))
          : (cents == null
                ? _draft.copyWith(clearHolidayPlus: true)
                : _draft.copyWith(holidayPlusCentsPerHour: cents));
    });
  }

  Future<void> _save(List<ShiftType> palette) async {
    if (_saving) return;
    if (_draft.paySectionApplies && (_nightPlusBad || _holidayPlusBad)) {
      setState(() => _showErrors = true);
      (_nightPlusBad ? _nightPlusFocus : _holidayPlusFocus).requestFocus();
      return;
    }
    final problems = _draft.validate(others: _others(palette));
    setState(() => _showErrors = true);
    if (problems.isNotEmpty) {
      final first = ShiftTypeField.values.firstWhere(problems.containsKey);
      switch (first) {
        case ShiftTypeField.code:
          _codeFocus.requestFocus();
        case ShiftTypeField.name:
          _nameFocus.requestFocus();
        case ShiftTypeField.unpaidBreak:
          _breakFocus.requestFocus();
        case ShiftTypeField.rate:
          _rateFocus.requestFocus();
        case ShiftTypeField.fixedPlus:
          _fixedPlusFocus.requestFocus();
        case ShiftTypeField.segment2:
          // The message sits right under the times: nothing to focus.
          break;
        case ShiftTypeField.location:
          _locationFocus.requestFocus();
        case ShiftTypeField.nightPlus:
          _nightPlusFocus.requestFocus();
        case ShiftTypeField.holidayPlus:
          _holidayPlusFocus.requestFocus();
      }
      return;
    }
    final id = _editing?.id ?? const Uuid().v4();
    final type = _draft.toShiftType(id);
    final controller = ref.read(scheduleControllerProvider.notifier);
    // A change of hours or money on a type already on days gone: a mistake
    // to correct everywhere, or a new working day or rate from today on.
    CivilDate? onlyFrom;
    if (_editing != null) {
      final today = CivilDate.fromDateTime(ref.read(clockProvider)());
      setState(() => _saving = true);
      final changesPast = await controller.shiftTypeEditChangesPast(
        type,
        today,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      if (changesPast) {
        final scope = await showShiftTypeScopeDialog(
          context,
          currentSince: currentTermsSince(
            ref.read(scheduleControllerProvider).schedule.versionsOf(id),
          ),
        );
        if (scope == null || !mounted) return;
        if (scope == ShiftTypeEditScope.fromToday) onlyFrom = today;
      }
    }
    controller.saveShiftType(type, onlyFrom: onlyFrom);
    await _saveDnd(id, type);
    if (!mounted) return;
    await _savePause(id, type);
    if (!mounted) return;
    // Saved: nothing left to lose (and `pop` does not go through PopScope).
    _leave();
  }

  /// Stores the «No molestar durante este turno» choice (P13). It lives with
  /// the silence settings, not in the shift type row, so it is written
  /// separately and only when it changed. Shifts the phone cannot be silenced
  /// during (a day off, an absence, no times) keep whatever they had.
  Future<void> _saveDnd(String id, ShiftType type) async {
    if (!ref.read(dndSupportedProvider) || !canSilenceDuring(type)) return;
    final current = await ref.read(dndSettingsProvider.future);
    final stored = current.forShiftType(id).enabled;
    if (!mounted || stored == _draft.dndEnabled) return;
    await saveSetting(
      context,
      () => ref
          .read(dndSettingsProvider.notifier)
          .setShiftType(id, DndTypeSettings(enabled: _draft.dndEnabled)),
    );
  }

  /// Stores the pause notice. It lives with the alarm settings, not in the
  /// shift type row, so it is written separately and only when it changed.
  /// A shift no alarm can ring for (an absence, no times) keeps whatever it
  /// had.
  Future<void> _savePause(String id, ShiftType type) async {
    if (!canShiftTypeRing(type)) return;
    final current = await ref.read(alarmSettingsProvider.future);
    final stored = current.forShiftType(id);
    if (!mounted || stored.pause == _draft.pause) return;
    await saveSetting(
      context,
      () => ref
          .read(alarmSettingsProvider.notifier)
          .setShiftType(id, stored.copyWith(pause: _draft.pause)),
    );
  }

  String? _errorText(
    Map<ShiftTypeField, ShiftTypeProblem> problems,
    ShiftTypeField field, {
    bool always = false,
  }) {
    final problem = problems[field];
    if ((!_showErrors && !always) || problem == null) return null;
    final l10n = context.l10n;
    return switch (problem.issue) {
      ShiftTypeIssue.codeEmpty => l10n.shiftTypesErrorCodeEmpty,
      ShiftTypeIssue.codeTooLong => l10n.shiftTypesErrorCodeTooLong,
      ShiftTypeIssue.codeTaken => l10n.shiftTypesErrorCodeTaken(
        problem.other ?? '',
      ),
      ShiftTypeIssue.nameEmpty => l10n.shiftTypesErrorNameEmpty,
      ShiftTypeIssue.breakTooLong => l10n.shiftTypesErrorBreak,
      ShiftTypeIssue.rateInvalid => l10n.shiftTypesErrorRate,
      ShiftTypeIssue.segment2Incomplete => l10n.shiftTypesErrorSplitIncomplete,
      ShiftTypeIssue.segment2StartOutOfRange => l10n.shiftTypesErrorSplitStart,
      ShiftTypeIssue.segment2DurationOutOfRange =>
        l10n.shiftTypesErrorSplitDuration,
      ShiftTypeIssue.segment2NotAfterFirst => l10n.shiftTypesErrorSplitNotAfter,
      ShiftTypeIssue.segment2TooLong => l10n.shiftTypesErrorSplitTooLong,
      // The place stops at its limit while typing (no message needed); the
      // pluses per hour are amounts like the rate.
      ShiftTypeIssue.locationTooLong => null,
      ShiftTypeIssue.nightPlusInvalid ||
      ShiftTypeIssue.holidayPlusInvalid => l10n.shiftTypesErrorRate,
    };
  }

  /// A shift for the preview (a placeholder code while none is typed).
  ShiftType get _previewShift => ShiftType(
    id: _editing?.id ?? 'preview',
    // Whole characters only: the code may not fit while it is being fixed.
    code: fitShiftCode(_draft.code),
    name: _draft.name,
    colorValue: _draft.colorValue,
    category: _draft.category,
    startMinute: _draft.hasTimes ? _draft.startMinute : null,
    endMinute: _draft.hasTimes ? _draft.endMinute : null,
    segment2StartMinute: _draft.segment2Fits
        ? _draft.segment2StartMinute
        : null,
    segment2DurationMinutes: _draft.segment2Fits
        ? _draft.segment2DurationMinutes
        : null,
    icon: _draft.icon,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_missing) {
      return Scaffold(
        appBar: ContentAppBar.adaptive(
          context,
          title: Text(l10n.shiftTypesEditTitle),
        ),
        body: PageBody(
          child: EmptyState(
            icon: AppIcons.error,
            title: l10n.shiftTypesNotFound,
            message: l10n.shiftTypesNotFoundMessage,
          ),
        ),
      );
    }

    final palette = ref.watch(
      scheduleControllerProvider.select((s) => s.palette),
    );
    final problems = _draft.validate(others: _others(palette));
    final isNew = _editing == null;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: _scaffold(context, palette, problems, isNew),
    );
  }

  Widget _scaffold(
    BuildContext context,
    List<ShiftType> palette,
    Map<ShiftTypeField, ShiftTypeProblem> problems,
    bool isNew,
  ) {
    final l10n = context.l10n;
    // The rate and the plus are typed in the currency of Ajustes.
    final symbol = currencySymbolOf(context);
    return Scaffold(
      appBar: ContentAppBar.adaptive(
        context,
        title: Text(isNew ? l10n.shiftTypesNewTitle : l10n.shiftTypesEditTitle),
      ),
      body: PageBody(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            Sp.page,
            Sp.s,
            Sp.page,
            Sp.section + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LabeledField(
                label: l10n.shiftTypesNameLabel,
                child: TextField(
                  key: const ValueKey('shift-name'),
                  controller: _name,
                  focusNode: _nameFocus,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(maxShiftNameLength),
                  ],
                  decoration: InputDecoration(
                    errorText: _errorText(problems, ShiftTypeField.name),
                  ),
                  onChanged: (text) => _onName(text, palette),
                ),
              ),
              const SizedBox(height: Sp.xl),
              LabeledField(
                label: l10n.shiftTypesCodeLabel,
                helper: l10n.shiftTypesCodeHelper,
                child: TextField(
                  key: const ValueKey('shift-code'),
                  controller: _code,
                  focusNode: _codeFocus,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  inputFormatters: const [ShiftCodeFormatter()],
                  decoration: InputDecoration(
                    errorText: _errorText(problems, ShiftTypeField.code),
                  ),
                  onChanged: (text) {
                    _codeTouched = true;
                    _update(_draft.copyWith(code: text));
                  },
                ),
              ),
              const SizedBox(height: Sp.section),
              // The preview sits right above the colours it reacts to.
              LabeledField(
                label: l10n.shiftTypesPreviewLabel,
                child: ShiftTypePreview(shift: _previewShift),
              ),
              const SizedBox(height: Sp.xl),
              LabeledField(
                label: l10n.shiftTypesColorLabel,
                child: ShiftColorGrid(
                  selected: _draft.colorValue,
                  onChanged: (value) =>
                      _update(_draft.copyWith(colorValue: value)),
                  onMore: _pickFreeColor,
                ),
              ),
              const SizedBox(height: Sp.section),
              LabeledField(
                label: l10n.shiftTypesCategoryLabel,
                child: Wrap(
                  spacing: Sp.s,
                  runSpacing: Sp.s,
                  children: [
                    for (final (key, category, label) in [
                      ('work', ShiftCategory.work, l10n.shiftTypesCategoryWork),
                      ('rest', ShiftCategory.rest, l10n.shiftTypesCategoryRest),
                      (
                        'absence',
                        ShiftCategory.absence,
                        l10n.shiftTypesCategoryAbsence,
                      ),
                    ])
                      ChoicePill(
                        key: ValueKey('category-$key'),
                        label: label,
                        selected: _draft.category == category,
                        onTap: () =>
                            _update(_draft.copyWith(category: category)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Sp.section),
              ShiftIconField(
                selected: _draft.icon,
                onChanged: (icon) => _update(
                  icon == null
                      ? _draft.copyWith(clearIcon: true)
                      : _draft.copyWith(icon: icon),
                ),
              ),
              const SizedBox(height: Sp.section),
              ShiftTypeTimesSection(
                draft: _draft,
                onNoTimes: (noTimes) =>
                    _update(_draft.copyWith(hasTimes: !noTimes)),
                onPickStart: () => _pickTime(start: true),
                onPickEnd: () => _pickTime(start: false),
                onUseSplitTemplate: isNew
                    ? () => _useSplitTemplate(palette)
                    : null,
                onSplit: (split) => _update(
                  split
                      ? _draft.withSplit()
                      : _draft.copyWith(clearSegment2: true),
                ),
                onPickSecondStart: () => _pickTime(start: true, second: true),
                onPickSecondEnd: () => _pickTime(start: false, second: true),
                splitError: _errorText(
                  problems,
                  ShiftTypeField.segment2,
                  always: true,
                ),
              ),
              if (_draft.category == ShiftCategory.work) ...[
                const SizedBox(height: Sp.section),
                LabeledField(
                  label: l10n.moneyLocationLabel,
                  helper: l10n.moneyLocationHelper,
                  child: TextField(
                    key: const ValueKey('shift-location'),
                    controller: _location,
                    focusNode: _locationFocus,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(maxShiftLocationLength),
                    ],
                    decoration: InputDecoration(
                      hintText: l10n.moneyLocationHint,
                    ),
                    onChanged: (text) => _update(
                      text.isEmpty
                          ? _draft.copyWith(clearLocation: true)
                          : _draft.copyWith(location: text),
                    ),
                  ),
                ),
              ],
              if (_draft.paySectionApplies) ...[
                const SizedBox(height: Sp.section),
                LabeledField(
                  label: l10n.shiftTypesBreakLabel,
                  helper: _breakHelper(),
                  child: TextField(
                    key: const ValueKey('shift-break'),
                    controller: _unpaidBreak,
                    focusNode: _breakFocus,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: InputDecoration(
                      // The unit shows before anything is typed (H-T05-5):
                      // the suffix alone only appears with text.
                      hintText: l10n.shiftTypesBreakHint,
                      suffixText: l10n.shiftTypesBreakUnit,
                      errorText: _errorText(
                        problems,
                        ShiftTypeField.unpaidBreak,
                      ),
                    ),
                    onChanged: (text) =>
                        _update(_draft.copyWith(unpaidBreakText: text)),
                  ),
                ),
                const SizedBox(height: Sp.xl),
                LabeledField(
                  label: l10n.shiftTypesNightLabel,
                  helper: l10n.shiftTypesNightHelper,
                  child: Wrap(
                    spacing: Sp.s,
                    runSpacing: Sp.s,
                    children: [
                      for (final (key, value, label)
                          in <(String, bool?, String)>[
                            ('auto', null, l10n.shiftTypesNightAuto),
                            ('always', true, l10n.shiftTypesNightAlways),
                            ('never', false, l10n.shiftTypesNightNever),
                          ])
                        ChoicePill(
                          key: ValueKey('night-$key'),
                          label: label,
                          selected: _draft.nightOverride == value,
                          onTap: () => _update(
                            value == null
                                ? _draft.copyWith(clearNightOverride: true)
                                : _draft.copyWith(nightOverride: value),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: Sp.xl),
                LabeledField(
                  label: l10n.shiftTypesRateLabel,
                  helper: l10n.shiftTypesRateHelper,
                  child: TextField(
                    key: const ValueKey('shift-rate'),
                    controller: _rate,
                    focusNode: _rateFocus,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: _draft.moneyDecimals > 0,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(
                          _draft.moneyDecimals > 0 ? r'[0-9.,]' : r'[0-9]',
                        ),
                      ),
                      LengthLimitingTextInputFormatter(9),
                    ],
                    decoration: InputDecoration(
                      hintText: l10n.shiftTypesRateHint,
                      suffixText: l10n.shiftTypesRateUnit(symbol),
                      errorText: _errorText(problems, ShiftTypeField.rate),
                      errorMaxLines: 3,
                    ),
                    onChanged: (text) =>
                        _update(_draft.copyWith(rateText: text)),
                  ),
                ),
                const SizedBox(height: Sp.xl),
                _plusField(
                  fieldKey: 'shift-night-plus',
                  label: l10n.moneyNightPlusLabel,
                  helper: l10n.moneyNightPlusHelper,
                  controller: _nightPlus,
                  focusNode: _nightPlusFocus,
                  night: true,
                  symbol: symbol,
                  error: _showErrors && _nightPlusBad
                      ? l10n.shiftTypesErrorRate
                      : _errorText(problems, ShiftTypeField.nightPlus),
                ),
                const SizedBox(height: Sp.xl),
                _plusField(
                  fieldKey: 'shift-holiday-plus',
                  label: l10n.moneyHolidayPlusLabel,
                  helper: l10n.moneyHolidayPlusHelper,
                  controller: _holidayPlus,
                  focusNode: _holidayPlusFocus,
                  night: false,
                  symbol: symbol,
                  error: _showErrors && _holidayPlusBad
                      ? l10n.shiftTypesErrorRate
                      : _errorText(problems, ShiftTypeField.holidayPlus),
                ),
              ],
              if (_draft.fixedPlusApplies) ...[
                const SizedBox(height: Sp.xl),
                LabeledField(
                  label: l10n.shiftTypesFixedPlusLabel,
                  helper: l10n.shiftTypesFixedPlusHelper,
                  child: TextField(
                    key: const ValueKey('shift-fixed-plus'),
                    controller: _fixedPlus,
                    focusNode: _fixedPlusFocus,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: _draft.moneyDecimals > 0,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(
                          _draft.moneyDecimals > 0 ? r'[0-9.,]' : r'[0-9]',
                        ),
                      ),
                      LengthLimitingTextInputFormatter(9),
                    ],
                    decoration: InputDecoration(
                      hintText: l10n.shiftTypesFixedPlusHint,
                      suffixText: symbol,
                      errorText: _errorText(problems, ShiftTypeField.fixedPlus),
                      errorMaxLines: 3,
                    ),
                    onChanged: (text) =>
                        _update(_draft.copyWith(fixedPlusText: text)),
                  ),
                ),
              ],
              if (_draft.dndSectionApplies &&
                  ref.watch(dndSupportedProvider)) ...[
                const SizedBox(height: Sp.section),
                _DndSection(
                  value: _draft.dndEnabled,
                  onChanged: (on) =>
                      _update(_draft.copyWith(dndEnabled: on)),
                ),
              ],
              if (_draft.alarmSectionApplies &&
                  ref.watch(alarmSoundsProvider).supported) ...[
                const SizedBox(height: Sp.section),
                _SoundSection(
                  uri: _draft.alarmSound,
                  title: _soundTitle,
                  missing: _soundMissing,
                  onPick: _pickingSound ? null : _pickSound,
                  onReset: _resetSound,
                ),
              ],
              if (_draft.pauseSectionApplies) ...[
                const SizedBox(height: Sp.section),
                ShiftPauseSection(
                  pause: _draft.pause,
                  onChanged: _setPause,
                  onPickTiming: _pickPauseTiming,
                  suggested: _draft.suggestsPause,
                  duration: _draft.scheduledMinutes,
                  split: _draft.segment2Fits,
                  outside: _draft.pauseOutsideShift,
                  alarmsOff:
                      ref.watch(alarmSettingsProvider).value?.enabled == false,
                ),
              ],
              const SizedBox(height: Sp.section),
              PrimaryButton(
                key: const ValueKey('shift-save'),
                label: l10n.save,
                onPressed: () => _save(palette),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A money-per-hour field of the pay section: the plus for night or holiday
  /// hours (P9), typed in the currency of Ajustes.
  Widget _plusField({
    required String fieldKey,
    required String label,
    required String helper,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool night,
    required String symbol,
    required String? error,
  }) {
    final l10n = context.l10n;
    return LabeledField(
      label: label,
      helper: helper,
      child: TextField(
        key: ValueKey(fieldKey),
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.numberWithOptions(
          decimal: _draft.moneyDecimals > 0,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            RegExp(_draft.moneyDecimals > 0 ? r'[0-9.,]' : r'[0-9]'),
          ),
          LengthLimitingTextInputFormatter(9),
        ],
        decoration: InputDecoration(
          hintText: l10n.moneyPlusHint,
          suffixText: l10n.shiftTypesRateUnit(symbol),
          errorText: error,
          errorMaxLines: 3,
        ),
        onChanged: (text) => _onPlus(night: night, text: text),
      ),
    );
  }

  /// "Se pagan 7 h 30 min" while the break makes sense.
  String _breakHelper() {
    final l10n = context.l10n;
    final unpaid = _draft.unpaidBreakMinutes;
    final paid = unpaid == null ? null : _draft.scheduledMinutes - unpaid;
    if (paid == null || paid <= 0) return l10n.shiftTypesBreakHelper;
    return l10n.shiftTypesPaidHelper(durationText(l10n, paid));
  }
}

/// «No molestar» section of the form (P13, Android only): whether the phone
/// is silenced while this shift works. The choice lives with the silence
/// settings (`DndSettings`), not in the shift type row, and only applies to
/// worked shifts with times ([ShiftTypeDraft.dndSectionApplies]).
class _DndSection extends StatelessWidget {
  const _DndSection({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Padding(
            padding: const EdgeInsets.only(bottom: Sp.s),
            child: Text(
              l10n.dndShiftSection.toUpperCase(),
              style: context.type.label.copyWith(
                color: context.colors.textMuted,
              ),
            ),
          ),
        ),
        SwitchListTile(
          key: const ValueKey('shift-dnd'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.dndShiftSwitch),
          subtitle: Text(l10n.dndShiftHelper),
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// «Alarma» section of the form: the sound this shift's alarms ring with
/// (docs/alarmas.md). The button opens the phone's sound picker and shows the
/// current choice; a sound that has gone says so and rings the default one.
class _SoundSection extends StatelessWidget {
  const _SoundSection({
    required this.uri,
    required this.title,
    required this.missing,
    required this.onPick,
    required this.onReset,
  });

  final String? uri;
  final String? title;
  final bool missing;
  final VoidCallback? onPick;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final String value;
    if (uri == null) {
      value = l10n.shiftTypesSoundDefault;
    } else if (missing) {
      value = l10n.shiftTypesSoundMissing;
    } else {
      value = title ?? l10n.shiftTypesSoundCustom;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Padding(
            padding: const EdgeInsets.only(bottom: Sp.s),
            child: Text(
              l10n.shiftTypesAlarmSection.toUpperCase(),
              style: context.type.label.copyWith(
                color: context.colors.textMuted,
              ),
            ),
          ),
        ),
        LabeledField(
          label: l10n.shiftTypesSoundLabel,
          helper: l10n.shiftTypesSoundHelper,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SecondaryButton(
                key: const ValueKey('shift-sound'),
                icon: AppIcons.sound,
                label: value,
                onPressed: onPick,
              ),
              if (uri != null) ...[
                const SizedBox(height: Sp.s),
                SecondaryButton(
                  key: const ValueKey('shift-sound-reset'),
                  icon: AppIcons.undo,
                  label: l10n.shiftTypesSoundReset,
                  expand: false,
                  onPressed: onReset,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
