# Diseño: dirección B «Noche» (claro y oscuro)

Elegida el 19-oct-2026 tras la ronda de propuestas (lienzo «Cuadrante · propuestas de diseño», filas B y «B en modo
claro»). Esta página manda sobre cualquier valor de color, tamaño o forma de la UI; los tokens viven en
`app/lib/core/theme/` y ningún widget usa valores sueltos.

## Idea
- **El turno, sin pensar.** Arriba, una tarjeta grande con el turno que importa ahora («Esta noche · Noche
  22:00–06:00 · Empieza en 3 h 40 min · Mañana: Noche»). La cuadrícula del mes va debajo.
- **Calma.** Celdas neutras con el **código grande en el tono del turno** y una **barra de color inferior**; un
  tinte muy suave del turno en el fondo de la celda para leer las semanas de lejos. Nada de bloques saturados.
- **Oscuro de verdad.** Pensada primero para la noche: fondo casi negro, tonos apagados, ámbar como acento. El modo
  claro es la misma estructura con otra paleta.
- **Nunca solo color:** cada día lleva código, hora y barra. Todo texto ≥ 4,5:1 sobre su fondo real.

## Tokens de color

| Token | Claro | Oscuro | Uso |
|---|---|---|---|
| `background` | `#F2F2F6` | `#0A0A0D` | Fondo de pantalla |
| `surface` | `#FFFFFF` | `#15151B` | Celdas del mes, tarjetas, hojas |
| `surfaceMuted` | `#ECECF1` | `#0F0F13` | Días de otro mes |
| `surfaceRaised` | `#F4F4F7` | `#1C1C23` | Botones redondos, fichas sin seleccionar |
| `border` | `#DCDCE2` | `#23232B` | Bordes suaves |
| `borderStrong` | `#C9C9D2` | `#34343E` | Bordes de controles |
| `textPrimary` | `#15151A` | `#ECECF1` | Texto principal |
| `textSecondary` | `#3A3A44` | `#C9C9D2` | Horas en la tarjeta, números de día |
| `textMuted` | `#5A5A64` | `#8E8E99` | Días de la semana, horas pequeñas, secundario |
| `accent` | `#4B4FD1` | `#A5A8FF` | Enlaces, interruptores, etiquetas |
| `highlight` | `#F5A524` | `#F5B547` | Cuenta atrás, icono del pincel, selección en oscuro |
| `onHighlight` | `#15151A` | `#0A0A0D` | Texto sobre `highlight` |
| `todayRing` | `#15151A` | `#F5B547` | Anillo de hoy y de la ficha seleccionada |
| `holiday` | `#D93036` | `#FF6369` | Número y punto de festivo |
| `primaryButton` / `onPrimaryButton` | `#15151A` / `#FFFFFF` | `#F5B547` / `#0A0A0D` | «Listo», botón principal |
| `fab` / `onFab` / `fabBorder` | `#15151A` / `#FFFFFF` / — | `#1C1C23` / `#F5B547` / `#34343E` | Botón «Pintar» (icono en `highlight`) |

### Acento elegible (opción 8.3B, 31-oct-2026)

En Ajustes › Apariencia › **Color de acento**, cinco acentos; Índigo (el de la tabla de arriba) por defecto. El
acento solo cambia `accent`, `accentText` y `accentSoft` (`AppColors.withAccent`, valores en
`core/theme/app_appearance.dart`): enlaces, interruptores, casillas, selección, pestañas, indicadores y botones de
texto. **Nunca** cambia los colores de los turnos, el ámbar (`highlight`: cuenta atrás, pincel, «Pintar»), el anillo
de hoy ni los botones principales.

| Acento | Claro `accent` / `accentSoft` | Oscuro `accent` / `accentSoft` |
|---|---|---|
| Índigo (por defecto) | `#4B4FD1` / `#E3E4FA` | `#A5A8FF` / `#23245A` |
| Azul | `#1A63C2` / `#DFE9F7` | `#8DBBFF` / `#2D3649` |
| Petróleo | `#0D7270` / `#DDEBEB` | `#5ED3CF` / `#243B3F` |
| Frambuesa | `#B4235A` / `#F5E0E8` | `#FF8FB8` / `#442D3A` |
| Grafito | `#3A3A44` / `#E2E2E5` | `#C9C9D2` / `#393940` |

Todos pasan 4,5:1 como texto sobre `background`, `surface` y `surfaceRaised`; `onAccent` 4,5:1 sobre el acento;
`textPrimary` 4,5:1 sobre `accentSoft`; y 3:1 (no texto) del acento sobre `accentSoft` y `surface`
(`test/core/theme/accent_contrast_test.dart`). Se guarda en `appearance.accent` (ausente = Índigo) y viaja en la
copia, como el tema. El selector muestra cada acento como un disco mitad claro, mitad oscuro.

## Color de cada turno

El usuario guarda **un** color por tipo (paleta por defecto de la especificación §4). La app deriva de él, al
pintar y nunca guardado, un `ShiftSwatch` por tema:

| Campo | Claro | Oscuro |
|---|---|---|
| `bar` (barra inferior, borde del trazo) | el color guardado | el guardado; si su luminancia < 0,15, aclarado hasta ≥ 0,15 (la Noche pasa a ≈ `#6B6EF0`) |
| `tint` (fondo de la celda del día) | mezcla 10 % del color sobre `surface` | mezcla 14 % sobre `surface` |
| `disc` (fondo de la ficha del modo pintar y del distintivo de la tarjeta) | mezcla 18 % sobre `surface` | mezcla 28 % sobre `surface` |
| `ink` (código y textos en el tono del turno) | el color oscurecido (luminosidad HSL) hasta ≥ 4,5:1 sobre `tint` **y** sobre `disc` | aclarado hasta ≥ 4,5:1 sobre `tint` y `disc` |

Valores de referencia (claro → oscuro): Mañana `ink` ≈ `#8F5A00` → `#F5B547`; Tarde ≈ `#B8401A` → `#FF8A66`;
Noche `#4B4FD1` → `#A5A8FF`; Vacaciones ≈ `#1D7A4F` → `#4CC38A`. **Libre** es especial: sin tinte, `bar`
`borderStrong`, `ink` `textMuted`. Días de otro mes: fondo `surfaceMuted`, sin tinte, código en `textMuted`, barra
al 45 % de opacidad (la barra no es texto).

## Tipografía
Fuente del sistema (SF Pro en iOS, Roboto en Android), sin fuentes incluidas. **Números tabulares** en la
cuadrícula, horas y cuentas atrás.

| Estilo | Tamaño / peso | Uso |
|---|---|---|
| `display` | 36 / 800, -0,6 | Nombre del turno en la tarjeta |
| `headline` | 24 / 800 | Cabecera del modo pintar |
| `title` | 21 / 750 | Mes («Octubre») |
| `bodyStrong` | 19 / 600 | Horas en la tarjeta |
| `body` | 15 / 400–600 | Texto general |
| `label` | 13 / 700, mayúsculas, +0,6 | «ESTA NOCHE», «PINTANDO» |
| `caption` | 12 / 600–700 | Días de la semana, etiquetas de fichas |
| `cellDay` | 11 / 650 (hoy 900) | Número del día |
| `cellCode` | 20 / 800 (14 con varios turnos) | Código del turno |
| `cellTime` | 10 / 600 | Hora compacta («22–06»; en el reloj de 12 h, «10p–6a»: `docs/formatos.md`) |

Mínimos adaptativos de la cuadrícula: `AppTypography.cellCodeMinSize` y `cellTimeMinSize` (8 dp antes del escalado
del usuario). El código se mide por separado; la línea horaria reserva los 6 dp del indicador de dos tramos
(`Sp.cellSegmentDot`) y su separación. Cuando el inicio con minutos no cabe, conserva la hora («09» para «09:30»);
la etiqueta accesible y el detalle mantienen los minutos y los dos tramos.

