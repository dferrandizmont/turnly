# Datos locales (Drift)

Contrato de la base de datos del móvil. Es la pieza que decide si se pierden datos: cualquier cambio de esquema pasa
por una migración con prueba (ver «Migraciones»). La especificación (§6) manda: **reglas y excepciones, nunca una
fila por día**.

## Dónde vive
- Archivo `cuadrante.sqlite` en **Application Support** (`getApplicationSupportDirectory`), no en Documents ni en
  caché. En iOS entra en la copia del dispositivo (iCloud/Inicio rápido, R2 de la matriz) y no se ve en Archivos; en
  Android entra en Auto Backup (A1–A4).
- Clase `AppDatabase` en `app/lib/core/database/`. Se abre una vez en el arranque (`bootstrapApp`) y se inyecta con
  `appDatabaseProvider`. Las pruebas usan `NativeDatabase.memory()`.

## Esquema v1 (releases 0.1.0 y 0.2.0; la v2 de más abajo lo amplía)

Fechas de calendario como texto ISO `YYYY-MM-DD` (`CivilDate`, con `TypeConverter`): se leen bien al depurar, se
ordenan bien como texto y no dependen de la zona horaria. Marcas de tiempo (`created_at`, `updated_at`) en
milisegundos UTC. Listas de ids como JSON en texto.

| Tabla | Columnas | Notas |
|---|---|---|
| `shift_types` | `id` TEXT PK, `code` TEXT, `name` TEXT, `color_value` INT, `category` TEXT (`work`/`rest`/`absence`), `start_minute` INT?, `end_minute` INT?, `paid_minutes` INT?, `night_override` BOOL?, `sort_order` INT, `archived` BOOL = false, `created_at`, `updated_at` | Borrar un tipo lo **archiva**: los días pasados lo siguen mostrando. Los archivados no salen en la paleta. CHECK: `start_minute` y `end_minute`, los dos o ninguno, entre 0 y 1439. |
| `patterns` | `id` TEXT PK, `name` TEXT, `steps` TEXT (JSON `[[id, …], …]`, ≥ 1 paso), `created_at`, `updated_at` | |
| `pattern_runs` | `id` TEXT PK, `pattern_id` TEXT → `patterns.id`, `start_date` TEXT, `end_date` TEXT?, `step_offset` INT = 0, `seq` INT UNIQUE, `created_at` | CHECK `end_date IS NULL OR end_date >= start_date`. |
| `day_entries` | `date` TEXT PK, `shift_type_ids` TEXT? (JSON; **NULL = no sustituye al patrón**, `[]` = día vacío), `note` TEXT?, `updated_at` | Una fila solo si hay override o nota (el motor normaliza; el repositorio borra la fila si queda vacía). Desde la v3 también cuenta un recordatorio, horas extra o salida anticipada (`DayEntry.isEmpty`; ver «Esquema v3»). |
| `holidays` | `id` INT PK auto, `date` TEXT, `scope` TEXT (`national`/`regional`/`local`), `name` TEXT, `region_code` TEXT?, `municipality_code` TEXT?, `source` TEXT (`bundled`/`remote`/`user`) | Índice por `date`. Se llena en la semana 3. |
| `absence_balances` | `year` INT, `type` TEXT, `allowed_days` REAL, PK (`year`, `type`) | Lo usado se calcula de los días; aquí solo lo permitido. P1. Ampliada en la v6 (abajo). |
| `settings` | `key` TEXT PK, `value` TEXT (JSON) | Preferencias sueltas (comunidad, municipio, franja nocturna…). |

Los campos de la especificación que todavía no se usaban (adjuntos y «cambio con…» de `DayEntry`) llegaron con la v6,
en tablas propias (abajo).

## Repositorio

`ScheduleRepository` (en `features/schedule/data/`), sobre `AppDatabase`:
- `Future<ScheduleSnapshot> load(String calendarId)`: tipos (incluidos los archivados, para resolver el pasado) y
  patrones, que son comunes, más las rotaciones y entradas **de ese calendario**, en una sola transacción de
  lectura.
- `Future<void> apply(String calendarId, ScheduleChange change)`: en **una transacción**: para cada día del parche,
  borra la fila (`calendar_id`, `date`) si `after == null` o la escribe (upsert) si no; si `runsAfter != null`, deja
  las rotaciones **de ese calendario** iguales a `runsAfter` (borra las que sobran, inserta o actualiza el resto).
  Nunca toca otro calendario: un calendario que no existe falla por la clave foránea y un id de rotación que ya es
  de otro calendario se rechaza (`StateError`), todo sin escribir nada. Deshacer es
  `apply(calendarId, change.inverse())`: no hay otra vía de escritura de días y rotaciones.
  Antes de escribir, comprueba en esa misma transacción que todos los tipos referenciados por las entradas nuevas
  existen (también valen los archivados). Si falta alguno, rechaza el cambio completo con `StateError`, sin perder
  las entradas anteriores ni guardar referencias huérfanas.
- `nextRunSeq()`: el `seq` que debe tomar una rotación nueva (máximo de **todos** los calendarios + 1), porque
  `seq` es único en toda la tabla. `Schedule.applyPattern(..., seq: await repo.nextRunSeq())`; sin pasarlo,
  calcula el máximo de las rotaciones de su calendario y dos calendarios podrían chocar (la base de datos lo
  rechaza y el controlador recarga: no se corrompe nada, pero el cambio no se guarda).
- `saveShiftType` (con `hourlyRateCents`), `saveShiftTypeWithHistory` (esquema v5), `archiveShiftType`, `savePattern` (el editor llega en la semana 2; aquí
  basta con lo que usa la siembra).
- Conversión fila ↔ modelo del motor en un único sitio (`schedule_mappers.dart`), con pruebas de ida y vuelta.

## Arranque y siembra

1. `bootstrapApp()` abre la base de datos (con la copia previa a la migración, abajo) y carga el `Schedule` inicial
   del calendario activo (`calendars.active`; `main` la primera vez) **antes del primer frame**: el calendario aparece con datos, sin parpadeo (objetivo de la especificación: ver el
   turno de mañana en menos de 1 s). Se inyecta con `initialScheduleProvider`.
2. Si la base de datos está vacía (sin tipos de turno): siembra los tipos de `shiftTemplates` (id = clave de la
   plantilla, `sort_order` en el orden de la tabla) y los patrones de `patternPresets`. Sin rotaciones ni días: el
   primer uso (semana 3) los crea.
3. Con `USE_DEMO_DATA=true` (por defecto en desarrollo), la siembra añade además la rotación y los días de prueba de
   `buildDemoSchedule`. Solo en una base de datos vacía: nunca pisa datos.

