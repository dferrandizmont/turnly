import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/app_date_format.dart';
import '../../../core/icons/app_icons.dart';
import '../../../core/icons/settings_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/buttons.dart';
import '../../calendar/application/schedule_controller.dart';
import '../../calendars/application/primary_schedule.dart';
import '../../holidays/application/holidays_provider.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../../settings/application/preferences_controller.dart';
import '../../settings/presentation/settings_widgets.dart';
import '../application/widget_providers.dart';
import '../data/widget_publisher.dart';
import '../domain/widget_snapshot.dart';
import '../domain/widget_snapshot_builder.dart';
import '../domain/widget_strings.dart';
import 'widget_previews.dart';

/// Settings row "Añadir widget": opens the gallery that shows the six
/// widgets with the user's shifts and pins the chosen one (Android launchers
/// that support it) or explains how to add one by hand.
class AddWidgetSettingsRow extends ConsumerWidget {
  const AddWidgetSettingsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return SettingsRow(
      key: const ValueKey('settings-widget'),
      icon: SettingsIcons.widget,
      title: l10n.widgetAddTitle,
      subtitle: l10n.widgetAddSubtitle,
      onTap: () =>
          showAddWidgetSheet(context, ref.read(widgetPublisherProvider)),
    );
  }
}

/// The "Añadir widget" sheet (design 7A, B8): a gallery of the six widgets
/// at scale on a home-screen background, drawn with the user's shifts of
/// today; tapping one chooses it and the button says «Añadir Mediano». With
/// [publisher] unable to pin, the gallery stays (to see them) and the manual
/// steps of the platform replace the button.
Future<void> showAddWidgetSheet(
  BuildContext context,
  WidgetPublisher publisher,
) {
  return showAppSheet<void>(
    context: context,
    builder: (sheetContext) => _AddWidgetSheet(publisher: publisher),
  );
}

/// The schedule the widget follows (the primary calendar's). The gallery
/// shows the one on screen until it is read.
final _previewScheduleProvider = FutureProvider.autoDispose<Schedule>(
  readPrimarySchedule,
);

/// The order of the gallery.
const List<WidgetSize> _gallery = [
  WidgetSize.small,
  WidgetSize.agenda,
  WidgetSize.medium,
  WidgetSize.twoWeeks,
  WidgetSize.fourWeeks,
  WidgetSize.large,
];

/// The part of the keys of each widget: `widget-preview-<id>` for its tile
/// and `widget-pin-<id>` for the button while it is the chosen one.
String _id(WidgetSize size) => switch (size) {
  WidgetSize.twoWeeks => 'two-weeks',
  WidgetSize.fourWeeks => 'four-weeks',
  _ => size.name,
};

class _AddWidgetSheet extends ConsumerStatefulWidget {
  const _AddWidgetSheet({required this.publisher});

  final WidgetPublisher publisher;

  @override
  ConsumerState<_AddWidgetSheet> createState() => _AddWidgetSheetState();
}

class _AddWidgetSheetState extends ConsumerState<_AddWidgetSheet> {
  WidgetSize _selected = WidgetSize.medium;
  late final Future<bool> _canPin = widget.publisher.canPin();

