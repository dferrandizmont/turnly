@Tags(['store'])
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cuadrante/app.dart';
import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/database/database_provider.dart';
import 'package:cuadrante/core/providers.dart';
import 'package:cuadrante/core/router.dart';
import 'package:cuadrante/core/theme/app_colors.dart';
import 'package:cuadrante/core/theme/app_typography.dart';
import 'package:cuadrante/features/absences/application/absence_providers.dart';
import 'package:cuadrante/features/absences/data/absence_balances_repository.dart';
import 'package:cuadrante/features/absences/data/absence_carry_over_store.dart';
import 'package:cuadrante/features/absences/domain/absence_balance.dart';
import 'package:cuadrante/features/calendar/application/paint_controller.dart';
import 'package:cuadrante/features/calendars/data/calendars_repository.dart';
import 'package:cuadrante/features/calendars/domain/calendar.dart';
import 'package:cuadrante/features/holidays/application/holidays_provider.dart';
import 'package:cuadrante/features/holidays/data/holiday_repository.dart';
import 'package:cuadrante/features/holidays/presentation/holidays_settings_providers.dart';
import 'package:cuadrante/features/onboarding/application/onboarding_providers.dart'
    show initialOnboardingProvider;
import 'package:cuadrante/features/onboarding/data/onboarding_repository.dart';
import 'package:cuadrante/features/patterns/application/pattern_wizard.dart';
import 'package:cuadrante/features/widget/data/widget_publisher.dart';
import 'package:cuadrante/features/widget/presentation/add_widget_row.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/schedule/application/schedule_providers.dart';
import 'package:cuadrante/features/settings/application/preferences_controller.dart';
import 'package:cuadrante/features/settings/domain/preferences.dart';
import 'package:cuadrante/features/summary/domain/month_summary.dart';
import 'package:cuadrante/features/swaps/application/swaps_controller.dart';
import 'package:cuadrante/features/swaps/data/shift_swaps_repository.dart';
import 'package:cuadrante/features/swaps/domain/shift_swap.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_storage.dart';
import 'readme_render_support.dart';

final _now = DateTime(2026, 12, 24, 18);
const _month = CivilDate(2026, 12, 1);
const _logical = Size(412, 940);
const _targetName = String.fromEnvironment(
  'STORE_TARGET',
  defaultValue: 'github',
);
// Raw screens, no caption or frame: the README phone and the Play tablet.
const _raw = _targetName == 'github' || _targetName == 'tablet';
const _tablet = _targetName == 'tablet';
const _rawPhysical = _tablet ? tabletPhysical : githubPhysical;
const _rawRatio = _tablet ? tabletPixelRatio : githubPixelRatio;
const _rawWidthDp = _tablet ? tabletWidthDp : githubWidthDp;
const _targets = {
  // Raw phone screenshots for the README: no caption, no frame.
  'github': githubPhysical,
  // Raw Android tablet screens in portrait, framed later by store_shots.py
  // (docs/store/shots.json, play-tablet10).
  'tablet': tabletPhysical,
  'play': Size(1080, 1920),
  'ios69': Size(1320, 2868),
  'ios65': Size(1242, 2688),
  // Required by App Store Connect: iPhone with Dynamic Island, medium display.
  'ios63': Size(1206, 2622),
};
// (file name, scene index, dark, README only). The dark month shot and the
// two settings scenes are only for the README; the store targets keep their
// own theme per scene (month and paint in dark).
const _shots = [
  ('01-mes', 0, false, false),
  ('02-lista', 1, false, false),
  ('03-pintar', 2, false, false),
  ('04-rotaciones', 3, false, false),
  ('05-horas', 4, false, false),
  ('06-festivos', 5, false, false),
  ('07-mes-oscuro', 0, true, false),
  ('08-vacaciones', 6, false, true),
  ('09-cambios', 7, false, true),
  ('10-primer-uso', 8, false, true),
  ('11-widgets', 9, false, true),
];
// One caption per shot, in the order of [_shots]. Vocabulary from
// docs/glosario-idiomas.md; ca, gl and eu are pending native review.
const _captions = {
  'es': [
    'Tus turnos, de un vistazo',
    'Cada horario, al detalle',
    'Pinta tus turnos',
    'Tu rotación, a tu manera',
    'Noches y festivos, por separado',
    'Tus festivos, sin conexión',
  ],
  'ca': [
    "Els teus torns, d'un cop d'ull",
    'Cada horari, al detall',
    'Pinta els teus torns',
    'La teva rotació, a la teva manera',
    'Nits i festius, per separat',
    'Els teus festius, sense connexió',
  ],
  'gl': [
    'As túas quendas, dunha ollada',
    'Cada horario, ao detalle',
    'Pinta as túas quendas',
    'A túa rotación, ao teu xeito',
    'Noites e festivos, por separado',
    'Os teus festivos, sen conexión',
  ],
  'eu': [
    'Zure txandak, begi-kolpe batean',
    'Ordutegi bakoitza, xehetasunez',
    'Margotu zure txandak',
    'Zure txandaketa, zure erara',
    'Gauak eta jaiegunak, bereiz',
    'Zure jaiegunak, konexiorik gabe',
  ],
  'en': [
    'Your shifts at a glance',
    'Every shift in detail',
    'Paint your shifts',
    'Your rotation, your way',
    'Night and public holiday hours',
    'Your public holidays, offline',
  ],
};
const _industry = {
  'es': 'Industria',
  'ca': 'Indústria',
  'gl': 'Industria',
  'eu': 'Industria',
  'en': 'Industry',
};

