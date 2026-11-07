import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/format/app_date_format.dart';
import '../../../core/icons/app_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_sheet.dart';
import '../application/preferences_controller.dart';
import 'settings_widgets.dart';

/// The rows of P8 · Apariencia (`docs/paridad-pago.md`) for Ajustes ›
/// Apariencia: «Color de acento», «Fondo negro» and «Tamaño del turno en el mes». Hooked
/// into the section with one line (`...appearanceStyleRows`).
const List<Widget> appearanceStyleRows = [
  AccentSettingRow(key: ValueKey('settings-accent')),
  PureBlackSettingRow(key: ValueKey('settings-pure-black')),
  CellTextSizeSettingRow(key: ValueKey('settings-cell-size')),
];

/// The glyphs of these two rows, picked like `SettingsIcons`: SF-Symbols
/// style on Apple platforms, Material Symbols rounded elsewhere. Kept here
/// so this package does not collide with the others growing that file.
abstract final class _Glyphs {
  static bool get _apple =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  static IconData get accent =>
      _apple ? CupertinoIcons.paintbrush : Symbols.palette_rounded;

  static IconData get pureBlack =>
      _apple ? CupertinoIcons.moon_fill : Symbols.dark_mode_rounded;

  static IconData get cellSize =>
      _apple ? CupertinoIcons.textformat_size : Symbols.format_size_rounded;
}

/// The name of an accent in the user's language.
String accentName(BuildContext context, AppAccent accent) {
  final l10n = context.l10n;
  return switch (accent) {
    AppAccent.indigo => l10n.appearanceAccentIndigo,
    AppAccent.blue => l10n.appearanceAccentBlue,
    AppAccent.petrol => l10n.appearanceAccentPetrol,
    AppAccent.raspberry => l10n.appearanceAccentRaspberry,
    AppAccent.graphite => l10n.appearanceAccentGraphite,
    AppAccent.violet => l10n.appearanceAccentViolet,
    AppAccent.plum => l10n.appearanceAccentPlum,
    AppAccent.emerald => l10n.appearanceAccentEmerald,
    AppAccent.olive => l10n.appearanceAccentOlive,
    AppAccent.terracotta => l10n.appearanceAccentTerracotta,
  };
}

/// The name of a cell text size in the user's language.
String cellTextSizeName(BuildContext context, CellTextSize size) {
  final l10n = context.l10n;
  return switch (size) {
    CellTextSize.normal => l10n.appearanceCellSizeNormal,
    CellTextSize.large => l10n.appearanceCellSizeLarge,
    CellTextSize.extraLarge => l10n.appearanceCellSizeExtraLarge,
  };
}

/// Ajustes › Apariencia › Color de acento: ten tested accents, Índigo by
/// default (option 8.3 of the 31-oct canvas). The change repaints the app at
/// once.
class AccentSettingRow extends ConsumerWidget {
  const AccentSettingRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final accent = ref.watch(preferencesProvider.select((p) => p.accent));
    return SettingsRow(
      icon: _Glyphs.accent,
      title: l10n.appearanceAccentTitle,
      value: accentName(context, accent),
      onTap: () async {
        final picked = await showAccentSheet(context, selected: accent);
        if (picked != null && context.mounted) {
          await saveSetting(
            context,
            () => ref.read(preferencesProvider.notifier).setAccent(picked),
          );
        }
      },
    );
  }
}

/// Ajustes › Apariencia › «Fondo negro»: pure black behind the screens of the
/// dark theme, for OLED phones. Off by default; changes nothing in the light
/// theme.
class PureBlackSettingRow extends ConsumerWidget {
  const PureBlackSettingRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final value = ref.watch(preferencesProvider.select((p) => p.pureBlack));
    return SettingsSwitchRow(
      icon: _Glyphs.pureBlack,
      title: l10n.appearancePureBlackTitle,
      subtitle: l10n.appearancePureBlackSubtitle,
      value: value,
      switchKey: const ValueKey('settings-pure-black-switch'),
      onChanged: (enabled) => saveSetting(
        context,
        () => ref.read(preferencesProvider.notifier).setPureBlack(enabled),
      ),
    );
  }
}

/// Ajustes › Apariencia › Tamaño del turno en el mes: Normal, Grande, Muy
/// grande. Each option shows a small cell drawn at that size.
class CellTextSizeSettingRow extends ConsumerWidget {
  const CellTextSizeSettingRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final size = ref.watch(preferencesProvider.select((p) => p.cellTextSize));
    return SettingsRow(
      icon: _Glyphs.cellSize,
      title: l10n.appearanceCellSizeTitle,
      value: cellTextSizeName(context, size),
      onTap: () async {
        final picked = await showCellTextSizeSheet(context, selected: size);
        if (picked != null && context.mounted) {
          await saveSetting(
            context,
            () =>
                ref.read(preferencesProvider.notifier).setCellTextSize(picked),
          );
        }
      },
    );
  }
}