## Escritura desde la UI
- El controlador cambia el estado en memoria al instante y manda el cambio al repositorio en una **cola en serie**
  (las escrituras se aplican en orden aunque se encadenen deprisa).
- Durante un trazo no se escribe nada; al cerrarlo (`endStroke`) se escribe el cambio completo. Deshacer y rehacer
  escriben su cambio igual.
- Si una escritura falla: se informa a `CrashReporter`, se recarga el `Schedule` desde la base de datos (la verdad
  es lo guardado) y se avisa al usuario («No se ha podido guardar el cambio»). Nunca se queda la UI mostrando algo
  que no está guardado sin decirlo.

## Esquema v2 (release 0.3.0): varios calendarios y precio por hora — hecho

Motivo: paridad (LRHSoft permite 10 calendarios; segundo trabajo, pareja) y resumen de ingresos gratis
(`docs/roadmap.md`). Hay usuarios con la v1 instalada (APK 0.1.0 y 0.2.0): **la migración no puede perder nada**.

| Cambio | Detalle |
|---|---|
| Tabla nueva `calendars` | `id` TEXT PK, `name` TEXT, `color_value` INT, `sort_order` INT, `archived` BOOL = false, `created_at`, `updated_at`. La migración crea `main` («Mi cuadrante», color índigo, orden 0) |
| `pattern_runs.calendar_id` | TEXT NOT NULL → `calendars.id`; las filas existentes pasan a `main`. `seq` sigue siendo único global |
| `day_entries` | PK pasa de (`date`) a (`calendar_id`, `date`) y `calendar_id` TEXT NOT NULL → `calendars.id`: la tabla se recrea (`TableMigration` de Drift) copiando las filas con `calendar_id = 'main'` |
| `shift_types.hourly_rate_cents` | INT NULL (precio por hora para el resumen gratis; céntimos, sin coma flotante) |
| Ajustes | `calendars.active` (el que se ve) y `calendars.primary` (el que usan el widget y las alarmas), por defecto `main` |

**Estado: hecho** (`schemaVersion` 2; volcado `app/drift_schemas/app_database/drift_schema_v2.json`). Una base de
datos nueva (`onCreate`) y la migración dejan el mismo `main`; `bootstrapApp` llama además a
`CalendarsRepository.ensureMain()`, una red de seguridad para que la app no arranque sin calendario. Una base de
datos nunca se queda sin calendarios: no se puede archivar el último y una copia sin ninguno activo se rechaza.

Los tipos de turno y los patrones son **comunes** a todos los calendarios; las rotaciones y los días son de cada uno.

**Comparar calendarios** (gratis, `/comparar`; `calendars/domain/calendar_comparison.dart`): solo lectura. Lee el
`Schedule` de cada calendario (el activo desde el editor en memoria; los demás con `ScheduleRepository.load`, sin
cambiar el calendario activo ni escribir nada). Un día es **libre** si no tiene ningún turno de categoría `work`
(vacío, descanso, ausencia o descanso + ausencia); un turno cuenta en el día en que empieza.
El motor no cambia: un `Schedule` es el de un calendario. `ScheduleRepository.load(calendarId)` y
`apply(calendarId, change)` (ver «Repositorio»).

### Calendarios (`features/calendars/`)
- `Calendar` (`domain/calendar.dart`) y las constantes de `main` (`mainCalendarId`, `mainCalendarName`,
  `mainCalendarColor`). `CalendarsRepository` (`data/`): `list`, `create`, `rename`, `recolor`, `archive`,
  `activeId`, `primaryId`, `setActive`, `setPrimary`, `ensureMain`.
- **Archivar** no borra: las rotaciones y los días se quedan guardados. Se rechaza archivar el último calendario
  (`LastCalendarCannotBeArchived`) o uno que no existe (`CalendarNotFound`). Si el archivado era el activo o el
  primario, esos ajustes pasan al primer calendario que queda.
- **Sin límite de calendarios.** Ya no existe `CalendarLimits` (ni `free`, ni `pro`, ni `calendarLimitsProvider`): con la
  gratuidad total (decisión del 26-oct-2026) el tope de 10 **se retiró del código** y no hay nivel «pro». `create` no
  comprueba ningún tope ni lanza `CalendarLimitReached`; los archivados tampoco influyen. Se pueden crear todos los
  calendarios que hagan falta, y recuperar un archivado nunca falla por el número.
- **Ajuste** `postNight.auto`: `true` / `false` en JSON (Saliente automático; apagado si no existe). Lo lee y escribe
  `PostNightSettingsRepository` (`features/patterns/data/`) y lo expone `postNightAutoProvider`.
- **Ajustes** `calendars.active` y `calendars.primary`: texto JSON con el id (`"main"`), en la tabla `settings`.
  Sin valor valen `main`. Un id que no existe o está archivado (una copia restaurada, por ejemplo) se resuelve a un
  calendario que sí existe, nunca rompe el arranque.
- `ScheduleController` trabaja sobre el calendario activo (`ScheduleState.calendarId`; cada escritura en cola lleva
  el calendario en que se hizo). `switchCalendar(id)` guarda `calendars.active`, carga el calendario y vacía
  deshacer y el trazo abierto; las escrituras ya hechas siguen yendo a su calendario. `reload()` (tras restaurar)
  vuelve a leer el activo guardado.
- Alarmas y widget usan el calendario **primario**: `readPrimarySchedule(ref)`
  (`calendars/application/primary_schedule.dart`) devuelve el `Schedule` en memoria si el primario es el que se ve
  y, si no, lo lee de la base de datos. `AlarmSync.readSchedule` acepta `FutureOr<Schedule>`. El widget, cuando se
  conecte su sincronización, lee por la misma función.
- `CalendarsController` (`application/`) envuelve el repositorio para la interfaz (lista de calendarios y
  primario). Archivar el calendario que se ve cambia a otro; cambiar o archivar el primario recalcula las alarmas.

### El paso v1 → v2 (código real)
`app/lib/core/database/migration_v1_to_v2.dart`, enchufado en `AppDatabase.migration`:

```dart
onUpgrade: stepByStep(from1To2: migrateFrom1To2),

Future<void> migrateFrom1To2(Migrator m, Schema2 schema, {...}) async {
  final db = m.database;
  await db.transaction(() async {            // todo o nada: si algo falla, el archivo sigue en v1
    final types = await count('shift_types');
    final runs = await count('pattern_runs');
    final entries = await count('day_entries');

    await m.createTable(schema.calendars);
    await db.customStatement(
      'INSERT INTO calendars (id, name, color_value, sort_order, archived, created_at, updated_at) '
      'VALUES (?, ?, ?, 0, 0, ?, ?)',
      ['main', 'Mi cuadrante', 0xFF4B4FD1, stamp, stamp],
    );
    await m.addColumn(schema.shiftTypes, schema.shiftTypes.hourlyRateCents);
    await m.alterTable(TableMigration(schema.patternRuns,
        columnTransformer: {schema.patternRuns.calendarId: const Constant<String>('main')},
        newColumns: [schema.patternRuns.calendarId]));
    await m.alterTable(TableMigration(schema.dayEntries,
        columnTransformer: {schema.dayEntries.calendarId: const Constant<String>('main')},
        newColumns: [schema.dayEntries.calendarId]));

    // Sin perder filas y todo en `main`: si no, lanza y la transacción se deshace.
    ...
  });
}
```

