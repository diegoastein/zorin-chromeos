#!/usr/bin/env bash
# Script generado por "Panel ChromeOS en Zorin"
# Equipo: Philco N14P4020 (Celeron, 4 GB). Sistema: Zorin OS Core / Ubuntu con GNOME.
# Módulos: base, region, chrome, chrome_autostart, pwas, onedrive, accounts, acc_cal, acc_contacts, acc_mail, drv_fw, drv_hwe, drv_rtl, drv_bcm, drv_wifi_ps, drv_audio, zram, perf_anim, perf_tracker, perf_services, updates, look_icons, look_scheme, look_scroll, look_touchpad, look_keys, look_favs
#
# Uso:
#   DRY_RUN=1 bash setup.sh   # muestra lo que haría, sin cambiar nada
#   bash setup.sh             # aplica los cambios (ejecutalo con tu usuario, no como root)
set -euo pipefail
DRY_RUN="${DRY_RUN:-0}"


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

if [ "$DRY_RUN" != 1 ]; then
  [ "$(id -u)" -ne 0 ] || { echo "Ejecutá el script con tu usuario; usa sudo solo cuando hace falta."; exit 1; }
  grep -qi 'ubuntu' /etc/os-release || { echo "Este script es para Zorin OS / Ubuntu."; exit 1; }
  [ "$(uname -m)" = x86_64 ] || { echo "Este script es para equipos de 64 bits (x86_64)."; exit 1; }
  sudo -v
fi
CODENAME="$(. /etc/os-release; echo "${UBUNTU_CODENAME:-}")"

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
  run sudo apt-get install -y language-pack-es language-pack-gnome-es
  run sudo locale-gen es_AR.UTF-8
  run sudo update-locale LANG=es_AR.UTF-8
  gs org.gnome.desktop.input-sources sources "[('xkb', 'latam')]"
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


mod_chrome_autostart() {
  say "Chrome se abre al iniciar sesión"
  put "$HOME/.config/autostart/google-chrome.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Google Chrome
Exec=google-chrome-stable
X-GNOME-Autostart-enabled=true
EOF
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
  make_pwa onedrive-web "OneDrive web" "https://onedrive.live.com/" folder-remote
  make_pwa outlook "Outlook" "https://outlook.live.com/mail/" internet-mail
  make_pwa gmail "Gmail" "https://mail.google.com/" internet-mail
  make_pwa gdrive "Drive" "https://drive.google.com/" folder-remote
  make_pwa gcal "Calendar" "https://calendar.google.com/" x-office-calendar
  make_pwa gdocs "Docs" "https://docs.google.com/document/" x-office-document
  make_pwa gsheets "Sheets" "https://docs.google.com/spreadsheets/" x-office-spreadsheet
  make_pwa gslides "Slides" "https://docs.google.com/presentation/" x-office-presentation
  run update-desktop-database "$HOME/.local/share/applications" || true
  manual "Apps web: los lanzadores abren cada servicio en su propia ventana. Si querés íconos propios, instalá cada una desde Chrome (menú ⋮, Transmitir, guardar y compartir, Instalar página como app)."
}


mod_onedrive() {
  say "Instalando onedriver (OneDrive como carpeta)"
  local ver=""
  case "$CODENAME" in
    focal) ver="20.04" ;;
    jammy) ver="22.04" ;;
    noble) ver="24.04" ;;
  esac
  if [ -z "$ver" ]; then
    if [ "$DRY_RUN" = 1 ]; then ver="24.04"; else
      warn "Versión de Ubuntu no reconocida; se omite onedriver. Instalalo desde https://github.com/jstaf/onedriver y montalo en ~/OneDrive."
      return 0
    fi
  fi
  local base="https://download.opensuse.org/repositories/home:/jstaf/xUbuntu_$ver"
  sh_c "curl -fsSL '$base/Release.key' | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/onedriver.gpg"
  echo "deb [signed-by=/etc/apt/keyrings/onedriver.gpg] $base/ /" | put /etc/apt/sources.list.d/onedriver.list sudo
  run sudo apt-get update
  run sudo apt-get install -y onedriver
  run mkdir -p "$HOME/OneDrive"
  manual "OneDrive, paso 1: en una terminal corré  onedriver ~/OneDrive  e iniciá sesión con tu cuenta de Microsoft en la ventana que se abre."
  manual "OneDrive, paso 2: para que se monte solo al iniciar sesión, corré  systemctl --user daemon-reload  y después  systemctl --user enable --now \"\$(systemd-escape --template onedriver@.service --path \$HOME/OneDrive)\""
}


