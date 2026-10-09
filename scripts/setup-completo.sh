#!/usr/bin/env bash
# Script generado por "Panel ChromeOS en Zorin y MX"
# Equipo: Philco N14P4020 (Celeron, 4 GB). Sistema: Zorin OS Core (GNOME).
# Módulos: base, backup_snapshot, region, chrome, chrome_autostart, pwas, onedrive, cleanup_apps, accounts, acc_cal, acc_contacts, acc_mail, drv_fw, drv_hwe, drv_rtl, drv_bcm, drv_wifi_ps, drv_audio, drv_audio_fw, drv_audio_unmute, drv_audio_jd, drv_brightness, zram, perf_anim, perf_tracker, perf_power, perf_services, updates, look_shelf, look_wallpaper, look_font, look_icons, look_scheme, look_scroll, look_touchpad, look_keys, look_favs
#
# Uso:
#   DRY_RUN=1 bash setup.sh   # muestra lo que haría, sin cambiar nada
#   bash setup.sh             # aplica los cambios (ejecutalo con tu usuario, no como root)
set -euo pipefail
DRY_RUN="${DRY_RUN:-0}"
TARGET="zorin"


say()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[aviso]\033[0m %s\n' "$*" >&2; }
MANUAL=()
NEEDS_REBOOT=0
manual() { MANUAL+=("$*"); }
OK_MODS=()
FAILED_MODS=()
MOD_FAILED=0
# run_mod ID: corre mod_ID sin que un error adentro frene el resto del script.
# Guarda el resultado para el reporte final (finish), usando MOD_FAILED (lo marcan
# run/sh_c/put cuando algo realmente falla) en vez del código de salida de mod_ID,
# porque un paso que falla en el medio no corta los pasos siguientes del módulo.
# mod_base queda afuera a propósito: si falla la actualización base, seguir con el
# resto no tiene sentido.
run_mod() {
  local id="$1"
  MOD_FAILED=0
  "mod_$id" || true
  if [ "$MOD_FAILED" -eq 0 ]; then
    OK_MODS+=("$id")
  else
    FAILED_MODS+=("$id")
  fi
}

# run: ejecuta el comando, o solo lo muestra en modo de prueba. Si falla, lo marca
# para el reporte final en vez de cortar el script.
run() {
  if [ "$DRY_RUN" = 1 ]; then printf '[dry-run] %s\n' "$*"; return 0; fi
  "$@" || { MOD_FAILED=1; warn "Falló: $*"; }
}
# sh_c: igual que run, para cadenas con pipes
sh_c() {
  if [ "$DRY_RUN" = 1 ]; then printf '[dry-run] %s\n' "$1"; return 0; fi
  bash -c "$1" || { MOD_FAILED=1; warn "Falló: $1"; }
}
# put DESTINO [sudo]: escribe el contenido que llega por stdin
put() {
  local dest="$1" use_sudo="${2:-}"
  if [ "$DRY_RUN" = 1 ]; then
    echo "[dry-run] escribiría $dest"; cat >/dev/null
  elif [ -n "$use_sudo" ]; then
    { sudo mkdir -p "$(dirname "$dest")" && sudo tee "$dest" >/dev/null; } || { MOD_FAILED=1; warn "No se pudo escribir $dest"; }
  else
    { mkdir -p "$(dirname "$dest")" && cat >"$dest"; } || { MOD_FAILED=1; warn "No se pudo escribir $dest"; }
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
  grep -qi 'ubuntu' /etc/os-release || { echo 'Este script es para Zorin OS / Ubuntu.'; exit 1; }
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


mod_backup_snapshot() {
  say "Respaldo: instalando Timeshift y creando un punto de restauración"
  run sudo apt-get install -y timeshift
  if [ "$DRY_RUN" = 1 ]; then
    echo "[dry-run] sudo timeshift --create --comments 'antes de aplicar el script' --tags D"
  else
    sudo timeshift --create --comments "Antes de aplicar el script ($(date +%F))" --tags D \
      || warn "No se pudo crear el snapshot automáticamente; abrí Timeshift y creá uno a mano antes de seguir."
  fi
  manual "Respaldo: si algo sale mal, abrí Timeshift (menú de apps) y restaurá el punto de antes de este script."
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


mod_cleanup_apps() {
  say "Quitando LibreOffice y Brave (si están instalados)"
  if [ "$DRY_RUN" = 1 ] || dpkg -l 2>/dev/null | grep -q '^ii *libreoffice'; then
    run sudo apt-get purge -y 'libreoffice*'
  fi
  if [ "$DRY_RUN" = 1 ] || dpkg -l 2>/dev/null | grep -q '^ii *brave-browser'; then
    run sudo apt-get purge -y brave-browser
  fi
  run sudo apt-get autoremove -y
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
    if [ "$TARGET" = mx ]; then
      # En Debian/MX el paquete puede no estar: si falla, se deja la instalación a mano sin cortar el script
      run sudo apt-get install -y dkms build-essential "linux-headers-$(uname -r)" rtl8821ce-dkms || { warn "rtl8821ce-dkms no está en los repositorios de MX."; manual "Driver Realtek 8821CE en MX: el paquete no vino en los repositorios. Instalalo siguiendo la guía de morrownr/8821ce en GitHub y reiniciá."; return 0; }
    else
      run sudo apt-get install -y dkms build-essential "linux-headers-$(uname -r)" rtl8821ce-dkms
    fi
    NEEDS_REBOOT=1
    manual "Driver Realtek: si el equipo tiene Secure Boot, al reiniciar aparece una pantalla azul de MOK. Elegí Enroll MOK e ingresá la contraseña que te pidió la instalación."
  else
    warn "No se encontró un Realtek 8821CE en este equipo; se omite."
  fi
}


mod_drv_bcm() {
  say "Driver Broadcom de WiFi (solo si el chip está presente)"
  if [ "$DRY_RUN" = 1 ] || lspci -nn 2>/dev/null | grep -iE 'network.*broadcom' >/dev/null; then
    if [ "$TARGET" = mx ]; then
      # En Debian este driver está en non-free: si no está habilitado, se avisa sin cortar el script
      run sudo apt-get install -y bcmwl-kernel-source || { warn "bcmwl-kernel-source no está disponible."; manual "Driver Broadcom en MX: habilitá el repositorio non-free en /etc/apt/sources.list y después corré  sudo apt-get install bcmwl-kernel-source  y reiniciá."; return 0; }
    else
      run sudo apt-get install -y bcmwl-kernel-source
    fi
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


mod_drv_audio_fw() {
  say "Audio: reinstalando el firmware y la topología de SOF"
  run sudo apt-get install -y --reinstall sof-firmware alsa-ucm-conf
  run sudo update-initramfs -u
  NEEDS_REBOOT=1
  manual "Audio (SOF): este paso es lo opuesto al driver clásico de Intel. Probá uno de los dos, no los dos juntos, y mirá la sección Codec de audio del diagnóstico para decidir cuál."
}


mod_drv_audio_unmute() {
  say "Audio: desmuteando canales y fijando la salida analógica"
  local canal sink
  for canal in Master Speaker Headphone PCM; do
    run amixer -q set "$canal" 85% unmute 2>/dev/null || true
  done
  if [ "$DRY_RUN" = 1 ]; then
    echo "[dry-run] buscaría un sink analógico con pactl y lo pondría por defecto"
  else
    sink="$(pactl list sinks short 2>/dev/null | grep -i analog | awk '{print $1}' | head -n1)"
    if [ -n "$sink" ]; then
      pactl set-default-sink "$sink" || warn "No se pudo fijar el sink analógico como predeterminado."
      pactl set-sink-mute "$sink" 0 || true
    else
      warn "pactl no encontró un sink analógico; puede que la tarjeta solo tenga salida digital."
    fi
  fi
  manual "Audio: si el sonido sigue sin salir por los parlantes o los auriculares, abrí Configuración, Sonido, y elegí el dispositivo de salida a mano."
}


mod_drv_audio_jd() {
  say "Audio ES8336: invertir la detección del conector de auriculares (Philco)"
  if [ "$DRY_RUN" != 1 ]; then
    if ! grep -qi 'N14P4020' /sys/class/dmi/id/product_name 2>/dev/null; then
      warn "Este ajuste solo está probado en la Philco N14P4020; se omite en este equipo."
      return 0
    fi
    if ! grep -qiE 'es8336|essx8336' /proc/asound/cards 2>/dev/null; then
      warn "No se encontró la tarjeta de sonido ES8336; se omite."
      return 0
    fi
  fi
  printf 'options snd_soc_sof_es8336 quirk=64\n' | put /etc/modprobe.d/99-philco-audio.conf sudo
  run sudo update-initramfs -u
  NEEDS_REBOOT=1
  manual "Audio (Philco): después de reiniciar tienen que sonar los parlantes y el conector tiene que detectar los auriculares al enchufarlos. Si algo sale peor, deshacelo con  sudo rm /etc/modprobe.d/99-philco-audio.conf  y  sudo update-initramfs -u  y reiniciá."
}


mod_drv_brightness() {
  say "Brillo: pasando el control de la pantalla al driver nativo"
  printf 'options video acpi_backlight=native\n' | put /etc/modprobe.d/99-brillo.conf sudo
  run sudo update-initramfs -u
  NEEDS_REBOOT=1
  manual "Brillo: si las teclas de brillo siguen sin responder, cambiá native por vendor en /etc/modprobe.d/99-brillo.conf y repetí  sudo update-initramfs -u."
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


mod_perf_tracker() {
  say "Desactivando la indexación de archivos en segundo plano"
  local u
  for u in tracker-miner-fs-3 tracker-extract-3 localsearch-3 localsearch-extract-3; do
    if [ "$DRY_RUN" = 1 ] || systemctl --user list-unit-files "$u.service" 2>/dev/null | grep -q "$u"; then
      run systemctl --user mask "$u.service" || true
    fi
  done
}


mod_perf_power() {
  say "Batería: ahorro de energía con TLP"
  run sudo apt-get install -y tlp tlp-rdw
  run sudo systemctl enable --now tlp.service
  manual "Batería: corré  sudo tlp-stat -b  para ver el estado de la carga y del ahorro de energía."
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


mod_look_shelf() {
  say "Barra estilo ChromeOS: abajo, menú a la izquierda, apps al centro, reloj y sistema a la derecha"
  if [ "$TARGET" = mx ]; then
    local id=1
    if [ "$DRY_RUN" != 1 ]; then
      id="$(xfconf-query -c xfce4-panel -p /panels 2>/dev/null | grep -E '^[0-9]+$' | head -n1)"
      id="${id:-1}"
    fi
    xfset xfce4-panel "/panels/panel-$id/mode" uint 0
    xfset xfce4-panel "/panels/panel-$id/position" string 'p=10;x=0;y=0'
    xfset xfce4-panel "/panels/panel-$id/length" uint 100
    xfset xfce4-panel "/panels/panel-$id/size" uint 48
    xfset xfce4-panel "/panels/panel-$id/position-locked" bool true
    xfset xfce4-keyboard-shortcuts /commands/custom/Super_L string xfce4-popup-whiskermenu
    run xfce4-panel -r || true
    manual "Barra en MX: si los elementos quedaron desordenados, abrí MX Tweak, pestaña Panel, elegí Horizontal y Abajo. Para centrar las apps como en ChromeOS: clic derecho en la barra, Panel, Preferencias del panel, Elementos, y agregá un Separador con la opción Expandir a cada lado de Botones de ventana."
    return 0
  fi
  # Zorin usa su propia versión de dash-to-panel; se busca el esquema que exista
  local schema=org.gnome.shell.extensions.zorin-taskbar s
  if [ "$DRY_RUN" != 1 ]; then
    schema=""
    for s in org.gnome.shell.extensions.zorin-taskbar org.gnome.shell.extensions.dash-to-panel; do
      if gsettings list-schemas 2>/dev/null | grep -qx "$s"; then schema="$s"; break; fi
    done
  fi
  if [ -z "$schema" ]; then
    warn "No se encontró la configuración de la barra de Zorin."
    manual "Barra: abrí Zorin Appearance, Diseño, elegí la barra abajo y, en la configuración de la barra, centrá los íconos de las apps."
    return 0
  fi
  gs "$schema" panel-position "'BOTTOM'"
  gs "$schema" panel-positions "'{\"0\":\"BOTTOM\"}'"
  gs "$schema" panel-size 48
  gs "$schema" panel-sizes "'{\"0\":48}'"
  gs "$schema" panel-element-positions "'{\"0\":[{\"element\":\"showAppsButton\",\"visible\":false,\"position\":\"stackedTL\"},{\"element\":\"activitiesButton\",\"visible\":false,\"position\":\"stackedTL\"},{\"element\":\"leftBox\",\"visible\":true,\"position\":\"stackedTL\"},{\"element\":\"taskbar\",\"visible\":true,\"position\":\"centerMonitor\"},{\"element\":\"centerBox\",\"visible\":false,\"position\":\"stackedBR\"},{\"element\":\"rightBox\",\"visible\":true,\"position\":\"stackedBR\"},{\"element\":\"dateMenu\",\"visible\":true,\"position\":\"stackedBR\"},{\"element\":\"systemMenu\",\"visible\":true,\"position\":\"stackedBR\"},{\"element\":\"desktopButton\",\"visible\":false,\"position\":\"stackedBR\"}]}'"
  gs "$schema" dot-position "'BOTTOM'"
  gs "$schema" dot-style-focused "'DOTS'"
  gs "$schema" dot-style-unfocused "'DOTS'"
  manual "Barra: si después de cerrar sesión no quedó abajo con las apps al centro, abrí Zorin Appearance, Diseño, y ajustala desde ahí. El menú de la derecha (WiFi, sonido, brillo) es el de GNOME, que ya usa botones redondeados como ChromeOS."
}


mod_look_wallpaper() {
  say "Fondo de pantalla estilo ChromeOS (versión clara y oscura)"
  local dir="$HOME/.local/share/backgrounds"
  put "$dir/chromeos-estilo-claro.svg" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1920 1080" width="1920" height="1080">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#eef3fd"/><stop offset="1" stop-color="#dde7f6"/></linearGradient>
    <radialGradient id="a"><stop offset="0" stop-color="#8ab4f8" stop-opacity=".85"/><stop offset="1" stop-color="#8ab4f8" stop-opacity="0"/></radialGradient>
    <radialGradient id="b"><stop offset="0" stop-color="#81c995" stop-opacity=".7"/><stop offset="1" stop-color="#81c995" stop-opacity="0"/></radialGradient>
    <radialGradient id="c"><stop offset="0" stop-color="#fdd663" stop-opacity=".7"/><stop offset="1" stop-color="#fdd663" stop-opacity="0"/></radialGradient>
    <radialGradient id="d"><stop offset="0" stop-color="#f28b82" stop-opacity=".55"/><stop offset="1" stop-color="#f28b82" stop-opacity="0"/></radialGradient>
  </defs>
  <rect width="1920" height="1080" fill="url(#bg)"/>
  <circle cx="1520" cy="260" r="720" fill="url(#a)"/>
  <circle cx="280" cy="920" r="660" fill="url(#b)"/>
  <circle cx="1120" cy="1010" r="520" fill="url(#c)"/>
  <circle cx="240" cy="140" r="460" fill="url(#d)"/>
</svg>
EOF
  put "$dir/chromeos-estilo-oscuro.svg" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1920 1080" width="1920" height="1080">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#1c2230"/><stop offset="1" stop-color="#0f131b"/></linearGradient>
    <radialGradient id="a"><stop offset="0" stop-color="#4c7fd6" stop-opacity=".6"/><stop offset="1" stop-color="#4c7fd6" stop-opacity="0"/></radialGradient>
    <radialGradient id="b"><stop offset="0" stop-color="#3f9a63" stop-opacity=".45"/><stop offset="1" stop-color="#3f9a63" stop-opacity="0"/></radialGradient>
    <radialGradient id="c"><stop offset="0" stop-color="#c9a227" stop-opacity=".35"/><stop offset="1" stop-color="#c9a227" stop-opacity="0"/></radialGradient>
    <radialGradient id="d"><stop offset="0" stop-color="#c25b53" stop-opacity=".35"/><stop offset="1" stop-color="#c25b53" stop-opacity="0"/></radialGradient>
  </defs>
  <rect width="1920" height="1080" fill="url(#bg)"/>
  <circle cx="1520" cy="260" r="720" fill="url(#a)"/>
  <circle cx="280" cy="920" r="660" fill="url(#b)"/>
  <circle cx="1120" cy="1010" r="520" fill="url(#c)"/>
  <circle cx="240" cy="140" r="460" fill="url(#d)"/>
</svg>
EOF
  if [ "$TARGET" = mx ]; then
    if [ "$DRY_RUN" = 1 ]; then
      echo "[dry-run] xfconf-query -c xfce4-desktop: last-image = $dir/chromeos-estilo-claro.svg en cada monitor"
    else
      local props p
      props="$(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep '/last-image$' || true)"
      if [ -z "$props" ]; then
        manual "Fondo en MX: clic derecho en el escritorio, Configuración del escritorio, y elegí $dir/chromeos-estilo-claro.svg."
      fi
      for p in $props; do
        xfconf-query -c xfce4-desktop -p "$p" -s "$dir/chromeos-estilo-claro.svg" || warn "No se pudo cambiar el fondo en $p"
        xfconf-query -c xfce4-desktop -p "${p%last-image}image-style" -n -t int -s 5 2>/dev/null || true
      done
    fi
  else
    gs org.gnome.desktop.background picture-uri "'file://$dir/chromeos-estilo-claro.svg'"
    gs org.gnome.desktop.background picture-uri-dark "'file://$dir/chromeos-estilo-oscuro.svg'"
    gs org.gnome.desktop.background picture-options "'zoom'"
    gs org.gnome.desktop.screensaver picture-uri "'file://$dir/chromeos-estilo-claro.svg'"
  fi
  manual "Fondo: el script deja un fondo propio inspirado en ChromeOS. Si preferís una foto o un fondo oficial que tengas guardado, elegilo con clic derecho en el escritorio, Cambiar fondo."
}


mod_look_font() {
  say "Letra Roboto en menús y ventanas"
  run sudo apt-get install -y fonts-roboto
  if [ "$TARGET" = mx ]; then
    xfset xsettings /Gtk/FontName string 'Roboto 10'
  else
    gs org.gnome.desktop.interface font-name "'Roboto 11'"
    gs org.gnome.desktop.interface document-font-name "'Roboto 11'"
  fi
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


mod_look_scheme() {
  say "Tema claro u oscuro"
  gs org.gnome.desktop.interface color-scheme "'default'"
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
    gs org.gnome.shell favorite-apps "['google-chrome.desktop', 'org.gnome.Nautilus.desktop', 'pwa-word.desktop', 'pwa-excel.desktop', 'pwa-powerpoint.desktop', 'pwa-onedrive-web.desktop', 'pwa-outlook.desktop', 'pwa-gmail.desktop', 'pwa-gdrive.desktop', 'pwa-gcal.desktop', 'pwa-gdocs.desktop', 'pwa-gsheets.desktop', 'pwa-gslides.desktop', 'org.gnome.Settings.desktop']"
  fi
}


finish() {
  say "Listo"
  echo "Módulos aplicados: ${#OK_MODS[@]}. Con errores: ${#FAILED_MODS[@]}."
  if [ "${#FAILED_MODS[@]}" -gt 0 ]; then
    echo "No se pudieron completar (revisá los avisos de arriba):"
    local f
    for f in "${FAILED_MODS[@]}"; do echo "  - $f"; done
  fi
  if [ "$DRY_RUN" != 1 ]; then
    {
      echo "Reporte de instalación - $(date)"
      echo
      echo "Aplicados sin errores (${#OK_MODS[@]}):"
      local m
      for m in "${OK_MODS[@]}"; do echo "  - $m"; done
      echo
      echo "Con errores (${#FAILED_MODS[@]}):"
      for m in "${FAILED_MODS[@]}"; do echo "  - $m"; done
    } > "$HOME/REPORTE-INSTALACION.txt"
    echo "Reporte guardado en ~/REPORTE-INSTALACION.txt"
  fi
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
  run_mod backup_snapshot
  run_mod region
  run_mod chrome
  run_mod chrome_autostart
  run_mod pwas
  run_mod onedrive
  run_mod cleanup_apps
  run_mod accounts
  run_mod acc_cal
  run_mod acc_contacts
  run_mod acc_mail
  run_mod drv_fw
  run_mod drv_hwe
  run_mod drv_rtl
  run_mod drv_bcm
  run_mod drv_wifi_ps
  run_mod drv_audio
  run_mod drv_audio_fw
  run_mod drv_audio_unmute
  run_mod drv_audio_jd
  run_mod drv_brightness
  run_mod zram
  run_mod perf_anim
  run_mod perf_tracker
  run_mod perf_power
  run_mod perf_services
  run_mod updates
  run_mod look_shelf
  run_mod look_wallpaper
  run_mod look_font
  run_mod look_icons
  run_mod look_scheme
  run_mod look_scroll
  run_mod look_touchpad
  run_mod look_keys
  run_mod look_favs
  manual "Aspecto: la barra, la letra y los íconos se ven completos al cerrar sesión y volver a entrar."
  finish
}
main "$@"
