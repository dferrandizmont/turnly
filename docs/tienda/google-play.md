# Google Play · ficha de la tienda

> **Actualizado · 4-nov-2026 (app 0.8.4).** La ficha está publicada en prueba cerrada desde la 0.6.16/0.6.17 con los textos de la 0.6; aquí está el texto que hay que dejar en la consola en la próxima subida (0.8.4 o posterior). **La app es totalmente gratuita y de código abierto** (decisión del usuario del 26-oct-2026): sin compras, sin suscripciones, sin anuncios y sin cuentas. No hay ningún precio que insertar ni condiciones de compra que redactar. Nombre: **Turnly** (decisión del usuario del 30-oct-2026, pregunta 20; antes «Cuadrante»). Cada título lleva la palabra de búsqueda local (cuadrante, quadrant, cadro de quendas, txanden egutegia, shift calendar).

Los bloques de texto son los campos para copiar; los títulos, recuentos y notas son internos. Recuento en caracteres Unicode normalizados NFC, incluidos espacios, signos y saltos de línea LF; sin el salto final del bloque (contado con un script el 4-nov-2026). Idiomas en orden: es, ca, gl, eu, en. Inglés neutro con grafía US. Los nombres de las funciones son los de los ARB de cada idioma («Mantener al día», «Probar restauración», «Libro de cambios»…). Revisión nativa de ca/gl/eu pendiente según el glosario.

Fuentes leídas: [especificación §7](../../turnos-spec.md), [CHANGELOG](../../CHANGELOG.md) (0.7.0 a 0.8.4), [publicación](../plan-publicacion.md), [preguntas](../preguntas.md), [glosario](../glosario-idiomas.md), los ARB de `app/lib/l10n/` y el informe de revisión de MiniMax del 3-nov-2026 (sus correcciones de gallego y euskera se comprobaron una a una; varias no se aplicaron).

## Alcance antes de publicar

La ficha describe lo que hay en la app de Android 0.8.4; no certifica que el build esté listo. Verificar el candidato, la matriz de restauración, los siete días del widget y los idiomas. **Solo para Android:** la copia automática en una carpeta y silenciar el móvil en los turnos son de Android (`Platform.isAndroid`); quien reutilice estos textos en `docs/tienda/app-store.md` tiene que quitarlas o decir «en Android». No anunciar copia automática en iCloud (la réplica sigue apagada, `kICloudReplica = false`), compartir por enlace (construido, apagado hasta que se despliegue el servidor), reloj ni iPad.

**Todo es gratuito (decisión del 26-oct-2026):** no hay plan Pro, ni compras, ni suscripciones, ni anuncios, ni cuentas. En los textos públicos no se dice «gratis» de una función: se dice que la app entera es gratuita, y se anuncia solo lo que existe. En la 0.8.4 hay: pintar, patrones, varios turnos por día, varios calendarios y la comparación de hasta seis, los seis widgets de Android (hoy, semana, mes, agenda, dos semanas y cuatro semanas), notas con adjuntos y tareas, copias y «Probar restauración», copia automática diaria en una carpeta, alarmas de turno (programadas 30 días por delante), silenciar el móvil en los turnos, festivos de España y de 21 países más, importación (LRHSoft, calendario del móvil, `.ics` y CSV), exportación al calendario del móvil (puntual o con «Mantener al día») y a un archivo `.ics`, citas del móvil (solo lectura), informes PDF y CSV, imágenes del mes y del año, vacaciones y permisos con saldos, libro de cambios, y resumen de horas y dinero (nocturnas y festivas, extras, salidas anticipadas, objetivo y bolsa de horas, precio por hora, plus fijo por turno, plus nocturno y festivo por hora, importe extra por día, retención y sueldo neto estimado).

Los calendarios no tienen límite comercial y la sección «Cuadrante Pro» ya está retirada de Ajustes. Pendientes y **sin anunciar** hasta que existan: la jornada anual y el saldo contra convenio; los temas de la app; y compartir por enlace de solo lectura.

Política de privacidad: `https://turnly.mainshai.com/privacy/` (en inglés, `/en/privacy/`). Web: `https://turnly.mainshai.com`. Soporte: `turnly@mainshai.com`. No hay condiciones de compra ni de suscripción que adjuntar: la app no vende nada.

## Textos públicos localizados

## es · Español

### Título · 27/30 caracteres

```text
Turnly: Cuadrante de turnos
```

### Descripción breve · 77/80 caracteres

```text
Calendario de turnos de trabajo, widget y copias. Gratis y de código abierto.
```

### Descripción completa · 3166/4000 caracteres

