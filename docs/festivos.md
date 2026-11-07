# Festivos

Cómo llegan los festivos a la app: paquete incluido en la app (2026–2027), importación del calendario del móvil,
base de datos local, prioridades y mantenimiento anual. Alcance en la especificación: §3 P0.4 y §5. Sin red todavía:
la descarga remota está diseñada (abajo) pero no construida.

## Visión general

```
Mochila (sus calendarios oficiales, verificados)  +  app/tool/holidays_es/ (locales laborales revisados aquí)
   │  dart run tool/build_holidays.dart        (a mano, una vez al año; determinista)
   ▼
app/assets/holidays/   ← paquete incluido en la app, con manifest.json y sha256
   │  HolidayBundleLoader  (comprueba tamaño y sha256 de cada archivo)
   ▼
tabla holidays (source = bundled)  ← HolidayRepository.refreshBundled al arrancar, solo si cambia bundleVersion
   │  + filas source = user (festivos que añade la persona; nadie más las toca)
   ▼
HolidayCalendar(región, municipio) → Map<CivilDate, Holiday>  ← holidaysProvider → pantalla del mes
```

- Arranque: `bootstrapApp` lee `manifest.json` (3 KB) y compara `bundleVersion` con el guardado en `settings`
  (`holidays.bundleVersion`). Si coincide y hay filas incluidas, termina ahí. Si no, borra las filas `bundled` y las
  vuelve a insertar en **una transacción** (2.762 filas). Un archivo con suma incorrecta cancela todo y deja lo
  anterior intacto; el arranque nunca falla por los festivos.
- Ajustes: `holidays.country` (`"ES"`, `"MX"`… o `"ZZ"`), `holidays.region` (`"ES-CT"`) y `holidays.municipality`
  (`"08019"`), JSON en `settings`. Un municipio sin región implica la suya (por provincia). Comunidad y municipio solo
  existen en España: elegir otro país los borra, y si quedara alguno guardado con otro país se ignora.
- Sin región elegida solo salen los **7–8 festivos nacionales** del año (los que ninguna comunidad puede sustituir).
  Epifanía, Jueves Santo y el lunes siguiente a Todos los Santos o a la Constitución salen al elegir comunidad: la UI
  de la semana 3 debe pedirla en el primer uso.

## País (D1, decidido el 30-oct, pregunta 20)

La app se abre a fuera de España, así que el lugar empieza por el **país** (ISO 3166-1 alfa-2), independiente del
idioma. Código: `HolidayPlace.countryCode`, lista y nombres en `domain/holiday_country.dart`.

- **Compatibilidad:** sin `holidays.country` guardado es **España**. Quien ya usaba la app y toda copia de seguridad
  anterior (que llevan `holidays.region`/`holidays.municipality` en `settings`, sin país) siguen viendo exactamente lo
  mismo: no hay migración que pueda fallar, y leer nunca escribe. Un valor ilegible también cuenta como España. Las
  copias nuevas llevan `holidays.country` como cualquier otro ajuste; una versión antigua de la app lo ignora.
- **«Otro país: sin festivos oficiales»** se guarda como `"ZZ"` (el código de «región desconocida» de CLDR): no
  coincide con ninguna fila, así que solo salen los festivos propios.
- **Un país sin datos** (los de la lista que no están en «Otros países», abajo) se guarda con su código: no sale ningún
  festivo oficial hasta que el paquete traiga los suyos, y entonces aparecen solos. Los festivos propios funcionan
  siempre, con cualquier país.
- **Primer uso:** el país se propone con la región del sistema (`PlatformDispatcher.locale.countryCode`, o el primer
  idioma preferido que la tenga): si es España, el flujo de siempre (comunidad y municipio); si es un país de la lista,
  ese país; si no está en la lista, «Otro país»; si el móvil no dice nada, España. El último paso (opcional) deja
  cambiarlo, «Saltar» conserva el país (borra comunidad, municipio y profesión) y al terminar **siempre** se guarda, para
  que una instalación nueva fuera de España no herede los festivos españoles.
- **Selector** (último paso del primer uso y Ajustes › Festivos): España primero, el resto por su nombre en el idioma de la
  app (sin tildes ni mayúsculas) y al final «Otro país: sin festivos oficiales». Ni `intl` ni Flutter traen nombres de
  países, así que la lista (47 países: mercados de la hoja de ruta y destinos habituales) lleva sus nombres en los
  cinco idiomas, como dato de referencia igual que los nombres de las comunidades. Un idioma nuevo añade su columna.
- **Profesiones (D5):** el último paso del primer uso usa el país propuesto. En España, la lista de siempre; fuera, una neutra
  (Enfermería y sanidad, Seguridad, Policía, Bomberos, Industria, Hostelería, Comercio, Transporte, Otro) sin Guardia
  Civil, TCAE ni saliente. Si el país cambia y la profesión no está en la nueva lista, pasa a la más
  cercana (`professionForCountry`: Medicina → Enfermería y sanidad; Comercio → Hostelería y comercio; Transporte →
  Otro).
- **Locales en el primer uso (A5):** el aviso «añádelos tú» mira el año que toca y, en noviembre y diciembre, también
  el siguiente (`localHolidaysMissingYearsProvider`), como Ajustes. Tener locales de otro año ya no basta.

## Otros países (D4, 31-oct-2026)

Festivos oficiales de 40 países (21 del 31-oct y 19 del 6-nov-2026, propuesta 8 del informe de competencia),
**sin red y sin API en ejecución**: se generan en desarrollo y viajan como ficheros del
paquete (`assets/holidays/{año}/<cc>.json`, alcance `country`), 2026 y 2027.

| Zona | Países |
|---|---|
| América | México, Argentina, Colombia, Chile, Perú, Ecuador, Uruguay, Venezuela, Brasil, Estados Unidos, Canadá |
| América (6-nov) | Guatemala, Bolivia, Paraguay, Panamá, Costa Rica, República Dominicana, Honduras, El Salvador, Nicaragua, Cuba |
| Europa | Portugal, Francia, Italia, Alemania, Reino Unido, Irlanda, Países Bajos, Bélgica, Suiza, Austria |
| Europa (6-nov) | Polonia, Suecia, Noruega, Dinamarca, Finlandia, Luxemburgo, Grecia, Rumanía, Andorra |

Subdivisiones que se pueden elegir (código ISO 3166-2): Alemania (16 Länder), Estados Unidos (50 estados y DC), Canadá
(13), Suiza (26 cantones), Reino Unido (Inglaterra, Gales, Escocia, Irlanda del Norte), Brasil (26 estados y DF),
Argentina (24), Chile (16 regiones; solo 2 con día propio), Francia (14: Alsacia-Mosela y ultramar), Italia (107
provincias: el patrón del capoluogo), Portugal (20: Azores, Madeira y las capitales de distrito con su festivo
municipal). Bolivia (9 departamentos, cada uno con su día: La Paz 16 jul, Santa Cruz 24 sep...; tipo «Departamento»). Sin
subdivisión: México, Colombia, Perú, Ecuador, Uruguay, Venezuela, Irlanda, Países Bajos, Bélgica, Austria y los 18
nuevos salvo Bolivia (Austria: la biblioteca no tiene ningún día de Land que sea festivo; en El Salvador, Nicaragua,
Noruega, Finlandia y Andorra las subdivisiones solo añaden fiestas patronales de un municipio o parroquia, no se
ofrecen).

### Cómo se genera

