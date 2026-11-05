# Privacidad y cumplimiento

No es asesoramiento jurídico. Resume qué hace la app con los datos, comprobado contra el código el 26-oct-2026 y
repasado para la 0.8.4 el 4-nov-2026 (exportaciones, adjuntos, copia en carpeta, «No molestar» y reglas de copia);
revisar con un profesional antes del lanzamiento. La política para el usuario está en
[`docs/legal/politica-privacidad.md`](legal/politica-privacidad.md) y tiene que decir lo mismo que este documento.
English version: [`privacy.en.md`](privacy.en.md).

## Flujo de datos (decisión del dueño, 26-oct-2026)
- **La app no habla con ningún servidor.** No hay cuentas, servidor propio, analítica, telemetría, anuncios,
  compras ni identificadores de instalación. El manifiesto de release de Android no declara `INTERNET` (solo los
  de `debug` y `profile`, para Flutter); el código Dart no tiene cliente HTTP. Los festivos van incluidos en la app
  (`app/assets/holidays/`); la descarga remota descrita en `docs/festivos.md` no existe.
- **Informes de errores:** el único `CrashReporter` instalado es `NoopCrashReporter` (`app/lib/main.dart`), envuelto
  en `RedactingCrashReporter`: no sale nada del móvil. Si algún día se añadiera un backend, la interfaz
  (`app/lib/core/diagnostics/crash_reporting.dart`) solo deja pasar el tipo del error y la traza, nunca el mensaje.
- **App 100 % gratuita y de código abierto**: código MIT, contenido propio CC BY-SA 4.0
  (`LICENSE`, `LICENSE-CONTENT.md`). La configuración **ya no tiene** campos de RevenueCat (`rcApiKey*` se retiraron de
  `app/lib/core/config.dart`) y no hay SDK de compras en `app/pubspec.yaml`.
- Todo funciona sin conexión y sin pedir nombre, correo, teléfono ni edad.

## Qué se guarda en el móvil
Base de datos Drift `cuadrante.sqlite` en Application Support (`docs/datos.md`): calendarios, tipos de turno,
rotaciones, excepciones por día, **notas**, tareas del día, recordatorios, horas extra, **ausencias** (vacaciones,
moscosos, libre disposición, permisos y **baja médica**, categoría `absence`) y sus saldos por año, el libro de
cambios (nombres de compañeros que escribe el usuario), festivos propios, país, comunidad y municipio, precio por hora,
pluses, importes extra, retención y ajustes. Los **adjuntos** de las notas (fotos, dibujos y archivos) van como
archivos en `<Application Support>/attachments/`. Sin identificadores de dispositivo ni de usuario.

**Datos de salud.** La baja médica es un tipo de ausencia como los demás y vive en la misma base de datos. No hay
feed compartido ni analítica; sí se incluye en las copias descritas más abajo, según la decisión 13 resuelta por
el usuario el 26-oct-2026. Dónde aparece y dónde no, según el código actual:

| Dónde | Qué pasa con las ausencias (baja incluida) |
|---|---|
| Alarmas | Nunca suenan (`alarm_planner.dart`; `docs/alarmas.md`): un aviso de «baja» en la pantalla de bloqueo sería un dato de salud a la vista. El recordatorio de una nota en un día de ausencia lleva el cuerpo neutro «Tienes un recordatorio para hoy». |
| Widgets de hoy, semana y mes | Enseñan los turnos del día como el calendario, ausencias incluidas (código y color del tipo), y sus descripciones de accesibilidad nombran todos los turnos del día (`docs/widget-contrato.md`, extensión `descriptions`; `widget_snapshot_builder.dart`). Solo en el móvil, pero a la vista de quien tenga el teléfono en la mano. |
| Widgets de agenda y dos semanas | Anonimizadas: «Ausencia», sin código, nombre, horas ni marca de nota. |
| Widget de cuatro semanas | Como el calendario, pero un día de salud nunca enseña el texto de su nota. |
| Notas | A los widgets de hoy, semana, mes, agenda y dos semanas solo viaja si el día tiene nota, nunca el texto; el de cuatro semanas enseña la primera línea, salvo en un día de salud. |
| Copia `.turnly` (exportada o automática en el móvil) | Van dentro (apartado siguiente). |
| Copia automática en una carpeta (Android) | Van dentro: la app lo avisa al activarla («ausencias y bajas incluidas»). |
| Copia del sistema de Android | Van dentro, con la base de datos y los adjuntos, pero solo cifradas de extremo a extremo o de un móvil a otro (apartado «Copias del sistema»). |
| Exportar al calendario del móvil o a `.ics` (puntual o con «Mantener al día») | No salen salvo que el usuario active «Incluir ausencias» (apagado de serie). |
| Informes PDF y CSV | De serie, solo como «Ausencia»; una baja sale con su nombre y su nota solo si el usuario elige «Con su nombre y su nota». |