Los valores de `main` son literales a propósito (una migración que ya se publicó no debe cambiar si cambia una
constante); una prueba los compara con las constantes que usa la app. Las pruebas del paso están en
`test/drift/app_database/migration_v1_to_v2_test.dart` (datos reales, comparación fila a fila de todas las columnas
de v1, huella de los 730 días de `main` antes y después, el paso que falla deja el archivo en v1 y el siguiente
arranque lo migra) y `test/core/database/upgrade_from_v1_test.dart` (archivo real en disco por `openAppDatabase`:
copia previa, abrir dos veces, instalación nueva).

**Copia de seguridad:** el formato `.cuadrante` (hoy `.turnly`) pasa a `schemaVersion` 2 (incluye `calendars`, `calendarId` en
rotaciones y días y `hourlyRateCents` en los tipos de turno). El lector acepta v1 (todo a `main`) y v2
(`docs/copia-de-seguridad.md`); el archivo dorado v1 sigue restaurándose igual y hay un dorado v2. La huella
cubre todos los calendarios.

**Pruebas obligatorias (hechas):** paso v1→v2 con datos reales (tipos, patrones, 3 rotaciones con una recortada,
excepciones con varios turnos, `[]`, solo nota, festivos propios, ajustes) y comparación de la huella de 730 días
antes y después; la copia previa a la migración existe y abre como v1 con los mismos datos; abrir dos veces no
repite nada; una instalación nueva tiene `main`; un `.cuadrante` v1 restaura en v2.

### Preferencias de la pantalla Ajustes (`features/settings/`)
Texto JSON en `settings`, leídas por `PreferencesRepository` (valor ausente o no válido = valor por defecto) y
cargadas en `bootstrapApp` antes del primer frame (`initialPreferencesProvider`):

| Clave | Valores | Por defecto |
|---|---|---|
| `appearance.themeMode` | `"system"`, `"light"`, `"dark"` | `"system"` |
| `calendar.weekStart` | `1` (lunes), `7` (domingo) | `1` |
| `calendar.weekNumbers` | `true` / `false` (columna con el número de semana ISO) | `false` |
| `appearance.language` | `"system"`, `"es"`, `"ca"`, `"gl"`, `"eu"`, `"en"` (Ajustes › Apariencia › Idioma) | `"system"` |
| `appearance.timeFormat` | `"auto"`, `"24"`, `"12"` (Ajustes › Apariencia › Formato de hora) | `"24"` |
| `appearance.currency` | código ISO 4217 en mayúsculas (`"EUR"`, `"USD"`...; Ajustes › Apariencia › Moneda) | `"EUR"` |

Los tres últimos valores por defecto son el comportamiento de las versiones anteriores: una instalación existente no tiene
las filas y no cambia. Una instalación **nueva** recibe `calendar.weekStart`, `appearance.timeFormat = "auto"` y
`appearance.currency` según la región del móvil al sembrarse la base (`seedRegionDefaults`, solo filas que no existen).
Los importes se guardan en la unidad menor de la moneda y cambiar de moneda no los convierte: `docs/formatos.md`.

`appearance.language` = `"system"` sigue los idiomas preferidos del móvil, en orden, y se queda con el primero que
tenga la app; si no hay ninguno, español. Un valor desconocido o un idioma cuyo ARB ya no exista se lee como
`"system"`. El cambio se aplica al momento (`MaterialApp.locale`) y vuelve a publicar los textos que van a lo nativo
(avisos de las alarmas y del widget).

Con domingo como primer día, cada fila (domingo a sábado) muestra la semana ISO de su jueves. Viajan en la copia de
seguridad (tabla `settings`) y se releen tras restaurar. Excepciones: `appearance.language` y `appearance.timeFormat` son
ajustes del móvil y no viajan (`isDeviceSetting`); `appearance.currency` sí, con los importes que describe.

### Primer uso (`features/onboarding/`)
Texto JSON en `settings`, leído por `OnboardingRepository`. `bootstrapApp` decide **antes del primer frame** si se
abre `/bienvenida` en lugar del mes (`initialOnboardingProvider`):

| Clave | Valores | Significado |
|---|---|---|
| `onboarding.done` | `true` | El primer uso se hizo, se saltó o no hacía falta. Una vez a `true`, no vuelve. |
| `onboarding.profile` | `"nursing"`, `"medicine"`, `"police"`, `"firefighters"`, `"industry"`, `"security"`, `"hospitality"`, `"commerce"`, `"transport"`, `"other"` | La profesión elegida en el último paso, opcional (ausente si se saltó). `commerce` y `transport` solo se ofrecen fuera de España. |
| `onboarding.tipPending` | `true` / `false` | El consejo del mes («Pinta tu mes en un momento») espera a que lo cierren. |
| `onboarding.factoryCatalog` | Instantánea JSON de los tipos, patrones y calendario de fábrica | Procedencia provisional, solo al crear una base nueva sin demo. No viaja en las copias. |

Se muestra solo si no hay `onboarding.done` y, además: no hay datos (ni una fila de `pattern_runs` ni de
`day_entries` en ningún calendario; quien actualiza con datos queda marcado como hecho al arrancar) y no es una
compilación con datos de demostración (salvo `--dart-define=FORCE_ONBOARDING=true`, que ignora la demo y los datos
pero no la marca `onboarding.done`). El lugar se guarda en `holidays.country` / `holidays.region` /
`holidays.municipality` por el camino de siempre (`HolidayController.setPlace`); el país, siempre (sin él es España;
ver `festivos.md`, «País»).

El idioma se guarda al elegirlo en la primera pantalla («¿Cómo empiezas tu cuadrante?»). Los nombres y códigos de fábrica se fijan en ese idioma antes de abrir el importador o al terminar, solo si la instantánea provisional sigue intacta y no hay datos propios. Se consume entonces la marca: una edición, importación, restauración o un cambio posterior de idioma nunca renombra datos existentes. Una base anterior nunca recibe esta procedencia, aunque sus nombres coincidan con los de fábrica.