```text
Tus turnos, de un vistazo. Turnly te ayuda a organizar mañanas, tardes, noches, guardias, salientes y días libres, sin cuenta, sin anuncios, sin compras y sin conexión.

Pinta los días o aplica un patrón de correturnos, 24/72, 4x4 o tu propia rotación. Añade varios turnos en un día y consulta cada uno con color, código y horario. Mira el mes, la agenda o el año. En cada día puedes escribir una nota, añadir fotos, dibujos o archivos y llevar una lista de tareas.

SEIS WIDGETS QUE CAMBIAN DE DÍA SOLOS
Hoy, la semana, el mes, la agenda, dos semanas o cuatro semanas, sin abrir la app. El cambio de día depende de los permisos y las restricciones del sistema.

ALARMAS DE TURNO
Cada tipo de turno puede tener su aviso, que suena como una alarma de despertador y se programa con un mes de margen. Turnly también puede silenciar el móvil durante los turnos que elijas y devolverle el sonido al acabar.

COPIAS QUE PUEDES COMPROBAR
Turnly guarda copias en el móvil y, con «Probar restauración», compruebas que se pueden recuperar. Antes de restaurar ves qué contienen. La copia automática en una carpeta deja una al día en la carpeta que elijas (Drive, Dropbox, OneDrive o el propio móvil) y guarda las 10 últimas. Para cambiar de móvil, lleva un archivo .turnly al nuevo: las copias que se quedan dentro de la app se pierden al desinstalarla.

TRAE Y LLEVA TUS TURNOS
Importa tu copia .Shifter de LRHSoft (Calendario de Turnos), el calendario del móvil, un .ics o un CSV, y revisa la vista previa antes de guardar. Con «Mantener al día», tus turnos pasan al calendario del móvil y se actualizan cada vez que cambias el cuadrante; también puedes guardarlos en un archivo .ics. Y las citas del móvil se ven junto a tus turnos.

FESTIVOS SIN CONEXIÓN
Los festivos nacionales y autonómicos de España, los locales de muchos municipios y los oficiales de 21 países más vienen incluidos en la app. Añade los tuyos a mano.

HORAS Y DINERO
Revisa las horas trabajadas, nocturnas y festivas, las horas extra y las salidas anticipadas por mes, trimestre, año o las fechas que elijas, con tu objetivo de horas y la bolsa de horas. Con el precio por hora, los pluses fijos, nocturnos y festivos y el importe extra de cada día, Turnly estima tu sueldo bruto y, con tu retención, el neto. Saca informes en PDF o CSV para compartirlos.

VACACIONES, PERMISOS Y CAMBIOS
Lleva el saldo de vacaciones, moscosos y permisos de cada año, con los días arrastrados y cuándo caducan. En el libro de cambios apuntas los turnos que cambias con tus compañeros, quién debe a quién, y los aplicas al calendario. Compara hasta seis calendarios y mira qué días libráis a la vez.

A TU GUSTO
Formato de hora y de fecha, primer día de la semana, moneda, cinco colores de acento, paletas preparadas para tus turnos y una imagen de fondo para el calendario.

EN TU IDIOMA
Español, català, galego, euskara y English, con selector de idioma. Para sanidad, policía, bomberos, industria y cualquier trabajo a turnos.

GRATUITA Y DE CÓDIGO ABIERTO
Todo lo que hay en la app es gratis, y el código es abierto: puedes revisarlo y compilarlo tú mismo. Sin cuentas, sin anuncios, sin compras y sin suscripciones.
```

## ca · Català

### Título · 25/30 caracteres

```text
Turnly: Quadrant de torns
```

### Descripción breve · 79/80 caracteres

```text
Calendari de torns de treball, widget al dia i còpies. Gratuït i de codi obert.
```

### Descripción completa · 3150/4000 caracteres

