# Zorin con aspecto y funciones de ChromeOS

Scripts para convertir una instalación de **Zorin OS Core (GNOME)** o **MX Linux (XFCE)** en un escritorio centrado en Chrome, con apps web como ventanas propias, OneDrive montado como carpeta, cuenta de Google integrada (solo en Zorin) y ajustes de rendimiento para equipos modestos.

Pensado para una **Philco N14P4020** (Celeron de 2 núcleos, 4 GB de RAM, SSD de 128 GB) que venía con Windows 11 y corría ChromeOS Flex con problemas de sonido y WiFi. Zorin funciona en cualquier Ubuntu con GNOME de 64 bits; MX funciona en MX Linux con XFCE (basado en Debian).

## Qué hay en el repositorio

| Ruta | Contenido |
|---|---|
| `panel/index.html` | Panel web donde se elige el sistema (Zorin o MX), se eligen los módulos y se copia el script. Abrilo en cualquier navegador. |
| `scripts/setup-recomendado.sh` | Combinación recomendada para Zorin, lista para usar. |
| `scripts/setup-minimo.sh` | Solo Chrome, zram, región y actualizaciones automáticas (Zorin). |
| `scripts/setup-completo.sh` | Todos los módulos, incluidos los drivers (Zorin). |
| `scripts/setup-recomendado-mx.sh`, `setup-minimo-mx.sh`, `setup-completo-mx.sh` | Las mismas combinaciones para MX Linux (XFCE). |
| `scripts/diagnostico-hardware.sh` | Reúne datos de WiFi, audio y kernel para decidir qué drivers hacen falta. |
| `tools/generate.js` | Genera un script a medida desde la terminal (necesita Node.js). |
| `tools/build.sh` | Regenera `scripts/` a partir del panel. |
| `tools/test.sh` | Revisa la sintaxis, corre cada script en modo de prueba y prueba el análisis del diagnóstico. |
| `tools/test-diag.js` | Pruebas del análisis del diagnóstico con salidas inventadas (las corre `test.sh`). |
| `docs/` | Notas del equipo y pendientes. |

## Cómo se usa

1. **Pendrive:** descargá la ISO de Zorin OS Core desde zorin.com y grabala con balenaEtcher o Rufus.
2. **Probar en vivo:** arrancá desde el pendrive sin instalar. Probá sonido y WiFi y corrá el diagnóstico:
   ```bash
   bash scripts/diagnostico-hardware.sh
   ```
   Si el WiFi no anda, compartí internet por USB desde el celular. El archivo queda en `~/diagnostico-hardware.txt`.

   Para saber qué drivers activar, abrí `panel/index.html`, andá a la pestaña **Diagnóstico** y cargá ese archivo (o pegá su contenido). El panel se lee en tu navegador, no sube nada, te resume lo que detectó y, si confirmás, marca los módulos de drivers que corresponden. También se puede desde la terminal: `node tools/generate.js --analyze diagnostico-hardware.txt`.
3. **Instalar Zorin.** Esto borra el disco, así que hacé copia de lo que quieras conservar.
4. **Primer arranque:** conectate a internet y traé este repositorio.
   ```bash
   sudo apt-get install -y git
   git clone <URL-del-repositorio>
   cd zorin-chromeos
   ```
5. **Probar sin cambiar nada:**
   ```bash
   DRY_RUN=1 bash scripts/setup-recomendado.sh
   ```
6. **Aplicar.** Corrélo con tu usuario desde la terminal del escritorio, no como root. Los ajustes de GNOME necesitan la sesión gráfica.
   ```bash
   bash scripts/setup-recomendado.sh
   ```
7. **Reiniciar** y seguir los pasos manuales que el script imprime al final y guarda en `~/PASOS-MANUALES.txt`.

## Armar un script a medida

Con el panel: abrí `panel/index.html`, elegí el sistema y los módulos, y copiá o descargá el script.

Desde la terminal:

```bash
node tools/generate.js --list                                  # módulos y sistemas disponibles
node tools/generate.js --preset rec --out setup.sh             # un preset para Zorin
node tools/generate.js --preset rec --target mx --out setup.sh # el mismo preset para MX Linux
```

## Módulos

**Navegador y apps:** Google Chrome oficial (repositorio de Google), Chrome al iniciar sesión, lanzadores de apps web (Word, Excel, PowerPoint, OneDrive, Outlook, Gmail, Drive, Calendar, Docs, Sheets, Slides) y OneDrive como carpeta con onedriver.

**Idioma y teclado:** español de Argentina, zona horaria de Buenos Aires y distribución de teclado a elección.

