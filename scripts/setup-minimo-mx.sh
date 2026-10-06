#!/usr/bin/env bash
# Script generado por "Panel ChromeOS en Zorin y MX"
# Equipo: Philco N14P4020 (Celeron, 4 GB). Sistema: MX Linux (XFCE).
# Módulos: base, region, chrome, zram, updates
#
# Uso:
#   DRY_RUN=1 bash setup.sh   # muestra lo que haría, sin cambiar nada
#   bash setup.sh             # aplica los cambios (ejecutalo con tu usuario, no como root)
set -euo pipefail
DRY_RUN="${DRY_RUN:-0}"
TARGET="mx"


say()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[aviso]\033[0m %s\n' "$*" >&2; }
MANUAL=()
NEEDS_REBOOT=0
manual() { MANUAL+=("$*"); }

# run: ejecuta el comando, o solo lo muestra en modo de prueba
run() { if [ "$DRY_RUN" = 1 ]; then printf '[dry-run] %s\n' "$*"; else "$@"; fi; }
# sh_c: igual que run, para cadenas con pipes
sh_c() { if [ "$DRY_RUN" = 1 ]; then printf '[dry-run] %s\n' "$1"; else bash -c "$1"; fi; }
# put DESTINO [sudo]: escribe el contenido que llega por stdin
put() {
  local dest="$1" use_sudo="${2:-}"
  if [ "$DRY_RUN" = 1 ]; then
    echo "[dry-run] escribiría $dest"; cat >/dev/null
  elif [ -n "$use_sudo" ]; then
    sudo mkdir -p "$(dirname "$dest")" && sudo tee "$dest" >/dev/null
  else
    mkdir -p "$(dirname "$dest")" && cat >"$dest"
  fi
}
# gs ESQUEMA CLAVE VALOR: aplica un ajuste de GNOME solo si la clave existe en esta versión
gs() {
  if [ "$DRY_RUN" = 1 ]; then echo "[dry-run] gsettings set $1 $2 $3"; return 0; fi
  if gsettings list-keys "$1" 2>/dev/null | grep -qx "$2"; then
    gsettings set "$1" "$2" "$3" || warn "No se pudo aplicar $1 $2"
  else
    warn "Ajuste no disponible en esta versión: $1 $2"
  fi
}
# xfset CANAL PROPIEDAD TIPO VALOR: ajusta una opción de XFCE (xfconf) en la sesión actual
xfset() {
  if [ "$DRY_RUN" = 1 ]; then echo "[dry-run] xfconf-query -c $1 -p $2 -t $3 -s $4"; return 0; fi
  xfconf-query -c "$1" -p "$2" -n -t "$3" -s "$4" 2>/dev/null || warn "No se pudo aplicar $1 $2 (¿la sesión de XFCE está abierta?)"
}

if [ "$DRY_RUN" != 1 ]; then
  [ "$(id -u)" -ne 0 ] || { echo "Ejecutá el script con tu usuario; usa sudo solo cuando hace falta."; exit 1; }
  [ -r /etc/debian_version ] && command -v xfconf-query >/dev/null || { echo 'Este script es para MX Linux con XFCE.'; exit 1; }
  [ "$(uname -m)" = x86_64 ] || { echo "Este script es para equipos de 64 bits (x86_64)."; exit 1; }
  sudo -v
fi
CODENAME="$(. /etc/os-release; echo "${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}")"

mod_base() {
  say "Actualizando el sistema"
  run sudo apt-get update
  run sudo apt-get -y upgrade
  run sudo apt-get install -y curl wget gpg ca-certificates git
  run sudo install -d -m 0755 /etc/apt/keyrings
}


mod_region() {
  say "Idioma, zona horaria y teclado de Argentina"
  run sudo timedatectl set-timezone America/Argentina/Buenos_Aires
  if [ "$TARGET" = mx ]; then
    run sudo apt-get install -y locales
    run sudo sed -i 's/^# *es_AR.UTF-8 UTF-8/es_AR.UTF-8 UTF-8/' /etc/locale.gen
    run sudo locale-gen
  else
    run sudo apt-get install -y language-pack-es language-pack-gnome-es
    run sudo locale-gen es_AR.UTF-8
  fi
  run sudo update-locale LANG=es_AR.UTF-8
  xfset keyboard-layout /Default/XkbLayout string latam; run sudo localectl set-x11-keymap latam
  NEEDS_REBOOT=1
}


mod_chrome() {
  say "Instalando Google Chrome oficial"
  sh_c 'curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/google-chrome.gpg'
  echo 'deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main' | put /etc/apt/sources.list.d/google-chrome.list sudo
  run sudo apt-get update
  run sudo apt-get install -y google-chrome-stable
  run xdg-settings set default-web-browser google-chrome.desktop || warn "No se pudo fijar Chrome como navegador predeterminado."
  manual "Chrome: abrilo e iniciá sesión con tu cuenta de Google para sincronizar extensiones y favoritos."
}


mod_zram() {
  say "Activando zram (memoria comprimida) y ajustes de memoria"
  if [ "$TARGET" = mx ]; then
    run sudo apt-get install -y zram-tools
    printf 'ALGO=zstd\nPERCENT=100\n' | put /etc/default/zramswap sudo
    run sudo systemctl enable --now zramswap.service || warn "zram se activa después de reiniciar."
  else
    run sudo apt-get install -y systemd-zram-generator
    printf '[zram0]\nzram-size = ram\ncompression-algorithm = zstd\nswap-priority = 100\n' | put /etc/systemd/zram-generator.conf sudo
    run sudo systemctl daemon-reload
    run sudo systemctl start systemd-zram-setup@zram0.service || warn "zram se activa después de reiniciar."
  fi
  printf 'vm.swappiness = 100\nvm.page-cluster = 0\nvm.vfs_cache_pressure = 50\n' | put /etc/sysctl.d/99-zram.conf sudo
  run sudo sysctl --system
  NEEDS_REBOOT=1
}


mod_updates() {
  say "Actualizaciones automáticas en segundo plano"
  run sudo apt-get install -y unattended-upgrades
  printf 'APT::Periodic::Update-Package-Lists "1";\nAPT::Periodic::Unattended-Upgrade "1";\n' | put /etc/apt/apt.conf.d/20auto-upgrades sudo
  {
    printf 'Unattended-Upgrade::Allowed-Origins:: "Google LLC:stable";\n'
    printf 'Unattended-Upgrade::Automatic-Reboot "false";\n'
  } | put /etc/apt/apt.conf.d/52chromeos-like sudo
}


finish() {
  say "Listo"
  if [ "${#MANUAL[@]}" -gt 0 ]; then
    echo "Pasos que quedan por hacer a mano:"
    local i=1 m
    for m in "${MANUAL[@]}"; do printf '  %d. %s\n' "$i" "$m"; i=$((i+1)); done
    if [ "$DRY_RUN" != 1 ]; then printf '%s\n' "${MANUAL[@]}" > "$HOME/PASOS-MANUALES.txt"; echo "(guardados en ~/PASOS-MANUALES.txt)"; fi
  fi
  if [ "$NEEDS_REBOOT" = 1 ]; then echo "Reiniciá la notebook para aplicar todos los cambios."; fi
}

main() {
  mod_base
  mod_region
  mod_chrome
  mod_zram
  mod_updates
  finish
}
main "$@"
