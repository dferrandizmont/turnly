import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/diagnostics/crash_reporting.dart' show redactError;
import '../../../core/format/app_date_format.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_callout.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../settings/presentation/settings_widgets.dart';
import '../application/folder_backup_engine.dart';
import '../application/folder_backup_providers.dart';
import '../domain/folder_backup.dart';
import '../domain/backup_warnings.dart';
import '../domain/restore_summary.dart';
import 'backup_format.dart';
import 'verification_result_card.dart';

// Glyphs of the folder block (SF-style on Apple, Material Symbols rounded
// elsewhere), kept here so the shared icon files stay untouched.
IconData _icon(IconData apple, IconData material) =>
    BackupIcons.apple ? apple : material;

IconData get _folderIcon =>
    _icon(CupertinoIcons.folder, Symbols.folder_rounded);
IconData get _uploadIcon =>
    _icon(CupertinoIcons.arrow_up_doc, Symbols.drive_folder_upload_rounded);
IconData get _stopIcon =>
    _icon(CupertinoIcons.xmark_circle, Symbols.folder_off_rounded);

/// "Copia automática en una carpeta" on the backup screen (P10,
/// docs/copia-de-seguridad.md, section 11): the folder the user picked in the
/// system picker, when the last copy went there (or why it did not), and the
/// actions: choose or change the folder, copy now, test the newest copy in
/// the folder, stop. A widget of its own, hooked into `BackupScreen` with one
/// line; nothing at all where there is no folder copy (iOS for now).
class FolderBackupSection extends ConsumerStatefulWidget {
  const FolderBackupSection({super.key});

  @override
  ConsumerState<FolderBackupSection> createState() =>
      _FolderBackupSectionState();
}

class _FolderBackupSectionState extends ConsumerState<FolderBackupSection> {
  bool _busy = false;

  /// "Probar la copia de la carpeta": [_checking] while it runs, then
  /// [_checked] with [_result] (whose `null` means "no copy to test").
  bool _checking = false;
  bool _checked = false;
  RestoreVerification? _result;

  FolderBackupController get _controller =>
      ref.read(folderBackupControllerProvider.notifier);

