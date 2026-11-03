import 'package:cuadrante/features/holidays/domain/holiday.dart';
import 'package:cuadrante/features/reports/domain/report_model.dart';
import 'package:cuadrante/features/reports/domain/report_options.dart';
import 'package:cuadrante/features/reports/domain/report_strings.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/summary/domain/summary_range.dart';

// A name no other text of the report can contain: the privacy tests search for
// it in the PDF and the CSV.
const String secretLeaveName = 'Baja medica XQZ';
const String secretLeaveNote = 'cita con el oncologo XQZ';

const morning = ShiftType(
  id: 'm',
  code: 'M',
  name: 'Mañana',
  colorValue: 0xFFF5A524,
  category: ShiftCategory.work,
  startMinute: 360,
  endMinute: 840,
  hourlyRateCents: 1000,
);
const night = ShiftType(
  id: 'n',
  code: 'N',
  name: 'Noche',
  colorValue: 0xFF4B4FD1,
  category: ShiftCategory.work,
  startMinute: 1320,
  endMinute: 360,
);
const split = ShiftType(
  id: 's',
  code: 'P',
  name: 'Partido',
  colorValue: 0xFFE5484D,
  category: ShiftCategory.work,
  startMinute: 540,
  endMinute: 780,
  segment2StartMinute: 1020,
  segment2DurationMinutes: 240,
);
const off = ShiftType(
  id: 'l',
  code: 'L',
  name: 'Libre',
  colorValue: 0xFFE4E4E7,
  category: ShiftCategory.rest,
);
const vacation = ShiftType(
  id: 'v',
  code: 'V',
  name: 'Vacaciones',
  colorValue: 0xFF30A46C,
  category: ShiftCategory.absence,
);
const sickLeave = ShiftType(
  id: 'b',
  code: 'B',
  name: secretLeaveName,
  colorValue: 0xFFD6409F,
  category: ShiftCategory.absence,
);

/// October 2026: Mañana the 1st, Noche the 2nd, Partido the 3rd, Libre the
/// 4th, Vacaciones the 5th, the sick leave the 6th (with a health note), a
/// holiday on the 12th with a Mañana and a note, Mañana + Noche on the 13th.
Schedule octoberSchedule() => Schedule(
  shiftTypes: const [morning, night, split, off, vacation, sickLeave],
  entries: {
    const CivilDate(2026, 10, 1): const DayEntry(
      date: CivilDate(2026, 10, 1),
      shiftTypeIds: ['m'],
    ),
    const CivilDate(2026, 10, 2): const DayEntry(
      date: CivilDate(2026, 10, 2),
      shiftTypeIds: ['n'],
    ),
    const CivilDate(2026, 10, 3): const DayEntry(
      date: CivilDate(2026, 10, 3),
      shiftTypeIds: ['s'],
    ),
    const CivilDate(2026, 10, 4): const DayEntry(
      date: CivilDate(2026, 10, 4),
      shiftTypeIds: ['l'],
    ),
    const CivilDate(2026, 10, 5): const DayEntry(
      date: CivilDate(2026, 10, 5),
      shiftTypeIds: ['v'],
      note: 'viaje',
    ),
    const CivilDate(2026, 10, 6): const DayEntry(
      date: CivilDate(2026, 10, 6),
      shiftTypeIds: ['b'],
      note: secretLeaveNote,
    ),
    const CivilDate(2026, 10, 12): const DayEntry(
      date: CivilDate(2026, 10, 12),
      shiftTypeIds: ['m'],
      note: 'Cambio con Ana, "urgente"; llevar llaves',
    ),
    const CivilDate(2026, 10, 13): const DayEntry(
      date: CivilDate(2026, 10, 13),
      shiftTypeIds: ['m', 'n'],
    ),
  },
);

final octoberHolidays = {
  CivilDate(2026, 10, 12): Holiday(
    date: CivilDate(2026, 10, 12),
    name: 'Fiesta Nacional de España',
    scope: HolidayScope.national,
  ),
};

const october = SummaryRange(CivilDate(2026, 10, 1), CivilDate(2026, 10, 31));

ReportModel octoberReport({
  ReportOptions options = const ReportOptions(),
  CivilDate today = const CivilDate(2026, 11, 15),
  SummaryRange range = october,
}) => buildReport(
  schedule: octoberSchedule(),
  range: range,
  calendarName: 'Hospital',
  holidays: octoberHolidays,
  today: today,
  options: options,
);

/// Spanish words and formats without the localizations (domain tests).
ReportStrings spanishStrings({
  String delimiter = ';',
  String decimal = ',',
  bool hour12 = false,
  String? colExtra,
  String? extrasAmount,
}) {
  const shortDays = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
  const longDays = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];
  return ReportStrings(
    localeName: 'es',
    hour12: hour12,
    reportTitleFallback: 'Mis turnos',
    legendTitle: 'Leyenda',
    totalsTitle: 'Totales',
    notesTitle: 'Notas',
    holidaysTitle: 'Festivos',
    holidayMark: 'Festivo',
    absenceName: 'Ausencia',
    absenceCode: 'AUS',
    hoursTotal: 'Horas',
    hoursWorked: 'Horas trabajadas',
    hoursPlanned: 'Horas previstas',
    hoursDone: 'Trabajadas hasta ayer',
    hoursPlannedFrom: 'Previstas desde hoy',
    shiftsWorked: 'Turnos trabajados',
    nightHours: 'Horas nocturnas',
    holidayHours: 'Horas en festivo',
    overtime: 'Horas extra',
    earlyLeave: 'Salidas anticipadas',
    restDays: 'Días libres',
    absences: 'Ausencias',
    earnings: 'Ingresos estimados',
    footer: 'Creado con Turnly',
    colDate: 'Fecha',
    colDay: 'Día',
    colShifts: 'Turno',
    colCode: 'Código',
    colStart: 'Inicio',
    colEnd: 'Fin',
    colHours: 'Horas',
    colNote: 'Nota',
    colExtra: colExtra,
    extrasAmount: extrasAmount,
    weekdayShort: (w) => shortDays[w - 1],
    weekdayLong: (w) => longDays[w - 1],
    date: (y, m, d) => '$d/$m/$y',
    monthYear: (y, m) => 'octubre $y',
    dayMonth: (m, d) => '$d oct',
    hours: (min) => '${min ~/ 60} h ${min % 60} min',
    money: (cents) => '${cents / 100} EUR',
    days: (n) => '$n días',
    pageOf: (p, t) => 'Página $p de $t',
    csvDelimiter: delimiter,
    csvDecimal: decimal,
  );
}