/// The sheet of the accents; returns the one picked, or null.
Future<AppAccent?> showAccentSheet(
  BuildContext context, {
  required AppAccent selected,
}) {
  final l10n = context.l10n;
  return showAppSheet<AppAccent>(
    context: context,
    padded: true,
    builder: (ctx) => _OptionsSheet(
      title: l10n.appearanceAccentTitle,
      note: l10n.appearanceAccentNote,
      children: [
        for (final accent in AppAccent.values)
          _OptionRow(
            key: ValueKey('accent-${accent.stored}'),
            leading: AccentSwatch(accent: accent),
            label: accentName(ctx, accent),
            subtitle: accent == AppAccent.defaultAccent
                ? l10n.appearanceAccentDefault
                : null,
            selected: accent == selected,
            onTap: () => Navigator.pop(ctx, accent),
          ),
      ],
    ),
  );
}

/// The sheet of the cell sizes; returns the one picked, or null.
Future<CellTextSize?> showCellTextSizeSheet(
  BuildContext context, {
  required CellTextSize selected,
}) {
  final l10n = context.l10n;
  return showAppSheet<CellTextSize>(
    context: context,
    padded: true,
    builder: (ctx) => _OptionsSheet(
      title: l10n.appearanceCellSizeTitle,
      note: l10n.appearanceCellSizeNote,
      children: [
        for (final size in CellTextSize.values)
          _OptionRow(
            key: ValueKey('cell-size-${size.stored}'),
            leading: CellSizeSample(size: size),
            label: cellTextSizeName(ctx, size),
            selected: size == selected,
            onTap: () => Navigator.pop(ctx, size),
          ),
      ],
    ),
  );
}

/// A disc with the accent of the light theme on one half and the one of the
/// dark theme on the other, like the canvas.
class AccentSwatch extends StatelessWidget {
  const AccentSwatch({super.key, required this.accent});

  final AppAccent accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Disc.m,
      height: Disc.m,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: context.colors.border),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.light, accent.light, accent.dark, accent.dark],
          stops: const [0, 0.5, 0.5, 1],
        ),
      ),
    );
  }
}

/// A small neutral cell with a code and a time drawn with the cell styles of
/// [size] (the same `AppTypography.from` the theme uses), so the user sees
/// the size before picking it. Not a real day: no shift colour.
class CellSizeSample extends StatelessWidget {
  const CellSizeSample({super.key, required this.size});

  final CellTextSize size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = AppTypography.from(colors, cellScale: size.factor);
    // A night shift, 22:00 to 06:00, in the clock the cells use.
    final hour12 = AppDateFormat.of(context).hour12;
    final time =
        '${AppDateFormat.compactClock(22 * 60, hour12: hour12)}'
        '–${AppDateFormat.compactClock(6 * 60, hour12: hour12)}';
    return ExcludeSemantics(
      child: Container(
        constraints: const BoxConstraints(minWidth: Disc.l),
        padding: const EdgeInsets.symmetric(horizontal: Sp.xs, vertical: Sp.xs),
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: BorderRadius.circular(Rad.cell),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.appearanceCellSizeSampleCode,
              maxLines: 1,
              style: type.cellCode,
            ),
            Text(time, maxLines: 1, style: type.cellTime),
          ],
        ),
      ),
    );
  }
}

class _OptionsSheet extends StatelessWidget {
  const _OptionsSheet({
    required this.title,
    required this.note,
    required this.children,
  });

  final String title;
  final String note;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(title, style: type.headline)),
        const SizedBox(height: Sp.xs),
        Text(note, style: type.meta),
        const SizedBox(height: Sp.m),
        ...children,
      ],
    );
  }
}

/// A row of a single-choice sheet with a leading picture; the same indent,
/// height and check as `ChoiceRow`.
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    super.key,
    required this.leading,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final Widget leading;
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  static const double minHeight = 56;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Semantics(
      button: true,
      selected: selected,
      excludeSemantics: true,
      label: subtitle == null ? label : '$label, $subtitle',
      // The InkWell's own action is excluded with its semantics.
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
                leading,
                const SizedBox(width: Sp.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: selected ? type.bodyStrong : type.body,
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: type.meta.copyWith(color: colors.textMuted),
                        ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(AppIcons.check, color: colors.accentStrong, weight: 600),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
