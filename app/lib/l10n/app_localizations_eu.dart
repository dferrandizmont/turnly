// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Basque (`eu`).
class AppLocalizationsEu extends AppLocalizations {
  AppLocalizationsEu([String locale = 'eu']) : super(locale);

  @override
  String get appName => 'Turnly';

  @override
  String get cancel => 'Utzi';

  @override
  String get close => 'Itxi';

  @override
  String get delete => 'Ezabatu';

  @override
  String get save => 'Gorde';

  @override
  String get undo => 'Desegin';

  @override
  String get redo => 'Berregin';

  @override
  String get retry => 'Saiatu berriro';

  @override
  String get back => 'Atzera';

  @override
  String get loadingLabel => 'Kargatzen';

  @override
  String get errorGeneric => 'Zerbaitek huts egin du. Saiatu berriro.';

  @override
  String get calendarToday => 'Gaur';

  @override
  String calendarPickMonth(String month) {
    return '$month, aukeratu hilabetea';
  }

  @override
  String get calendarPreviousMonth => 'Aurreko hila';

  @override
  String get calendarNextMonth => 'Hurrengo hila';

  @override
  String calendarHeaderTomorrow(String date, String shifts) {
    return 'Bihar ($date): $shifts';
  }

  @override
  String calendarHeaderTomorrowNone(String date) {
    return 'Bihar ($date): txandarik ez';
  }

  @override
  String get todayLabelNow => 'Orain';

  @override
  String get todayLabelTonight => 'Gaur gauean';

  @override
  String get todayLabelToday => 'Gaur';

  @override
  String get todayLabelFree => 'Gaur libre';

  @override
  String get todayLabelDone => 'Gaurkoa amaituta';

  @override
  String todayFinishedAt(String time) {
    return 'Amaitu da: $time';
  }

  @override
  String get todayLabelGap => 'Etenaldia';

  @override
  String todayBackAt(String time) {
    return 'Itzulera: $time';
  }

  @override
  String todayBackIn(String duration) {
    return '$duration barru itzuliko zara';
  }

  @override
  String get todayFreeTitle => 'Libre';

  @override
  String todayUntil(String time) {
    return 'Amaiera: $time';
  }

  @override
  String todayStartsIn(String duration) {
    return '$duration barru hasiko da';
  }

  @override
  String todayEndsIn(String duration) {
    return '$duration barru amaituko da';
  }

  @override
  String todayNext(String name, String weekday, String time) {
    return 'Hurrengoa: $name, $weekday $time';
  }

  @override
  String get todayNoNext => 'Ez dago txandarik bistan';

  @override
  String todayAlso(String shift) {
    return '+ $shift';
  }

  @override
  String get offToday => 'Gaur libre zaude';

  @override
  String offTodayBack(String date) {
    return 'Gaur libre zaude; itzultzea: $date';
  }

  @override
  String get offTomorrow => 'Bihar libre zaude';

  @override
  String offOn(String date) {
    return 'Hurrengo egun librea: $date';
  }

  @override
  String offWeekend(String range) {
    return 'Asteburu librea: $range';
  }

  @override
  String offStreak(int worked) {
    return '$worked egun jarraian lanean';
  }

  @override
  String offStreakLeft(int worked, int left) {
    String _temp0 = intl.Intl.pluralLogic(
      left,
      locale: localeName,
      other: '$left geratzen zaizkizu',
      one: '1 geratzen zaizu',
    );
    return '$worked egun jarraian lanean; $_temp0';
  }

  @override
  String durationDaysHours(int days, int hours) {
    return '$days egun $hours h';
  }

