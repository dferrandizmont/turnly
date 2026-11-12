import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/diagnostics/crash_reporting.dart';
import '../../../core/providers.dart';
import '../../calendars/application/calendars_controller.dart';
import '../../calendar/application/schedule_controller.dart';
import '../../calendar/application/visible_month.dart';
import '../../holidays/application/holidays_provider.dart';
import '../../holidays/domain/holiday_country.dart';
import '../../patterns/application/post_night_provider.dart';
import '../../patterns/domain/pattern_application.dart';
import '../../patterns/domain/pattern_catalog.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../../settings/application/preferences_controller.dart';
import '../domain/profession.dart';
import 'onboarding_providers.dart';

/// The three ways to start (docs/diseno.md, «Primer uso»): import the shifts
/// from somewhere else, use a rotation, or paint the month by hand.
enum OnboardingPath { import, rotation, paint }

/// Where the person is in the first-use flow: the first question
/// ([choose]), the screens of the path chosen, the optional step [place]
/// (country, community and municipality for the holidays; on the import and
/// paint paths also the job) and [ready]. On the rotation path [place] comes
/// first, before the rotation, so the country's formats (first day of the
/// week) are already set when the preview is drawn.
enum OnboardingStage {
  choose,
  rotation,
  start,
  importCalendar,
  place,
  ready;

  /// The screens of [path] that carry «Paso N de M», in order (H-T01-9: one
  /// number per screen). The first question and «Listo» carry none.
  static List<OnboardingStage> stepsOf(OnboardingPath? path) => switch (path) {
    OnboardingPath.rotation => const [place, rotation, start],
    OnboardingPath.import => const [importCalendar, place],
    OnboardingPath.paint || null => const [place],
  };
}

/// What the person has chosen so far. Nothing is written until the last
/// step is left ([OnboardingController.finish]), so going back, changing
/// their mind or quitting half way leaves no half-made calendar behind.
class OnboardingState {
  const OnboardingState({
    required this.start,
    this.stage = OnboardingStage.choose,
    this.path,
    this.profession,
    this.countryCode = spainCountryCode,
    this.regionCode,
    this.municipalityCode,
    this.municipalityName,
    this.presetId,
    this.workShiftId = 'morning',
    this.byHand = false,
    this.stepOffset = 0,
    this.finishing = false,
    this.saveFailed = false,
  });

  final OnboardingStage stage;

  /// The way to start chosen on the first screen.
  final OnboardingPath? path;

  final Profession? profession;

  /// Country of the holidays (alpha-2, or [otherCountryCode]): proposed from
  /// the phone's region, changed in the place step. It also picks the list of
  /// jobs ([professionsFor]).
  final String countryCode;

  /// Region (Spain's community, or another country's subdivision such as
  /// `DE-BY`) and municipality (Spain only).
  final String? regionCode;
  final String? municipalityCode;

  /// Name of [municipalityCode], to show it back.
  final String? municipalityName;

  /// Catalogue preset chosen on the rotation screen.
  final String? presetId;
  final String workShiftId;

  /// "Lo pinto a mano": no rotation.
  final bool byHand;

  /// Day the rotation starts (today unless changed).
  final CivilDate start;

  /// Cycle step that falls on [start].
  final int stepOffset;

  /// The choices are being written.
  final bool finishing;

  /// Something of the writing failed (the rest was saved).
  final bool saveFailed;

  bool get hasRotation => presetId != null && !byHand;

  bool get isSpain => countryCode == spainCountryCode;

  /// The screens of the chosen path with «Paso N de M».
  List<OnboardingStage> get steps => OnboardingStage.stepsOf(path);

  /// 1-based number of the current screen in [steps]; `null` on the first
  /// question and on «Listo».
  int? get stepNumber {
    final i = steps.indexOf(stage);
    return i < 0 ? null : i + 1;
  }