La decisión 13 de `docs/preguntas.md` **quedó resuelta por el usuario el 26-oct-2026: dejarlo como está**. Las
ausencias de salud siguen en la misma base de datos y viajan en las copias `.turnly` y en las del sistema,
como explica la política. No se crea un almacén aparte. Activar la réplica en iCloud es otra decisión, pendiente
para el Mac; `kICloudReplica` sigue en `false`. Qué se declara por eso en la Seguridad de los datos de Google Play
es la **pregunta 30**, resuelta el 4-nov-2026: la copia de Google de Turnly solo se hace cifrada de extremo a extremo.

## Permisos
Todos se piden cuando el usuario toca la función, nunca al arrancar.

| Permiso | Para qué | Dónde |
|---|---|---|
| Notificaciones (`POST_NOTIFICATIONS`, Android 13+; permiso de notificaciones en iOS) | Alarmas de turno y recordatorios de notas. Se pide al activarlas o al probar una alarma (`alarm_providers.dart`, `ensureNotificationPermission`). | `AndroidManifest.xml` |
| Alarmas exactas (`SCHEDULE_EXACT_ALARM`) | Que la alarma suene a su hora, que el silencio de los turnos empiece y acabe a su hora y que el widget cambie de día a medianoche. Sin él, alarmas inexactas. No se usa `USE_EXACT_ALARM`. | `AndroidManifest.xml` |
| Acceso a «No molestar» (`ACCESS_NOTIFICATION_POLICY`, desde la 0.8.0) | «Silenciar el móvil en mis turnos»: pone el móvil en No molestar durante los turnos que el usuario elige y lo quita al acabar. Lo concede el usuario en los ajustes del sistema, solo al encender la opción. No toca la wifi ni el Bluetooth. | `AndroidManifest.xml` |
| `RECEIVE_BOOT_COMPLETED`, `VIBRATE` | Reprogramar las alarmas y el silencio tras reiniciar o actualizar; vibrar. | `AndroidManifest.xml` |
| `HIDE_OVERLAY_WINDOWS` (normal, sin diálogo) | Que la vista previa de restaurar no la tape otra app (tapjacking). | `AndroidManifest.xml`, `MainActivity` |
| Calendario (`READ_CALENDAR`, `WRITE_CALENDAR`; `NSCalendars*UsageDescription` en iOS) | Leer eventos al importar desde el calendario del móvil y para «Citas del móvil» (solo lectura, de los calendarios que el usuario elige); escribir al exportar una vez o con «Mantener al día», que actualiza sus propios eventos al cambiar el cuadrante y al abrir la app. Nunca en segundo plano. | `AndroidManifest.xml`, `app/ios/Runner/Info.plist`, `docs/importar.md` |

En total, 8 permisos en el manifiesto de release de Android (`FOREGROUND_SERVICE*`, que añade `workmanager`, se
quitan con `tools:node="remove"`). Sin permisos de ubicación, contactos, fotos, cámara, micrófono, almacenamiento
general ni red. Los archivos se eligen con el selector del sistema (`file_selector`), las fotos de los adjuntos con la
cámara o la galería del sistema, la carpeta de la copia diaria con el selector de carpetas del sistema, y todo se
comparte con la hoja del sistema (`share_plus`).

## Copias de seguridad (`docs/copia-de-seguridad.md`)
- **`.turnly`** (antes `.cuadrante`, que se sigue abriendo): JSON canónico comprimido con gzip y con suma de control;
  si hay adjuntos, un ZIP con ese JSON y los archivos. **No está cifrado**. Contiene todo lo que el usuario creó
  (ausencias, notas y adjuntos incluidos), sin cuentas ni identificadores. No entran los ajustes de primer uso ni el
  idioma.
- **Copias automáticas locales:** tras cada ráfaga de cambios, en `<Application Support>/backups`: las 7 más nuevas y
  la última de cada día de los últimos 30; copias previas a restaurar y a migrar, las 3 últimas de cada una. Todo en
  el móvil; nada se envía.