/// Names of the two balances of the «Vacation and leave» scene, in the app's
/// language (the ARB names of the vacation and personal-day shift types).
const _absenceBalanceNames = {
  'es': ('Vacaciones', 'Libre disposición'),
  'ca': ('Vacances', 'Lliure disposició'),
  'gl': ('Vacacións', 'Libre disposición'),
  'eu': ('Oporrak', 'Norberaren eguna'),
  'en': ('Vacation', 'Personal day'),
};

/// Series keys of the two balances (stable every year, so the days carry over).
const _vacationSeries = 'abs-vacaciones';
const _personalSeries = 'abs-libre-disposicion';

void main() {
  setUpAll(() async {
    if (generateStore) await loadStoreFonts();
  });
  tearDownAll(() => AppTypography.debugFamily = null);

  for (final language in _captions.keys) {
    for (final (shot, index, darkShot, readmeOnly) in _shots) {
      // The dark month shot and the two settings scenes only exist for the
      // README.
      if ((darkShot || readmeOnly) && !_raw) continue;
      final dark = _raw ? darkShot : index == 0 || index == 2;
      testWidgets(
        '$language/$shot ($_targetName)',
        (tester) async {
          final target = _targets[_targetName];
          expect(
            target,
            isNotNull,
            reason: 'STORE_TARGET: ${_targets.keys.join(', ')}',
          );
          debugDefaultTargetPlatformOverride = _targetName.startsWith('ios')
              ? TargetPlatform.iOS
              : TargetPlatform.android;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);
          if (_raw) {
            tester.view.physicalSize = _rawPhysical;
            tester.view.devicePixelRatio = _rawRatio;
            // The fake phone has a status bar and a gesture bar: the app
            // keeps clear of them through its own SafeAreas.
            final inset = FakeViewPadding(
              top: githubStatusBarDp * _rawRatio,
              bottom: githubGestureDp * _rawRatio,
            );
            tester.view.padding = inset;
            tester.view.viewPadding = inset;
          } else {
            tester.view.physicalSize = _logical;
            tester.view.devicePixelRatio = 1;
          }
          tester.platformDispatcher.localesTestValue = [Locale(language)];
          tester.platformDispatcher.localeTestValue = Locale(language);
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearAllTestValues);
          debugPhoneLocales = [Locale(language)];
          addTearDown(() => debugPhoneLocales = const [Locale('es', 'ES')]);
          final storage = await openTestStorage(tester, now: _now, demo: false);
          await tester.runAsync(() async {
            final repository = storage.repository;
            final calendars = CalendarsRepository(
              storage.database,
              now: () => _now,
            );
            await calendars.rename(mainCalendarId, 'Demo');
            if (index == 3) {
              await CalendarsRepository(
                storage.database,
                now: () => _now,
                newId: () => 'store-industry',
              ).create(name: _industry[language]!, colorValue: 0xFF4B4FD1);
            }
            // Keep a useful, compact palette; archived types remain in history.
            // The «Vacation and leave» scene also needs the absence types.
            final keep = {'morning', 'afternoon', 'night', 'rest', 'postNight'};
            if (index == 6) keep.addAll({'vacation', 'personalDay'});
            for (final t in shiftTemplates) {
              if (!keep.contains(t.key)) {
                await repository.archiveShiftType(t.key);
              }
            }
            final changes = <CivilDate, EntryChange>{};
            for (var day = 1; day <= 31; day++) {
              final id = switch (day) {
                >= 1 && <= 4 => 'morning',
                10 || 11 => 'afternoon',
                23 || 24 || 25 => 'night',
                26 => 'postNight',
                _ => 'rest',
              };
              final date = CivilDate(2026, 12, day);
              changes[date] = EntryChange(
                null,
                DayEntry(date: date, shiftTypeIds: [id]),
              );
            }
            await repository.apply(
              mainCalendarId,
              ScheduleChange(patch: EntriesPatch(changes)),
            );
            await HolidayRepository(storage.database)
                .savePlace(regionCode: 'ES-MD', municipalityCode: '28079');
            if (index == 6) {
              final stamp = _now.toUtc().millisecondsSinceEpoch;
              final names = _absenceBalanceNames[language]!;
              final balances = AbsenceBalancesRepository(storage.database);
              // 2025: 22 days, 15 taken, the 7 left carry into 2026 (cap 10).
              await balances.save(
                AbsenceBalance(
                  year: 2025,
                  type: _vacationSeries,
                  allowedDays: 22,
                  calendarId: mainCalendarId,
                  name: names.$1,
                  shiftTypeQuarters: const {'vacation': 4},
                  createdAt: stamp,
                  updatedAt: stamp,
                ),
              );
              await balances.save(
                AbsenceBalance(
                  year: 2026,
                  type: _vacationSeries,
                  allowedDays: 22,
                  calendarId: mainCalendarId,
                  name: names.$1,
                  shiftTypeQuarters: const {'vacation': 4},
                  carryOver: true,
                  carryOverMaxDays: 10,
                  sortOrder: 0,
                  createdAt: stamp,
                  updatedAt: stamp,
                ),
              );
              await balances.save(
                AbsenceBalance(
                  year: 2026,
                  type: _personalSeries,
                  allowedDays: 4,
                  calendarId: mainCalendarId,
                  name: names.$2,
                  shiftTypeQuarters: const {'personalDay': 4},
                  sortOrder: 1,
                  createdAt: stamp,
                  updatedAt: stamp,
                ),
              );
              await AbsenceCarryOverStore(storage.database).setExpiry(
                2026,
                _vacationSeries,
                const CivilDate(2027, 3, 31),
                calendarId: mainCalendarId,
              );
              // Days taken: 15 in 2025 (the carry-over), 4 enjoyed and 4
              // planned in 2026, and one personal day.
              final absences = <CivilDate, EntryChange>{};
              void taken(CivilDate date, String shift) {
                absences[date] = EntryChange(
                  null,
                  DayEntry(date: date, shiftTypeIds: [shift]),
                );
              }

              for (var day = 3; day <= 17; day++) {
                taken(CivilDate(2025, 8, day), 'vacation');
              }
              for (var day = 6; day <= 9; day++) {
                taken(CivilDate(2026, 7, day), 'vacation');
              }
              for (var day = 28; day <= 31; day++) {
                taken(CivilDate(2026, 12, day), 'vacation');
              }
              taken(const CivilDate(2026, 7, 13), 'personalDay');
              await repository.apply(
                mainCalendarId,
                ScheduleChange(patch: EntriesPatch(absences)),
              );
            }
            if (index == 7) {
              final stamp = _now.toUtc().millisecondsSinceEpoch;
              final swaps = ShiftSwapsRepository(storage.database);
              // Two colleagues with something pending and one settled.
              await swaps.save(
                ShiftSwap(
                  id: 'store-swap-laura',
                  calendarId: mainCalendarId,
                  date: const CivilDate(2026, 12, 5),
                  colleague: 'Laura',
                  direction: SwapDirection.theyOwe,
                  givenShiftTypeIds: const ['morning', 'afternoon'],
                  createdAt: stamp,
                  updatedAt: stamp,
                ),
              );
              await swaps.save(
                ShiftSwap(
                  id: 'store-swap-marcos',
                  calendarId: mainCalendarId,
                  date: const CivilDate(2026, 12, 12),
                  colleague: 'Marcos',
                  direction: SwapDirection.iOwe,
                  receivedShiftTypeIds: const ['night'],
                  createdAt: stamp,
                  updatedAt: stamp,
                ),
              );
              await swaps.save(
                ShiftSwap(
                  id: 'store-swap-ana',
                  calendarId: mainCalendarId,
                  date: const CivilDate(2026, 11, 20),
                  colleague: 'Ana',
                  direction: SwapDirection.theyOwe,
                  givenShiftTypeIds: const ['morning'],
                  status: SwapStatus.returned,
                  createdAt: stamp,
                  updatedAt: stamp,
                  closedAt: stamp,
                ),
              );
            }
          });
          final snapshot = (await tester.runAsync(
            storage.withReloadedSnapshot,
          ))!;
          final holidays = (await tester.runAsync(
            () => HolidayRepository(storage.database).loadSnapshot(),
          ))!;
          final summary = summarizeMonth(
            snapshot.snapshot.schedule,
            _month,
            holidays: holidays.byDay.keys.toSet(),
          );
          expect(summary.shiftsWorked, 9);
          expect(summary.workedMinutes, 72 * 60);
          expect(summary.nightMinutes, 24 * 60);
          expect(summary.holidayMinutes, 8 * 60);
          final initial = index == 3
              ? (await tester.runAsync(
                  () => storage.repository.load('store-industry'),
                ))!
              : snapshot.snapshot;
          final key = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: ProviderScope(
                overrides: [
                  appDatabaseProvider.overrideWithValue(storage.database),
                  initialScheduleProvider.overrideWithValue(initial),
                  clockProvider.overrideWithValue(() => _now),
                  if (index == 8)
                    initialOnboardingProvider.overrideWithValue(
                      const OnboardingStatus(needed: true),
                    ),
                  initialHolidaysProvider.overrideWithValue(holidays),
                  initialPreferencesProvider.overrideWithValue(
                    Preferences(
                      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
                      language: AppLanguage.values.byName(language),
                    ),
                  ),
                ],
                child: const CuadranteApp(),
              ),
            ),
          );
          try {
            await tester.pumpAndSettle();
            final container = ProviderScope.containerOf(
              tester.element(find.byType(CuadranteApp)),
            );
            final router = container.read(routerProvider);
            switch (index) {
              case 1:
                await tester.tap(
                  find.byKey(const ValueKey('month-presentation-list')),
                );
                await tester.pumpAndSettle();
                // The app initially reveals today; use the beginning of the
                // list for a complete header and whole, unclipped rows.
                tester
                    .state<ScrollableState>(find.byType(Scrollable).first)
                    .position
                    .jumpTo(0);
              case 2:
                final paint = container.read(paintControllerProvider.notifier);
                paint.enter();
                paint.selectShift('night');
              case 3:
                router.push('${AppRoutes.pattern}?inicio=2026-12-01');
                await tester.pumpAndSettle();
                final wizard = container.read(
                  patternWizardProvider((start: _month, shiftId: null))
                      .notifier,
                );
                wizard.selectPreset('continental');
                wizard.next();
                // Step 2: the start day and which day of the cycle it is
                // (0.8.4), here day 2.
                wizard.setStepOffset(1);
                await tester.pumpAndSettle();
              case 4:
                router.push(AppRoutes.summaryFor(_month));
              case 5:
                router.push(AppRoutes.settingsHolidays);
                await tester.pumpAndSettle();
                await tester.runAsync(
                  () => container.read(municipalityIndexProvider.future),
                );
                await tester.runAsync(
                  () => container.read(regionalNationalEntriesProvider.future),
                );
              case 6:
                router.push(AppRoutes.settingsAbsences);
                await tester.pumpAndSettle();
                await tester.runAsync(
                  () => container.read(
                    absenceBalancesProvider(_now.year).future,
                  ),
                );
              case 7:
                router.push(AppRoutes.swaps);
                await tester.pumpAndSettle();
                await tester.runAsync(
                  () => container.read(swapLedgerProvider.future),
                );
              case 9:
                // The «Add widget» gallery over the real month.
                unawaited(
                  showAddWidgetSheet(
                    tester.element(find.byType(Scaffold).first),
                    FakeWidgetPublisher()..pinSupported = true,
                  ),
                );
                await tester.pumpAndSettle();
            }
            await tester.pumpAndSettle();
            if (_raw && (index == 4 || index == 5)) {
              // Long scrolling screens: nudge the scroll so that no text ends
              // up behind the gesture pill (a line struck through by it).
              await _clearGesturePill(tester);
            }
            expect(tester.takeException(), isNull);
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final screen = await boundary.toImage(
                pixelRatio: _raw ? _rawRatio : 3,
              );
              try {
                final image = _raw
                    ? await _composeGithub(screen, target!, dark)
                    : await _compose(
                        screen,
                        target!,
                        _captions[language]![index],
                        index,
                      );
                try {
                  final path = _tablet
                      ? '../docs/store/tablet/$language/$shot.png'
                      : _raw
                      ? '../docs/readme/$language/$shot.png'
                      : 'build/store/$_targetName/$language/$shot.png';
                  await writeStorePng(image, path);
                } finally {
                  image.dispose();
                }
              } finally {
                screen.dispose();
              }
            });
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
            debugDefaultTargetPlatformOverride = null;
          }
        },
        skip: !generateStore,
        timeout: const Timeout(Duration(minutes: 3)),
      );
    }
  }
}

