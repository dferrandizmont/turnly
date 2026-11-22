# Política de privacidad de Turnly

Última actualización: 20 de noviembre de 2026 · versión 2026-11-20

Turnly es una app de calendario de turnos para quien trabaja a turnos en España. Es una app independiente: no
está creada, revisada ni respaldada por ninguna empresa, administración ni sindicato.

Resumen: **no tienes cuenta, no hay servidor propio y tus turnos se quedan en tu móvil.** La app es totalmente
gratuita y de código abierto, y no envía datos ni informes de errores a nadie. Lo único que puede sacar tus datos del
móvil son las copias de seguridad de tu cuenta de Google o de Apple, la copia diaria en la carpeta que elijas (en
Android, si la activas) y los archivos o calendarios que tú decidas exportar, y eso lo controlas tú. Si nos escribes, Cloudflare reenvía tu mensaje a Gmail y se
guarda una copia en Proton. Enviamos las respuestas a través de Resend, sin seguimiento de aperturas ni de clics
(detalle en «Si nos escribes»).

## 1. Responsable del tratamiento

- Titular: Daniel Mont Ferrandiz
- Correo de contacto: turnly@mainshai.com

## 2. Qué datos se tratan

### Datos que se quedan en tu móvil (no los recibimos)
Tus calendarios, tipos de turno, rotaciones, cambios de día, notas, recordatorios, horas extra, ausencias (vacaciones,
moscosos, libre disposición, permisos y baja médica), festivos, comunidad y municipio, precio por hora y ajustes se
guardan solo en una base de datos local del dispositivo. Los festivos oficiales van dentro de la app y todo funciona
sin conexión. No hay sincronización ni copia en ningún servidor nuestro.

**Tu baja médica es un dato de salud.** Nosotros nunca la recibimos: no hay servidor, analítica ni calendario
compartido. Las alarmas no suenan en los días de ausencia y el recordatorio de una nota en un día de ausencia no
enseña el texto de la nota, para que nada de eso salga en la pantalla de bloqueo. Ten en cuenta, eso sí, que:

- los widgets de hoy, de la semana y del mes enseñan en la pantalla de inicio los turnos del día, también una
  ausencia con el código y el color que le hayas dado, y su descripción para el lector de pantalla los nombra. Los
  widgets de agenda y de dos semanas solo dicen «Ausencia». El texto de tus notas no va nunca al widget;
- las ausencias, baja incluida, van dentro de tus copias de seguridad (ver abajo), igual que el resto de tus turnos.

### Copias de seguridad
La app hace **copias automáticas en tu propio móvil** y te deja **exportar una copia a un archivo `.turnly`**
(Ajustes › Copia de seguridad; las copias antiguas `.cuadrante` también se pueden abrir) para guardarla donde quieras o pasarla a otro móvil, y restaurarla después. Ese
archivo contiene tus turnos, notas y ausencias, no lleva ningún identificador y no está cifrado; lo guardas y lo
controlas tú: la app solo lo entrega a la app que elijas en la hoja de compartir del sistema. Lo que hagas con él
después (subirlo a tu nube, mandarlo por WhatsApp o por correo...) queda fuera de la app. Al abrir un `.turnly` o un `.cuadrante`,
nada se restaura sin que lo confirmes.

**Copia diaria en una carpeta (solo Android).** Si la activas en Ajustes › Copia de seguridad › «Copia automática en
una carpeta», eliges una carpeta con el selector del sistema (una del móvil o de la tarjeta, o la de un servicio en la
nube si su app la ofrece en ese selector; no todos lo hacen). La app deja en ella una copia `.turnly` al elegirla y,
después, más o menos una vez al día si ha cambiado algo desde la última (el sistema decide el momento), además de otra
después de tus cambios si tienes la app abierta (como mucho cada 6 horas) y cuando tocas «Copiar ahora en la carpeta».
Es el mismo archivo que exportas a mano: lleva todo tu cuadrante, con las notas, sus adjuntos y las ausencias, baja
médica incluida, y no está cifrado. Viene desactivada: no se copia nada hasta que eliges la carpeta. Turnly solo tiene
permiso sobre esa carpeta, no ve ninguna cuenta y no envía nada por sí misma: si la carpeta es de un servicio en la
nube, es ese servicio el que sube la copia, según sus propias condiciones. La app guarda las 10 últimas copias y borra
las más antiguas; solo escribe, lee y borra sus propios archivos (`turnly-auto-…`); de los demás que haya en la
carpeta solo ve el nombre, el tamaño y la fecha, y nunca los abre, cambia ni borra. Si tocas «Dejar de copiar en esta
carpeta», la app deja de copiar y devuelve el permiso, pero las copias que ya están en la carpeta no se borran, igual
que al usar «Borrar todo y empezar de cero» o al desinstalar la app. Si eliges otra carpeta, las copias de la anterior
tampoco se borran. Si no las quieres, bórralas tú. Qué carpeta has elegido y su permiso se quedan en el móvil y no van
en la copia del sistema.