```text
Els teus torns, d’un cop d’ull. Turnly t’ajuda a organitzar matins, tardes, nits, guàrdies, sortints i dies lliures, sense compte, sense anuncis, sense compres i sense connexió.

Pinta els dies o aplica un patró de torns rotatius, 24/72, 4x4 o la teva pròpia rotació. Afegeix diversos torns en un dia i consulta’ls amb color, codi i horari. Mira el mes, l’agenda o l’any. A cada dia pots escriure una nota, afegir-hi fotos, dibuixos o fitxers i portar una llista de tasques.

SIS WIDGETS QUE CANVIEN DE DIA SOLS
Avui, la setmana, el mes, l’agenda, dues setmanes o quatre setmanes, sense obrir l’app. El canvi de dia depèn dels permisos i les restriccions del sistema.

ALARMES DE TORN
Cada tipus de torn pot tenir el seu avís, que sona com una alarma de despertador i es programa amb un mes de marge. Turnly també pot silenciar el mòbil durant els torns que triïs i tornar-li el so quan acabes.

CÒPIES QUE POTS COMPROVAR
Turnly desa còpies al mòbil i, amb «Prova la restauració», comproves que es poden recuperar. Abans de restaurar veus què contenen. La còpia automàtica en una carpeta en deixa una cada dia a la carpeta que triïs (Drive, Dropbox, OneDrive o el mateix mòbil) i en guarda les 10 últimes. Per canviar de mòbil, porta un fitxer .turnly al nou: les còpies que queden dins de l’app es perden en desinstal·lar-la.

IMPORTA I EXPORTA ELS TEUS TORNS
Importa la còpia .Shifter de LRHSoft (Calendario de Turnos), el calendari del mòbil, un .ics o un CSV, i revisa la vista prèvia abans de desar. Amb «Mantenir al dia», els teus torns passen al calendari del mòbil i s’actualitzen cada vegada que canvies el quadrant; també els pots desar en un fitxer .ics. I les cites del mòbil es veuen al costat dels teus torns.

FESTIUS SENSE CONNEXIÓ
Els festius nacionals i autonòmics d’Espanya, els locals de molts municipis i els oficials de 21 països més venen inclosos a l’app. Afegeix els teus a mà.

HORES I DINERS
Revisa les hores treballades, nocturnes i festives, les hores extra i les sortides anticipades per mes, trimestre, any o les dates que triïs, amb el teu objectiu d’hores i la borsa d’hores. Amb el preu per hora, els plusos fixos, nocturns i festius i l’import extra de cada dia, Turnly estima el teu sou brut i, amb la teva retenció, el net. Treu informes en PDF o CSV per compartir-los.

VACANCES, PERMISOS I CANVIS
Porta el saldo de vacances, dies de lliure disposició i permisos de cada any, amb els dies arrossegats i quan caduquen. Al llibre de canvis apuntes els torns que canvies amb els companys, qui deu què a qui, i els apliques al calendari. Compara fins a sis calendaris i mira quins dies teniu lliures alhora.

AL TEU GUST
Format d’hora i de data, primer dia de la setmana, moneda, cinc colors d’accent, paletes preparades per als teus torns i una imatge de fons per al calendari.

EN EL TEU IDIOMA
Español, català, galego, euskara i English, amb selector d’idioma. Per a sanitat, policia, bombers, indústria i qualsevol feina a torns.

GRATUÏTA I DE CODI OBERT
Tot el que hi ha a l’app és gratuït, i el codi és obert: el pots revisar i compilar tu mateix. Sense comptes, sense anuncis, sense compres ni subscripcions.
```

## gl · Galego

### Título · 24/30 caracteres

```text
Turnly: Cadro de quendas
```

### Descripción breve · 68/80 caracteres

```text
Calendario de quendas, widget e copias. De balde e de código aberto.
```

### Descripción completa · 3113/4000 caracteres

```text
As túas quendas, dunha ollada. Turnly axúdache a organizar mañás, tardes, noites, gardas, saíntes e días libres, sen conta, sen anuncios, sen compras e sen conexión.

Pinta os días ou aplica un patrón de quendas rotativas, 24/72, 4x4 ou a túa propia rotación. Engade varias quendas nun día e consulta cada unha con cor, código e horario. Mira o mes, a axenda ou o ano. En cada día podes escribir unha nota, engadir fotos, debuxos ou ficheiros e levar unha lista de tarefas.

SEIS WIDGETS QUE CAMBIAN DE DÍA SÓS
Hoxe, a semana, o mes, a axenda, dúas semanas ou catro semanas, sen abrir a app. O cambio de día depende dos permisos e das restricións do sistema.

ALARMAS DE QUENDA
Cada tipo de quenda pode ter o seu aviso, que soa como unha alarma de espertador e prográmase cun mes de marxe. Turnly tamén pode silenciar o móbil durante as quendas que escollas e devolverlle o son ao remataren.

COPIAS QUE PODES COMPROBAR
Turnly garda copias no móbil e, con «Probar restauración», comprobas que se poden recuperar. Antes de restaurar ves que conteñen. A copia automática nun cartafol deixa unha ao día no cartafol que escollas (Drive, Dropbox, OneDrive ou o propio móbil) e garda as 10 últimas. Para cambiar de móbil, leva un ficheiro .turnly ao novo: as copias que quedan dentro da app pérdense ao desinstalala.

TRAE E LEVA AS TÚAS QUENDAS
Importa a túa copia .Shifter de LRHSoft (Calendario de Turnos), o calendario do móbil, un .ics ou un CSV, e revisa a vista previa antes de gardar. Con «Manter ao día», as túas quendas pasan ao calendario do móbil e actualízanse cada vez que cambias o cadro; tamén podes gardalas nun ficheiro .ics. E as citas do móbil vense xunto ás túas quendas.

FESTIVOS SEN CONEXIÓN
Os festivos nacionais e autonómicos de España, os locais de moitos municipios e os oficiais de 21 países máis veñen incluídos na app. Engade os teus á man.

HORAS E DIÑEIRO
Revisa as horas traballadas, nocturnas e festivas, as horas extra e as saídas anticipadas por mes, trimestre, ano ou as datas que escollas, co teu obxectivo de horas e a bolsa de horas. Co prezo por hora, os pluses fixos, nocturnos e festivos e o importe extra de cada día, Turnly estima o teu soldo bruto e, coa túa retención, o neto. Saca informes en PDF ou CSV para compartilos.

VACACIÓNS, PERMISOS E CAMBIOS
Leva o saldo de vacacións, días de libre disposición e permisos de cada ano, cos días arrastrados e cando caducan. No libro de cambios apuntas as quendas que cambias cos compañeiros, quen lle debe a quen, e aplícalas ao calendario. Compara ata seis calendarios e mira que días tedes libres á vez.

AO TEU GUSTO
Formato de hora e de data, primeiro día da semana, moeda, cinco cores de acento, paletas preparadas para as túas quendas e unha imaxe de fondo para o calendario.

NO TEU IDIOMA
Español, català, galego, euskara e English, con selector de idioma. Para a sanidade, a policía, os bombeiros, a industria e calquera traballo a quendas.

DE BALDE E DE CÓDIGO ABERTO
Todo o que hai na app é de balde, e o código é aberto: podes revisalo e compilalo ti mesmo. Sen contas, sen anuncios, sen compras nin subscricións.
```