mod_accounts() {
  say "Cuentas en línea y Google Drive en el explorador de archivos"
  run sudo apt-get install -y gnome-online-accounts gnome-control-center gvfs-backends gvfs-fuse
  run sudo apt-get install -y gnome-online-accounts-gtk || true
  manual "Cuentas de Google: Configuración, Cuentas en línea, Google. Iniciá sesión y activá Archivos. Chrome sincroniza aparte con su propio inicio de sesión."
}


mod_acc_cal() {
  say "Calendario de GNOME"
  run sudo apt-get install -y gnome-calendar
}


mod_acc_contacts() {
  say "Contactos de GNOME"
  run sudo apt-get install -y gnome-contacts
}


mod_acc_mail() {
  say "Correo (Geary)"
  run sudo apt-get install -y geary
}


mod_drv_fw() {
  say "Reinstalando el firmware de la placa (WiFi y audio)"
  run sudo apt-get install -y --reinstall linux-firmware
  run sudo update-initramfs -u
  NEEDS_REBOOT=1
}


mod_drv_hwe() {
  say "Kernel más nuevo (HWE) para mejor soporte de hardware"
  case "$CODENAME" in
    jammy) run sudo apt-get install -y linux-generic-hwe-22.04 ;;
    noble) run sudo apt-get install -y linux-generic-hwe-24.04 ;;
    *) warn "Versión de Ubuntu no reconocida; se omite el kernel HWE." ;;
  esac
  NEEDS_REBOOT=1
}


mod_drv_rtl() {
  say "Driver Realtek 8821CE (solo si el chip está presente)"
  if [ "$DRY_RUN" = 1 ] || lspci -nn 2>/dev/null | grep -qi '10ec:c821'; then
    run sudo apt-get install -y dkms build-essential "linux-headers-$(uname -r)" rtl8821ce-dkms
    NEEDS_REBOOT=1
    manual "Driver Realtek: si el equipo tiene Secure Boot, al reiniciar aparece una pantalla azul de MOK. Elegí Enroll MOK e ingresá la contraseña que te pidió la instalación."
  else
    warn "No se encontró un Realtek 8821CE en este equipo; se omite."
  fi
}


mod_drv_bcm() {
  say "Driver Broadcom de WiFi (solo si el chip está presente)"
  if [ "$DRY_RUN" = 1 ] || lspci -nn 2>/dev/null | grep -iE 'network.*broadcom' >/dev/null; then
    run sudo apt-get install -y bcmwl-kernel-source
    NEEDS_REBOOT=1
  else
    warn "No se encontró una placa WiFi Broadcom; se omite."
  fi
}


mod_drv_wifi_ps() {
  say "Desactivando el ahorro de energía del WiFi (evita cortes de conexión)"
  printf '[connection]\nwifi.powersave = 2\n' | put /etc/NetworkManager/conf.d/99-wifi-powersave-off.conf sudo
  NEEDS_REBOOT=1
}


mod_drv_audio() {
  say "Audio: usar el driver clásico de Intel"
  printf 'options snd-intel-dspcfg dsp_driver=1\n' | put /etc/modprobe.d/99-audio-clasico.conf sudo
  run sudo update-initramfs -u
  NEEDS_REBOOT=1
  manual "Audio: si después de reiniciar sigue sin sonido, borrá /etc/modprobe.d/99-audio-clasico.conf, corré  sudo update-initramfs -u  y pasame la salida del diagnóstico."
}


mod_zram() {
  say "Activando zram (memoria comprimida) y ajustes de memoria"
  run sudo apt-get install -y systemd-zram-generator
  printf '[zram0]\nzram-size = ram\ncompression-algorithm = zstd\nswap-priority = 100\n' | put /etc/systemd/zram-generator.conf sudo
  printf 'vm.swappiness = 100\nvm.page-cluster = 0\nvm.vfs_cache_pressure = 50\n' | put /etc/sysctl.d/99-zram.conf sudo
  run sudo sysctl --system
  run sudo systemctl daemon-reload
  run sudo systemctl start systemd-zram-setup@zram0.service || warn "zram se activa después de reiniciar."
  NEEDS_REBOOT=1
}