Las demás elecciones viven en memoria hasta el final del paso 4 (se puede volver atrás o salir sin
dejar medio calendario hecho). Al terminar, por los controladores de siempre: las horas de la profesión sobre los
tipos de turno que ya existen (solo los que conservan las horas de la paleta estándar; nunca se crea un tipo
repetido) y su orden en la barra de pintar, el lugar, y la rotación como **un solo** `applyPatternRun`.

## Esquema v3 (release 0.6.0 «Paridad»): recordatorio, horas extra, icono, sonido y turno partido — hecho

Motivo: los huecos de paridad con las apps líderes (`docs/paridad.md`): recordatorio en la nota (A1), sonido de alarma
por tipo (A3), horas extra y salida anticipada (A6), icono por turno (A8) y turno partido (A12). Solo es la capa de
datos: sin pantallas nuevas, el motor no cambia. Hay usuarios con la v2 instalada (0.3.0 a 0.5.0): **la migración no
puede perder nada** y todo lo nuevo es `NULL` en lo que ya existe.

| Tabla | Columna nueva | Detalle |
|---|---|---|
| `day_entries` | `note_reminder_minute` | INT NULL, CHECK entre 0 y 1439: minuto de **ese día civil** en que suena la nota (A1) |
| `day_entries` | `overtime_minutes` | INT NULL, CHECK ≥ 0: minutos extra trabajados ese día (A6) |
| `day_entries` | `early_leave_minutes` | INT NULL, CHECK ≥ 0: minutos que se salió antes (A6) |
| `shift_types` | `icon` | TEXT NULL: clave de `ShiftIcon` (texto plano a propósito: una clave desconocida se lee como «sin icono», nunca falla) (A8) |
| `shift_types` | `alarm_sound` | TEXT NULL, CHECK no vacío: id opaco del sonido o tono del sistema elegido para el tipo; `NULL` = el del canal (A3) |
| `shift_types` | `segment2_start_minute`, `segment2_duration_minutes` | INT NULL: segundo tramo de un turno partido (A12). CHECK de tabla: los dos o ninguno; inicio entre 0 y 1439; duración entre 1 y 1440; solo en un tipo que tiene horas |

**Límites que aún no son CHECK.** `overtime_minutes` y `early_leave_minutes` solo llevan CHECK ≥ 0; el tope de
1440 (`maxDayExtraMinutes`) lo hacen cumplir el editor, `BackupData.validate` (rechaza un archivo con más) y
`DayEntryRowMapper.toEntry` (acota al leer). No se sube el esquema solo por un CHECK: **`isBetweenValues(0, 1440)` en el
próximo cambio de esquema** (en una reconstrucción de `day_entries`, con prueba de migración). Lo mismo para
`shift_types.hourly_rate_cents` (0 a 999 999, `maxHourlyRateCents`, hoy solo en el editor y en la validación de la
copia).

**Estado: hecho** (`schemaVersion` 3; volcado `app/drift_schemas/app_database/drift_schema_v3.json`). Lo que no se puede
expresar en SQL (que el segundo tramo quepa después del primero dentro de 24 h) lo comprueba el dominio, y lo hacen
cumplir `ScheduleRepository.saveShiftType` (`ArgumentError` antes de escribir) y `BackupData.validate`. Al leer una
fila, un segundo tramo que el dominio no acepta se lee como «sin segundo tramo», un recordatorio fuera del día o unos
minutos negativos como «ninguno» y un icono desconocido como «sin icono»: una fila mala nunca rompe la app.

### Dominio
- `ShiftIcon` (`schedule/domain/shift_icon.dart`): lista cerrada de 30 claves (`sun`, `moon`, `sunrise`, `hospital`,
  `ambulance`, `police`, `fire`, `factory`, `truck`, `plane`, `school`, `home`, `beach`, `bed`, `star`, `heart`,
  `coffee`, `book`, `money`, `alert`, `phone`, `car`, `train`, `bus`, `shop`, `tool`, `baby`, `sport`, `party`,
  `medical`). **Nunca emojis.** La clave es lo que se guarda (base de datos y archivo); cada plataforma la dibuja con
  su juego de símbolos (`AppIcons`, en la capa de presentación). Las claves que salieron no se renombran ni se quitan;
  las nuevas van al final. `ShiftIcon.fromKey` devuelve `null` para lo desconocido.
- `ShiftType` lleva `icon`, `alarmSound`, `segment2StartMinute` y `segment2DurationMinutes` (inmutable, `==`,
  `copyWith` con `clearIcon` / `clearAlarmSound` / `clearSegment2`; quitar las horas quita también el segundo tramo).
- **Segundo tramo** (`checkSegment2`, devuelve un `Segment2Problem` o `null`): el inicio es una **hora del reloj**
  que se lee como «la próxima vez que llega ese minuto después de que acabe el primer tramo» (puede pasar de
  medianoche). Es válido si no empieza justo cuando acaba el primero (sería un solo tramo) y primer tramo + hueco +
  segundo tramo caben en 24 h (`ShiftType.spanMinutes`). Ejemplo: 08:00-12:00 y 16:00 durante 4 h es un turno de 12 h
  de principio a fin con 4 h de hueco. **El motor lo usa desde la 0.6.0** (`docs/motor-de-turnos.md`, «Turno partido»):
  `durationMinutes` sigue siendo el primer tramo, las horas son `scheduledMinutes` (los dos tramos sin el hueco) y las
  ocurrencias son dos (con `null` todo se comporta igual que antes). El editor ya no descarta en silencio un segundo
  tramo que no encaja: lo señala y no guarda.
- `DayEntry` lleva `noteReminderMinute`, `overtimeMinutes` y `earlyLeaveMinutes` (con `assert` de rango,
  `copyWith` con un `clear…` por campo y `withShiftTypeIds`). **Una entrada cuyo único contenido es un recordatorio,
  horas extra o salida anticipada no está vacía** (`DayEntry.isEmpty`); 0 minutos de extra o de salida equivale a
  nada. El recordatorio no depende de que haya texto en la nota: borrar la nota no borra el recordatorio (decisión
  tomada para que la pantalla futura pueda ofrecerlos por separado).
- **Edición por rangos:** el recordatorio, las horas extra y la salida anticipada siguen **exactamente** las reglas de
  la nota. Pintar, «Poner turno», «Doblar», «Borrar», «Volver al patrón», «Aplicar rotación» (con o sin quitar
  excepciones) y la importación conservan los tres campos del día (solo se tocan los turnos). Copiar, pegar, repetir y
  «Duplicar en otro día» los llevan en el portapapeles junto a la nota (`ClipDay`): se pegan solo con «Incluir notas»
  (`includeNotes`), un valor copiado sustituye al del destino y uno que el día copiado no tiene deja en paz al del
  destino, cada campo por separado. `withAnnotationsOf` es el único sitio que lo decide.