`app/tool/export_country_holidays.py` (Python, biblioteca [`python-holidays`](https://github.com/vacanza/holidays),
licencia MIT, **versión fijada `0.107`**; el script se niega a correr con otra). El entorno virtual no se sube:
`.venv/` está en el `.gitignore`. En una sola pasada y de forma determinista escribe:

- `assets/holidays/{año}/<cc>.json` (uno por país y año),
- `assets/holidays/NOTICE` (licencia MIT y procedencia; viaja en el paquete),
- `app/tool/country_holidays_sources.json` (procedencia de cada fichero; no viaja),
- `lib/features/holidays/domain/country_holiday_data.dart` (qué países hay y los nombres de sus subdivisiones).

Reglas del export:

1. Solo festivos **públicos** (la categoría por defecto), con la fecha **observada** cuando se traslada (`(observed)`,
   `(observado)`). El día original también se conserva: quien trabaja a turnos puede trabajar ese día.
2. Idioma: español en los países hispanohablantes (también los nuevos); el propio del país en Portugal (`pt_PT`), Brasil (`pt_BR`), Francia,
   Italia, Alemania, Países Bajos y Austria; inglés en Reino Unido, Irlanda, Estados Unidos y Canadá, y también en
   Bélgica y Suiza (tres y cuatro lenguas oficiales: así no se elige bando) y Luxemburgo (luxemburgués, francés y
   alemán); el propio del país en Polonia (`pl`), Suecia (`sv`), Noruega (`no`), Dinamarca (`da`), Finlandia (`fi`),
   Grecia (`el`), Rumanía (`ro`) y Andorra (`ca`). Estos nombres no se traducen a ca/gl/eu/en.

   **Nombre en pantalla (7-nov-2026):** solo los festivos de España se traducen a es/ca/gl/eu/en (`holidayDisplayName`,
   claves `holidayName*`). Los demás países muestran siempre el nombre local del paquete, en cualquier idioma de la app:
   traducir solo los pocos que coinciden con una clave española mezclaba dos idiomas en una lista (Bolivia, Portugal).
   `Holiday.countryCode` lo decide; la prueba `holiday_names_test.dart` recorre todos los países e idiomas.
3. `national` = los días que **todas** las subdivisiones tienen (por fecha). Un día del país que solo algunas
   mantienen va en esas subdivisiones como `national-optional`; el que solo ellas tienen, como `regional`. En Estados
   Unidos `national` son los festivos federales (con sus días observados) y los estados solo añaden los suyos.
4. Un país ofrece subdivisiones si alguna añade un día; si ninguna lo hace (Austria), no tiene selector.
5. Fuera quedan los territorios de Estados Unidos (PR, GU, AS, MP, VI, UM), `DROP_DAYS` (Venezuela, 15 de mayo: decreto
   de 2024 sin vigencia en 2026-27) y se renombra con `RENAME_DAYS` (Escocia, 15 jun 2026: «World Cup bank holiday», el
   nombre de gov.scot). También sale Guatemala, 15 ago: la Asunción es festivo solo de la capital, no del país.

### Regenerarlo cada año

Desde `app/` (en Windows; en Mac, `.venv/bin/…`):

```
python -m venv ../.venv
../.venv/Scripts/pip install holidays==0.107      # o la versión nueva, cambiando PINNED_VERSION
PYTHONUTF8=1 ../.venv/Scripts/python tool/export_country_holidays.py     # --check solo compara, --list resume
dart format lib/features/holidays/domain/country_holiday_data.dart
dart run tool/build_holidays.dart                 # reescribe manifest.json y conserva estos ficheros
```

Para un año nuevo: añadirlo a `YEARS` y subir `SNAPSHOT_DATE`, crear `assets/holidays/{año}/` y declararla en
`pubspec.yaml`, regenerar y **revisar el `git diff`** (los ficheros son estables: un día por línea). Con otra versión de
la biblioteca, repetir el contraste de abajo. `build_holidays.dart` ya no borra estos ficheros: los lee del paquete, los
deja tal cual y los pone en el manifiesto con la procedencia de `country_holidays_sources.json`.

### Contraste con fuentes (31-oct-2026)

Cada país se comparó, en sus días fijos y en al menos un día móvil, con una fuente oficial o fiable:

| País | Comprobado | Fuente |
|---|---|---|
| México | 2027: 1 feb, 15 mar, 15 nov (lunes de la LFT), 1 ene, 1 may, 16 sep, 25 dic; 2026 igual | Ley Federal del Trabajo, art. 74; officeholidays.com |
| Argentina | 2026 completo: carnavales, puentes (23 mar, 10 jul, 7 dic), 2 abr (Malvinas + Jueves Santo), 15 jun, 17 ago, 23 nov y 9 nov (visita del Papa, DNU 1103/2026) | officeholidays.com; Boletín Oficial (vía prensa) |
| Colombia | 2027 completo (ley Emiliani); 13 jul 2026 (Chiquinquirá, Ley 2578 de 2026) | officeholidays.com; prensa colombiana |
| Chile | 2027: Viernes y Sábado Santo, 28 jun (San Pedro y San Pablo al lunes más cercano, Ley 19.668), 17 sep (viernes), 11 oct | officeholidays.com, que **discrepa en el 30 jun** (error suyo: la ley manda el lunes 28) |
| Perú | 2027 completo (incluidos los de 2022: 7 jun, 23 jul, 6 ago, 8 oct, 9 dic) | officeholidays.com |
| Ecuador | Fijos y Carnaval; **los traslados dependen de decretos anuales** (en 2026 ya hubo decretos extra): revisar cada diciembre | officeholidays.com; prensa |
| Uruguay | Los 5 feriados «pagos» (1 ene, 1 may, 18 jul, 25 ago, 25 dic) | officeholidays.com |
| Venezuela | LOTTT art. 184 (1 ene, Carnaval, Jueves y Viernes Santo, 19 abr, 1 may, 24 jun, 5 jul, 24 jul, 12 oct, 24, 25 y 31 dic) | officeholidays.com; jibble.io (cita la ley) |
| Portugal | 2027 completo (Sexta-feira Santa 26 mar, Páscoa 28 mar, Corpo de Deus 27 may y los fijos) | officeholidays.com |
| Brasil | 2027: Sexta-feira Santa, Tiradentes, 20 nov (nacional desde 2024) | officeholidays.com |
| Francia | 2027: lundi de Pâques 29 mar, Ascension 6 may, Pentecôte 17 may y los fijos | officeholidays.com |
| Italia | 2027 completo; 4 oct (San Francesco) festivo desde 2026 (Ley 151/2025, Gazzetta Ufficiale 10-10-2025) | officeholidays.com; prensa italiana |
| Alemania | 2027 completo; Baviera: Dreikönig, Fronleichnam (27 may 2027), Allerheiligen | officeholidays.com |
| Reino Unido | 2026-27 de Inglaterra/Gales, Escocia (2 ene, 4 ene 2027 sustituto, 3 ago, 30 nov, 15 jun 2026) e Irlanda del Norte (17 mar, 12-13 jul) | gov.uk/bank-holidays; gov.scot |
| Irlanda | 2027 exacto (incluido St Brigid, 1 feb) | officeholidays.com |
| Estados Unidos | Federales 2026 y 2027 con observados (3 jul 2026; 18 jun, 5 jul y 24 dic 2027) | opm.gov, Federal Holidays |
| Canadá | Año Nuevo, Viernes Santo, Canada Day, Labour Day y Navidad (el resto es provincial) | officeholidays.com |
| Países Bajos | 2027 exacto (Koningsdag, Hemelvaart, pinksteren; el 5 may no, es cada cinco años) | officeholidays.com |
| Bélgica | 2027 exacto | officeholidays.com |
| Suiza | Nacionales 2027: 1 ene, Ascensión, 1 ago, 25 dic | officeholidays.com |
| Austria | 2027 completo | officeholidays.com |

### Festivos móviles (6-nov-2026)

Ningún festivo móvil se escribe a mano: Pascua, Corpus Christi, Ascensión, Pentecostés, Carnaval, Semana Santa, los
lunes de la ley (México, Colombia, Rep. Dominicana, Chile) y los trasladados los **calcula la biblioteca** al generar
cada año, con una regla (`easter + n días`, «primer lunes de...»), y el fichero guarda el resultado. Grecia y Rumanía
cuentan desde la Pascua ortodoxa. `test/features/holidays/movable_holidays_test.dart` lo comprueba con un segundo cálculo
independiente (computus gregoriano y ortodoxo escritos en el test), no con las fechas del fichero:

- los dos computus contra la Pascua de tres años distintos (2026: 5 y 12 abr; 2027: 28 mar y 2 may; 2028: 16 y 16 abr);
- cada festivo móvil de 19 países de la lista (Jueves y Viernes Santo, Pascua, lunes de Pascua, Ascensión, Pentecostés,
  Corpus, Carnaval, Lunes Limpio...) cae en `Pascua + n` en 2026 y en 2027, con su nombre;
- al elegir el país (`savePlace`) se cargan sus festivos de los dos años y ninguno de España.

El paquete solo trae 2026 y 2027, así que la prueba de un tercer año es la del cálculo (arriba); `--check` del exportador
vuelve a comparar con la biblioteca al regenerar. Un año nuevo solo hace falta añadirlo a `YEARS`.

### Contraste de los 19 nuevos (6-nov-2026)

Los nuevos se **revisaron por muestras, no uno a uno contra el boletín oficial**: nombres y fechas fijas y los móviles
contra Pascua (arriba), y estas decisiones contra fuentes:

| País | Decisión | Fuente |
|---|---|---|
| Guatemala | Se quita el 15 ago (Asunción): solo es festivo en la capital. El 29 jun (Día del Ejército, el 30 trasladado al lunes) lo trae la biblioteca | conocimiento de la ley; revisar |
| El Salvador | El 10 may (Día de la Madre) y el 17 jun (Día del Padre) vienen de la biblioteca como nacionales; las fuentes de prensa no coinciden en si son asueto general o de quien es madre o padre | jibble.io; prensa salvadoreña: **dudoso** |
| Nicaragua | 30 may (Día de las Madres): feriado nacional por la Ley 1118 de 2022; en la práctica ha variado entre sector público y privado | La Prensa (Nicaragua) |
| Polonia | 24 dic (Wigilia) festivo desde 2025; incluye Pascua y Pentecostés (domingos) | conocimiento de la ley |
| Rumanía, Grecia | Calendario ortodoxo (Pascua 12 abr 2026 y 2 may 2027) | computus ortodoxo en la prueba |
| Costa Rica, Honduras, Paraguay, Panamá, Rep. Dominicana, Cuba | Fijos y móviles de la biblioteca; los traslados a lunes (Rep. Dominicana: Ley 139-97; Paraguay: Jura de la Constitución) los aplica la biblioteca | revisión pendiente contra gaceta oficial |

Fuera, a propósito: Marruecos y Filipinas (fechas por avistamiento de la luna o proclama anual), Puerto Rico (la
biblioteca no trae español), Guinea Ecuatorial, Australia y Nueva Zelanda (días de estado sin códigos ISO ni nombres
limpios). Siguen en el selector y salen como «sin festivos oficiales» hasta que tengan datos.

### Límites conocidos

- **2027 es el calendario legal**: lo que se decreta cada año (puentes en Argentina, Ecuador o Perú; días puntuales
  como el de Escocia en 2026) solo está si ya se había decretado en octubre. Regenerar cada otoño.
- **Estados Unidos**: la biblioteca lista festivos estatales que no son día libre para todos (`Day After Thanksgiving`,
  `Diwali` en California...). Se ofrecen tal cual como festivo del estado.
- **Italia y Portugal**: la subdivisión es la capital (el patrón del capoluogo, el festivo municipal de la capital del
  distrito). El resto de municipios tiene el suyo: se añade a mano como festivo propio.
- **Francia**: solo Alsacia-Mosela y ultramar; los festivos locales no entran.
- **Uruguay**: solo los cinco feriados no laborables pagos.
- **Regiones de los nuevos:** solo Bolivia tiene selector. Alemania y el resto se mantienen como estaban. En Suecia,
  Noruega y Dinamarca los víspera-festivos de hecho (Nochebuena, Nochevieja, Midsommarafton) no son festivo legal y no
  están, salvo Finlandia (Juhannusaatto, Jouluaatto) y Polonia (Wigilia), donde la biblioteca los trae.
- Un nombre aparece solo en el idioma del país (arriba); los festivos propios y los de España siguen igual.

### Tamaño

Los 42 ficheros de los 21 primeros países pesan **116 KB** en bruto (el paquete de España, 270 KB), más `NOTICE` (1,7 KB) y los 9,7 KB
de nombres de subdivisiones en Dart: en el APK, ~40 KB comprimidos. Al cambiar `bundleVersion` la base de datos guarda
unas 2.700 filas más de festivos oficiales. Los 38 ficheros de los 19 nuevos suman **28 KB** (el conjunto, 144 KB) y unas
500 filas más.

## Traer festivos del calendario del móvil (gratis)

Ruta: **Ajustes > Festivos > Traer festivos del calendario del móvil** (`/ajustes/festivos`). Importa los eventos
elegidos como festivos propios (`source = user`), sin depender de la cobertura del paquete incluido: también sirve
para años posteriores a 2027.

1. Usa el permiso de lectura de calendario que ya existe para importar turnos; no añade permisos. Si aún no está
   concedido, explica para qué se necesita antes de pedirlo. Puedes elegir varios calendarios del móvil, incluidos
   los de solo lectura; los ocultos no se ofrecen. Reutiliza `CalendarPermissionCard` y `askForAccess`: la primera
   negativa de Android permite reintentar; la definitiva ofrece abrir ajustes y comprobar de nuevo. El acceso de
   «solo añadir» de iOS requiere volver a pedir acceso completo, como en la importación de turnos.
2. El intervalo inicial va del **1 de enero del año actual al 31 de diciembre del siguiente**, con el año obtenido
   de `clockProvider`. Puedes cambiarlo, hasta un máximo de cinco años.
3. La vista previa incluye **solo eventos de día completo**; los eventos con hora se omiten y se cuentan en un
   aviso. Cada evento de varios días se expande por fechas civiles, con **fin exclusivo**, hasta un máximo de
   **31 días desde su inicio**; si dura más, se recorta y se avisa. El nombre se recorta a 60 grafemas (el límite del
   editor manual), con un límite previo de 120 unidades UTF-16 para acotar también los grafemas con muchos
   caracteres combinantes. No corta pares surrogate.
4. Se pliegan los duplicados normalizando sus nombres. Las fechas ya cubiertas por un festivo aplicable al lugar
   elegido (incluido o propio) aparecen como «Ya existe · se omite»; el resto, como «Se añadirá». Si no queda nada
   nuevo, se indica sin modificar los datos. Al aplicar, una transacción vuelve a comprobar los festivos existentes
   para evitar duplicarlos aunque hayan cambiado desde la vista previa.
5. El aviso final permite **Deshacer**: usa exactamente los IDs insertados por esa importación. Conserva las filas
   que se hayan cambiado después y no elimina otros festivos añadidos a continuación.

La lectura se comparte con el importador de turnos y tiene un límite de **5.000 eventos**, con aviso si hay más.
Todo se procesa y guarda localmente, sin red. El acceso al calendario es de **solo lectura**: no crea,
modifica ni borra eventos en los calendarios del móvil.

Pruebas: `holiday_import_test.dart` cubre expansión, conflictos, transacciones y deshacer;
`holiday_import_flow_test.dart` usa el calendario falso de la importación de turnos y verifica los permisos y el
flujo completo. `holiday_import_layout_test.dart` comprueba los cinco idiomas, claro/oscuro, 320 dp y texto ×2 con
Roboto real, incluida la barra superior y los nombres externos largos. No sustituye la comprobación del plugin
en dispositivos Android/iOS reales.

## Formato del paquete

```
assets/holidays/
  manifest.json                    {schema: 1, bundleVersion, files[]}
  municipalities.json              código INE → nombre, por comunidad (para el selector)
  {año}/es.json                    nacionales + las 19 comunidades
  {año}/municipal/ES-XX.json       festivos locales por municipio (código INE de 5 dígitos)
```

Mismo diseño que la propuesta de `plan-publicacion.md` (los mismos caminos servirán en la descarga remota), solo con
etiquetas en español. Cada JSON lleva `schema: 1`; un `schema` distinto se rechaza.

### Paquetes por país

El cargador ya lee paquetes de otros países, aunque hoy solo exista España (los datos se generan en D4, otra tarea):

```
assets/holidays/{año}/<cc>.json    p. ej. 2027/mx.json; en el manifiesto, "scope": "country", "country": "MX"
```

```json
{"schema":1,"year":2027,"country":"MX",
 "national":[{"date":"2027-09-16","name":"Día de la Independencia"}],
 "regional":{"MX-CMX":[{"date":"2027-…","name":"…","origin":"regional"}]}}
```

- Mismo formato que `es.json` más `country`; `regional` es opcional y sus claves son ISO 3166-2 de ese país
  (`MX-CMX`). Un archivo que diga `ES` se lee exactamente como `es.json`.
- **Sin columna nueva** (sin cambio de esquema): el país va en `region_code`. Una fila nacional de otro país se guarda
  con el código del país solo (`MX`); una de una subdivisión, con el suyo (`MX-CMX`). `NULL` o `ES-XX` es España, como
  todo lo guardado hasta ahora (`HolidayEntry.countryCode`, `isCountryWide`).
- El cargador comprueba que el `country` del archivo coincide con el del manifiesto, además de tamaño y sha256.
  `HolidayManifest.countries` dice qué países trae el paquete.
- Un año nuevo de otro país va en la carpeta del año, que ya está en `pubspec.yaml`.
- **Subdivisión fuera de España (D4):** la persona la elige en Ajustes › Festivos y en el paso del lugar si el país la
  tiene (`country_holiday_data.dart`, `holiday_subdivision.dart`). Se guarda en `holidays.region` (`DE-BY`) y solo vale
  con su país: `savePlace` rechaza el código de otro país y `loadPlace` lo ignora. El municipio sigue siendo solo de
  España. Fila y selector: «Estado», «Estado federado», «Provincia», «Región», «Nación», «Cantón», «Ciudad» o «Ciudad
  o región» según el país (`HolidaySubdivisionKind`); desde 13 subdivisiones, con buscador (sin tildes ni mayúsculas).

`manifest.json`:

```json
{"schema":1,"bundleVersion":"2026-10-17.2231f936",
 "files":[{"path":"2026/es.json","year":2026,"scope":"es","sha256":"…","bytes":8179,
           "source":{"url":"https://www.boe.es/…","ref":"BOE núm. 259, 28.10.2025 — …","published":"2025-10-28"}}]}
```

- `scope`: `es`, `municipal` o `municipalities` (el índice; `year: null`). `region` solo en los municipales.
- `bundleVersion` = fecha de la fuente más reciente + 8 hex del hash del contenido. Cambia siempre que cambia un
  archivo, así que la app refresca sin que nadie tenga que acordarse de subir un número.
- `source` es la atribución (BOE, DOGC, BOCM) de cada archivo.

`{año}/es.json`:

```json
{"schema":1,"year":2026,
 "national":[{"date":"2026-01-01","name":"Año Nuevo"}],
 "regional":{"ES-CT":[{"date":"2026-01-06","name":"Epifanía del Señor","origin":"national-optional"},
                      {"date":"2026-12-26","name":"San Esteban","origin":"regional"}]}}
```

`{año}/municipal/ES-XX.json`:

```json
{"schema":1,"year":2026,"region":"ES-CT",
 "municipalities":{"08019":[{"date":"2026-05-25"},{"date":"2026-09-24"}]}}
```

Un día sin `name` es «Fiesta local»; con nombre lleva el de la pedanía («Fiesta local (El Boalo)») o el de la isla
(«Fiesta insular (Virgen de la Candelaria)», ver «Festivos insulares de Canarias»).

### Locales revisados a mano (`app/tool/holidays_es/`)

Mochila solo trae locales de Cataluña y Madrid. El resto se revisa a mano, contra el boletín oficial, en
`app/tool/holidays_es/` (no es un asset: lo lee `build_holidays.dart`, que lo funde con Mochila):

```json
{"region":"ES-MC","year":2026,"kind":"labour",
 "sources":{"s1":{"url":"https://www.borm.es/…","ref":"BORM núm. 163, 17.7.2025 — Resolución …","published":"2025-07-17","retrieved":"2026-10-31"}},
 "municipalities":{"30030":{"name":"Murcia","days":["2026-04-07","2026-09-15"],"source":"s1","note":"opcional"}}}
```

- Un archivo por comunidad y año (`{año}/ES-XX.json`). `kind` tiene que ser `labour`: **solo fiestas laborales**
  (días inhábiles a efectos laborales, retribuidos y no recuperables). Nunca un calendario escolar.
- Cada municipio cita su fuente (`source`, un id de `sources`). Fuentes válidas: BOE, boletín autonómico o provincial
  (BOP) o la web del ayuntamiento que cite el acuerdo. Un agregador (laboral-social, calendarr…) sirve para encontrar
  el documento, nunca como fuente.
- La herramienta rechaza (y una prueba lo comprueba en lo publicado) un municipio de otra comunidad, una fecha de otro
  año, un municipio sin fuente conocida y **una fuente que parezca escolar** (`escolar`, `lectivo`, `curso 2026`,
  `Ensenyament`, `ikasturte`: `schoolSourcePattern`).
- Un municipio revisado aquí sustituye los días que Mochila tenga para él ese año. En el manifiesto, el archivo
  municipal cita la primera fuente en `source` y el resto en `source.also`.
- Los calendarios escolares de Mochila (`ES-XX/municipal-non-teaching-*.json`) ya **no** entran: sus días son no
  lectivos, no festivos laborales (así entraron por error los de Murcia hasta octubre de 2026).

### Festivos insulares de Canarias

Cada isla tiene su festivo (Decreto del calendario laboral de Canarias, anexo). Va **además** de los nacionales y
autonómicos, y cada municipio tiene encima sus dos locales. Como la app no pregunta la isla, el festivo insular se
reparte a **todos los municipios de la isla** en `{año}/municipal/ES-CN.json`, con el nombre «Fiesta insular (…)»
(`islandHolidayPrefix`). Datos: `app/tool/holidays_es/canarias-islands.json` (isla → códigos INE de sus municipios,
los 88 una sola vez, y el día de cada isla por año con su fuente). Si un municipio ya tiene ese día como local, no se
repite.

- Sin municipio elegido no sale el insular (no se sabe la isla).
- El insular **no cuenta** como local del municipio: `isBundledLocalOf` lo excluye, así que Arona (solo insular) sigue
  avisando de que faltan sus locales, en Ajustes y en el primer uso.

### Filas en la tabla `holidays`

| Origen | `scope` | `region_code` | `municipality_code` | `source` |
|---|---|---|---|---|
| `national` de `es.json` | `national` | NULL | NULL | `bundled` |
| `origin: national-optional` | `national` | `ES-XX` | NULL | `bundled` |
| `origin: regional` | `regional` | `ES-XX` | NULL | `bundled` |
| municipal | `local` | `ES-XX` | INE | `bundled` |
| festivo de la persona | `local` (u otro) | NULL | NULL | `user` |
| `national` de `<cc>.json` (otro país) | `national` | `MX` | NULL | `bundled` |
| `regional` de `<cc>.json` | `regional` | `MX-CMX` | NULL | `bundled` |
| descarga remota (futuro) | igual que arriba | | | `remote` |

## Reglas de prioridad

Copiadas de `officialCalendar` (el calendario oficial del proyecto hermano), más lo que necesita la cuadrícula
(un festivo por día). Código: `HolidayCalendar` (`features/holidays/domain/holiday_calendar.dart`).

0. **País:** una fila oficial solo vale en su país (`HolidayEntry.countryCode`). España no ve las de México ni al
   revés; «Otro país» (`ZZ`) no ve ninguna. Los festivos de la persona valen siempre.
1. **Nacionales:** todos los del país los reciben.
2. **Región elegida:** su archivo aporta (a) los `regional`, que son festivos autonómicos, y (b) los
   `national-optional`, que son festivos nacionales **que esa comunidad mantiene**. Una comunidad «sustituye» un
   festivo nacional sustituible simplemente **no listándolo**: es el único mecanismo de `official.ts`.
3. **Municipio elegido:** solo con región **y** municipio, y solo los locales de ese municipio en esa región. Si la
   región es otra, no sale nada.
4. **Un día, un festivo** (cuadrícula del mes): festivo de la persona > local > autonómico > nacional. En un mismo
   nivel, una fila `remote` gana a una `bundled`. `HolidayCalendar.list` conserva todas las filas, en el orden de
   `official.ts` (fecha, nacional < autonómico < local, nombre).
5. El alcance (`HolidayScope`) y el origen (`HolidaySource`) viajan en `Holiday` para que la UI los distinga.

Ejemplos reales de los datos:

| Caso | Resultado |
|---|---|
| Sin región, 2026 | 1 ene, 3 abr (Viernes Santo), 1 may, 15 ago, 12 oct, 8 dic, 25 dic. Sin Epifanía. |
| **ES-CT 2026, Sant Esteve** | 26 dic, «San Esteban», `regional`. Además Lunes de Pascua (6 abr), San Juan (24 jun) y la Diada (11 sep). |
| **ES-CT, Epifanía (national-optional)** | 6 ene sale como `national`: Cataluña la mantiene. |
| ES-CT frente a ES-MD, 2 abr 2026 | En Cataluña no es festivo (la sustituyó por el Lunes de Pascua); en Madrid sí: Jueves Santo `national-optional`. |
| ES-MD 2026, 2 nov | «Día siguiente a Todos los Santos», `national-optional` (el 1 nov es domingo; nadie lo lista). |
| **ES-CT + 08019 (Barcelona)** | Añade 25 may y 24 sep, «Fiesta local», `local`. |
| ES-MD + 28079 (Madrid) | Añade 15 may y 9 nov; el 2 may sigue siendo el de la Comunidad. |
| ES-AN + 41091 (Sevilla) | Añade 22 abr y 4 jun (2026), «Fiesta local». |
| ES-AN + 41038 (Dos Hermanas) | Sin locales en el paquete: solo nacionales y autonómicos de Andalucía. |
| ES-CN + 38006 (Arona) | 2 feb, «Fiesta insular (Virgen de la Candelaria)»; sin locales propios, así que avisa de que faltan. |
| Festivo propio el 12 oct | Sustituye a la Fiesta Nacional en esa pantalla; al quitarlo vuelve el oficial. |
| País México (sin datos), 2026 | Ningún festivo oficial: ni el 12 oct ni Navidad. Solo los propios. |
| «Otro país» (`ZZ`) | Solo los propios. |

## Cobertura incluida (paquete `2026-10-31`)

De Mochila solo entra lo que su manifiesto marca `verified: true` y `status: complete`; lo de `tool/holidays_es` se
revisó a mano el 31-oct-2026 contra el boletín oficial de cada municipio (tabla de abajo).

| Dato | 2026 | 2027 |
|---|---|---|
| Nacionales (BOE-A-2025-21667 y BOE-A-2026-21254) | 7 días | 8 días |
| Autonómicos (19: 17 comunidades, Ceuta y Melilla) | 19 de 19, revisados | 19 de 19, revisados |
| Insulares de Canarias (7 islas, los 88 municipios) | sí (Decreto 61/2025) | sí (Decreto 115/2026) |
| Locales Cataluña (Mochila) | 870 de 947 municipios (1.739 días) | **pendiente** (DOGC, diciembre de 2026) |
| Locales Madrid (Mochila) | 163 de 179 municipios (331 días) | **pendiente** (BOCM, diciembre de 2026) |
| Locales Murcia (BORM, calendario laboral) | 45 de 45 municipios | 45 de 45 municipios |
| **Capitales de provincia** (50) | **50 de 50** | **31 de 50** (faltan las de CT, MD, CM, AR, VC, CB, León y Pamplona) |
| Ceuta y Melilla, locales | las dos | pendiente (BOCCE, BOME) |
| Resto de municipios, locales | no hay | no hay |
| Índice de municipios (INE) | 8.132 municipios, 19 comunidades | igual |

Tamaño total: **315 KB** (`municipalities.json` 192 KB, `ES-CT` 48 KB, `ES-MD` 9 KB, cada `ES-CN` 8 KB, el resto
menos de 3 KB cada uno).

### Autonómicos: revisión del 31-oct-2026

Los días de las 19 comunidades de 2026 y 2027 coinciden con los anexos del BOE
([BOE-A-2025-21667](https://www.boe.es/diario_boe/txt.php?id=BOE-A-2025-21667),
[BOE-A-2026-21254](https://www.boe.es/diario_boe/txt.php?id=BOE-A-2026-21254)) y, donde se abrieron, con los
decretos autonómicos (p. ej. Castilla-La Mancha 44/2025 y 34/2026; Canarias 61/2025 y 115/2026; Madrid 75/2025;
Murcia, [BORM 17.7.2025](https://www.borm.es/services/anuncio/ano/2025/numero/3546/pdf?id=837607) y
[BORM 27.7.2026](https://www.borm.es/services/anuncio/844400/pdf); Cataluña EMT/52/2026). No hubo que cambiar nada.
Notas: Canarias 2027 lista 3 días porque el duodécimo es el insular; Navarra tiene el 3 de diciembre (San Francisco
Javier) como uno de los **dos locales** de cada municipio, no como autonómico.

### Locales de las capitales: procedencia

Dos días por capital (dd/mm). «Mochila» = viene del repositorio hermano; el resto, de `tool/holidays_es`. Murcia
(los 45 municipios) sale de la misma resolución del BORM que su capital.

| Municipio | Comunidad | 2026 | Fuente 2026 | 2027 | Fuente 2027 |
|---|---|---|---|---|---|
| Almería (04013) | ES-AN | 24/06, 29/08 | [BOJA núm. 197, 14.10.2025](https://www.juntadeandalucia.es/boja/2025/197/28) | 24/06, 28/08 | [BOJA núm. 210, 29.10.2026](https://www.juntadeandalucia.es/boja/2026/210/BOJA26-210-00021-14189-01_00345419.pdf) |
| Cádiz (11012) | ES-AN | 16/02, 07/10 | [BOJA núm. 197, 14.10.2025](https://www.juntadeandalucia.es/boja/2025/197/28) | 08/02, 07/10 | [BOJA núm. 210, 29.10.2026](https://www.juntadeandalucia.es/boja/2026/210/BOJA26-210-00021-14189-01_00345419.pdf) |
| Córdoba (14021) | ES-AN | 08/09, 24/10 | [BOJA núm. 197, 14.10.2025](https://www.juntadeandalucia.es/boja/2025/197/28) | 08/09, 25/10 | [BOJA núm. 210, 29.10.2026](https://www.juntadeandalucia.es/boja/2026/210/BOJA26-210-00021-14189-01_00345419.pdf) |
| Granada (18087) | ES-AN | 02/01, 04/06 | [BOJA núm. 197, 14.10.2025](https://www.juntadeandalucia.es/boja/2025/197/28) | 03/05, 27/05 | [BOJA núm. 210, 29.10.2026](https://www.juntadeandalucia.es/boja/2026/210/BOJA26-210-00021-14189-01_00345419.pdf) |
| Huelva (21041) | ES-AN | 03/08, 08/09 | [BOJA núm. 197, 14.10.2025](https://www.juntadeandalucia.es/boja/2025/197/28) | 03/08, 08/09 | [BOJA núm. 210, 29.10.2026](https://www.juntadeandalucia.es/boja/2026/210/BOJA26-210-00021-14189-01_00345419.pdf) |
| Jaén (23050) | ES-AN | 11/06, 25/11 | [BOJA núm. 197, 14.10.2025](https://www.juntadeandalucia.es/boja/2025/197/28) | 11/06, 18/10 | [BOJA núm. 210, 29.10.2026](https://www.juntadeandalucia.es/boja/2026/210/BOJA26-210-00021-14189-01_00345419.pdf) |
| Málaga (29067) | ES-AN | 19/08, 08/09 | [BOJA núm. 197, 14.10.2025](https://www.juntadeandalucia.es/boja/2025/197/28) | 19/08, 08/09 | [BOJA núm. 210, 29.10.2026](https://www.juntadeandalucia.es/boja/2026/210/BOJA26-210-00021-14189-01_00345419.pdf) |
| Sevilla (41091) | ES-AN | 22/04, 04/06 | [BOJA núm. 197, 14.10.2025](https://www.juntadeandalucia.es/boja/2025/197/28) | 14/04, 27/05 | [BOJA núm. 210, 29.10.2026](https://www.juntadeandalucia.es/boja/2026/210/BOJA26-210-00021-14189-01_00345419.pdf) |
| Huesca (22125) | ES-AR | 22/01, 10/08 | [BOA núm. 225, 20.11.2025](https://www.boa.aragon.es/cgi-bin/EBOA/BRSCGI?CMD=VEROBJ&MLKOB=1421874360606) | — | pendiente (BOA, nov.) |
| Teruel (44216) | ES-AR | 07/04, 13/07 | [BOA núm. 225, 20.11.2025](https://www.boa.aragon.es/cgi-bin/EBOA/BRSCGI?CMD=VEROBJ&MLKOB=1421874360606) | — | pendiente (BOA, nov.) |
| Zaragoza (50297) | ES-AR | 29/01, 05/03 | [BOA núm. 225, 20.11.2025](https://www.boa.aragon.es/cgi-bin/EBOA/BRSCGI?CMD=VEROBJ&MLKOB=1421874360606) | — | pendiente (BOA, nov.) |
| Oviedo (33044) | ES-AS | 26/05, 21/09 | [BOPA núm. 114, 16.6.2025 (Cód. 2025-04744)](https://miprincipado.asturias.es/documents/d/guest/2025-04744) | 18/05, 21/09 | [BOPA núm. 110, 10.6.2026 (Cód. 2026-04656)](https://www.asturias.es/bopa/2026/06/10/2026-04656.pdf) |
| Santander (39075) | ES-CB | 25/05, 25/07 | [BOC núm. 238, 11.12.2025, CVE-2025-10276](https://boc.cantabria.es/boces/verAnuncioAction.do?idAnuBlob=428192) | — | pendiente (BOC, dic.) |
| Ceuta (51001) | ES-CE | 20/03, 13/06 | [BOCCE núm. 6.549, 19.9.2025](https://www.ceuta.es/ceuta/component/jdownloads/finish/1960-septiembre/22923-bocce-6549-19-09-2025?Itemid=0) | — | pendiente (BOCCE) |
| Ávila (05019) | ES-CL | 02/05, 15/10 | [BOP de Ávila núm. 186, 26.9.2025](https://www.diputacionavila.es/bops/2025/26-09-2025/26-09-2025_188425.pdf) | 03/05, 15/10 | [BOP de Ávila núm. 129, 8.7.2026](https://www.diputacionavila.es/bops/2026/08-07-2026/08-07-2026_144826.pdf) |
| Burgos (09059) | ES-CL | 12/06, 29/06 | [BOP de Burgos núm. 165, 3.9.2025, CVE BOPBUR-2025-04120 (anuncio 202504120)](http://bopbur.diputaciondeburgos.es/sites/default/files/private/publicado/bopbur-2025-165/bopbur-2025-165-anuncio-202504120.pdf) | 04/06, 29/06 | [BOP de Burgos núm. 202, 23.10.2026, CVE BOPBUR-2026-04503 (anuncio 202604503)](http://bopbur.diputaciondeburgos.es/sites/default/files/private/publicado/bopbur-2026-202/bopbur-2026-202-anuncio-202604503.pdf) |
| León (24089) | ES-CL | 24/06, 05/10 | [BOP de León núm. 177, 17.9.2025, CVE BOP-LE-2025-177019](https://bop.dipuleon.es/export/sites/bop/.galleries/Documentos-BOPs-en-PDF/bop-17_09_2025-8096efeb-92fa-11f0-a28c-dd38f9a6a5be-1758084338473.pdf) | — | pendiente (BOP de León: la capital no está aún) |
| Palencia (34120) | ES-CL | 02/02, 02/09 | [BOP de Palencia núm. 112, 17.9.2025](https://www.diputaciondepalencia.es/system/files/bop/2025/20250917-bop-112-Ordinario.pdf) | 02/02, 02/09 | [BOP de Palencia núm. 83, 13.7.2026](https://www.diputaciondepalencia.es/system/files/bop/2026/20260713-bop-83-Ordinario.pdf) |
| Salamanca (37274) | ES-CL | 12/06, 08/09 | [BOP de Salamanca núm. 234, 4.12.2025, CVE BOP-SA-20251204-001](https://sede.diputaciondesalamanca.gob.es/documentacion/bop/2025/20251204/BOP-SA-20251204-001.pdf) | 12/06, 08/09 | [BOP de Salamanca núm. 129, 8.7.2026, CVE BOP-SA-20260708-001](https://sede.diputaciondesalamanca.gob.es/documentacion/bop/2026/20260708/BOP-SA-20260708-001.pdf) |
| Segovia (40194) | ES-CL | 29/06, 26/10 | [BOP de Segovia núm. 113, 19.9.2025](https://www.dipsegovia.es/documents/39512/01582b77-49da-7674-975e-ffa4d2debaa2) | 29/06, 25/10 | [BOP de Segovia núm. 80, 6.7.2026 (RC-9105)](https://www.dipsegovia.es/documents/39512/56aab79e-edee-6aff-6ffd-544ebb560401) |
| Soria (42173) | ES-CL | 25/06, 02/10 | [BOP de Soria núm. 108, 22.9.2025 (BOPSO-108-22092025)](http://bop.dipsoria.es/index.php/mod.documentos/mem.descargar/fichero.documentos_1968_ee41f700%232E%23pdf) | 24/06, 02/10 | [BOP de Soria núm. 81, 15.7.2026 (BOPSO-81-15072026)](http://bop.dipsoria.es/index.php/mod.documentos/mem.descargar/fichero.documentos_1390_b8116e16%232E%23pdf) |
| Valladolid (47186) | ES-CL | 13/05, 08/09 | [BOP de Valladolid núm. 2025/179, 19.9.2025](https://bop.sede.diputaciondevalladolid.es/boletines/2025/septiembre/19/BOPVA-A-2025-03050.pdf) | 13/05, 08/09 | [BOP de Valladolid núm. 2026/204, 23.10.2026, BOPVA-A-2026-03085](https://bop.sede.diputaciondevalladolid.es/boletines/2026/octubre/23/BOPVA-A-2026-03085.pdf) |
| Zamora (49275) | ES-CL | 25/05, 29/06 | [BOP de Zamora núm. 106, 19.9.2025, anuncio R-202502347](https://www.diputaciondezamora.es/opencms/export/sites/dipu-zamora/servicios/BOP/.Archivos/documentos/BOP/anuncios/2025/106/202502347.pdf) | 17/05, 29/06 | [BOP de Zamora núm. 87, 27.7.2026 (anuncio 202601859)](https://www.diputaciondezamora.es/opencms/export/sites/dipu-zamora/servicios/BOP/.Archivos/documentos/BOP/anuncios/2026/87/202601859.pdf) |
| Albacete (02003) | ES-CM | 24/06, 08/09 | [DOCM núm. 240, 12.12.2025](https://docm.jccm.es/docm/descargarArchivo.do?ruta=2025/12/12/pdf/2025_9468.pdf&tipo=rutaDocm) | — | pendiente (DOCM, dic.) |
| Ciudad Real (13034) | ES-CM | 25/05, 22/08 | [DOCM núm. 240, 12.12.2025](https://docm.jccm.es/docm/descargarArchivo.do?ruta=2025/12/12/pdf/2025_9468.pdf&tipo=rutaDocm) | — | pendiente (DOCM, dic.) |
| Cuenca (16078) | ES-CM | 01/06, 21/09 | [DOCM núm. 240, 12.12.2025](https://docm.jccm.es/docm/descargarArchivo.do?ruta=2025/12/12/pdf/2025_9468.pdf&tipo=rutaDocm) | — | pendiente (DOCM, dic.) |
| Guadalajara (19130) | ES-CM | 08/09, 18/09 | [DOCM núm. 240, 12.12.2025](https://docm.jccm.es/docm/descargarArchivo.do?ruta=2025/12/12/pdf/2025_9468.pdf&tipo=rutaDocm) | — | pendiente (DOCM, dic.) |
| Toledo (45168) | ES-CM | 23/01, 26/11 | [DOCM núm. 240, 12.12.2025](https://docm.jccm.es/docm/descargarArchivo.do?ruta=2025/12/12/pdf/2025_9468.pdf&tipo=rutaDocm) | — | pendiente (DOCM, dic.) |
| Las Palmas de Gran Canaria (35016) | ES-CN | 17/02, 24/06 | [BOC núm. 165, 21.8.2025](https://www.gobiernodecanarias.org/boc/2025/165/3029.html) | 09/02, 24/06 | [BOC núm. 168, 21.8.2026](https://www.gobiernodecanarias.org/boc/2026/168/3035.html) |
| Santa Cruz de Tenerife (38038) | ES-CN | 17/02, 04/05 | [BOC núm. 165, 21.8.2025](https://www.gobiernodecanarias.org/boc/2025/165/3029.html) | 23/02, 03/05 | [BOC núm. 168, 21.8.2026](https://www.gobiernodecanarias.org/boc/2026/168/3035.html) |
| Badajoz (06015) | ES-EX | 17/02, 24/06 | [DOE núm. 204, 23.10.2025](https://doe.juntaex.es/pdfs/doe/2025/2040o/25063799.pdf) | 09/02, 24/06 | [DOE núm. 207, 27.10.2026](https://doe.juntaex.es/pdfs/doe/2026/2070o/26062650.pdf) |
| Cáceres (10037) | ES-EX | 23/04, 29/05 | [DOE núm. 204, 23.10.2025](https://doe.juntaex.es/pdfs/doe/2025/2040o/25063799.pdf) | 23/04, 28/05 | [DOE núm. 207, 27.10.2026](https://doe.juntaex.es/pdfs/doe/2026/2070o/26062650.pdf) |
| A Coruña (15030) | ES-GA | 17/02, 07/10 | [DOG núm. 210, 30.10.2025](https://www.xunta.gal/dog/Publicados/2025/20251030/AnuncioG0767-221025-0001_es.html) | 09/02, 24/06 | [DOG núm. 204, 26.10.2026](https://www.xunta.gal/dog/Publicados/2026/20261026/AnuncioG0767-161026-0001_es.html) |
| Lugo (27028) | ES-GA | 17/02, 05/10 | [DOG núm. 210, 30.10.2025](https://www.xunta.gal/dog/Publicados/2025/20251030/AnuncioG0767-221025-0001_es.html) | 09/02, 05/10 | [DOG núm. 204, 26.10.2026](https://www.xunta.gal/dog/Publicados/2026/20261026/AnuncioG0767-161026-0001_es.html) |
| Ourense (32054) | ES-GA | 17/02, 11/11 | [DOG núm. 210, 30.10.2025](https://www.xunta.gal/dog/Publicados/2025/20251030/AnuncioG0767-221025-0001_es.html) | 09/02, 11/11 | [DOG núm. 204, 26.10.2026](https://www.xunta.gal/dog/Publicados/2026/20261026/AnuncioG0767-161026-0001_es.html) |
| Pontevedra (36038) | ES-GA | 18/02, 11/07 | [DOG núm. 210, 30.10.2025](https://www.xunta.gal/dog/Publicados/2025/20251030/AnuncioG0767-221025-0001_es.html) | 10/02, 29/03 | [DOG núm. 204, 26.10.2026](https://www.xunta.gal/dog/Publicados/2026/20261026/AnuncioG0767-161026-0001_es.html) |
| Palma (07040) | ES-IB | 20/01, 24/06 | [BOIB núm. 129, 27.9.2025 (anuncio 10694)](https://www.caib.es/sites/calendarilaboral/f/529360) | 20/01, 24/06 | [BOIB núm. 83, 2.7.2026 (registro 6638)](https://www.caib.es/eboibfront/pdf/es/2026/83/1223136) |
| Murcia (30030) | ES-MC | 07/04, 15/09 | [BORM núm. 163, 17.7.2025, pág. 19390](https://www.borm.es/services/anuncio/ano/2025/numero/3546/pdf?id=837607) | 30/03, 14/09 | [BORM núm. 171, 27.7.2026](https://www.borm.es/services/anuncio/844400/pdf) |
| Melilla (52001) | ES-ML | 08/09, 17/09 | [BOME núm. 6315, 3.10.2025, art. 1033](https://bomemelilla.es/bome/descargar/BOME-A-2025-1033.pdf) | — | pendiente (BOME) |
| Pamplona/Iruña (31201) | ES-NC | 30/11, 03/12 | [BON núm. 241, 2.12.2025](https://bon.navarra.es/es/anuncio/-/texto/2025/241/12) | — | pendiente: solo se sabe el 3 dic (BON 2026/103); el propio, tras el 15 nov |
| Bilbao (48020) | ES-PV | 31/07, 28/08 | [BOB núm. 148, 6.8.2025](https://www.euskadi.eus/contenidos/informacion/5907/es_2296/calendario-laboral-BIZKAIA-2026-modificacion-cas.pdf) | 31/07, 27/08 | [BOB núm. 181, 22.9.2026, BOB-2026a181-(III-145), pp. 220-224](https://www.bizkaia.eus/lehendakaritza/Bao_bob/2026/09/BOB-2026a181.pdf) |
| Donostia/San Sebastián (20069) | ES-PV | 20/01, 31/07 | [BOG de 4.9.2025 (núm. 168, según una fuente secundaria; el PDF no lo imprime)](https://egoitza.gipuzkoa.eus/gao-bog/castell/bog/2025/09/04/c2506163.pdf) | 20/01, 31/07 | [BOG núm. 187 (número según una fuente secundaria), 1.10.2026](https://egoitza.gipuzkoa.eus/gao-bog/castell/bog/2026/10/01/c2606250.pdf) |
| Vitoria-Gasteiz (01059) | ES-PV | 28/04, 05/08 | [BOTHA núm. 82, 21.7.2025](https://www.araba.eus/BOTHA/Boletines/2025/082/2025_082_02192_C.pdf) | 28/04, 05/08 | [BOTHA núm. 116, 9.10.2026 (anuncio 2026-02851)](https://www.araba.eus/BOTHA/Boletines/2026/116/2026_116_02851_C.pdf) |
| Logroño (26089) | ES-RI | 11/06, 21/09 | [BOR núm. 159, 19.8.2025, p. 14492](https://ias1.larioja.org/boletin/Bor_Boletin_visor_Servlet?referencia=36153930-1-PDF-571537) | 11/06, 21/09 | [BOR núm. 160, 21.8.2026, p. 14689](https://ias1.larioja.org/boletin/Bor_Boletin_visor_Servlet?referencia=41863576-1-PDF-579228) |
| Alacant/Alicante (03014) | ES-VC | 16/04, 23/06 | [DOGV núm. 10238, 14.11.2025](https://dogv.gva.es/datos/2025/11/14/pdf/2025_46326_es.pdf) | — | pendiente (DOGV, nov.) |
| Castelló de la Plana/Castellón de la Plana (12040) | ES-VC | 09/03, 29/06 | [DOGV núm. 10238, 14.11.2025](https://dogv.gva.es/datos/2025/11/14/pdf/2025_46326_es.pdf) | — | pendiente (DOGV, nov.) |
| València (46250) | ES-VC | 22/01, 13/04 | [DOGV núm. 10238, 14.11.2025](https://dogv.gva.es/datos/2025/11/14/pdf/2025_46326_es.pdf) | — | pendiente (DOGV, nov.) |
| Barcelona (08019) | ES-CT | 25/05, 24/09 | [Dades Obertes Catalunya b4eh-r8up](https://analisi.transparenciacatalunya.cat/Treball/Calendari-de-festes-locals-a-Catalunya/b4eh-r8up) (Mochila) | — | pendiente (DOGC, dic.) |
| Girona (17079) | ES-CT | 25/07, 29/10 | [Dades Obertes Catalunya b4eh-r8up](https://analisi.transparenciacatalunya.cat/Treball/Calendari-de-festes-locals-a-Catalunya/b4eh-r8up) (Mochila) | — | pendiente (DOGC, dic.) |
| Lleida (25120) | ES-CT | 11/05, 29/09 | [Dades Obertes Catalunya b4eh-r8up](https://analisi.transparenciacatalunya.cat/Treball/Calendari-de-festes-locals-a-Catalunya/b4eh-r8up) (Mochila) | — | pendiente (DOGC, dic.) |
| Tarragona (43148) | ES-CT | 19/08, 23/09 | [Dades Obertes Catalunya b4eh-r8up](https://analisi.transparenciacatalunya.cat/Treball/Calendari-de-festes-locals-a-Catalunya/b4eh-r8up) (Mochila) | — | pendiente (DOGC, dic.) |
| Madrid (28079) | ES-MD | 15/05, 09/11 | [BOCM núm. 296, 12.12.2025](https://www.bocm.es/bocm-20251212-34) (Mochila) | — | pendiente (BOCM, dic.) |

Comprobaciones hechas y avisos:

- **Fechas en sábado** (son laborables para muchos turnos, se incluyen): Almería 29/08/2026 y 28/08/2027, Córdoba
  24/10/2026, Ciudad Real 22/08/2026, Santander 25/07/2026, Ceuta 13/06/2026, Salamanca 12/06/2027, Soria
  02/10/2027, Bilbao y Donostia 31/07/2027. Ninguna cae en domingo.
- **Santa Cruz de Tenerife 2027:** el «martes de Carnaval» es el 23/02 (el Ayuntamiento retrasó el Carnaval dos
  semanas), no el 9/02 del calendario. Es lo que publica el BOC.
- **Pliego (Murcia) 2026:** el BORM dice «viernes 2 de febrero», pero es lunes; se toma la fecha.
- **Pamplona 2027** no se incluye: solo se sabe el 3 de diciembre; su día propio se publica tras el 15 de noviembre.
  Mejor que la app avise de que faltan que dar uno solo como si estuvieran los dos.
- Textos leídos en una copia (el boletín oficial no se pudo abrir entero) y citados por su boletín: León 2026 (copia
  con el mismo CVE), Aragón 2026 (anexo leído en una reproducción; cabecera del BOA comprobada), Ceuta 2026 (BOCCE
  6.551 en reproducción) y el decreto de Madrid 2027. Las correcciones posteriores que se encontraron (BOJA, DOE, DOCM,
  DOGV, DOG, BOA, BON, BOB) no tocan a las capitales; Bilbao 2026 ya lleva la modificación del BOB núm. 148.
- Las listas de 2027 de Andalucía (BOJA 29.10.2026) y Extremadura (DOE 27.10.2026) son recientes: en 2026 hubo
  correcciones meses después. Revisar antes de cada versión.

## Qué falta para la v1

- **Locales de 2027 aún sin publicar** (31-oct-2026): Cataluña (DOGC, diciembre), Madrid (BOCM, diciembre),
  Castilla-La Mancha (DOCM, diciembre), Aragón (BOA, noviembre), Comunitat Valenciana (DOGV, noviembre), Cantabria
  (BOC, diciembre), Ceuta, Melilla, León (no está en los BOP de julio ni de octubre) y el día propio de Pamplona. La
  app ya avisa del año que falta; al salir, se añaden a `tool/holidays_es/2027/` y se regenera el paquete.
- **Locales del resto de municipios.** No existe un conjunto abierto fuera de Cataluña y Madrid. Lo siguiente:
  municipios de más de 50.000 habitantes (~150, decisión pendiente §12). Casi todas las comunidades publican **una
  sola resolución** con todos sus municipios (BOJA, DOGV, DOG, BOC, BOPV…), así que cada una se puede volcar entera
  como Murcia; Castilla y León y País Vasco van por provincia (BOP, BOTHA, BOB, BOG). Mientras, el festivo local
  manual en dos toques (`HolidayController.addUserHoliday`).
- **Cataluña:** 77 municipios sin fila (la lista, en el `note` de Mochila). Madrid: 16 sin comunicar.
- **Mochila** sigue teniendo los locales de Murcia del calendario escolar; aquí se ignoran. Conviene corregirlo allí
  también (necesita su visto bueno).
- **UI:** `HolidayController` (`setPlace`, `addUserHoliday`, `removeUserHoliday`) y `MunicipalityIndex`
  (`HolidayBundleLoader.loadMunicipalities`) ya están listos para ella.
- **`main.dart`:** añadir `initialHolidaysProvider.overrideWithValue(boot.holidays)` a los overrides para que el
  primer fotograma ya marque festivos (sin él se cargan en cuanto arranca la app, sin parpadeo apreciable pero no
  instantáneo).
- Descarga remota (abajo).

## Mantenimiento anual

1. **Octubre:** sale el BOE nacional del año siguiente. En Mochila, el PR automático de festivos lo añade al
   manifiesto como `verified`/`complete`.
2. **Noviembre–diciembre:** autonómicos y locales (DOGC/BOCM, etc.). Cuando un `…/{año}.json` pasa de `pending` a
   `complete`, ya entra. Los locales que no vienen de Mochila (capitales, Murcia, insulares de Canarias) se añaden a
   mano en `app/tool/holidays_es/{año}/ES-XX.json` desde el boletín oficial (formato arriba), con su fila en la tabla
   de procedencia.
3. Desde `app/`:
   ```
   dart run tool/build_holidays.dart                 # --mochila <ruta al repositorio hermano> si no está al lado
   ```
   Imprime los archivos, los tamaños y lo **omitido** (no verificado o sin publicar). Si avisa de carpetas que faltan
   en `pubspec.yaml` (un año nuevo es una carpeta nueva: Flutter no baja a subcarpetas), añadir las líneas
   `- assets/holidays/{año}/` y `- assets/holidays/{año}/municipal/`. Una prueba falla si se olvida alguna.
   Los países de «Otros países» se regeneran aparte (`tool/export_country_holidays.py`); esta herramienta los conserva.
4. `flutter analyze && flutter test`. Las pruebas comprueban que cada archivo coincide con su suma del manifiesto y
   que el paquete se carga desde los assets reales. `dart run tool/build_holidays.dart --check` dice si el paquete
   incluido está al día respecto a Mochila.
5. Revisar el `git diff` de `assets/holidays/` (los archivos son estables: una línea por municipio, orden fijo) y
   publicar versión. Al instalar la app nueva, `bundleVersion` cambia y la base de datos se refresca sola; los
   festivos propios no se tocan.
6. **Enero:** correcciones de Mochila → repetir desde el paso 3.

## Descarga remota (por construir)

Se mantiene como en `plan-publicacion.md` («Festivos: cómo consumir los de Mochila»): un paso de CI en Mochila publica
`holidays/v1/manifest.json` (+ firma Ed25519), `holidays/v1/{año}/es.json` y `…/municipal/ES-XX.json` solo con
archivos verificados; la app los baja como mucho una vez al día, comprueba firma y sumas, y guarda las filas con
`source = remote`. Nada de esto está hecho, y toca el repositorio de Mochila: **necesita el visto bueno** antes de
cambiar allí nada. Lo que ya está preparado para ello:

- El formato del paquete incluido es el mismo que el remoto (mismos caminos, mismo `manifest.json`); la descarga solo
  añade la firma y el transporte.
- `HolidaySource.remote` existe en la tabla y en `HolidayCalendar` (a igual nivel, la fila remota gana a la incluida).
- `refreshBundled` solo borra filas `bundled`: una descarga futura escribirá las suyas con `remote` sin chocar.
  Pendiente de decidir entonces: qué hacer con filas incluidas y remotas del mismo año (hoy conviven y gana la remota
  por día; lo limpio será borrar las `bundled` de los años que la descarga cubra).

## Lo de `official.ts` que no se replica

- **Idiomas:** el paquete trae solo español (`label.es`). Los nombres de **todos** los festivos de España (estatales, autonómicos
  e insulares y locales con nombre: «Fiesta local (lugar)» lleva el lugar tal cual) se traducen al mostrarse (ca, gl, eu, en), con claves `holidayName*` de los ARB y
  `lib/features/holidays/presentation/holiday_names.dart`; el paquete no tiene ids, así que la clave estable es el
  nombre en español plegado (`foldSpanish`). Una prueba (`holiday_names_test.dart`) falla si un nombre de España del paquete se queda sin clave en alguno de los cuatro idiomas: al añadir un año o un festivo, añade la clave. Un nombre sin traducción se muestra tal cual viene del paquete, y un
  festivo añadido por la persona nunca se traduce (H-T21-1).
- **Cobertura** (`officialCoverage`: disponible/pendiente/faltante): no se guarda en la base de datos. La UI puede
  deducir «sin datos locales para tu municipio» comprobando si hay filas `local`; «pendiente» se sabe leyendo
  `manifest.json` (un año sin `municipal/ES-XX.json`).
- **`source` y `ref` por día:** quedan por archivo en el manifiesto, no por fila.
- **`municipalNonTeaching`** (días no lectivos de Murcia) y los calendarios escolares: no son festivos y no están
  en el alcance.
- **Festivos insulares de Canarias:** `official.ts` no los sirve; aquí sí (arriba), repartidos por municipio.