- **Exportar y restaurar:** el usuario guarda o comparte el archivo con la hoja del sistema (`_shareWithSystem`,
  `backup_providers.dart`) y lo abre desde Archivos, Drive o WhatsApp; nada se restaura sin su confirmación en la
  vista previa. Dónde acabe ese archivo es decisión suya.
- **Copia automática en una carpeta (Android, desde la 0.7.0):** si el usuario la activa, la app deja un `.turnly` al
  día en la carpeta que elige con el selector del sistema (Drive, Dropbox, OneDrive o el propio móvil) y guarda las 10
  últimas (`folder_backup_providers.dart`, `folder_backup_task.dart`). Si la carpeta es de un servicio en la nube, **su
  proveedor la sube**, fuera del control de la app; la pantalla avisa de que la copia lleva todo el cuadrante,
  ausencias y bajas incluidas. Es una transferencia iniciada por el usuario.
- **Réplica en iCloud: apagada.** `kICloudReplica = false` en `backup_providers.dart`; el canal Swift no existe y,
  aun existiendo, haría falta el interruptor de Ajustes. Activarla requiere otra decisión en el Mac, según la
  respuesta del usuario del 26-oct-2026 a la decisión 13.

## Copias del sistema
- **Android (Auto Backup):** `allowBackup="@bool/allow_system_backup"` (apagado en Android 7–8, encendido desde el 9)
  con reglas explícitas (`res/xml/backup_rules.xml`,
  `data_extraction_rules.xml`, comprobadas el 4-nov-2026): `<include domain="file" path="."/>` con
  `<exclude domain="file" path="folder_backup/"/>`. Entra todo `files/`: la base de datos `cuadrante.sqlite`,
  `backups/` y **`attachments/`** (fotos, dibujos y archivos de las notas); queda fuera `folder_backup/` (el registro
  de la copia en carpeta, porque el permiso de la carpeta no viaja). No entran las preferencias compartidas, la caché ni
  `no_backup/`. **Desde el 4-nov-2026 (pregunta 30)** la copia en la nube solo se hace **cifrada de extremo a
  extremo** con el bloqueo de pantalla (`disableIfNoEncryptionCapabilities="true"` en Android 12+,
  `requireFlags="clientSideEncryption"` en Android 9–11): sin bloqueo de pantalla, Turnly no entra en la copia de
  Google. El paso directo de un móvil a otro (`<device-transfer>`, `deviceToDeviceTransfer`) sigue igual. En Android
  7–8 no hay copia del sistema. Nosotros no lo vemos y Google tampoco puede leerlo, pero los datos **sí salen del
  móvil** por esa vía, cifrados, ausencias y adjuntos incluidos. No decir «nunca salen del móvil». Prueba:
  `tool/qa/backup_android.sh`.
- **iOS:** la base de datos entra en la copia del iPhone (iCloud o del ordenador), que gestiona el usuario con su
  Apple ID.

## Importar y exportar (`docs/importar.md`)
- **Importar** desde el calendario del móvil, desde archivos `.ics` o CSV, o desde una copia de LRHSoft
  (`.Shifter`): se lee en el móvil, se agrupa en el móvil y solo se guarda lo que el usuario acepta. Los mensajes de
  error nunca llevan texto del archivo. Los archivos de otra app se tratan como entrada hostil (solo lectura, límites
  de tamaño, copia temporal que se borra).
- **Exportar al calendario del móvil**, una vez o con **«Mantener al día»** (desde la 0.7.0: actualiza sus propios
  eventos, de una semana atrás a tres meses adelante, cada vez que cambia el cuadrante y al abrir la app; nunca en
  segundo plano): escribe título («Mañana · M»), horario y una etiqueta propia; nunca notas ni cantidades. Si ese
  calendario se sincroniza con una cuenta (Google, iCloud, Exchange), **la sube el sistema a esa cuenta**, fuera del
  control de la app; la pantalla lo avisa. Ausencias y días libres solo con sus interruptores, apagados de serie.
- **Exportar a un archivo `.ics`** (0.7.0): los mismos eventos, en un archivo que el usuario guarda o comparte con la
  hoja del sistema; las ausencias, solo con su interruptor.
