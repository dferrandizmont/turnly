# Documentos legales

No son asesoramiento jurídico; conviene que los revise un profesional antes del lanzamiento. English version:
[LEEME.en.md](LEEME.en.md).

| Fichero | Qué es | Estado |
|---|---|---|
| `politica-privacidad.md` | Política de privacidad para publicar (RGPD y LOPDGDD), en tuteo. Refleja [`docs/privacy.md`](../privacy.md), que es la fuente de verdad técnica. | Sin marcadores: titular, correo y fecha ya rellenos. Las notas internas están al final de este documento. |
| `politica-privacidad.en.md` | Traducción de cortesía al inglés. Manda la española. | Mantenerla al día con la española. |
| `../privacy.md` y `../privacy.en.md` | Inventario técnico de datos, permisos, copias y exportaciones, comprobado contra el código. | Revisar cada vez que cambie el flujo de datos. |
| `../../SECURITY.md` y `SECURITY.en.md` | Cómo avisar de una vulnerabilidad sin mandar datos reales. | — |
| `../../LICENSE` y `../../LICENSE-CONTENT.md` (`.en.md`) | MIT para el código; CC BY-SA 4.0 para el contenido propio; festivos oficiales, Mochila y terceros aparte. | — |

Convención: el texto en español es el que vale; cada documento tiene su versión inglesa en `*.en.md` al lado.

## Cómo se mantienen en sincronía con la web
La política se publica en la web de la app, `https://turnly.mainshai.com/privacy/` (en inglés, `/en/privacy/`; en
catalán, gallego y euskera se muestra la española con un aviso), generada **desde este markdown** sin resumirla:

1. La fuente es `docs/legal/politica-privacidad.md` y su traducción `politica-privacidad.en.md`. El generador común de
   las webs (`mainshai-web`, `sitegen`) las lee según `web/site.toml` y comprueba que el texto publicado coincide con
   el markdown y que `privacy_date` de `web/content/<idioma>.json` es la fecha de «Última actualización».
2. Esa misma URL va en las fichas de las dos tiendas y en la fila «Política de privacidad» de Ajustes › Ayuda, ya
   implementada: abre el navegador externo solo al tocarla. El build usa `PRIVACY_URL` para la política española y
   `PRIVACY_URL_EN` para la inglesa (las URL de arriba por defecto; se pueden sustituir con `--dart-define`).
3. **Si cambia el flujo de datos**, se actualizan a la vez y en el mismo commit: `docs/privacy.md`, esta política (y
   las dos versiones inglesas), la fecha de «Última actualización», `privacy_date` en `web/content/*.json` y las
   declaraciones de las tiendas (`docs/tienda/google-play.md`, «Seguridad de los datos»; `docs/tienda/app-store.md`,
   «App Privacy»). Después se regenera y se despliega la web (skill `web-app`).

Hasta el 30-oct-2026 se publicaba en GitHub Pages (`web/legal/`, rama `gh-pages`); esas páginas se retiran con una
redirección a la web nueva.

## Lista para publicar
1. Revisar las notas para el titular de abajo y, si procede, cambiar el plazo de conservación de los correos o la fecha.
2. Comprobar el correo de soporte en el build: `kSupportEmail` (`app/lib/core/config.dart`) ya contiene
   `turnly@mainshai.com`; `SUPPORT_EMAIL` permite sustituirlo.
3. Generar, comprobar y desplegar la web de la app.
4. Poner la URL en las fichas de las tiendas y comprobar que coincide con «Seguridad de los datos» (Play) y
   «Privacidad de la app» (Apple): no se recopilan datos.

## Notas para el titular
Estaban al final de la política y salieron de ella el 30-oct-2026, al publicarla en la web nueva. Texto redactado el
26-oct-2026 contra el código de esa fecha (`docs/privacy.md` es la fuente de verdad): revísalo con una persona antes
del lanzamiento.