/// Scrolls the biggest vertical list by the smallest amount (up to 160 dp)
/// that leaves every text and icon clear of the gesture pill, without
/// pushing any row that is fully visible above the top edge of the list
/// (the app bar's bottom). If no amount does both, the list stays where it is.
Future<void> _clearGesturePill(WidgetTester tester) async {
  final height = _rawPhysical.height / _rawRatio;
  const pillHalfWidth = 54 + 8.0;
  final pill = Rect.fromLTRB(
    _rawWidthDp / 2 - pillHalfWidth,
    height - 12 - 2 - 6,
    _rawWidthDp / 2 + pillHalfWidth,
    height - 12 + 2 + 6,
  );
  ScrollableState? list;
  RenderBox? listBox;
  var listHeight = 0.0;
  for (final element in find.byType(Scrollable).evaluate()) {
    final state = (element as StatefulElement).state as ScrollableState;
    if (axisDirectionToAxis(state.axisDirection) != Axis.vertical) continue;
    final box = element.renderObject! as RenderBox;
    if (list == null || box.size.height > listHeight) {
      list = state;
      listBox = box;
      listHeight = box.size.height;
    }
  }
  if (list == null || listBox == null) return;
  final listTop = listBox.localToGlobal(Offset.zero).dy;
  final rects = <Rect>[
    for (final finder in [find.byType(Text), find.byType(Icon)])
      for (final element in finder.evaluate())
        if (element.renderObject case final RenderBox box when box.attached)
          box.localToGlobal(Offset.zero) & box.size,
  ];
  bool clearsPill(double d) =>
      rects.every((r) => !r.shift(Offset(0, -d)).overlaps(pill));
  // Rows that start inside the list must stay inside it, so the first row
  // of a screen is never cut by the app bar.
  bool keepsTop(double d) =>
      rects.every((r) => r.top < listTop || r.top - d >= listTop);
  for (var d = 0; d <= 160; d++) {
    if (clearsPill(d.toDouble()) && keepsTop(d.toDouble())) {
      if (d > 0) {
        list.position.jumpTo(list.position.pixels + d);
        await tester.pumpAndSettle();
      }
      return;
    }
  }
}

