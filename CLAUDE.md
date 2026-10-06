# CLAUDE.md

Panel web que genera un script de bash para convertir Zorin OS Core (GNOME) o MX Linux (XFCE) en un escritorio con aspecto y funciones de ChromeOS. Pensado para una Philco N14P4020 (Celeron de 2 núcleos, 4 GB de RAM, SSD de 128 GB). El README tiene la explicación para usuarios; este archivo es para quien modifica el repo.

## Idioma

Todo está en español rioplatense con voseo: README, docs, comentarios, textos del panel y mensajes de los scripts (`say`, `warn`, `manual`). Mantenelo así en lo que agregues.

## Fuente de verdad

`panel/index.html` es la única fuente. Todo lo demás se deriva de él:

- `scripts/*.sh` son **generados**. No los edites a mano: se pisan con `tools/build.sh`.
- Los módulos de bash están dentro de `<script type="text/plain" data-mod="NOMBRE">` (datos, no se ejecutan en la página).
- El generador es JS puro dentro de `<script id="gen">` (`PWAS`, `ORDER`, `SCHEMES`, `KEYMAPS`, `ZORIN_ONLY`, `TARGETS`, `build()`). `tools/generate.js` lo extrae del HTML con regex y lo evalúa con `new Function`, así que el panel y la CLI usan exactamente el mismo código. Por eso el bloque `gen` no puede depender del DOM ni usar `import`/`require`.
- La interfaz es el último `<script>` (IIFE con `GROUPS`, estado, render, copiar y descargar).

## Comandos

```bash
bash tools/build.sh          # regenera scripts/ desde el panel (6 setups + diagnóstico)
bash tools/test.sh           # sintaxis (bash -n), dry-run de cada setup y chequeo de que scripts/ está al día
node tools/generate.js --list
node tools/generate.js --preset rec|min|all [--target zorin|mx] [--out archivo]
node tools/generate.js --diag
DRY_RUN=1 bash scripts/setup-recomendado.sh   # muestra qué haría, sin cambiar nada
```

Hace falta Node.js (no hay `package.json` ni dependencias). Después de editar el panel corré siempre `build.sh` y luego `test.sh`; `test.sh` falla con `DESACTUALIZADO` si `scripts/` no coincide con lo que genera el panel.

## Cómo se arma un script

`build(state, mods)` concatena: `header`, `helpers`, los módulos elegidos (en el orden de `ORDER`), `footer` y un `main()` que llama a `mod_base` y a cada `mod_<id>`. Antes reemplaza los marcadores `@@NOMBRE@@` (`TARGET`, `TARGETNAME`, `OSCHECK`, `KEYMAPLINE`, `PWALIST`, `SCHEME`, `FAVS`, `REBOOTLINE`, `MODULES`). Un marcador que no existe se reemplaza por vacío sin avisar.

Reglas del generador:

- Si se eligen `pwas` o `chrome_autostart` sin `chrome`, se agrega `chrome` solo.
- Con `target=mx` se descartan los ids de `ZORIN_ONLY`.
- `updates_reboot` es una opción de `updates` (la lee `REBOOTLINE`), no un módulo: no está en `ORDER` ni tiene bloque `data-mod`.
- `diag` es un script aparte (diagnóstico de hardware), no entra en `build()`.

## Convenciones de los módulos bash

- Cada módulo define una función `mod_<id>` que anuncia lo que hace con `say "..."` (en `mod_perf_anim` el `say` va dentro de cada rama por sistema).
- Usá los helpers de `helpers`: `run` (ejecuta o, en dry-run, solo imprime), `sh_c` (para cadenas con pipes), `put DEST [sudo]` (escribe stdin), `gs ESQUEMA CLAVE VALOR` (gsettings solo si la clave existe), `xfset CANAL PROP TIPO VALOR` (xfconf), `warn`, `manual "..."` (paso manual que se imprime al final y se guarda en `~/PASOS-MANUALES.txt`) y `NEEDS_REBOOT=1`.
- No ejecutes nada que cambie el sistema sin pasar por `run`, `sh_c`, `put`, `gs` o `xfset`; si no, `DRY_RUN=1` deja de ser inocuo.
- Cuando algo depende del sistema, ramificá con `if [ "$TARGET" = mx ]`.
- Si un ajuste puede no existir en otra versión, que avise con `warn` y siga; el script no debe cortarse por eso (el script usa `set -euo pipefail`).
- Fuera de `DRY_RUN`, el script se niega a correr como root o en otra arquitectura que no sea x86_64, y comprueba el sistema con `OSCHECK`; lo hace `helpers`.

## Agregar o cambiar un módulo

Las listas están duplicadas y hay que mantenerlas a mano en sincronía:

1. Bloque `<script type="text/plain" data-mod="id">` con `mod_id()`.
2. `ORDER` en el bloque `gen` del panel (define el orden de ejecución).
3. `GROUPS` en la interfaz: nombre, descripción, `desc`/`dmx` (texto para Zorin y para MX) y la marca `p` (`r` = recomendado, `m` = mínimo).
4. `REC`, `MIN` y `ALL` en `tools/generate.js`. El propio archivo avisa que `REC` y `MIN` deben coincidir con las marcas `p` del panel; nada lo verifica automáticamente.
5. `ZORIN_ONLY` si solo aplica a GNOME.
6. Si agregás un preset o un script nuevo: `tools/build.sh` y las listas de nombres de `tools/test.sh`.

## Cosas a tener en cuenta

- `generate.js` todavía acepta `--code "zcos1:..."`, pero el panel ya no genera esos códigos (el último commit quitó el código de configuración) y el README no lo documenta. Es un resto, no una función activa.
- El panel guarda el estado en `localStorage` (clave `zcos-panel-v1`). Si cambia la forma del estado, subí la versión de la clave.
- El panel también está pensado para publicarse como artifact de claude.ai: ahí usa `window.claude.use('downloads')` y descarga `.txt` en vez de `.sh`. Abierto como archivo local descarga `.sh` con un blob.
- El header de los scripts menciona la Philco N14P4020, y los defaults asumen 4 GB de RAM (zram, sin animaciones, sin indexación).
- Los fondos oficiales de ChromeOS son de Google y no se incluyen: el script instala uno propio.

## Qué está verificado

`test.sh` solo garantiza sintaxis, que el dry-run termine y que `scripts/` esté al día. **No** prueba que los paquetes, repositorios, claves de `gsettings` o de `xfconf` existan en una Zorin o una MX reales. La variante MX (xfconf, atajos de xfwm4, `zram-tools`) y la barra de Zorin (`org.gnome.shell.extensions.zorin-taskbar`) se escribieron a partir de documentación, sin probarlas. No presentes esos pasos como probados. Los pendientes están en `docs/notas-equipo.md`.

## Git

Rama `main`. El historial usa mensajes de commit en español. Si cambiaste el panel, incluí en el mismo commit los `scripts/` regenerados.