- La huella de la matriz (`resolvedDayLines`) añade un último elemento a la línea de un día que tiene recordatorio,
  horas extra o salida anticipada; los días que no tienen ninguno dan la misma línea que siempre (las huellas de los
  datos anteriores no cambian).

### El paso v2 → v3 (código real)
`app/lib/core/database/migration_v2_to_v3.dart`, enchufado en `AppDatabase.migration`:

```dart
onUpgrade: stepByStep(from1To2: migrateFrom1To2, from2To3: migrateFrom2To3),

Future<void> migrateFrom2To3(Migrator m, Schema3 schema, {...}) async {
  await db.transaction(() async {            // todo o nada: si algo falla, el archivo sigue en v2
    final before = await dump();             // todas las columnas de v2 de todas las tablas
    await m.addColumn(schema.dayEntries, schema.dayEntries.noteReminderMinute);
    await m.addColumn(schema.dayEntries, schema.dayEntries.overtimeMinutes);
    await m.addColumn(schema.dayEntries, schema.dayEntries.earlyLeaveMinutes);
    await m.alterTable(TableMigration(schema.shiftTypes, newColumns: [icon, alarmSound, segment2…]));
    // Cada fila de v2 igual, valor a valor, y las columnas nuevas vacías: si no, lanza y se deshace.
  });
}
```

`shift_types` se **reconstruye** (`TableMigration`) en vez de añadir columnas porque las reglas del segundo tramo son
CHECK de tabla, que `ALTER TABLE ADD COLUMN` no puede añadir; `day_entries` solo necesita CHECK de columna y se
amplía en el sitio. La copia previa (`pre-v2-a-v3-<fecha>.sqlite`, o `pre-v1-a-v3-…` si se salta desde la 1: **una
sola copia para toda la cadena**) se hace antes de abrir, como siempre. Cada paso de una cadena confirma por su
cuenta: si v2 → v3 falla en un archivo v1, el archivo se queda en v2 con todos los datos y el siguiente arranque
termina.

**Pruebas obligatorias (hechas)**, en `test/drift/app_database/migration_v2_to_v3_test.dart` (datos reales de tres
calendarios, fixture en `test/support/v2_database.dart`) y `test/core/database/upgrade_from_v2_test.dart` (archivo
real en disco por `openAppDatabase`): v2 → v3 fila a fila (todas las columnas de v2, ids de festivos incluidos) y
huella de 730 días de **cada** calendario antes y después; las columnas nuevas vacías; `testWithDataIntegrity` con las
clases generadas; v1 → v3 encadenado con datos reales; base v2 vacía; el paso que falla deja el archivo v2 exacto
(sin tablas temporales ni columnas nuevas) y el siguiente arranque migra; cadena v1 que falla en el último paso; los
CHECK del archivo migrado; escribir y leer los campos nuevos tras migrar (incluida la misma fecha en dos calendarios y
el rechazo de un segundo tramo inválido); copia previa legible como v2 y sin segunda copia al reabrir; **diario
caliente real** recuperado antes de copiar y migrar (solo sobrevive lo confirmado); un archivo sin copia posible no
se migra; los archivos de las migraciones anteriores se conservan (3 últimas). Los pasos v1 → v2 se prueban ahora
hasta v3, que es lo que hace la app.

**Copia de seguridad:** el formato `.cuadrante` pasa a `schemaVersion` 3 con los campos nuevos
(`docs/copia-de-seguridad.md`); el lector v2 no cambia y hay un dorado v3.

## Esquema v4: plus fijo por tipo de turno — hecho

El plus fijo por tipo de turno es gratis, igual que el precio por hora (especificación §7). Se guarda como
`shift_types.fixed_plus_cents`: INT NULL, CHECK entre 0 y 999 999. Son céntimos enteros; `NULL` significa que no
hay plus y 0 es un importe válido. No depende de las horas ni del segundo tramo: cada turno trabajado suma una
vez el importe de su tipo. Descansos y ausencias no lo suman. Los pluses por hora nocturna o festiva no están
implementados y no forman parte de este cambio; cuando se hagan serán gratuitos (decisión del 26-oct-2026).

`migration_v3_to_v4.dart` añade la columna en el sitio, dentro de una transacción. Conserva todas las columnas
anteriores y comprueba que la nueva empieza vacía. No reconstruye tablas ni endurece CHECK anteriores: los datos
históricos se conservan tal como estaban. El volcado es `app/drift_schemas/app_database/drift_schema_v4.json` y
los pasos se generan con `dart run drift_dev make-migrations`.

La copia automática previa sigue siendo obligatoria y cubre toda la cadena: `pre-v3-a-v4-<fecha>.sqlite` al
actualizar desde v3, o `pre-v1-a-v4-…` / `pre-v2-a-v4-…` desde versiones anteriores. Se crea antes de abrir con
Drift; si no puede hacerse, no se migra. Reabrir no repite la copia ni la migración.

Pruebas: `test/drift/app_database/migration_v3_to_v4_test.dart` compara cada columna de v3 en todas las tablas y
730 días de cada uno de tres calendarios, con tipos archivados, precio por hora, turno partido, icono, sonido y
anotaciones. Comprueba los nulos iniciales, escritura y lectura del plus, los límites SQL y el rollback y reintento
tras un fallo. `test/core/database/upgrade_from_v3_test.dart` usa un archivo real, verifica la copia legible como v3,
la apertura repetida conservando el plus y el bloqueo de la migración cuando falla la copia.

El formato de copia (`.turnly`, antes `.cuadrante`) sigue en **versión 3**: `fixedPlusCents` es opcional y se omite cuando vale `NULL`.
Las copias anteriores restauran sin plus. Una app anterior que lee v3 ignora esta clave desconocida y valida su
suma de control normalmente; no conserva ese importe al volver a exportar. Véase `docs/copia-de-seguridad.md`.

## Esquema v5: versiones de un tipo de turno («Solo a partir de hoy», A2) — hecho

Motivo: cambiar las horas o el precio de un tipo (Noche de 8 a 10 h, otro precio por hora) no puede reescribir los
meses ya trabajados y cobrados, en ningún calendario. El editor pregunta «Corregir en todos los días» o «Solo a
partir de hoy» (`docs/motor-de-turnos.md`, «Versiones de un tipo»). La segunda opción guarda lo que el tipo **era**
hasta ayer en una tabla nueva; el tipo conserva su id, así que rotaciones, patrones, días, deshacer, copias e
importación siguen apuntando al mismo tipo y **no se reescribe ninguna fila de días ni de rotaciones**.