/// The screen as is, scaled to exactly 1080x2400, with the Android status
/// bar and gesture pill drawn on top. No caption, frame or tint.
Future<ui.Image> _composeGithub(ui.Image screen, Size target, bool dark) async {
  final colors = dark ? AppColors.dark : AppColors.light;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawImageRect(
    screen,
    Rect.fromLTWH(0, 0, screen.width.toDouble(), screen.height.toDouble()),
    Offset.zero & target,
    Paint()..filterQuality = FilterQuality.high,
  );
  paintAndroidChrome(
    canvas,
    size: target,
    ink: colors.textPrimary,
    textStyle: AppTypography.from(colors).body,
    widthDp: _rawWidthDp,
  );
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(target.width.toInt(), target.height.toInt());
  } finally {
    picture.dispose();
  }
}

Future<ui.Image> _compose(
  ui.Image screen,
  Size target,
  String caption,
  int index,
) async {
  final colors = index == 0 || index == 2 ? AppColors.dark : AppColors.light;
  final type = AppTypography.from(colors);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(Offset.zero & target, Paint()..color = colors.background);
  final margin = target.width * .06;
  final titleHeight = target.height * .12;
  paintCaption(
    canvas,
    caption,
    Rect.fromLTWH(margin, margin, target.width - margin * 2, titleHeight),
    type.headline.copyWith(fontSize: target.width * .057),
  );
  final scale = math.min(
    (target.width - margin * 2) / _logical.width,
    (target.height - titleHeight - margin * 2) / _logical.height,
  );
  final rect = Rect.fromLTWH(
    (target.width - _logical.width * scale) / 2,
    titleHeight + margin,
    _logical.width * scale,
    _logical.height * scale,
  );
  final frame = RRect.fromRectAndRadius(
    rect.inflate(2),
    Radius.circular(target.width * .025),
  );
  canvas.drawRRect(frame, Paint()..color = colors.borderStrong);
  canvas.save();
  canvas.clipRRect(
    RRect.fromRectAndRadius(rect, Radius.circular(target.width * .025)),
  );
  canvas.drawImageRect(
    screen,
    Rect.fromLTWH(0, 0, screen.width.toDouble(), screen.height.toDouble()),
    rect,
    Paint()..filterQuality = FilterQuality.high,
  );
  canvas.restore();
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(target.width.toInt(), target.height.toInt());
  } finally {
    picture.dispose();
  }
}