Decisiones ya tomadas en el texto, por si quieres cambiarlas: titular Daniel Mont Ferrandiz; correo
`turnly@mainshai.com` (el de la app desde el 30-oct-2026; antes `dev@mainshai.com`). Desde el 16-nov-2026
Cloudflare Email Routing lo reenvía a un buzón de Gmail y una copia va a Proton; las respuestas salen desde el
20-nov-2026 por Resend, sin seguimiento (del 16 al 20-nov el servicio previsto era Brevo, con su píxel de apertura y
sus enlaces de clic en modo anónimo, pero solo envió pruebas del titular; ver «Respuestas por Resend» abajo): la política lo cuenta en «Si nos escribes», «Quién recibe los
datos», «Transferencias internacionales» y «Cuánto tiempo se conservan», y si el titular cambia de proveedor hay que
cambiar esos cuatro apartados; conservación de correos «como máximo un año desde el último mensaje de la conversación», con una limpieza cada tres meses que borra lo que cumpliría el año antes de la siguiente (plazo común a todas las apps desde el
16-nov-2026), en Gmail y Proton; Resend y Brevo no entran en esa limpieza: Resend borra solo a los 30 días, y la regla
de retención de Brevo (desde el 20-nov-2026) borra cada registro de envío de las pruebas 12 meses después del envío; fecha de última actualización la de la redacción. No se publica el NIF: el RGPD pide identificar al responsable y un contacto, y una app gratuita sin
actividad económica no está obligada a darlo por la LSSI.

Pendientes: la decisión 13 de `docs/preguntas.md` (ausencias de salud fuera de toda copia automática) no está
implementada, y la política dice la verdad actual (van en las copias); si se implementa, reescribir «Tu baja médica» y
«Copias de seguridad». Comprobar que la política coincide con «Seguridad de los datos» (Play) y «Privacidad de la app»
(Apple): no se recopilan datos. La versión inglesa (`politica-privacidad.en.md`) es una traducción de cortesía; manda
la española.

### Respuestas por Resend (2026-11-20)

**Decisión de Daniel (20-11-2026):** fuera el seguimiento de las respuestas de soporte en todas sus apps. Brevo, en el
plan gratuito, ponía un píxel y reescribía los enlaces, y eso pide un consentimiento previo que no se pedía (ePrivacy
5.3, guía de la AEPD; análisis de Astra en `regalos/docs/legal/NOTAS.md`). Se elige **Resend** (gratis, seguimiento
apagado, SMTP).

**Circuito desde el 20-11-2026:** Cloudflare Email Routing recibe y reenvía al buzón de Gmail, con copia a Proton (sin
cambios); Gmail «Enviar como» de turnly@mainshai.com envía por `smtp.resend.com`. Probado ese día: enlaces sin
reescribir, sin píxel, sin pie de baja; Resend no registra aperturas. Dominio `mainshai.com` en la región Ireland
(eu-west-1), seguimiento de aperturas y clics desactivado.

