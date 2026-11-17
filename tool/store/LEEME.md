# Gráficos y capturas del README y las tiendas

Como en Ley al Blanco, los tests de `app/test/store/` dibujan las composiciones
alrededor de **pantallas reales de Turnly**. No necesitan emulador, dispositivo,
red, una base de datos del usuario ni herramientas de retoque.

## Regenerar los README

Flutter **3.47.7**, desde `app/`:

```bash
TZ=Europe/Madrid flutter test --dart-define=GENERATE_STORE=true test/store
```

PowerShell:

```powershell
Get-TimeZone # En este equipo: Romance Standard Time (Madrid)
Remove-Item Env:TZ -ErrorAction SilentlyContinue
flutter test --dart-define=GENERATE_STORE=true test/store
```

Sin `GENERATE_STORE=true`, los tests quedan omitidos: `flutter test` normal no
escribe PNG. La etiqueta `store` permite seleccionarlos. La fuente Roboto se
carga desde el SDK de Flutter (no se descarga ni se incluye en la app). Si no
está disponible, la generación falla en vez de usar la fuente cuadrada de tests.
En Windows se usa la zona del sistema: no definas `TZ=Europe/Madrid`, porque
su runtime no interpreta ese identificador IANA como Linux.

Salidas versionadas en **`docs/readme/<idioma>/`** para los cinco idiomas de la app
(`es`, `ca`, `gl`, `eu`, `en`), trece por idioma. Las capturas son **pantallas en bruto
del móvil, como las de Ink Lab**: 1080 × 2400 (412 dp de ancho a 1080/412), tema claro,
con barra de estado de Android (10:00, wifi, 3G, cobertura y batería llenas) y píldora
del gesto abajo, **sin titular, sin marco y sin tinte de fondo**. `07-mes-oscuro.png` va en oscuro en el README, y cada
captura tiene además su gemela oscura `NN-nombre-oscuro.png` para la web. Las dibuja el destino `github` (el predeterminado de `STORE_TARGET`):

| Archivo | Tamaño | Contenido |
|---|---|---|
| `header.png` | 1024 × 500 | Cabecera, reutilizable como gráfico destacado de Play |
| `icon-512.png` | 512 × 512 | Icono real de `app/assets/icon/icon.png` |
| `01-mes.png` | 1080 × 2400 | Cuadrícula del mes, tema claro |
| `02-lista.png` | 1080 × 2400 | Lista del mismo mes |
| `03-pintar.png` | 1080 × 2400 | Pintar con la paleta |
| `04-rotaciones.png` | 1080 × 2400 | Asistente 0.11.0, paso 1: constructor de 63 días · 9 semanas, tres bloques cerrados de 21 días (Mañana, Noche, Tarde) y paleta; texto a escala 1,0. La tira empieza por el día 1 en tablet |
| `05-horas.png` | 1080 × 2400 | Resumen de horas |
| `06-festivos.png` | 1080 × 2400 | Festivos: país, comunidad y municipio |
| `07-mes-oscuro.png` | 1080 × 2400 | Cuadrícula del mes, tema oscuro |
| `08-vacaciones.png` | 1080 × 2400 | Vacaciones y permisos: saldos del año |
| `09-cambios.png` | 1080 × 2400 | Libro de cambios: balance con los compañeros |
| `10-primer-uso.png` | 1080 × 2400 | Primer uso: los tres caminos (importar, rotación, pintar) |
| `11-widgets.png` | 1080 × 2400 | Galería «Añadir widget» con los turnos de la muestra |
| `NN-nombre-oscuro.png` | 1080 × 2400 | La misma escena de cada captura (01–06 y 08–11) en tema oscuro, para la web en oscuro |

En las pantallas largas (`05-horas`, `06-festivos`) el test desplaza la lista lo mínimo
para que ningún texto quede bajo la píldora del gesto. PNG RGB de 8 bits, opacos y sin metadatos. El escritor comprueba las dimensiones
decodificando el PNG antes de guardarlo. La cabecera y el icono los genera
`readme_graphics_test.dart`; las escenas, `store_screenshots_test.dart`.

## Muestra reproducible

Reloj fijo: **24-dic-2026, 18:00**, por `clockProvider`. Base Drift en memoria,
nueva en cada escena. Calendario «Demo» y plantillas de turno del ARB del idioma:
Mañana 1–4, Tarde 10–11, Noche 23–25 y Saliente 26; el resto Libre. Madrid,
comunidad y municipio, con los festivos del paquete real de la app.

El test comprueba con el motor **9 turnos, 72 h, 24 h nocturnas y 8 h festivas**
antes de guardar cada imagen. Sin datos personales, salud ni importes ficticios.
El asistente usa otro calendario vacío, «Industria» / «Industry», sin las
excepciones de «Demo». Su ciclo tiene tres bloques de 21 días: Mañana, Noche,
Tarde, con las mismas horas que el resto de escenas. El paso 1 muestra los
tres bloques cerrados, cada uno con color, código, hora y duración, a escala
de texto 1,0 tanto en móvil (412 dp) como en tablet. El test desplaza el
constructor hasta dejar la cabecera «63 días · 9 semanas» y los tres bloques
visibles sobre la paleta fija, sin cortar textos ni celdas en los bordes.
En móvil se priorizan cabecera, bloques y paleta: la paleta actual reserva dos
filas y no deja espacio para una fila completa de la tira. En tablet se ve
también el principio de la tira por el día 1. Mostrarlo en móvil requiere el
ajuste del constructor de la rama `fix/constructor-horizontal`; este montaje
no modifica el código de la app.
En `shots.json`, esta escena usa `fit: true`: Play muestra el teléfono entero
para conservar también la paleta y el botón «Siguiente».
Pintar y la vista previa no se guardan: no alteran el resumen de las otras escenas.
La sexta escena usa Festivos; las de «Vacaciones y permisos» y «Libro de cambios»
(08 y 09, solo del README) usan esas pantallas reales, con saldos y cambios de ejemplo,
y ninguna baja médica. No se simula un escritorio ni un widget nativo.