| Tabla nueva | Columnas | Notas |
|---|---|---|
| `shift_type_versions` | `shift_type_id` TEXT → `shift_types.id` (`ON DELETE CASCADE`), `until_date` TEXT (`CivilDate`, último día incluido), `category`, `start_minute`, `end_minute`, `paid_minutes`, `night_override`, `hourly_rate_cents`, `fixed_plus_cents`, `segment2_start_minute`, `segment2_duration_minutes`, `created_at`; PK (`shift_type_id`, `until_date`) | Una fila **por cambio**, nunca por día. Los mismos CHECK que `shift_types` (horas los dos o ninguno, 0–1439; segundo tramo; precio y plus 0–999 999; minutos pagados ≥ 0). Los términos actuales siguen en `shift_types`. |

- **Cómo se lee:** las versiones de un tipo, ordenadas por `until_date`, parten el tiempo: la primera vale para todos
  los días hasta su fecha, la siguiente para los días después hasta la suya, y la fila de `shift_types` para todos los
  días posteriores a la última. Nombre, código, color, icono y sonido no están en la versión: son siempre los de
  `shift_types` (se aplican a todos los días).
- **Repositorio:** `load` lee la tabla entera y la pasa a `Schedule.shiftTypeVersions` (comunes a todos los
  calendarios, como los tipos). `saveShiftTypeWithHistory(tipo, versiones)` guarda el tipo y **sustituye** sus
  versiones en una sola transacción (valida con `checkShiftTypeVersions`: términos válidos y una sola versión por
  fecha; si no, `ArgumentError` sin escribir nada; el tipo tiene que existir). `saveShiftType` no toca las versiones:
  ninguna otra escritura (reordenar, archivar, recuperar, importar, el primer uso) puede perderlas. Borrar un tipo
  (solo uno sin usar, al deshacer una importación) borra sus versiones por la clave foránea. Una fila que el dominio
  rechace (solo por un fallo o un archivo editado a mano) se ignora al leer (`groupShiftTypeVersions`).
- **Copia de seguridad:** van dentro de cada tipo, `shiftTypes[].pastVersions`, solo si tiene alguna; el formato sigue
  en la versión 3 (`docs/copia-de-seguridad.md`). Restaurar borra la tabla antes que los tipos y la vuelve a llenar
  después. La copia automática (`_userTables`) también la vigila.

`migration_v4_to_v5.dart` solo crea la tabla vacía, dentro de una transacción, y comprueba que las 8 tablas de antes
quedan idénticas fila a fila y que la nueva está vacía; si no, deshace. Volcado
`app/drift_schemas/app_database/drift_schema_v5.json`. La copia previa sigue siendo una por destino
(`pre-v4-a-v5-<fecha>.sqlite`, o `pre-v1/v2/v3-a-v5-…`).

Pruebas: `test/drift/app_database/migration_v4_to_v5_test.dart` (un archivo v4 real con tres calendarios, pluses,
turno partido, iconos, sonidos y anotaciones: todas las filas iguales, tabla nueva vacía, 730 días de cada calendario
iguales; el paso que falla deja el v4 intacto y el siguiente arranque migra; escribir y leer versiones tras migrar,
los CHECK y la clave foránea), las de arranque desde v1, v2 y v3 (`test/core/database/upgrade_from_v*_test.dart`,
ahora hasta v5) y `test/features/backup/shift_type_versions_backup_test.dart`.

## Esquema v6: lo que piden las funciones de pago que damos gratis (P0) — hecho

Motivo: `docs/paridad-pago.md`, §2, paquete P0. Un solo cambio de esquema para que P2 (notas ricas), P3 (vacaciones y
permisos con saldo), P4 (libro de cambios) y P9 (horas y dinero) construyan encima sin migrar cada uno. **Solo la
capa de datos**: sin pantallas, el motor no cambia de comportamiento. Todo lo nuevo empieza vacío en lo que ya existe.

| Tabla | Cambio | Detalle |
|---|---|---|
| `shift_types` | `location` | TEXT NULL, CHECK no en blanco y hasta 200 (`maxShiftLocationLength`): lugar del turno. Como el nombre, vale para todos los días (no es un término versionado). |
| `shift_types` | `night_plus_cents_per_hour`, `holiday_plus_cents_per_hour` | INT NULL, CHECK 0 a 999 999 999: plus por hora nocturna y por hora en festivo, en la unidad menor de la moneda (`docs/formatos.md`). Son **términos** (cuentan para «solo a partir de hoy»). |
| `shift_types` | `fixed_plus_cents` | El tope del CHECK sube de 999 999 a **999 999 999** (`maxStoredMoneyCents`). |
| `shift_type_versions` | `night_plus_cents_per_hour`, `holiday_plus_cents_per_hour` | Los mismos dos pluses en cada versión; topes de `hourly_rate_cents` y `fixed_plus_cents` a 999 999 999. |
| `day_entries` | `extra_amount_cents` | INT NULL, CHECK entre −999 999 999 y 999 999 999: importe extra del día (dietas, un plus suelto; negativo para un descuento). |
| `absence_balances` | 12 columnas nuevas | Ver «Saldos de ausencias». |
| `note_attachments` (nueva) | `id` TEXT PK, `calendar_id` → `calendars.id` (`ON DELETE CASCADE`), `date`, `kind` (`photo`/`file`/`sketch`), `relative_path` (UNIQUE `COLLATE NOCASE`: APFS no distingue mayúsculas), `mime_type`, `size_bytes`, `sha256`, `display_name`?, `sort_order` = 0, `created_at`; índice (`calendar_id`, `date`) | Un adjunto de la nota de un día. Los bytes son un archivo de la app en `<Application Support>/attachments/<relative_path>`. CHECK: tipo cerrado; id de 1 a 64; ruta de 1 a 512 sin `/` ni `.` al principio, sin `..` ni barra invertida; MIME de 1 a 255; tamaño de 0 a 50 MiB (`maxAttachmentBytes`); SHA-256 de 64; nombre de 1 a 255 o NULL. El dominio es más estricto (`isSafeAttachmentId`, `isSafeAttachmentPath`: solo letras, cifras, `.`, `_` y `-`, ningún `..`) y nunca acepta una ruta que el CHECK rechace (hay prueba que compara las dos reglas). |
| `day_tasks` (nueva) | `id` TEXT PK, `calendar_id` → `calendars.id` (cascada), `date`, `title`, `done` = false, `sort_order` = 0, `created_at`, `updated_at`; índice (`calendar_id`, `date`) | Lista de casillas de un día. CHECK: título no en blanco y hasta 500. |
| `shift_swaps` (nueva) | `id` TEXT PK, `calendar_id` → `calendars.id` (cascada), `date`, `colleague`, `direction` (`theyOwe`/`iOwe`), `given_shift_type_ids`?, `received_shift_type_ids`? (JSON), `return_date`?, `status` (`pending`/`returned`) = `pending`, `note`?, `created_at`, `updated_at`, `closed_at`?; índice (`calendar_id`, `date`) | El libro de cambios: «me debe / le debo». CHECK: compañero no en blanco y hasta 200; nota hasta 2000; `closed_at` existe **exactamente** cuando el estado es `returned`. No cambia el calendario por sí solo. |

