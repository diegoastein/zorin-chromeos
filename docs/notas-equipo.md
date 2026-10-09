# Notas del equipo

## Philco N14P4020

Según las fichas de venta de Frávega y Megatone: Celeron de 2 núcleos, 4 GB de RAM, SSD de 128 GB, pantalla de 14.1" TN sin tacto, 2 puertos USB y 1 HDMI. Salía con Windows 11 Home.

No se pudo confirmar desde las fichas el chip de WiFi ni el de audio. Por eso el repositorio incluye el diagnóstico y los drivers solo se instalan si el script detecta el chip.

## Problemas conocidos en ChromeOS Flex

Sonido y conectividad. El diagnóstico (`scripts/diagnostico-hardware.sh`) tiene que correrse desde un pendrive de Zorin en modo de prueba para ver qué chip hay y si funciona con el kernel de Zorin.

## Audio (verificado el 2026-10-09)

La Philco usa el driver SOF (`sof-audio-pci-intel-apl`) con el códec ES8336 (tarjeta `sof-essx8336`). El driver clásico de Intel (HDA) no sirve acá.

Síntoma: después de probar el micrófono en Google Meet solo aparecía la salida "Headphones" y los parlantes no sonaban. Causa: la detección del conector marcaba auriculares conectados (`Headphone Jack = on`) con el parlante apagado (`Speaker Switch = off`). Con PipeWire apagado y `Speaker Switch` en `on` el parlante sonaba, así que el hardware está bien.

Arreglo: `options snd_soc_sof_es8336 quirk=64` en `/etc/modprobe.d/99-philco-audio.conf` (bit `JD_INVERTED`) y reiniciar. Confirmado: `dmesg` muestra `quirk mask 0x40` y el sonido funciona. Lo aplica el módulo `drv_audio_jd` del panel.

## Decisiones tomadas

- Base: Zorin OS Core (GNOME), por la integración de Cuentas en línea. Con 4 GB se compensa con zram.
- Chrome oficial, no Chromium.
- OneDrive con onedriver (descarga bajo demanda, cuida el SSD).
- OnlyOffice queda afuera por ahora.

## Pendientes

- Correr el diagnóstico en la notebook y decidir drivers según el resultado.
- Probar el script recomendado en una instalación real y ajustar lo que falle.
- Variante para MX Linux (XFCE): el panel y los scripts `*-mx.sh` ya están. Falta probarla en una MX real, sobre todo las claves de xfconf, los atajos de xfwm4 y el paquete de zram. Si 4 GB con GNOME se queda corto, MX es el plan B.
- Barra estilo ChromeOS: verificar en Zorin que existan las claves de `org.gnome.shell.extensions.zorin-taskbar` (`panel-element-positions`, `panel-position` o `panel-positions`) y que el menú de Zorin quede a la izquierda. En MX, verificar el valor `p=10` de la posición del panel y el tipo de `length`.
