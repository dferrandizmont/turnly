import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/format/app_date_format.dart';
import '../../../core/icons/app_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_callout.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/content_app_bar.dart';
import '../../../core/widgets/page_body.dart';
import '../../calendar/application/schedule_controller.dart';
import '../../calendars/domain/calendar.dart';
import '../../calendars/presentation/calendar_dot.dart';
import '../../settings/presentation/settings_widgets.dart';
import '../application/share_link_controller.dart';
import '../data/share_link_api.dart';
import '../domain/share_feed.dart';
import 'share_link_icons.dart';

/// Shares the text of the link with the system sheet. Tests override it.
final shareLinkTextSenderProvider = Provider<Future<void> Function(String)>(
  (ref) =>
      (text) => SharePlus.instance.share(ShareParams(text: text)),
);

/// «Compartir por enlace» (`/ajustes/compartir`, docs/compartir.md): publish
/// a read-only `.ics` link of one calendar, with its QR, and revoke it.
class ShareLinkScreen extends ConsumerStatefulWidget {
  const ShareLinkScreen({super.key});

  @override
  ConsumerState<ShareLinkScreen> createState() => _ShareLinkScreenState();
}

class _ShareLinkScreenState extends ConsumerState<ShareLinkScreen> {
  /// The calendar picked before publishing; the one on screen by default.
  String? _picked;

  @override
  void initState() {
    super.initState();
    // Calendars may have been created or renamed since the last read.
    Future.microtask(
      () => ref.read(shareLinkControllerProvider.notifier).load(force: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    final state = ref.watch(shareLinkControllerProvider);
    final activeId = ref.watch(
      scheduleControllerProvider.select((s) => s.calendarId),
    );

    final Widget body;
    if (!state.available) {
      body = AppCallout(
        titleKey: const ValueKey('share-unavailable'),
        icon: ShareLinkIcons.link,
        title: l10n.shareLinkUnavailableTitle,
        message: l10n.shareLinkUnavailableBody,
      );
    } else if (state.loading) {
      body = const Padding(
        padding: EdgeInsets.all(Sp.x3),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (state.settings.hasToken) {
      body = _Published(state: state);
    } else {
      final picked =
          state.calendars
              .where((c) => c.id == (_picked ?? activeId))
              .firstOrNull ??
          state.calendars.firstOrNull;
      body = _NotPublished(
        state: state,
        picked: picked,
        onPick: (id) => setState(() => _picked = id),
      );
    }

    return Scaffold(
      appBar: ContentAppBar.adaptive(context, title: Text(l10n.shareLinkTitle)),
      body: PageBody(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Sp.page, Sp.s, Sp.page, Sp.x4 * 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.shareLinkIntro,
                style: type.body.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: Sp.l),
              body,
            ],
          ),
        ),
      ),
    );
  }
}

/// Before publishing: which calendar, what goes out, and the button.
class _NotPublished extends ConsumerWidget {
  const _NotPublished({
    required this.state,
    required this.picked,
    required this.onPick,
  });

  final ShareLinkState state;
  final Calendar? picked;
  final ValueChanged<String> onPick;

  Future<void> _publish(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final calendar = picked;
    if (calendar == null) return;
    final ok = await showConfirmDialog(
      context,
      title: l10n.shareLinkPublishConfirmTitle,
      body: l10n.shareLinkPublishConfirmBody,
      confirmLabel: l10n.shareLinkPublishConfirm,
      confirmKey: const ValueKey('share-publish-confirm'),
    );
    if (!ok) return;
    await ref.read(shareLinkControllerProvider.notifier).publish(calendar.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final busy = state.busy != ShareLinkBusy.none;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.calendars.length > 1) ...[
          _CalendarPicker(
            calendars: state.calendars,
            selectedId: picked?.id,
            enabled: !busy,
            onPick: onPick,
          ),
          const SizedBox(height: Sp.section),
        ],
        _Options(state: state),
        const SizedBox(height: Sp.section),
        const _PrivacyCard(),
        const SizedBox(height: Sp.l),
        PrimaryButton(
          key: const ValueKey('share-publish'),
          icon: ShareLinkIcons.link,
          label: busy ? l10n.shareLinkPublishing : l10n.shareLinkPublishButton,
          loading: busy,
          onPressed: picked == null ? null : () => _publish(context, ref),
        ),
        if (state.problem != null) ...[
          const SizedBox(height: Sp.l),
          _ProblemCallout(problem: state.problem!),
        ],
      ],
    );
  }
}

/// With a link: QR, address, copy, share, update, options and revoke.
class _Published extends ConsumerWidget {
  const _Published({required this.state});

  final ShareLinkState state;

