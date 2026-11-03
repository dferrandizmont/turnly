import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/app_formats.dart';
import '../../../../core/format/money.dart';
import '../../../../core/icons/settings_icons.dart';
import '../../../../core/l10n/app_locales.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/widgets/choice_sheet.dart';
import '../../../holidays/presentation/holidays_settings_row.dart';
import '../../application/preferences_controller.dart';
import '../../domain/preferences.dart';
import '../appearance_extras_rows.dart';
import '../appearance_style_rows.dart';
import '../currency_sheet.dart';
import '../settings_widgets.dart';

/// «Apariencia» (design 6A): theme, language, time format, first day of the
/// week, week numbers, currency, and country and holidays. The rows of
/// another feature (accent colour, cell size) are one more line in
/// `children`, as the holidays row is.
class AppearanceSection extends ConsumerWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final preferences = ref.watch(preferencesProvider);
    final controller = ref.read(preferencesProvider.notifier);

    // «Sistema» says which theme it gives now; reading it from MediaQuery
    // rebuilds this section when the phone switches (H-T15-5).
    final systemDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;

    String themeName(ThemeMode mode) => switch (mode) {
      ThemeMode.system =>
        systemDark
            ? l10n.settingsThemeSystemDark
            : l10n.settingsThemeSystemLight,
      ThemeMode.light => l10n.settingsThemeLight,
      ThemeMode.dark => l10n.settingsThemeDark,
    };
    String weekStartName(int weekStart) => weekStart == WeekStart.sunday
        ? l10n.settingsWeekStartSunday
        : l10n.settingsWeekStartMonday;

    // Each language is named in its own language; «Sistema» says which one
    // the phone gives now (the app's current locale while it follows it).
    String endonym(String code) => switch (code) {
      'ca' => l10n.languageNameCa,
      'gl' => l10n.languageNameGl,
      'eu' => l10n.languageNameEu,
      'en' => l10n.languageNameEn,
      _ => l10n.languageNameEs,
    };
    final systemLanguage = resolveAppLocale(
      WidgetsBinding.instance.platformDispatcher.locales,
    ).languageCode;
    String languageName(AppLanguage language) => language == AppLanguage.system
        ? l10n.settingsLanguageSystem(endonym(systemLanguage))
        : endonym(language.name);
    final languageCodes = {for (final l in appSupportedLocales) l.languageCode};
    final languages = [
      for (final language in AppLanguage.values)
        if (language == AppLanguage.system ||
            languageCodes.contains(language.name))
          language,
    ];

    // «Automático» says which clock it gives now: the phone's 24 h switch,
    // else the clock of the region (the same rule as the rest of the app).
    final formats = AppFormats.maybeOf(context);
    final localeName =
        formats?.localeName ?? Localizations.localeOf(context).toString();
    final autoHour12 = TimeFormatPreference.auto.resolve(
      phoneUses24Hour: MediaQuery.alwaysUse24HourFormatOf(context),
      localeUses12Hour: localeUses12HourClock(localeName),
    );
    String timeFormatName(TimeFormatPreference option) => switch (option) {
      TimeFormatPreference.auto => l10n.settingsTimeFormatAuto(
        autoHour12
            ? l10n.settingsTimeFormatShort12
            : l10n.settingsTimeFormatShort24,
      ),
      TimeFormatPreference.h24 => l10n.settingsTimeFormat24,
      TimeFormatPreference.h12 => l10n.settingsTimeFormat12,
    };
    String currencyName(String code) {
      final symbol = currencySymbol(localeName, code);
      return symbol == code ? code : '$code ($symbol)';
    }

    return SettingsSection(
      title: l10n.settingsSectionAppearance,
      children: [
        SettingsRow(
          key: const ValueKey('settings-theme'),
          icon: SettingsIcons.theme,
          title: l10n.settingsThemeTitle,
          value: themeName(preferences.themeMode),
          onTap: () async {
            final picked = await showChoiceSheet<ThemeMode>(
              context: context,
              title: l10n.settingsThemeTitle,
              selected: preferences.themeMode,
              options: [
                for (final mode in ThemeMode.values)
                  ChoiceOption(mode, themeName(mode)),
              ],
            );
            if (picked != null && context.mounted) {
              await saveSetting(context, () => controller.setThemeMode(picked));
            }
          },
        ),
        // B10 «Color de acento» and the cell size: right below Tema.
        ...appearanceStyleRows,
        // UX · Extras visuales: note in the month, paint sound, prepared
        // colours and the background picture.
        ...appearanceExtraRows,
        SettingsRow(
          key: const ValueKey('settings-language'),
          icon: SettingsIcons.language,
          title: l10n.settingsLanguageTitle,
          value: languageName(preferences.language),
          onTap: () async {
            final picked = await showChoiceSheet<AppLanguage>(
              context: context,
              title: l10n.settingsLanguageTitle,
              selected: preferences.language,
              options: [
                for (final language in languages)
                  ChoiceOption(language, languageName(language)),
              ],
            );
            if (picked != null && context.mounted) {
              await saveSetting(context, () => controller.setLanguage(picked));
            }
          },
        ),
        SettingsRow(
          key: const ValueKey('settings-time-format'),
          icon: SettingsIcons.timeFormat,
          title: l10n.settingsTimeFormatTitle,
          value: timeFormatName(preferences.timeFormat),
          onTap: () async {
            final picked = await showChoiceSheet<TimeFormatPreference>(
              context: context,
              title: l10n.settingsTimeFormatTitle,
              selected: preferences.timeFormat,
              options: [
                for (final option in TimeFormatPreference.values)
                  ChoiceOption(option, timeFormatName(option)),
              ],
            );
            if (picked != null && context.mounted) {
              await saveSetting(
                context,
                () => controller.setTimeFormat(picked),
              );
            }
          },
        ),
        SettingsRow(
          key: const ValueKey('settings-week-start'),
          icon: SettingsIcons.weekStart,
          title: l10n.settingsWeekStartTitle,
          value: weekStartName(preferences.weekStart),
          onTap: () async {
            final picked = await showChoiceSheet<int>(
              context: context,
              title: l10n.settingsWeekStartTitle,
              selected: preferences.weekStart,
              options: [
                for (final weekStart in [WeekStart.monday, WeekStart.sunday])
                  ChoiceOption(weekStart, weekStartName(weekStart)),
              ],
            );
            if (picked != null && context.mounted) {
              await saveSetting(context, () => controller.setWeekStart(picked));
            }
          },
        ),
        SettingsSwitchRow(
          icon: SettingsIcons.weekNumbers,
          title: l10n.settingsWeekNumbersTitle,
          subtitle: l10n.settingsWeekNumbersSubtitle,
          value: preferences.weekNumbers,
          switchKey: const ValueKey('settings-week-numbers'),
          onChanged: (show) =>
              saveSetting(context, () => controller.setWeekNumbers(show)),
        ),
        SettingsRow(
          key: const ValueKey('settings-currency'),
          icon: SettingsIcons.currency,
          title: l10n.settingsCurrencyTitle,
          value: currencyName(preferences.currency),
          onTap: () async {
            final picked = await showCurrencySheet(
              context: context,
              selected: preferences.currency,
              locale: localeName,
            );
            if (picked != null && context.mounted) {
              await saveSetting(context, () => controller.setCurrency(picked));
            }
          },
        ),
        const HolidaysSettingsRow(),
      ],
    );
  }
}