  OnboardingState copyWith({
    OnboardingStage? stage,
    OnboardingPath? path,
    Profession? profession,
    bool clearProfession = false,
    String? countryCode,
    String? regionCode,
    String? municipalityCode,
    String? municipalityName,
    bool clearPlace = false,
    bool clearMunicipality = false,
    String? presetId,
    String? workShiftId,
    bool? byHand,
    bool clearRotation = false,
    CivilDate? start,
    int? stepOffset,
    bool? finishing,
    bool? saveFailed,
  }) => OnboardingState(
    stage: stage ?? this.stage,
    path: path ?? this.path,
    profession: clearProfession ? null : profession ?? this.profession,
    countryCode: countryCode ?? this.countryCode,
    regionCode: clearPlace ? null : regionCode ?? this.regionCode,
    municipalityCode: clearPlace || clearMunicipality
        ? null
        : municipalityCode ?? this.municipalityCode,
    municipalityName: clearPlace || clearMunicipality
        ? null
        : municipalityName ?? this.municipalityName,
    presetId: clearRotation ? null : presetId ?? this.presetId,
    workShiftId: workShiftId ?? this.workShiftId,
    byHand: clearRotation ? byHand ?? false : byHand ?? this.byHand,
    start: start ?? this.start,
    stepOffset: stepOffset ?? this.stepOffset,
    finishing: finishing ?? this.finishing,
    saveFailed: saveFailed ?? this.saveFailed,
  );
}

/// The first-use flow: how to start (import, rotation or by hand), the
/// screens of that path, holidays and job (optional), ready. Everything
/// it writes goes through the existing controllers and repositories
/// (`ScheduleController`, `HolidayController`, `OnboardingRepository`).
class OnboardingController extends Notifier<OnboardingState> {
  /// What the database held when the flow opened: [finish] writes nothing if
  /// the answer changed meanwhile (a backup was restored under the flow).
  Future<({bool done, bool data})>? _baseline;

  @override
  OnboardingState build() {
    final today = CivilDate.fromDateTime(ref.read(clockProvider)());
    _baseline = _probe();
    return OnboardingState(
      start: today,
      countryCode: proposeHolidayCountry(ref.read(systemCountryCodeProvider)),
    );
  }

  Future<({bool done, bool data})> _probe() async {
    try {
      final repository = ref.read(onboardingRepositoryProvider);
      return (
        done: await repository.isDone(),
        data: await repository.hasUserData(),
      );
    } catch (_) {
      // No readable database: nothing to protect.
      return (done: false, data: false);
    }
  }

  // ---- first question: how to start --------------------------------------

  /// «Usar una rotación»: first the place (its country sets the week start
  /// the rotation preview uses), then the rotation catalogue. A rotation
  /// chosen before (and the way back here) is kept.
  void chooseRotation() {
    state = state.copyWith(path: OnboardingPath.rotation, byHand: false);
    _go(OnboardingStage.place);
  }

  /// «Importar mis turnos»: the import screen, without any rotation.
  void chooseImport() {
    state = state.copyWith(path: OnboardingPath.import, clearRotation: true);
    _go(OnboardingStage.importCalendar);
  }

  /// «Pintar a mano»: no rotation; after the place step the month opens in
  /// paint mode.
  void choosePaint() {
    state = state.copyWith(
      path: OnboardingPath.paint,
      clearRotation: true,
      byHand: true,
    );
    _go(OnboardingStage.place);
  }

  // ---- job (optional): rotation screen, or the place step -----------------

  /// Tapping the chosen job again leaves none (the question is optional).
  /// The job is asked on the rotation screen (before the list, which it
  /// orders) when the person uses a rotation, and in the place step on the
  /// other ways. The rotation chosen stays: the job only sets the hours of
  /// the shift types.
  void selectProfession(Profession profession) =>
      state = state.profession == profession
      ? state.copyWith(clearProfession: true)
      : state.copyWith(profession: profession);

  // ---- place (optional) ------------------------------------------------------