- **Informes en PDF y CSV** (0.7.0/0.8.0) de un mes o de unas fechas: se generan en el móvil y se comparten con la hoja
  del sistema. Pueden llevar notas e importes si el usuario los incluye; las ausencias salen de serie solo como
  «Ausencia».
- **Citas del móvil** (0.8.0): solo lee los calendarios del móvil que el usuario elige y las enseña junto a sus turnos;
  no escribe ni cambia nada en ellos.
- Todas las salidas de datos las inicia el usuario: la copia `.turnly` (a mano o en la carpeta diaria), el calendario
  del móvil, el `.ics` y los informes. Compartir por enlace está construido pero **apagado** hasta que exista el
  servidor (P1); si se activa, este documento se revisa antes.

## Widgets (`docs/widget-contrato.md`)
La app escribe un JSON con los próximos 60 días (y los auxiliares de agenda y dos semanas) en el almacén compartido
con los widgets: `UserDefaults` del App Group `group.es.cuadrante.app` en iOS y las preferencias de `home_widget` en
Android, que no entran en la copia del sistema. Solo lo leen los widgets de esta app.

## Soporte y enlaces
«Ayuda y contacto» (Ajustes) enseña la dirección de soporte para **copiarla**; la app no abre el correo.
La dirección es **turnly@mainshai.com**, definida en `kSupportEmail`
(`app/lib/core/config.dart`); el build puede sustituirla con `--dart-define=SUPPORT_EMAIL=...`.
«Licencias de código abierto» abre la página de licencias de Flutter, sin conexión.
«Política de privacidad» (Ajustes › Ayuda) abre la web en el **navegador externo**, solo al tocar la fila, mediante
el plugin oficial `url_launcher`. No envía datos del cuadrante ni añade permiso `INTERNET` a la app: el navegador
hace la conexión. `PRIVACY_URL` apunta por defecto a `https://turnly.mainshai.com/privacy/`;
en inglés se usa `PRIVACY_URL_EN` (`https://turnly.mainshai.com/en/privacy/`). Las dos URL pueden
cambiarse con `--dart-define`. La web española es la referencia para los demás idiomas.

## Declaraciones en tiendas
- App Store, App Privacy: **no se recogen datos**, sin seguimiento ni compras dentro de la app
  (`docs/tienda/app-store.md`).
- Google Play, Seguridad de los datos: la app no comparte nada de forma automática y no tiene anuncios, analítica ni
  compras. Leer el calendario o guardar notas en el móvil no es recopilar. La copia de Google solo lleva los datos
  cifrados de extremo a extremo (pregunta 30, 4-nov-2026), que Play no cuenta como recopilados: **no se recogen datos**
  (`docs/tienda/google-play.md`, «Seguridad de los datos»). Declarar los permisos de alarmas
  exactas, «No molestar» y calendario con su justificación (misma sección, «Permisos de Android»).
- No hay cuentas que borrar; los datos se eliminan desinstalando la app o borrando sus datos desde el sistema (y, si
  procede, de las copias de Google o iCloud del usuario).
- Revisar los formularios con el AAB/IPA definitivo y publicar una URL de política coherente con estos hechos.

## Pendiente antes del lanzamiento
- [x] Decisión 13 resuelta (usuario, 26-oct-2026): se mantiene el comportamiento actual, con las ausencias de salud
      en la misma base de datos y en las copias, como explica la política.
- [ ] Comprobar la pantalla «Ayuda y contacto» en el build de release; `kSupportEmail` ya contiene `turnly@mainshai.com`.
- [ ] Publicar la política de privacidad (URL), enlazarla desde las dos tiendas y comprobar las dos URL desde la
      fila de Ajustes ya implementada (`docs/legal/LEEME.md`).
- [x] Pregunta 30 resuelta y aplicada (4-nov-2026): copia de Google solo cifrada; la política para el usuario
      (`docs/legal/politica-privacidad.md` y `.en.md`) ya lo cuenta. Falta desplegar la web con la política nueva.
- [x] Llevar los cambios del 4-nov-2026 a `privacy.en.md` (hecho el 4-nov-2026).
- [ ] Rellenar App Privacy (Apple) y Seguridad de los datos (Play) con el binario final.
- [ ] Mantener `kICloudReplica = false` hasta la decisión independiente sobre activar la réplica en el Mac.
- [ ] Revisar este documento cada vez que cambie el flujo de datos (permisos, copias, exportaciones, soporte).