## eu · Euskara

### Título · 24/30 caracteres

```text
Turnly: Txanden egutegia
```

### Descripción breve · 72/80 caracteres

```text
Lan-txanden egutegia, widgeta eta babeskopiak. Doakoa eta kode irekikoa.
```

### Descripción completa · 3495/4000 caracteres

```text
Zure txandak, begirada batean. Turnly aplikazioarekin goizeko, arratsaldeko eta gaueko txandak, guardiak, gau-ondokoak eta egun libreak antola ditzakezu, konturik, iragarkirik, erosketarik eta Interneteko konexiorik gabe.

Margotu egunak edo aplikatu txanda birakarien eredua, 24/72, 4x4 edo zure txandaketa. Gehitu hainbat txanda egun berean, bakoitza kolorearekin, kodearekin eta ordutegiarekin. Ikusi hilabetea, agenda edo urtea. Egun bakoitzean oharra idatz dezakezu, argazkiak, marrazkiak edo fitxategiak erantsi eta zereginen zerrenda bat egin.

EGUNA BEREZ ALDATZEN DUTEN SEI WIDGET
Gaur, astea, hilabetea, agenda, bi aste edo lau aste, aplikazioa ireki gabe. Egun-aldaketa sistemaren baimenen eta murrizketen araberakoa da.

TXANDA-ALARMAK
Txanda mota bakoitzak bere abisua izan dezake: iratzargailu-alarma gisa jotzen du, eta hilabeteko tartearekin programatzen da. Gainera, zuk aukeratutako txandetan Turnly-k mugikorra isildu eta, txanda amaitzean, soinua itzul dezake.

EGIAZTA DITZAKEZUN BABESKOPIAK
Turnly-k babeskopiak gordetzen ditu mugikorrean, eta «Probatu leheneratzea» erabiliz berreskura daitezkeela egiazta dezakezu. Leheneratu aurretik, zer duten ikusten duzu. «Kopia automatikoa karpeta batean» aukerak egunean kopia bat uzten du aukeratzen duzun karpetan (Drive, Dropbox, OneDrive edo mugikorra bera), eta azken 10ak gordetzen ditu. Mugikorrez aldatzeko, eraman .turnly fitxategi bat berrira: aplikazioaren barruan geratzen diren kopiak galdu egiten dira desinstalatzean.

EKARRI ETA ERAMAN ZURE TXANDAK
Inportatu LRHSoft-en (Calendario de Turnos) .Shifter kopia, mugikorreko egutegia, .ics bat edo CSV bat, eta berrikusi aurrebista gorde aurretik. «Eguneratuta mantendu» aukerarekin, zure txandak mugikorreko egutegira pasatzen dira, eta txandak aldatzen dituzun bakoitzean eguneratzen dira; .ics fitxategi batean ere gorde ditzakezu. Mugikorreko hitzorduak ere zure txanden ondoan ikusten dira.

JAIEGUNAK KONEXIORIK GABE
Espainiako estatuko eta erkidegoetako jaiegunak, udalerri askotako tokikoak eta beste 21 herrialdetako jaiegun ofizialak aplikazioan bertan datoz. Gehitu zureak eskuz.

ORDUAK ETA DIRUA
Berrikusi lan egindako orduak, gauekoak eta jaiegunetakoak, aparteko orduak eta irteera aurreratuak hilabeteka, hiruhilekoka, urteka edo zuk aukeratutako datetan, zure ordu-helburuarekin eta ordu-poltsarekin. Orduko prezioarekin, plus finkoekin, gaueko eta jaieguneko plusekin eta egun bakoitzeko zenbateko gehigarriarekin, Turnly-k soldata gordina zenbatesten du, eta zure atxikipenarekin, garbia. Atera PDF edo CSV txostenak, partekatzeko.

OPORRAK, BAIMENAK ETA ALDAKETAK
Kontrolatu urte bakoitzeko oporren, norberaren egunen eta baimenen saldoa, aurreko urtetik ekarritako egunekin eta noiz iraungitzen diren. Trukeen liburuan, lankideekin trukatzen dituzun txandak idazten dituzu, nork zor dion nori, eta egutegian aplikatzen dituzu. Alderatu sei egutegi arte, eta ikusi zein egunetan zaudeten guztiak libre.

ZURE GUSTURA
Ordu- eta data-formatua, asteko lehen eguna, moneta, bost azentu-kolore, zure txandetarako prestatutako paletak eta egutegiaren atzeko irudia.

ZURE HIZKUNTZAN
Español, català, galego, euskara eta English, hizkuntza hautatzeko aukerarekin. Osasungintzarako, poliziarako, suhiltzaileentzat, industriarako eta txandaka lan egiten duen edonorentzat.

DOAKOA ETA KODE IREKIKOA
Aplikazioan dagoen guztia doakoa da, eta kodea irekia da: berrikusi eta konpilatu dezakezu zeuk ere. Konturik, iragarkirik, erosketarik eta harpidetzerik gabe.
```

