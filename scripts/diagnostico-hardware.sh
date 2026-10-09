#!/usr/bin/env bash
# Diagnóstico de hardware para la Philco N14P4020. Corrélo desde el pendrive en modo de prueba.
out="$HOME/diagnostico-hardware.txt"
{
  echo "## Fecha"; date
  echo "## Kernel"; uname -r
  echo "## CPU y RAM"; LC_ALL=C lscpu | grep -E 'Model name|^CPU\(s\):'; LC_ALL=C free -h
  echo "## Placas PCI de red y audio"; lspci -nnk | grep -A3 -iE 'network|audio'
  echo "## Dispositivos USB"; lsusb
  echo "## Tarjetas de sonido"; aplay -l 2>&1
  echo "## Codec de audio"; cat /proc/asound/card*/codec#* 2>&1
  echo "## Módulos de audio cargados"; lsmod | grep -E 'snd_(sof|soc|hda|intel)'
  echo "## Firmware y topología SOF instalados"; dpkg -l 2>/dev/null | grep -i sof-firmware; ls /lib/firmware/intel/sof* 2>&1 | head -n 20
  echo "## Tarjetas y perfiles de sonido (pactl)"; pactl list cards short 2>&1; echo; pactl list sinks 2>&1
  echo "## Estado de PipeWire/WirePlumber"; wpctl status 2>&1
  echo "## Volumen y mute (tarjeta 0)"; amixer -c0 contents 2>&1
  echo "## Cámara"; v4l2-ctl --list-devices 2>&1 || ls /dev/video* 2>&1
  echo "## Micrófono"; arecord -l 2>&1; pactl list sources short 2>&1
  echo "## Brillo de pantalla"; ls /sys/class/backlight 2>&1
  echo "## Bloqueos de radio"; rfkill list 2>&1
  echo "## Interfaces de red"; nmcli device status 2>&1
  echo "## Mensajes del kernel sobre firmware, WiFi, audio y brillo"
  sudo dmesg | grep -iE 'firmware|rtw|rtl|iwlwifi|brcm|ath|sof|snd|hdaudio|backlight' | tail -n 80
} > "$out" 2>&1
echo "Listo: $out"