  Future<void> _copy(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final done = context.l10n.shareLinkCopied;
    await Clipboard.setData(ClipboardData(text: url));
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(appSnackBar(content: Text(done)));
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ok = await showConfirmDialog(
      context,
      title: l10n.shareLinkRevokeConfirmTitle,
      body: l10n.shareLinkRevokeConfirmBody,
      confirmLabel: l10n.shareLinkRevokeConfirm,
      destructive: true,
      confirmKey: const ValueKey('share-revoke-confirm'),
    );
    if (!ok) return;
    await ref.read(shareLinkControllerProvider.notifier).revoke();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    final controller = ref.read(shareLinkControllerProvider.notifier);
    final url = state.url;
    final busy = state.busy != ShareLinkBusy.none;
    final published = state.settings.publishedAt;
    final format = AppDateFormat.of(context);
    final calendar = state.sharedCalendar;

    final pending = state.settings.revokePending;
    final String status;
    if (pending && state.busy != ShareLinkBusy.revoking) {
      status = l10n.shareLinkRevokePending;
    } else if (state.busy == ShareLinkBusy.publishing) {
      status = l10n.shareLinkPublishing;
    } else if (state.busy == ShareLinkBusy.revoking) {
      status = l10n.shareLinkRevoking;
    } else if (state.waiting) {
      status = l10n.shareLinkWaiting;
    } else if (published == null) {
      status = l10n.shareLinkNotPublished;
    } else {
      final local = published.toLocal();
      status = l10n.shareLinkLastPublished(
        '${format.dayMonthYear(local)}, ${format.time(local)}',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (url != null && published != null && !pending) ...[
          _QrCard(url: url.toString()),
          const SizedBox(height: Sp.l),
          _SectionLabel(l10n.shareLinkLinkLabel),
          AppCard(
            child: SelectableText(
              url.toString(),
              key: const ValueKey('share-url'),
              style: type.body,
            ),
          ),
          const SizedBox(height: Sp.m),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  key: const ValueKey('share-copy'),
                  icon: AppIcons.copy,
                  label: l10n.shareLinkCopy,
                  onPressed: () => _copy(context, url.toString()),
                ),
              ),
              const SizedBox(width: Sp.m),
              Expanded(
                child: SecondaryButton(
                  key: const ValueKey('share-share'),
                  icon: AppIcons.share,
                  label: l10n.shareLinkShare,
                  onPressed: () => ref.read(shareLinkTextSenderProvider)(
                    l10n.shareLinkShareText(url.toString()),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.l),
        ],
        Semantics(
          liveRegion: true,
          child: Text(
            status,
            key: const ValueKey('share-status'),
            style: type.meta.copyWith(color: colors.textSecondary),
          ),
        ),
        if (calendar != null) ...[
          const SizedBox(height: Sp.xs),
          Text(
            l10n.shareLinkSharedCalendar(calendar.name),
            key: const ValueKey('share-calendar'),
            style: type.meta.copyWith(color: colors.textMuted),
          ),
        ],
        const SizedBox(height: Sp.m),
        SecondaryButton(
          key: const ValueKey('share-refresh'),
          icon: ShareLinkIcons.refresh,
          label: l10n.shareLinkRefresh,
          onPressed: busy || pending || state.calendarMissing
              ? null
              : controller.refreshNow,
        ),
        if (state.problem != null) ...[
          const SizedBox(height: Sp.l),
          _ProblemCallout(problem: state.problem!),
        ],
        if (state.calendarMissing) ...[
          const SizedBox(height: Sp.l),
          AppCallout(
            titleKey: const ValueKey('share-calendar-missing'),
            icon: AppIcons.error,
            title: l10n.shareLinkCalendarMissing,
          ),
        ],
        if (state.calendars.length > 1 || state.calendarMissing) ...[
          const SizedBox(height: Sp.section),
          _CalendarPicker(
            calendars: state.calendars,
            selectedId: calendar?.id,
            enabled: !busy,
            onPick: controller.setCalendar,
          ),
        ],
        const SizedBox(height: Sp.section),
        _Options(state: state),
        const SizedBox(height: Sp.section),
        const _HowCard(),
        const SizedBox(height: Sp.l),
        const _PrivacyCard(),
        const SizedBox(height: Sp.section),
        SecondaryButton(
          key: const ValueKey('share-revoke'),
          icon: ShareLinkIcons.revoke,
          label: l10n.shareLinkRevoke,
          // A pending revocation was already confirmed: retry it directly.
          onPressed: busy
              ? null
              : pending
              ? controller.revoke
              : () => _revoke(context, ref),
        ),
      ],
    );
  }
}

/// Side of the QR (dp): the modules of a ~70-character URL stay big enough
/// to scan from another phone held at a normal distance.
const double _qrSide = 220;