**Hechos de Resend (consultados el 20-11-2026; fuentes y citas en `regalos/docs/legal/NOTAS.md`, «Respuestas por
Resend (séptima vuelta, 2026-11-20)»):** Plus Five Five, Inc. (EE. UU.). Guarda los datos en EE. UU. aunque el envío
salga de Irlanda: copia de cada respuesta (contenido) y registro de envío, 30 días en el plan gratuito; las copias de
seguridad se conservan siete días («Backups persist for 7 days»: no es «7 días más» después de los 30). DPA del art. 28 para todas las cuentas y planes (https://resend.com/legal/dpa). Transferencia:
DPF (Resend «Active - Re-certification under Review» en dataprivacyframework.gov; si saliera de la lista, quitar la
frase del DPF de la política y quedarse con las SCC) y SCC de la Comisión, módulo 2, incorporadas al DPA. Un correo
concreto solo se borra antes pidiéndolo al soporte de Resend con los identificadores del panel (Emails).
Subencargados: AWS y otros, en EE. UU.

**Qué cambió en la política (es y en), primera redacción, corregida en la ronda 1 (histórico: la ronda 1 de
abajo cambia el plazo de las copias, el párrafo de Brevo y la supresión):** viñeta de Resend en «Si nos escribes» (envío desde Irlanda, datos en EE. UU.,
copia y registro 30 días, copias de seguridad 7 más, seguimiento desactivado, subencargados como AWS); fuera los
consejos para evitar el píxel; párrafo «Brevo, hasta el 20 de noviembre de 2026» (qué hacía, que las respuestas nuevas
ya no pasan por Brevo, qué queda allí y cuándo se borra, que vamos a pedir el borrado y cerrar la cuenta); párrafo de
conservación con Resend y lo que queda en Brevo; supresión: Gmail, Proton, petición al soporte de Resend y registros
de Brevo; se quita «Si dejamos de usar alguno de esos servicios, borramos lo que haya en él» (con Brevo recién dejado
no sería cierto hasta que Brevo borre). Apartado 4: fila de Resend, fila de Brevo limitada al pasado y frase del DPA de
Resend. Apartado 5: DPF + SCC módulo 2 para Resend. Apartado 6: Resend y los registros antiguos de Brevo. La política
no tenía fila de bases jurídicas ni párrafo de base propios del seguimiento de Brevo. Fecha y versión: siguen en
2026-11-20 (mismo día que el cambio de Brevo de la mañana; ya se hizo así con los cambios del 17-nov), igual que
`privacy_date` de `web/content/*.json`. También `docs/privacy.md` y `docs/privacy.en.md`.

**Turnly y Brevo:** turnly@mainshai.com solo envió por Brevo pruebas del titular (commit `899bcffc`; en toda la
cuenta de Brevo solo hay pruebas suyas, confirmado por Daniel el 20-11). Por eso la política lo dice así, sin el
condicional «si te respondimos antes por Brevo» y sin «sin copia de la respuesta»: las vistas previas de esas pruebas
(16-20 nov) pueden seguir en Brevo, porque «Never store previews» no es retroactivo; incluirlas en la petición de
borrado. Brevo sale de la supresión y del apartado 6: no tiene datos de personas usuarias.

**Ronda 1 de revisión del modelo (20-11-2026; Astra high FIX, Fable high PASS; modelo en regalos `4ddef46`):** plazo
de Resend con la fórmula «según Resend, conserva cada respuesta y su registro de envío durante 30 días desde el envío,
y sus copias de seguridad se conservan durante siete días»; párrafo de Brevo como servicio previsto que solo envió
pruebas; bases del 6.1.c (solicitudes de derechos) y del 6.1.f (conservación por reclamación) en «Si nos escribes» y
dos filas en el apartado 3; Resumen con el recorrido del correo; apartado 4 «cada uno en el paso que indica la tabla»
y «que se aplica»; enlace al DPA y «puedes pedirnos información» en el 5; enlace a la lista de subencargados; inglés
«a sending log», «emails are sent from Ireland», «(module 2)»; CHANGELOG. También `docs/privacy.md` y `.en.md`.

**Cómo atender una solicitud de derechos sobre el correo** (Turnly no tiene procedimiento propio; el completo está en
`regalos/docs/legal/procedimiento-derechos.md`): acceso = copia fiel e inteligible (art. 15.3), con un extracto sin
duplicados y protegiendo a terceros, incluido el registro de Cloudflare (pedírselo si el panel no lo deja ver); si la
petición es solo del correo, verificación proporcional (misma dirección o mismo hilo). En Resend, localizar los envíos
por destinatario y **comprobar en cada uno que el remitente es turnly@mainshai.com** (la cuenta envía por varias apps);
si hay dudas, aclararlas con Resend antes de entregar o borrar. Antes del borrado, comprobar si procede conservar algún
dato y documentar la razón; si se conserva algo, explicárselo a la persona (qué y por qué). El correo final de la supresión deja una copia nueva en
Resend y en Enviados de Gmail: decírselo a la persona. La primera vez que se entregue algo con adjunto, mirar si
Resend guarda el adjunto y anotarlo aquí. Limpieza trimestral: comprobar en Resend › Domains que `mainshai.com` sigue
con el seguimiento desactivado, en Gmail que «Enviar como» usa `smtp.resend.com`, que Resend sigue en la lista del DPF («Active - Re-certification under Review» el 20-11),
que https://resend.com/security/gdpr.md sigue diciendo 30 días y copias de siete días, y el pendiente de Brevo.

**Pendiente de Daniel:** pedir a Brevo por escrito que borre el historial, quitar sus DNS y cerrar la cuenta (anotar
aquí qué se pidió, qué confirmó y cuándo). Cuando la cuenta esté cerrada y Brevo confirme el borrado, cambiar el párrafo
de Brevo (y las filas de los apartados 4 y 6) para decir que ya no queda nada. Regenerar y desplegar la web (skill
`web-app`). Siguen abiertos: art. 28 con Google (Gmail de consumo) y Proton (plan gratuito); plazo del registro del
reenvío de Cloudflare.

**Ronda 2 de revisión del modelo (20-11-2026; Astra high FIX, Fable high PASS):** supresión con el criterio del art.
17.3.e («si procede la supresión… si debemos conservar algún dato, te explicaremos cuál y por qué»), Resend borra
respuestas y registros de envío; la viñeta de Resend dice que las respuestas salen desde turnly@mainshai.com; estado
del DPF «Active - Re-certification under Review». El registro de Cloudflare no se toca (pendiente ya anotado).

**Duda abierta (dev@mainshai.com):** la política admite correo en dev@mainshai.com, la dirección de las primeras
versiones, y dice que las respuestas salen desde turnly@mainshai.com. Comprobar en Cloudflare si dev@ sigue
reenviándose y que en Gmail las respuestas a lo que llegue a dev@ salen desde turnly@mainshai.com por Resend (y no
desde otra dirección o por otro SMTP); si no es así, ajustar la frase.