**Tamaño del turno en la casilla** (Ajustes › Apariencia › Tamaño del turno en el mes; P8, fila 10 de la
paridad): Normal ×1, Grande ×1,2, Muy grande ×1,4. Multiplica el tamaño de partida (y la línea) de `cellCode`,
`cellCodeMulti` y `cellTime` en `AppTypography.from(cellScale:)`; nada más. `day_cell.dart` no cambia: sigue
encogiendo el código y la hora hasta lo que cabe (`cellCodeSize`, `cellTimeInCell`, y la hora de inicio sola como
alternativa), así que en un móvil de 320 dp con letra ×1,6 un tamaño mayor llega antes al límite de la casilla pero
no desborda (`test/core/theme/cell_text_size_test.dart`). Las filas del mes crecen con él (`dayCellHeightWithTime`
mide los estilos del tema). Se guarda en `appearance.cellTextSize` (ausente = Normal) y viaja en la copia.

La altura de las líneas de la casilla se **mide**, no se estima: el motor las dibuja en píxeles enteros, así que
la celda reserva la altura real del número, del código y de la hora (con la letra al 130 %, la línea real mide
hasta 0,4 dp más de la estimada). Si una celda es más baja que la que reserva la rejilla (la imagen que se
comparte, la vista previa del asistente), el código se encoge hasta caber en vez de desbordarse.

## Componentes

**Tarjeta de hoy** (arriba del mes): `surface`, radio 24, padding 18, barra inferior de 5 px en `bar` del turno.
Bajo la fila del contador y «Mañana», dos líneas discretas de `meta` (C1): el próximo libre en `textSecondary` y en
negrita («Libras el jueves 5», «Mañana libras», «Hoy libras; vuelves el lunes 9») y, en `textMuted`, el próximo fin de
semana libre y la racha de trabajo (desde 3 días) separados por « · ». No salen cuando el calendario no sabe nada
más allá. En **Comparar calendarios**, el día en que nadie trabaja pero alguno no tiene nada anotado lleva un aro
vacío con un guion (`UnrecordedMark`, `borderStrong` y `textMuted`) en la esquina donde los libres en común llevan el
check; nunca solo color.
Etiqueta según el momento: «AHORA» (turno en curso: «Noche hasta las 06:00»), «ESTA NOCHE» (empieza a partir de
las 20:00), «HOY» (empieza antes), «HOY LIBRE» (sin turno: muestra el próximo, «Próximo: Mañana, mié 06:00»),
«HOY TERMINADO» (el último turno de hoy ya acabó: nombre del turno, «Terminó a las 22:00» y el próximo turno; no es un
día libre).
`display` con el nombre, `bodyStrong` con las horas, distintivo de 56×56 radio 18 (`disc` + `ink` con el código).
Debajo, ficha `highlight` con la cuenta atrás («Empieza en 3 h 40 min», se actualiza cada minuto) y la línea de mañana en
`textMuted`, con la fecha para que «mañana» no se lea como un turno llamado Mañana: «Mañana (mié 21): turno de Tarde» /
«Mañana (mié 21): sin turno». Varios turnos hoy: el siguiente que empieza manda; los demás en una línea «+ Tarde 14:00–22:00».
**Plegable** (B1, opción 1A del lienzo del 31-oct): en el mes de una columna, un botón de 48 dp con chevrón
(`textMuted`) cierra la última línea de la tarjeta (la del próximo libre si la hay; si no, la de la cuenta atrás y
mañana) y la **pliega a una línea**: distintivo de 44 dp (radio `Rad.input`, código en `title`), etiqueta del momento,
nombre en `bodyStrong` 800 con las horas en `body` `textSecondary` y la ficha de la cuenta atrás (pasan a otra línea
si no caben), el chevrón para desplegar a la derecha y, debajo, el próximo libre en negrita con el fin de semana y la
racha en `textMuted` («Libras el jueves 5 · Fin de semana libre: 14–15 nov»). La línea de mañana, los demás turnos
del día y el siguiente tras uno terminado esperan en la tarjeta abierta. Se pliega y despliega en 200 ms
(`AnimatedSize`, nada con «reducir movimiento») y **se recuerda entre aperturas** (fila
`calendar.todayCardCollapsed` de la tabla `settings`, sin cambio de esquema; viaja en la copia como el tema). El
lector lee la tarjeta como un bloque y el botón aparte, «Plegar/Desplegar la tarjeta de hoy», con su estado
expandido; es el mismo elemento en las dos formas, así que el foco no se pierde al pulsarlo. En el panel derecho de
dos paneles la tarjeta no se pliega (allí sobra sitio).
**Empieza plegada cuando el mes no cabe** (decisión 28, 1-nov-2026): al montar la pantalla (y al girar o cambiar el
tamaño de texto) se calcula una sola vez si caben, sin desplazar, la fecha, la tarjeta **desplegada**, la fila del mes,
la de los días de la semana, **seis filas** de casillas (siempre seis, aunque el mes tenga cinco, para que la tarjeta no
cambie al pasar de mes), la fila fija inferior (72 dp) y, debajo, la barra de destinos con el área del sistema
(`MonthFit`; no lee el teclado). Si caben (tablets, móviles muy altos, texto normal) sale desplegada; si no, **sale
plegada** en su forma de una línea. Solo fija el **valor por defecto**: la elección de la persona
(`calendar.todayCardCollapsed`) sigue ganando y se recuerda (sin elección guardada, el proveedor vale `null`); si
despliega la tarjeta en un móvil donde no cabe, el mes se desplaza con la fila del mes fija. En «HOY LIBRE» la línea de
horas de la forma plegada dice el próximo turno («Próximo: Tarde, lun 14:00»). Con «reducir movimiento» la tarjeta
cambia de alto de golpe (`MotionSize`).
**Turno partido** (A12): entre sus dos tramos la etiqueta es «DESCANSO», con «Vuelves a las 17:00» y la ficha «Vuelves
en 2 h 45 min»; dentro de cada tramo es «AHORA» con «Hasta las 13:00» / «Termina en…». El segundo tramo no sale como
otro turno en la línea «+ …». Antes del primero, la línea de horas lleva los dos: «09:00–13:00 · 17:00–21:00».

**Márgenes de la pantalla del mes**: todo (cabecera, tarjeta de hoy, fila del mes con sus flechas y la
cuadrícula) respeta `Sp.l` (16 dp) a cada lado. La cuadrícula lo consigue con 14 dp de relleno más los 2 dp que
lleva cada casilla; los botones de 48 dp con el glifo de 24 dp van a 4 dp del borde. La fecha de la cabecera sale
entera («Martes, 20 de octubre») y, si no cabe en una línea (texto grande, 320 dp), en forma corta («Mar 20 oct»);
nunca se recorta con puntos suspensivos ni a media palabra.