**Copia del sistema.** En Android 9 o superior, si tienes activada la copia de seguridad de Google y tu móvil tiene
bloqueo de pantalla, el sistema sube periódicamente la base de datos, las copias y los adjuntos de la app a tu cuenta
de Google, cifrados de extremo a extremo con ese bloqueo (ni Google ni nosotros podemos leerlos). Sin bloqueo de
pantalla, Turnly no entra en esa copia. Al estrenar móvil, el sistema también puede pasar los datos directamente del
móvil viejo al nuevo. En Android 7 y 8, Turnly no usa la copia del sistema. En iPhone, la base de datos
entra en la copia del dispositivo (iCloud o la del ordenador). Esas copias las gestionas tú con tu cuenta de Google o
de Apple y puedes desactivarlas en los ajustes del sistema; la app no envía nada por su cuenta y no hace ninguna
copia propia en iCloud.

### Calendario del móvil
Solo si tú lo pides, y solo en ese momento:

- **Importar** lee los eventos del calendario que elijas (o de un archivo `.ics`, CSV o una copia de otra app de
  turnos) para proponerte turnos. Se leen y se agrupan en tu móvil, y solo se guarda lo que aceptes.
- **Exportar** escribe tus turnos (nombre, código y horario; nunca notas ni cantidades) en el calendario del móvil
  que elijas. **Si ese calendario se sincroniza con una cuenta** (Google, iCloud, Exchange...), tus turnos se verán
  también en esa cuenta: lo sube el propio sistema, fuera del control de la app. La pantalla te lo avisa. Las
  ausencias y los días libres no se exportan salvo que actives sus interruptores.

El permiso de calendario se pide cuando empiezas a importar o a exportar, nunca al arrancar, y la app no lee ni
escribe el calendario en segundo plano.

### Permisos
Además del calendario, la app pide permiso de **notificaciones** y de **alarmas y recordatorios** cuando activas las
alarmas de turno o el recordatorio de una nota, para que suenen a su hora y el widget cambie de día a medianoche. Si
no lo concedes, las alarmas pueden sonar con retraso. No pide ubicación, contactos, fotos, cámara, micrófono ni acceso
general al almacenamiento, y la versión publicada de Android no tiene permiso de red.

### Comunicaciones
La app no transmite turnos, identificadores ni informes de errores. No utiliza compras, anuncios ni analítica. Los
errores se manejan solo en el dispositivo.

**Valoraciones en la tienda.** De vez en cuando, después de aplicar una rotación o de pintar días, Turnly puede pedirle
a la tienda (Google Play o la App Store) que te muestre su ventana para valorar la app; la tienda decide si la
enseña. También puedes abrir la página de Turnly en la tienda desde Ajustes › Ayuda › «Valorar Turnly». Para eso la
app usa la biblioteca de valoraciones de Google Play en Android y la función del sistema en iPhone y iPad. Turnly solo
le indica a la tienda de qué app se trata: no le pasa tus turnos ni ningún otro dato tuyo, y no sabe si has valorado
ni qué has escrito. Tu valoración y tu reseña las escribes en la ventana de la tienda y las recibe Google o Apple, con
tu cuenta de la tienda y según sus condiciones. Para decidir cuándo preguntar, la app guarda en el móvil qué día la
abriste por primera vez, cuántos días la has abierto y cuántas veces, cuándo y con qué versión ha pedido la
valoración. Esos contadores no van en el archivo `.turnly` y Turnly no los envía a nadie; están en la base de datos de
la app, así que solo salen del móvil dentro de la copia del sistema, si la tienes activada (ver «Copia del sistema»).

