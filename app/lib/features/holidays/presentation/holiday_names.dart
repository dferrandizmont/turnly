import '../../../core/format/text_fold.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/holiday.dart';

/// The name of [holiday] in the app's language (H-T21-1).
///
/// Spain's bundle carries Spanish names. Every national, regional and local
/// name of the bundle has a translation in the ARB files (`holidayName*`, a
/// test checks it); a name that is not there stays as the bundle has it.
/// Every other country shows its own local names (see `docs/festivos.md`),
/// in every app language: translating only the few that match a Spanish key
/// would mix two languages in one list (Bolivia, Portugal). A holiday the
/// person added is theirs: never translated.
String holidayDisplayName(AppLocalizations l10n, Holiday holiday) {
  if (holiday.isUserAdded || holiday.countryCode != 'ES') return holiday.name;
  return localizedHolidayName(l10n, holiday.name) ?? holiday.name;
}

final RegExp _localFeast = RegExp(r'^Fiesta local \((.+)\)$');

/// The translation of the bundle name [bundleName], or `null` when there is
/// none. The bundle has no ids, so the stable key is the Spanish name folded
/// ([foldSpanish]: no accents, case or hyphens), which survives the small
/// spelling differences between years of the bundle.
String? localizedHolidayName(AppLocalizations l10n, String bundleName) {
  // «Fiesta local (Cerceda)»: the place is a proper name, the rest translates.
  final local = _localFeast.firstMatch(bundleName.trim());
  if (local != null) return l10n.holidayNameLocalFeast(local.group(1)!);
  return switch (foldSpanish(bundleName.trim())) {
    'ano nuevo' => l10n.holidayNameNewYear,
    'epifania del senor' => l10n.holidayNameEpiphany,
    'jueves santo' => l10n.holidayNameMaundyThursday,
    'viernes santo' => l10n.holidayNameGoodFriday,
    'lunes de pascua' => l10n.holidayNameEasterMonday,
    'fiesta del trabajo' => l10n.holidayNameLabourDay,
    'asuncion de la virgen' => l10n.holidayNameAssumption,
    'fiesta nacional de espana' => l10n.holidayNameNationalDay,
    'todos los santos' => l10n.holidayNameAllSaints,
    'dia de la constitucion espanola' => l10n.holidayNameConstitution,
    'inmaculada concepcion' => l10n.holidayNameImmaculate,
    'natividad del senor' => l10n.holidayNameChristmas,
    'san esteban' => l10n.holidayNameStStephen,
    'san jose' => l10n.holidayNameStJoseph,
    'santiago apostol' => l10n.holidayNameStJames,
    'dia de galicia' => l10n.holidayNameGaliciaDay,
    'santiago apostol / dia nacional de galicia' =>
      l10n.holidayNameStJamesGalicia,
    'diada nacional de cataluna' ||
    'diada nacional de catalunya' => l10n.holidayNameCataloniaDay,
    'dia del pais vasco' => l10n.holidayNameBasqueDay,
    'san juan' => l10n.holidayNameStJohn,
    'dia de andalucia' => l10n.holidayNameAndalusiaDay,
    'dia siguiente a todos los santos' => l10n.holidayNameDayAfterAllSaints,
    'lunes siguiente al dia de la constitucion' ||
    'lunes siguiente al dia de la constitucion espanola' =>
      l10n.holidayNameMondayAfterConstitution,
    'san jorge / dia de aragon' => l10n.holidayNameAragonDay,
    'dia de asturias' => l10n.holidayNameAsturiasDay,
    'dia de las instituciones de cantabria' =>
      l10n.holidayNameCantabriaInstitutionsDay,
    'la bien aparecida' => l10n.holidayNameBienAparecida,
    'fiesta del sacrificio (eidul adha)' ||
    'fiesta del sacrificio (aid al adha)' ||
    'eidul adha (fiesta del sacrificio)' => l10n.holidayNameEidAdha,
    'fiesta del eid fitr' => l10n.holidayNameEidFitr,
    'nuestra senora de africa' => l10n.holidayNameOurLadyAfrica,
    'dia de ceuta' => l10n.holidayNameCeutaDay,
    'fiesta de castilla y leon' => l10n.holidayNameCastileLeonDay,
    'corpus christi' => l10n.holidayNameCorpusChristi,
    'dia de canarias' => l10n.holidayNameCanaryDay,
    'dia de extremadura' => l10n.holidayNameExtremaduraDay,
    'dia de la region de murcia' => l10n.holidayNameMurciaDay,
    'fiesta de la comunidad de madrid' => l10n.holidayNameMadridDay,
    'dia de la rioja' => l10n.holidayNameRiojaDay,
    'dia de la comunitat valenciana' => l10n.holidayNameValencianDay,
    'dia de les illes balears' => l10n.holidayNameBalearicDay,
    'lunes siguiente al dia de les illes balears' =>
      l10n.holidayNameMondayAfterBalearicDay,
    'dia de castilla la mancha' => l10n.holidayNameCastillaMancha,
    'sustitucion del 15 de agosto' => l10n.holidayNameAugustReplacement,
    'lunes siguiente a la asuncion de la virgen' =>
      l10n.holidayNameMondayAfterAssumption,
    'traslado de la asuncion' => l10n.holidayNameAssumptionMoved,
    'dia de las letras gallegas' => l10n.holidayNameGalicianLettersDay,
    'aniversario del primer gobierno vasco' =>
      l10n.holidayNameFirstBasqueGovernment,
    'fiesta insular (nuestra senora del pino)' => l10n.holidayNameIslandPino,
    'fiesta insular (nuestra senora de la pena)' => l10n.holidayNameIslandPena,
    'fiesta insular (nuestra senora de los volcanes)' =>
      l10n.holidayNameIslandVolcanoes,
    'fiesta insular (virgen de la candelaria)' =>
      l10n.holidayNameIslandCandelaria,
    'fiesta insular (nuestra senora de guadalupe)' =>
      l10n.holidayNameIslandGuadalupe,
    'fiesta insular (nuestra senora de las nieves)' =>
      l10n.holidayNameIslandNieves,
    'fiesta insular (nuestra senora de los reyes)' =>
      l10n.holidayNameIslandReyes,
    _ => null,
  };
}
