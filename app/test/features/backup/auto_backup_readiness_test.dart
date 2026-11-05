import 'dart:io';

import 'package:cuadrante/core/providers.dart';
import 'package:cuadrante/features/backup/application/backup_providers.dart';
import 'package:cuadrante/features/backup/application/backup_service.dart';
import 'package:cuadrante/features/backup/domain/auto_backup_policy.dart';
import 'package:cuadrante/features/onboarding/application/onboarding_providers.dart';
import 'package:cuadrante/features/onboarding/data/onboarding_repository.dart';
import 'package:cuadrante/features/settings/data/reset_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final afterReset in [false, true]) {
    test(
      'no automatic files before first use finishes (reset=$afterReset)',
      () async {
        final now = DateTime(2026, 11, 4, 12);
        final storage = await TestStorage.open(now: now, demo: false);
        addTearDown(storage.close);
        if (afterReset) {
          await ResetRepository(storage.database, now: () => now).clear();
        }
        final directory = makeTempDir('backup-readiness');
        final container = ProviderContainer(
          overrides: [
            ...storage.overrides,
            clockProvider.overrideWithValue(() => now),
            initialOnboardingProvider.overrideWithValue(
              // Simulate bootstrap's stale pre-reset status, too.
              OnboardingStatus(needed: !afterReset),
            ),
            backupDirectoryProvider.overrideWith((ref) async => directory),
            backupTaskRunnerProvider.overrideWithValue(runOnThisIsolate),
            autoBackupPolicyProvider.overrideWithValue(
              const AutoBackupPolicy(
                debounce: Duration(milliseconds: 10),
                minInterval: Duration.zero,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        final subscription = container.listen(
          autoBackupRunnerProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        final runner = container.read(autoBackupRunnerProvider);
        expect(await container.read(autoBackupReadyProvider.future), isFalse);
        runner.noteChange();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(directory.listSync().whereType<File>(), isEmpty);

        await OnboardingRepository(storage.database).markDone();
        final tools = await container.read(backupToolsProvider.future);
        for (var attempt = 0; attempt < 100; attempt++) {
          if ((await tools.autoStore.list()).isNotEmpty) break;
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        final copies = await tools.autoStore.list();
        expect(copies, hasLength(1));
        await tools.service.decodeFile(
          await tools.autoStore.read(copies.single),
        );
      },
    );
  }
}