### Decisiones
- **Tareas en tabla propia, no JSON en `day_entries.tasks`.** La fila de `day_entries` la gestiona el motor: existe solo
  si el día guarda algo y se borra cuando queda vacía, y pasa por deshacer, copiar y pegar, la huella... Con las tareas
  dentro habría que enseñar todo eso al motor, y marcar una casilla sería un cambio del cuadrante (con su paso de
  deshacer y reescribiendo la fila entera). En su tabla, marcar es escribir una fila, la lista no depende de que el día
  tenga fila y `load` no las lee al arrancar. Lo mismo para los adjuntos.
- **El importe extra sí va en `day_entries`**, como las horas extra: es una anotación del día y sigue sus reglas
  (`DayEntry.extraAmountCents`, 0 es «nada»; un día con solo importe no está vacío; copiar, pegar, repetir y cortar con
  «Incluir notas» lo llevan como la nota: `ClipDay`, `withAnnotationsOf`, `cutDays`; «Borrar el día por completo» lo
  quita; la huella lo añade a la línea del día solo si no es 0, así que las huellas de antes no cambian).
- **El tope de los importes sube en la base de datos, no en el editor.** En monedas sin decimales (guaraní, rupia,
  dong) o con cifras altas (forinto) 999 999 no llega para un plus por turno. La base de datos acepta ya hasta
  999 999 999 en todas las columnas de dinero; el editor y la copia siguen en 999 999 para el precio por hora y el plus
  fijo (`maxHourlyRateCents`, `maxFixedPlusCents`) y P9 puede subirlos sin migrar. Una copia con importes por encima de
  999 999 la rechaza una app anterior (no pierde nada: no restaura). `shift_types.hourly_rate_cents` sigue sin CHECK:
  añadírselo podría impedir la migración de un archivo que ya tenga un valor raro.
- **Lugar y pluses en el dominio:** `ShiftType.location`, `nightPlusCentsPerHour`, `holidayPlusCentsPerHour`
  (`ShiftTerms` lleva los dos pluses; `ShiftTerms.applyTo` conserva el lugar actual). El formulario aún no los edita:
  `ShiftTypeDraft` los lleva de ida y vuelta para que editar un tipo nunca los pierda. Cambiar un plus en un turno
  trabajado con horas pregunta «todos los días / solo a partir de hoy»; cambiar el lugar, no.

### Saldos de ausencias (`absence_balances`, P3)
La tabla existía desde la v1 sin pantalla. Se **amplía** en vez de sustituirla: la clave (`year`, `type`) y
`allowed_days` siguen igual, y un lector de copias anterior a la v6 exige justo esas tres claves (únicas por año y
tipo) en `absenceBalances`; cambiar su significado haría irrestaurables las copias nuevas en una app antigua.
`type` pasa a ser la **clave estable de una serie** de saldos (la misma cada año, para el arrastre; la crea la app, por
ejemplo un id, y es única entre calendarios); lo que ve el usuario es `name`.

| Columna nueva | Detalle |
|---|---|
| `calendar_id` | TEXT NULL → `calendars.id` (cascada). El calendario cuyos días cuentan; NULL (filas de antes) = el primario. |
| `name` | TEXT NULL, no en blanco y hasta 100. NULL = se muestra `type`. |
| `period_start`, `period_end` | TEXT NULL (`CivilDate`), los dos o ninguno, fin ≥ inicio. Ninguno = el año natural `year`. Un periodo de abril a marzo es del `year` en que empieza. |
| `unit` | TEXT = `day` (`day`/`half`/`quarter`): la parte más pequeña de un día que cuenta. |
| `shift_type_quarters` | TEXT NULL, JSON `{"<id de tipo>": cuartos}` con claves ordenadas: qué tipos de ausencia descuentan y cuánto cada día (1 a 4 cuartos; un medio día de vacaciones, 2). |
| `carry_over`, `carry_over_max_days` | BOOL = false y REAL NULL (≥ 0, en cuartos): si lo que sobra del `year − 1` de la misma serie se suma, con tope opcional. |
| `adjustment_days` | REAL = 0, en cuartos: días añadidos o quitados a mano (los ya gastados antes de usar la app...). |
| `sort_order`, `created_at`, `updated_at` | INT = 0, INT NULL, INT NULL. |

Lo **usado** no se guarda: P3 lo cuenta de los días del calendario con alguno de esos tipos. `allowed_days` sigue
siendo REAL (los cuartos son exactos en coma flotante); el dominio (`AbsenceBalance.problem`) exige al escribir que
sea un número entero de unidades, y no se le añade CHECK porque una fila de antes podría no cumplirlo.

Dos datos de un saldo no tienen columna y van en `settings` (viajan en la copia con la tabla entera, sin migración):
la fecha en que caducan los días arrastrados (`absences.carryOverExpiry`) y si el saldo cuenta **solo días hábiles**
(`absences.workingDays`, propuesta 8: lista ordenada de claves `<calendario>|<año>:<serie>`). Un saldo en días hábiles
solo gasta los días de lunes a viernes que no son festivo del calendario (`isWorkingDay` en `absence_balance.dart`):
una semana de vacaciones con un festivo gasta 4 días. Sin la marca cuenta cada día con uno de sus tipos, como antes.

### Repositorios (sin interfaz)
`NoteAttachmentsRepository` y `DayTasksRepository` (`features/notes/data/`), `ShiftSwapsRepository`
(`features/swaps/data/`) y `AbsenceBalancesRepository` (`features/absences/data/`), con sus modelos en `domain/`
(`NoteAttachment`, `DayTask`, `ShiftSwap`, `AbsenceBalance`; cada uno con `problem`, las mismas reglas que la tabla y la
copia). Leer por día o por rango, guardar (upsert por clave; uno inválido lanza `ArgumentError` sin escribir), borrar,
marcar hecha una tarea, marcar devuelto o reabrir un cambio. El repositorio de adjuntos solo lleva las filas: el
almacén de archivos (P2, `features/notes/data/attachment_store.dart`) escribe el archivo antes de la fila y borra la
fila antes que el archivo. Cada archivo del almacén se nombra por el SHA-256 de sus bytes (`<dos hex>/<hash>`), así
que el mismo contenido no se guarda dos veces y un archivo se puede comprobar contra su fila en cualquier momento;
la tabla no deja que dos filas compartan archivo (la ruta es única), así que un segundo adjunto con el mismo
contenido recibe su propia copia. El almacén borra los archivos que ninguna fila apunta (una tarea de un día
borrado, un calendario borrado, una restauración que falló) y avisa con `AttachmentStoreException` cuando un archivo
es demasiado grande (`maxAttachmentBytes`), cuando el almacén se llena (`maxAttachmentStoreBytes`, 128 MiB, o `maxAttachmentFiles`, 2 000 archivos) o
cuando una ruta no es segura. La ruta de una fila es siempre `<sha[0:2]>/<sha>` (más `-<n>` de 2 a 999 en las copias):
`NoteAttachment.problem` rechaza cualquier otra (`isCanonicalAttachmentPath`).
`ScheduleRepository` lee y escribe el lugar, los pluses (también en las versiones) y el importe extra por
`schedule_mappers.dart`; un importe fuera del tope se lee como «ninguno» y un lugar en blanco como «sin lugar».