  void _snack(String message) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(appSnackBar(content: Text(message)));
  }

  void _report(Object error, StackTrace stack) {
    ref
        .read(crashReporterProvider)
        .record(redactError(error), stack, fatal: false);
  }

  /// Runs [work] with the block busy (one action at a time).
  Future<void> _run(Future<void> Function() work) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await work();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _tellOutcome(FolderBackupOutcome outcome) {
    if (!mounted) return;
    if (outcome.kind == FolderBackupOutcomeKind.saved) {
      final skipped = skippedAttachmentCount(outcome.warnings);
      _snack(
        skipped > 0
            ? context.l10n.backupWarnCopySkipped(skipped)
            : context.l10n.autoBackupFolderCopyDone,
      );
    } else if (outcome.kind == FolderBackupOutcomeKind.skipped) {
      // Another copy held the folder for too long.
      _snack(folderProblemMessage(context.l10n, FolderProblem.failed));
    } else if (outcome.problem case final problem?) {
      _snack(folderProblemMessage(context.l10n, problem));
    }
  }

  Future<void> _choose() => _run(() async {
    final l10n = context.l10n;
    try {
      final outcome = await _controller.choose();
      if (outcome != null) _tellOutcome(outcome);
      if (mounted) setState(() => _checked = false);
    } on FolderBackupException {
      if (mounted) _snack(l10n.autoBackupFolderPickFailed);
    } catch (error, stack) {
      _report(error, stack);
      if (mounted) _snack(l10n.autoBackupFolderPickFailed);
    }
  });

  Future<void> _backupNow() => _run(() async {
    try {
      _tellOutcome(await _controller.backupNow());
    } catch (error, stack) {
      _report(error, stack);
      if (mounted) {
        _snack(folderProblemMessage(context.l10n, FolderProblem.failed));
      }
    }
  });

  Future<void> _stop() => _run(() async {
    final l10n = context.l10n;
    try {
      await _controller.stop();
      if (mounted) {
        setState(() => _checked = false);
        _snack(l10n.autoBackupFolderStopped);
      }
    } catch (error, stack) {
      _report(error, stack);
      if (mounted) _snack(l10n.settingsSaveFailed);
    }
  });

  Future<void> _verify() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _checked = false;
    });
    RestoreVerification? result;
    try {
      result = await _controller.verifyLatest();
    } catch (error, stack) {
      _report(error, stack);
      result = VerificationFailed(error);
    }
    if (!mounted) return;
    setState(() {
      _checking = false;
      _checked = true;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Nothing is loaded or asked where there is no folder copy.
    if (!ref.watch(folderBackupSupportedProvider)) {
      return const SizedBox.shrink();
    }
    final view = ref.watch(folderBackupControllerProvider).value;
    if (view == null || !view.supported) return const SizedBox.shrink();
    final l10n = context.l10n;
    final state = view.state;
    final problem = view.problem;

    // Its own space above, so the screen hooks it in with one line.
    return Padding(
      key: const ValueKey('folder-backup'),
      padding: const EdgeInsets.only(top: Sp.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsSection(
            title: l10n.autoBackupFolderTitle,
            children: state.configured
                ? _configuredRows(context, view)
                : _emptyRows(context),
          ),
          if (problem != null) ...[
            const SizedBox(height: Sp.card),
            _ProblemCallout(
              problem: problem,
              at: state.lastProblemAt,
              onChoose: _busy ? null : _choose,
              onRetry: _busy ? null : _backupNow,
            ),
          ],
          if (_checking) ...[
            const SizedBox(height: Sp.m),
            AppCallout(
              key: const ValueKey('folder-backup-verify-running'),
              icon: BackupIcons.verify,
              title: l10n.backupUiVerifyRunning,
            ),
          ] else if (_checked) ...[
            const SizedBox(height: Sp.m),
            KeyedSubtree(
              key: const ValueKey('folder-backup-verify-result'),
              child: VerificationResultCard(result: _result),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _emptyRows(BuildContext context) {
    final l10n = context.l10n;
    return [
      _Explanation(
        key: const ValueKey('folder-backup-intro'),
        lines: [l10n.autoBackupFolderIntro, l10n.autoBackupFolderPrivacy],
      ),
      SettingsRow(
        key: const ValueKey('folder-backup-choose'),
        icon: _folderIcon,
        title: l10n.autoBackupFolderChoose,
        subtitle: l10n.autoBackupFolderChooseSubtitle,
        onTap: _busy ? null : _choose,
      ),
    ];
  }

  List<Widget> _configuredRows(BuildContext context, FolderBackupView view) {
    final l10n = context.l10n;
    final state = view.state;
    final now = ref.watch(clockProvider)();
    final hour12 = AppDateFormat.of(context).hour12;
    final last = state.lastSuccessAt;
    final name = state.name;
    return [
      SettingsRow(
        key: const ValueKey('folder-backup-folder'),
        icon: _folderIcon,
        title: name == null || name.isEmpty
            ? l10n.autoBackupFolderUnnamed
            : name,
        subtitle: l10n.autoBackupFolderChange,
        onTap: _busy ? null : _choose,
      ),
      _Explanation(
        key: const ValueKey('folder-backup-status'),
        strong: last == null
            ? l10n.autoBackupFolderNone
            : l10n.autoBackupFolderLast(
                backupWhen(l10n, last, now, hour12: hour12),
              ),
        lines: [l10n.autoBackupFolderSchedule, l10n.autoBackupFolderPrivacy],
      ),
      SettingsRow(
        key: const ValueKey('folder-backup-now'),
        icon: _uploadIcon,
        title: l10n.autoBackupFolderCopyNow,
        onTap: _busy ? null : _backupNow,
        trailing: _busy
            ? const SizedBox.square(
                dimension: IconSize.base,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
      ),
      if (state.lastFileName != null)
        SettingsRow(
          key: const ValueKey('folder-backup-verify'),
          icon: BackupIcons.verify,
          title: l10n.autoBackupFolderVerify,
          subtitle: l10n.autoBackupFolderVerifySubtitle,
          onTap: _checking || _busy ? null : _verify,
        ),
      SettingsRow(
        key: const ValueKey('folder-backup-stop'),
        icon: _stopIcon,
        title: l10n.autoBackupFolderStop,
        subtitle: l10n.autoBackupFolderStopSubtitle,
        onTap: _busy ? null : _stop,
      ),
    ];
  }
}

/// Text inside the card: an optional strong line and muted lines below.
class _Explanation extends StatelessWidget {
  const _Explanation({super.key, this.strong, required this.lines});

  final String? strong;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Padding(
      padding: const EdgeInsets.all(Sp.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (strong != null) ...[
            Text(strong!, style: type.bodyStrong),
            const SizedBox(height: Sp.xs),
          ],
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0) const SizedBox(height: Sp.s),
            Text(
              lines[i],
              style: type.meta.copyWith(color: colors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// The red warning: what went wrong, when, and the action that fixes it
/// (choose the folder again, or try again).
class _ProblemCallout extends ConsumerWidget {
  const _ProblemCallout({
    required this.problem,
    required this.at,
    required this.onChoose,
    required this.onRetry,
  });

  final FolderProblem problem;
  final DateTime? at;
  final VoidCallback? onChoose;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;
    final now = ref.watch(clockProvider)();
    final when = at == null
        ? null
        : l10n.autoBackupFolderFailedWhen(
            backupWhen(
              l10n,
              at!,
              now,
              hour12: AppDateFormat.of(context).hour12,
            ),
          );
    final reason = folderProblemMessage(l10n, problem);
    return AppCallout(
      key: const ValueKey('folder-backup-problem'),
      icon: BackupIcons.warning,
      tone: TonePair(colors.dangerContainer, colors.danger),
      title: l10n.autoBackupFolderFailedTitle,
      message: when == null ? reason : '$reason $when',
      primaryKey: const ValueKey('folder-backup-problem-action'),
      primaryLabel: problem.needsNewFolder
          ? l10n.autoBackupFolderChooseAgain
          : l10n.backupUiRetry,
      onPrimary: problem.needsNewFolder ? onChoose : onRetry,
    );
  }
}

/// Why the folder copy does not work, in words the user can act on.
String folderProblemMessage(AppLocalizations l10n, FolderProblem problem) =>
    switch (problem) {
      FolderProblem.revoked => l10n.autoBackupFolderErrRevoked,
      FolderProblem.missing => l10n.autoBackupFolderErrMissing,
      FolderProblem.unwritable => l10n.autoBackupFolderErrUnwritable,
      FolderProblem.noSpace => l10n.autoBackupFolderErrNoSpace,
      FolderProblem.tooLarge => l10n.autoBackupFolderErrTooLarge,
      FolderProblem.damaged => l10n.autoBackupFolderErrDamaged,
      FolderProblem.failed ||
      FolderProblem.unsupported => l10n.autoBackupFolderErrFailed,
    };