**Celda del día**: `surface` + `tint`, radio 12, alto ≥ 62. Número arriba a la izquierda (`cellDay`,
`textSecondary`); código centrado abajo (`cellCode`, `ink`) y hora (`cellTime`, `textMuted`); **barra inferior de
6 px** (`bar`; con varios turnos, segmentos iguales y códigos apilados). **Turno partido:** la hora de la casilla es
«09–13/17–21» y solo se dibuja si cabe en el ancho de la casilla a su tamaño (`shiftTimeFitsInCell`, con el texto
del usuario); si no, la casilla dice la hora de inicio del primer tramo («09»), porque nunca se queda solo con el
código (los dos horarios están en el detalle del día). Festivo: número en `holiday` + punto de
6 px arriba a la derecha. Nota: clip de 11 px arriba a la derecha (si hay festivo, el clip a la izquierda del punto).
Hoy: anillo interior de 2 px `todayRing` y número en 900. Día vacío: solo `surface`, sin barra.
El contenido de la casilla (código, icono y hora) se dibuja **dentro** del borde más grueso que
dibuja la casilla (3,5 dp de margen a cada lado), de modo que el borde de un día elegido nunca
tapa el código ni la hora; el margen se reserva siempre, para que el código no cambie de tamaño
al elegir el día.
**Icono del turno** (A8): va **delante del código**, de 12 dp (escalado con el texto) en la `ink` del turno, y solo si
icono + 2 dp + código al tamaño normal caben dentro del borde de la casilla (3,5 dp a cada lado) con 1 dp de margen a
cada lado (`shiftIconFitsInCell`); si no, la casilla enseña solo el código, nunca un código más pequeño por culpa del icono. Con
varios turnos en el día nunca hay icono. En una casilla de ~42 dp (móvil de 320 dp) un código de una letra lleva
icono con el texto al 100 % y no al 130 %; los códigos de 2-3 letras solo lo llevan en pantallas anchas. **Horas extra /
salí antes** (A6): un «+» de 11 px (`AppIcons.extras`, `textMuted` del tono del turno) arriba a la derecha, en la fila
del número del día y delante del clip de la nota y del punto de festivo (esa fila no la invade nunca el código ni la
hora; en una casilla muy estrecha la fila encoge hasta el 60 % en vez de salirse); el texto leído de la casilla dice «horas extra: 1 h 30 min» / «salida anticipada: 30 min».
En el distintivo de 44 px (lista de turnos, detalle del día), en las fichas redondas de pintar y en la leyenda el
icono va encima del código (12-14 dp) o delante del nombre; el código no desaparece nunca.
**Cuatro turnos o más en un día:** como mucho 3 bandas. Se ven los 2 primeros turnos y una tercera banda neutra «+N» (`surfaceMuted`, borde superior `borderStrong` de `Sp.hair`, texto `textMuted` en `cellCodeMulti`), nunca en color de turno; la altura de la fila se mide con ese tope y el lector de pantalla nombra todos los turnos. Las bandas se reparten la altura de la casilla en proporción a lo que necesita cada una (su código y su hora; la primera, además, la fila del número; la última, la barra), y la fila mide la suma de esas alturas, no la banda más alta por el número de bandas.**Forma de las fichas:** `ChoicePill` es una píldora por defecto; las fichas de etiqueta larga o de varias líneas (profesión, turno y tanda del día del ciclo) usan `Rad.inputRadius`.

**Modo pintar** (B3, opción 3A del lienzo del 31-oct; una línea y hoja que mide lo que sobra, decisión 28): cabecera
**de una línea** «PINTANDO · CAMBIAR EL TURNO» (`label`: «PINTANDO» en `ink` del turno elegido y el modo en `textMuted`;
con «Borrar» la segunda parte dice «BORRAR», que no tiene modo) a la izquierda y, a la derecha, el botón del patrón y
«Listo» (`primaryButton`). Ya no hay línea `headline` con «Tarde · 14:00–22:00»: el turno elegido se ve en la ficha con
anillo y nombre en negrita y sus horas pasan a la miniatura. El lector lee «Pintando, cambiar el turno» (una frase, sin
el separador). Abajo, hoja `surface` radio 26 con, de arriba abajo:
- **El consejo del primer uso**, solo la primera vez que se entra en Pintar tras el primer uso: una línea `meta` con el
  icono del pincel, «Elige un turno y arrastra.» y la cruz de 48 dp (`onboarding-tip`), encima del control de modos.
  Desaparece al terminar el primer trazo o con la cruz, y se recuerda (`onboarding.tipPending`). Ya no sale en el mes,
  que se queda sin elementos que no sean el mes.
- **Los dos modos**, «Cambiar el turno | Añadir otro turno», un control segmentado a todo el ancho (pista
  `surfaceMuted` radio `Rad.button`; el elegido en `accentSoft` con borde `borderStrong` y etiqueta 800, nunca solo
  color; iconos de 18 dp que desaparecen desde texto ×1,6; las etiquetas se parten entre palabras, nunca se
  cortan). Sustituye al chip «Doblar»: la palabra del sector se conserva en el nombre leído («Añadir otro turno
  (doblar)») y en la miniatura. Con «Borrar» elegido el control se atenúa y no responde.
- **La miniatura del efecto** a la izquierda de Deshacer y Rehacer (círculos de 48 px en `surfaceRaised`, siempre a la
  vista), en **una línea**: «Al tocar un día» en `caption`, dos casillas pequeñas reales (`tint`, códigos en `ink` y
  barra de 4 dp en `bar`, en segmentos con dos turnos; 36 dp como mínimo y crecen con el texto) y, a su derecha, las
  **horas del turno elegido** en `meta` negrita («[T] → [M] 06:00–14:00»). Lo que no cabe en la línea se va por el final:
  primero «Sustituye al que haya» / «Se suma al que ya hay» / «Deja el día vacío», luego «Al tocar un día». El día de
  antes es un ejemplo: el primer otro turno de trabajo de la paleta. Cambia (fundido de 200 ms) en cuanto se elige otro
  turno, «Borrar» o el otro modo. El lector la lee entera («Al tocar un día: Tarde pasa a Mañana, 06:00–14:00.
  Sustituye al que haya»), y la ficha elegida lee su nombre y sus horas («Mañana, 06:00–14:00»).
- La zona de **fichas redondas** de 48 dp (`Disc.toolPuck`; `disc` + `ink`, etiqueta `caption` debajo; la seleccionada
  con anillo de 2,5 px `todayRing` separado 3 px; «Borrar» con borde `borderStrong`).
Durante el trazo, las celdas tocadas se rellenan con `disc` y anillo de 2 px en `bar`.
La cabecera mide **siempre lo mismo** al cambiar de herramienta (el mes de debajo no se mueve); «PINTANDO · …» se
reduce antes de partirse. **La hoja mide lo que sobra, no lo que quiere** (decisión 28): la pantalla coloca primero la
cabecera, la fila del mes y los días de la semana y **las seis filas de la cuadrícula** (a 64 dp o lo que pidan los días
con turnos apilados) y le da a la hoja la altura restante (`PaintBar.maxHeight`), con un **suelo** de consejo (si
sale) + control de modos + miniatura con Deshacer/Rehacer + una fila de fichas + el área del sistema (unos 250 dp;
`PaintBar.minHeight`). El control de modos y la miniatura con Deshacer/Rehacer quedan **siempre fijos**; solo se
desplaza en vertical la zona de fichas (se mantiene el `Wrap`), con un degradado arriba y abajo cuando hay más y la
ficha elegida a la vista al abrir. La altura de la hoja se anima 200 ms al cambiar (nada con «reducir movimiento»,
`MotionSize`). Con texto grande (desde ×1,6) o móviles bajos, si ni el suelo cabe, se vuelve al comportamiento
anterior: la hoja mide lo que necesitan sus herramientas, la zona de fichas no pasa del 25 % del alto de la pantalla
y el mes se desplaza por encima con su fila fija; los botones ↑↓ solo se muestran cuando el mes se desplaza de
verdad. Las fichas se ensanchan con el tamaño de texto y parten el nombre entre palabras («Libre /
disposición»), nunca lo abrevian. **Las fichas saltan de línea** (`Wrap`), nunca una fila que se desplaza de lado y
corta la última a media palabra (H-T17-3). En el panel derecho (dos paneles) la hoja es una tarjeta con el margen
`Sp.l` de las demás y las cuatro esquinas redondeadas (H-T17-7). En ese panel ocupa toda la altura disponible entre la
cabecera y las acciones: fichas en rejilla con desplazamiento vertical y Deshacer/Rehacer siempre accesibles.