**Cuentas de Google:** Cuentas en línea de GNOME con Drive en el explorador, y opcionalmente Calendario, Contactos y Geary.

**Aspecto ChromeOS y atajos:** barra abajo con el menú de apps a la izquierda, las apps al centro y el reloj y el menú de sistema a la derecha, fondo de pantalla propio inspirado en ChromeOS (claro y oscuro), letra Roboto, íconos Papirus, tema claro u oscuro, desplazamiento natural, clic con toque, atajos tipo ChromeOS (captura con Ctrl+Shift+F5, ventanas a izquierda y derecha con Alt+[ y Alt+]) y apps ancladas.

**Rendimiento:** zram, sin animaciones, sin indexación de archivos, servicios innecesarios apagados, actualizaciones automáticas (con reinicio nocturno opcional).

**Sonido y WiFi:** ahorro de energía del WiFi desactivado, reinstalación de firmware, drivers Realtek 8821CE y Broadcom (solo si el chip existe), kernel HWE y driver de audio clásico de Intel.

## Qué está probado y qué no

- Cada script pasa `bash -n` y corre completo en modo de prueba (`DRY_RUN=1`). Eso se verifica con `tools/test.sh`.
- El análisis del diagnóstico se probó con salidas inventadas y con el diagnóstico de otra PC, no con el de la Philco. Sus reglas se apoyan en IDs de PCI y en mensajes del kernel (WiFi Realtek 8821CE y Broadcom, firmware que no carga, audio Intel sin tarjetas, placas sin driver). Por eso el panel muestra el resumen y pide confirmación antes de marcar módulos.
- El modo de prueba **no** confirma que cada paquete o repositorio exista en tu versión de Zorin o de MX. Esos puntos se probaron solo por lectura de documentación, no en una Zorin ni en una MX reales.
- La variante de MX no se probó en una MX real. Las claves de `xfconf` (teclado, atajos de xfwm4, efecto de composición) y los paquetes de Debian (`zram-tools`, `xfce4-screenshooter`) salieron de la documentación. Hay que verificarlos en la primera instalación.
- Los ajustes de GNOME se aplican solo si la clave existe en esa versión. Si no, el script avisa y sigue.
- La barra estilo ChromeOS en Zorin ajusta la barra de Zorin (`zorin-taskbar`, derivada de dash-to-panel). Los nombres de las claves salen de dash-to-panel y no se verificaron en una Zorin real. Si una clave no existe, el script avisa y deja el paso manual en Zorin Appearance.
- Los fondos oficiales de ChromeOS son de Google y no se incluyen. El script instala un fondo propio con colores parecidos.
- Los lanzadores de apps web abren Chrome con `--app`. Para íconos propios, instalá cada una desde Chrome.

## Diferencias con MX Linux (XFCE)

Los módulos que dependen de GNOME no aparecen en el panel cuando elegís MX: cuentas en línea y Drive en el explorador, Calendario, Contactos y Correo de GNOME, el kernel HWE de Ubuntu, el modo claro u oscuro y la indexación de Tracker. Las apps web de Gmail, Drive y Calendar siguen disponibles como lanzadores.

Lo que cambia en XFCE:

- **Ajustes:** se aplican con `xfconf-query` (íconos Papirus, teclado, efecto de composición de la ventana).
- **Touchpad y desplazamiento:** se guardan como configuración de Xorg en `/etc/X11/xorg.conf.d/`. Hacen falta cerrar sesión para que tomen efecto.
- **Atajos:** la captura usa `xfce4-screenshooter` y el acomodo de ventanas usa los atajos de xfwm4.
- **Zram:** usa el paquete `zram-tools` en lugar de `systemd-zram-generator`.
- **Barra de lanzadores:** no se ancla por script. El script deja los pasos a mano.
- **Barra estilo ChromeOS:** la barra de MX pasa a horizontal, abajo y a lo ancho, y Super abre el menú Whisker. Centrar las apps requiere agregar separadores a mano (el script deja los pasos). XFCE no tiene un menú rápido como el de ChromeOS; a la derecha quedan la bandeja y el reloj.
- **Drivers:** Realtek 8821CE y Broadcom no siempre están en los repositorios de Debian. Si la instalación falla, el script avisa y deja los pasos a mano sin cortarse.

## No incluido

OnlyOffice, Waydroid (apps Android, pesado con 4 GB) y Zorin Lite.

## Desarrollo

La fuente de verdad es `panel/index.html`: los módulos de bash están dentro de etiquetas `<script type="text/plain" data-mod="...">` y el generador en `<script id="gen">`. Después de editar:

```bash
bash tools/build.sh
bash tools/test.sh
```
