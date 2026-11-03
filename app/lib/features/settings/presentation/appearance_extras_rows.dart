import 'dart:io' show File;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/icons/app_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../calendar/application/calendar_background_providers.dart';
import '../../calendar/application/schedule_controller.dart';
import '../../calendar/data/calendar_background_store.dart';
import '../../shift_types/domain/shift_color_presets.dart';
import '../application/preferences_controller.dart';
import 'settings_widgets.dart';

/// The «Extras visuales» of Ajustes › Apariencia (UX): «Ver la nota en el
/// mes», «Sonido al pintar», «Paletas preparadas» and «Imagen de fondo del
/// calendario». Hooked into the section with one line (`...appearanceExtraRows`).
const List<Widget> appearanceExtraRows = [
  ShowNoteInMonthSettingRow(key: ValueKey('settings-note-in-month')),
  PaintSoundSettingRow(key: ValueKey('settings-paint-sound')),
  ShiftColorPresetSettingRow(key: ValueKey('settings-color-presets')),
  CalendarBackgroundSettingRow(key: ValueKey('settings-calendar-background')),
];

/// Glyphs of these rows, picked like `SettingsIcons`: SF-Symbols style on
/// Apple platforms, Material Symbols rounded elsewhere. Kept here so the file
/// does not collide with the other presentations growing `app_icons.dart`.
abstract final class _Glyphs {
  static bool get _apple =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  static IconData get note =>
      _apple ? CupertinoIcons.doc_text : Symbols.event_note_rounded;

  static IconData get sound =>
      _apple ? CupertinoIcons.speaker_2 : Symbols.volume_up_rounded;

  static IconData get presets =>
      _apple ? CupertinoIcons.circle_lefthalf_fill : Symbols.contrast_rounded;

  static IconData get background =>
      _apple ? CupertinoIcons.rectangle_stack : Symbols.layers_rounded;
}

/// The name of a prepared colour set in the user's language.
String shiftColorPresetName(BuildContext context, String id) {
  final l10n = context.l10n;
  return switch (id) {
    'sunset' => l10n.appearancePresetSunset,
    'sea' => l10n.appearancePresetSea,
    'forest' => l10n.appearancePresetForest,
    'candy' => l10n.appearancePresetCandy,
    'nocturnal' => l10n.appearancePresetNocturnal,
    _ => id,
  };
}

/// Ajustes › Apariencia › «Ver la nota en el mes» (UX · Extras visuales): the
/// first line of the note is written in the cell of the month.
class ShowNoteInMonthSettingRow extends ConsumerWidget {
  const ShowNoteInMonthSettingRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final value = ref.watch(
      preferencesProvider.select((p) => p.showNoteInMonth),
    );
    return SettingsSwitchRow(
      icon: _Glyphs.note,
      title: l10n.appearanceNoteInMonthTitle,
      subtitle: l10n.appearanceNoteInMonthSubtitle,
      value: value,
      switchKey: const ValueKey('settings-note-in-month-switch'),
      onChanged: (show) => saveSetting(
        context,
        () => ref.read(preferencesProvider.notifier).setShowNoteInMonth(show),
      ),
    );
  }
}

/// Ajustes › Apariencia › «Sonido al pintar» (UX · Extras visuales): a click of
/// the system when a day is painted. Off by default; the silent mode is kept.
class PaintSoundSettingRow extends ConsumerWidget {
  const PaintSoundSettingRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final value = ref.watch(preferencesProvider.select((p) => p.paintSound));
    return SettingsSwitchRow(
      icon: _Glyphs.sound,
      title: l10n.appearancePaintSoundTitle,
      subtitle: l10n.appearancePaintSoundSubtitle,
      value: value,
      switchKey: const ValueKey('settings-paint-sound-switch'),
      onChanged: (enabled) => saveSetting(
        context,
        () => ref.read(preferencesProvider.notifier).setPaintSound(enabled),
      ),
    );
  }
}