**Detalle del día** (B4 y A7; opción 4A del lienzo del 31 oct, elegida por el usuario): hoja inferior `surface`
radio 26, **alta según su contenido** hasta un máximo del 88 % de la pantalla (lo que no cabe se desplaza dentro; un día
normal ocupa media pantalla y el mes se sigue viendo encima). La altura cambia con un `AnimatedSize` de `Motion.state`
(cero con «reducir movimiento») al abrir la paleta o «Más opciones»; con el teclado, la hoja se apoya encima y solo
encoge si no cabe. La cabecera queda fuera del desplazamiento (arrastrarla cierra la hoja como el asa) y lleva la
fecha en `headline`, el festivo en `holiday` (sin repetir la palabra: «Festivo propio», «Festivo: Fiesta Nacional de
España») y, a la derecha, **Deshacer** (botón de icono de 48 dp, `day-undo`, con el nombre «Deshacer el último cambio
de este día»): deshace el último paso del historial solo si cambió ese día y nada más (un turno, la nota, su aviso, las
horas extra), aunque se hiciera antes de abrir la hoja; si el último paso es de otro día, de una rotación o de una
pincelada de varios días, está desactivado (`disabledContent`). Lo que se está escribiendo se guarda antes, así que
deshace eso. El festivo propio y «Sin alarma este día» no están en el historial: se deshacen con su interruptor.
Rehacer sigue en Pintar. Debajo, por capas:

1. **Turnos**: una fila por turno (distintivo de 44 px con `disc` + `ink`, nombre `bodyStrong`, hora y horas que
   cuentan en `body` `textSecondary`, «22:00–06:00 · 8 h») con su **menú** (`…`, 48 dp, «Opciones de Noche»):
   Cambiar, Subir, Bajar y Quitar (subir y bajar solo con dos turnos o más; la primera no sube y la última no baja, con
   el icono en `disabledContent`). Después, de dónde sale el día en `meta` («Según tu patrón» / «Cambiado a mano») y,
   si está cambiado a mano, «Volver al patrón» (botón con borde) con lo que da la rotación en `meta`.
2. **Añadir turno** (botón con borde a todo el ancho) abre la **paleta en la misma hoja**: tarjeta `surfaceRaised`
   radio 16 con borde, título en `bodyStrong` («Añadir turno» en un día vacío, «Doblar con otro turno» si ya tiene uno,
   «Cambiar Noche por…» desde el menú de una fila), botón de cerrar y las fichas redondas de 44 px de pintar (con salto
   de línea y los nombres enteros; las que el día ya tiene, atenuadas y sin acción). Al elegir, la paleta se cierra y
   la fila nueva dice lo que pasó. En un día sin turno la paleta ya sale abierta (es a lo que se abre).
3. **Nota**, siempre a la vista: campo `surfaceMuted` de 2 líneas mínimo con el clip delante; el lector de pantalla lo
   llama «Nota».
4. **Más opciones**, plegado (fila con separador, icono, título `bodyStrong` y, en `meta`, lo que guarda: «Horas extra
   · Festivo propio · Aviso · Duplicar · Borrar», con los valores puestos, «Aviso: 21:00», «Horas extra: 1 h 30 min»;
   «Aviso» no sale en un día pasado y «Alarma» / «Sin alarma este día» solo cuando ese interruptor se muestra). Para el
   lector es un botón con estado plegado/desplegado. Dentro: la sección «Horas extra / Salí antes» (dos contadores con
   «−» y «+» de 15 min y el valor en `body` en negrita, «Ninguna» si es 0; el valor se escribe tras 600 ms sin tocar o
   al cerrar la hoja, así que una tanda de toques es un solo paso de deshacer; con texto grande la etiqueta pasa a su
   propia línea), el interruptor «Festivo propio» con su nombre, «Avisarme», «Sin alarma este día», las secciones de
   otras funciones y los atajos «Duplicar en otro día» y «Borrar día» (botones con borde; los dos cierran la hoja y
   avisan con una barra, «Día borrado» con «Deshacer»).

**Hueco para funciones futuras** (adjuntos C7, libro de cambios C10, importe extra por día): se enganchan con una línea
en `dayMoreSectionsProvider` (`app/lib/features/calendar/presentation/day_more_options.dart`), una `DayMoreSection`
con id, nombre corto (de los ARB) y constructor de la sección. Sale dentro de «Más opciones» después de las propias y
antes de «Duplicar» y «Borrar día», en la hoja y en el panel de tablet, y su nombre se añade a la línea que resume
«Más opciones». La sección guarda sus cambios (un paso de deshacer cada uno) y escribe lo pendiente en su `dispose`.

Cada cambio es un paso de deshacer. En el panel derecho de tablet (dos paneles) es lo mismo, con Deshacer y el botón de
cerrar el día juntos arriba, y ocupa todo el alto del panel.

**Mis turnos** (Ajustes): lista de tarjetas `surface` radio 16 con el distintivo del turno, «horas · categoría ·
precio», archivar y asa para arrastrar; «Nuevo turno» fijo abajo. El formulario va de arriba abajo: nombre, código,
**vista previa** (la celda real en claro y en oscuro, con el contraste del código impreso debajo), rejilla de colores
(los 8 de la especificación y 16 más, círculos de 44 px; el elegido con anillo `todayRing` y marca de verificación),
categoría y opciones en **píldoras** (`ChoicePill`: borde `borderStrong`; la elegida con anillo de 2 px `todayRing`, marca
y negrita), horario (interruptor «Sin horario» y dos botones de hora de 24 h) y, solo en turnos de trabajo con
horario, descanso no pagado, turno nocturno y precio por hora. El campo **Icono** (opcional; debajo de la categoría)
es un botón con el icono actual o «Sin icono» que abre una hoja con una rejilla de blancos de 48 px: «Sin icono» y los
30 símbolos de la lista cerrada `ShiftIcon`; el elegido con anillo `todayRing` y marca de verificación, y cada uno
con su nombre para el lector de pantalla.

**Botón «Pintar»** (FAB extendido): ver tokens `fab`; alto 56, radio 28, icono de pincel en `highlight`.

**Widgets**: misma lógica que la tarjeta de hoy (pequeño), tira de 7 días con barras (mediano), mes en miniatura
(grande); fondo `surface` del tema del sistema; barra inferior en el pequeño.
**Elegir widget** (diseño 7A, B8; Ajustes › Avisos y widget › Añadir widget): hoja con una **galería** de los cinco
widgets a escala sobre un «fondo de pantalla» hecho con tokens (degradado `accentSoft` → `surfaceMuted` → un 18 % de
`highlight`, radio 24). Cada miniatura se dibuja en Flutter (`widget_previews.dart`) con la **misma instantánea** que
leen los widgets nativos (`buildWidgetSnapshot`, un día) y los turnos reales del calendario principal: el pequeño con
el código en grande sobre el `tint` del turno, la tira de 7 días, las dos semanas, la agenda y el mes con hoy en
anillo `todayRing` y los festivos con el número en `holiday`. Cada una se maqueta a su tamaño de pantalla de inicio
(150×150, 320×150, 320×320) y se escala a lo que tiene, sin seguir la letra del móvil (como en la pantalla de inicio);
debajo, nombre (`bodyStrong`) y qué enseña (`meta`). Pequeño y Agenda van lado a lado y se apilan con texto grande o
menos de 300 dp. Tocar una la elige (anillo `todayRing` de 2,5 dp) y el botón fijo de abajo dice «Añadir Mediano»;
donde el lanzador no deja anclar, la galería sigue y el texto con los pasos sustituye al botón. Para el lector, cada
miniatura es un botón «Mediano: los próximos 7 días», seleccionado o no.