Si tocas «Política de privacidad» en Ajustes › Ayuda, se abre esta página en tu navegador externo. Es el navegador
el que se conecta a la web; Turnly no le envía tus turnos, notas ni ausencias.

### Datos que NO se tratan
- La app no pide ni guarda nombre, correo, teléfono, DNI, fecha de nacimiento ni datos de tu empresa.
- En la app y en la web no hay analítica, ni anuncios, ni publicidad personalizada, ni rastreo entre apps. El correo
  de soporte tiene su propio apartado («Si nos escribes»).
- No accedemos a tu ubicación, contactos, fotos, cámara ni micrófono.
- No recibimos tus turnos, tus notas, tus ausencias ni tus horas.

### Si nos escribes
«Ayuda y contacto» (Ajustes) te enseña la dirección de soporte para que la copies y nos escribas desde tu propia app
de correo, con la versión de la app si quieres adjuntarla. La app no abre el correo ni envía nada por sí misma. No
nos mandes copias `.turnly` o `.cuadrante` ni capturas con turnos, notas o ausencias reales: para un fallo nos basta
con datos inventados.

Si escribes a turnly@mainshai.com (o a dev@mainshai.com, la dirección de las primeras versiones), usamos tu dirección
de correo, tu nombre si lo pones y lo que nos cuentes para contestarte y resolver lo que nos preguntas. Si ejerces un
derecho de protección de datos, tratamos tu solicitud para cumplir las obligaciones que nos impone el RGPD (art.
6.1.c). Si necesitamos conservar una conversación por una reclamación, lo hacemos por nuestro interés legítimo en
formularla, ejercerla o defendernos frente a ella (art. 6.1.f), durante el tiempo necesario para ello. Por el camino
intervienen estos proveedores:

- **Cloudflare** (Cloudflare, Inc., Estados Unidos) recibe el mensaje en nuestro dominio y lo reenvía al momento. No
  guarda el mensaje, pero sí un registro técnico del reenvío (remitente, destinatario, asunto, fecha y resultado). Lo
  conserva durante el plazo que fija su servicio, que no hemos podido confirmar, igual que las opciones para borrarlo;
  si nos pides la supresión, trasladaremos también la solicitud a Cloudflare y te informaremos del resultado. Cloudflare trata el correo también
  en Estados Unidos.
- **Google** (Gmail; Google Ireland Limited) es el buzón donde leemos tu mensaje, te respondemos y guardamos la
  conversación. Google puede tratar estos datos también en Estados Unidos.
- **Proton** (Proton AG, Suiza) guarda una copia de los mensajes que recibimos, como respaldo. Desde ahí no
  respondemos.
- **Resend** (Plus Five Five, Inc., Estados Unidos) envía nuestras respuestas, que salen desde turnly@mainshai.com, por
  lo que trata su contenido. Las envía desde sus servidores de Irlanda, pero guarda los datos en Estados Unidos: una copia de cada respuesta (que
  puede incluir tu mensaje, si va citado debajo) y su registro de envío (destinatario, asunto, fecha y si se entregó).
  Según Resend, conserva cada respuesta y su registro de envío durante 30 días desde el envío, y sus copias de
  seguridad se conservan durante siete días. Tenemos desactivado el seguimiento de aperturas y de clics: nuestras
  respuestas no llevan ninguna imagen de seguimiento y sus enlaces no se cambian. Resend usa sus propios subencargados
  (por ejemplo, Amazon Web Services para el envío), en Estados Unidos; la lista está en
  https://resend.com/legal/subprocessors.

**Brevo, hasta el 20 de noviembre de 2026.** Hasta esa fecha, esta política decía que las respuestas salían por Brevo
(Sendinblue SAS, que opera como Brevo, Francia), que añade a los correos una imagen invisible (un píxel) que registra si
se abren y cambia los enlaces por otros suyos que registran si se pulsan. Antes del cambio a Resend, desde
turnly@mainshai.com solo se enviaron por Brevo pruebas del titular, ninguna respuesta a quien nos escribiera. Brevo
conserva el registro de esas pruebas y lo borra automáticamente doce meses después de cada envío (el borrado puede
tardar hasta un día más). Vamos a pedir a Brevo que borre antes ese historial y a cerrar la cuenta.