## en · English

### Título · 27/30 caracteres

```text
Turnly: Work Shift Calendar
```

### Descripción breve · 69/80 caracteres

```text
Your shifts, widgets and backups you can check. Free and open source.
```

### Descripción completa · 3045/4000 caracteres

```text
Your shifts at a glance. Turnly helps you plan mornings, afternoons, nights, 24-hour shifts, post-night days and days off, without an account, ads, purchases or an internet connection.

Paint days or apply a rotating shift pattern, 24/72, 4x4 or your own rotation. Add several shifts to a day and see each one with a color, code and times. View the month, the agenda or the year. On each day you can write a note, add photos, drawings or files and keep a task list.

SIX WIDGETS THAT CHANGE DAY ON THEIR OWN
Today, the week, the month, the agenda, two weeks or four weeks, without opening the app. Day changes depend on system permissions and restrictions.

SHIFT ALARMS
Each shift type can have its own alarm, which rings like an alarm clock and is scheduled a month ahead. Turnly can also silence your phone during the shifts you pick and bring the sound back when they end.

BACKUPS YOU CAN CHECK
Turnly keeps backups on your phone, and Test restore checks that they can be recovered. Before restoring, you see what they contain. Automatic backup to a folder leaves one copy a day in the folder you choose (Drive, Dropbox, OneDrive or the phone itself) and keeps the last 10. To change phones, take a .turnly file to the new one: the backups that stay inside the app are lost when you uninstall it.

BRING YOUR SHIFTS IN AND OUT
Import your .Shifter backup from LRHSoft (Calendario de Turnos), your phone calendar, an .ics or a CSV file, and review the preview before saving. With Keep up to date, your shifts go to your phone calendar and update every time you change your schedule; you can also save them as an .ics file. And your phone events show next to your shifts.

PUBLIC HOLIDAYS OFFLINE
Spain’s national and regional public holidays, the local ones of many municipalities and the official holidays of 21 more countries come with the app. Add your own by hand.

HOURS AND MONEY
Check worked, night and public holiday hours, overtime and early leave by month, quarter, year or any dates, with your hours goal and hours bank. With your hourly rate, fixed, night and holiday premiums and an extra amount per day, Turnly estimates your gross pay and, with your withholding, your net pay. Get PDF or CSV reports to share.

VACATION, LEAVE AND SWAPS
Track your vacation, personal days and leave balance for each year, with carried-over days and when they expire. In the swap book you write down the shifts you swap with colleagues and who owes whom, and apply them to the calendar. Compare up to six calendars to see the days you are all off.

MAKE IT YOURS
Time and date format, first day of the week, currency, five accent colors, ready-made palettes for your shifts and a calendar background image.

IN YOUR LANGUAGE
Español, català, galego, euskara and English, with a language selector. For healthcare, police, firefighters, industry and anyone who works shifts.

FREE AND OPEN SOURCE
Everything in the app is free, and the code is open: you can review it and build it yourself. No accounts, no ads, no purchases and no subscriptions.
```

### Novedades

Las notas de cada subida están en [`novedades.md`](novedades.md). Las de la primera publicación (0.6.12) ya no se usan.

### Correcciones de idioma del informe de MiniMax (3-nov-2026)