**Resumen: «¿Cómo voy?»** (diseño 5A, B5). Primera tarjeta del resumen (mes, año y fechas), radio 24: «¿CÓMO VOY?»
(`label`), las horas **trabajadas** en grande (`display`) con «trabajadas» / «trabajadas hasta ayer» al lado (un
periodo que no ha empezado enseña las **previstas** en grande) y, en un periodo en curso, «y 64 h previstas hasta el
sáb 31 oct». Debajo, **una barra** de 14 dp: trabajadas en `accent` macizo, previstas a continuación **rayadas** (rayas
del `accent` al 60 % sobre un 16 %) y el **objetivo** como una marca de 3 dp en `textPrimary` que sobresale 6 dp; la
barra mide lo mayor entre el total y el objetivo. Leyenda en `meta` con la cifra de cada parte. Con objetivo, una ficha
`highlight` + `onHighlight` (radio 12, la de la cuenta atrás) con la diferencia («Te faltan 24 h», «Con lo previsto, 10 h
de más») y, debajo, de dónde sale el objetivo del periodo («1642 h al año, entre 12»); sin objetivo, «Fijar un
objetivo de horas» discreto. El lápiz para cambiarlo va en la cabecera. Después, la tarjeta **Desglose** (la
comparación con el periodo anterior y las líneas de turnos, extras, nocturnas, libres, ausencias y festivo), el
estimado si hay precios, los turnos por grupo y, al final, **lo que no tiene datos plegado** en una tarjeta de líneas:
«Ausencias · Ninguna» y «Ingresos estimados · Sin precios», que se abre (chevron que gira) para enseñar qué hacer.

**Ajustes** (diseño 6A, B6): grupos en este orden, cada fila con su icono y **el estado a la derecha o en la
segunda línea**: **Mi calendario** (Mis turnos con cuántos hay, Calendarios con el de pantalla, Mis rotaciones,
Saliente automático, Importar turnos) · **Avisos y widget** (Alarmas con «Activadas» y «Avisos hasta el mar 17 nov»,
Añadir widget, Exportar turnos al calendario del móvil, Compartir por enlace) · **Copias y cambio de móvil** (Copia de seguridad: «Última:
ayer a las 22:14, comprobada», «Todavía no hay ninguna copia» o el fallo de la última copia automática) ·
**Apariencia** (Tema, Idioma, Formato de hora, Primer día de la semana, número de semana, Moneda, Festivos con el país o
la comunidad) · **Ayuda** · **Borrar todo y empezar de cero** (grupo propio al final, fila destructiva).
El borrado conserva solo el idioma y dos copias de seguridad previas, separadas de la rotación automática.
La pantalla enumera también los festivos propios, el enlace compartido y la copia diaria en carpeta (sus archivos se
conservan). Mientras guarda la copia se puede volver atrás; tras confirmar, «Borrando…» bloquea la interacción y
atrás. Primero se vacía la base; la limpieza de sistema continúa aunque falle un paso. Siempre lleva al primer uso,
con una línea de aviso si quedó algo sin limpiar. Una fila nueva de otra función es su propio widget y una línea en el grupo (el «Color de
acento» va justo debajo de Tema).

**Copia de seguridad** (B9): la acción principal es **«Guardar una copia fuera de Turnly»** (botón relleno: comparte
el archivo para la nube, otro dispositivo o el correo) con una línea que explica para qué; «Hacer copia ahora» (la del
móvil) va debajo con borde y dice «Guardando la copia…» mientras tanto. La tarjeta de estado añade «Comprobada: se
puede recuperar entera» en `success` (cada copia se vuelve a leer entera al guardarla).

**Estados vacíos** (diseño 8.1B, B10): los que esperan turnos llevan un **dibujo hecho con las piezas de la app**
(`EmptyIllustration`, 200×124 dp, `CustomPaint` + los códigos como texto) en lugar del disco con icono: tres fichas
redondas en arco con un «+» punteado (agenda), tres casillas con su barra y una punteada (resumen sin turnos, año
vacío, rotaciones, Mis turnos, comparar) y dos casillas en una tarjeta con un camino punteado y un check en
`accentSoft`/`accent` (sin copias). Usa **los colores y códigos de los turnos de la persona** (los tres primeros que no
son Libre; si faltan, Mañana, Tarde y Noche de partida), así que sigue al tema y a la paleta, y nunca es solo color.
Es decorativo: no lo lee el lector de pantalla y no crece con la letra. Los errores y las búsquedas sin resultado
siguen con su icono.


**Icono de la app**: cuadrícula 3×3 sobre `#141418`, casillas con radio ≈ 4 % del lado; la **fila central** en
Mañana `#F5A524`, Tarde `#F06A3F` y Noche `#4B4FD1`; el resto `#2A2A31`.

**Texto grande y pantallas estrechas** (campaña de pruebas T04-T07): nunca se parte una palabra ni una cifra; se
envuelve entre palabras o se cambia de disposición. Los controles del mes (Cuadrícula/Lista, «Hoy» y las flechas)
se reparten en dos filas cuando no caben en una: primero, si el título cabe con «Hoy» y las flechas, el selector
Cuadrícula/Lista baja solo a una línea propia debajo, alineado a la derecha; si ni eso cabe, el título ocupa su línea y
los controles van debajo en una o dos filas (320 dp con letra grande en inglés), sin bajar de 48 dp de objetivo táctil. `ValueRow` apila el valor bajo el título (hasta 3 líneas,
alineado con él); `AdaptiveButtonRow` apila dos botones (el principal arriba) cuando la palabra más larga de una
etiqueta no cabe; las barras de herramientas con nombre bajo cada botón (selección de días) miden su palabra más
larga y, desde texto ×1,6, quedan solo con el icono y el nombre como tooltip. Los rangos de horas se escriben con
`keepTimeRangesTogether`. **Avisos** (`SnackBar`): siempre con `appSnackBar` (6 s; si hay acción y lector de pantalla, permanece hasta actuar o cerrarlo) y, sobre el mes, con `showTrackedSnackBar`, que reserva su alto bajo la rejilla. **Archivados**: lo que se
archiva (turnos, calendarios) se recupera desde una sección plegable «Archivados (n)» al final de su lista, con
«Recuperar». **Salir con cambios**: un formulario con datos sin guardar pregunta «¿Descartar los cambios?»
(«Seguir editando» / «Descartar»).

## Mes: Cuadrícula / Lista (decisión D, 26-oct-2026)