  /// Another country drops the region and municipality (in Spain, its
  /// autonomous community and municipality; elsewhere, its subdivision) and,
  /// if the job chosen is not in that country's list, swaps it for the
  /// closest one there ([professionForCountry]).
  void selectCountry(String countryCode) {
    final code = normalizeCountryCode(countryCode) ?? otherCountryCode;
    if (code == state.countryCode) return;
    final profession = state.profession;
    state = state.copyWith(
      countryCode: code,
      clearPlace: true,
      profession: profession == null
          ? null
          : professionForCountry(profession, code),
    );
    // Choosing a country sets its formats (first day of the week, currency)
    // for whoever has not picked them by hand. It is not awaited here (the
    // country must show at once) and a failure is reported like the rest of
    // the flow, never left uncaught.
    unawaited(_applyRegionDefaults(code));
  }

  /// [applyRegionDefaults] with its failure reported through the crash
  /// reporter (the same diagnostics as `finish`): a country whose formats
  /// cannot be written must not fail silently.
  Future<void> _applyRegionDefaults(String code) async {
    try {
      await ref.read(preferencesProvider.notifier).applyRegionDefaults(code);
    } catch (error, stack) {
      try {
        await ref
            .read(crashReporterProvider)
            .record(redactError(error), stack, fatal: false);
      } catch (_) {
        // A reporter that fails must not break the flow.
      }
    }
  }

  void selectRegion(String? regionCode) {
    if (regionCode == state.regionCode) return;
    // A municipality belongs to one region.
    state = regionCode == null
        ? state.copyWith(clearPlace: true)
        : state.copyWith(regionCode: regionCode, clearMunicipality: true);
  }

  /// [name] is only for showing the choice back ("Listo").
  void selectMunicipality(String? municipalityCode, {String? name}) =>
      state = municipalityCode == null
      ? state.copyWith(clearMunicipality: true)
      : state.copyWith(
          municipalityCode: municipalityCode,
          municipalityName: name,
        );

  // ---- rotation -------------------------------------------------------------

  void selectPreset(String presetId) =>
      state = state.copyWith(presetId: presetId, byHand: false, stepOffset: 0);

  /// "Lo pinto a mano" on the rotation screen: no rotation, and since the
  /// place was already asked, the choices are written (and the month opens in
  /// paint mode at the end).
  Future<void> paintByHand() async {
    if (state.finishing) return;
    state = state.copyWith(clearRotation: true, byHand: true);
    await finish();
  }

  void setStart(CivilDate date) => state = state.copyWith(start: date);

  void setStepOffset(int index) => state = state.copyWith(stepOffset: index);

  void setWorkShift(String id) => state = state.copyWith(workShiftId: id);

  // ---- navigation -----------------------------------------------------------

  /// Whether the main button of the current stage has something to do. The
  /// first question has no main button: its cards go on by themselves.
  bool get canAdvance => switch (state.stage) {
    OnboardingStage.choose => false,
    OnboardingStage.rotation => state.presetId != null,
    _ => true,
  };

  /// "Siguiente" / "Continuar". From the last step of the path it writes the
  /// choices and lands on "Listo".
  Future<void> next() async {
    if (state.finishing || !canAdvance) return;
    switch (state.stage) {
      case OnboardingStage.rotation:
        _go(OnboardingStage.start);
      case OnboardingStage.importCalendar:
        _go(OnboardingStage.place);
      case OnboardingStage.place:
        if (state.path == OnboardingPath.rotation) {
          _go(OnboardingStage.rotation);
        } else {
          await finish();
        }
      case OnboardingStage.start:
        await finish();
      case OnboardingStage.choose || OnboardingStage.ready:
        break;
    }
  }

