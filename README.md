# Zorin con aspecto y funciones de ChromeOS

Scripts para convertir una instalación de **Zorin OS Core (GNOME)** en un escritorio centrado en Chrome, con apps web como ventanas propias, OneDrive montado como carpeta, cuenta de Google integrada y ajustes de rendimiento para equipos modestos.

Pensado para una **Philco N14P4020** (Celeron de 2 núcleos, 4 GB de RAM, SSD de 128 GB) que venía con Windows 11 y corría ChromeOS Flex con problemas de sonido y WiFi. Funciona en cualquier Ubuntu con GNOME de 64 bits.

## Qué hay en el repositorio

| Ruta | Contenido |
|---|---|
| `panel/index.html` | Panel web donde se eligen los módulos y se copia el script. Abrilo en cualquier navegador. |
| `scripts/setup-recomendado.sh` | Combinación recomendada, lista para usar. |
| `scripts/setup-minimo.sh` | Solo Chrome, zram, región y actualizaciones automáticas. |
| `scripts/setup-completo.sh` | Todos los módulos, incluidos los drivers. |
| `scripts/diagnostico-hardware.sh` | Reúne datos de WiFi, audio y kernel para decidir qué drivers hacen falta. |
| `tools/generate.js` | Genera un script a medida desde la terminal (necesita Node.js). |
| `tools/build.sh` | Regenera `scripts/` a partir del panel. |
| `tools/test.sh` | Revisa la sintaxis y corre cada script en modo de prueba. |
| `docs/` | Notas del equipo y pendientes. |

## Cómo se usa

1. **Pendrive:** descargá la ISO de Zorin OS Core desde zorin.com y grabala con balenaEtcher o Rufus.
2. **Probar en vivo:** arrancá desde el pendrive sin instalar. Probá sonido y WiFi y corrá el diagnóstico:
   ```bash
   bash scripts/diagnostico-hardware.sh
   ```
   Si el WiFi no anda, compartí internet por USB desde el celular. El archivo queda en `~/diagnostico-hardware.txt`.
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

Con el panel: abrí `panel/index.html`, elegí módulos, copiá el script. El panel también muestra un código de configuración (empieza con `zcos1:`).

Desde la terminal:

```bash
node tools/generate.js --list                                  # módulos disponibles
node tools/generate.js --preset rec --out setup.sh             # un preset
node tools/generate.js --code "zcos1:chrome,zram,updates|pwas=word,excel|scheme=system|keymap=latam" --out setup.sh
```

## Módulos

**Navegador y apps:** Google Chrome oficial (repositorio de Google), Chrome al iniciar sesión, lanzadores de apps web (Word, Excel, PowerPoint, OneDrive, Outlook, Gmail, Drive, Calendar, Docs, Sheets, Slides) y OneDrive como carpeta con onedriver.

**Idioma y teclado:** español de Argentina, zona horaria de Buenos Aires y distribución de teclado a elección.

**Cuentas de Google:** Cuentas en línea de GNOME con Drive en el explorador, y opcionalmente Calendario, Contactos y Geary.

**Aspecto y atajos:** íconos Papirus, tema claro u oscuro, desplazamiento natural, clic con toque, atajos tipo ChromeOS (captura con Ctrl+Shift+F5, ventanas a izquierda y derecha con Alt+[ y Alt+]) y apps ancladas.

**Rendimiento:** zram, sin animaciones, sin indexación de archivos, servicios innecesarios apagados, actualizaciones automáticas (con reinicio nocturno opcional).

**Sonido y WiFi:** ahorro de energía del WiFi desactivado, reinstalación de firmware, drivers Realtek 8821CE y Broadcom (solo si el chip existe), kernel HWE y driver de audio clásico de Intel.

## Qué está probado y qué no

- Cada script pasa `bash -n` y corre completo en modo de prueba (`DRY_RUN=1`). Eso se verifica con `tools/test.sh`.
- El modo de prueba **no** confirma que cada paquete o repositorio exista en tu versión de Zorin. Esos puntos se probaron solo por lectura de documentación, no en una Zorin real.
- Los ajustes de GNOME se aplican solo si la clave existe en esa versión. Si no, el script avisa y sigue.
- La barra inferior centrada no se puede fijar con seguridad por script. Se elige a mano en Zorin Appearance.
- Los lanzadores de apps web abren Chrome con `--app`. Para íconos propios, instalá cada una desde Chrome.

## No incluido

OnlyOffice, Waydroid (apps Android, pesado con 4 GB) y MX Linux o Zorin Lite (usan XFCE y los ajustes de GNOME no se aplican).

## Desarrollo

La fuente de verdad es `panel/index.html`: los módulos de bash están dentro de etiquetas `<script type="text/plain" data-mod="...">` y el generador en `<script id="gen">`. Después de editar:

```bash
bash tools/build.sh
bash tools/test.sh
```