mod_perf_anim() {
  say "Desactivando animaciones del escritorio"
  gs org.gnome.desktop.interface enable-animations false
}


mod_perf_tracker() {
  say "Desactivando la indexación de archivos en segundo plano"
  local u
  for u in tracker-miner-fs-3 tracker-extract-3 localsearch-3 localsearch-extract-3; do
    if [ "$DRY_RUN" = 1 ] || systemctl --user list-unit-files "$u.service" 2>/dev/null | grep -q "$u"; then
      run systemctl --user mask "$u.service" || true
    fi
  done
}


mod_perf_services() {
  say "Apagando servicios que no se usan (módem móvil y descubrimiento de impresoras)"
  local s
  for s in ModemManager cups-browsed; do
    if [ "$DRY_RUN" = 1 ] || systemctl list-unit-files "$s.service" 2>/dev/null | grep -q "$s"; then
      run sudo systemctl disable --now "$s.service" || true
    fi
  done
}


mod_updates() {
  say "Actualizaciones automáticas en segundo plano"
  run sudo apt-get install -y unattended-upgrades
  printf 'APT::Periodic::Update-Package-Lists "1";\nAPT::Periodic::Unattended-Upgrade "1";\n' | put /etc/apt/apt.conf.d/20auto-upgrades sudo
  {
    printf 'Unattended-Upgrade::Allowed-Origins:: "Google LLC:stable";\n'
    printf 'Unattended-Upgrade::Automatic-Reboot "true";\nUnattended-Upgrade::Automatic-Reboot-Time "04:00";\n'
  } | put /etc/apt/apt.conf.d/52chromeos-like sudo
}


mod_look_icons() {
  say "Íconos Papirus"
  run sudo apt-get install -y papirus-icon-theme
  gs org.gnome.desktop.interface icon-theme "'Papirus'"
}


mod_look_scheme() {
  say "Tema claro u oscuro"
  gs org.gnome.desktop.interface color-scheme "'default'"
}


mod_look_scroll() {
  say "Desplazamiento natural del touchpad"
  gs org.gnome.desktop.peripherals.touchpad natural-scroll true
}


mod_look_touchpad() {
  say "Touchpad: tocar para hacer clic y clic derecho con dos dedos"
  gs org.gnome.desktop.peripherals.touchpad tap-to-click true
  gs org.gnome.desktop.peripherals.touchpad two-finger-scrolling-enabled true
  gs org.gnome.desktop.peripherals.touchpad click-method "'fingers'"
}


mod_look_keys() {
  say "Atajos de teclado tipo ChromeOS"
  gs org.gnome.shell.keybindings show-screenshot-ui "['<Primary><Shift>F5', 'Print']"
  gs org.gnome.mutter.keybindings toggle-tiled-left "['<Alt>bracketleft', '<Super>Left']"
  gs org.gnome.mutter.keybindings toggle-tiled-right "['<Alt>bracketright', '<Super>Right']"
}


mod_look_favs() {
  say "Apps ancladas en la barra"
  gs org.gnome.shell favorite-apps "['google-chrome.desktop', 'org.gnome.Nautilus.desktop', 'pwa-word.desktop', 'pwa-excel.desktop', 'pwa-powerpoint.desktop', 'pwa-onedrive-web.desktop', 'pwa-outlook.desktop', 'pwa-gmail.desktop', 'pwa-gdrive.desktop', 'pwa-gcal.desktop', 'pwa-gdocs.desktop', 'pwa-gsheets.desktop', 'pwa-gslides.desktop', 'org.gnome.Settings.desktop']"
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
  mod_chrome_autostart
  mod_pwas
  mod_onedrive
  mod_accounts
  mod_acc_cal
  mod_acc_contacts
  mod_acc_mail
  mod_drv_fw
  mod_drv_hwe
  mod_drv_rtl
  mod_drv_bcm
  mod_drv_wifi_ps
  mod_drv_audio
  mod_zram
  mod_perf_anim
  mod_perf_tracker
  mod_perf_services
  mod_updates
  mod_look_icons
  mod_look_scheme
  mod_look_scroll
  mod_look_touchpad
  mod_look_keys
  mod_look_favs
  manual "Aspecto: abrí Zorin Appearance y elegí un diseño con la barra abajo y los íconos centrados para acercarte al estilo de ChromeOS. Los cambios de esta sección se ven al cerrar sesión y volver a entrar."
  finish
}
main "$@"