  /// "Saltar": leaves this screen without choosing anything in it.
  Future<void> skip() async {
    if (state.finishing) return;
    switch (state.stage) {
      case OnboardingStage.rotation || OnboardingStage.start:
        // The place was asked before: no rotation, and the choices are
        // written.
        state = state.copyWith(clearRotation: true);
        await finish();
      case OnboardingStage.importCalendar:
        _go(OnboardingStage.place);
      case OnboardingStage.place:
        // The country stays (the proposed one, or the one chosen): skipping
        // the community must not bring Spain's holidays to someone in
        // another country. The community goes, and the job too unless it
        // is asked on the rotation screen (then it is not part of this
        // step and stays).
        final rotation = state.path == OnboardingPath.rotation;
        state = state.copyWith(clearPlace: true, clearProfession: !rotation);
        if (rotation) {
          _go(OnboardingStage.rotation);
        } else {
          await finish();
        }
      case OnboardingStage.choose || OnboardingStage.ready:
        break;
    }
  }

  /// Back one screen. Returns `false` when there is nowhere to go (the first
  /// question, or "Listo", whose choices are already saved).
  bool back() {
    if (state.finishing) return true;
    switch (state.stage) {
      case OnboardingStage.choose || OnboardingStage.ready:
        return false;
      case OnboardingStage.importCalendar:
        _go(OnboardingStage.choose);
      case OnboardingStage.rotation:
        _go(OnboardingStage.place);
      case OnboardingStage.start:
        _go(OnboardingStage.rotation);
      case OnboardingStage.place:
        _go(switch (state.path) {
          OnboardingPath.import => OnboardingStage.importCalendar,
          OnboardingPath.rotation ||
          OnboardingPath.paint ||
          null => OnboardingStage.choose,
        });
    }
    return true;
  }

  void _go(OnboardingStage stage) => state = state.copyWith(stage: stage);

  // ---- what happened outside the flow --------------------------------------

  /// The person came back from the import opened from the flow: what it
  /// brought is theirs, so [finish] must still write the choices made after
  /// it (the country and the job of the place step).
  void acceptImported() => _baseline = _probe();

  /// Whether a backup was restored while the flow was open (from
  /// «Recuperar una copia de seguridad»): data, or the "done" mark a restore
  /// leaves, appeared. The flow then has nothing left to ask.
  Future<bool> restoredMeanwhile() async {
    final before = await (_baseline ?? _probe());
    final now = await _probe();
    return (now.done && !before.done) || (now.data && !before.data);
  }

  // ---- result ---------------------------------------------------------------

  /// What the rotation would be: the chosen preset from [start].
  PatternRequest? request(Schedule schedule) {
    final id = state.presetId;
    if (id == null || state.byHand) return null;
    final pattern = presetPattern(
      schedule,
      patternPresetById(id),
      workShiftId: state.workShiftId,
    );
    return PatternRequest(
      pattern: pattern,
      from: state.start,
      stepOffset: state.stepOffset % pattern.lengthDays,
    );
  }

  /// Accept provisional defaults in the chosen language before the importer
  /// can use them as the person's data. The provenance marker is consumed.
  Future<void> prepareFactoryCatalog() async {
    final schedule = ref.read(scheduleControllerProvider.notifier);
    await schedule.pendingWrites;
    if (await ref
        .read(onboardingRepositoryProvider)
        .finalizeFactoryCatalog(catalogTexts)) {
      await schedule.reload();
      ref.invalidate(calendarsControllerProvider);
    }
  }

