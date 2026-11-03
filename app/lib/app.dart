import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/app_locales.dart';
import 'core/l10n/app_material_localizations.dart';
import 'core/l10n/catalog_texts.dart';
import 'core/l10n/l10n.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_snack_bar.dart';
import 'features/alarms/presentation/alarms_host.dart';
import 'features/backup/presentation/backup_host.dart';
import 'features/calendar_export/presentation/calendar_sync_host.dart';
import 'features/dnd/application/dnd_providers.dart';
import 'features/device_events/presentation/device_events_host.dart';
import 'features/settings/application/preferences_controller.dart';
import 'features/settings/presentation/formats_host.dart';
import 'features/share_link/presentation/share_link_host.dart';
import 'features/widget/presentation/widget_host.dart';

class CuadranteApp extends ConsumerWidget {
  const CuadranteApp({super.key});

  /// Spanish plus every language with an ARB file.
  static List<Locale> get supportedLocales => appSupportedLocales;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(preferencesProvider.select((p) => p.themeMode));
    // Ajustes › Apariencia › Color de acento and Tamaño del turno en el mes.
    final accent = ref.watch(preferencesProvider.select((p) => p.accent));
    final cellSize = ref.watch(
      preferencesProvider.select((p) => p.cellTextSize),
    );
    // Ajustes › Idioma: a language forces its locale; «Sistema» (null)
    // follows the phone through [resolveAppLocale], Spanish when the phone's
    // language is not one the app has.
    final forced = ref.watch(
      preferencesProvider.select((p) => p.language.locale),
    );
    // The silence windows of the shift (P13): the runner keeps the device in
    // step with the schedule, the settings and the clock. It shows nothing.
    ref.watch(dndSyncRunnerProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appName,
      routerConfig: router,
      theme: AppTheme.light(accent: accent, cellSize: cellSize),
      darkTheme: AppTheme.dark(accent: accent, cellSize: cellSize),
      themeMode: themeMode,
      locale: forced != null && supportedLocales.contains(forced)
          ? forced
          : null,
      supportedLocales: supportedLocales,
      localeListResolutionCallback: (device, supported) =>
          resolveAppLocale(device, supported),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        AppMaterialLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      builder: (context, child) => FormatsHost(
        child: CatalogTextsHost(
          child: BackupHost(
            child: AlarmsHost(
              child: CalendarSyncHost(
                child: DeviceEventsHost(
                  child: WidgetHost(
                    child: ShareLinkHost(
                      child: AnnotatedRegion<SystemUiOverlayStyle>(
                        value: AppTheme.overlayStyle(
                          Theme.of(context).brightness,
                        ),
                        child: AppSnackBarLayout(
                          child: child ?? const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
