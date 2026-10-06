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
  echo "## Módulos de audio cargados"; lsmod | grep -E 'snd_(sof|soc|hda|intel)'
  echo "## Bloqueos de radio"; rfkill list 2>&1
  echo "## Interfaces de red"; nmcli device status 2>&1
  echo "## Mensajes del kernel sobre firmware, WiFi y audio"
  sudo dmesg | grep -iE 'firmware|rtw|rtl|iwlwifi|brcm|ath|sof|snd' | tail -n 60
} > "$out" 2>&1
echo "Listo: $out"