### Los dibujos a mano (P2)
Un dibujo son **trazos** (`features/notes/domain/sketch.dart`): un lienzo (ancho y alto, hasta 2048 de cada lado y
4 Mi de píxeles) y trazos con sus puntos, su color (ARGB) y su grosor. Los trazos viajan como **JSON compacto**
(`{"v":1,"w":1000,"h":1000,"s":[{"c":4278190080,"w":4,"p":[10.5,20,11,22]}]}`, los puntos en parejas) y el archivo que
la app guarda como adjunto es el **PNG** del dibujo (`features/notes/data/sketch_png.dart`, escrito a mano: `IHDR` +
`IDAT` + `IEND`, sin dependencias nuevas), que lleva los trazos dentro (un chunk `tEXt` con la palabra
`turnly:sketch`) para que el dibujo se pueda volver a abrir y editar después de una restauración. Los bytes del PNG
son los del adjunto (tipo `sketch`, MIME `image/png`): viajan en la copia como cualquier otro adjunto.

### El paso v5 → v6 (código real)
`app/lib/core/database/migration_v5_to_v6.dart`, en **una transacción** (si algo falla, el archivo queda en v5 tal cual):

1. Vuelca todas las columnas de v5 de las 9 tablas, ordenadas por su clave (`patterns` por `rowid`: su orden es dato).
2. Guarda en memoria las filas de `shift_type_versions` y **borra esa tabla**; reconstruye `shift_types`
   (`TableMigration`: los CHECK solo se cambian reconstruyendo); crea la tabla de versiones nueva y vuelve a meter las
   filas. Así, borrar `shift_types` no puede arrastrar en cascada sus versiones, esté como esté `PRAGMA foreign_keys`
   (hay prueba con las claves foráneas activas durante la migración).
3. `day_entries`: añade la columna en el sitio. `absence_balances`: se reconstruye (lleva CHECK de tabla); las filas
   conservan sus tres columnas y las nuevas quedan a su valor por defecto.
4. Crea las tres tablas nuevas con sus índices.
5. Comprueba que cada columna de v5 de cada fila es igual, que lo nuevo está vacío (o a su valor por defecto), que las
   tablas nuevas están vacías y que `PRAGMA foreign_key_check` no devuelve nada; si no, lanza y se deshace.

La copia previa sigue siendo una por destino (`pre-v5-a-v6-<fecha>.sqlite`, o `pre-v1…v4-a-v6-…`). Volcado
`app/drift_schemas/app_database/drift_schema_v6.json`.

Pruebas: `test/drift/app_database/migration_v5_to_v6_test.dart` (archivo v5 real: la instalación v3 de tres
calendarios llevada a v5 por la cadena publicada, con pluses, el plus fijo en el tope antiguo, dos versiones y dos saldos
de la v1 —`test/support/v5_database.dart`—: todas las columnas iguales, lo nuevo vacío, 730 días de cada calendario,
versiones intactas también con las claves foráneas activas; el paso que falla deja el v5 exacto, sin tablas
temporales, y el siguiente arranque migra; escribir y leer todo lo nuevo, los CHECK y la cascada al borrar un
calendario), la cadena completa desde v1, v2, v3 y v4 (las pruebas de cada paso anterior llegan ahora hasta v6) y las
de arranque con archivo real (`test/core/database/upgrade_from_v*_test.dart`).

**Copia de seguridad:** el formato sigue en la versión 3 con claves opcionales, y los adjuntos viajan en un
contenedor (`docs/copia-de-seguridad.md`, «Esquema v6»).

## Migraciones
- `schemaVersion` es 6 (la 1 fue la de las versiones 0.1.0 y 0.2.0; la 2, la de 0.3.0 a 0.5.0; la 3 añadió los
  campos de paridad de la 0.6.0; la 4, el plus fijo; la 5, las versiones de un tipo; la 6, la base de las funciones
  de pago que damos gratis: adjuntos, tareas, cambios, saldos, lugar, pluses por hora e importe por día). Esquemas guardados con
  `dart run drift_dev make-migrations` (configurado en `build.yaml`, carpeta `app/drift_schemas/`), que también
  genera las pruebas de migración y los pasos (`stepByStep`). Cada versión nueva: subir `schemaVersion`, ejecutar
  `make-migrations`, escribir el paso (en su propio archivo, como `migration_v1_to_v2.dart`, dentro de una
  transacción y con sus comprobaciones) y pasar sus pruebas con datos (no solo el esquema). `make-migrations`
  regenera también `test/drift/app_database/generated/` (se sube con el cambio).
- **Copia previa a la migración:** antes de abrir con Drift, se lee `PRAGMA user_version` del archivo; si es menor
  que `schemaVersion` (y mayor que 0), se copia el archivo a `backups/pre-v{origen}-a-v{destino}-{fecha}.sqlite`
  dentro de Application Support. Se guardan las 3 últimas. **Una sola copia por destino:** si ya existe un
  `pre-v*-a-v{destino}-*`, no se hace otra. Si v1 → v2 confirma y v2 → v3 falla en cada arranque, la copia buena es
  la primera (`pre-v1-a-v3-*`, los datos antes de tocar nada); una copia por arranque la habría borrado a la tercera
  pasada. Además, al podar nunca se borra la copia más antigua del destino actual. Con pruebas
  (`migration_backup_test.dart`, `upgrade_from_v2_test.dart`).
- **Esa copia no se ve en la interfaz** (decidido tras la campaña de QA, H-T16-1): «Copias en este móvil» solo lista
  las `.turnly` (o `.cuadrante` antiguas), no los `pre-v*.sqlite`. Es una red de seguridad interna, no una función para el usuario:
  el usuario recupera con las copias `.turnly` de Ajustes › Copia de seguridad. En una compilación de
  lanzamiento no se puede comprobar con `run-as` ni con `adb backup` (apps con `targetSdk` 36); se comprueba con la
  prueba automática o con una compilación de depuración.
- Prueba de humo en CI: el esquema que genera el código coincide con el último volcado de `drift_schemas/`
  (si alguien cambia una tabla sin migración, falla).