| Propuesta | Decisión |
|---|---|
| gl «a copia local pódese perder» | **No.** «perder» con «se» es la pasiva refleja normal en galego: «pérdese» (singular) o «pérdense» (plural), que es lo que se usa ahora. |
| gl «Mantemento ao día» | **No.** El nombre en la app es «Manter ao día» (`calSyncTitle` de `app_gl.arb`). |
| gl «dineiro», «turnos» | **No.** Es «diñeiro» y, en este contexto, «quendas». |
| gl «Para a sanidade» | **Sí.** Ahora: «Para a sanidade, a policía, os bombeiros, a industria…». |
| eu «zure udalerriko» | La frase se ha reescrito («udalerri askotako tokikoak»). |
| eu «Inportatu zure LRHSoft (.Shifter) kopiaren datuak» | **Reescrita** de otra forma: «Inportatu LRHSoft-en (Calendario de Turnos) .Shifter kopia». Su texto completo en euskera traía además errores («E alderantz», «soin», «garatutako soldata»): no se copió. |

## Permisos de Android · justificación

Play pide justificar los permisos sensibles en *App content* (alarmas exactas y, si la consola lo pregunta, el acceso a «No molestar») y los revisa contra la ficha. El manifiesto de release (`app/android/app/src/main/AndroidManifest.xml`, comprobado el 4-nov-2026) declara estos **8**; `FOREGROUND_SERVICE` y `FOREGROUND_SERVICE_SHORT_SERVICE`, que añade `workmanager`, se **quitan** con `tools:node="remove"`. No hay `INTERNET` en release. Verificar contra el manifiesto fusionado del AAB (`bundletool dump manifest`).

| Permiso | Tipo | Para qué (texto para la consola, en inglés si lo pide) | Cuándo se pide |
|---|---|---|---|
| `POST_NOTIFICATIONS` | En tiempo de ejecución (Android 13+) | Mostrar las alarmas de turno y los recordatorios de las notas. / *Show shift alarms and note reminders.* | Al activar las alarmas o probar una, nunca al arrancar |
| `SCHEDULE_EXACT_ALARM` | Acceso especial («Alarmas y recordatorios») | Que el aviso de cada turno suene a la hora que el usuario fijó, que el silencio de los turnos empiece y acabe a su hora y que el widget cambie de día a medianoche. Sin él, avisos inexactos. No se usa `USE_EXACT_ALARM`. / *Shift alarms must ring at the exact time the user set; the shift silence must start and end on time; the widget changes day at midnight.* | La app explica y abre el ajuste del sistema |
| `ACCESS_NOTIFICATION_POLICY` | Acceso especial («Acceso a No molestar») | «Silenciar el móvil en mis turnos»: poner el móvil en No molestar al empezar los turnos que el usuario elige y quitarlo al acabar. Nunca toca la wifi ni el Bluetooth. / *“Silence the phone on my shifts”: turns Do Not Disturb on during the shifts the user picks and off when they end.* | Solo al encender esa opción; la app explica y abre el ajuste del sistema |
| `RECEIVE_BOOT_COMPLETED` | Normal | Volver a programar las alarmas y el silencio de los turnos tras reiniciar el móvil o actualizar la app. | Se concede al instalar |
| `VIBRATE` | Normal | Vibrar con las alarmas de turno. | Se concede al instalar |
| `HIDE_OVERLAY_WINDOWS` | Normal | Que otra app no pueda tapar la vista previa de restaurar una copia (protección contra *tapjacking*). | Se concede al instalar |
| `READ_CALENDAR` | En tiempo de ejecución | Importar turnos desde el calendario del móvil, mostrar las citas del móvil de los calendarios que el usuario elige (solo lectura) y que «Mantener al día» encuentre sus propios eventos. / *Import shifts from the phone calendar and show the phone events of the calendars the user picks, read-only.* | Al importar, al activar «Citas del móvil» o al exportar |
| `WRITE_CALENDAR` | En tiempo de ejecución | Exportar los turnos al calendario del móvil, una vez o con «Mantener al día» (al cambiar el cuadrante y al abrir la app, nunca en segundo plano). Solo crea y cambia sus propios eventos. / *Export shifts to the phone calendar, once or with “Keep up to date”; it only touches its own events.* | Al exportar o al activar «Mantener al día» |

La cámara y la galería de los adjuntos se usan con el selector y la cámara del sistema: la app no declara `CAMERA` ni permisos de almacenamiento.

## Categoría, etiquetas y términos de búsqueda

- Tipo: aplicación; categoría propuesta: **Productividad / Productivity**. No es un juego.
- Etiquetas de consola candidatas: **Calendario / Calendar**, **Productividad / Productivity**, **Planificador personal / Personal planner**. Verificar los nombres disponibles en Play Console; seleccionar solo los que existan y describan la app, hasta el máximo que permita la consola.
- Google Play no tiene un campo independiente de keywords. La tabla siguiente es para investigación ASO; no pegarla como bloque de palabras en la descripción.

