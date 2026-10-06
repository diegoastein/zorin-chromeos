#!/usr/bin/env bash
# Script generado por "Panel ChromeOS en Zorin y MX"
# Equipo: Philco N14P4020 (Celeron, 4 GB). Sistema: MX Linux (XFCE).
# Módulos: base, region, chrome, pwas, onedrive, drv_wifi_ps, zram, perf_anim, updates, look_icons, look_scroll, look_touchpad, look_keys, look_favs
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


make_pwa() { # make_pwa id "Nombre" URL icono
  local id="$1" name="$2" url="$3" icon="$4"
  put "$HOME/.local/share/applications/pwa-$id.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$name
Exec=google-chrome-stable --app=$url
Icon=$icon
Terminal=false
Categories=Network;Office;
EOF
}

mod_pwas() {
  say "Creando lanzadores de apps web"
  make_pwa word "Word" "https://www.office.com/launch/word" x-office-document
  make_pwa excel "Excel" "https://www.office.com/launch/excel" x-office-spreadsheet
  make_pwa powerpoint "PowerPoint" "https://www.office.com/launch/powerpoint" x-office-presentation
  make_pwa gmail "Gmail" "https://mail.google.com/" internet-mail
  make_pwa gdrive "Drive" "https://drive.google.com/" folder-remote
  run update-desktop-database "$HOME/.local/share/applications" || true
  manual "Apps web: los lanzadores abren cada servicio en su propia ventana. Si querés íconos propios, instalá cada una desde Chrome (menú ⋮, Transmitir, guardar y compartir, Instalar página como app)."
}


mod_onedrive() {
  say "Instalando onedriver (OneDrive como carpeta)"
  local repo=""
  case "$CODENAME" in
    focal) repo="xUbuntu_20.04" ;;
    jammy) repo="xUbuntu_22.04" ;;
    noble) repo="xUbuntu_24.04" ;;
    bookworm) repo="Debian_12" ;;
    trixie) repo="Debian_13" ;;
  esac
  if [ -z "$repo" ]; then
    if [ "$DRY_RUN" = 1 ]; then repo="xUbuntu_24.04"; else
      warn "Versión no reconocida; se omite onedriver. Instalalo desde https://github.com/jstaf/onedriver y montalo en ~/OneDrive."
      return 0
    fi
  fi
  local base="https://download.opensuse.org/repositories/home:/jstaf/$repo"
  sh_c "curl -fsSL '$base/Release.key' | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/onedriver.gpg"
  echo "deb [signed-by=/etc/apt/keyrings/onedriver.gpg] $base/ /" | put /etc/apt/sources.list.d/onedriver.list sudo
  run sudo apt-get update
  run sudo apt-get install -y onedriver
  run mkdir -p "$HOME/OneDrive"
  manual "OneDrive, paso 1: en una terminal corré  onedriver ~/OneDrive  e iniciá sesión con tu cuenta de Microsoft en la ventana que se abre."
  manual "OneDrive, paso 2: para que se monte solo al iniciar sesión, corré  systemctl --user daemon-reload  y después  systemctl --user enable --now \"\$(systemd-escape --template onedriver@.service --path \$HOME/OneDrive)\""
}


mod_drv_wifi_ps() {
  say "Desactivando el ahorro de energía del WiFi (evita cortes de conexión)"
  printf '[connection]\nwifi.powersave = 2\n' | put /etc/NetworkManager/conf.d/99-wifi-powersave-off.conf sudo
  NEEDS_REBOOT=1
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


mod_perf_anim() {
  if [ "$TARGET" = mx ]; then
    say "Desactivando los efectos de composición de XFCE (ventanas más livianas)"
    xfset xfwm4 /general/use_compositing bool false
  else
    say "Desactivando animaciones del escritorio"
    gs org.gnome.desktop.interface enable-animations false
  fi
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


mod_look_icons() {
  say "Íconos Papirus"
  run sudo apt-get install -y papirus-icon-theme
  if [ "$TARGET" = mx ]; then
    xfset xsettings /Net/IconThemeName string Papirus
  else
    gs org.gnome.desktop.interface icon-theme "'Papirus'"
  fi
}


mod_look_scroll() {
  say "Desplazamiento natural del touchpad"
  if [ "$TARGET" = mx ]; then
    printf 'Section "InputClass"\n    Identifier "touchpad natural scroll"\n    MatchIsTouchpad "on"\n    Driver "libinput"\n    Option "NaturalScrolling" "true"\nEndSection\n' | put /etc/X11/xorg.conf.d/40-touchpad-scroll.conf sudo
  else
    gs org.gnome.desktop.peripherals.touchpad natural-scroll true
  fi
}


mod_look_touchpad() {
  say "Touchpad: tocar para hacer clic y clic derecho con dos dedos"
  if [ "$TARGET" = mx ]; then
    printf 'Section "InputClass"\n    Identifier "touchpad tap"\n    MatchIsTouchpad "on"\n    Driver "libinput"\n    Option "Tapping" "on"\n    Option "ClickMethod" "clickfinger"\nEndSection\n' | put /etc/X11/xorg.conf.d/40-touchpad-tap.conf sudo
  else
    gs org.gnome.desktop.peripherals.touchpad tap-to-click true
    gs org.gnome.desktop.peripherals.touchpad two-finger-scrolling-enabled true
    gs org.gnome.desktop.peripherals.touchpad click-method "'fingers'"
  fi
}


mod_look_keys() {
  say "Atajos de teclado tipo ChromeOS"
  if [ "$TARGET" = mx ]; then
    run sudo apt-get install -y xfce4-screenshooter
    xfset xfce4-keyboard-shortcuts '/commands/custom/<Primary><Shift>F5' string 'xfce4-screenshooter -r'
    xfset xfce4-keyboard-shortcuts '/xfwm4/custom/<Alt>bracketleft' string tile_left_key
    xfset xfce4-keyboard-shortcuts '/xfwm4/custom/<Alt>bracketright' string tile_right_key
  else
    gs org.gnome.shell.keybindings show-screenshot-ui "['<Primary><Shift>F5', 'Print']"
    gs org.gnome.mutter.keybindings toggle-tiled-left "['<Alt>bracketleft', '<Super>Left']"
    gs org.gnome.mutter.keybindings toggle-tiled-right "['<Alt>bracketright', '<Super>Right']"
  fi
}


mod_look_favs() {
  say "Apps ancladas en la barra"
  if [ "$TARGET" = mx ]; then
    manual "Lanzadores en MX: clic derecho en la barra inferior, Panel, Agregar elementos, Lanzador. Después arrastrá Chrome, Archivos y las apps web que elegiste."
  else
    gs org.gnome.shell favorite-apps "['google-chrome.desktop', 'org.gnome.Nautilus.desktop', 'pwa-word.desktop', 'pwa-excel.desktop', 'pwa-powerpoint.desktop', 'pwa-gmail.desktop', 'pwa-gdrive.desktop', 'org.gnome.Settings.desktop']"
  fi
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
  mod_pwas
  mod_onedrive
  mod_drv_wifi_ps
  mod_zram
  mod_perf_anim
  mod_updates
  mod_look_icons
  mod_look_scroll
  mod_look_touchpad
  mod_look_keys
  mod_look_favs
  manual "Aspecto: el touchpad y el desplazamiento se activan al cerrar sesión y volver a entrar. Los íconos, los atajos y el efecto de composición se aplican al momento."
  finish
}
main "$@"