  /// One day of snapshot: today, its strip, its month and the two weeks.
  WidgetSnapshot _snapshot(BuildContext context) {
    final active = ref.watch(
      scheduleControllerProvider.select((s) => s.schedule),
    );
    final schedule = ref.watch(_previewScheduleProvider).value ?? active;
    final now = ref.watch(minuteClockProvider);
    return buildWidgetSnapshot(
      schedule: schedule,
      holidays: ref.watch(holidaysProvider),
      today: CivilDate.fromDateTime(now),
      timeZone: '',
      strings: WidgetStrings.fromL10n(
        context.l10n,
        hour12: AppDateFormat.of(context).hour12,
      ),
      days: kWidgetFourWeeksDays,
      weekStart: ref.watch(preferencesProvider.select((p) => p.weekStart)),
      generatedAt: now,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.type;
    final colors = context.colors;
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    final snapshot = _snapshot(context);
    final names = {
      WidgetSize.small: l10n.widgetNameSmall,
      WidgetSize.medium: l10n.widgetNameMedium,
      WidgetSize.large: l10n.widgetNameLarge,
      WidgetSize.agenda: l10n.widgetNameAgenda,
      WidgetSize.twoWeeks: l10n.widgetNameTwoWeeks,
      WidgetSize.fourWeeks: l10n.widgetNameFourWeeks,
    };

    Widget tile(WidgetSize size) => _PreviewTile(
      key: ValueKey('widget-preview-${_id(size)}'),
      size: size,
      snapshot: snapshot,
      name: names[size]!,
      description: switch (size) {
        WidgetSize.small => l10n.widgetDescSmall,
        WidgetSize.medium => l10n.widgetDescMedium,
        WidgetSize.large => l10n.widgetDescLarge,
        WidgetSize.agenda => l10n.widgetDescAgenda,
        WidgetSize.twoWeeks => l10n.widgetDescTwoWeeks,
        WidgetSize.fourWeeks => l10n.widgetDescFourWeeks,
      },
      semanticLabel: switch (size) {
        WidgetSize.small => l10n.widgetAddSmall,
        WidgetSize.medium => l10n.widgetAddMedium,
        WidgetSize.large => l10n.widgetAddLarge,
        WidgetSize.agenda => l10n.widgetAddAgenda,
        WidgetSize.twoWeeks => l10n.widgetAddTwoWeeks,
        WidgetSize.fourWeeks => l10n.widgetAddFourWeeks,
      },
      selected: size == _selected,
      onTap: () => setState(() => _selected = size),
    );

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.widgetAddTitle, style: type.headline),
        ),
        const SizedBox(height: Sp.xs),
        Text(
          l10n.widgetAddBody,
          style: type.body.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: Sp.m),
      ],
    );
    final gallery = _Wallpaper(
      child: LayoutBuilder(
        builder: (context, box) {
          // Small and Agenda side by side, as on a home screen; one under
          // the other when there is no room.
          final sideBySide =
              !context.largeText && box.maxWidth >= _PreviewTile.minPairWidth;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (sideBySide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: tile(_gallery[0])),
                    const SizedBox(width: Sp.m),
                    Expanded(flex: 3, child: tile(_gallery[1])),
                  ],
                )
              else ...[
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _PreviewTile.smallMaxWidth,
                    ),
                    child: tile(_gallery[0]),
                  ),
                ),
                const SizedBox(height: Sp.l),
                tile(_gallery[1]),
              ],
              for (final size in _gallery.skip(2)) ...[
                const SizedBox(height: Sp.l),
                tile(size),
              ],
            ],
          );
        },
      ),
    );

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: FutureBuilder<bool>(
          future: _canPin,
          builder: (context, pin) {
            final canPin = pin.data ?? false;
            // Only the button stays fixed under the gallery; the title and,
            // without pinning, the manual steps scroll with it, so nothing
            // is cut on a small phone with large text.
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    key: const ValueKey('widget-gallery'),
                    padding: const EdgeInsets.fromLTRB(
                      Sp.page,
                      0,
                      Sp.page,
                      Sp.l,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        header,
                        gallery,
                        if (!canPin) ...[
                          const SizedBox(height: Sp.l),
                          Text(
                            key: const ValueKey('widget-add-manual'),
                            ios
                                ? l10n.widgetAddManualIos
                                : l10n.widgetAddManualAndroid,
                            style: type.body.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (canPin)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border(top: BorderSide(color: colors.border)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Sp.page,
                        Sp.m,
                        Sp.page,
                        Sp.l,
                      ),
                      child: PrimaryButton(
                        key: ValueKey('widget-pin-${_id(_selected)}'),
                        label: l10n.widgetAddNamed(names[_selected]!),
                        icon: AppIcons.add,
                        onPressed: () {
                          Navigator.pop(context);
                          widget.publisher.requestPin(_selected);
                        },
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A home-screen background for the gallery, made of the theme's soft
/// tokens (accent, muted surface and a touch of the highlight).
class _Wallpaper extends StatelessWidget {
  const _Wallpaper({required this.child});

  final Widget child;

  /// Share of the highlight in the warm end of the background.
  static const double _warmth = 0.18;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: Rad.cardRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.accentSoft,
            colors.surfaceMuted,
            Color.alphaBlend(
              colors.highlight.withValues(alpha: _warmth),
              colors.surfaceMuted,
            ),
          ],
        ),
      ),
      child: Padding(padding: const EdgeInsets.all(Sp.l), child: child),
    );
  }
}

/// One widget of the gallery: its drawing (with a ring when chosen), its
/// name and what it shows. One button for screen readers: «Mediano: los
/// próximos 7 días», selected or not.
class _PreviewTile extends StatelessWidget {
  const _PreviewTile({
    super.key,
    required this.size,
    required this.snapshot,
    required this.name,
    required this.description,
    required this.semanticLabel,
    required this.selected,
    required this.onTap,
  });

  final WidgetSize size;
  final WidgetSnapshot snapshot;
  final String name;
  final String description;
  final String semanticLabel;
  final bool selected;
  final VoidCallback onTap;

  /// Narrowest gallery that fits Small and Agenda side by side.
  static const double minPairWidth = 300;

  /// Small never grows past this on its own row.
  static const double smallMaxWidth = 200;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: Motion.of(context, Motion.state),
              curve: Motion.curve,
              padding: const EdgeInsets.all(Sp.xs),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Rad.preview + Sp.xs),
                border: Border.all(
                  color: selected ? colors.todayRing : Colors.transparent,
                  width: Sp.selectionRing,
                ),
              ),
              child: WidgetPreview(size: size, snapshot: snapshot),
            ),
            const SizedBox(height: Sp.xs),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.xs),
              child: Wrap(
                spacing: Sp.s,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  Text(name, style: type.bodyStrong),
                  Text(
                    description,
                    style: type.meta.copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