| Idioma | Términos de búsqueda internos |
|---|---|
| es | calendario de turnos, cuadrante, correturnos, guardias, saliente, moscosos, horas nocturnas, festivos locales |
| ca | calendari de torns, quadrant, torns rotatius, guàrdies, sortint, lliure disposició, hores nocturnes, festius locals |
| gl | calendario de quendas, cadro de quendas, quendas rotativas, gardas, saínte, libre disposición, horas nocturnas, festivos locais |
| eu | txanden egutegia, txandaketa, txanda birakariak, guardia, gau-ondokoa, norberaren egunak, gaueko orduak, tokiko jaiegunak |
| en | shift calendar, shift schedule, roster, rota, rotating shifts, post-night, personal days, night hours, local holidays |

## Clasificación de contenido · respuestas de consola

Respuestas administrativas comunes a las cinco fichas; no se traducen ni se pegan en la descripción. Verificar el cuestionario IARC vigente en la consola: las preguntas y el resultado exacto los determina Google.

| Pregunta o grupo | Respuesta propuesta para el código actual |
|---|---|
| Categoría del cuestionario | Todas las demás aplicaciones; utilidad de calendario/productividad |
| Violencia, sangre, lesiones, miedo u horror | No / ninguno |
| Sexualidad, desnudos o contenido sugerente | No / ninguno |
| Lenguaje ofensivo o humor vulgar | No / ninguno |
| Drogas, alcohol o tabaco | No / ninguno |
| Apuestas, casino, apuestas simuladas, premios en dinero o activos negociables | No |
| Odio o discriminación | No |
| Contenido médico o consejos de salud | No; anotar una ausencia no ofrece información clínica |
| Comunicación entre usuarios, chat, citas o intercambio público de contenido | No; notas, adjuntos y el libro de cambios son locales, no hay comunidad ni feed |
| Contenido de usuarios accesible por otros dentro de la app | No |
| Ubicación precisa o compartir la ubicación | No; municipio elegido a mano, sin GPS |
| Acceso sin restricciones a Internet, navegador o buscador web | No |
| Publicidad | No |
| Compras digitales | **No.** La app es totalmente gratuita (decisión del 26-oct-2026): no hay compras digitales, ni suscripción, ni contenido bloqueado |
| Audiencia infantil / Families | No está diseñada específicamente para niños; público previsto: personas que trabajan a turnos. Selección de audiencia de Play propuesta: 18 años o más; verificar con el usuario. No confundir con la clasificación de contenido |
| Clasificación esperable en España | **PEGI 3**, provisional; aceptar solo el resultado emitido por IARC |

## Seguridad de los datos · Data safety

Borrador técnico basado en el código de la 0.8.4 (revisado el 4-nov-2026). Se responde por el comportamiento de la versión que se suba. **No hay cuentas, anuncios, analítica ni telemetría remota en el código actual, y la app no habla con ningún servidor** (sin `INTERNET` en release). Leer datos del calendario o guardar notas en el dispositivo no equivale a recopilarlos fuera del dispositivo.

> **Pregunta 30 resuelta y aplicada (4-nov-2026):** la copia de Google de Turnly solo se hace **cifrada de extremo a extremo** con el bloqueo de pantalla (sin bloqueo, Turnly no entra en ella; en Android 7–8 no hay copia del sistema). Play no cuenta como recopilados los datos cifrados de extremo a extremo que ni el desarrollador ni nadie más que el emisor y el receptor pueden leer, así que la respuesta es **«Ninguno»**. Se responde así **solo con un bundle que lleve este cambio** (el commit del 4-nov-2026 o posterior); la 0.6.17 de Play no lo lleva.

### Respuestas al formulario

| Campo | Respuesta propuesta | Alcance / verificar |
|---|---|---|
| ¿La app recopila o comparte alguno de los tipos de datos exigidos? | **No** | La copia de Google solo va cifrada de extremo a extremo (excepción de Play). Verificar de nuevo el AAB final y sus SDK. No hay RevenueCat ni compras: la app es totalmente gratuita (decisión del 26-oct-2026) |
| Datos recopilados | **Ninguno** | No seleccionar calendario, salud, información financiera ni notas solo por su tratamiento local |
| Datos compartidos | **Ninguno por la app de forma automática** | Todo lo demás lo inicia el usuario y es una transferencia iniciada por él (excepción de Play): exportar o compartir una copia `.turnly`, un `.ics` o un informe PDF/CSV con la hoja del sistema; exportar al calendario del móvil (puntual o con «Mantener al día»); y la copia automática diaria en la carpeta que el usuario elige (Drive, Dropbox, OneDrive o el móvil), que el sistema pasa a ese proveedor |
| ¿Todos los datos recopilados se cifran en tránsito? | **No aplica: no hay recopilación** | Si la consola omite la pregunta, no rellenarla. No marcar Sí como garantía de cifrado de archivos locales |
| Métodos de creación de cuentas | **La app no permite crear cuentas** | Una cuenta Apple/Google del sistema no es una cuenta de Turnly |
| URL para pedir eliminación de cuenta | **No aplica** | No inventar una web ni un flujo de cuentas |
| Solicitud de eliminación de datos | **No aplica: no se recopilan datos** (la copia cifrada de Google la borra el usuario desde su cuenta) | Verificar el nombre exacto del campo y su visibilidad en la consola |
| Finalidades, tratamiento efímero, obligatoriedad y vinculación por tipo de dato | **No aplica** | No hay tipos recopilados que detallar |
| Revisión de seguridad independiente / acreditaciones | **No** | No se ha aportado ninguna certificación |
| Política de privacidad · contenido y URL | `https://turnly.mainshai.com/privacy/` (30-oct-2026; antes GitHub Pages) | Cambiarla también en Play Console › Política de la app |