El mes ofrece dos presentaciones mediante etiquetas visibles **«Cuadrícula» / «Lista»**. Desde B1 (31-oct) el
control es pequeño y está **en la fila del mes**, entre el título y «Hoy»/flechas, en todos los modos, incluidos
Pintar y Selección: texto `meta` sin iconos, pista `surfaceMuted` de radio `Rad.inner` dibujada más fina (6 dp por
arriba y por abajo) dentro de los 48 dp de cada mitad, que son el objetivo táctil entero. La fila del mes y la de los
días de la semana quedan **fijas arriba** (`PinnedHeaderSliver`, fondo `background`) mientras los días se desplazan
por debajo; la fecha y la tarjeta de hoy se van con el desplazamiento. Con texto desde ×1,6 o una ventana de
menos de 480 dp de alto (móvil en horizontal) o de 320 dp de ancho (pantalla dividida) esa fila fija se comería los días: entonces solo Cuadrícula/Lista queda
fija, en su propia línea centrada encima del mes (como antes de B1), y la fila del mes se desplaza con los días
(`monthRowPinned`). Sus blancos táctiles y semánticos miden
al menos `Sp.touch` (48 dp), y el `Wrap` pasa los controles a otra línea sin reducir el texto. Permanece accesible
al desplazar los días: reserva toda su altura natural, también cuando el texto grande hace que el `Wrap`
ocupe varias líneas. Las dos opciones quedan siempre visibles y pulsables sin desplazar el selector;
solo se desplazan los días. «Seleccionar días» comparte la fila fija inferior con los botones de desplazamiento
de Pintar (que solo salen si el mes se desplaza de verdad), para reservar sitio a ambas presentaciones y a los días.
**La cuadrícula manda** (decisión 28): con texto normal el mes entero (seis filas) cabe sin desplazar en un móvil
alto, en Mes (con la tarjeta de hoy plegada por defecto si no cabe desplegada) y en Pintar (la hoja cede). La fila fija
inferior mide **72 dp** (el botón «Pintar» de 56 dp más su margen de 16): la cuadrícula termina encima de ella y el
botón flota sobre esa fila, nunca sobre un día. **Nunca se cambia de presentación automáticamente.**
La elección dura toda la sesión,
también al navegar a otra pantalla, cambiar de mes/calendario y girar el dispositivo, y **se recuerda entre aperturas**
(B7, 31-oct; antes no se escribía): cuando la persona elige una presentación se guarda en la fila
`calendar.monthPresentation` de la tabla `settings` (sin cambio de esquema) y se lee al abrir el mes (la cuadrícula
hasta que llega la lectura; una elección hecha antes gana). Nada la cambia sola: la recomendación de la Lista sigue
siendo solo un punto.

La opción Lista se destaca con fondo y borde cuando `(anchoPanel − 28 − columnaSemanas) / 7 < 48 dp`
(`columnaSemanas` = 24 dp si está activada), cuando el escalado real del estilo de código u horario alcanza
×1,5, o si medir el contenido predice reducción/omisión en la cuadrícula (incluidos varios turnos). El aviso
accesible/tooltip explica «Lista recomendada para ver los horarios completos y el texto grande». Es una
recomendación, no una afirmación de que las casillas compactas cumplan 48 dp o ampliación íntegra al 200 %.

**Lista del mismo mes:** usa `Schedule.resolve` y `CivilDate`, muestra todos sus días (también vacíos) y ningún
día gris de los meses vecinos. Agrupa por semanas con el inicio configurado; la cabecera dice las fechas del
grupo y, si está activo, el mismo número ISO que la cuadrícula. Comparte anterior/siguiente y Hoy; no es la
Agenda general ni tiene su límite de próximos días. La Agenda no cambia.

**Fila adaptable:** tarjeta `surface`, radio `Rad.row`, margen lateral `Sp.l`, relleno `Sp.m` y separación `Sp.s`.
Fecha con `bodyStrong`; Hoy como texto; selección con borde grueso y la palabra «elegido», además del fondo.
Cada turno lleva su propio bloque `tint`, barra `bar`, código `bodyStrong` y nombre/horario `body` en su `ink`.
Cada tramo ocupa una línea propia y conserva minutos y cruce de medianoche (por ejemplo, `09:30–13:00`,
`17:15–21:00`, `22:15–06:15`). No hay elipsis, `FittedBox`, tamaño mínimo impuesto ni reducción del texto.
Se muestran festivos oficiales y propios (también cuando coinciden), indicador de nota y minutos de extras o
salida anticipada; el detalle del día permite leer/editar su contenido completo.

**Mismas acciones e historial:** toque/Intro/Espacio abren el mismo detalle, pintan con `PaintController` o
alternan el día mediante `SelectionController`, según el modo. En la Lista **arrastrar solo desplaza** y cada
toque de pintura es un paso de deshacer; borrar y doblar usan las herramientas existentes. «Seleccionar días»
permite entrar sin pulsación larga en ambas presentaciones, y conserva todas las operaciones de la barra
(turno, doblar, borrar, patrón, nota, copiar/cortar/pegar y repetir), además de deshacer/rehacer.
La selección se conserva por calendario durante la sesión: al cambiar a otro no se aplica la elección del
anterior; al volver se recupera. Cambiar de presentación no escribe datos ni añade historial.

**Foco y lectura:** cambiar de presentación emite un solo anuncio («Presentación de lista/cuadrícula») y
solicita foco en el último día usado, abierto o seleccionado dentro del mes (si no, Hoy o su primer día).
Reconstruir no vuelve a anunciar. Tab recorre las filas en orden; flechas arriba/abajo e izquierda/derecha
avanzan un día en Lista; Intro/Espacio activan sin repetir por mantener la tecla. La cuadrícula conserva su
movimiento vertical de una semana y sus acciones accesibles. El foco desplaza la fila hasta hacerla visible.

Textos propuestos en los cinco ARB: Cuadrícula/Quadrícula/Cuadrícula/Sareta/Grid;
Lista/Llista/Lista/Zerrenda/List; Seleccionar días/Selecciona dies/Seleccionar días/Hautatu egunak/Select days.
Los avisos y anuncios también están localizados; no se añaden sufijos a variables en euskera.

## Barra de destinos (B1, opción 1A, 31-oct-2026)

**Mes · Rotación · Agenda · Resumen**, siempre con nombre, en una barra inferior (`NavigationBar` del tema: fondo
`surface` con filete `border` arriba, indicador `accentSoft` en forma de píldora, icono de 24 dp; nombre en `caption`,
`textPrimary` 800 el elegido y `textMuted` 600 los demás). El botón «Pintar» flota encima, a la derecha. La barra se
oculta en Pintar y Selección (su hoja de herramientas ocupa ese sitio) y con el teclado abierto. Desde texto ×1,6, o si
un nombre no cabe en su cuarto de ancho, los destinos quedan solo con el icono y el nombre como tooltip y texto leído,
como las demás barras con nombre. Con dos paneles los mismos destinos van en un **raíl** de 80 dp a la izquierda del mes
(`NavigationRail`, nombres debajo; solo iconos con la misma regla), porque una barra inferior se comería el alto que le
falta al mes en un móvil horizontal. Ese raíl lo llevan también Rotación, Agenda y Resumen (`DestinationRailShell`, puesto en la ruta) cuando hay dos paneles: el mismo punto de corte (`Adaptive.useSplit`), con su destino marcado; tocar otro destino sustituye la pantalla (el atrás sigue yendo al mes) y «Mes» vuelve al mes de hoy. Con una columna (móvil, tableta en vertical) no cambia nada.

Qué abre cada uno (los tres últimos se abren encima, con su botón atrás, como antes):
- **Mes**: esta pantalla; tocarlo vuelve al mes de hoy (y cierra el día abierto en el panel).
- **Rotación**: «Mis rotaciones» (`/ajustes/rotaciones`: terminar o quitar una rotación) si el calendario tiene alguna;
  si no hay ninguna, el asistente de patrón (`/patron`), que es donde se crea. Antes de B1 no había un acceso
  «Rotación»: el icono de la fila del mes era la **vista anual**, que no es una rotación; la vista anual sigue a un
  toque desde el **título del mes** («Octubre, elegir mes»).
- **Agenda**: próximas notas y búsqueda (antes, icono de la cabecera).
- **Resumen**: el resumen del mes que se está viendo (antes, icono de la fila del mes).

## Pantallas anchas (horizontal y tablet)

Decidido con el usuario el 22 oct 2026 (opción A). En pantallas anchas el mes pasa a **dos paneles**: el mes a la
izquierda y, a la derecha, el detalle del día elegido o, sin día, la tarjeta de hoy y los próximos días. El móvil en
vertical no cambia en nada.

