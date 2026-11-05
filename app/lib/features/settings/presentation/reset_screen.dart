import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/app_date_format.dart';
import '../../../core/icons/app_icons.dart';
import '../../../core/icons/reset_icons.dart';
import '../../../core/icons/settings_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../core/router.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/content_app_bar.dart';
import '../../../core/widgets/page_body.dart';
import '../../backup/domain/backup_store.dart';
import '../../backup/presentation/backup_format.dart';
import '../application/reset_providers.dart';
import '../application/reset_everything.dart';
import '../application/reset_notice.dart';
import 'settings_widgets.dart';

class ResetScreen extends ConsumerStatefulWidget {
  const ResetScreen({super.key});
  @override
  ConsumerState<ResetScreen> createState() => _ResetScreenState();
}

class _ResetScreenState extends ConsumerState<ResetScreen> {
  BackupEntry? _copy;
  bool _busy = true;
  bool _savingCopy = true;
  bool _deleting = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    Future.microtask(_prepare);
  }

  Future<void> _prepare() async {
    try {
      final copy = await ref.read(resetEverythingProvider).prepareBackup();
      if (mounted) setState(() => _copy = copy);
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.resetBackupFailed);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _savingCopy = false;
        });
      }
    }
  }

  /// The copy's moment as the pieces the sentences need (de hoy, del 3 de
  /// noviembre), in the clock and the 12/24 h format of the app.
  BackupWhenParts _when(BackupEntry copy) => backupWhenParts(
    context.l10n,
    copy.modifiedAt,
    ref.read(clockProvider)(),
    hour12: AppDateFormat.of(context).hour12,
  );

  Future<void> _share() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(shareResetBackupProvider)(_copy!);
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.resetShareFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _confirmBody(BackupEntry copy) {
    final parts = _when(copy);
    return context.l10n.resetConfirmBody(parts.day, parts.time, parts.date);
  }

  Future<void> _reset() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _savingCopy = true;
      _error = null;
    });
    try {
      final operation = ref.read(resetEverythingProvider);
      final done = await operation.resetEverything(
        preparedBackup: _copy,
        onDeleting: () {
          if (mounted) setState(() => _deleting = true);
        },
        confirm: (copy) async {
          if (!mounted) return false;
          setState(() {
            _copy = copy;
            _savingCopy = false;
          });
          return showConfirmDialog(
            context,
            title: context.l10n.resetConfirmTitle,
            body: _confirmBody(copy),
            confirmLabel: context.l10n.resetDelete,
            destructive: true,
            scrollable: true,
          );
        },
      );
      if (done && mounted) {
        ref
            .read(resetCleanupNoticeProvider.notifier)
            .show(operation.cleanupFailures);
        context.go(AppRoutes.onboarding);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ResetBackupFailure
              ? context.l10n.resetBackupFailed
              : context.l10n.resetFailed,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _deleting = false;
          _savingCopy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final copy = _copy;
    final items = [
      (AppIcons.calendar, l10n.resetCalendars),
      (AppIcons.note, l10n.resetNotes),
      (ResetIcons.absences, l10n.resetAbsences),
      (SettingsIcons.holidays, l10n.resetHolidays),
      (ResetIcons.swaps, l10n.resetSwaps),
      (SettingsIcons.alarms, l10n.resetAlarms),
      (SettingsIcons.widget, l10n.resetWidget),
      (AppIcons.silence, l10n.resetDnd),
      (AppIcons.deviceEvents, l10n.resetCalendarEvents),
      (ResetIcons.shareLink, l10n.resetShareLink),
      (ResetIcons.folder, l10n.resetFolderBackup),
      (ResetIcons.preferences, l10n.resetPreferences),
    ];
    final String? status;
    if (_deleting) {
      status = l10n.resetDeleting;
    } else if (_savingCopy) {
      status = l10n.resetBackupPreparing;
    } else if (copy != null) {
      ref.watch(clockProvider);
      final parts = _when(copy);
      status = l10n.resetBackupSavedAt(parts.day, parts.time, parts.date);
    } else {
      status = null;
    }
    return PopScope(
      canPop: !_deleting,
      child: AbsorbPointer(
        key: const ValueKey('reset-barrier'),
        absorbing: _deleting,
        child: Scaffold(
          appBar: ContentAppBar.adaptive(context, title: Text(l10n.resetTitle)),
          body: PageBody(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Sp.page),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SettingsSection(
                    key: const ValueKey('reset-items'),
                    title: l10n.resetListTitle,
                    children: [
                      for (final (icon, text) in items)
                        _ResetItemRow(icon: icon, text: text),
                    ],
                  ),
                  const SizedBox(height: Sp.m),
                  _KeepNote(text: l10n.resetKeepLanguage),
                  const SizedBox(height: Sp.m),
                  if (status != null)
                    Text(
                      status,
                      key: const ValueKey('reset-status'),
                      style: context.type.body.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  if (_busy) ...[
                    const SizedBox(height: Sp.m),
                    const Center(child: ButtonSpinner()),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: Sp.m),
                    Text(
                      _error!,
                      key: const ValueKey('reset-error'),
                      style: context.type.body.copyWith(color: colors.danger),
                    ),
                  ],
                  const SizedBox(height: Sp.m),
                  if (copy != null)
                    SecondaryButton(
                      key: const ValueKey('reset-share'),
                      label: l10n.resetShare,
                      onPressed: _busy ? null : _share,
                    ),
                  if (copy == null && !_busy)
                    SecondaryButton(
                      label: l10n.retry,
                      onPressed: () {
                        setState(() {
                          _busy = true;
                          _savingCopy = true;
                          _error = null;
                        });
                        _prepare();
                      },
                    ),
                  const SizedBox(height: Sp.section),
                  FilledButton(
                    key: const ValueKey('reset-delete'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.dangerContainer,
                      foregroundColor: colors.danger,
                    ),
                    onPressed: _busy || copy == null ? null : _reset,
                    child: Text(l10n.resetDelete),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One thing the reset deletes: a neutral icon disc and its sentence on the
/// `surface` card of [SettingsSection] (the hairline indent matches the disc).
/// The icon is quiet on purpose: what warns is the button.
class _ResetItemRow extends StatelessWidget {
  const _ResetItemRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sp.l, vertical: Sp.m),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Container(
              width: Disc.m,
              height: Disc.m,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: IconSize.button,
                color: colors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: Sp.m),
          Expanded(child: Text(text, style: context.type.body)),
        ],
      ),
    );
  }
}

/// What stays after the reset: a tinted note with the accent disc of
/// [AppCallout] (a shield) and no heading, so it reads as a note, not a title.
class _KeepNote extends StatelessWidget {
  const _KeepNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tone = colors.accentTone;
    final disc = ExcludeSemantics(
      child: Container(
        width: Disc.m,
        height: Disc.m,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: tone.bg, shape: BoxShape.circle),
        child: Icon(
          SettingsIcons.backup,
          size: IconSize.button,
          fill: 1,
          color: tone.fg,
        ),
      ),
    );
    final message = Text(
      text,
      key: const ValueKey('reset-keep-note'),
      style: context.type.body.copyWith(color: colors.textSecondary),
    );
    return AppCard.tinted(
      child: context.largeText
          // The text gets the card's whole width at large text sizes.
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                disc,
                const SizedBox(height: Sp.m),
                message,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                disc,
                const SizedBox(width: Sp.m),
                Expanded(child: message),
              ],
            ),
    );
  }
}
