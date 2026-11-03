import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/icons/app_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_callout.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/content_app_bar.dart';
import '../../../core/widgets/empty_illustration.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/page_body.dart';
import '../../calendar_export/application/device_calendar_providers.dart';
import '../../calendar_export/domain/device_calendar_api.dart';
import '../../calendars/presentation/calendar_dot.dart';
import '../application/device_events_providers.dart';
import '../domain/device_events_permission.dart';
import '../domain/device_events_settings.dart';

/// «Citas del móvil» (`/ajustes/citas`, P6): the calendars of the phone whose
/// appointments are shown next to the shifts.
///
/// The permission is never asked for on its own: the card says what it is
/// for and only its button shows the question of the system.
class DeviceEventsScreen extends ConsumerStatefulWidget {
  const DeviceEventsScreen({super.key});

  @override
  ConsumerState<DeviceEventsScreen> createState() => _DeviceEventsScreenState();
}

class _DeviceEventsScreenState extends ConsumerState<DeviceEventsScreen> {
  /// The person refused the question just now (and it can be asked again).
  bool _declined = false;

  /// The system question is on screen.
  bool _busy = false;

  Future<void> _request() async {
    if (_busy) return;
    setState(() => _busy = true);
    final outcome = await requestDeviceEventsPermission(ref);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _declined = outcome.declined;
    });
  }

  Future<void> _openSettings() async {
    try {
      await ref.read(deviceCalendarApiProvider).openSettings();
    } catch (_) {
      _fail();
    }
  }

  /// Reads the permission again (the person may have given it in the settings
  /// of the system). The button shows it is working while the read lasts.
  Future<void> _recheck() async {
    if (_busy) return;
    setState(() => _busy = true);
    refreshDeviceEvents(ref);
    try {
      await ref.read(deviceEventsPermissionProvider.future);
    } catch (_) {
      // The card of the screen shows the problem.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fail() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(appSnackBar(content: Text(context.l10n.devEventsSaveFailed)));
  }

  /// Chooses or unchooses the calendar [id]. The order of the chosen ones is
  /// kept; a new one goes to the end.
  Future<void> _toggle(String id, bool chosen) async {
    final current =
        ref.read(deviceEventsSettingsProvider).value ?? DeviceEventsSettings.none;
    final ids = [...current.calendarIds];
    if (chosen) {
      ids.remove(id);
    } else {
      ids.add(id);
    }
    try {
      await ref.read(deviceEventsSettingsProvider.notifier).setCalendars(ids);
    } catch (_) {
      _fail();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    final permissionState = ref.watch(deviceEventsPermissionProvider);
    final permission = permissionState.value;
    final calendars = ref.watch(deviceEventsCalendarsProvider).value;
    final settings = ref.watch(deviceEventsSettingsProvider).value;
    final chosen = settings?.calendarIds ?? const <String>[];

    return Scaffold(
      appBar: ContentAppBar.adaptive(context, title: Text(l10n.devEventsTitle)),
      body: PageBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Sp.page,
            Sp.s,
            Sp.page,
            Sp.section,
          ),
          children: [
            Text(
              l10n.devEventsHelp,
              style: type.body.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: Sp.l),
            if (permissionState.hasError)
              _errorCard(l10n)
            else if (permission == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: Sp.xl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (permission == DeviceEventsPermission.granted)
              ..._calendars(l10n, colors, type, calendars ?? const [], chosen)
            else
              _permissionCard(l10n, permission),
            // With the preference still loading, nothing chosen is not yet a
            // choice: wait for `settings` before saying the feature is off.
            if (permission == DeviceEventsPermission.granted &&
                settings != null &&
                chosen.isEmpty) ...[
              const SizedBox(height: Sp.l),
              AppCallout(
                key: const ValueKey('device-events-off'),
                icon: AppIcons.calendar,
                title: l10n.devEventsOffTitle,
                message: l10n.devEventsOffBody,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The phone's calendar did not answer: what to say and how to try again.
  Widget _errorCard(AppLocalizations l10n) => AppCallout(
    key: const ValueKey('device-events-error'),
    icon: AppIcons.error,
    title: l10n.devEventsReadFailedTitle,
    message: l10n.devEventsReadFailedBody,
    primaryKey: const ValueKey('device-events-error-retry'),
    primaryLabel: l10n.devEventsPermissionRecheck,
    onPrimary: _busy ? null : _recheck,
    primaryLoading: _busy,
  );

  /// The calendars of the phone, each one with a check when it is chosen
  /// (never colour alone).
  ///
  /// It is only reached with the permission granted, which already means the
  /// phone has at least one calendar the app can read: the empty case is the
  /// `noCalendars` state of [_permissionCard], never this one.
  List<Widget> _calendars(
    AppLocalizations l10n,
    AppColors colors,
    AppTypography type,
    List<DeviceCalendarInfo> calendars,
    List<String> chosen,
  ) {
    return [
      Semantics(
        header: true,
        child: Text(
          l10n.devEventsCalendarsTitle,
          style: type.label.copyWith(color: colors.textMuted),
        ),
      ),
      const SizedBox(height: Sp.xs),
      Text(
        l10n.devEventsChosenCount(chosen.length),
        key: const ValueKey('device-events-chosen-count'),
        style: type.meta.copyWith(color: colors.textMuted),
      ),
      const SizedBox(height: Sp.s),
      AppCard(
        key: const ValueKey('device-events-calendars'),
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < calendars.length; i++) ...[
              if (i > 0)
                Divider(height: 1, thickness: 1, color: colors.border),
              _CalendarChoice(
                key: ValueKey('device-events-calendar-${calendars[i].id}'),
                title: calendars[i].name,
                subtitle: calendars[i].accountName,
                color: calendars[i].colorValue,
                selected: chosen.contains(calendars[i].id),
                onTap: () =>
                    _toggle(calendars[i].id, chosen.contains(calendars[i].id)),
              ),
            ],
          ],
        ),
      ),
    ];
  }

  /// What the permission card says, and the buttons that change it.
  Widget _permissionCard(AppLocalizations l10n, DeviceEventsPermission state) {
    final apple =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    return switch (state) {
      DeviceEventsPermission.denied => AppCallout(
        key: const ValueKey('device-events-permission-denied'),
        icon: AppIcons.error,
        title: l10n.devEventsPermissionDeniedTitle,
        message: apple
            ? l10n.devEventsPermissionDeniedBodyIos
            : l10n.devEventsPermissionDeniedBody,
        primaryKey: const ValueKey('device-events-permission-settings'),
        primaryLabel: l10n.devEventsPermissionSettings,
        onPrimary: _busy ? null : _openSettings,
        secondaryKey: const ValueKey('device-events-permission-recheck'),
        secondaryLabel: l10n.devEventsPermissionRecheck,
        onSecondary: _busy ? null : _recheck,
      ),
      DeviceEventsPermission.restricted => AppCallout(
        key: const ValueKey('device-events-permission-restricted'),
        icon: AppIcons.error,
        title: l10n.devEventsPermissionRestrictedTitle,
        message: l10n.devEventsPermissionRestrictedBody,
      ),
      DeviceEventsPermission.noCalendars => EmptyState(
        key: const ValueKey('device-events-no-calendars'),
        icon: AppIcons.calendar,
        illustration: const EmptyIllustration(
          kind: EmptyIllustrationKind.calendar,
        ),
        title: l10n.devEventsEmptyTitle,
        message: l10n.devEventsEmptyBody,
        compact: true,
      ),
      _ => AppCallout(
        key: const ValueKey('device-events-permission-needed'),
        icon: AppIcons.calendar,
        title: l10n.devEventsPermissionTitle,
        message: _declined
            ? l10n.devEventsPermissionDeclinedBody
            : l10n.devEventsPermissionBody,
        primaryKey: const ValueKey('device-events-permission-allow'),
        primaryLabel: l10n.devEventsPermissionAllow,
        onPrimary: _busy ? null : _request,
        primaryLoading: _busy,
      ),
    };
  }
}

/// A calendar of the phone: its colour, its name and its account, and a check
/// when it is chosen (never colour alone).
class _CalendarChoice extends StatelessWidget {
  const _CalendarChoice({
    super.key,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final int? color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Semantics(
      button: true,
      selected: selected,
      excludeSemantics: true,
      label: subtitle == null ? title : '$title, $subtitle',
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Sp.touch),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Sp.l,
              vertical: Sp.m,
            ),
            child: Row(
              children: [
                CalendarDot(
                  colorValue: color ?? colors.accent.toARGB32(),
                  size: CalendarDot.rowSize,
                ),
                const SizedBox(width: Sp.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: type.body.copyWith(
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
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
                  Icon(
                    AppIcons.check,
                    key: const ValueKey('device-events-calendar-check'),
                    size: IconSize.button,
                    color: colors.accent,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