/// The QR on a light panel whatever the theme: scanners read dark modules on
/// a light ground best. The light palette's own tokens, never loose colours.
class _QrCard extends StatelessWidget {
  const _QrCard({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    const light = AppColors.light;
    return Center(
      child: Semantics(
        image: true,
        label: context.l10n.shareLinkQrLabel,
        excludeSemantics: true,
        child: DecoratedBox(
          key: const ValueKey('share-qr'),
          decoration: BoxDecoration(
            color: light.surface,
            borderRadius: BorderRadius.circular(Rad.row),
            border: Border.all(color: context.colors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(Sp.m),
            child: QrImageView(
              data: url,
              size: _qrSide,
              padding: EdgeInsets.zero,
              backgroundColor: light.surface,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
              eyeStyle: QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: light.textPrimary,
              ),
              dataModuleStyle: QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: light.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Options extends ConsumerWidget {
  const _Options({required this.state});

  final ShareLinkState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final controller = ref.read(shareLinkControllerProvider.notifier);
    final options = state.settings.options;
    final busy = state.busy != ShareLinkBusy.none;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(l10n.shareLinkOptionsLabel),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              SettingsSwitchRow(
                key: const ValueKey('share-include-rest'),
                switchKey: const ValueKey('share-include-rest-switch'),
                icon: ShareLinkIcons.rest,
                title: l10n.shareLinkIncludeRest,
                subtitle: l10n.shareLinkIncludeRestHelp,
                value: options.includeRest,
                onChanged: busy
                    ? (_) {}
                    : (v) => controller.setOptions(
                        ShareFeedOptions(
                          includeRest: v,
                          includeAbsences: options.includeAbsences,
                        ),
                      ),
              ),
              Divider(height: 1, thickness: 1, color: context.colors.border),
              SettingsSwitchRow(
                key: const ValueKey('share-include-absences'),
                switchKey: const ValueKey('share-include-absences-switch'),
                icon: ShareLinkIcons.absence,
                title: l10n.shareLinkIncludeAbsences,
                subtitle: l10n.shareLinkIncludeAbsencesHelp,
                value: options.includeAbsences,
                onChanged: busy
                    ? (_) {}
                    : (v) => controller.setOptions(
                        ShareFeedOptions(
                          includeRest: options.includeRest,
                          includeAbsences: v,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CalendarPicker extends StatelessWidget {
  const _CalendarPicker({
    required this.calendars,
    required this.selectedId,
    required this.enabled,
    required this.onPick,
  });

  final List<Calendar> calendars;
  final String? selectedId;
  final bool enabled;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(context.l10n.shareLinkCalendarLabel),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (i, c) in calendars.indexed) ...[
                if (i > 0)
                  Divider(height: 1, thickness: 1, color: colors.border),
                Semantics(
                  button: true,
                  selected: c.id == selectedId,
                  excludeSemantics: true,
                  label: c.name,
                  child: InkWell(
                    key: ValueKey('share-calendar-${c.id}'),
                    onTap: enabled ? () => onPick(c.id) : null,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: Sp.touch),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Sp.l,
                          vertical: Sp.m,
                        ),
                        child: Row(
                          children: [
                            CalendarDot(colorValue: c.colorValue),
                            const SizedBox(width: Sp.m),
                            Expanded(
                              child: Text(
                                c.name,
                                style: type.body.copyWith(
                                  fontWeight: c.id == selectedId
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                              ),
                            ),
                            if (c.id == selectedId)
                              Icon(
                                AppIcons.check,
                                size: IconSize.button,
                                color: colors.accent,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _InfoCard(
      key: const ValueKey('share-privacy'),
      icon: ShareLinkIcons.privacy,
      title: l10n.shareLinkPrivacyTitle,
      body: l10n.shareLinkPrivacyBody,
    );
  }
}

class _HowCard extends StatelessWidget {
  const _HowCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _InfoCard(
      key: const ValueKey('share-how'),
      icon: AppIcons.calendar,
      title: l10n.shareLinkHowTitle,
      body: l10n.shareLinkHowBody,
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return AppCard.tinted(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: IconSize.button, color: colors.textSecondary),
          const SizedBox(width: Sp.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: type.bodyStrong),
                ),
                const SizedBox(height: Sp.xs),
                Text(
                  body,
                  style: type.body.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProblemCallout extends StatelessWidget {
  const _ProblemCallout({required this.problem});

  final ShareLinkFailure problem;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      liveRegion: true,
      child: AppCallout(
        titleKey: const ValueKey('share-problem'),
        icon: AppIcons.error,
        title: switch (problem) {
          ShareLinkFailure.network => l10n.shareLinkProblemNetwork,
          ShareLinkFailure.rateLimited => l10n.shareLinkProblemRateLimited,
          ShareLinkFailure.tooLarge => l10n.shareLinkProblemTooLarge,
          ShareLinkFailure.rejected => l10n.shareLinkProblemRejected,
          ShareLinkFailure.revoked => l10n.shareLinkProblemRevoked,
          ShareLinkFailure.server => l10n.shareLinkProblemServer,
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.xs, 0, Sp.xs, Sp.s),
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          style: context.type.label.copyWith(color: context.colors.textMuted),
        ),
      ),
    );
  }
}