**Cuándo hay dos paneles** (`Adaptive.useSplit`, sobre el tamaño de la ventana entera, que el teclado no cambia):
ancho ≥ 840 dp (la clase «expandida» de Material), o ancho ≥ 600 dp y la ventana más ancha que alta (horizontal).

| Pantalla | Tamaño (dp) | Resultado |
|---|---|---|
| Móvil vertical (Pixel 9) | 412 × 915 | una columna, como siempre |
| Móvil horizontal | 915 × 412 | dos paneles |
| Tableta horizontal (Pixel Tablet) | 1280 × 800 | dos paneles |
| Tableta vertical | 800 × 1280 | **una columna** |

La tableta vertical se queda en una columna a propósito: 800 dp no llegan a 840, y con dos paneles el mes se quedaría
en unos 480 dp y el detalle en una tira de 320 dp, peor que la rejilla de 640 dp centrada y una hoja inferior con el
resto de la pantalla para el mes. Una ventana de 1024 × 1366 (iPad grande en vertical) sí tiene dos paneles.

**Panel izquierdo: el mes.** Cabecera del mes con sus flechas, fila de días y rejilla, igual que en el móvil, pero con
toda la altura: la fecha, los tres botones y la tarjeta de hoy se van al panel derecho. Las filas se reparten la altura
(sin pasar de 1,5 veces el ancho de la celda). Una fila nunca baja de lo que hace falta para ver el **horario bajo el
código** al tamaño de texto del usuario (`dayCellHeightWithTime`, como mucho 80 dp): en un móvil horizontal (412 dp de
alto) eso son unos 64 dp por fila y el mes se desplaza un poco en vez de quedarse en códigos sueltos. Al pintar se
conserva esa altura: arrastrar por las casillas pinta; los botones de subir y bajar, fuera de la rejilla, desplazan
el mes por páginas con una fila en común. Así siguen accesibles las seis filas aunque la cabecera ocupe dos líneas.

**Panel derecho.** Ancho = 40 % de la ventana, entre 300 y 440 dp (366 dp en un móvil de 915 dp, tan ancho como un móvil
en vertical, que es para lo que están hechos sus contenidos; 440 dp en una tableta). Un filete `border` de 1 dp lo
separa del mes. A la izquierda del mes, el **raíl de destinos** (ver «Barra de destinos»). Arriba del panel, la
fecha y los botones (compartir, ajustes) y el selector de calendario. Con un día abierto, la cabecera muestra solo su fecha y «Hoy» permite volver; el detalle no repite la fecha. Debajo:
- **Sin día abierto:** la tarjeta de hoy, el consejo del primer uso y **Próximos días**: los 7 días siguientes a hoy en
  una tarjeta con filas compactas (día de la semana y número, ficha de 28 dp con el código, nombre y horario de cada
  turno, «Sin turno» si no hay, un clip si tiene nota; el número en `holiday` si es festivo). Tocar una fila abre ese
  día.
- **Con un día abierto:** el mismo contenido y las mismas acciones que la hoja inferior (turnos, nota, aviso, festivo
  propio, horas extra, saltar alarma, duplicar y borrar), en `DayDetailBody`, que usan la hoja y el panel. En vez del
  asa de la hoja, un botón de cerrar a la derecha del título; cerrar, o el botón atrás del sistema, vuelve a la
  tarjeta de hoy. «Duplicar en otro día» y «Borrar día» también cierran el día, como cerraban la hoja.
- **Modo pintar y modo selección:** su cabecera arriba y su barra de herramientas abajo, **dentro del panel derecho**
  (no a lo ancho de la pantalla): en un móvil horizontal una barra a todo lo ancho se comería media pantalla y dejaría
  el mes en dos filas. Deshacer y rehacer siguen en la barra. El botón «Pintar» flota sobre el panel derecho y el
  área visible del contenido que se desplaza termina 72 dp por encima del borde inferior (alto del botón más margen),
  para que ningún control pase por detrás. «Pintar» se oculta mientras está abierto el teclado, también en el móvil.
  La barra de selección del panel distribuye sus etiquetas visibles en dos filas; con texto grande crece hacia abajo y se desplaza, sin truncar ni reducir las zonas táctiles. Los avisos flotantes en ventanas de al menos 600 dp no superan 560 dp de ancho; con dos paneles se colocan sobre el
  mes, a la izquierda, para dejar libres las barras de selección y pintar. En el móvil vertical mantienen sus márgenes.

**Día abierto en la rejilla.** El día que se ve en el panel lleva un **anillo** de `Sp.selectionRing` (2,5 dp) en el
color de selección (acento en claro, ámbar en oscuro), sin velo ni marca de verificación (eso es de elegir varios días).
Hoy sigue con su anillo fino y su número en negrita. El día abierto se cierra al entrar en pintar o en selección y al
cambiar de calendario.

**Girar el móvil o la tableta** cambia de una columna a dos paneles y al revés (en todos los móviles y tabletas, porque
vertical es una columna y horizontal son dos). El mes visible, el modo pintar con su pincel y el día abierto están en
estado de Riverpod y sobreviven: con un día abierto, de dos paneles a una columna el día vuelve como hoja inferior, y de
una columna a dos paneles la hoja se cierra y el día pasa al panel. La nota que se está escribiendo pasa de un campo al
otro con su texto (se guarda cada vez que cambia la disposición, un paso de deshacer por cada guardado). Una hoja abierta
desde otra pantalla (la agenda) sigue siendo modal.

**Otras pantallas.** Ajustes, resumen, año, agenda, copia de seguridad, importar y exportar, turnos, alarmas, festivos,
calendarios, el asistente de patrón y el primer uso usan `PageBody`, que centra el contenido y lo limita a
`Sp.maxContentWidth` (640 dp): no se estiran de borde a borde. Las hojas (`showAppSheet`) tienen el mismo tope, y los
diálogos de Material no pasan de 560 dp. El primer uso en horizontal (menos de 480 dp de alto) desplaza la cabecera con
el paso y deja «Siguiente» fijo abajo.

## Primer uso: tres caminos (2A, 31-oct-2026)
Opción 2A del lienzo `docs/diseno-propuestas/2026-10-31-propuestas.html` (ID B2 de `docs/propuesta-mejoras.md`). Objetivo:
calendario útil en menos de 60 s sin responder nada que no haga falta.
- **Primera pantalla, «¿Cómo empiezas tu cuadrante?»** (`ChooseStep`): sin barra ni «Siguiente». Arriba a la derecha,
  el idioma («Idioma: Español ›», la misma hoja que Ajustes; se elige aquí porque los nombres de fábrica se fijan en
  él). Título `headline`, una línea de ayuda y **tres tarjetas** `AppCard` con un dibujo en un cuadrado `Disc.badge`
  `surfaceRaised` (radio `Rad.inner`), el nombre en `bodyStrong`, una línea `meta` y el chevron: **Importar mis turnos**
  (el icono de importar en `accentText`), **Usar una rotación** (un ciclo en `ShiftBadge` con color y código, y la
  etiqueta «Si tu turno se repite» en `accentSoft`/`accentText`) y **Pintar a mano** (unos días pintados con su `tint`
  y su `bar`, y el pincel). Debajo, en `meta` centrado, «Después te preguntamos el país…» y el botón de texto
  **Recuperar una copia de seguridad** (abre Ajustes › Copia; si se restaura, el flujo termina en el mes).