Guardamos la conversación en Gmail y la copia en Proton como máximo un año desde el último mensaje de la
conversación, salvo que necesitemos conservarlas más tiempo para atender una reclamación. Hacemos una limpieza cada
tres meses y en cada una borramos lo que cumpliría el año antes de la siguiente. Según Resend, conserva cada respuesta
y su registro de envío durante 30 días desde el envío, y sus copias de seguridad se conservan durante siete días. Si
nos pides que borremos tus mensajes antes y procede la supresión, borramos los mensajes de Gmail y Proton y pedimos a
Resend que elimine las respuestas y los registros de envío que aún conserve (solo se puede pidiéndoselo a su servicio
de ayuda). Si debemos conservar algún dato, te explicaremos cuál y por qué.

## 3. Para qué y con qué base jurídica

| Tratamiento | Finalidad | Base jurídica (RGPD) |
|---|---|---|
| Turnos, notas, ausencias y ajustes en tu móvil | Que lleves tu cuadrante, tus horas y tus alarmas | No los recibimos: se quedan en tu dispositivo, bajo tu control |
| Copias de seguridad y exportaciones | Que no pierdas tus datos y puedas cambiar de móvil | Las haces tú; los servicios que uses (Google, Apple, tu nube) tienen sus propias condiciones |
| Correos de soporte | Responder a tu consulta y guardar la conversación durante el plazo de «Cuánto tiempo se conservan» | Tu solicitud y nuestro interés legítimo en atenderla (art. 6.1.f) |
| Solicitudes de derechos de protección de datos | Atender y documentar tu solicitud | Cumplir las obligaciones que nos impone el RGPD (art. 6.1.c) |
| Conservación de una conversación por una reclamación | Formular, ejercer o defendernos frente a una reclamación | Nuestro interés legítimo (art. 6.1.f), durante el tiempo necesario |

No tomamos decisiones automatizadas ni elaboramos perfiles sobre ti.

## 4. Quién recibe los datos
La app no transmite datos a terceros. Si valoras la app en la tienda, tu valoración y tu reseña las recibe Google o Apple
directamente, no nosotros. Si exportas a un calendario sincronizado, eliges para la copia diaria una carpeta de un servicio en la
nube o tienes activada la copia del sistema, quien recibe esos datos es el proveedor de tu cuenta (Google, Apple u
otro), en tu nombre y según sus condiciones.

Si nos escribes, el correo de soporte pasa por estos proveedores, cada uno en el paso que indica la tabla (detalle en
«Si nos escribes»):

| Proveedor | Para qué | Dónde |
|---|---|---|
| Cloudflare, Inc. | Recibir y reenviar el correo de soporte; registro técnico del reenvío | EE. UU. |
| Google Ireland Limited (Gmail) | Buzón del correo de soporte | Irlanda; Google LLC puede tratar datos en EE. UU. |
| Proton AG | Copia de respaldo del correo recibido | Suiza |
| Plus Five Five, Inc. (Resend) | Enviar las respuestas; copia de cada respuesta y su registro de envío durante 30 días desde el envío (sus copias de seguridad se conservan siete días); sin seguimiento de aperturas ni de clics | EE. UU. (el envío sale de Irlanda) |
| Sendinblue SAS (Brevo), RCS París 498 019 298 | Hasta el 20 de noviembre de 2026, servicio de envío previsto; solo envió pruebas del titular, cuyo registro borra automáticamente doce meses después de cada envío, aunque el borrado puede tardar hasta un día más | UE (Francia) |