  /// Writes the choices and goes to "Listo": the shift types of the
  /// profession (hours and order of the paint bar), the place for the
  /// holidays, the rotation as one pattern application, and the "done" flag.
  /// A part that fails is reported and does not stop the others.
  Future<void> finish() async {
    if (state.finishing) return;
    state = state.copyWith(finishing: true, saveFailed: false);
    final schedule = ref.read(scheduleControllerProvider.notifier);
    final repository = ref.read(onboardingRepositoryProvider);
    var failed = false;

    // Data that appeared while the flow was open (a restored backup) is
    // never overwritten by the choices made here: just close.
    final before = await (_baseline ?? _probe());
    final now = await _probe();
    if (!ref.mounted) return;
    final errorsBefore = ref.read(scheduleControllerProvider).saveErrors;

    Future<void> guarded(Future<void> Function() step) async {
      try {
        await step();
      } catch (error, stack) {
        failed = true;
        try {
          await ref
              .read(crashReporterProvider)
              .record(redactError(error), stack, fatal: false);
        } catch (_) {
          // A reporter that fails must not stop the flow.
        }
      }
    }

    await guarded(prepareFactoryCatalog);

    if ((now.done && !before.done) || (now.data && !before.data)) {
      state = state.copyWith(
        stage: OnboardingStage.ready,
        finishing: false,
        saveFailed: failed,
        clearProfession: true,
        clearPlace: true,
        clearRotation: true,
      );
      return;
    }

    final profession = state.profession;
    if (profession != null) {
      await guarded(() async {
        for (final type in professionShiftTypes(
          ref.read(scheduleControllerProvider).schedule,
          profession,
        )) {
          schedule.saveShiftType(type);
        }
        final palette = ref.read(scheduleControllerProvider).palette;
        final order = professionPaletteOrder(palette, profession);
        schedule.reorderShiftTypes(order);
        await repository.saveProfile(profession);
      });
    }

    // Always written: the country is what keeps a fresh install outside
    // Spain from showing Spain's holidays (nothing stored means Spain).
    await guarded(
      () => ref
          .read(holidayControllerProvider.notifier)
          .setPlace(
            countryCode: state.countryCode,
            // Spain's community or another country's subdivision.
            regionCode: state.regionCode,
            municipalityCode: state.isSpain ? state.municipalityCode : null,
          ),
    );

    final rotation = request(ref.read(scheduleControllerProvider).schedule);
    if (rotation != null) {
      await guarded(() async {
        await schedule.applyPatternRun(rotation);
        ref.read(visibleMonthProvider.notifier).goTo(rotation.from);
      });
    }

    // The shift types are queued writes: wait until they are in the database
    // (and see whether any failed) before saying the flow is done.
    await guarded(() async {
      await schedule.pendingWrites;
      if (ref.read(scheduleControllerProvider).saveErrors > errorsBefore) {
        failed = true;
      }
    });

    await guarded(() async {
      await repository.markDone(tip: true);
      ref.read(onboardingTipProvider.notifier).show();
    });
    if (!ref.mounted) return;
    state = state.copyWith(
      stage: OnboardingStage.ready,
      finishing: false,
      saveFailed: failed,
    );
  }
}

final onboardingControllerProvider =
    NotifierProvider.autoDispose<OnboardingController, OnboardingState>(
      OnboardingController.new,
    );

/// What applying the rotation chosen in the first-use flow would look like,
/// for the live preview of «¿Cuándo empiezas?»: the same planner as the
/// wizard (`patternPreviewProvider`), on the schedule with the chosen job's
/// hours, so what is shown is what `finish` writes. `null` without a rotation.
final onboardingPreviewProvider = Provider.autoDispose<PatternApplication?>((
  ref,
) {
  final state = ref.watch(onboardingControllerProvider);
  if (!state.hasRotation) return null;
  final schedule = ref.watch(
    scheduleControllerProvider.select((s) => s.schedule),
  );
  final palette = ref.watch(
    scheduleControllerProvider.select((s) => s.palette),
  );
  final auto = ref.watch(postNightAutoProvider);
  final request = ref
      .read(onboardingControllerProvider.notifier)
      .request(scheduleWithProfession(schedule, state.profession));
  if (request == null) return null;
  final plan = planPatternApplication(
    schedule,
    request,
    seq: schedule.runs.fold(0, (m, r) => r.seq > m ? r.seq : m) + 1,
    postNightAuto: auto,
    palette: palette,
  );
  // The factory types are stored in the phone's language until the end of
  // the flow (`finalizeFactoryCatalog`): the preview draws them in the app's
  // language, like the shift chips above it (`shiftTypeForFirstUse`).
  return PatternApplication(
    schedule: plan.schedule.copyWith(
      shiftTypes: plan.schedule.shiftTypes.map(factoryTextsShiftType),
    ),
    change: plan.change,
    newTypes: plan.newTypes,
    newPattern: plan.newPattern,
    postNightDays: plan.postNightDays,
  );
});