  @override
  String durationDays(int days) {
    return '$days egun';
  }

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String durationHours(int hours) {
    return '$hours h';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get calendarNoShift => 'Txandarik ez';

  @override
  String calendarShiftWithTimes(String name, String times) {
    return '$name $times';
  }

  @override
  String get calendarWeekdayMon => 'Al';

  @override
  String get calendarWeekdayTue => 'Ar';

  @override
  String get calendarWeekdayWed => 'Az';

  @override
  String get calendarWeekdayThu => 'Og';

  @override
  String get calendarWeekdayFri => 'Or';

  @override
  String get calendarWeekdaySat => 'Lr';

  @override
  String get calendarWeekdaySun => 'Ig';

  @override
  String get daySemanticsToday => 'gaur';

  @override
  String get daySemanticsNoShift => 'txandarik ez';

  @override
  String daySemanticsShift(String name, String start, String end) {
    return '$name, hasiera $start, amaiera $end';
  }

  @override
  String daySemanticsShiftSplit(
    String name,
    String start,
    String end,
    String start2,
    String end2,
  ) {
    return '$name, hasiera $start, amaiera $end; eta hasiera $start2, amaiera $end2';
  }

  @override
  String daySemanticsAnd(String first, String second) {
    return '$first eta $second';
  }

  @override
  String daySemanticsHoliday(String name) {
    return 'jaieguna: $name';
  }

  @override
  String get daySemanticsNote => 'oharrarekin';

  @override
  String daySemanticsOvertime(String duration) {
    return 'aparteko orduak: $duration';
  }

  @override
  String daySemanticsEarlyLeave(String duration) {
    return 'irteera aurreratua: $duration';
  }

  @override
  String daySheetHoliday(String name) {
    return 'Jaieguna: $name';
  }

  @override
  String get daySheetNote => 'Oharra';

  @override
  String get daySheetEmpty => 'Egun honek ez du txandarik.';

  @override
  String get dayPaneClose => 'Itxi eguna';

  @override
  String get upcomingTitle => 'Hurrengo egunak';

  @override
  String get dayDetailSourcePattern => 'Zure ereduaren arabera';

  @override
  String get dayDetailSourceOverride => 'Eskuz aldatua';

  @override
  String get dayDetailAdd => 'Gehitu txanda';

  @override
  String get dayDetailDouble => 'Gehitu bigarren txanda';

  @override
  String get dayDetailReset => 'Itzuli eredura';

  @override
  String dayDetailPatternGives(String shifts) {
    return 'Ereduaren arabera: $shifts';
  }

  @override
  String get dayDetailNoteHint => 'Idatzi ohar bat egun honetarako';

  @override
  String get dayDetailUserHoliday => 'Jaiegun pertsonala';

  @override
  String get dayDetailUserHolidayDefault => 'Jaiegun pertsonala';

  @override
  String get dayDetailUserHolidayNameHint => 'Jaiegunaren izena';

  @override
  String get dayDetailDuplicate => 'Bikoiztu beste egun batean';

  @override
  String get dayDetailDuplicateHelp => 'Kopiatu egun honetara';

  @override
  String dayDetailDuplicated(String date) {
    return 'Kopiatuta: $date';
  }

  @override
  String get dayDetailClear => 'Ezabatu eguna';

  @override
  String get dayDetailCleared => 'Eguna ezabatuta';

  @override
  String get dayDetailMoveUp => 'Igo';

  @override
  String get dayDetailMoveDown => 'Jaitsi';

  @override
  String dayDetailRemove(String name) {
    return 'Kendu: $name';
  }

  @override
  String get dayDetailUndo => 'Desegin egun honetako azken aldaketa';

  @override
  String dayDetailShiftMenu(String name) {
    return 'Aukerak: $name';
  }

  @override
  String get dayDetailChange => 'Aldatu';

  @override
  String dayDetailChangeTitle(String name) {
    return 'Aldatu txanda: $name';
  }

  @override
  String get dayDetailChangeHint =>
      'Txanda bat beste batekin aldatzeko, ukitu haren menua.';

  @override
  String get dayDetailMore => 'Aukera gehiago';

  @override
  String get dayMoreExtras => 'Aparteko orduak';

  @override
  String get dayMoreReminder => 'Abisua';

  @override
  String get dayMoreAlarm => 'Alarma';

  @override
  String get dayMoreDuplicate => 'Bikoiztu';

  @override
  String get dayMoreClear => 'Ezabatu';

  @override
  String get dayExtrasTitle => 'Aparteko orduak / Lehenago irten naiz';

  @override
  String get dayExtrasOvertime => 'Aparteko orduak';

  @override
  String get dayExtrasEarlyLeave => 'Lehenago irten naiz';

  @override
  String get dayExtrasNone => 'Bat ere ez';

  @override
  String get dayExtrasHelper =>
      'Hileko orduei eta estimazioari gehitzen edo kentzen zaizkie. 0 jarrita kentzen da.';

  @override
  String dayExtrasMore(String label) {
    return 'Gehiago: $label';
  }

  @override
  String dayExtrasLess(String label) {
    return 'Gutxiago: $label';
  }

  @override
  String dayExtrasValue(String label, String value) {
    return '$label: $value';
  }

  @override
  String get shiftTypesTitle => 'Nire txandak';

  @override
  String get shiftTypesEditEntry => 'Editatu txandak';

  @override
  String get shiftTypesEmptyTitle => 'Ez duzu txandarik';

  @override
  String get shiftTypesEmptyMessage =>
      'Sortu lehenengoa egutegian margotu ahal izateko.';

  @override
  String get shiftTypesNew => 'Txanda berria';

  @override
  String get shiftTypesNewTitle => 'Txanda berria';

  @override
  String get shiftTypesEditTitle => 'Editatu txanda';

  @override
  String get shiftTypesNotFound => 'Ez dugu txanda hau aurkitu';

  @override
  String get shiftTypesNotFoundMessage =>
      'Baliteke artxibatu izana. Itzuli txanden zerrendara.';

  @override
  String get shiftTypesArchive => 'Artxibatu';

  @override
  String shiftTypesArchiveTitle(String name) {
    return '«$name» artxibatu nahi duzu?';
  }

  @override
  String get shiftTypesArchiveBody =>
      'Margotzean ez da gehiago agertuko. Dagoeneko erabiltzen duten egunek erakusten jarraituko dute.';

  @override
  String get shiftTypesArchiveConfirm => 'Artxibatu';

  @override
  String get shiftTypesDragHandle => 'Arrastatu ordena aldatzeko';

  @override
  String shiftTypesArchivedSection(int count) {
    return 'Artxibatuak ($count)';
  }

  @override
  String get shiftTypesArchivedHelp =>
      'Margotzean ez dira agertzen. Berreskuratu, eta paletara itzuliko dira.';

  @override
  String get shiftTypesRestore => 'Berreskuratu';

  @override
  String shiftTypesRestoreSemantic(String name) {
    return 'Berreskuratu «$name»';
  }

  @override
  String shiftTypesRestored(String name) {
    return '«$name» berreskuratu da';
  }

  @override
  String get shiftTypesDiscardTitle => 'Aldaketak baztertu nahi dituzu?';

  @override
  String get shiftTypesDiscardBody =>
      'Txanda honetan aldatu duzuna ez da gordeko.';

  @override
  String get shiftTypesDiscardKeep => 'Jarraitu editatzen';

  @override
  String get shiftTypesDiscardConfirm => 'Baztertu';

  @override
  String get shiftTypesScopeTitle => 'Zer egunetan eragiten du aldaketak?';

  @override
  String get shiftTypesScopeBody =>
      'Txanda honen orduak edo dirua aldatu dituzu, eta dagoeneko iraganeko egunetan duzu.';

  @override
  String get shiftTypesScopeAll => 'Zuzendu egun guztietan';

  @override
  String get shiftTypesScopeAllHint =>
      'Akats bat zen: iraganeko egunen orduak eta dirua ere aldatzen dira.';

  @override
  String shiftTypesScopeAllHintSince(String date) {
    return 'Akats bat zen: data honetatik aurrerako egunak aldatzen dira: $date (txanda hau azkenekoz aldatu zenuen eguna). Aurrekoak dauden bezala geratzen dira.';
  }

  @override
  String get shiftTypesScopeFromToday => 'Gaurtik aurrera bakarrik';

  @override
  String get shiftTypesScopeFromTodayHint =>
      'Zure lanaldia edo prezioa aldatu da: iraganeko egunak lehen bezala geratzen dira.';

  @override
  String get shiftTypesNoTimes => 'Ordutegirik gabe';

  @override
  String shiftTypesRatePerHour(String rate) {
    return '$rate/h';
  }

  @override
  String shiftTypesFixedPlusPerShift(String amount) {
    return 'Txanda bakoitzeko: +$amount';
  }

  @override
  String get shiftTypesCategoryWork => 'Lana';

  @override
  String get shiftTypesCategoryRest => 'Atsedena';

  @override
  String get shiftTypesCategoryAbsence => 'Absentzia';

  @override
  String get shiftTypesNameLabel => 'Izena';

  @override
  String get shiftTypesCodeLabel => 'Kodea';

  @override
  String get shiftTypesCodeHelper =>
      '1-3 karaktere. Hileko lauki bakoitzean ikusten dena da.';

  @override
  String get shiftTypesColorLabel => 'Kolorea';

  @override
  String shiftTypesColorOption(int number, int total) {
    return 'Kolorea: $number/$total';
  }

  @override
  String shiftTypesColorOptionNamed(String name, int number, int total) {
    return '$name, $number/$total';
  }

  @override
  String get shiftColorNameOrange => 'Laranja';

  @override
  String get shiftColorNameCoral => 'Korala';

  @override
  String get shiftColorNameIndigo => 'Indigoa';

  @override
  String get shiftColorNameLightGrey => 'Gris argia';

  @override
  String get shiftColorNameRed => 'Gorria';

  @override
  String get shiftColorNameLilac => 'Lila';

  @override
  String get shiftColorNameGreen => 'Berdea';

  @override
  String get shiftColorNameTeal => 'Turkesa';

  @override
  String get shiftColorNameRaspberry => 'Mugurdia';

  @override
  String get shiftColorNamePink => 'Arrosa';

  @override
  String get shiftColorNameTangerine => 'Mandarina';

  @override
  String get shiftColorNameYellow => 'Horia';

  @override
  String get shiftColorNameLime => 'Lima';

  @override
  String get shiftColorNameForest => 'Baso-berdea';

  @override
  String get shiftColorNameMint => 'Menda';

  @override
  String get shiftColorNameCyan => 'Ziana';

  @override
  String get shiftColorNameSkyBlue => 'Zeru-urdina';

  @override
  String get shiftColorNameBlue => 'Urdina';

  @override
  String get shiftColorNameCobalt => 'Kobaltoa';

  @override
  String get shiftColorNameViolet => 'Bioleta';

  @override
  String get shiftColorNamePurple => 'Morea';

  @override
  String get shiftColorNameBrown => 'Marroia';

  @override
  String get shiftColorNameGrey => 'Grisa';

  @override
  String get shiftColorNameGraphite => 'Grafitoa';

  @override
  String get shiftTypesColorCurrent => 'Uneko kolorea';

  @override
  String get shiftTypesIconLabel => 'Ikonoa';

  @override
  String get shiftTypesIconHelper =>
      'Aukerakoa. Kodearen ondoan ikusten da lekua dagoenean; kodea eta kolorea beti daude.';

  @override
  String get shiftTypesIconNone => 'Ikonorik ez';

  @override
  String get shiftTypesIconChoose => 'Aukeratu ikonoa';

  @override
  String shiftTypesIconCurrent(String name) {
    return 'Ikonoa: $name';
  }

  @override
  String get shiftIconNameSun => 'Eguzkia';

  @override
  String get shiftIconNameMoon => 'Ilargia';

  @override
  String get shiftIconNameSunrise => 'Egunsentia';

  @override
  String get shiftIconNameHospital => 'Ospitalea';

  @override
  String get shiftIconNameAmbulance => 'Anbulantzia';

  @override
  String get shiftIconNamePolice => 'Polizia';

  @override
  String get shiftIconNameFire => 'Suhiltzaileak';

  @override
  String get shiftIconNameFactory => 'Lantegia';

  @override
  String get shiftIconNameTruck => 'Kamioia';

  @override
  String get shiftIconNamePlane => 'Hegazkina';

  @override
  String get shiftIconNameSchool => 'Ikastetxea';

  @override
  String get shiftIconNameHome => 'Etxea';

  @override
  String get shiftIconNameBeach => 'Hondartza';

  @override
  String get shiftIconNameBed => 'Ohea';

  @override
  String get shiftIconNameStar => 'Izarra';

  @override
  String get shiftIconNameHeart => 'Bihotza';

  @override
  String get shiftIconNameCoffee => 'Kafea';

  @override
  String get shiftIconNameBook => 'Liburua';

  @override
  String get shiftIconNameMoney => 'Dirua';

  @override
  String get shiftIconNameAlert => 'Abisua';

  @override
  String get shiftIconNamePhone => 'Telefonoa';

  @override
  String get shiftIconNameCar => 'Autoa';

  @override
  String get shiftIconNameTrain => 'Trena';

  @override
  String get shiftIconNameBus => 'Autobusa';

  @override
  String get shiftIconNameShop => 'Denda';

  @override
  String get shiftIconNameTool => 'Tresnak';

  @override
  String get shiftIconNameBaby => 'Haurra';

  @override
  String get shiftIconNameSport => 'Kirola';

  @override
  String get shiftIconNameParty => 'Jaia';

  @override
  String get shiftIconNameMedical => 'Medikua';

  @override
  String get shiftTypesColorMore => 'Kolore gehiago…';

  @override
  String get shiftTypesColorPickerTitle => 'Aukeratu zure kolorea';

  @override
  String get shiftTypesColorPickerHelp =>
      'Ikusi nola geratzen den laukia modu argian eta ilunean. Testua bere kasa egokitzen da ondo irakurtzeko.';

  @override
  String get shiftTypesColorHue => 'Ñabardura';

  @override
  String get shiftTypesColorSaturation => 'Intentsitatea';

  @override
  String get shiftTypesColorLightness => 'Argitasuna';

  @override
  String shiftTypesColorHueSpoken(int degrees) {
    return '$degrees gradu';
  }

  @override
  String shiftTypesColorPercentSpoken(int percent) {
    return 'ehuneko $percent';
  }

  @override
  String get shiftTypesColorHexLabel => 'Kode hamaseitarra';

  @override
  String get shiftTypesColorHexError =>
      'Idatzi 6 zifra edo letra, A-tik F-ra; adibidez, #1C7ED6.';

  @override
  String get shiftTypesColorUse => 'Erabili kolore hau';

  @override
  String get shiftTypesCategoryLabel => 'Kategoria';

  @override
  String get shiftTypesTimesLabel => 'Ordutegia';

  @override
  String shiftTypesStarts(String time) {
    return 'Hasiera: $time';
  }

  @override
  String shiftTypesEnds(String time) {
    return 'Amaiera: $time';
  }

  @override
  String get shiftTypesPickStart => 'Hasiera-ordua';

  @override
  String get shiftTypesPickEnd => 'Amaiera-ordua';

  @override
  String shiftTypesDuration(String duration) {
    return 'Iraupena: $duration';
  }

  @override
  String shiftTypesEndsNextDay(String duration) {
    return 'Hurrengo egunean amaitzen da · iraupena: $duration';
  }

  @override
  String get shiftTypesTwentyFourHours =>
      '24 h irauten du: hurrengo egunean amaitzen da, ordu berean';

  @override
  String get shiftTypesSplitLabel => 'Txanda zatitua';

  @override
  String get shiftTypesSplitHelper =>
      'Bi zati egun berean, tartean lan gisa kontatzen ez den etenaldi batekin.';

  @override
  String get shiftTypesSplitTemplate => 'Erabili «Zatitua 09–13 / 17–21»';

  @override
  String get shiftTypesSplitSecondTitle => 'Bigarren zatia';

  @override
  String get shiftTypesPickSecondStart => '2. zatiaren hasiera';

  @override
  String get shiftTypesPickSecondEnd => '2. zatiaren amaiera';

  @override
  String shiftTypesSplitSummary(String first, String second, String total) {
    return 'Lana: $first eta $second; guztira $total';
  }

  @override
  String get shiftTypesErrorSplitIncomplete =>
      'Jarri noiz hasi eta amaitzen den bigarren zatia, edo desaktibatu txanda zatitua.';

  @override
  String get shiftTypesErrorSplitStart =>
      'Bigarren zatiaren hasiera-ordua ez da baliozkoa.';

  @override
  String get shiftTypesErrorSplitDuration =>
      'Bigarren zatiak minutu 1 eta 24 h bitartean iraun behar du.';

  @override
  String get shiftTypesErrorSplitNotAfter =>
      'Bigarren zatia ezin da hasi lehena amaitzen den unean bertan: zati bakarra izango litzateke. Utzi etenaldi bat bien artean.';

  @override
  String get shiftTypesErrorSplitTooLong =>
      'Bi zatiak eta haien arteko etenaldia ez dira 24 orduan sartzen. Egiaztatu bigarrena lehena amaitu ondoren hasten dela.';

  @override
  String get shiftTypesBreakLabel => 'Ordaindu gabeko etenaldia';

  @override
  String get shiftTypesBreakUnit => 'min';

  @override
  String get shiftTypesBreakHint => '0 min';

  @override
  String get shiftTypesRateHint => 'Preziorik gabe';

  @override
  String get shiftTypesBreakHelper =>
      'Ordaintzen ez diren txandako minutuak. Utzi hutsik dena ordaintzen bada.';

  @override
  String shiftTypesPaidHelper(String duration) {
    return 'Ordaindua: $duration';
  }

  @override
  String get shiftTypesNightLabel => 'Gaueko txanda';

  @override
  String get shiftTypesNightHelper =>
      'Automatikoa aukerak 22:00 eta 06:00 arteko orduak gaueko gisa kontatzen ditu.';

  @override
  String get shiftTypesNightAuto => 'Automatikoa';

  @override
  String get shiftTypesNightAlways => 'Beti gauekoa';

  @override
  String get shiftTypesNightNever => 'Inoiz ez gauekoa';

  @override
  String get shiftTypesFixedPlusLabel => 'Txandako osagarria (aukerakoa)';

  @override
  String get shiftTypesFixedPlusHelper =>
      'Lan egindako txanda bakoitzeko behin gehitzen da.';

  @override
  String get shiftTypesFixedPlusHint => 'Osagarririk gabe';

  @override
  String get shiftTypesRateLabel => 'Orduko prezioa (aukerakoa)';

  @override
  String get shiftTypesRateHelper =>
      'Hileko laburpenean zenbat irabazten duzun kalkulatzeko.';

  @override
  String shiftTypesRateUnit(String symbol) {
    return '$symbol/h';
  }

  @override
  String get shiftTypesPreviewLabel => 'Honela ikusiko da hilean';

  @override
  String get shiftTypesPreviewLight => 'Argia';

  @override
  String get shiftTypesPreviewDark => 'Iluna';

  @override
  String shiftTypesPreviewContrast(String ratio) {
    return 'Kontrastea: $ratio:1';
  }

  @override
  String get shiftTypesErrorCodeEmpty => 'Idatzi 1-3 karaktereko kode bat';

  @override
  String get shiftTypesErrorCodeTooLong =>
      'Kodeak gehienez 3 karaktere izan ditzake, emojirik eta zuriunerik gabe';

  @override
  String shiftTypesErrorCodeTaken(String name) {
    return 'Kode hau dagoeneko erabiltzen du txanda honek: «$name»';
  }

  @override
  String get shiftTypesErrorNameEmpty => 'Jarri izen bat txandari';

  @override
  String get shiftTypesErrorBreak =>
      'Etenaldiak txandak baino laburragoa izan behar du';

  @override
  String get shiftTypesErrorRate =>
      'Idatzi zenbateko baliozko bat; adibidez, 12,50';

  @override
  String get paintFab => 'Margotu';

  @override
  String get paintHeader => 'Margotzen';

  @override
  String paintHeaderShift(String name, String times) {
    return '$name · $times';
  }

  @override
  String get paintDone => 'Eginda';

  @override
  String get paintDouble => 'Bikoiztu';

  @override
  String get paintEraser => 'Ezabatu';

  @override
  String get paintToolsLabel => 'Margotzeko tresnak';

  @override
  String get paintModeReplace => 'Aldatu txanda';

  @override
  String get paintModeAdd => 'Gehitu beste txanda bat';

  @override
  String get paintModeAddSpoken => 'Gehitu beste txanda bat (bikoiztu)';

  @override
  String paintHeaderMode(String header, String mode) {
    return '$header · $mode';
  }

  @override
  String get paintPreviewTitle => 'Egun bat ukitzean';

  @override
  String get paintPreviewTitleDouble => 'Egun bat ukitzean (bikoiztu)';

  @override
  String get paintPreviewReplace => 'Dagoena ordezkatzen du';

  @override
  String get paintPreviewAdd => 'Dagoenari gehitzen zaio';

  @override
  String get paintPreviewErase => 'Eguna hutsik uzten du';

  @override
  String get paintPreviewEmpty => 'hutsik';

  @override
  String paintPreviewSpoken(
    String title,
    String before,
    String after,
    String effect,
  ) {
    return '$title. Lehen: $before. Gero: $after. $effect';
  }

  @override
  String paintPreviewSpokenTimes(
    String title,
    String before,
    String after,
    String times,
    String effect,
  ) {
    return '$title. Lehen: $before. Gero: $after, $times. $effect';
  }

  @override
  String paintToolSpoken(String name, String times) {
    return '$name, $times';
  }

  @override
  String get selectionHeader => 'Hautapena';

  @override
  String get selectionHint =>
      'Ukitu egunak, edo eduki sakatuta eta arrastatu batzuk aukeratzeko';

  @override
  String selectionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count egun',
      one: 'Egun 1',
      zero: 'Egunik ez',
    );
    return '$_temp0';
  }

  @override
  String get selectionBarLabel => 'Aukeratutako egunetarako ekintzak';

  @override
  String get selectionSetShift => 'Jarri txanda…';

  @override
  String get selectionDouble => 'Bikoiztu…';

  @override
  String get selectionClear => 'Ezabatu';

  @override
  String get selectionReset => 'Itzuli eredura';

  @override
  String get selectionCopy => 'Kopiatu';

  @override
  String get selectionCut => 'Ebaki';

  @override
  String get selectionPaste => 'Itsatsi';

  @override
  String get selectionRepeat => 'Errepikatu…';

  @override
  String get selectionNote => 'Oharra…';

  @override
  String get selectionCancel => 'Utzi';

  @override
  String get selectionCellSelected => 'aukeratuta';

  @override
  String get selectionSetShiftTitle => 'Jarri txanda';

  @override
  String get selectionSetShiftHelp =>
      'Aukeratutako egunetako txandak ordezten ditu.';

  @override
  String get selectionDoubleTitle => 'Gehitu bigarren txanda';

  @override
  String get selectionDoubleHelp =>
      'Aukeratutako egunek dituzten txandei gehitzen die.';

  @override
  String get selectionNoteTitle => 'Aukeratutako egunetarako oharra';

  @override
  String get selectionNoteHint => 'Ohar bera egun guztietan';

  @override
  String get selectionNoteSave => 'Gorde oharra';

  @override
  String get selectionNoteRemove => 'Kendu oharrak';

  @override
  String get selectionPasteTitle => 'Itsatsi egunak';

  @override
  String selectionPasteSummary(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count egun itsatsiko dira',
      one: 'Egun 1 itsatsiko da',
    );
    return '$_temp0. Hasiera: $date.';
  }

  @override
  String selectionPasteReach(String from, String to) {
    return 'Itsasteko tartea: $from – $to.';
  }

  @override
  String get selectionPasteReplaces =>
      'Egun horietako txandak ordeztu egingo dira. Desegin ahal izango duzu.';

  @override
  String get selectionIncludeNotes => 'Sartu oharrak';

  @override
  String get selectionIncludeNotesHelp =>
      'Kopiatutako egunetako oharrek helmugakoak ordezten dituzte.';

  @override
  String get selectionCutNotesMove =>
      'Ebakitzean, oharrak egunekin batera mugitzen dira.';

  @override
  String get selectionPasteConfirm => 'Itsatsi';

  @override
  String get selectionRepeatTitle => 'Errepikatu aukeratutako egunak';

  @override
  String selectionRepeatTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count aldiz',
      one: 'Behin',
    );
    return '$_temp0';
  }

  @override
  String get selectionRepeatLess => 'Behin gutxiago';

  @override
  String get selectionRepeatMore => 'Behin gehiago';

  @override
  String selectionRepeatPreview(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count egun gehiago aldatuko dira (azkena: $date).',
      one: 'Egun 1 gehiago aldatuko da (azkena: $date).',
    );
    return '$_temp0';
  }

  @override
  String get selectionRepeatConfirm => 'Errepikatu';

  @override
  String selectionChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count egun aldatu dira',
      one: 'Egun 1 aldatu da',
    );
    return '$_temp0';
  }

  @override
  String get selectionNothingChanged => 'Egun horiek horrela zeuden jada';

  @override
  String selectionCopied(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count egun kopiatu dira',
      one: 'Egun 1 kopiatu da',
    );
    return '$_temp0. Aukeratu hasierako eguna eta sakatu Itsatsi.';
  }

  @override
  String selectionCutDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count egun ebaki dira',
      one: 'Egun 1 ebaki da',
    );
    return '$_temp0. Aukeratu hasierako eguna eta sakatu Itsatsi.';
  }

  @override
  String selectionPasted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count egun itsatsi dira',
      one: 'Egun 1 itsatsi da',
    );
    return '$_temp0';
  }

  @override
  String selectionRepeated(int times) {
    String _temp0 = intl.Intl.pluralLogic(
      times,
      locale: localeName,
      other: '$times aldiz',
      one: 'behin',
    );
    return 'Errepikatuta: $_temp0';
  }

  @override
  String get selectionRunsTitle => 'Nire txandaketak';

  @override
  String get selectionRunsSubtitle => 'Amaitu edo kendu eredu bat behingoz';

  @override
  String get selectionRunsEmptyTitle => 'Txandaketarik ez';

  @override
  String get selectionRunsEmptyMessage =>
      'Margotu ataletik eredu bat aplikatzen duzunean, hemen agertuko da.';

  @override
  String selectionRunsRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String selectionRunsOpenEnded(String from) {
    return 'Hasiera: $from; amaiera-datarik gabe';
  }

  @override
  String selectionRunsStep(int day) {
    return 'Hasiera: zikloaren $day. eguna';
  }

  @override
  String get selectionRunsActive => 'Martxan';

  @override
  String get selectionRunsFuture => 'Oraindik ez da hasi';

  @override
  String get selectionRunsEnded => 'Amaituta';

  @override
  String get selectionRunsEnd => 'Amaitu hemen';

  @override
  String get selectionRunsEndHelp => 'Txandaketarik gabeko lehen eguna';

  @override
  String selectionRunsEndDone(String date) {
    return 'Txandaketaren amaiera: $date';
  }

  @override
  String get selectionRunsDelete => 'Ezabatu';

  @override
  String selectionRunsDeleteTitle(String name) {
    return '$name ezabatu nahi duzu?';
  }

  @override
  String get selectionRunsDeleteBody =>
      'Egutegi osotik kentzen da. Eskuz aldatu zenituen egunak eta oharrak dauden bezala geratzen dira. Desegin ahal izango duzu.';

  @override
  String get selectionRunsDeleted => 'Txandaketa ezabatu da';

  @override
  String get agendaTitle => 'Agenda';

  @override
  String get agendaOpenTooltip => 'Oharren agenda';

  @override
  String get agendaSearchHint => 'Bilatu oharretan eta txandetan';

  @override
  String get agendaSearchHintShort => 'Bilatu';

  @override
  String get agendaModeNotes => 'Oharrak';

  @override
  String get agendaModeShifts => 'Txandak';

  @override
  String get agendaSearchScope =>
      'Zure ohar eta jaiegun pertsonal guztietan bilatzen du, eta duela urtebetetik urtebete barrurako txandetan. Datak ere ulertzen ditu: 15/10 edo urriaren 15.';

  @override
  String get agendaSearchClear => 'Garbitu bilaketa';

  @override
  String get agendaEmptyTitle => 'Ez dago hurrengo oharrik';

  @override
  String get agendaEmptyMessage =>
      'Hurrengo egunetako oharrak eta jaiegun pertsonalak hemen agertuko dira.';

  @override
  String get agendaNoResultsTitle => 'Ez da ezer aurkitu';

  @override
  String agendaNoResultsMessage(String query) {
    return 'Ez dago bilaketa honekin bat datorren oharrik edo txandarik: «$query».';
  }

  @override
  String agendaHoliday(String name) {
    return 'Jaieguna: $name';
  }

  @override
  String agendaTruncated(int count) {
    return 'Lehenengo $count emaitzak erakusten dira. Idatzi zerbait gehiago bilaketa zehazteko.';
  }

  @override
  String agendaResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count emaitza',
      one: 'Emaitza 1',
    );
    return '$_temp0';
  }

  @override
  String agendaSemanticsNote(String note) {
    return 'oharra: $note';
  }

  @override
  String get patternButton => 'Eredua';

  @override
  String get patternTitle => 'Aplikatu eredua';

  @override
  String patternStepOf(int current, int total) {
    return 'Urratsa: $current/$total';
  }

  @override
  String get patternStepChoose => 'Aukeratu eredu bat';

  @override
  String get patternStepStart => 'Noiz hasten zara?';

  @override
  String get patternStepEnd => 'Noiz arte?';

  @override
  String get patternNext => 'Hurrengoa';

  @override
  String get patternBack => 'Atzera';

  @override
  String get patternApply => 'Aplikatu';

  @override
  String get patternApplied => 'Eredua aplikatu da';

  @override
  String get patternApplyFailed => 'Ezin izan da eredua aplikatu';

  @override
  String patternFromDay(String date) {
    return 'Hasiera: $date';
  }

  @override
  String get patternGroupHealth => 'Osasuna';

  @override
  String get patternGroupPolice => 'Polizia eta Guardia Zibila';

  @override
  String get patternGroupFirefighters => 'Suhiltzaileak';

  @override
  String get patternGroupIndustry => 'Industria';

  @override
  String get patternGroupSecurity => 'Segurtasuna';

  @override
  String get patternGroupOther => 'Beste bat';

  @override
  String get patternGroupMine => 'Nire ereduak';

  @override
  String patternGroupTypical(String shift) {
    return 'Lehen eguna: $shift';
  }

  @override
  String patternGroupIncluding(String shift) {
    return 'Barne dutenak: $shift';
  }

  @override
  String patternCycleDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count egun',
      one: 'Egun 1',
    );
    return '$_temp0';
  }

  @override
  String get patternCreateOwn => 'Sortu nirea';

  @override
  String get patternCreateOwnHint => 'Osatu zure sekuentzia egunez egun';

  @override
  String get patternBuilderBack => 'Aukeratu zerrendako eredu bat';

  @override
  String get patternBuilderName => 'Ereduaren izena';

  @override
  String get patternBuilderDefaultName => 'Nire eredua';

  @override
  String get patternBuilderSequence => 'Zure sekuentzia';

  @override
  String get patternBuilderEmpty => 'Ukitu beheko txandak egunak gehitzeko.';

  @override
  String get patternBuilderSameDay => 'Txanda bat baino gehiago egun batean';

  @override
  String get patternBuilderSameDayHint =>
      'Aktibatuta: ukitzen duzun txanda bakoitza sekuentziako azken egunari gehitzen zaio, egun berri bat sortu beharrean.';

  @override
  String get patternBuilderRemoveLast => 'Kendu azkena';

  @override
  String get patternBuilderClear => 'Hustu sekuentzia';

  @override
  String patternBuilderAdd(String name) {
    return 'Gehitu: $name';
  }

  @override
  String get patternStartLabel => 'Hasierako eguna';

  @override
  String patternSuggestedStart(String weekday) {
    return 'Eredu hau egun honetan hasi ohi da: $weekday.';
  }

  @override
  String get patternWeekdayMonday => 'astelehena';

  @override
  String get patternWeekdayTuesday => 'asteartea';

  @override
  String get patternWeekdayWednesday => 'asteazkena';

  @override
  String get patternWeekdayThursday => 'osteguna';

  @override
  String get patternWeekdayFriday => 'ostirala';

  @override
  String get patternWeekdaySaturday => 'larunbata';

  @override
  String get patternWeekdaySunday => 'igandea';

  @override
  String get patternOffsetTitle =>
      'Zikloaren zein egunetan zaude egun horretan?';

  @override
  String patternOffsetHelp(String date) {
    return 'Ukitu data honetan dagokizun ereduaren eguna: $date.';
  }

  @override
  String patternOffsetThatDay(String shifts) {
    return 'Egun horretan: $shifts';
  }

  @override
  String patternChipDay(int day, String shifts) {
    return '$day. eguna: $shifts';
  }

  @override
  String get patternEndNever => 'Amaierarik gabe';

  @override
  String get patternEndNeverHint => 'Aldatu arte errepikatzen da.';

  @override
  String get patternEndUntil => 'Data batera arte';

  @override
  String get patternEndUntilHint =>
      'Data horren ondoren, lehen zenuena itzultzen da.';

  @override
  String get patternUntilLabel => 'Azken eguna';

  @override
  String get patternOverridesTitle => 'Eskuz aldatu dituzun egunak';

  @override
  String get patternOverridesKeep => 'Errespetatu eskuz aldatu ditudan egunak';

  @override
  String get patternOverridesKeepHint =>
      'Zure aldaketak geratzen dira; ereduak gainerakoa betetzen du.';

  @override
  String get patternOverridesReplace => 'Ordeztu ereduarekin';

  @override
  String get patternOverridesReplaceHint =>
      'Data horietan eskuz egindako aldaketak ezabatzen dira. Oharrak geratzen dira.';

  @override
  String get patternPreviewTitle => 'Honela geratuko da';

  @override
  String get patternPreviewNone =>
      'Aukeratu eredu bat nola geratzen den ikusteko.';

  @override
  String patternPreviewPostNight(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Gau-ondoko automatikoa: $count egun, gau baten ondoren.',
      one: 'Gau-ondoko automatikoa: egun 1, gau baten ondoren.',
    );
    return '$_temp0';
  }

  @override
  String get patternPickBanner => 'Ukitu eredua hasten den eguna';

  @override
  String get onboardingSkip => 'Saltatu';

  @override
  String get onboardingNext => 'Hurrengoa';

  @override
  String get onboardingContinue => 'Jarraitu';

  @override
  String get onboardingChooseTitle => 'Nola hasiko duzu zure txanden egutegia?';

  @override
  String get onboardingChooseHelp =>
      'Aukeratu modu bat. Minutu bat baino lehen hilabetea prest izango duzu, eta gero nahi duzunean alda dezakezu.';

  @override
  String get onboardingPathImport => 'Inportatu nire txandak';

  @override
  String get onboardingPathImportHint =>
      'Mugikorreko egutegitik, .ics edo CSV fitxategi batetik, edo LRHSoft kopia batetik.';

  @override
  String get onboardingPathRotation => 'Erabili txandaketa bat';

  @override
  String get onboardingPathRotationHint =>
      'Aukeratu zure zikloa (goizak, arratsaldeak, gauak, gau-ondokoa…) eta bere kasa betetzen da, hilabetez hilabete.';

  @override
  String get onboardingPathRotationTag => 'Zure txanda errepikatzen bada';

  @override
  String get onboardingPathPaint => 'Margotu eskuz';

  @override
  String get onboardingPathPaintHint =>
      'Aukeratu txanda bat eta arrastatu egunen gainetik. Hilabete bakoitza desberdina denean.';

  @override
  String get onboardingChooseLater =>
      'Gero herrialdea galdetuko dizugu, jaiegunak markatzeko. Salta dezakezu.';

  @override
  String get onboardingRestore => 'Berreskuratu babeskopia bat';

  @override
  String get onboardingOptional => 'Aukerakoa';

  @override
  String onboardingProgress(int current, int total) {
    return 'Urratsa: $current/$total';
  }

  @override
  String get onboardingProfessionTitle => 'Zertan egiten duzu lan?';

  @override
  String get onboardingProfessionHelp =>
      'Zure laneko ohiko ordutegiak prest uzteko bakarrik. Nahi duzunean alda dezakezu.';

  @override
  String get onboardingProfessionNursing =>
      'Erizaintza, erizaintzako laguntzaileak eta zeladoreak';

  @override
  String get onboardingProfessionNursingHint =>
      'Goi 08–15, Arr 15–22, Gau 22–08 eta gau-ondokoa';

  @override
  String get onboardingProfessionMedicine => 'Medikuntza (guardiak)';

  @override
  String get onboardingProfessionMedicineHint =>
      'Goiza, 24 orduko guardia eta gau-ondokoa';

  @override
  String get onboardingProfessionPolice => 'Polizia eta Guardia Zibila';

  @override
  String get onboardingProfessionPoliceHint =>
      'Goi 07–15, Arr 15–23 eta Gau 23–07';

  @override
  String get onboardingProfessionFirefighters => 'Suhiltzaileak';

  @override
  String get onboardingProfessionFirefightersHint =>
      '24 orduko guardia eta atseden luzeak';

  @override
  String get onboardingProfessionIndustry => 'Industria';

  @override
  String get onboardingProfessionIndustryHint =>
      'Txanda birakariak: Goi 06–14, Arr 14–22 eta Gau 22–06';

  @override
  String get onboardingProfessionSecurity => 'Segurtasun pribatua';

  @override
  String get onboardingProfessionSecurityHint =>
      '12 orduko txandak, egunez eta gauez';

  @override
  String get onboardingProfessionHospitality => 'Ostalaritza eta merkataritza';

  @override
  String get onboardingProfessionHospitalityHint => 'Goi 08–16 eta Arr 16–00';

  @override
  String get onboardingProfessionOther => 'Beste bat';

  @override
  String get onboardingProfessionOtherHint => 'Betiko txandekin hasiko zara';

  @override
  String get onboardingProfessionNursingAbroad => 'Erizaintza eta osasuna';

  @override
  String get onboardingProfessionNursingAbroadHint =>
      'Goi 08–15, Arr 15–22 eta Gau 22–08';

  @override
  String get onboardingProfessionPoliceAbroad => 'Polizia';

  @override
  String get onboardingProfessionSecurityAbroad => 'Segurtasuna';

  @override
  String get onboardingProfessionHospitalityAbroad => 'Ostalaritza';

  @override
  String get onboardingProfessionIndustryAbroadHint =>
      'Txanda birakariak: Goi 06–14, Arr 14–22 eta Gau 22–06';

  @override
  String get onboardingProfessionCommerce => 'Merkataritza';

  @override
  String get onboardingProfessionCommerceHint => 'Goi 09–15 eta Arr 15–21';

  @override
  String get onboardingProfessionTransport => 'Garraioa';

  @override
  String get onboardingProfessionTransportHint =>
      'Goi 06–14, Arr 14–22 eta Gau 22–06';

  @override
  String get onboardingPlaceTitle => 'Non egiten duzu lan?';

  @override
  String get onboardingPlaceHelp =>
      'Zure erkidegoko eta udalerriko jaiegunak egutegian markatzeko.';

  @override
  String get onboardingPlaceHelpAbroad =>
      'Zure herrialdeko jaiegun ofizialak egutegian markatzeko.';

  @override
  String get onboardingCountryLabel => 'Herrialdea';

  @override
  String get onboardingCountrySheetTitle => 'Zure herrialdea';

  @override
  String get onboardingRegionLabel => 'Erkidegoa';

  @override
  String get onboardingRegionPick => 'Aukeratu erkidegoa';

  @override
  String get onboardingRegionSheetTitle => 'Zure erkidegoa';

  @override
  String get onboardingMunicipalityLabel => 'Udalerria (aukerakoa)';

  @override
  String get onboardingMunicipalityPick => 'Bilatu udalerria';

  @override
  String get onboardingMunicipalityNeedsRegion => 'Aukeratu lehenik erkidegoa';

  @override
  String get onboardingMunicipalitySheetTitle => 'Zure udalerria';

  @override
  String get onboardingMunicipalitySearch => 'Idatzi izena';

  @override
  String get onboardingMunicipalityNone => 'Ez dago izen hori duen udalerririk';

  @override
  String get onboardingMunicipalityClear => 'Kendu udalerria';

  @override
  String get onboardingLocalHolidaysMissing =>
      'Zure udalerriko tokiko jaiegunak zuk zeuk gehi ditzakezu, bi ukitutan.';

  @override
  String onboardingLocalHolidaysMissingYear(String year) {
    return 'Zure udalerriko tokiko jaiegunak oraindik ez dira argitaratu ($year): gehitu zuk zeuk bi ukitutan edo itxaron eguneratze bati.';
  }

  @override
  String onboardingCountryNoData(String country) {
    return 'Oraindik ez ditugu herrialde honetako jaiegun ofizialak: $country. Zureak Ezarpenak › Jaiegunak atalean gehi ditzakezu.';
  }

  @override
  String get onboardingCountryNone =>
      'Jaiegun ofizialik gabe. Zureak Ezarpenak › Jaiegunak atalean gehi ditzakezu.';

  @override
  String onboardingCountryIncluded(String country) {
    return 'Zure egutegian $country herrialdeko jaiegun ofizialak markatuko ditugu. Zureak Ezarpenak › Jaiegunak atalean gehi ditzakezu.';
  }

  @override
  String get onboardingRotationTitle => 'Nolakoa da zure txandaketa?';

  @override
  String get onboardingRotationHelp =>
      'Aukeratu antzekoena. Gero esango duzu noiz hasten zaren.';

  @override
  String get onboardingRotationTypical => 'Zure lanean ohikoena';

  @override
  String get onboardingRotationOthers => 'Beste txandaketa batzuk';

  @override
  String get onboardingRotationAll => 'Txandaketak';

  @override
  String get onboardingByHand => 'Eskuz margotuko dut';

  @override
  String get onboardingByHandHint =>
      'Txandaketarik gabe: zuk margotzen dituzu egunak egutegian.';

  @override
  String get onboardingStartTitle => 'Noiz hasten zara?';

  @override
  String get onboardingStartHelp =>
      'Esan zein egunetatik kontatzen den eta zikloaren zein puntutan zauden egun horretan.';

  @override
  String get onboardingImportTitle => 'Beste aplikazio batetik zatoz?';

  @override
  String get onboardingImportBody =>
      'Zure txandak LRHSoft (Shifter), Supershift edo beste aplikazio batean bazeneuzkan, ekarri itzazu haren kopiatik, mugikorreko egutegitik edo fitxategi batetik. Geroago ere egin dezakezu, Ezarpenak atalean.';

  @override
  String get onboardingReadyTitle => 'Prest';

  @override
  String get onboardingReadyBody =>
      'Zure egutegia prest dago. Hau guztia nahi duzunean alda dezakezu Ezarpenak atalean.';

  @override
  String onboardingReadyProfession(String name) {
    return 'Lana: $name';
  }

  @override
  String onboardingReadyPlace(String place) {
    return 'Jaiegunak: $place';
  }

  @override
  String onboardingReadyRotation(String name, String date) {
    return 'Txandaketa: $name; hasiera: $date';
  }

  @override
  String onboardingReadyOffset(int day, String shifts) {
    return 'Hasiera: zikloaren $day. eguna ($shifts)';
  }

  @override
  String get onboardingReadyByHand => 'Txandaketa: zuk margotzen duzu eskuz';

  @override
  String get onboardingReadyNoOfficialHolidays =>
      'Jaiegunak: zuk gehitzen dituzunak bakarrik';

  @override
  String get onboardingReadyNothing =>
      'Ez duzu ezer aukeratu; beraz, egutegi hutsarekin hasiko zara.';

  @override
  String get onboardingReadySaveFailed =>
      'Ezin izan da dena gorde. Berrikusi zure txandak eta jaiegunak Ezarpenak atalean.';

  @override
  String get onboardingOpenCalendar => 'Ikusi nire egutegia';

  @override
  String get onboardingTipTitle => 'Margotu zure hila berehala';

  @override
  String get onboardingTipBody =>
      'Sakatu Margotu, aukeratu txanda bat eta arrastatu egunen gainetik. Eredua botoiarekin txandaketa oso bat errepikatzen duzu behingoz.';

  @override
  String get onboardingTipDismiss => 'Ados';

  @override
  String get onboardingTipClose => 'Itxi aholkua';

  @override
  String get paintScrollUp => 'Gora egin hilabetean';

  @override
  String get paintScrollDown => 'Behera egin hilabetean';

  @override
  String get monthTipPaint => 'Aukeratu txanda bat eta arrastatu.';

  @override
  String get postNightAutoTitle => 'Gau-ondoko automatikoa';

  @override
  String get postNightAutoHelp =>
      'Gau baten ondoren, hurrengo eguna Gau-ondokoa bihurtzen da, hutsik edo libre bazegoen.';

  @override
  String get yearTitle => 'Urteko ikuspegia';

  @override
  String get yearOpenTooltip => 'Ikusi urtea';

  @override
  String get yearPrevious => 'Aurreko urtea';

  @override
  String get yearNext => 'Hurrengo urtea';

  @override
  String get yearShare => 'Partekatu irudi gisa';

  @override
  String yearShareSubject(int year) {
    return 'Nire txandak: $year';
  }

  @override
  String get yearShareFailed => 'Ezin izan da irudia partekatu';

  @override
  String yearImageTitle(int year) {
    return 'Nire txandak $year';
  }

  @override
  String get yearMonthEmpty => 'txandarik ez';

  @override
  String get yearLegendTitle => 'Urteko txandak';

  @override
  String get yearLegendEmpty => 'Urte honek ez du txandarik.';

  @override
  String yearLegendDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count egun',
      one: 'Egun 1',
    );
    return '$_temp0';
  }

  @override
  String get yearLegendHoliday => 'Jaieguna';

  @override
  String get summaryTitle => 'Laburpena';

  @override
  String get summaryOpenTooltip => 'Hileko laburpena';

  @override
  String get summaryModeMonth => 'Hila';

  @override
  String get summaryModeYear => 'Urtea';

  @override
  String get summaryModeRange => 'Datak…';

  @override
  String get summaryRangeFrom => 'Hasiera';

  @override
  String get summaryRangeTo => 'Amaiera';

  @override
  String get summaryRangePrevious => 'Aurreko aldia';

  @override
  String get summaryRangeNext => 'Hurrengo aldia';

  @override
  String summaryRangeDays(int count, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count egun guztira',
      one: 'Egun 1 guztira',
    );
    return '$_temp0. Gehienez $max egun aukera ditzakezu.';
  }

  @override
  String summaryRangeClamped(int max) {
    return 'Gehienez $max egun: amaiera-data laburtu dugu.';
  }

  @override
  String summaryRangePreviousName(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'aurreko $days egunak',
      one: 'aurreko eguna',
    );
    return '$_temp0';
  }

  @override
  String get summaryRangeEmptyTitle => 'Ez dago txandarik data hauetan';

  @override
  String get summaryRangeEmptyBody =>
      'Aukeratu beste data batzuk edo margotu txandak egutegian.';

  @override
  String get summaryRangeNoteMidnight =>
      'Gauerdia gainditzen duen txanda baten orduak hasten den egunean kontatzen dira, baita daten azken eguna bada ere.';

  @override
  String get summaryEmptyTitle => 'Ez dago txandarik hilabete honetan';

  @override
  String get summaryEmptyBody =>
      'Margotu txandak egutegian, eta hemen ikusiko dituzu orduak eta estimazioa.';

  @override
  String get summaryHoursWorked => 'Lan egindako orduak';

  @override
  String get summaryHoursPlanned => 'Aurreikusitako orduak';

  @override
  String summaryWorkedToDate(String hours) {
    return 'Atzo arte lan egindakoak: $hours';
  }

  @override
  String get summaryShiftsWorked => 'Lan egindako txandak';

  @override
  String get summaryNightHours => 'Gaueko orduak';

  @override
  String get summaryRestDays => 'Egun libreak';

  @override
  String get summaryAbsences => 'Absentziak';

  @override
  String get summaryHolidayHours => 'Jaiegunetako orduak';

  @override
  String summaryHolidayDetail(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count txanda jaiegunetan',
      one: 'Txanda 1 jaiegunean',
    );
    return '$_temp0';
  }

  @override
  String get summaryOvertime => 'Aparteko orduak';

  @override
  String get summaryEarlyLeave => 'Irteera aurreratuak';

  @override
  String summaryExtrasPay(String amount) {
    return 'Estimazioan: $amount';
  }

  @override
  String get summaryExtrasNoRate =>
      'Badaude aparteko orduak edo irteerak orduko prezioa duen txandarik gabeko egunetan: ez daude estimazioan.';

  @override
  String get summaryNoteExtras =>
      'Aparteko orduak eta irteera aurreratuak: egun bakoitzean idazten dituzunak. Aparteko orduak gehitu egiten zaizkie lan egindako orduei, eta irteerak kendu (egun bat ez da 0 h-tik jaisten). Irteerak eguneko azken txandaren amaiera mozten du, eta aparteko orduak haren ondoren doaz: horrela, gaueko eta jaiegunetako orduetan ere zenbatzen dira. Egun horretan prezioa duen lehen txandaren orduko prezioan baloratzen dira.';

  @override
  String summaryDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count egun',
      one: 'Egun 1',
    );
    return '$_temp0';
  }

  @override
  String summaryShifts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count txanda',
      one: 'Txanda 1',
    );
    return '$_temp0';
  }

  @override
  String summaryNightOf(String hours) {
    return '$hours gauez';
  }

  @override
  String get summaryNoTimes => 'ordutegirik gabe';

  @override
  String get summaryNoRate => 'prezio gabe';

  @override
  String get summaryGroupWork => 'Lan-txandak';

  @override
  String get summaryGroupRest => 'Atsedenak';

  @override
  String get summaryEstimateTitle => 'Diru-sarrera estimatuak';

  @override
  String get summaryFixedPluses => 'Osagarriak';

  @override
  String summaryFixedPlusCount(int count) {
    return '$count txanda';
  }

  @override
  String get summaryEstimateNote => 'Estimazioa, zergen aurretik';

  @override
  String get summaryEstimateNone =>
      'Jarri orduko prezioa edo txandako osagarria Nire txandak atalean estimazioa ikusteko.';

  @override
  String summaryEstimateMissing(String types) {
    return 'Orduko preziorik gabe, orduko ordainketa ez da sartzen: $types.';
  }

  @override
  String get summaryRateAction => 'Jarri prezioak Nire txandak atalean';

  @override
  String summaryDelta(String delta, String month) {
    return '$delta · alderaketa: $month';
  }

  @override
  String summaryDeltaSame(String month) {
    return 'Ordu berak, honekin alderatuta: $month';
  }

  @override
  String summaryDeltaNone(String month) {
    return 'Ez dago alderatzeko txandarik: $month';
  }

  @override
  String get summaryNotesTitle => 'Nola kontatzen da';

  @override
  String get summaryNoteMidnight =>
      'Gauerdia gainditzen duen txanda baten orduak hasten den egunean eta hilean kontatzen dira.';

  @override
  String get summaryNoteNight =>
      'Gaueko orduak: 22:00etatik 06:00etara, txandan beste zerbait markatzen ez baduzu.';

  @override
  String get summaryNoteDst =>
      'Erlojuko orduak dira: ordu-aldaketaren gauean ez da 7 edo 9 ordura egokitzen.';

  @override
  String get summaryNoteNoTimes =>
      'Ordutegirik gabeko txandak txanda gisa kontatzen dira, baina ez dute ordurik gehitzen.';

  @override
  String get summaryNoteHoliday =>
      'Jaiegunetako orduak: zure erkidegoko eta udalerriko jaiegun batean egiten direnak, baita txandak gauerdia gainditzen badu ere.';

  @override
  String get summaryNoteTense =>
      'Lan egindakoak: gaur aurreko egunak. Aurreikusitakoak: gaurtik aurrera, zure txanden egutegiaren arabera.';

  @override
  String get summaryNoteGoal =>
      'Helburua: hilabete batean urtekoaren hamabirena hartzen da; urte batean, hilekoa bider 12; data batzuetan, egun horiei dagokien zatia. Aldeak lan egindakoak eta aurreikusitakoak batzen ditu.';

  @override
  String get summaryGoalTitle => 'Ordu-helburua';

  @override
  String get summaryGoalAdd => 'Ezarri ordu-helburu bat';

  @override
  String get summaryGoalEdit => 'Aldatu helburua';

  @override
  String get summaryGoalTarget => 'Helburua';

  @override
  String get summaryGoalDone => 'Lan egindakoak';

  @override
  String get summaryGoalPlanned => 'Aurreikusitakoak';

  @override
  String summaryGoalShort(String hours) {
    return 'Falta zaizkizu: $hours';
  }

  @override
  String summaryGoalShortPlanned(String hours) {
    return 'Aurreikusitakoarekin, falta zaizkizu: $hours';
  }

  @override
  String summaryGoalOver(String hours) {
    return 'Soberan daramatzazu: $hours';
  }

  @override
  String summaryGoalOverPlanned(String hours) {
    return 'Aurreikusitakoarekin, soberan: $hours';
  }

  @override
  String get summaryGoalMet => 'Helburua zehatz-mehatz';

  @override
  String get summaryGoalMetPlanned =>
      'Aurreikusitakoarekin, helburua zehatz-mehatz';

  @override
  String get summaryGoalPerMonth => 'Hileko helburua';

  @override
  String get summaryGoalPerYear => 'Urteko helburua';

  @override
  String summaryGoalFromYear(String goal) {
    return 'Urtean $goal, zati 12';
  }

  @override
  String summaryGoalFromMonth(String goal) {
    return 'Hilean $goal, bider 12';
  }

  @override
  String summaryGoalRangeFromYear(String goal, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days egunei',
      one: 'egun bati',
    );
    return 'Urtean $goal, $_temp0 dagokien zatia';
  }

  @override
  String summaryGoalRangeFromMonth(String goal, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days egunei',
      one: 'egun bati',
    );
    return 'Hilean $goal bider 12, $_temp0 dagokien zatia';
  }

  @override
  String get summaryGoalChoiceYear => 'Urtean';

  @override
  String get summaryGoalChoiceMonth => 'Hilean';

  @override
  String get summaryGoalHoursYear => 'Orduak urtean';

  @override
  String get summaryGoalHoursMonth => 'Orduak hilean';

  @override
  String get summaryGoalHelpYear =>
      'Adibidez, 1.642 h, ohiko urteko lanaldia. Begiratu zure hitzarmenekoa. Hilabete bakoitzean hamabirena hartzen da.';

  @override
  String get summaryGoalHelpMonth =>
      'Adibidez, 140 h. Urtean 12 aldiz hartzen da.';

  @override
  String get summaryGoalUnit => 'h';

  @override
  String summaryGoalInvalid(int max) {
    return 'Idatzi 1 eta $max arteko ordu kopurua.';
  }

  @override
  String get summaryGoalRemove => 'Kendu helburua';

  @override
  String get summaryGoalSaveFailed => 'Ezin izan da helburua gorde.';

  @override
  String get summaryHowTitle => 'Nola noa?';

  @override
  String get summaryHowWorked => 'lan eginda';

  @override
  String get summaryHowWorkedToDate => 'lan eginda atzo arte';

  @override
  String get summaryHowPlanned => 'aurreikusita';

  @override
  String summaryHowPlannedRest(String hours, String date) {
    return 'eta $hours aurreikusita, $date arte';
  }

  @override
  String summaryHowBarLabel(String worked, String planned) {
    return 'Lan eginda: $worked. Aurreikusita: $planned';
  }

  @override
  String get summaryBreakdownTitle => 'Xehetasunak';

  @override
  String get summaryAbsencesNone => 'Bat ere ez';

  @override
  String get summaryEstimateNoPrices => 'Preziorik gabe';

  @override
  String get summaryYearEmpty => 'Urte honek ez du txandarik.';

  @override
  String get summaryYearHint => 'Ukitu hilabete bat xehetasunak ikusteko.';

  @override
  String get summaryYearHeaderMonth => 'Hila';

  @override
  String get summaryYearHeaderShifts => 'Txandak';

  @override
  String get summaryYearHeaderHours => 'Orduak';

  @override
  String get summaryYearHeaderNight => 'Gaua';

  @override
  String get summaryYearHeaderEstimate => 'Estimazioa';

  @override
  String get summaryYearTotal => 'Guztira';

  @override
  String summaryYearEstimated(String amount) {
    return 'Estimatua: $amount';
  }

  @override
  String get summaryYearMonthEmpty => 'Txandarik ez';

  @override
  String get summaryYearRowTitle => 'Orduak eta estimazioa';

  @override
  String get summaryYearRowBody =>
      'Hilabete bakoitzeko txandak, orduak eta zenbatekoak';

  @override
  String summaryYearMonthSemantics(String month, String shifts, String hours) {
    return '$month: $shifts, $hours';
  }

  @override
  String get shareMonthTooltip => 'Partekatu hila irudi gisa';

  @override
  String shareMonthSubject(String month) {
    return 'Nire txandak: $month';
  }

  @override
  String get shareMonthFailed => 'Ezin izan da irudia partekatu';

  @override
  String get shareMonthLegendTitle => 'Hileko txandak';

  @override
  String get shareMonthLegendEmpty => 'Hilabete honek ez du txandarik.';

  @override
  String get reportShareTooltip => 'Txostena PDF edo CSV formatuan';

  @override
  String get reportSheetTitle => 'Txanden txostena';

  @override
  String get reportSheetIntro =>
      'PDF garbi bat inprimatzeko edo bidaltzeko, edo kalkulu-orri bat zure txandekin.';

  @override
  String get reportFormatPdf => 'PDFa inprimatzeko edo bidaltzeko';

  @override
  String get reportFormatCsv => 'CSV Excel edo Sheets-erako';

  @override
  String get reportIncludeTitle => 'Zer sartu';

  @override
  String get reportIncludeNotes => 'Egunetako oharrak';

  @override
  String get reportIncludeEarnings => 'Zenbateko estimatuak';

  @override
  String get reportAbsencesTitle => 'Absentziak';

  @override
  String get reportAbsencesHidden => 'Ez erakutsi';

  @override
  String get reportAbsencesGeneric => '«Absentzia» gisa soilik';

  @override
  String get reportAbsencesDetailed => 'Izenarekin eta oharrarekin';

  @override
  String get reportAbsencesHint =>
      'Gaixotasun-baja bat ez da bere izenarekin edo oharrarekin agertzen, «Izenarekin eta oharrarekin» aukeratzen ez baduzu.';

  @override
  String get reportCreate => 'Sortu eta partekatu';

  @override
  String get reportFailed => 'Ezin izan da txostena sortu';

  @override
  String reportSubject(String period) {
    return 'Txandak: $period';
  }

  @override
  String get reportUntitled => 'Nire txandak';

  @override
  String get reportLegendTitle => 'Legenda';

  @override
  String get reportTotalsTitle => 'Guztira';

  @override
  String get reportNotesTitle => 'Oharrak';

  @override
  String get reportHolidaysTitle => 'Jaiegunak';

  @override
  String get reportHolidayMark => 'Jaieguna';

  @override
  String get reportAbsenceName => 'Absentzia';

  @override
  String get reportAbsenceCode => 'ABS';

  @override
  String get reportHoursTotal => 'Orduak';

  @override
  String get reportHoursDone => 'Atzora arte landuak';

  @override
  String get reportHoursPlannedFrom => 'Gaurtik aurrera aurreikusiak';

  @override
  String get reportFooter => 'Turnly-rekin sortua';

  @override
  String reportPageOf(int page, int total) {
    return 'Orria: $page/$total';
  }

  @override
  String get reportColDate => 'Data';

  @override
  String get reportColDay => 'Eguna';

  @override
  String get reportColShifts => 'Txanda';

  @override
  String get reportColCode => 'Kodea';

  @override
  String get reportColStart => 'Hasiera';

  @override
  String get reportColEnd => 'Amaiera';

  @override
  String get reportColHours => 'Orduak';

  @override
  String get reportColNote => 'Oharra';

  @override
  String get saveFailed => 'Ezin izan da aldaketa gorde';

  @override
  String get settingsTitle => 'Ezarpenak';

  @override
  String get settingsOpenTooltip => 'Ireki ezarpenak';

  @override
  String get settingsSectionSchedule => 'Nire egutegia';

  @override
  String get settingsShiftsTitle => 'Nire txandak';

  @override
  String get settingsShiftsSubtitle => 'Koloreak, kodeak eta orduak';

  @override
  String get settingsCalendarsTitle => 'Egutegiak';

  @override
  String get settingsSectionAppearance => 'Itxura';

  @override
  String get settingsThemeTitle => 'Gaia';

  @override
  String get settingsThemeSystemLight => 'Sistema (argia)';

  @override
  String get settingsThemeSystemDark => 'Sistema (iluna)';

  @override
  String get settingsThemeLight => 'Argia';

  @override
  String get settingsThemeDark => 'Iluna';

  @override
  String get appearanceAccentTitle => 'Azentu-kolorea';

  @override
  String get appearanceAccentIndigo => 'Indigoa';

  @override
  String get appearanceAccentBlue => 'Urdina';

  @override
  String get appearanceAccentPetrol => 'Petrolioa';

  @override
  String get appearanceAccentRaspberry => 'Mugurdia';

  @override
  String get appearanceAccentGraphite => 'Grafitoa';

  @override
  String get appearanceAccentDefault => 'Lehenetsia';

  @override
  String get appearanceAccentNote =>
      'Estekak, etengailuak, hautapena eta fitxak aldatzen ditu. Zure txanden koloreak ez dira aldatzen.';

  @override
  String get appearanceCellSizeTitle => 'Txandaren tamaina hilabetean';

  @override
  String get appearanceCellSizeNormal => 'Normala';

  @override
  String get appearanceCellSizeLarge => 'Handia';

  @override
  String get appearanceCellSizeExtraLarge => 'Oso handia';

  @override
  String get appearanceCellSizeNote =>
      'Hilabeteko egun bakoitzaren kodea eta ordua. Gelaxka batean sartzen ez badira, berez egokitzen dira.';

  @override
  String get appearanceCellSizeSampleCode => 'G';

  @override
  String get settingsWeekStartTitle => 'Asteko lehen eguna';

  @override
  String get settingsWeekStartMonday => 'Astelehena';

  @override
  String get settingsWeekStartSunday => 'Igandea';

  @override
  String get settingsWeekNumbersTitle => 'Erakutsi astearen zenbakia';

  @override
  String get settingsWeekNumbersSubtitle => 'Zutabe bat hilaren ezkerrean';

  @override
  String get settingsLanguageTitle => 'Hizkuntza';

  @override
  String settingsLanguageSystem(String language) {
    return 'Sistema ($language)';
  }

  @override
  String get languageNameEs => 'Español';

  @override
  String get languageNameCa => 'Català';

  @override
  String get languageNameGl => 'Galego';

  @override
  String get languageNameEu => 'Euskara';

  @override
  String get languageNameEn => 'English';

  @override
  String get settingsTimeFormatTitle => 'Ordu-formatua';

  @override
  String settingsTimeFormatAuto(String format) {
    return 'Automatikoa ($format)';
  }

  @override
  String get settingsTimeFormat24 => '24 h (22:00)';

  @override
  String get settingsTimeFormat12 => '12 h (10:00 PM)';

  @override
  String get settingsTimeFormatShort24 => '24 h';

  @override
  String get settingsTimeFormatShort12 => '12 h';

  @override
  String get settingsCurrencyTitle => 'Moneta';

  @override
  String get settingsCurrencyNote =>
      'Moneta aldatzeak ez ditu zenbatekoak bihurtzen. Berrikusi orduko prezioak eta osagarriak.';

  @override
  String get settingsCurrencySearchHint => 'Bilatu moneta edo kode bat';

  @override
  String get settingsCurrencyCommon => 'Ohikoenak';

  @override
  String get settingsCurrencyAll => 'Guztiak';

  @override
  String get settingsCurrencyNone => 'Ez dago bat datorren monetarik';

  @override
  String get settingsSaveFailed =>
      'Ezin izan da ezarpena gorde. Saiatu berriro.';

  @override
  String get settingsSectionMore => 'Abisuak eta widgeta';

  @override
  String get settingsSectionBackup => 'Kopiak eta mugikorrez aldatzea';

  @override
  String get settingsHolidaysTitle => 'Jaiegunak';

  @override
  String get settingsAlarmsTitle => 'Alarmak';

  @override
  String settingsAlarmsUntil(String date) {
    return 'Abisuak: $date arte';
  }

  @override
  String get settingsBackupTitle => 'Babeskopia';

  @override
  String settingsBackupLast(String when) {
    return 'Azkena: $when, egiaztatuta';
  }

  @override
  String get settingsPrivacyTitle => 'Pribatutasun-politika';

  @override
  String get settingsPrivacySubtitle => 'Zure nabigatzailean irekiko da';

  @override
  String get settingsPrivacyOpenFailed =>
      'Ezin izan da pribatutasun-politika ireki. Saiatu berriro.';

  @override
  String get faqAlarmsQIos =>
      'Nola konfiguratzen ditut alarmak, eta zer da jakinarazpenen baimena?';

  @override
  String get faqAlarmsAIos =>
      'Ezarpenak › Alarmak atalean, aktibatu «Abisatu txanda bakoitzaren aurretik», aukeratu zenbat lehenago eta, nahi baduzu, aurreko eguneko abisu bat ordu jakin batean. Egun baten xehetasunetan haren alarma ken dezakezu «Alarmarik ez egun honetan» aukerarekin.\n\nJakinarazpenen baimenik gabe, Turnly-k ezin dizu abisatu. Baimentzeko leihoa agertzen ez bazaizu, aktibatu sistemaren ezarpenetan.';

  @override
  String get faqWidgetAIos =>
      'Ezarpenak › Gehitu widgeta atalean tamainak ikusiko dituzu (txikia: gaur eta bihar; ertaina: hurrengo 7 egunak; handia: hilabete osoa) eta nola jarri. Eduki sakatuta hasierako pantaila, ukitu goiko + ikurra eta bilatu Turnly.\n\nWidgetak zure hurrengo egunak gordetzen ditu. Sistemak erabakitzen du noiz eguneratu, eta egun-aldaketa atzeratu dezake. Daturik gabe geratzen bada, ireki Turnly eguneratzeko.';

  @override
  String get faqBackupAIos =>
      'Ezarpenak › Babeskopia atalak kopia automatikoak gordetzen ditu gailu honetan aldaketa bakoitzaren ondoren, baina gailua galtzen baduzu edo aplikazioa desinstalatzen baduzu, galdu egiten dira. Esportatu fitxategi bat «Esportatu fitxategia» aukerarekin eta gorde iCloud Driven, edo bidali zeure buruari WhatsApp edo posta elektroniko bidez.\n\nGailuz aldatzeko: esportatu fitxategia, instalatu Turnly gailu berrian, ireki fitxategia aplikazioarekin (edo erabili «Inportatu fitxategia» babeskopian) eta berrikusi aurrebista leheneratu aurretik. «Probatu leheneratzea» aukerak egiaztatzen du zure azken kopia osorik berreskura daitekeela.';

  @override
  String get calExportPermissionDeniedBodyIos =>
      'Aktibatu sistemaren ezarpenetan (Turnly › Egutegiak) eta itzuli hona.';

  @override
  String get backupUiWarningIos =>
      'Kopia hauek gailu honetan gordetzen dira. Beste kopiarik gabe aplikazioa desinstalatzen baduzu, galdu egiten da. Esportatu fitxategi bat eta gorde iCloud Driven, edo bidali WhatsApp edo posta elektroniko bidez.';

  @override
  String get backupUiExportSubtitleIos =>
      'iCloud Driven gordetzeko edo WhatsApp edo posta elektroniko bidez bidaltzeko';

  @override
  String get settingsSectionHelp => 'Laguntza';

  @override
  String get settingsHelpTitle => 'Laguntza eta harremana';

  @override
  String get settingsHelpSubtitle => 'Idatzi iezaguzu zerbait ondo ez badabil';

  @override
  String get settingsHelpBody =>
      'Zalantzak dituzu edo zerbait ez dabil ondo? Kontatu zer gertatzen zaizun eta zein bertsio erabiltzen duzun.';

  @override
  String get settingsHelpSubtitleSoon =>
      'Laguntza-helbide elektronikoa prestatzen ari gara';

  @override
  String get settingsHelpBodySoon =>
      'Oraindik ez dugu laguntza-helbide elektronikorik. Bitartean, begiratu ohiko galderak eta, zerbait ondo ez badabil, izan eskura erabiltzen duzun bertsioa.';

  @override
  String get settingsHelpNoEmail =>
      'Laguntza-helbide elektronikoa dendako bertsioarekin iritsiko da.';

  @override
  String get settingsHelpCopyEmail => 'Kopiatu helbidea';

  @override
  String get settingsHelpCopyVersion => 'Kopiatu bertsioa';

  @override
  String get settingsFaqTitle => 'Ohiko galderak';

  @override
  String get settingsFaqSubtitle =>
      'Margotzea, txandaketak, alarmak, widgeta eta gehiago';

  @override
  String get faqIntro =>
      'Turnly nola dabilen azaltzeko erantzun azkarrak. Dena gailu honetan dago: ez da konturik ez konexiorik behar.';

  @override
  String get faqNotFound => 'Ez duzu bilatzen duzuna aurkitzen?';

  @override
  String get faqContact => 'Laguntza eta harremana';

  @override
  String get faqPaintQ => 'Nola margotzen dut hila?';

  @override
  String get faqPaintA =>
      'Sakatu «Margotu» egutegian, aukeratu txanda bat behean eta ukitu egunak edo pasatu hatza haien gainetik. Egun bat husteko, erabili «Ezabatu». Trazu bakoitza desegin eta berregin daiteke barrako geziekin. Sakatu «Eginda» amaitzean.\n\nMargotzen ari ez zarela egun bat ukitzen baduzu, haren xehetasunak irekitzen dira: han txanda aldatzen duzu, ohar bat gehitzen duzu edo eredura itzultzen zara. Egun bat sakatuta edukitzen baduzu, batzuk aldi berean aukeratzen hasiko zara: txanda jarri, kopiatu, ebaki eta itsatsi, edo aste bat errepikatu ditzakezu.';

  @override
  String get faqPatternQ =>
      'Nola aplikatzen dut txandaketa bat, eta zer da desfasea?';

  @override
  String get faqPatternA =>
      'Margotze moduan, sakatu «Eredua» botoia eta jarraitu urratsei: aukeratu zure txandaketa (edo sortu zurea), hasten zaren eguna eta noiz arte errepikatzen den.\n\nDesfasea hasierako egunean zikloaren zein puntutan zauden da. Egun horretan gaua egokitzen bazaizu, «Zikloaren zein egunetan zaude egun horretan?» urratsean gaua ukitzen duzu, eta gainerakoa bere kasa egokitzen da. Eskuz aldatu zenituen egunak errespetatu edo ordeztu egiten dira, nahiago duzun bezala. Txandaketa bat amaitzeko edo kentzeko, joan Ezarpenak › Nire txandaketak atalera.';

  @override
  String get faqDoubleQ => 'Nola bikoizten dut txanda bat?';

  @override
  String get faqDoubleA =>
      'Bikoiztea egun berean bi txanda egitea da. Ukitu eguna eta, haren xehetasunetan, erabili «Gehitu bigarren txanda». Margotzen ari bazara, aukeratu «Gehitu beste txanda bat» modua eta ukitu egunak. Egun batzuk aukeratuta, «Bikoiztu…» aukerak txanda guztiei gehitzen die.\n\nEgun batek behar dituzun txandak izan ditzake, eta bakoitzak bere orduak gehitzen ditu bereiz.';

  @override
  String get faqPostNightQ => 'Zer da gau-ondoko automatikoa?';

  @override
  String get faqPostNightA =>
      'Gau baten hurrengo eguneko atsedena da. Ezarpenak › Gau-ondoko automatikoa atalean aktibatzen baduzu, gau bat margotzean edo aplikatzean, hurrengo eguna Gau-ondokoa bihurtzen da, hutsik edo libre bazegoen. Beste txanda bat zuten egunak ez dira ukitzen. Desaktibatuta dator.';

  @override
  String get faqNotesQ => 'Nola erabiltzen ditut oharrak eta agenda?';

  @override
  String get faqNotesA =>
      'Ukitu egun bat eta idatzi oharraren eremuan; oharra duten egunak egutegian markatzen dira. Ireki agenda egutegiaren goiko aldean: «Oharrak» atalak oharrak eta jaiegun pertsonalak biltzen ditu; «Txandak» atalak hurrengo txandak erakusten ditu.\n\nBilatu testua, maiuskulak eta azentuak kontuan hartu gabe, edo data: adibidez, 15/10 edo urr 15. Bilaketak ohar eta jaiegun pertsonal guztiak hartzen ditu, baita duela urtebetetik datorren urtera arteko txandak ere.';

  @override
  String get faqAlarmsQ =>
      'Nola konfiguratzen ditut alarmak, eta zer da alarma zehatzen baimena?';

  @override
  String get faqAlarmsA =>
      'Ezarpenak › Alarmak atalean, aktibatu «Abisatu txanda bakoitzaren aurretik», aukeratu zenbat lehenago eta, nahi baduzu, aurreko eguneko abisu bat ordu jakin batean. Egun baten xehetasunetan haren alarma ken dezakezu «Alarmarik ez egun honetan» aukerarekin.\n\nAndroiden, jakinarazpenak eta sistemaren ezarpenetako «Alarmak eta abisuak» baimena behar dira: hori gabe, Androidek minutu batzuk atzeratu dezake abisua. Alarmen pantailak esaten dizu zer falta den eta ezarpenetara eramaten zaitu. Zure mugikorrak bateria modu oldarkorrean aurrezten badu, utzi Turnly murrizketarik gabe, abisuak geldi ez ditzan.';

  @override
  String get faqHolidaysQ => 'Nola gehitzen dut tokiko jaiegun bat?';

  @override
  String get faqHolidaysA =>
      'Ezarpenak › Jaiegunak atalean, aukeratu zure erkidegoa eta udalerria, eta dagozkizun jaiegunak ikusiko dituzu. Zure herrikoa falta bada, ukitu egun hori egutegian eta aktibatu «Jaiegun pertsonala»: izena jartzen diozu, eta une horretatik aurrera jaiegun gisa kontatzen da.\n\nMugikorreko egutegiko jaiegunak ere ekar ditzakezu, Ezarpenak › Jaiegunak atalean. Aukeratu egutegiak eta datak, eta berrikusi aurrebista: egun osoko gertaerak bakarrik irakurtzen dira, lehendik dituzun jaiegunak saltatzen dira eta ekintza desegin dezakezu. Ez da egutegiko gertaerarik aldatzen.';

  @override
  String get faqWidgetQ =>
      'Nola gehitzen dut widgeta, eta zergatik aldatzen da bere kasa?';

  @override
  String get faqWidgetA =>
      'Ezarpenak › Gehitu widgeta atalean tamainak ikusiko dituzu (txikia: gaur eta bihar; ertaina: hurrengo 7 egunak; handia: hilabete osoa) eta nola jarri. Androiden, eduki sakatuta hasierako pantailako gune huts bat, aukeratu Widgetak eta bilatu Turnly.\n\nWidgetak beti erakusten du gaurko eguna: gauerdian aldatzen da, aplikazioa ireki ez arren, hurrengo egunak gordeta dituelako. Denbora luzez Turnly ireki gabe egoten bazara, datuak agortzen zaizkio eta aplikazioa irekitzeko eskatzen dizu, eguneratzeko.';

  @override
  String get faqBackupQ => 'Nola egin kopia eta aldatu gailuz?';

  @override
  String get faqBackupA =>
      'Ezarpenak › Babeskopia atalak kopia automatikoak gordetzen ditu gailu honetan aldaketa bakoitzaren ondoren, baina gailua galtzen baduzu edo aplikazioa desinstalatzen baduzu, galdu egiten dira. Esportatu fitxategi bat «Esportatu fitxategia» aukerarekin eta gorde Driven, edo bidali zeure buruari WhatsApp edo posta elektroniko bidez.\n\nGailuz aldatzeko: esportatu fitxategia, instalatu Turnly gailu berrian, ireki fitxategia aplikazioarekin (edo erabili «Inportatu fitxategia» babeskopian) eta berrikusi aurrebista leheneratu aurretik. «Probatu leheneratzea» aukerak egiaztatzen du zure azken kopia osorik berreskura daitekeela.';

  @override
  String get faqImportQ =>
      'Nire txandak egutegira inportatu edo esporta ditzaket?';

  @override
  String get faqImportA =>
      'Bai. Ezarpenak › Inportatu txandak atalean, LRHSoft aplikazioaren «.Shifter» kopia bat, mugikorreko egutegiko txandak, .ics fitxategi bat edo CSV bat ekar ditzakezu. LRHSoft aplikazioan, sortu kopia bat Menua › Babeskopia › Tokiko kopia atalean, eta aukeratu Documents › ShifterBackups karpetako fitxategia. Berrikusi datak, txanda motak eta aurrebista inportatu aurretik.\n\n«Esportatu mugikorreko egutegira» aukerak behin kopiatzen ditu zure txandak telefonoko egutegi batera. Berriro esportatzen baduzu, ez dira bikoizten: Turnly-k sortutako gertaerak bakarrik ukitzen dira.';

  @override
  String get faqCalendarsQ =>
      'Egutegi bat baino gehiago izan eta alderatu ditzaket?';

  @override
  String get faqCalendarsA =>
      'Bai. Ezarpenak › Egutegiak atalean, egutegi bat sortzen duzu zure bikotearentzat, bigarren lan batentzat edo seme-alaba batentzat: bakoitzak bere txandaketak eta egunak ditu, eta txanda motak berak dira. Bi edo gehiago dituzunean, hilaren gaineko egutegi-izenarekin batetik bestera alda zaitezke. Widgetak eta alarmek «Widgeta eta alarmak» gisa markatutako egutegia jarraitzen dute.\n\nNoiz zaudeten biak libre ikusteko, sakatu «Alderatu egutegiak» orri berean: bi aukeratzen dituzu eta haien txandak elkarrekin ikusten dituzu, baita hilabeteko egun libre komunak ere.';

  @override
  String get faqSummaryQ => 'Nola kalkulatzen dira orduak eta dirua?';

  @override
  String get faqSummaryA =>
      'Egutegiko laburpen-ikonoak txandak, orduak, gaueko orduak eta jaiegunetakoak erakusten ditu, hilabetekoak, urte osokoak edo «Datak…» atalean aukeratzen dituzun datetakoak (366 egun arte). Txanda bat hasten den egunean kontatzen da, gauerdia gainditzen badu ere.\n\nZenbatekoak ikusteko, jarri txanden orduko prezioa eta, baduzu, txanda motaren osagarri finkoa Ezarpenak › Nire txandak atalean. Estimazioak osagarri finko horiek barne hartzen ditu, zergen aurretik, Ezarpenak › Itxura atalean aukeratzen duzun monetan. Ez ditu gaueko edo jaiegunetako orduen osagarriak ez atxikipenak barne hartzen.\n\n«Txandako osagarria» behin gehitzen da mota horretako txanda landu bakoitzeko, baita zatitutakoa bada ere; ez da ordu kopuruaren araberakoa. Atsedenek eta absentziek ez dute gehitzen.';

  @override
  String get settingsVersionCopied => 'Bertsioa kopiatu da';

  @override
  String get settingsEmailCopied => 'Helbidea kopiatu da';

  @override
  String get settingsAboutTitle => 'Honi buruz';

  @override
  String settingsAboutVersion(String version) {
    return 'Bertsioa: $version';
  }

  @override
  String get settingsAboutVersionDev => 'Garapen-bertsioa';

  @override
  String get settingsAboutTagline =>
      'Turnly-k konexiorik eta konturik gabe funtzionatzen du: zure txandak zure mugikorrean geratzen dira.';

  @override
  String get settingsAboutLicenses => 'Kode irekiko lizentziak';

  @override
  String calendarWeekNumberSemantics(int number) {
    return '$number. astea';
  }

  @override
  String get importSectionTitle => 'Inportatu eta esportatu';

  @override
  String get importRowTitle => 'Inportatu txandak';

  @override
  String get importRowSubtitle =>
      'LRHSoft kopia, mugikorreko egutegia, .ics edo CSV';

  @override
  String get calExportRowTitle => 'Esportatu txandak';

  @override
  String get calExportRowSubtitle => 'Mugikorreko egutegira, bikoiztu gabe';

  @override
  String get importTitle => 'Inportatu txandak';

  @override
  String importStepOf(int current, int total) {
    return 'Urratsa: $current/$total';
  }

  @override
  String get importNext => 'Hurrengoa';

  @override
  String get importReading => 'Irakurtzen…';

  @override
  String get importSourceTitle => 'Nondik datoz zure txandak?';

  @override
  String get importSourceHelp =>
      'Turnly-k hementxe irakurtzen ditu gertaerak, zure mugikorrean, eta ez ditu inora bidaltzen. Zuk erabakitzen duzu zer inportatzen den.';

  @override
  String get importSourceDevice => 'Mugikorreko egutegia';

  @override
  String get importSourceDeviceHelp =>
      'Google, iCloud, Outlook… egutegi-aplikazioan duzuna.';

  @override
  String get importSourceIcs => '.ics fitxategia';

  @override
  String get importSourceIcsHelp =>
      'Esportatutako egutegi bat, gertaera bakoitzeko txanda batekin.';

  @override
  String get importSourceCsv => 'CSV fitxategia';

  @override
  String get importSourceCsvHelp =>
      'Errenkada bakoitzean data bat eta txanda bat dituen orri bat.';

  @override
  String get importSourceLrhsoft => 'LRHSoft kopia (Txanden Egutegia)';

  @override
  String get importSourceLrhsoftHelp =>
      'Zure kopia lokaleko .Shifter fitxategia';

  @override
  String get importFileLrhsoft => 'LRHSoft kopia';

  @override
  String get importHowToTitle => 'LRHSoft edo Supershift aplikaziotik zatoz?';

  @override
  String get importHowToBody =>
      'LRHSoft edo Shifter: aplikazioan, Menua › Babeskopia › Kopia lokala. Gero, aukeratu hemen .Shifter fitxategi hori. Mugikorraren memorian dago: Documents › ShifterBackups.\nSupershift: esportatu zure txandak mugikorreko egutegira eta aukeratu «Mugikorreko egutegia».';

  @override
  String get calExportPermissionTitle => 'Egutegiaren baimena falta da';

  @override
  String get calExportPermissionReadBody =>
      'Inportatzeko, Turnly-k zure egutegietako gertaerak irakurri behar ditu. Orain bakarrik egiten du, inportatzen ari zaren bitartean, eta ez du ezer gordetzen mugikorretik kanpo.';

  @override
  String get calExportPermissionWriteBody =>
      'Zure txandak gehitzeko, Turnly-k zure egutegietarako sarbidea behar du. Bere gertaerak bakarrik gehitzen edo aldatzen ditu, eta zuk esportatzen duzunean bakarrik. Aukeratzen duzun egutegia kontu batekin sinkronizatzen bada (Google, iCloud...), kontu horrek ere jasoko ditu txandak.';

  @override
  String get calExportPermissionAgainBody =>
      'Ez duzu baimenik eman. Baimenik gabe ezin ditugu zure egutegiak erabili, baina orain eman dezakezu. Berriro ukatzen baduzu, sistemaren ezarpenetan aktibatu beharko duzu.';

  @override
  String get calExportPermissionAllow => 'Eman sarbidea';

  @override
  String get calExportPermissionDeniedTitle =>
      'Egutegirako sarbidea desaktibatuta dago';

  @override
  String get calExportPermissionDeniedBody =>
      'Aktibatu sistemaren ezarpenetan (Baimenak › Egutegia) eta itzuli hona.';

  @override
  String get calExportPermissionSettings => 'Ireki ezarpenak';

  @override
  String get calExportPermissionRecheck => 'Egiaztatu berriro';

  @override
  String get calExportPermissionRestrictedTitle =>
      'Mugikor honek ez du uzten egutegia erabiltzen';

  @override
  String get calExportPermissionRestrictedBody =>
      'Gurasoen kontrola edo laneko profil bat izan daiteke. Inportatzen ari bazara, probatu .ics fitxategi batekin.';

  @override
  String get calExportPermissionWriteOnlyBody =>
      'Sistemak gertaerak gehitzeko baimena bakarrik eman du. Turnly-k sarbide osoa behar du egutegiak irakurtzeko edo aurreko esportazio baten gertaerak ordezteko.';

  @override
  String get importCalendarsTitle => 'Aukeratu egutegiak';

  @override
  String get importCalendarsHelp =>
      'Markatu nondik datozen zure txandak. Besteak ez dira ukitzen.';

  @override
  String get importCalendarsEmpty => 'Ez dago egutegirik mugikor honetan.';

  @override
  String get importCalendarsNoAccount => 'Konturik gabe';

  @override
  String get importCalendarsReadOnly => 'Irakurtzeko soilik';

  @override
  String importCalendarSemantics(String name, String account) {
    return '$name, $account';
  }

  @override
  String get importRangeTitle => 'Zein datatakoak?';

  @override
  String get importRangeHelp =>
      'Egun hauetako gertaerak bakarrik begiratzen dira.';

  @override
  String get importRangeFrom => 'Hasiera';

  @override
  String get importRangeTo => 'Amaiera';

  @override
  String get importRangeDefault => 'Azken 12 hilabeteak eta hurrengo 6ak';

  @override
  String get importRangeInvalid =>
      'Amaiera-data ezin da hasiera-data baino lehenagokoa izan.';

  @override
  String get importRangeClamped => 'Gehienez 5 urte: hasiera moztu da.';

  @override
  String importRangeFile(String name) {
    return 'Fitxategia: $name';
  }

  @override
  String importRangeFileEvents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Fitxategiak $count gertaera dauzka.',
      one: 'Fitxategiak gertaera 1 dauka.',
    );
    return '$_temp0';
  }

  @override
  String importRangeFileSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count gertaerak ez dute data baliozkorik, eta ez dira irakurriko.',
      one: 'Gertaera batek ez du data baliozkorik, eta ez da irakurriko.',
    );
    return '$_temp0';
  }

  @override
  String importRangeFileRules(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count gertaerak ulertzen ez dugun errepikapen bat dute, eta behin bakarrik kontatzen dira.',
      one: 'Gertaera batek ulertzen ez dugun errepikapen bat du, eta behin bakarrik kontatzen da.',
    );
    return '$_temp0';
  }

  @override
  String get importColumnsTitle => 'Zer da zutabe bakoitza?';

  @override
  String get importColumnsHelp =>
      'Begiratu lehen errenkadak eta berretsi zein den data eta zein txanda.';

  @override
  String get importColumnsHeader => 'Lehen errenkadan izenburuak daude';

  @override
  String get importColumnDate => 'Data';

  @override
  String get importColumnTitle => 'Txanda edo kodea';

  @override
  String get importColumnStart => 'Hasiera-ordua (aukerakoa)';

  @override
  String get importColumnEnd => 'Amaiera-ordua (aukerakoa)';

  @override
  String get importColumnNone => 'Bat ere ez';

  @override
  String importColumnNumber(int number) {
    return '$number. zutabea';
  }

  @override
  String importColumnNamed(int number, String name) {
    return '$number: $name';
  }

  @override
  String get importColumnsScrollHint =>
      'Irristatu alboetara zutabe guztiak ikusteko.';

  @override
  String get importColumnsPreview => 'Lehen errenkadak';

  @override
  String get importMappingTitle => 'Zein txanda dagokio izenburu bakoitzari?';

  @override
  String get importMappingHelp =>
      'Gertaerak izenburuaren arabera taldekatzen ditugu. Aukeratu zure txandetako bat, sortu berri bat edo ez ikusi egin.';

  @override
  String importMappingSummary(int days, int groups) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days egun',
      one: 'Egun 1',
    );
    String _temp1 = intl.Intl.pluralLogic(
      groups,
      locale: localeName,
      other: '$groups izenburu',
      one: 'izenburu 1',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String importMappingTruncated(String limit) {
    return '$limit gertaera baino gehiago daude: lehenengoak bakarrik irakurri dira. Laburtu datak gainerakoak ikusteko.';
  }

  @override
  String importMappingSkippedRows(int count, int line) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count errenkada saltatu dira, ez dutelako data edo txanda baliozkorik (adibidez, lerro hau: $line).',
      one:
          'Errenkada bat saltatu da, ez duelako data edo txanda baliozkorik (adibidez, lerro hau: $line).',
    );
    return '$_temp0';
  }

  @override
  String get importMappingNothing =>
      'Aukeratu gutxienez izenburu bat inportatzeko.';

  @override
  String importGroupDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count egun',
      one: 'Egun 1',
    );
    return '$_temp0';
  }

  @override
  String get importGroupAllDay => 'Egun osoa';

  @override
  String importGroupExamples(String dates) {
    return 'adib. $dates';
  }

  @override
  String get importGroupUntitled => 'Izenbururik gabe';

  @override
  String get importMapIgnore => 'Ez ikusi egin';

  @override
  String get importMapCreate => 'Sortu mota berria';

  @override
  String get importMapChoose => 'Aukeratu txanda';

  @override
  String get importMapSuggested => 'Iradokia';

  @override
  String importMapNew(String name) {
    return 'Berria: $name';
  }

  @override
  String importMapPickTitle(String title) {
    return 'Zein txanda da «$title»?';
  }

  @override
  String importMapSemantics(String title, String choice) {
    return '$title: $choice';
  }

  @override
  String get importNewTypeTitle => 'Txanda mota berria';

  @override
  String get importNewTypeUse => 'Erabili mota hau';

  @override
  String get importPreviewTitle => 'Honela geratuko da';

  @override
  String get importPreviewHelp =>
      'Berrikusi hilabeteak. Ez da ezer gordeko Inportatu sakatu arte.';

  @override
  String importPreviewTarget(String name) {
    return 'Egutegi honetan inportatuko da: «$name».';
  }

  @override
  String importPreviewDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count egun idatziko dira.',
      one: 'Egun 1 idatziko da.',
    );
    return '$_temp0';
  }

  @override
  String importPreviewUnchanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count egun berdin zeuden jada.',
      one: 'Egun 1 berdin zegoen jada.',
    );
    return '$_temp0';
  }

  @override
  String importPreviewNewTypes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count txanda mota berri sortuko dira.',
      one: 'Txanda mota berri 1 sortuko da.',
    );
    return '$_temp0';
  }

  @override
  String get importPreviewEmpty => 'Aukera hauekin ez da egunik aldatzen.';

  @override
  String importPreviewMoreMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Eta erakutsi gabeko $count hilabete gehiago.',
      one: 'Eta erakutsi gabeko hilabete 1 gehiago.',
    );
    return '$_temp0';
  }

  @override
  String importConflictsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count egunek badute txanda jada',
      one: 'Egun batek badu txanda jada',
    );
    return '$_temp0';
  }

  @override
  String get importConflictsHelp => 'Zer egingo dugu haiekin?';

  @override
  String get importConflictReplace => 'Ordeztu';

  @override
  String get importConflictKeep => 'Mantendu nirea';

  @override
  String importConflictsExamples(String dates) {
    return 'Adibidez: $dates';
  }

  @override
  String importApply(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Inportatu $count egun',
      one: 'Inportatu egun 1',
    );
    return '$_temp0';
  }

  @override
  String importApplied(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count egun inportatu dira.',
      one: 'Egun 1 inportatu da.',
    );
    return '$_temp0';
  }

  @override
  String importAppliedWithTypes(int days, int types) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days egun inportatu dira',
      one: 'Egun 1 inportatu da',
    );
    String _temp1 = intl.Intl.pluralLogic(
      types,
      locale: localeName,
      other: '$types txanda mota berri barne',
      one: 'txanda mota berri 1 barne',
    );
    return '$_temp0, $_temp1.';
  }

  @override
  String get importUndoDone => 'Inportazioa desegin da.';

  @override
  String importUndoKeptTypes(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Motak «$names» geratzen dira: zerbaitek erabiltzen ditu.',
      one: 'Mota «$names» geratzen da: zerbaitek erabiltzen du.',
    );
    return '$_temp0';
  }

  @override
  String get importApplyFailed => 'Ezin izan da inportatu. Saiatu berriro.';

  @override
  String get importProblemPermissionDenied =>
      'Baimenik gabe ezin ditugu zure egutegiak irakurri.';

  @override
  String get importProblemPermissionRestricted =>
      'Mugikor honek ez dio Turnly-ri egutegia erabiltzen uzten. Probatu fitxategi batekin.';

  @override
  String get importProblemCalendarUnavailable =>
      'Mugikor honek ez du egutegirik erabilgarri.';

  @override
  String get importProblemReadFailed =>
      'Ezin izan dira gertaerak irakurri. Saiatu berriro.';

  @override
  String get importProblemFileTooLarge =>
      'Fitxategiak 5 MB baino gehiago ditu. Esportatzean, aukeratu data gutxiago.';

  @override
  String get importProblemFileUnreadable =>
      'Ezin izan dugu fitxategi hori ireki. .csv, .ics eta .Shifter (LRHSoft) fitxategiak onartzen ditugu.';

  @override
  String get importProblemNotCalendar =>
      'Fitxategi hori ez dirudi .ics egutegi bat.';

  @override
  String get importProblemNotCsv =>
      'Ez dugu daten zutaberik aurkitu CSV horretan.';

  @override
  String get importProblemNoEvents => 'Ez dago gertaerarik data horietan.';

  @override
  String get importProblemTooComplex =>
      'Fitxategi hori handiegia edo konplexuegia da, eta gehiegi behar du. Esportatzean, aukeratu data gutxiago.';

  @override
  String get importProblemUnknown =>
      'Zerbaitek huts egin du fitxategia irakurtzean. Probatu beste batekin.';

  @override
  String get importProblemNotLrhsoft =>
      'Fitxategi hori ez dirudi LRHSoft kopia bat (.Shifter). Saiatu beste kopia lokal bat sortzen.';

  @override
  String importRangeLrhsoftDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Kopiak $count egun dauzka.',
      one: 'Kopiak egun 1 dauka.',
    );
    return '$_temp0';
  }

  @override
  String importMappingInvalidRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Baliozkoak ez ziren $count errenkada baztertu dira.',
      one: 'Baliozkoa ez zen errenkada 1 baztertu da.',
    );
    return '$_temp0';
  }

  @override
  String get importLrhsoftNotImported =>
      'Alarmak, marrazkiak, argazkiak eta aparteko orduak ez dira ekartzen.';

  @override
  String importNoteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ohar',
      one: 'Ohar 1',
    );
    return '$_temp0';
  }

  @override
  String importApplyNotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Inportatu $count ohar',
      one: 'Inportatu ohar 1',
    );
    return '$_temp0';
  }

  @override
  String importAppliedNotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ohar inportatu dira.',
      one: 'Ohar 1 inportatu da.',
    );
    return '$_temp0';
  }

  @override
  String importPreviewNotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ohar gehituko dira.',
      one: 'Ohar 1 gehituko da.',
    );
    return '$_temp0';
  }

  @override
  String get calExportTitle => 'Esportatu txandak';

  @override
  String get calExportHelp =>
      'Zure txandak gertaera gisa gehitzen ditu mugikorreko egutegi batean, behin bakarrik. Errepikatzen baduzu, Turnly-k data horietako bere aurreko gertaerak ordezten ditu, bikoiztu beharrean.';

  @override
  String calExportSource(String name) {
    return 'Egutegi honetako txandak esportatuko dira: «$name».';
  }

  @override
  String get calExportCalendarLabel => 'Egutegia';

  @override
  String get calExportNewCalendar => 'Sortu «Turnly» egutegia';

  @override
  String get calExportNewCalendarHelp =>
      'Horrela, nahi duzunean ezkutatu edo osorik ezabatu ahal izango duzu.';

  @override
  String get calExportRangeLabel => 'Datak';

  @override
  String get calExportFrom => 'Hasiera';

  @override
  String get calExportTo => 'Amaiera';

  @override
  String get calExportIncludeRest => 'Sartu egun libreak';

  @override
  String get calExportIncludeRestHelp =>
      'Libre eta Gau-ondokoa ere gehitzen dira, egun osoko gertaera gisa.';

  @override
  String get calExportIncludeAbsences => 'Sartu absentziak';

  @override
  String get calExportIncludeAbsencesHelp =>
      'Oporrak, bajak eta beste absentzia batzuk. Egutegi horri eta harekin sinkronizatzen den kontuari gehituko litzaizkieke.';

  @override
  String calExportSynced(String account) {
    return 'Egutegi hau kontu honekin sinkronizatzen da: $account. Zure txandak bertan ikusiko dira.';
  }

  @override
  String get calExportSyncedUnnamed =>
      'Egutegi hau kontu batekin sinkronizatzen da: zure txandak bertan ikusiko dira.';

  @override
  String calExportPlanAdd(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gertaera gehituko dira.',
      one: 'Gertaera 1 gehituko da.',
    );
    return '$_temp0';
  }

  @override
  String calExportPlanReplace(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Aurreko esportazio bateko $count gertaera ordeztuko dira.',
      one: 'Aurreko esportazio bateko gertaera 1 ordeztuko da.',
    );
    return '$_temp0';
  }

  @override
  String calExportPlanRemove(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Aurreko esportazio bateko $count gertaera kenduko dira.',
      one: 'Aurreko esportazio bateko gertaera 1 kenduko da.',
    );
    return '$_temp0';
  }

  @override
  String calExportPlanSame(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gertaera eguneratuta daude jada.',
      one: 'Gertaera 1 eguneratuta dago jada.',
    );
    return '$_temp0';
  }

  @override
  String get calExportPlanNothing =>
      'Dena eguneratuta dago: ez dago ezer aldatzeko.';

  @override
  String get calExportPlanNone => 'Ez dago txandarik data horietan.';

  @override
  String get calExportButton => 'Esportatu';

  @override
  String calExportRunning(int done, int total) {
    return 'Esportatzen… $done/$total';
  }

  @override
  String get calExportDoneTitle => 'Esportazioa eginda';

  @override
  String get calExportDoneCalendar => '«Turnly» egutegia sortu da.';

  @override
  String calExportDoneCreated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gertaera gehitu dira',
      one: 'Gertaera 1 gehitu da',
    );
    return '$_temp0';
  }

  @override
  String calExportDoneReplaced(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Aurreko $count gertaera ordeztu dira',
      one: 'Aurreko gertaera 1 ordeztu da',
    );
    return '$_temp0';
  }

  @override
  String calExportDoneRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gertaera kendu dira',
      one: 'Gertaera 1 kendu da',
    );
    return '$_temp0';
  }

  @override
  String calExportDoneSame(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gertaera eguneratuta zeuden jada',
      one: 'Gertaera 1 eguneratuta zegoen jada',
    );
    return '$_temp0';
  }

  @override
  String calExportDoneFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Ezin izan dira $count gertaera idatzi. Esportatu berriro osatzeko.',
      one: 'Ezin izan da gertaera 1 idatzi. Esportatu berriro osatzeko.',
    );
    return '$_temp0';
  }

  @override
  String get calExportProblemPermission =>
      'Baimenik gabe ezin dugu zure egutegian idatzi.';

  @override
  String get calExportProblemUnavailable =>
      'Mugikor honek ez du egutegirik erabilgarri.';

  @override
  String get calExportProblemFailed =>
      'Ezin izan da esportatu. Saiatu berriro.';

  @override
  String get calExportRangeClamped => 'Gehienez urtebete: amaiera moztu da.';

  @override
  String get calSyncTitle => 'Eguneratuta mantendu';

  @override
  String get calSyncHelp =>
      'Turnly-k berak eguneratzen ditu gertaera horiek, txanden egutegia aldatzen duzun bakoitzean eta aplikazioa irekitzean: duela astebetetik hurrengo hiru hilabeteetara. Berak sortutako gertaerei bakarrik eragiten die. Itzaltzen baduzu, dagoeneko daudenak han geratzen dira.';

  @override
  String calSyncLast(String when) {
    return 'Azken eguneratzea: $when';
  }

  @override
  String calSyncFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Ezin izan dira $count gertaera eguneratu. Hurrengo eguneratzean berriro saiatuko da.',
      one: 'Ezin izan da gertaera 1 eguneratu. Hurrengo eguneratzean berriro saiatuko da.',
    );
    return '$_temp0';
  }

  @override
  String get calSyncLocked =>
      'Beste egutegi bat aukeratzeko, itzali lehenago «Eguneratuta mantendu».';

  @override
  String get calSyncRunning => 'Egutegia eguneratzen…';

  @override
  String get calSyncNoticePermission =>
      '«Eguneratuta mantendu» itzali egin da: Turnly-k ez du jada zure egutegia erabiltzeko baimenik.';

  @override
  String get calSyncNoticeCalendarGone =>
      '«Eguneratuta mantendu» itzali egin da: mugikorreko egutegia ez dago jada edo izena aldatu du.';

  @override
  String get calSyncNoticeSourceGone =>
      '«Eguneratuta mantendu» itzali egin da: esportatzen zen Turnly-ko egutegia ez da jada existitzen.';

  @override
  String get calSyncNoticeDismiss => 'Ulertuta';

  @override
  String get calExportIcsTitle => 'Gorde .ics fitxategi gisa';

  @override
  String get calExportIcsHelp =>
      'Google Calendar, Outlook eta Apple Calendar-ek irekitzen duten fitxategia, nahi duzunera bidaltzeko edo gordetzeko. Ez du baimenik behar.';

  @override
  String calExportIcsRange(String from, String to) {
    return 'Noiztik: $from. Noiz arte: $to';
  }

  @override
  String get calExportIcsButton => 'Gorde .ics fitxategia';

  @override
  String get calExportIcsRunning => 'Fitxategia prestatzen…';

  @override
  String get calExportIcsFailed =>
      'Ezin izan da fitxategia sortu. Saiatu berriro.';

  @override
  String get shareLinkRowTitle => 'Partekatu esteka bidez';

  @override
  String get shareLinkRowSubtitle =>
      'Zure familiak zure txandak ikusten ditu bere egutegian';

  @override
  String get shareLinkRowPublished => 'Esteka argitaratuta';

  @override
  String get shareLinkTitle => 'Partekatu esteka bidez';

  @override
  String get shareLinkIntro =>
      'Argitaratu irakurtzeko soilik den esteka bat: daukanak zure txandak ikusiko ditu bere egutegian (Google, Apple, Outlook), ezer instalatu gabe. Bere kabuz eguneratzen da txanden egutegia aldatzen duzunean.';

  @override
  String get shareLinkUnavailableTitle => 'Oraindik ez dago erabilgarri';

  @override
  String get shareLinkUnavailableBody =>
      'Bertsio honek oraindik ezin du estekarik argitaratu. Bitartean, zure txandak .ics fitxategi gisa gorde ditzakezu Esportatu txandak atalean.';

  @override
  String get shareLinkCalendarLabel => 'Egutegia';

  @override
  String get shareLinkOptionsLabel => 'Zer partekatzen den';

  @override
  String get shareLinkIncludeRest => 'Sartu egun libreak';

  @override
  String get shareLinkIncludeRestHelp =>
      'Libre eta Gau-ondokoa, egun osoko gertaera gisa.';

  @override
  String get shareLinkIncludeAbsences => 'Erakutsi absentziak «Absentzia» gisa';

  @override
  String get shareLinkIncludeAbsencesHelp =>
      'Arrazoirik gabe: ez da jakiten baja, oporrak edo norberaren eguna den.';

  @override
  String get shareLinkPrivacyTitle => 'Zer ateratzen den eta zer ez';

  @override
  String get shareLinkPrivacyBody =>
      'Txanda bakoitzaren izena, kodea eta ordua ateratzen dira, eta egutegiaren izena. Ez dira inoiz ateratzen zure oharrak, bajak edo absentzien arrazoiak. Esteka daukanak zure txandak ikus ditzake: nahi duzunari bakarrik eman, eta baliogabetu nahi duzunean.';

  @override
  String get shareLinkPublishButton => 'Argitaratu esteka';

  @override
  String get shareLinkPublishConfirmTitle => 'Zure txandak argitaratu?';

  @override
  String get shareLinkPublishConfirmBody =>
      'Zure txandak Turnly-ren zerbitzarira igoko dira esteka ibil dadin. Hori da aplikazioak mugikorretik kanpora bidaltzen duen gauza bakarra. Esteka baliogabetzean edo sei hilabetez eguneratu gabe egon ondoren ezabatzen dira.';

  @override
  String get shareLinkPublishConfirm => 'Argitaratu';

  @override
  String get shareLinkQrLabel => 'Zure txanden esteka duen QR kodea';

  @override
  String get shareLinkLinkLabel => 'Esteka';

  @override
  String get shareLinkCopy => 'Kopiatu';

  @override
  String get shareLinkCopied => 'Esteka kopiatuta';

  @override
  String get shareLinkShare => 'Partekatu';

  @override
  String shareLinkShareText(String url) {
    return 'Nire txandak Turnly-n. Gehitu zure egutegira esteka honekin: $url';
  }

  @override
  String shareLinkLastPublished(String date) {
    return 'Azken argitalpena: $date';
  }

  @override
  String get shareLinkPublishing => 'Argitaratzen…';

  @override
  String get shareLinkWaiting => 'Laster eguneratuko da.';

  @override
  String get shareLinkNotPublished => 'Oraindik ezin izan da argitaratu.';

  @override
  String get shareLinkRefresh => 'Eguneratu orain';

  @override
  String shareLinkSharedCalendar(String name) {
    return 'Egutegi honen txandak partekatzen dira: $name.';
  }

  @override
  String get shareLinkCalendarMissing =>
      'Partekatzen zenuen egutegia ez dago jada. Aukeratu beste bat esteka eguneratzen jarraitzeko.';

  @override
  String get shareLinkHowTitle => 'Nola harpidetu';

  @override
  String get shareLinkHowBody =>
      'Google Calendar-en: Beste egutegi batzuk › URL bidez, eta itsatsi esteka. iPhone-an: ireki esteka, edo joan Ezarpenak › Egutegia › Kontuak › Gehitu kontua › Bestelakoa › Gehitu harpidetutako egutegia. Egutegi bakoitzak erabakitzen du noizero begiratzen dituen aldaketak: ordu batzuk behar ditzakete.';

  @override
  String get shareLinkRevoke => 'Baliogabetu esteka';

  @override
  String get shareLinkRevokeConfirmTitle => 'Esteka baliogabetu?';

  @override
  String get shareLinkRevokeConfirmBody =>
      'Zerbitzaritik ezabatzen da eta inorentzat ez du funtzionatzen. Berriro argitaratzen baduzu, esteka berri bat sortzen da.';

  @override
  String get shareLinkRevokeConfirm => 'Baliogabetu';

  @override
  String get shareLinkRevoking => 'Baliogabetzen…';

  @override
  String get shareLinkRevokePending =>
      'Baliogabetzea zain dago: laster saiatuko da berriro bere kabuz. Bitartean ez da ezer argitaratzen.';

  @override
  String get shareLinkProblemNetwork =>
      'Ez dago zerbitzariarekin konexiorik. Geroago saiatuko gara berriro.';

  @override
  String get shareLinkProblemRateLimited =>
      'Eguneratze gehiegi jarraian. Laster saiatuko gara berriro.';

  @override
  String get shareLinkProblemTooLarge =>
      'Txanden egutegia handiegia da argitaratzeko.';

  @override
  String get shareLinkProblemRejected =>
      'Zerbitzariak ez du esteka onartu. Baliogabetu eta argitaratu berri bat.';

  @override
  String get shareLinkProblemRevoked =>
      'Esteka hau baliogabetu egin zen eta ez du funtzionatzen. Argitaratu berri bat zure txandak berriro partekatu nahi badituzu.';

  @override
  String get shareLinkProblemServer => 'Ezin izan da osatu. Saiatu berriro.';

  @override
  String get shareLinkAbsence => 'Absentzia';

  @override
  String get onboardingImportButton => 'Inportatu orain';

  @override
  String get onboardingImportLrhsoftButton => 'Inportatu LRHSoft kopia';

  @override
  String get backupUiRowSubtitle => 'Automatikoa, esportatu eta inportatu';

  @override
  String get backupUiStatusNoneTitle => 'Oraindik ez dago kopiarik';

  @override
  String get backupUiStatusNoneBody =>
      'Egin bat orain: segundo bat behar du. Kopiarik ez duzun bitartean, gailua galtzen baduzu edo aplikazioa desinstalatzen baduzu, zure txanden egutegia galduko da.';

  @override
  String get backupUiStatusLast => 'Azken kopia';

  @override
  String get backupUiStatusWhere => 'Gailu honetan';

  @override
  String get backupUiStatusVerified => 'Egiaztatuta: osorik berreskura daiteke';

  @override
  String get backupUiStatusRunning => 'Kopia gordetzen…';

  @override
  String get backupUiStatusPending =>
      'Aldaketa berriak daude: segundo batzuk barru egingo da kopia.';

  @override
  String backupUiStatusPendingAt(String time) {
    return 'Aldaketa berriak daude: hurrengo kopia $time inguruan egingo da. Itxaron nahi ez baduzu, sakatu «Egin kopia orain».';
  }

  @override
  String get backupUiStatusPendingLater =>
      'Aldaketa berriak daude: hurrengo kopia minutu batzuen buruan egingo da. Itxaron nahi ez baduzu, sakatu «Egin kopia orain».';

  @override
  String get backupUiStatusFailedTitle =>
      'Azken kopia automatikoak huts egin du';

  @override
  String backupUiStatusFailedWithGood(String when, String good) {
    return 'Saiatu gara ($when), baina ezin izan da gorde. Azken kopia ona: $good.';
  }

  @override
  String backupUiStatusFailedNoGood(String when) {
    return 'Saiatu gara ($when), baina ezin izan da gorde. Oraindik ez duzu kopia onik.';
  }

  @override
  String get backupUiFailDiskFull => 'Gailuak ez du leku librerik.';

  @override
  String get backupUiFailGeneric => 'Ezin izan da kopiaren fitxategia idatzi.';

  @override
  String get backupUiRetry => 'Saiatu berriro';

  @override
  String get backupUiSystemOn => 'Androideko sistemaren babeskopia: aktibatuta';

  @override
  String get backupUiSystemOff =>
      'Androideko sistemaren babeskopia: desaktibatuta. Aktibatu Androideko ezarpenetan beste kopia bat izateko.';

  @override
  String get backupUiSystemUnknown =>
      'Androideko sistemaren babeskopia: ezin dugu aplikaziotik egiaztatu. Begiratu Androideko ezarpenetan aktibatuta dagoela.';

  @override
  String get backupUiWarning =>
      'Kopia hauek gailu honetan gordetzen dira. Beste kopiarik gabe aplikazioa desinstalatzen baduzu, galdu egiten da. Esportatu fitxategi bat eta gorde Driven, edo bidali WhatsApp edo posta elektroniko bidez.';

  @override
  String get backupUiBackupNow => 'Egin kopia orain';

  @override
  String get backupUiBackupDone => 'Kopia eginda';

  @override
  String get backupUiBackupFailed =>
      'Ezin izan da kopia egin. Zure datuak lehen bezala daude.';

  @override
  String backupWarnRestoreSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Lehenago egin dugun kopiak ez dauzka $count eranskin: haien fitxategiak ez zeuden edo ezin izan ziren irakurri.',
      one: 'Lehenago egin dugun kopiak ez dauka eranskin 1: haren fitxategia ez zegoen edo ezin izan zen irakurri.',
    );
    return '$_temp0';
  }

  @override
  String backupWarnCopySkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Kopia eginda, baina $count eranskin gabe: haien fitxategiak ez daude edo ezin dira irakurri.',
      one: 'Kopia eginda, baina eranskin 1 gabe: haren fitxategia ez dago edo ezin da irakurri.',
    );
    return '$_temp0';
  }

  @override
  String get backupUiAutoTitle => 'Kopia automatikoak';

  @override
  String get backupUiAutoOn =>
      'Zerbait aldatu ondoren, konturatu gabe. Azken 7ak gordetzen ditugu, eta egunean bat 30 egunez.';

  @override
  String get backupUiAutoOff =>
      'Desaktibatuta: zuk eskatzen duzunean bakarrik egiten da kopia.';

  @override
  String get autoBackupFolderTitle => 'Kopia automatikoa karpeta batean';

  @override
  String get autoBackupFolderIntro =>
      'Egunean kopia bat zuk aukeratutako karpetan: Drive, Dropbox, OneDrive edo gailuko karpeta bat. Gailua galtzen baduzu, han izango duzu. Azken 10ak gordetzen ditugu.';

  @override
  String get autoBackupFolderPrivacy =>
      'Kopiak zure txanden egutegi osoa darama, absentziak eta baja medikoak barne, eta karpeta hori dagoen tokian gordetzen da (adibidez, zure hodeian). Ez da konturik behar Turnly erabiltzeko.';

  @override
  String get autoBackupFolderChoose => 'Aukeratu karpeta';

  @override
  String get autoBackupFolderChooseSubtitle =>
      'Sistemaren karpeta-hautatzailea irekiko da';

  @override
  String get autoBackupFolderFolder => 'Karpeta';

  @override
  String get autoBackupFolderUnnamed => 'Aukeratutako karpeta';

  @override
  String get autoBackupFolderChange => 'Sakatu beste bat aukeratzeko';

  @override
  String autoBackupFolderLast(String when) {
    return 'Karpetako azken kopia: $when';
  }

  @override
  String get autoBackupFolderNone => 'Oraindik ez dago kopiarik karpetan.';

  @override
  String get autoBackupFolderSchedule =>
      'Egunean behin kopiatzen da eta, aplikazioa irekita dagoenean, zure aldaketen ondoren (gehienez 6 orduan behin).';

  @override
  String get autoBackupFolderCopyNow => 'Kopiatu orain karpetan';

  @override
  String get autoBackupFolderCopyDone => 'Kopia karpetan gorde da';

  @override
  String get autoBackupFolderVerify => 'Probatu karpetako kopia';

  @override
  String get autoBackupFolderVerifySubtitle =>
      'Karpetako azken kopia osorik berreskura daitekeela egiaztatzen du';

  @override
  String get autoBackupFolderStop => 'Utzi karpeta honetan kopiatzeari';

  @override
  String get autoBackupFolderStopSubtitle =>
      'Karpetan dauden kopiak ez dira ezabatzen';

  @override
  String get autoBackupFolderStopped =>
      'Jada ez da kopiarik egiten karpeta horretan';

  @override
  String get autoBackupFolderFailedTitle =>
      'Karpetako kopiak ez du funtzionatzen';

  @override
  String autoBackupFolderFailedWhen(String when) {
    return 'Azken saiakera: $when.';
  }

  @override
  String get autoBackupFolderErrRevoked =>
      'Turnlyk jada ez du karpeta hori erabiltzeko baimenik. Aukeratu berriro.';

  @override
  String get autoBackupFolderErrMissing =>
      'Ez dugu karpeta aurkitu: agian ezabatu edo lekuz aldatu da. Aukeratu beste bat.';

  @override
  String get autoBackupFolderErrUnwritable =>
      'Karpeta horrek ez du fitxategiak gordetzen uzten. Aukeratu beste bat.';

  @override
  String get autoBackupFolderErrNoSpace =>
      'Ez dago lekurik karpeta dagoen tokian (gailuan edo zure hodeian). Egin lekua eta saiatu berriro.';

  @override
  String get autoBackupFolderErrTooLarge => 'Kopia handiegia da gordetzeko.';

  @override
  String get autoBackupFolderErrFailed =>
      'Ezin izan da kopia karpetan gorde. Berriro saiatuko gara.';

  @override
  String get autoBackupFolderErrDamaged =>
      'Ezin izan dugu karpetako kopiaren konfigurazioa irakurri. Aukeratu karpeta berriro.';

  @override
  String get autoBackupFolderChooseAgain => 'Aukeratu karpeta berriro';

  @override
  String get autoBackupFolderPickFailed =>
      'Ezin izan da karpeta hori erabili. Saiatu beste batekin.';

  @override
  String get backupUiSectionFile => 'Fitxategia';

  @override
  String get backupUiSectionCheck => 'Egiaztatu';

  @override
  String get backupUiSectionCopies => 'Gailu honetako kopiak';

  @override
  String get backupUiExport => 'Esportatu fitxategia';

  @override
  String get backupUiSaveOutside => 'Gorde kopia bat Turnly-tik kanpo';

  @override
  String get backupUiSaveOutsideHelp =>
      'Zure hodeian, beste gailu batean edo posta bidez. Mugikorra galtzen baduzu edo aldatzen baduzu, «Inportatu fitxategia» erabiliz berreskuratuko duzu.';

  @override
  String get backupUiExportSubtitle =>
      'Driven gordetzeko edo WhatsApp edo posta elektroniko bidez bidaltzeko';

  @override
  String get backupUiExportFailed => 'Ezin izan da fitxategia esportatu.';

  @override
  String get backupUiSave => 'Gorde gailuan';

  @override
  String get backupUiSaveSubtitle =>
      'Aukeratu karpeta bat; adibidez, Deskargak';

  @override
  String get backupUiSaveDone => 'Fitxategia gorde da';

  @override
  String get backupUiSaveFailed =>
      'Ezin izan da fitxategia gorde. Saiatu beste karpeta batekin edo erabili «Esportatu fitxategia».';

  @override
  String get backupUiImport => 'Inportatu fitxategia';

  @override
  String get backupUiImportSubtitle => 'Berreskuratu Turnly-ren fitxategi bat';

  @override
  String get backupUiVerify => 'Probatu leheneratzea';

  @override
  String get backupUiVerifySubtitle =>
      'Zure azken kopia osorik berreskura daitekeela egiaztatzen du';

  @override
  String get backupUiVerifyRunning => 'Kopia egiaztatzen…';

  @override
  String get backupUiVerifyNone =>
      'Oraindik ez dago probatzeko kopiarik. Egin bat lehenik.';

  @override
  String backupUiVerifyOk(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Kopia osorik dago: $days egun egiaztatu dira',
      one: 'Kopia osorik dago: egun 1 egiaztatu da',
    );
    return '$_temp0';
  }

  @override
  String get backupUiVerifySame => 'Orain duzunaren berdina da.';

  @override
  String backupUiVerifyOlder(String day) {
    return 'Orain duzuna baino zaharragoa da (aldatzen den lehen eguna: $day). Normala da geroago aldaketak egin badituzu.';
  }

  @override
  String get backupUiVerifyOlderNoDay =>
      'Orain duzuna baino zaharragoa da. Normala da geroago aldaketak egin badituzu.';

  @override
  String backupUiVerifyMismatch(String day) {
    return 'Kopia ez da berdin berreraikitzen. Desberdina den lehen eguna: $day. Egin kopia berri bat eta jakinarazi iezaguzu.';
  }

  @override
  String get backupUiVerifyMismatchNoDay =>
      'Kopia ez da berdin berreraikitzen: gordetako datuak ez datoz bat. Egin kopia berri bat eta jakinarazi iezaguzu.';

  @override
  String backupUiVerifyError(String reason) {
    return 'Ezin izan da kopia probatu. $reason';
  }

  @override
  String get backupUiCopiesEmpty => 'Zure kopiak hemen agertuko dira.';

  @override
  String get backupUiCopyLocal => 'Gailuko kopia';

  @override
  String get backupUiCopySafety => 'Leheneratu aurretik';

  @override
  String backupUiCopyMeta(String kind, String size) {
    return '$kind · $size';
  }

  @override
  String backupUiCopyMetaVersion(String kind, String version, String size) {
    return '$kind · $version · $size';
  }

  @override
  String get backupUiCopyRestore => 'Leheneratu hau';

  @override
  String backupUiCopyRestoreLabel(String when) {
    return 'Leheneratu kopia ($when)';
  }

  @override
  String backupUiWhenToday(String time) {
    return 'gaur, $time';
  }

  @override
  String backupUiWhenYesterday(String time) {
    return 'atzo, $time';
  }

  @override
  String backupUiWhenDate(String date, String time) {
    return '$date, $time';
  }

  @override
  String get backupUiPreviewTitle => 'Leheneratu kopia';

  @override
  String get backupUiPreviewReading => 'Fitxategia irakurtzen…';

  @override
  String get backupUiOriginFile => 'Aukeratu duzun fitxategia';

  @override
  String get backupUiOriginShared =>
      'Beste aplikazio batetik jasotako fitxategia';

  @override
  String get backupUiOriginLocal => 'Gailu honetako kopia';

  @override
  String get backupUiOriginSafety => 'Leheneratu aurretik egindako kopia';

  @override
  String get backupUiOriginCloud => 'iCloudeko kopia';

  @override
  String backupUiPreviewSaved(String when) {
    return 'Gordeta: $when';
  }

  @override
  String backupUiPreviewSender(String sender) {
    return 'Bidaltzailea: $sender';
  }

  @override
  String get backupUiPreviewSenderHint =>
      'Gailuak adierazten du. Fitxategi hau espero ez bazenuen, utzi.';

  @override
  String get backupUiPreviewTurnsOffTitle =>
      'Kopia honek aktibatuta dituzun ezarpenak desaktibatzen ditu';

  @override
  String get backupUiPreviewTurnsOffAuto =>
      'Kopia automatikoak desaktibatzen ditu.';

  @override
  String get backupUiPreviewTurnsOffAlarms =>
      'Txanden alarmak desaktibatzen ditu.';

  @override
  String get backupUiPreviewContains => 'Zer dakar';

  @override
  String backupUiPreviewNow(String value) {
    return 'Orain: $value';
  }

  @override
  String get backupUiPreviewCalendars => 'Egutegiak';

  @override
  String backupUiPreviewArchived(String name) {
    return '$name (artxibatuta)';
  }

  @override
  String get backupUiPreviewDays =>
      'Eskuz jarritako txanda edo oharra duten egunak';

  @override
  String get backupUiPreviewRuns => 'Txandaketak';

  @override
  String get backupUiPreviewTypes => 'Txanda motak';

  @override
  String get backupUiPreviewRange => 'Datak';

  @override
  String backupUiPreviewRangeValue(String from, String to) {
    return '$from – $to';
  }

  @override
  String backupUiPreviewRangeOpen(String from, String to) {
    return '$from – $to, eta txandaketa batek aurrera jarraitzen du';
  }

  @override
  String get backupUiPreviewRangeNone => 'Datarik gabe';

  @override
  String get backupUiPreviewReplace =>
      'Honek orain duzuna ordezten du; aurretik kopia bat gordetzen dugu.';

  @override
  String get backupUiPreviewConfirm => 'Ordeztu dudana';

  @override
  String get backupUiPreviewCancel => 'Utzi';

  @override
  String get backupUiRestoring => 'Zure txanden egutegia leheneratzen…';

  @override
  String get backupUiRestoringHint => 'Ez itxi aplikazioa.';

  @override
  String get backupUiDoneTitle => 'Eginda, zure txanden egutegia leheneratu da';

  @override
  String get backupUiDoneBody =>
      'Ezer aldatu aurretik, zeneukana gorde dugu. Espero zenuena ez bazen, atzera egin dezakezu.';

  @override
  String get backupUiDoneView => 'Ikusi nire egutegia';

  @override
  String get backupUiDoneUndo => 'Itzuli lehengora';

  @override
  String get backupUiErrorNotOurs =>
      'Fitxategi hau ez da Turnly-ren kopia bat.';

  @override
  String get backupUiErrorNewer =>
      'Fitxategi hau Turnly-ren bertsio berriago batekoa da: eguneratu aplikazioa.';

  @override
  String get backupUiErrorCorrupt =>
      'Fitxategia hondatuta edo osatu gabe dago, eta ezin da erabili.';

  @override
  String get backupUiErrorTooLarge =>
      'Fitxategi hau handiegia da Turnly-ren kopia bat izateko.';

  @override
  String get backupUiErrorUnreadable => 'Ezin izan da fitxategia irakurri.';

  @override
  String get backupUiErrorUntouched =>
      'Ez dugu ezer aldatu: zure datuak lehen bezala daude.';

  @override
  String get backupUiErrorRestoreFailed =>
      'Ezin izan da leheneratu. Zure datuak lehen bezala daude.';

  @override
  String get backupUiErrorRestoreReload =>
      'Zure datuak leheneratu ditugu, baina ezin izan da pantaila eguneratu. Itxi Turnly eta ireki berriro.';

  @override
  String get backupUiBack => 'Itzuli';

  @override
  String get widgetWeekdaysShort => 'al,ar,az,og,or,lr,ig';

  @override
  String get widgetWeekdayHeaders => 'Al,Ar,Az,Og,Or,Lr,Ig';

  @override
  String get widgetMonthNames =>
      'urtarrila,otsaila,martxoa,apirila,maiatza,ekaina,uztaila,abuztua,iraila,urria,azaroa,abendua';

  @override
  String get widgetTomorrow => 'Bihar';

  @override
  String get widgetEmptyCircular => '–';

  @override
  String get widgetStaleTitle => 'Turnly';

  @override
  String get widgetStaleBody => 'Ireki Turnly eguneratuta egoteko';

  @override
  String get widgetAddTitle => 'Gehitu widgeta';

  @override
  String get widgetAddSubtitle => 'Zure gaurko txanda hasierako pantailan';

  @override
  String get widgetAddBody =>
      'Widgetak beti erakusten du gaurko eguna, aplikazioa ireki ez arren.';

  @override
  String get widgetAddSmall => 'Txikia: gaur eta bihar';

  @override
  String get widgetAddMedium => 'Ertaina: hurrengo 7 egunak';

  @override
  String get widgetAddLarge => 'Handia: hilabete osoa';

  @override
  String get widgetAddAgenda => 'Agenda: hurrengo txandak';

  @override
  String get widgetAddTwoWeeks => 'Bi aste: aste hau eta hurrengoa';

  @override
  String get widgetAddManualAndroid =>
      'Eduki sakatuta hasierako pantailako gune huts bat, aukeratu Widgetak eta bilatu Turnly.';

  @override
  String get widgetAddManualIos =>
      'Eduki sakatuta hasierako pantaila, ukitu goiko + ikurra eta bilatu Turnly.';

  @override
  String get widgetNameSmall => 'Txikia';

  @override
  String get widgetNameMedium => 'Ertaina';

  @override
  String get widgetNameLarge => 'Handia';

  @override
  String get widgetNameAgenda => 'Agenda';

  @override
  String get widgetNameTwoWeeks => 'Bi aste';

  @override
  String get widgetDescSmall => 'Gaur eta bihar';

  @override
  String get widgetDescMedium => 'Hurrengo 7 egunak';

  @override
  String get widgetDescLarge => 'Hilabete osoa';

  @override
  String get widgetDescAgenda => 'Hurrengo txandak';

  @override
  String get widgetDescTwoWeeks => 'Aste hau eta hurrengoa';

  @override
  String widgetAddNamed(String name) {
    return 'Gehitu: $name';
  }

  @override
  String get compareTitle => 'Alderatu egutegiak';

  @override
  String get compareOpen => 'Alderatu egutegiak';

  @override
  String get compareOpenSubtitle => 'Ikusi noiz zaudeten biak libre';

  @override
  String get compareSwap => 'Trukatu';

  @override
  String get compareIntro =>
      'Aukeratu bi egutegietatik sei artean eta ikusi haien txandak elkarrekin. Egun libre guztiak markatuta daude.';

  @override
  String get comparePickTitle => 'Aukeratu egutegiak';

  @override
  String get compareNeedTwoTitle => 'Bi egutegi behar dituzu';

  @override
  String get compareNeedTwoBody =>
      'Sortu beste egutegi bat (zure bikotea, bigarren lan bat) noiz zaudeten biak libre ikusteko.';

  @override
  String compareCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count egun libre komun hilabete honetan',
      one: 'Egun libre komun 1 hilabete honetan',
      zero: 'Ez dago egun libre komunik hilabete honetan',
    );
    return '$_temp0';
  }

  @override
  String get compareFreeListTitle => 'Egun libre komunak';

  @override
  String get compareLegendFree => 'Denak libre';

  @override
  String get compareNote =>
      'Egun bat libretzat hartzen da inork lan egiten ez duenean eta guztiak libre bat edo absentzia bat (oporrak, baja…) idatzita dutenean. Txandarik idatzi gabeko eguna ez da libretzat hartzen: «idatzi gabe» markatzen da. Txanda bakoitza hasten den egunean kontatzen da.';

  @override
  String get compareNoShiftMark => '–';

  @override
  String get compareBothFree => 'denak libre';

  @override
  String compareCellCalendar(String calendar, String shifts) {
    return '$calendar: $shifts';
  }

  @override
  String get compareLegendUnrecorded => 'Bat batean idatzi gabe';

  @override
  String compareUnrecordedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count egun bat batean idatzi gabe',
      one: 'Egun 1 bat batean idatzi gabe',
    );
    return '$_temp0';
  }

  @override
  String get compareUnrecorded => 'bat batean idatzi gabe';

  @override
  String get compareLoadFailed => 'Ezin izan dira egutegiak irakurri.';

  @override
  String get calendarsTitle => 'Egutegiak';

  @override
  String get calendarsIntro =>
      'Egutegi bakoitzak bere txanden egutegia du: zurea, zure bikotearena, bigarren lan batena. Txanda motak berak dira guztietan.';

  @override
  String get calendarsActiveBadge => 'Aktiboa';

  @override
  String get calendarsPrimaryBadge => 'Widgeta eta alarmak';

  @override
  String get calendarsAdd => 'Egutegi berria';

  @override
  String get calendarsNewTitle => 'Egutegi berria';

  @override
  String get calendarsEditTitle => 'Editatu egutegia';

  @override
  String get calendarsNameLabel => 'Izena';

  @override
  String get calendarsNameHint => 'Bikotea, bigarren lana…';

  @override
  String get calendarsColorLabel => 'Kolorea';

  @override
  String calendarsColorOption(int index) {
    return 'Kolorea: $index';
  }

  @override
  String get calendarsCreate => 'Sortu';

  @override
  String get calendarsMakePrimary => 'Erabili widgeterako eta alarmetarako';

  @override
  String get calendarsPrimaryHelp =>
      'Widgetak eta alarmek egutegi hau jarraitzen dute, beste bat ikusten ari bazara ere.';

  @override
  String get calendarsArchive => 'Artxibatu';

  @override
  String calendarsArchiveTitle(String name) {
    return '«$name» artxibatu nahi duzu?';
  }

  @override
  String get calendarsArchiveBody =>
      'Ez da zerrendan agertuko, baina «Artxibatuak» ataletik berreskuratu ahal izango duzu. Haren txandak mugikorrean gordeta geratzen dira.';

  @override
  String calendarsArchivePrimaryNote(String name) {
    return 'Widgeta eta alarmak egutegi honetara pasatuko dira: «$name».';
  }

  @override
  String calendarsArchivedSection(int count) {
    return 'Artxibatuak ($count)';
  }

  @override
  String get calendarsRestore => 'Berreskuratu';

  @override
  String calendarsRestoreSemantic(String name) {
    return 'Berreskuratu «$name»';
  }

  @override
  String calendarsRestored(String name) {
    return '«$name» berreskuratu da';
  }

  @override
  String get calendarsLastError =>
      'Ezin duzu azken egutegia artxibatu: beti egon behar da bat.';

  @override
  String get calendarsNameRequired => 'Jarri izen bat egutegiari.';

  @override
  String get calendarsNotFoundError => 'Egutegi hori ez dago jada.';

  @override
  String get calendarsSaveFailed =>
      'Ezin izan da egutegia gorde. Saiatu berriro.';

  @override
  String calendarsSwitcherLabel(String name) {
    return 'Egutegia: $name. Aldatu egutegia';
  }

  @override
  String get calendarsSwitcherTitle => 'Aldatu egutegia';

  @override
  String get calendarsSwitchFailed => 'Ezin izan da egutegia aldatu.';

  @override
  String get calendarsManage => 'Kudeatu egutegiak';

  @override
  String get holidayImportAction => 'Ekarri jaiegunak mugikorreko egutegitik';

  @override
  String get holidayImportTitle => 'Jaiegunak';

  @override
  String get holidayImportHelp =>
      'Egun osoko gertaerak bakarrik. Dena zure mugikorrean geratzen da; zure egutegia ez da aldatzen.';

  @override
  String get holidayImportRangeHelp =>
      'Hasieran, aurtengoa eta hurrengo urtea.';

  @override
  String get holidayImportSkipped => 'Badago · saltatuko da';

  @override
  String get holidayImportReady => 'Gehituko da';

  @override
  String holidayImportIgnored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ordua duten $count gertaera saltatuko dira.',
      one: 'Ordua duen gertaera 1 saltatuko da.',
    );
    return '$_temp0';
  }

  @override
  String holidayImportCapped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '31 egun baino gehiagoko $count gertaera laburtuko dira.',
      one: '31 egun baino gehiagoko gertaera 1 laburtuko da.',
    );
    return '$_temp0';
  }

  @override
  String holidayImportAdd(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Gehitu $count jaiegun',
      one: 'Gehitu jaiegun 1',
    );
    return '$_temp0';
  }

  @override
  String holidayImportAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jaiegun gehitu dira',
      one: 'Jaiegun 1 gehitu da',
    );
    return '$_temp0';
  }

  @override
  String get holidayImportEmpty => 'Ez dago jaiegun berririk.';

  @override
  String get holidayImportPreviewHelp =>
      'Dagoeneko jaieguna duten datak saltatuko dira.';

  @override
  String get holidaysSettingsRegionTitle => 'Autonomia-erkidegoa';

  @override
  String get holidaysSettingsRegionUnset => 'Aukeratu gabe';

  @override
  String get holidaysSettingsRegionClear => 'Erkidegorik gabe';

  @override
  String get holidaysSettingsCountryTitle => 'Herrialdea';

  @override
  String get holidaysSettingsCountryOther =>
      'Beste herrialde bat: jaiegun ofizialik gabe';

  @override
  String get holidaysSettingsCountryNone => 'Jaiegun ofizialik gabe';

  @override
  String get holidaysSettingsMunicipalityTitle => 'Udalerria';

  @override
  String get holidaysSettingsMunicipalityNone => 'Bat ere ez';

  @override
  String get holidaysSettingsMunicipalitySearch => 'Bilatu udalerria';

  @override
  String holidaysSettingsMunicipalityNoMatch(String query) {
    return 'Ez dago bilaketa honekin bat datorren udalerririk: «$query»';
  }

  @override
  String get holidaysSettingsMunicipalityLoadFailed =>
      'Ezin izan da udalerrien zerrenda kargatu.';

  @override
  String get holidaysSettingsStatusNoRegion =>
      'Erkidegorik gabe, estatuko jaiegunak bakarrik agertzen dira. Aukeratu zurea erkidegokoak ikusteko.';

  @override
  String get holidaysSettingsStatusNoMunicipality =>
      'Aukeratu zure udalerria haren tokiko jaiegunak ikusteko, edo gehitu zuk zeuk behean.';

  @override
  String holidaysSettingsStatusCountryNoData(String country) {
    return 'Oraindik ez ditugu herrialde honetako jaiegun ofizialak: $country. Gehitu zureak behean';
  }

  @override
  String get holidaysSettingsStatusNoOfficial =>
      'Jaiegun ofizialik gabe: behean zuk gehitzen dituzunak bakarrik agertzen dira';

  @override
  String holidaysSettingsStatusLocalIncluded(String municipality) {
    return 'Tokiko jaiegunak ($municipality): barne';
  }

  @override
  String holidaysSettingsStatusYearPending(String year) {
    return 'Urte honetako jaiegun ofizialak eguneratze batekin iritsiko dira: $year';
  }

  @override
  String get holidaysSettingsStatusLocalMissing =>
      'Oraindik ez ditugu zure udalerrikoak: gehitu zuk zeuk behean';

  @override
  String holidaysSettingsStatusLocalMissingYear(
    String municipality,
    String year,
  ) {
    return 'Oraindik ez ditugu jaiegun hauek: $municipality, $year. Gehitu zuk zeuk behean';
  }

  @override
  String get holidaysSubdivisionKindState => 'Estatu';

  @override
  String get holidaysSubdivisionKindFederalState => 'Estatu federala';

  @override
  String get holidaysSubdivisionKindProvince => 'Probintzia';

  @override
  String get holidaysSubdivisionKindRegion => 'Eskualdea';

  @override
  String get holidaysSubdivisionKindNation => 'Nazioa';

  @override
  String get holidaysSubdivisionKindCanton => 'Kantoia';

  @override
  String get holidaysSubdivisionKindCity => 'Hiria';

  @override
  String get holidaysSubdivisionKindCityOrRegion => 'Hiria edo eskualdea';

  @override
  String get holidaysSubdivisionSearch => 'Bilatu';

  @override
  String get holidaysSettingsStatusNoSubdivision =>
      'Aukeratu gabe, herrialde osoko jaiegunak bakarrik agertzen dira. Aukeratu zurea, zure eremukoak ere ikusteko.';

  @override
  String get holidaysSettingsAdd => 'Gehitu tokiko jaieguna';

  @override
  String get holidaysSettingsAddName => 'Izena';

  @override
  String get holidaysSettingsAddDefaultName => 'Tokiko jaia';

  @override
  String holidaysSettingsEmptyYear(String year) {
    return 'Oraindik ez ditugu urte honetako jaiegunak: $year.';
  }

  @override
  String get holidaysSettingsScopeNational => 'Estatukoa';

  @override
  String get holidaysSettingsScopeLocal => 'Tokikoa';

  @override
  String get holidaysSettingsScopeUser => 'Zurea';

  @override
  String holidaysSettingsNoteReplaces(String name) {
    return 'Honen ordez: $name';
  }

  @override
  String holidaysSettingsNoteCovered(String name) {
    return 'Zure egutegian beste honek estaltzen du: «$name»';
  }

  @override
  String holidaysSettingsSubstitutedTitle(String region) {
    return 'Ez dira jaiegun hemen: $region';
  }

  @override
  String get holidaysSettingsSubstitutedBody =>
      'Erkidego batek estatuko jaiegun hauek bere beste batzuekin ordez ditzake.';

  @override
  String get holidaysSettingsRemove => 'Kendu jaieguna';

  @override
  String holidaysSettingsRemoved(String name) {
    return 'Jaieguna kenduta: $name';
  }

  @override
  String holidaysSettingsRowSemantics(String date, String name, String scope) {
    return '$date. $name. $scope';
  }

  @override
  String alarmTitle(String name, String start) {
    return '$name txanda: $start';
  }

  @override
  String alarmBody(String name, String start, String end) {
    return '$name: $start–$end';
  }

  @override
  String get alarmChannelName => 'Txanden alarmak';

  @override
  String get alarmChannelDescription =>
      'Txanda bakoitza hasi aurretik abisatzen dizu.';

  @override
  String alarmsNotifDayBeforeTitle(String name, String start) {
    return 'Bihar: $name txanda, $start';
  }

  @override
  String get alarmsNotifSnooze => 'Atzeratu 10 min';

  @override
  String get alarmsNotifAwake => 'Esna nago';

  @override
  String get alarmsNotifTestTitle => 'Proba-abisua';

  @override
  String get alarmsNotifTestBody =>
      'Honela abisatuko dizu Turnly-k zure txanda baino lehen.';

  @override
  String get alarmsRowOn => 'Aktibatuta';

  @override
  String get alarmsRowOff => 'Desaktibatuta';

  @override
  String get alarmsMasterTitle => 'Abisatu txanda bakoitzaren aurretik';

  @override
  String get alarmsMasterHelp =>
      'Abisu bat mugikorrean, konexiorik eta konturik gabe.';

  @override
  String get alarmsPermOkTitle => 'Dena prest';

  @override
  String get alarmsPermOkBody =>
      'Jakinarazpenak eta ordu zehatzeko alarmak baimenduta daude.';

  @override
  String get alarmsPermOkBodyIos => 'Jakinarazpenak baimenduta daude.';

  @override
  String get alarmsPermNotifTitle => 'Jakinarazpenak falta dira';

  @override
  String get alarmsPermNotifBody =>
      'Jakinarazpenen baimenik gabe, Turnly-k ezin dizu abisatu. Baimentzeko leihoa agertzen ez bazaizu, aktibatu sistemaren ezarpenetan.';

  @override
  String get alarmsPermNotifAllow => 'Baimendu';

  @override
  String get alarmsPermNotifBlockedBody =>
      'Androidek jada ez dizu jakinarazpenei buruz galdetzen. Aktibatu sistemaren ezarpenetan, eta Turnly-k abisatu ahal izango dizu.';

  @override
  String get alarmsPermNotifBlockedBodyIos =>
      'iOSek jada ez dizu jakinarazpenei buruz galdetzen. Aktibatu Ezarpenak › Turnly › Jakinarazpenak atalean, eta Turnly-k abisatu ahal izango dizu.';

  @override
  String get alarmsPermNotifOpenSettings => 'Ireki ezarpenak';

  @override
  String get alarmsPermExactTitle => 'Alarmak eta abisuak';

  @override
  String get alarmsPermExactBody =>
      'Alarmak minutu batzuk berandu irits daitezke. Ordu zehatzean jo dezaten, baimendu «Alarmak eta abisuak» sistemaren ezarpenetan.';

  @override
  String get alarmsPermExactOpen => 'Ireki ezarpenak';

  @override
  String get alarmsSectionTypes => 'Txanda motak';

  @override
  String get alarmsTypesEmpty =>
      'Zure txandetako batek ere ez du ordutegirik. Jarri ordua Nire txandak atalean, Turnly-k abisatu ahal izan diezazun.';

  @override
  String get alarmsBeforeTitle => 'Txandaren aurretik';

  @override
  String get alarmsBeforeAtStart => 'Hastean';

  @override
  String get alarmsBeforeSheetTitle => 'Txanda baino zenbat lehenago';

  @override
  String get alarmsBeforeCustom => 'Pertsonalizatua';

  @override
  String get alarmsBeforeCustomTitle => 'Aurrerapen pertsonalizatua';

  @override
  String get alarmsBeforeCustomHelp =>
      'Txanda hasi baino zenbat ordu eta minutu lehenago.';

  @override
  String get alarmsBeforeCustomApply => 'Gorde';

  @override
  String get alarmsSecondSegmentTitle =>
      'Abisatu bigarren zatiaren aurretik ere';

  @override
  String get alarmsSecondSegmentHelper =>
      'Bigarren abisu bat, aurrerapen berarekin, lanera itzuli aurretik.';

  @override
  String get alarmsDayBeforeTitle => 'Aurreko eguneko abisua';

  @override
  String alarmsDayBeforeAt(String time) {
    return 'Ordua: $time';
  }

  @override
  String get alarmsDayBeforeTimeTitle => 'Abisuaren ordua';

  @override
  String get alarmsLabelTitle => 'Abisuaren testua';

  @override
  String get alarmsLabelDefault => 'Betikoa';

  @override
  String get alarmsLabelHint => 'Adibidez: Lanera!';

  @override
  String get alarmsLabelApply => 'Gorde';

  @override
  String get alarmsLabelReset => 'Erabili betikoa';

  @override
  String get alarmsTestButton => 'Probatu abisua';

  @override
  String get alarmsTestScheduled => '10 segundo barru abisatuko dizugu.';

  @override
  String get alarmsTestDenied =>
      'Jakinarazpenen baimenik gabe ezin dugu abisua probatu.';

  @override
  String alarmsNextLine(String when, String shift) {
    return 'Hurrengo abisua: $when · $shift';
  }

  @override
  String alarmsNextLineDayBefore(String when, String shift) {
    return 'Hurrengo abisua: $when · $shift, aurreko egunean';
  }

  @override
  String alarmsNextWhen(String weekday, int day, String month, String time) {
    return '$weekday, $month $day, $time';
  }

  @override
  String get alarmsNextNone =>
      'Ez dago abisurik aurreikusita hurrengo egunetan.';

  @override
  String get alarmsNextOff => 'Alarmak desaktibatuta daude.';

  @override
  String alarmsScheduledUntil(String date) {
    return 'Abisuak programatuta data honetara arte: $date';
  }

  @override
  String get alarmsRenewalTitle => 'Txanden abisuak';

  @override
  String alarmsRenewalBody(String date) {
    return 'Txanden abisuak data honetara arte daude programatuta: $date. Ireki Turnly hurrengoak programatzeko.';
  }

  @override
  String get alarmsSkipDay => 'Alarmarik ez egun honetan';

  @override
  String get alarmsReminderTitle => 'Gogorarazpena';

  @override
  String get alarmsReminderEmptyBody => 'Gogorarazpen bat duzu gaurko';

  @override
  String get alarmsReminderChannelName => 'Oharren gogorarazpenak';

  @override
  String get alarmsReminderChannelDescription =>
      'Egun bateko oharrean aukeratzen duzun orduan abisatzen dizu.';

  @override
  String get dayReminderAdd => 'Abisatu';

  @override
  String dayReminderAt(String time) {
    return 'Abisua: $time';
  }

  @override
  String get dayReminderChange => 'Aldatu abisuaren ordua';

  @override
  String get dayReminderRemove => 'Kendu abisua';

  @override
  String get dayReminderRemoved => 'Abisua kenduta';

  @override
  String get dayReminderPickHelp => 'Abisuaren ordua';

  @override
  String get dayReminderPast => 'Ordu hori pasatu da: ez du joko.';

  @override
  String get dayReminderNoPermission =>
      'Jakinarazpenak desaktibatuta daude; beraz, abisuak ez du joko. Aktibatu mugikorraren ezarpenetan.';

  @override
  String get dayReminderOnlyPrimary =>
      'Egutegi nagusiko abisuek bakarrik jotzen dute.';

  @override
  String agendaSemanticsReminder(String time) {
    return 'abisua: $time';
  }

  @override
  String get dndSection => 'Ez molestatu txandan zehar';

  @override
  String get dndMasterTitle => 'Isildu mugikorra nire txandetan';

  @override
  String get dndMasterHelp =>
      '«Ez molestatu» modua aktibatzen da txanda hastean, eta desaktibatu egiten da amaitzean.';

  @override
  String get dndFilterTitle => 'Zer onartzen den';

  @override
  String get dndFilterSheetTitle => 'Zer onartzen den txandan zehar';

  @override
  String get dndFilterAll => 'Dena';

  @override
  String get dndFilterPriority => 'Lehentasunezkoa soilik';

  @override
  String get dndFilterAlarms => 'Alarmak soilik';

  @override
  String get dndFilterNone => 'Isiltasun osoa';

  @override
  String get dndPermOkTitle => 'Dena prest';

  @override
  String get dndPermOkBody =>
      'Turnly-k mugikorra «Ez molestatu» moduan jar dezake zure txandetan. Sistemaren alarma gisa programatzen da: erlojuak txandaren hasiera edo amaiera hurrengo alarma gisa erakutsi dezake.';

  @override
  String get dndPermTitle => 'Ez molestatu modurako sarbidea falta da';

  @override
  String get dndPermBody =>
      'Txandan zehar mugikorra isiltzeko, eman Turnly-ri «Ez molestatu» modurako sarbidea sistemaren ezarpenetan.';

  @override
  String get dndPermOpen => 'Ireki ezarpenak';

  @override
  String get dndShiftSection => 'Ez molestatu';

  @override
  String get dndShiftSwitch => 'Gaitu Ez molestatu txanda honetan';

  @override
  String get dndShiftHelper =>
      'Mugikorra isiltzen da txanda honetan lan egiten duzun bitartean.';

  @override
  String get shiftTypesAlarmSection => 'Alarma';

  @override
  String get shiftTypesSoundLabel => 'Soinua';

  @override
  String get shiftTypesSoundHelper =>
      'Alarmen bolumenarekin jotzen du, txanda honen alarma Ezarpenak atalean aktibatzen duzunean.';

  @override
  String get shiftTypesSoundDefault => 'Lehenetsia';

  @override
  String get shiftTypesSoundCustom => 'Mugikorreko soinua';

  @override
  String get shiftTypesSoundMissing =>
      'Ez dago erabilgarri: lehenetsiak jotzen du';

  @override
  String get shiftTypesSoundReset => 'Erabili lehenetsia';

  @override
  String get catalogShiftMorningName => 'Goiza';

  @override
  String get catalogShiftMorningCode => 'Goi';

  @override
  String get catalogShiftAfternoonName => 'Arratsaldea';

  @override
  String get catalogShiftAfternoonCode => 'Arr';

  @override
  String get catalogShiftNightName => 'Gaua';

  @override
  String get catalogShiftNightCode => 'Gau';

  @override
  String get catalogShiftRestName => 'Libre';

  @override
  String get catalogShiftRestCode => 'L';

  @override
  String get catalogShiftGuard24Name => 'Guardia 24 h';

  @override
  String get catalogShiftGuard24Code => 'G24';

  @override
  String get catalogShiftPostNightName => 'Gau-ondokoa';

  @override
  String get catalogShiftPostNightCode => 'GO';

  @override
  String get catalogShiftVacationName => 'Oporrak';

  @override
  String get catalogShiftVacationCode => 'Opo';

  @override
  String get catalogShiftPersonalDayName => 'Norberaren eguna';

  @override
  String get catalogShiftPersonalDayCode => 'NE';

  @override
  String get catalogShiftDay12Name => 'Eguna 12 h';

  @override
  String get catalogShiftDay12Code => 'E12';

  @override
  String get catalogShiftNight12Name => 'Gaua 12 h';

  @override
  String get catalogShiftNight12Code => 'G12';

  @override
  String get catalogShiftSplitName => 'Zatitua';

  @override
  String get catalogShiftSplitCode => 'Zat';

  @override
  String get catalogPatternCorreturnosName => 'Txanda birakariak';

  @override
  String get catalogPatternCorreturnosDescription =>
      '5 goiz, 2 libre, 5 arratsalde, 2 libre, 5 gau, 2 libre';

  @override
  String get catalogPattern24x72Name => '24 x 72';

  @override
  String get catalogPattern24x72Description =>
      '24 orduko guardia eta 72 ordu libre';

  @override
  String get catalogPattern12hName => '12 ordu';

  @override
  String get catalogPattern12hDescription =>
      'Eguna 12 h, gaua 12 h, gau-ondokoa eta librea';

  @override
  String get catalogPattern6x4Name => '6 x 4';

  @override
  String get catalogPattern6x4Description => '6 goiz eta 4 libre';

  @override
  String get catalogPattern4x4Name => '4 x 4';

  @override
  String get catalogPattern4x4Description => '12 orduko 4 egun eta 4 libre';

  @override
  String get catalogPattern5x2Name => '5 x 2';

  @override
  String get catalogPattern5x2Description =>
      '5 goiz eta 2 libre (astelehenetik ostiralera)';

  @override
  String get catalogPattern223Name => '2-2-3';

  @override
  String get catalogPattern223Description =>
      '12 orduko bi egun, bi libre, 12 orduko hiru, bi libre, 12 orduko bi eta hiru libre (2-2-3-2-2-3 ere bai)';

  @override
  String get catalogPatternContinentalName => 'Kontinentala';

  @override
  String get catalogPatternContinentalDescription =>
      '28 eguneko txanda jarraitua 4 talderekin: 2 eta 3 goiz, arratsalde eta gauetako blokeak, eta 7 libre';

  @override
  String get catalogPatternDupontName => 'DuPont';

  @override
  String get catalogPatternDupontDescription =>
      '28 eguneko zikloa 12 orduko txandetan: 4 gau, 3 libre, 3 egun, libre 1, 3 gau, 3 libre, 4 egun eta 7 libre';

  @override
  String get holidayNameNewYear => 'Urteberri eguna';

  @override
  String get holidayNameEpiphany => 'Errege eguna';

  @override
  String get holidayNameMaundyThursday => 'Ostegun Santua';

  @override
  String get holidayNameGoodFriday => 'Ostiral Santua';

  @override
  String get holidayNameEasterMonday => 'Pazko astelehena';

  @override
  String get holidayNameLabourDay => 'Langileen eguna';

  @override
  String get holidayNameAssumption => 'Andre Mariaren Jasokundea';

  @override
  String get holidayNameNationalDay => 'Espainiako Jai Nazionala';

  @override
  String get holidayNameAllSaints => 'Santu Guztien eguna';

  @override
  String get holidayNameConstitution => 'Konstituzio eguna';

  @override
  String get holidayNameImmaculate => 'Sortzez Garbiaren eguna';

  @override
  String get holidayNameChristmas => 'Eguberri eguna';

  @override
  String get holidayNameStStephen => 'San Esteban';

  @override
  String get holidayNameStJoseph => 'San José';

  @override
  String get holidayNameStJames => 'Santiago Apostolua';

  @override
  String get holidayNameGaliciaDay => 'Galiziako eguna';

  @override
  String get holidayNameStJamesGalicia =>
      'Santiago Apostolua / Galiziako eguna';

  @override
  String get holidayNameCataloniaDay => 'Kataluniako Diada';

  @override
  String get holidayNameBasqueDay => 'Euskadiko eguna';

  @override
  String get catalogCalendarMainName => 'Nire txanden egutegia';

  @override
  String get historyUndone => 'Aldaketa desegin da';

  @override
  String get historyRedone => 'Aldaketa berregin da';

  @override
  String get historyNothingToUndo => 'Ez dago ezer desegiteko';

  @override
  String get historyNothingToRedo => 'Ez dago ezer berregiteko';

  @override
  String get monthPresentationGrid => 'Sareta';

  @override
  String get monthPresentationList => 'Zerrenda';

  @override
  String get monthSelectDays => 'Hautatu egunak';

  @override
  String get monthNavMonth => 'Hilabetea';

  @override
  String get monthNavRotation => 'Txandaketa';

  @override
  String get monthNavAgenda => 'Agenda';

  @override
  String get monthNavSummary => 'Laburpena';

  @override
  String get todayCardCollapse => 'Tolestu gaurko txartela';

  @override
  String get todayCardExpand => 'Zabaldu gaurko txartela';

  @override
  String get monthSelectDay => 'Sakatu egun hau hautatzeko';

  @override
  String get monthListRecommended =>
      'Ordutegi osoak eta testu handia ikusteko, zerrenda gomendatzen da.';

  @override
  String get monthListSelected => 'Zerrenda ikuspegia';

  @override
  String get monthGridSelected => 'Sareta ikuspegia';

  @override
  String get absenceRowTitle => 'Oporrak eta baimenak';

  @override
  String get absenceRowSubtitle =>
      'Baimendutako egunak, erabilitakoak eta geratzen zaizkizunak';

  @override
  String get absenceTitle => 'Oporrak eta baimenak';

  @override
  String get absenceYearPrevious => 'Aurreko urtea';

  @override
  String get absenceYearNext => 'Hurrengo urtea';

  @override
  String absenceDays(num days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$daysString egun',
      one: 'egun 1',
    );
    return '$_temp0';
  }

  @override
  String get absenceEmptyTitle => 'Oraindik ez dago saldorik';

  @override
  String get absenceEmptyBody =>
      'Sortu saldo bat (oporrak, norberaren egunak…), eta aplikazioak zure txanden egutegitik kontatuko ditu egunak.';

  @override
  String get absenceAdd => 'Gehitu saldoa';

  @override
  String get absenceContinueSeries => 'Serie bat jarraitu';

  @override
  String get absenceContinueSeriesHelper =>
      'Aurreko urteko serie bat jarraitzen baduzu, haren izena, motak eta muga kopiatzen dira, eta sobratu zaizuna arrastatu egiten da. Zeuk baimendutako egunak betetzen dituzu.';

  @override
  String get absenceCopyNextYear => 'Hurrengo urtera kopiatu';

  @override
  String absenceCopiedNextYear(int year) {
    return 'Saldoa hurrengo urtera kopiatu da ($year).';
  }

  @override
  String absenceLeftCaption(num days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'egun geratzen zaizkizu',
      one: 'egun geratzen zaizu',
    );
    return '$_temp0';
  }

  @override
  String absenceLeftSemantics(String name, String days) {
    return '$name: $days geratzen zaizkizu';
  }

  @override
  String get absenceAllowed => 'Baimenduak';

  @override
  String get absenceCarried => 'Ekarritakoak';

  @override
  String get absenceAdjustment => 'Doikuntzak';

  @override
  String get absenceEnjoyed => 'Hartutakoak';

  @override
  String get absencePlanned => 'Planifikatuak';

  @override
  String absenceCarriedUntil(String date) {
    return 'Iraungitzen dira: $date';
  }

  @override
  String get absenceCarriedNoExpiry => 'Iraungitze-datarik gabe';

  @override
  String absenceCarriedExpired(String date) {
    return 'Iraungi ziren: $date';
  }

  @override
  String absenceWarnExpiring(String days, String date) {
    return 'Aurreko urteko $days geratzen zaizkizu. Iraungitze-data: $date.';
  }

  @override
  String absenceWarnPlanned(String planned, String left) {
    return 'Dituzunak baino gehiago planifikatu dituzu: $planned planifikatuta eta $left erabilgarri.';
  }

  @override
  String get absenceNewTitle => 'Saldo berria';

  @override
  String get absenceEditTitle => 'Editatu saldoa';

  @override
  String absenceEditTooltip(String name) {
    return 'Editatu: $name';
  }

  @override
  String get absenceFieldName => 'Izena';

  @override
  String get absenceFieldNameHint => 'Oporrak';

  @override
  String get absenceFieldAllowed => 'Baimendutako egunak';

  @override
  String get absenceFieldAllowedHelper =>
      'Aurten dagozkizunak, aurreko urtetik ekarritakoak kontatu gabe.';

  @override
  String get absenceFieldAdjustment => 'Eskuzko doikuntza';

  @override
  String get absenceFieldAdjustmentHelper =>
      'Gehitu edo kendu egunak eskuz: aplikazioa erabili aurretik gastatu dituzunak edo eman dizuten egun gehigarri bat. Negatiboak onartzen ditu.';

  @override
  String get absenceDaysSuffix => 'egun';

  @override
  String get absenceFieldCarry => 'Ekarri aurreko urteko soberakina';

  @override
  String get absenceFieldCarryCap => 'Ekar daitekeen gehienezkoa';

  @override
  String get absenceFieldCarryCapHelper => 'Utzi hutsik, dena ekartzen bada.';

  @override
  String get absenceFieldExpiry => 'Iraungitze-data';

  @override
  String get absenceFieldExpiryNone => 'Iraungitze-datarik gabe';

  @override
  String get absenceFieldExpiryClear => 'Kendu iraungitze-data';

  @override
  String get absenceFieldTypes => 'Kontatzen diren txanda motak';

  @override
  String get absenceFieldTypesHelper =>
      'Mota hauetako batekin margotutako egun bakoitzak saldo honetako egun bat gastatzen du.';

  @override
  String get absenceFieldTypesNone =>
      'Ez duzu absentzia-txanda motarik. Sortu bat Nire txandak atalean, Absentzia kategoriarekin.';

  @override
  String absenceInvalidName(int max) {
    return 'Jarri izen bat (gehienez $max letra).';
  }

  @override
  String get absenceInvalidAllowed =>
      'Idatzi baliozko egun kopuru bat; adibidez, 22.';

  @override
  String get absenceInvalidAdjustment =>
      'Idatzi egunak laurdenka; adibidez, -1 edo 0,5.';

  @override
  String get absenceInvalidCap => 'Idatzi baliozko muga bat; adibidez, 5.';

  @override
  String get absenceRemove => 'Kendu saldoa';

  @override
  String get absenceRemoveTitle => 'Saldo hau kendu nahi duzu?';

  @override
  String absenceRemoveBody(String name, int year) {
    return '«$name» saldoa ezabatuko da ($year). Zure txandak ez dira aldatuko.';
  }

  @override
  String get absenceRemoveConfirm => 'Kendu';

  @override
  String get absenceSaveFailed => 'Ezin izan da saldoa gorde. Saiatu berriro.';

  @override
  String absenceSummaryLeft(String days, String name) {
    return '$name: $days geratzen zaizkizu';
  }

  @override
  String get absenceSummaryOpen => 'Ireki oporrak eta baimenak';

  @override
  String get moneyNightPlusLabel => 'Orduko gaueko plusa';

  @override
  String get moneyNightPlusHelper => 'Gaueko lan-ordu bakoitzeko gehitzen da.';

  @override
  String get moneyHolidayPlusLabel => 'Orduko jaiegun-plusa';

  @override
  String get moneyHolidayPlusHelper =>
      'Jaiegunetan lan egindako ordu bakoitzeko gehitzen da.';

  @override
  String get moneyLocationLabel => 'Lekua';

  @override
  String get moneyLocationHint => 'Ospitalea, 3. solairua';

  @override
  String get moneyLocationHelper =>
      'Txostenetan (PDF eta CSV) agertzen da, txandaren izenaren ondoan.';

  @override
  String get moneyExtraTitle => 'Zenbateko gehigarria';

  @override
  String get moneyExtraHelper =>
      'Dietak, kilometrajea, bonus bat… Erabili zenbateko negatibo bat kenkari baterako. Eguneko zenbatespenari gehitzen zaio.';

  @override
  String get moneyExtraHint => 'Zenbatekorik gabe';

  @override
  String get moneyExtraInvalid =>
      'Idatzi baliozko zenbateko bat; adibidez, 25 edo -10,50';

  @override
  String get moneyExtraClear => 'Kendu zenbateko gehigarria';

  @override
  String get moneySectionTitle => 'Orduak eta dirua';

  @override
  String get moneyWithholdingTitle => 'Atxikipena (%)';

  @override
  String get moneyWithholdingSubtitle => 'Zenbatetsitako garbia kalkulatzeko';

  @override
  String moneyWithholdingValue(int percent) {
    return '$percent %';
  }

  @override
  String get moneyWithholdingNone => 'Atxikipenik gabe';

  @override
  String get moneyWithholdingHelper =>
      'Nominatik atxikitzen dizuten ehunekoa (PFEZ eta kotizazioak). Horrekin gutxi gorabeherako soldata garbia kalkulatzen dugu; ez du zure nomina ordezkatzen.';

  @override
  String get moneyWithholdingField => 'Atxikipen-ehunekoa';

  @override
  String get moneyWithholdingInvalid =>
      'Idatzi 0 eta 100 arteko zenbaki oso bat.';

  @override
  String get moneyGross => 'Zenbatetsitako gordina';

  @override
  String get moneyNet => 'Zenbatetsitako garbia';

  @override
  String moneyNetNote(int percent) {
    return '$percent % atxikipenarekin';
  }

  @override
  String get moneyNetSetup => 'Ezarri zure atxikipena garbia ikusteko';

  @override
  String get moneyEarnedTitle => 'Orain arte irabazita';

  @override
  String get moneyEarnedNote =>
      'Igarotako egunak eta gaur lan egindakoa, orain arte.';

  @override
  String get moneyModeQuarter => 'Hiruhilekoa';

  @override
  String moneyQuarterLabel(int quarter, int year) {
    return '${quarter}H $year';
  }

  @override
  String get moneyQuarterPrevious => 'Aurreko hiruhilekoa';

  @override
  String get moneyQuarterNext => 'Hurrengo hiruhilekoa';

  @override
  String get moneyBagTitle => 'Ordu-poltsa';

  @override
  String moneyBagFavour(String hours) {
    return '$hours gehiago';
  }

  @override
  String moneyBagOwed(String hours) {
    return '$hours falta zaizkizu';
  }

  @override
  String get moneyBagEven => 'Zeroan';

  @override
  String moneyBagNote(String month) {
    return 'Lan egindako orduak ken helburua, hilez hil metatuta (azken hilabetea: $month). Abenduko saldoa urtarrilera igarotzen da.';
  }

  @override
  String get moneyReportExtraColumn => 'Zenbateko gehigarria';

  @override
  String get moneyReportExtraTotal => 'Zenbateko gehigarriak';

  @override
  String get moneyPlusHint => 'Zenbatekorik gabe';

  @override
  String get swapRowTitle => 'Trukeen liburua';

  @override
  String get swapRowSubtitle => 'Zor dizkizuten txandak eta zuk zor dituzunak';

  @override
  String get swapTitle => 'Trukeen liburua';

  @override
  String get swapBalancesTitle => 'Balantzea';

  @override
  String swapBalanceTheyOwe(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count txanda zor dizkit',
      one: 'Txanda bat zor dit',
    );
    return '$_temp0';
  }

  @override
  String swapBalanceIOwe(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count txanda zor dizkiot',
      one: 'Txanda bat zor diot',
    );
    return '$_temp0';
  }

  @override
  String get swapBalanceEven => 'Zorrik ez';

  @override
  String get swapChangesTitle => 'Trukeak';

  @override
  String get swapEmptyTitle => 'Oraindik ez dago trukerik';

  @override
  String get swapEmptyBody =>
      'Idatzi txanda-truke bat lankide batekin, eta aplikazioak gogoratuko du nork zer zor dizun.';

  @override
  String get swapAdd => 'Gehitu trukea';

  @override
  String get swapNewTitle => 'Truke berria';

  @override
  String get swapEditTitle => 'Editatu trukea';

  @override
  String get swapStagePending => 'Zain';

  @override
  String get swapStageReturned => 'Itzulita';

  @override
  String get swapStageSettled => 'Kitatuta';

  @override
  String get swapDirectionTheyOwe => 'Zor didate';

  @override
  String get swapDirectionIOwe => 'Zor diot';

  @override
  String get swapFieldService => 'Zerbitzuaren datuak';

  @override
  String get swapFieldColleague => 'Norekin';

  @override
  String get swapFieldColleagueHint => 'Marta';

  @override
  String get swapInvalidColleague => 'Idatzi norekin den trukea.';

  @override
  String get swapFieldDirection => 'Nork zor du txanda';

  @override
  String get swapFieldDirectionHelper =>
      'Aukeratu nor geratzen den zorretan trukearen ondoren.';

  @override
  String get swapFieldDate => 'Txanda uzten duzun eguna';

  @override
  String get swapFieldReturnDate => 'Txanda jasotzen duzun eguna';

  @override
  String get swapFieldReturnNone => 'Oraindik ez duzu jaso';

  @override
  String get swapFieldReturnClear => 'Kendu eguna';

  @override
  String get swapFieldGivenTypes => 'Uzten duzun txanda';

  @override
  String get swapFieldReceivedTypes => 'Jasotzen duzun txanda';

  @override
  String get swapFieldTypesHelper =>
      'Aukeratu trukeko txandak, txanden egutegian aplikatu ahal izateko.';

  @override
  String get swapFieldNote => 'Oharra';

  @override
  String get swapNoteHint => 'Adibidez: astelehenean itzuliko dit';

  @override
  String get swapRemove => 'Kendu trukea';

  @override
  String get swapRemoveTitle => 'Truke hau kendu nahi duzu?';

  @override
  String swapRemoveBody(String name, String date) {
    return 'Trukea ezabatuko da ($name, $date). Zure txandak ez dira aldatuko.';
  }

  @override
  String get swapRemoveConfirm => 'Kendu';

  @override
  String get swapSaveFailed => 'Trukea ezin izan da gorde. Saiatu berriro.';

  @override
  String get swapRemoved => 'Trukea kenduta';

  @override
  String swapEditTooltip(String name) {
    return 'Editatu trukea: $name';
  }

  @override
  String get swapMarkReturned => 'Markatu itzulitzat';

  @override
  String get swapMarkReturnedTitle => 'Zein egunetan itzuliko dizute?';

  @override
  String get swapMarkedReturned => 'Trukea itzulitzat markatu da';

  @override
  String get swapMarkSettled => 'Markatu kitatutzat';

  @override
  String get swapMarkedSettled => 'Trukea kitatuta';

  @override
  String get swapReopen => 'Markatu zain';

  @override
  String get swapReopened => 'Trukea berriro zain dago';

  @override
  String get swapApplyToCalendar => 'Aplikatu txanden egutegian';

  @override
  String get swapUndoFromCalendar => 'Kendu txanden egutegitik';

  @override
  String get swapApplied => 'Trukea txanden egutegian aplikatu da';

  @override
  String get swapUnapplied => 'Trukea txanden egutegitik kendu da';

  @override
  String get swapNothingToApply => 'Egunak jada trukeak dioen bezala daude';

  @override
  String get swapNotApplied => 'Truke hau ez dago txanden egutegian aplikatuta';

  @override
  String get swapDaySection => 'Txanda-trukea';

  @override
  String get swapDayAdd => 'Idatzi truke bat';

  @override
  String get swapDayEmpty => 'Egun horrek ez dauka trukerik idatzita.';

  @override
  String get swapMenuTooltip => 'Trukearen aukerak';

  @override
  String get swapGivesLabel => 'Uzten duzu';

  @override
  String get swapReceivesLabel => 'Jasotzen duzu';

  @override
  String get noteAttachmentsSection => 'Eranskinak';

  @override
  String get noteAttachmentsEmptyTitle =>
      'Oraindik ez dago argazkirik edo fitxategirik';

  @override
  String get noteAttachmentsEmptyBody =>
      'Argazki bat, fitxategi bat edo marrazki bat gehi diezaiokezu egun honi.';

  @override
  String get noteAttachmentsAdd => 'Gehitu';

  @override
  String get noteAttachmentsAddPhoto => 'Atera argazki bat';

  @override
  String get noteAttachmentsAddGallery => 'Aukeratu galeriatik';

  @override
  String get noteAttachmentsAddFile => 'Aukeratu fitxategi bat';

  @override
  String get noteAttachmentsAddSketch => 'Marraztu';

  @override
  String get noteAttachmentKindPhoto => 'Argazkia';

  @override
  String get noteAttachmentKindFile => 'Fitxategia';

  @override
  String get noteAttachmentKindSketch => 'Marrazkia';

  @override
  String noteAttachmentOpen(String name) {
    return 'Ireki: $name';
  }

  @override
  String noteAttachmentRemove(String name) {
    return 'Kendu: $name';
  }

  @override
  String noteAttachmentRemoveHint(String name) {
    return 'Luze sakatu kentzeko: $name';
  }

  @override
  String noteAttachmentRemoved(String name) {
    return 'Kenduta: $name';
  }

  @override
  String get noteAttachmentsViewerTitle => 'Eranskina';

  @override
  String get noteAttachmentTooLarge =>
      'Fitxategi hori handiegia da (gehienez 50 MB).';

  @override
  String get noteAttachmentStoreFull => 'Ez dago lekurik eranskin gehiagorako.';

  @override
  String get noteAttachmentUnreadable => 'Ezin izan da fitxategia irakurri.';

  @override
  String get noteAttachmentCameraDenied =>
      'Baimenik gabe ezin dugu kamera ireki.';

  @override
  String get noteAttachmentGalleryDenied =>
      'Baimenik gabe ezin dugu galeria ireki.';

  @override
  String get noteAttachmentFailed => 'Ezin izan da eranskina gorde.';

  @override
  String get noteAttachmentRemoveFailed => 'Ezin izan da eranskina kendu.';

  @override
  String get noteTasksSection => 'Zereginak';

  @override
  String get noteTasksEmpty => 'Egun honek ez dauka zereginik.';

  @override
  String get noteTasksAdd => 'Gehitu zeregina';

  @override
  String get noteTasksHint => 'Zer egin behar da';

  @override
  String get noteTasksInvalid => 'Idatzi zer egin behar den.';

  @override
  String get noteTasksUndo => 'Desegin zereginen azken aldaketa';

  @override
  String get noteTaskMenu => 'Zereginaren aukerak';

  @override
  String get noteTaskMoveUp => 'Igo';

  @override
  String get noteTaskMoveDown => 'Jaitsi';

  @override
  String get noteTaskRemove => 'Kendu zeregina';

  @override
  String get sketchTitle => 'Marrazkia';

  @override
  String get sketchPen => 'Trazua';

  @override
  String get sketchEraser => 'Goma';

  @override
  String get sketchUndo => 'Desegin trazua';

  @override
  String get sketchRedo => 'Berregin trazua';

  @override
  String get sketchClear => 'Ezabatu marrazkia';

  @override
  String get sketchSave => 'Gorde';

  @override
  String get sketchColor => 'Trazuaren kolorea';

  @override
  String get sketchColorInk => 'Tinta';

  @override
  String get sketchColorAccent => 'Azentua';

  @override
  String get sketchColorHighlight => 'Anbarra';

  @override
  String get sketchColorHoliday => 'Gorria';

  @override
  String get sketchColorSuccess => 'Berdea';

  @override
  String get sketchEmpty => 'Marraztu zerbait gorde ahal izateko.';

  @override
  String get sketchFailed => 'Ezin izan da marrazkia gorde.';

  @override
  String get appearanceNoteInMonthTitle => 'Erakutsi oharra hilabetean';

  @override
  String get appearanceNoteInMonthSubtitle =>
      'Oharraren lehen lerroa eguneko laukian';

  @override
  String get appearancePaintSoundTitle => 'Soa margotzean';

  @override
  String get appearancePaintSoundSubtitle =>
      'Klik bat egun bat margotzean, mugikorra isilik ez badago';

  @override
  String get appearancePresetsTitle => 'Prestatutako paletak';

  @override
  String get appearancePresetsNote =>
      'Fabrikako koloreak dituzten txanden kolorea aldi berean aldatzen dute. Zuk zure gustura margotutakoak ez dira aldatzen.';

  @override
  String get appearancePresetsChoose => 'Aukeratu';

  @override
  String get appearancePresetsApplied => 'Paleta aplikatuta. Desegin dezakezu.';

  @override
  String get appearancePresetSunset => 'Ilunabarra';

  @override
  String get appearancePresetSea => 'Itsasoa';

  @override
  String get appearancePresetForest => 'Basoa';

  @override
  String get appearancePresetCandy => 'Karrameloa';

  @override
  String get appearancePresetNocturnal => 'Gau beltza';

  @override
  String get appearanceBackgroundTitle => 'Egutegiaren atzeko irudia';

  @override
  String get appearanceBackgroundChoose => 'Aukeratu';

  @override
  String get appearanceBackgroundChange => 'Aldatu';

  @override
  String get appearanceBackgroundPick => 'Aukeratu galeriatik';

  @override
  String get appearanceBackgroundRemove => 'Kendu irudia';

  @override
  String get appearanceBackgroundOnDevice =>
      'Mugikor honetan geratzen da: ez doa babeskopian';

  @override
  String get appearanceBackgroundNote =>
      'Zure galeriatik aukeratzen da, eta hilabetearen atzean ikusten da, geruza erdi-garden batekin dena ondo irakurtzeko. Txanden laukiak ez dira aldatzen.';

  @override
  String get appearanceBackgroundTooLarge =>
      'Irudi hori handiegia da. Saiatu txikiago batekin.';

  @override
  String get appearanceBackgroundFailed => 'Ezin izan da irudia gorde.';

  @override
  String get widgetAddFourWeeks => 'Lau aste: hilabete bat';

  @override
  String get widgetNameFourWeeks => 'Lau aste';

  @override
  String get widgetDescFourWeeks => 'Hilabetea asteka';

  @override
  String get compareSelectorTitle => 'Konparatutako egutegiak';

  @override
  String get compareSelectorAction => 'Aldatu';

  @override
  String get compareSheetHint => '2 eta 6 egutegi artean konpara ditzakezu.';

  @override
  String get compareSheetDone => 'Eginda';

  @override
  String get compareSheetMinWarning =>
      'Konparatzeko gutxienez 2 egutegi behar dira.';

  @override
  String get compareSheetMaxWarning =>
      'Dagoeneko 6 egutegi konparatzen ari zara, gehienekoa.';

  @override
  String get compareWeekendTitle => 'Asteburu libre amankomunak';

  @override
  String compareWeekendCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count asteburu libre amankomun hilabete honetan',
      one: 'Asteburu libre amankomun 1 hilabete honetan',
      zero: 'Hilabete honetan ez dago asteburu libre amankomunik',
    );
    return '$_temp0';
  }

  @override
  String compareWeekendDaysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Asteburuko $count egun libre amankomun',
      one: 'Asteburuko egun libre amankomun 1',
    );
    return '$_temp0';
  }

  @override
  String compareWeekendSpoken(String saturday, String sunday) {
    return '$saturday eta $sunday, denek libre';
  }

  @override
  String get compareTableNames => 'Egutegiak';

  @override
  String get devEventsRowTitle => 'Mugikorreko hitzorduak';

  @override
  String get devEventsRowSubtitle => 'Zure egutegiko hitzorduak txanden ondoan';

  @override
  String get devEventsTitle => 'Mugikorreko hitzorduak';

  @override
  String get devEventsHelp =>
      'Aukeratu zein mugikorreko egutegiren hitzorduak ikusi nahi dituzun txanden ondoan. Turnly-k irakurri besterik ez ditu egiten: ez du ezer idazten ez aldatzen.';

  @override
  String get devEventsPermissionTitle => 'Egutegiaren baimena falta da';

  @override
  String get devEventsPermissionBody =>
      'Mugikorreko hitzorduak irakurtzeko, Turnly-k zure egutegiak ikusteko baimena behar du. Ez da eskatzen aplikazioa irekitzean: hemen onartzen baduzu bakarrik.';

  @override
  String get devEventsPermissionDeniedTitle =>
      'Egutegirako sarbidea desaktibatuta dago';

  @override
  String get devEventsPermissionDeniedBody =>
      'Aktibatu sistemaren ezarpenetan (Baimenak › Egutegia) eta itzuli hona.';

  @override
  String get devEventsPermissionDeniedBodyIos =>
      'Aktibatu sistemaren ezarpenetan (Turnly › Egutegiak) eta itzuli hona.';

  @override
  String get devEventsPermissionRestrictedTitle =>
      'Mugikor honek ez du egutegia erabiltzen uzten';

  @override
  String get devEventsPermissionRestrictedBody =>
      'Gurasoen kontrola edo laneko profil bat izan daiteke. Baimen hori gabe ezin dira hitzorduak erakutsi.';

  @override
  String get devEventsPermissionDeclinedBody =>
      'Ez duzu baimena eman. Hura gabe ezin ditugu zure egutegiak irakurri, baina orain eman dezakezu.';

  @override
  String get devEventsPermissionAllow => 'Eman sarbidea';

  @override
  String get devEventsPermissionSettings => 'Ireki ezarpenak';

  @override
  String get devEventsPermissionRecheck => 'Egiaztatu berriro';

  @override
  String get devEventsCalendarsTitle => 'Mugikorreko egutegiak';

  @override
  String devEventsChosenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count egutegi hautatuta',
      one: 'Egutegi 1 hautatuta',
    );
    return '$_temp0';
  }

  @override
  String get devEventsEmptyTitle => 'Ez dago egutegirik';

  @override
  String get devEventsEmptyBody =>
      'Mugikor honek ez du Turnly-k irakurri dezakeen egutegirik.';

  @override
  String get devEventsReadFailedTitle =>
      'Ezin izan dira zure egutegiak irakurri';

  @override
  String get devEventsReadFailedBody =>
      'Mugikorreko egutegiak ez du erantzun. Egiaztatu berriro.';

  @override
  String get devEventsOffTitle => 'Orain ez da hitzordurik erakusten';

  @override
  String get devEventsOffBody =>
      'Ez duzu egutegirik aukeratu. Bat aukeratu arte, hilabetean eta egunean ez da hitzordurik agertuko.';

  @override
  String get devEventsSaveFailed => 'Ezin izan dira aldaketak gorde.';

  @override
  String get devEventsSectionTitle => 'Mugikorreko hitzorduak';

  @override
  String get devEventsAllDay => 'Egun osoa';

  @override
  String devEventsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hitzordu',
      one: 'Hitzordu 1',
    );
    return '$_temp0';
  }

  @override
  String devEventsEventSemantics(String time, String title) {
    return '$time, $title';
  }

  @override
  String devEventsEventWithCalendarSemantics(
    String time,
    String title,
    String calendar,
  ) {
    return '$time, $title, $calendar';
  }
}