Usamos una cuenta de Gmail normal, sin contrato de encargo con Google: Google trata esos correos según sus propias
condiciones. Resend trata las respuestas como encargado del tratamiento, con el acuerdo de tratamiento de datos (art.
28 del RGPD) que se aplica a todas sus cuentas (https://resend.com/legal/dpa).

## 5. Transferencias internacionales
La app no realiza transferencias de datos. Los servicios externos que decidas utilizar (tu correo, nube, calendario
sincronizado, destino de una exportación o la tienda en la que valores la app) se rigen por sus propias condiciones.

En el correo de soporte, Cloudflare y Google pueden tratar datos en Estados Unidos. Cloudflare, Inc. y Google LLC
están adheridas al Marco de Privacidad de Datos UE-EE. UU. (decisión de adecuación de la Comisión Europea de 10 de
julio de 2023); el acuerdo de tratamiento de datos de Cloudflare incluye además cláusulas contractuales tipo. Proton
está en Suiza, país con decisión de adecuación de la Comisión Europea. Resend (Plus Five Five, Inc.) guarda en Estados
Unidos las respuestas y su registro, aunque el envío salga de Irlanda; esa transferencia se ampara en la adhesión de
Resend al Marco de Privacidad de Datos UE-EE. UU. y en las cláusulas contractuales tipo de la Comisión Europea (módulo
2) que incorpora su acuerdo de tratamiento de datos (https://resend.com/legal/dpa); también puedes pedirnos
información en el correo de contacto. Brevo, el servicio previsto hasta el 20 de noviembre de 2026, es una empresa
francesa y, según su documentación, aloja los datos en la Unión Europea.

## 6. Cuánto tiempo se conservan

- **Datos en tu móvil:** hasta que desinstales la app o borres sus datos desde los ajustes del sistema (y, en su
  caso, de las copias de seguridad de tu cuenta, de los archivos que hayas exportado y de las copias diarias de la
  carpeta que elegiste, que siguen en ella hasta que las borres tú).
- **Correos de soporte:** la conversación en Gmail y la copia en Proton, como máximo un año desde el último mensaje de
  la conversación, con una limpieza cada tres meses, salvo que necesitemos conservarlas más tiempo para atender una
  reclamación. Según Resend, conserva cada respuesta y su registro de envío durante 30 días desde el envío, y sus
  copias de seguridad se conservan durante siete días. Puedes pedir la supresión antes. Si procede, borramos los
  mensajes de Gmail y Proton y pedimos a Resend que elimine las respuestas y los registros de envío que aún conserve.
  Si debemos conservar algún dato, te explicaremos cuál y por qué (detalle en «Si nos escribes»).
  Cloudflare conserva su registro técnico del reenvío durante el plazo que fija su servicio, que no hemos podido
  confirmar; si nos pides la supresión, le trasladaremos también la solicitud y te informaremos del resultado. Sobre lo
  que queda en Brevo, ver «Si nos escribes».

## 7. Tus derechos

Puedes ejercer tus derechos de **acceso, rectificación, supresión, oposición, limitación del tratamiento y
portabilidad** escribiendo a turnly@mainshai.com. Te responderemos en el plazo de un mes.

No recibimos los datos guardados en tu móvil, así que no podemos verlos ni borrarlos por ti. Puedes borrarlos
desinstalando la app o borrando sus datos desde los ajustes del sistema, y llevártelos con «Exportar copia».

Si crees que no hemos tratado bien tus datos, puedes reclamar ante la Agencia Española de Protección de Datos:
https://www.aepd.es

## 8. Menores

La app está pensada para personas que trabajan. No pide la edad ni recoge datos personales de nadie, tampoco de
menores: los turnos y los ajustes se mantienen en el dispositivo.

## 9. Seguridad
No hay servidor ni transmisión de datos desde la app. Las copias automáticas se guardan en la carpeta privada de la
app. La copia diaria en una carpeta, si la activas, queda fuera de la app y sin cifrar: puede leerla quien tenga
acceso a esa carpeta (otras apps con permiso sobre ella, el servicio en la nube al que pertenezca o quien use tu
cuenta). Tú controlas los archivos exportados y las copias de tu cuenta de Google o de Apple; la copia de Google de
Turnly solo se hace cifrada con tu bloqueo de pantalla. El código es público y cualquiera puede comprobar lo que hace.

## 10. Cambios en esta política

Si cambia lo que hacemos con los datos, en la app o en el correo de soporte, actualizaremos esta página y la fecha de arriba. Si el cambio es
importante (por ejemplo, si algún día se añadiera una copia en iCloud o cualquier función que envíe datos, que solo
se activaría con tu consentimiento), te lo indicaremos también dentro de la app.

## 11. Contacto

turnly@mainshai.com