/// Ajustes › Apariencia › «Paletas preparadas» (UX · Extras visuales): opens
/// the sheet of sets and applies the chosen one in one undoable step.
class ShiftColorPresetSettingRow extends ConsumerWidget {
  const ShiftColorPresetSettingRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return SettingsRow(
      icon: _Glyphs.presets,
      title: l10n.appearancePresetsTitle,
      value: l10n.appearancePresetsChoose,
      onTap: () async {
        final preset = await showShiftColorPresetSheet(context);
        if (preset == null || !context.mounted) return;
        final controller = ref.read(scheduleControllerProvider.notifier);
        final previous = controller.applyColorPreset(preset);
        // Nothing changed (every type already has that colour, or only custom
        // colours are left): no notice.
        if (previous == null || !context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            appSnackBar(
              context: context,
              content: Text(l10n.appearancePresetsApplied),
              action: SnackBarAction(
                label: l10n.undo,
                onPressed: () => controller.restoreShiftTypes(previous),
              ),
            ),
          );
      },
    );
  }
}

/// Ajustes › Apariencia › «Imagen de fondo del calendario» (UX · Extras
/// visuales): opens the sheet to pick one from the gallery or to remove it,
/// and shows a small thumbnail of the one in use.
class CalendarBackgroundSettingRow extends ConsumerWidget {
  const CalendarBackgroundSettingRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final file = ref.watch(calendarBackgroundFileProvider).value;
    return SettingsRow(
      icon: _Glyphs.background,
      title: l10n.appearanceBackgroundTitle,
      subtitle: file == null ? null : l10n.appearanceBackgroundOnDevice,
      value: file == null ? l10n.appearanceBackgroundChoose : null,
      trailing: file == null ? null : _BackgroundThumb(file: file),
      onTap: () => _chooseBackground(context, ref, hasImage: file != null),
    );
  }

  Future<void> _chooseBackground(
    BuildContext context,
    WidgetRef ref, {
    required bool hasImage,
  }) async {
    final l10n = context.l10n;
    final action = await showCalendarBackgroundSheet(
      context,
      hasImage: hasImage,
    );
    if (action == null || !context.mounted) return;

    final serviceFuture = ref.read(calendarBackgroundServiceProvider.future);
    if (action == CalendarBackgroundAction.remove) {
      final service = await serviceFuture;
      await service.remove();
      return;
    }

    final bytes = await ref.read(calendarImagePickerProvider)();
    if (bytes == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final tooLarge = l10n.appearanceBackgroundTooLarge;
    final failed = l10n.appearanceBackgroundFailed;
    try {
      final service = await serviceFuture;
      await service.setFromBytes(bytes);
    } on CalendarBackgroundException {
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(appSnackBar(content: Text(tooLarge)));
    } catch (_) {
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(appSnackBar(content: Text(failed)));
    }
  }
}

/// What the calendar-background sheet returns.
enum CalendarBackgroundAction { pick, remove }

/// The sheet of the calendar background; returns what was chosen, or `null`.
Future<CalendarBackgroundAction?> showCalendarBackgroundSheet(
  BuildContext context, {
  required bool hasImage,
}) {
  final l10n = context.l10n;
  return showAppSheet<CalendarBackgroundAction>(
    context: context,
    padded: true,
    builder: (ctx) => _BackgroundSheet(hasImage: hasImage, l10n: l10n),
  );
}

class _BackgroundSheet extends StatelessWidget {
  const _BackgroundSheet({required this.hasImage, required this.l10n});

  final bool hasImage;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.appearanceBackgroundTitle, style: type.headline),
        ),
        const SizedBox(height: Sp.xs),
        Text(l10n.appearanceBackgroundNote, style: type.meta),
        const SizedBox(height: Sp.m),
        _SheetOption(
          key: const ValueKey('background-pick'),
          icon: AppIcons.add,
          label: hasImage
              ? l10n.appearanceBackgroundChange
              : l10n.appearanceBackgroundPick,
          onTap: () => Navigator.pop(context, CalendarBackgroundAction.pick),
        ),
        if (hasImage)
          _SheetOption(
            key: const ValueKey('background-remove'),
            icon: AppIcons.remove,
            label: l10n.appearanceBackgroundRemove,
            destructive: true,
            onTap: () =>
                Navigator.pop(context, CalendarBackgroundAction.remove),
          ),
      ],
    );
  }
}