## Tamaños de tienda

Los mismos tests pueden componer las seis escenas (con titular y marco; `07-mes-oscuro`,
`08-vacaciones` y `09-cambios` son solo del README) para cada tienda, sin estirar
ni cortar la pantalla. Desde `app/`:

```bash
TZ=Europe/Madrid flutter test --dart-define=GENERATE_STORE=true --dart-define=STORE_TARGET=play test/store/store_screenshots_test.dart
TZ=Europe/Madrid flutter test --dart-define=GENERATE_STORE=true --dart-define=STORE_TARGET=ios69 test/store/store_screenshots_test.dart
TZ=Europe/Madrid flutter test --dart-define=GENERATE_STORE=true --dart-define=STORE_TARGET=ios65 test/store/store_screenshots_test.dart
TZ=Europe/Madrid flutter test --dart-define=GENERATE_STORE=true --dart-define=STORE_TARGET=ios63 test/store/store_screenshots_test.dart
```

| Target | Lienzo | Salida regenerable |
|---|---|---|
| `play` | 1080 × 1920 | `app/build/store/play/{es,ca,gl,eu,en}/` |
| `ios69` | 1320 × 2868 | `app/build/store/ios69/{es,ca,gl,eu,en}/` |
| `ios65` | 1242 × 2688 | `app/build/store/ios65/{es,ca,gl,eu,en}/` |
| `ios63` | 1206 × 2622 | `app/build/store/ios63/{es,ca,gl,eu,en}/` (**obligatorio** en App Store Connect: «iPhone with Dynamic Island, medium display», comprobado el 28-oct-2026) |
| `tablet` | 1600 × 2560 | `docs/store/tablet/{es,ca,gl,eu,en}/`: pantallas en bruto de una tablet Android en vertical (800 dp, clase Redmi Pad 2 Pro). `store_shots.py docs/store/shots.json` las enmarca en `docs/store/<idioma>/play-tablet7/` (1350 × 2400) y `play-tablet10/` (1800 × 3200) para Play |

Para actualizar Android en Windows, desde `app/`, sin definir `TZ`:

```bash
sh ~/.agents/scripts/heavy.sh flutter test --dart-define=GENERATE_STORE=true --dart-define=STORE_TARGET=github test/store
sh ~/.agents/scripts/heavy.sh flutter test --dart-define=GENERATE_STORE=true --dart-define=STORE_TARGET=play test/store/store_screenshots_test.dart
sh ~/.agents/scripts/heavy.sh flutter test --dart-define=GENERATE_STORE=true --dart-define=STORE_TARGET=tablet test/store/store_screenshots_test.dart
```

Las composiciones finales de Play salen de los PNG en bruto de GitHub y tablet,
no de `app/build/store/play/`. Desde la raíz, usa el generador de la skill
`readme-app`, limitando las tiendas a Android para no regenerar iOS:

```powershell
$androidShots = @'
import importlib.util
import sys
from pathlib import Path
sys.dont_write_bytecode = True
script = Path.home() / '.agents/skills/readme-app/scripts/store_shots.py'
spec = importlib.util.spec_from_file_location('store_shots', script)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
module.STORES = {key: value for key, value in module.STORES.items() if key.startswith('play')}
module.main('docs/store/shots.json', 'fastlane/metadata')
'@
python -c $androidShots
```

Necesita Pillow y la fuente Inter de la skill, sin descargas. Escribe
`docs/store/<idioma>/{play,play-tablet7,play-tablet10}/` y copias numeradas sin
huecos en `fastlane/metadata/android/<locale>/images/{phoneScreenshots,sevenInchScreenshots,tenInchScreenshots}/`.
La rotación queda como `03-rotaciones.png` en Fastlane, porque la selección de
tienda omite `02-lista.png`. Actualiza también `shots-manifest.json` con los
sha256; las copias de Fastlane y el manifiesto están ignorados por Git.
Compara los PNG con los originales y conserva solo los cambios de la escena
que estés actualizando. Revisa visualmente todas sus variantes antes de subirlas.

El target iOS selecciona controles Flutter de iOS; estos renders **no sustituyen
la validación del build de iPhone** ni las capturas de widgets nativos. Comprueba
los tamaños aceptados en cada consola y revisa visualmente cada PNG antes de
subirlo. Este generador entrega seis escenas en los cinco idiomas; el guion de ocho
capturas de `docs/tienda/capturas.md` sigue siendo otra entrega.

Para validar sin escribir imágenes: `flutter analyze` y
`TZ=Europe/Madrid flutter test`. No se necesitan `flutter run`, `adb` ni pruebas
de integración en dispositivos.
