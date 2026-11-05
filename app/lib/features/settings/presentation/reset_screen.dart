import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/app_date_format.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/router.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/content_app_bar.dart';
import '../../../core/widgets/page_body.dart';
import '../../backup/domain/backup_store.dart';
import '../application/reset_providers.dart';
import '../application/reset_everything.dart';
import '../application/reset_notice.dart';

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

  String _date(BackupEntry copy) {
    final format = AppDateFormat.of(context);
    final date = copy.modifiedAt.toLocal();
    return '${format.dayMonthYear(date)} · ${format.time(date)}';
  }

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
            body: context.l10n.resetConfirmBody(_date(copy)),
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
      l10n.resetCalendars,
      l10n.resetNotes,
      l10n.resetAbsences,
      l10n.resetHolidays,
      l10n.resetSwaps,
      l10n.resetAlarms,
      l10n.resetWidget,
      l10n.resetDnd,
      l10n.resetCalendarEvents,
      l10n.resetShareLink,
      l10n.resetFolderBackup,
      l10n.resetPreferences,
    ];
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
                  Text(l10n.resetIntro, style: context.type.bodyStrong),
                  const SizedBox(height: Sp.m),
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Sp.s),
                      child: Text('• $item', style: context.type.body),
                    ),
                  const SizedBox(height: Sp.m),
                  Text(l10n.resetKeepLanguage, style: context.type.bodyStrong),
                  const SizedBox(height: Sp.section),
                  if (_savingCopy || _deleting || copy != null)
                    Text(
                      _deleting
                          ? l10n.resetDeleting
                          : _savingCopy
                          ? l10n.resetBackupPreparing
                          : l10n.resetBackupSaved(copy!.id),
                      style: context.type.body,
                    ),
                  if (_busy) const Center(child: ButtonSpinner()),
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