/// Small preview of the picture in use, at the trailing edge of the row.
class _BackgroundThumb extends StatelessWidget {
  const _BackgroundThumb({required this.file});

  final File file;

  static const double _size = Disc.l;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: Rad.chipSmallRadius,
        child: Image.file(
          file,
          width: _size,
          height: _size,
          fit: BoxFit.cover,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => const SizedBox.square(dimension: _size),
        ),
      ),
    );
  }
}

/// One option of the background sheet: an icon and a label, one touch target.
class _SheetOption extends StatelessWidget {
  const _SheetOption({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  static const double minHeight = 56;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final color = destructive ? colors.danger : colors.textPrimary;
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: label,
      onTap: onTap,
      child: InkWell(
        borderRadius: Rad.rowRadius,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Sp.xs,
              vertical: Sp.s,
            ),
            child: Row(
              children: [
                Icon(icon, size: IconSize.button, color: color),
                const SizedBox(width: Sp.m),
                Expanded(
                  child: Text(label, style: type.body.copyWith(color: color)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The sheet of the prepared colour sets; returns the one picked, or `null`.
Future<ShiftColorPreset?> showShiftColorPresetSheet(BuildContext context) {
  final l10n = context.l10n;
  return showAppSheet<ShiftColorPreset>(
    context: context,
    padded: true,
    builder: (ctx) => _PresetsSheet(l10n: l10n),
  );
}

class _PresetsSheet extends StatelessWidget {
  const _PresetsSheet({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.appearancePresetsTitle, style: type.headline),
        ),
        const SizedBox(height: Sp.xs),
        Text(l10n.appearancePresetsNote, style: type.meta),
        const SizedBox(height: Sp.m),
        for (final preset in shiftColorPresets)
          _PresetRow(
            key: ValueKey('preset-${preset.id}'),
            preset: preset,
            onTap: () => Navigator.pop(context, preset),
          ),
      ],
    );
  }
}

/// One prepared set: a strip of the real cell tints of its colours, then its
/// name.
class _PresetRow extends StatelessWidget {
  const _PresetRow({super.key, required this.preset, required this.onTap});

  final ShiftColorPreset preset;
  final VoidCallback onTap;

  static const double minHeight = 56;

  @override
  Widget build(BuildContext context) {
    final label = shiftColorPresetName(context, preset.id);
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: label,
      onTap: onTap,
      child: InkWell(
        borderRadius: Rad.rowRadius,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Sp.xs,
              vertical: Sp.s,
            ),
            child: Row(
              children: [
                _PresetSwatch(preset: preset),
                const SizedBox(width: Sp.m),
                Expanded(child: Text(label, style: context.type.body)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The strip of one prepared set: each colour as the tint of a day cell with
/// its bar under it, the real look the set gives a shift.
class _PresetSwatch extends StatelessWidget {
  const _PresetSwatch({required this.preset});

  final ShiftColorPreset preset;

  static const double _width = 14;
  static const double _height = 26;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final swatches = [
      for (final color in preset.colors)
        ShiftSwatch.forColor(color.toARGB32(), colors.brightness),
    ];
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final swatch in swatches)
            Padding(
              padding: const EdgeInsets.only(right: Sp.hair),
              child: Container(
                width: _width,
                height: _height,
                decoration: BoxDecoration(
                  color: swatch.tint,
                  borderRadius: Rad.chipSmallRadius,
                  border: Border.all(color: colors.border),
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: Sp.hair * 2,
                    decoration: BoxDecoration(
                      color: swatch.bar,
                      borderRadius: Rad.chipSmallRadius,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