### Evidencias y límites de la declaración

| Comprobación | Evidencia del repositorio |
|---|---|
| Dependencias sin SDK de cuentas, anuncios, analítica o compras remotas | `app/pubspec.yaml` y `app/pubspec.lock`; la especificación ya no contempla RevenueCat ni compras (decisión del 26-oct-2026); las preguntas 7, 8 y 9 actualizan el alcance |
| Informes de errores sin envío | `app/lib/main.dart`, `app/lib/core/providers.dart` y `app/lib/core/diagnostics/crash_reporting.dart` usan `NoopCrashReporter`; que exista una interfaz de informes no significa que haya telemetría remota |
| Persistencia del cuadrante | Drift/SQLite local en `app/lib/core/database/` y repositorios de `app/lib/features/`; adjuntos de las notas en `<Application Support>/attachments/` |
| Copia local, en carpeta y prueba de recuperación | `app/lib/features/backup/` (`backup_providers.dart`, `folder_backup_providers.dart`, `folder_backup_task.dart`); réplica iCloud desactivada con `kICloudReplica = false` |
| Importación de LRHSoft local | `app/lib/features/import/data/lrhsoft_reader.dart`: copia temporal privada y SQLite `OpenMode.readOnly`; no sube el archivo |
| Calendario: lectura | `app/lib/features/import/` y las citas del móvil: solo leen; **no modifican** los calendarios de origen |
| Calendario: escritura | `app/lib/features/calendar_export/` (`calendar_exporter.dart`, `calendar_sync.dart`, `ics_export.dart`): exportación puntual, «Mantener al día» y `.ics`, a petición del usuario. Ausencias solo con su interruptor, apagado de serie. No declarar que todo el permiso es solo lectura |
| Informes PDF y CSV | `app/lib/features/reports/`: se generan en el móvil y se comparten con la hoja del sistema; una baja médica no sale con su nombre ni su nota salvo que el usuario lo elija |
| Festivos sin conexión | `app/lib/features/holidays/data/holiday_bundle_loader.dart` y `app/assets/holidays/`; país, comunidad y municipio se eligen localmente |
| Idiomas y textos | `app/lib/l10n/app_es.arb`, `app_ca.arb`, `app_gl.arb`, `app_eu.arb`, `app_en.arb` |

**Copia y exportación no son una nube propia.** El archivo `.turnly` puede contener turnos, notas, adjuntos, importes y ausencias; no está cifrado. La copia dentro de la app se pierde al desinstalar. Si el usuario guarda o comparte el archivo con otro servicio, elige una carpeta de Drive, Dropbox u OneDrive para la copia diaria, o exporta a un calendario sincronizado, ese destino puede enviarlo a su proveedor.

**Auto Backup de Android está habilitado desde Android 9, solo cifrado**: `AndroidManifest.xml` tiene `allowBackup="@bool/allow_system_backup"` (`false` en Android 7–8, `true` desde el 9); `app/android/app/src/main/res/xml/backup_rules.xml` (Android 9–11) y `data_extraction_rules.xml` (Android 12+, copia en la nube y paso de móvil a móvil) incluyen todo el dominio `file` (`<include domain="file" path="."/>`): la base de datos `cuadrante.sqlite`, `backups/` y **`attachments/` (fotos, dibujos y archivos de las notas)**; solo queda fuera `folder_backup/` (comprobado el 4-nov-2026). Desde el 4-nov-2026 la copia en la nube exige el cifrado de extremo a extremo (`disableIfNoEncryptionCapabilities="true"` en Android 12+, `requireFlags="clientSideEncryption"` en 9–11): sin bloqueo de pantalla, Turnly no entra en la copia de Google. El paso directo de móvil a móvil sigue igual. Prueba: `tool/qa/backup_android.sh`. No afirmar que todos los datos permanecen únicamente en el teléfono: salen, cifrados.

Antes de enviar: verificar el manifiesto fusionado de release, los SDK empaquetados y cualquier cambio de red o copia del sistema. Las respuestas anteriores no cubren una réplica iCloud activada ni el servidor de compartir por enlace.