- **Cada camino lleva a lo suyo:** importar → «¿Vienes de otra app?» (importar ahora o la copia de LRHSoft) →
  último paso; rotación → catálogo → día de inicio y **turno y día del ciclo** → último paso; a mano → último paso, y
  el mes se abre ya en modo pintar. «Lo pinto a mano» sigue en el catálogo y hace lo mismo sin salir del camino.
- **Último paso, opcional** (`PlaceStep`): «Paso N de M · Opcional» en `meta` seminegrita, «¿Dónde trabajas?» (país,
  comunidad y municipio como antes) y, debajo, «¿A qué te dedicas? Opcional» en `title` con las profesiones del país
  en `ChoicePill` (la elegida con borde `todayRing` y check; tocarla otra vez la quita) y sus horas habituales en una
  línea debajo. «Saltar» o «Continuar» guardan siempre el país (el propuesto o el elegido). Luego «Listo» con el
  resumen y «Ver mi calendario».
- **Barra:** atrás, una raya por pantalla del camino (la actual más larga, nunca solo color; «Paso N de M» para el
  lector de pantalla) y «Saltar». La primera pantalla y «Listo» no llevan número.
- **Fuera de la maqueta, por las reglas:** las profesiones conservan su línea de horas (la del elegido); la fila «Sin
  festivos oficiales» de la maqueta es la opción «Otro país» del selector de país (ya existía); la tarjeta del lugar no
  muestra aún el número de festivos del año.

## Movimiento y tacto
Cambios de estado 200 ms `easeOutCubic`; respeta «reducir movimiento». Vibración ligera (`selectionClick`) por cada
día pintado; ninguna animación infinita. **Cambio de mes**: los días del mes nuevo (cuadrícula o lista) entran con un
fundido desde el 30 % y un desplazamiento del 6 % de su ancho desde el lado del que vienen (la derecha si el mes es
posterior), en 200 ms; la cabecera y la fila del mes no se mueven. Con «reducir movimiento» el cambio es inmediato.

## Asistente de patrón y vista anual
- **Asistente de patrón** (`/patron`, tres pasos con una barra de tres segmentos y «Paso 1 de 3»): tarjetas `surface`
  de radio `Rad.row` con el nombre, el ciclo («28 días») y la secuencia como **fichas pequeñas** (`Disc.s`, `disc` +
  `ink` del turno, el código siempre visible). La elegida lleva el borde `todayRing` y un check, no solo color.
- **Selector de turno y día del ciclo** (mismo componente en el paso 2 del asistente y en «¿Cuándo empiezas?» del
  primer uso, `CycleStartPicker`): la pregunta es **qué turno** tiene ese día, con una píldora `ChoicePill` por turno
  distinto del ciclo (radio `Rad.inputRadius`, el mismo de las fichas de profesión; color y código en un `ShiftBadge`,
  nunca solo color; los del catálogo hablan el idioma de la app). Si ese turno aparece varias veces en el ciclo, debajo
  sale **una píldora por día del turno**, rotulada por su tanda («2.º de 5 · Mañana»; «Tanda 2 · 1.º de 2 · Libre,
  después de Noche» cuando el turno tiene varias tandas separadas, nombradas por el turno del día anterior). Una tanda
  sólo se rotula «después de X» cuando el día inmediatamente anterior tiene otro turno; si está vacío, se cae esa parte.
  La cuadrícula numerada de todo el ciclo sigue detrás de «Ver el ciclo completo» (fichas `Disc.m`, con el número del
  día debajo) para quien la prefiera. Bajo el selector, **«Así quedará»**: dos meses con la misma `DayCell` de la
  pantalla del mes que se actualizan en vivo; el primer uso lo enseña con este mismo componente y el asistente lo deja
  para su paso 3, para no pintarlo dos veces. El texto bajo el selector resume «Ese día te toca: …».
- **Vista anual** (`/ano`): cada día es un cuadrado con la `bar` del turno (varios turnos: franjas verticales),
  `surfaceMuted` si no hay turno, un punto `holiday` en los festivos y un anillo `todayRing` en hoy; 3 columnas en
  móvil (4 desde 600 dp). Cada mes se lee en voz alta como sus recuentos («Octubre 2026: 8 Noche, 5 Libre»). La
  leyenda usa cuadrados de 14 dp (`Rad.swatch`) con código, nombre y días del año.

## Icono y pantalla de arranque
Todo sale de un solo guion, `tool/icon/make_icon.py` (Python + Pillow), con los colores y proporciones de «Icono de
la app» arriba: cuadrícula 3×3 de ≈ 60 % del lienzo, separación del 6 % de la cuadrícula, radio del 4 %. Si cambia el
diseño, se cambian las constantes del guion y se regenera; los PNG no se retocan a mano.

| Archivo (`app/assets/icon/`) | Qué es |
|---|---|
| `icon.png` | 1024 px, a sangre y **sin alfa**. Origen de los mipmaps de Android (icono clásico) y del `AppIcon` de iOS (`remove_alpha_ios`). |
| `foreground.png` | Capa frontal del icono adaptable de Android: transparente, solo la cuadrícula. `flutter_launcher_icons` la mete con un margen del 16 % por lado, así que el PNG va dibujado más grande y, ya colocada, la cuadrícula mide el 46 % de los 108 dp y cabe en la zona segura (círculo de 66 dp; el guion lo comprueba). |
| `monochrome.png` | Icono tematizado de Android 13: blanco sobre transparente, fila central opaca y el resto con menos alfa (opción 8.2A, 31-oct: comprobado, va en `<monochrome>` de `mipmap-anydpi-v26/ic_launcher.xml`). Misma geometría que la capa frontal. |
| `splash.png` | Pantalla de arranque: solo la cuadrícula (520 px) en un lienzo transparente de 1152 px; cabe en el círculo de 192 dp de Android 12. Sin texto ni marca. |

El fondo del icono adaptable es `#141418` (en `values/colors.xml`). Las vistas previas a 48 y 96 px, con la máscara
cuadrada redondeada de iOS y la circular de Android, están en `tool/icon/preview/` (`icon_*`, `adaptive_*`,
`monochrome_*`); se regeneran con el guion.

**Pantalla de arranque**: fondo claro `#F2F2F6` y oscuro `#0A0A0D`, que son `background` del tema
(`app_colors.dart`), y la misma imagen en las dos. Así la primera imagen de Flutter (`scaffoldBackgroundColor`) tiene
el mismo fondo que el arranque nativo y no hay salto. En Android 12+ la imagen va en el círculo del sistema con el
mismo color de fondo, así que el círculo no se nota. La lectura de la base de datos y las preferencias se hace antes de
`runApp`, de modo que el arranque nativo se queda hasta que sale la pantalla real: no hay pantalla de carga de Flutter
en medio. Si la persona fuerza un tema distinto al del sistema, el arranque sigue el del sistema (una limitación de las
pantallas nativas).

**Regenerar** (desde la raíz del repositorio):
1. `python tool/icon/make_icon.py`: los cuatro PNG y las vistas previas.
2. `bash tool/icon/apply_icons.sh`: `dart run flutter_launcher_icons` y, después, deshace lo que el plugin estropea en
   iOS (reescribe `Contents.json` con tamaños de iOS 6 y toca un ajuste de compilación de Xcode).
3. `bash tool/icon/apply_splash.sh`: `dart run flutter_native_splash:create` y restaura `ios/Runner/Info.plist`, que el
   plugin reindenta entero.

Las dos herramientas están fijadas en `app/pubspec.yaml` (`flutter_launcher_icons` 0.14.4, `flutter_native_splash`
2.4.8) y su configuración son las secciones del mismo nombre de ese archivo. Lo generado va al repositorio (mipmaps,
XML del icono adaptable, `AppIcon.appiconset`, recursos de arranque de Android y `LaunchScreen` de iOS).
