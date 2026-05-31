#!/usr/bin/env bash
# =============================================================================
# Script de Automação: Niri + Noctalia Shell no Arch Linux
# Versão: 3.0 (Maio 2026)
# Descrição: Instala e configura o ambiente Niri (Wayland), Noctalia Shell,
#            drivers Nvidia e o gerenciador de login Lemurs no Arch Linux.
# =============================================================================

# --- Configurações de Segurança e Tratamento de Erros ---
set -euo pipefail

# --- Cores (usando $'...' para garantir interpretação correta de escape) ---
GREEN=$'\033[0;32m'
RED=$'\033[0;31m'
BLUE=$'\033[0;34m'
YELLOW=$'\033[0;33m'
CYAN=$'\033[0;36m'
BOLD=$'\033[1m'
NC=$'\033[0m'

# =============================================================================
# CONFIGURAÇÕES — ajuste aqui se necessário
# =============================================================================
KEYMAP="br"
VARIANT="abnt2"
TERMINAL="ghostty"
THEME="nord"
MONITOR_OUTPUT="DP-1"
MONITOR_RES="1920x1080@144"
USER_NAME="$(whoami)"
SYSTEM_LANG="en_US.UTF-8"
BROWSER="vivaldi"

# --- Variáveis internas ---
LOG_FILE="/tmp/niri_setup_$(date +%Y%m%d_%H%M%S).log"
TEMP_DIR="/tmp/niri_setup_temp_$$"
BACKUP_DIR="$HOME/niri_config_backup_$(date +%Y%m%d_%H%M%S)"
ERRORS=0

# =============================================================================
# FUNÇÕES DE LOG
# =============================================================================
log_info()    { echo -e "${BLUE}[INFO]   ${NC} $1" | tee -a "$LOG_FILE"; }
log_success() { echo -e "${GREEN}[OK]     ${NC} $1" | tee -a "$LOG_FILE"; }
log_warning() { echo -e "${YELLOW}[AVISO]  ${NC} $1" | tee -a "$LOG_FILE"; }
log_error()   { echo -e "${RED}${BOLD}[ERRO]   ${NC} $1" | tee -a "$LOG_FILE"; exit 1; }
log_skip()    { echo -e "${CYAN}[SKIP]   ${NC} $1" | tee -a "$LOG_FILE"; }

log_step() {
    local msg="$1"
    local line
    line=$(printf '═%.0s' {1..50})
    echo -e "\n${CYAN}${BOLD}╔${line}╗${NC}" | tee -a "$LOG_FILE"
    printf "${CYAN}${BOLD}║  %-48s  ║${NC}\n" "$msg" | tee -a "$LOG_FILE"
    echo -e "${CYAN}${BOLD}╚${line}╝${NC}\n" | tee -a "$LOG_FILE"
}

# =============================================================================
# FUNÇÕES AUXILIARES
# =============================================================================

cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_warning "Script interrompido (código: $exit_code). Limpando..."
    fi
    [[ -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Instala um ou mais pacotes via pacman (aceita array ou lista)
install_pacman() {
    local pkgs=("$@")
    log_info "Instalando via pacman: ${pkgs[*]}"
    sudo pacman -S --needed --noconfirm "${pkgs[@]}" \
        || log_error "Falha ao instalar: ${pkgs[*]}"
    log_success "Pacotes instalados: ${pkgs[*]}"
}

# Instala um pacote via yay; em caso de falha, registra e continua
install_aur() {
    local pkg="$1"
    log_info "Instalando $pkg via yay (AUR)..."
    if yay -S --noconfirm --needed "$pkg" 2>>"$LOG_FILE"; then
        log_success "$pkg instalado."
    else
        log_warning "Falha ao instalar $pkg via AUR. Instale manualmente após o boot."
        (( ERRORS++ )) || true
    fi
}

check_root() {
    [[ $EUID -eq 0 ]] && log_error "NÃO execute como root. Use como usuário normal com sudo disponível."
}

check_internet() {
    log_info "Verificando conexão com a internet..."
    # Tenta curl primeiro (mais confiável que ping em ambientes restritos)
    if command -v curl &>/dev/null; then
        curl -fsS --max-time 5 https://archlinux.org > /dev/null \
            || log_error "Sem conexão com a internet."
    elif command -v ping &>/dev/null; then
        ping -c 1 -W 5 archlinux.org &>/dev/null \
            || log_error "Sem conexão com a internet."
    else
        log_warning "curl e ping não encontrados. Assumindo conexão ativa."
    fi
    log_success "Internet OK."
}

check_disk_space() {
    log_info "Verificando espaço em disco (mínimo 6 GB)..."
    local available_kb
    available_kb=$(df -k / | awk 'NR==2 {print $4}')
    (( available_kb < 6291456 )) \
        && log_error "Espaço insuficiente em /. Libere pelo menos 6 GB."
    log_success "Espaço OK: $(( available_kb / 1024 / 1024 )) GB disponíveis."
}

detect_bootloader() {
    # Detecta se o sistema usa GRUB ou systemd-boot
    if [[ -f /etc/default/grub ]]; then
        echo "grub"
    elif [[ -d /boot/loader ]]; then
        echo "systemd-boot"
    else
        echo "unknown"
    fi
}

# Instala o yay se não estiver presente
ensure_yay() {
    if command -v yay &>/dev/null; then
        log_info "yay encontrado. Atualizando..."
        yay -Syu --noconfirm 2>>"$LOG_FILE" || log_warning "Falha ao atualizar yay. Continuando."
        return
    fi
    log_info "Instalando yay (AUR helper)..."
    git clone --depth=1 https://aur.archlinux.org/yay.git "$TEMP_DIR/yay" \
        || log_error "Falha ao clonar repositório yay."
    (cd "$TEMP_DIR/yay" && makepkg -si --noconfirm) \
        || log_error "Falha ao compilar yay."
    log_success "yay instalado."
}

# Habilita serviços de usuário sem --now (requer sessão ativa)
enable_user_service() {
    local svc="$1"
    if systemctl --user enable "$svc" 2>>"$LOG_FILE"; then
        log_success "Serviço de usuário habilitado: $svc"
    else
        log_warning "Não foi possível habilitar $svc agora. Será ativado no primeiro login."
        (( ERRORS++ )) || true
    fi
}

# =============================================================================
# PRÉ-VERIFICAÇÕES
# =============================================================================
check_root
check_internet
check_disk_space
mkdir -p "$TEMP_DIR"

# Inicia o log
echo "=== Niri Setup v3.0 — $(date) ===" >> "$LOG_FILE"
log_info "Log: $LOG_FILE"

# =============================================================================
# FASE 1 — BASE E BACKUPS
# =============================================================================
log_step "Fase 1 — Base e backups"

# Backup de configurações existentes
mkdir -p "$BACKUP_DIR"
for d in "$HOME/.config/niri" "$HOME/.config/fontconfig"; do
    if [[ -d "$d" ]]; then
        cp -r "$d" "$BACKUP_DIR/"
        log_info "Backup: $d → $BACKUP_DIR/"
    fi
done

log_info "Atualizando sistema..."
sudo pacman -Syu --noconfirm || log_error "Falha ao atualizar o sistema."

install_pacman base-devel git curl wget

# Configurar locale
if ! grep -q "^${SYSTEM_LANG} UTF-8" /etc/locale.gen; then
    sudo sed -i "s/^#${SYSTEM_LANG} UTF-8/${SYSTEM_LANG} UTF-8/" /etc/locale.gen
fi
sudo locale-gen || log_error "Falha ao gerar locale."
echo "LANG=${SYSTEM_LANG}" | sudo tee /etc/locale.conf > /dev/null
log_success "Locale configurado: $SYSTEM_LANG"

# =============================================================================
# FASE 2 — DRIVERS NVIDIA
# =============================================================================
log_step "Fase 2 — Drivers Nvidia"

install_pacman nvidia-dkms nvidia-utils libva-nvidia-driver linux-headers

# Configurar bootloader para KMS Nvidia
BOOTLOADER="$(detect_bootloader)"
log_info "Bootloader detectado: $BOOTLOADER"

case "$BOOTLOADER" in
    grub)
        if ! grep -q "nvidia_drm.modeset=1" /etc/default/grub; then
            sudo sed -i \
                's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="nvidia_drm.modeset=1 nvidia_drm.fbdev=1 /' \
                /etc/default/grub
            sudo grub-mkconfig -o /boot/grub/grub.cfg \
                || log_error "Falha ao atualizar GRUB."
            log_success "GRUB atualizado com parâmetros Nvidia KMS."
        else
            log_skip "nvidia_drm.modeset=1 já presente no GRUB."
        fi
        ;;
    systemd-boot)
        log_warning "systemd-boot detectado. Adicione manualmente ao arquivo de entrada de boot:"
        log_warning "  nvidia_drm.modeset=1 nvidia_drm.fbdev=1"
        log_warning "  Ex: /boot/loader/entries/arch.conf → linha 'options ...'"
        ;;
    *)
        log_warning "Bootloader não reconhecido. Adicione 'nvidia_drm.modeset=1 nvidia_drm.fbdev=1' manualmente."
        ;;
esac

# Módulo Nvidia: KMS + framebuffer
sudo tee /etc/modprobe.d/nvidia.conf > /dev/null << 'EOF'
# Habilita KMS e framebuffer Nvidia — obrigatório para Wayland (Niri)
options nvidia_drm modeset=1 fbdev=1
EOF

# Adicionar nvidia aos módulos do initramfs (necessário para KMS precoce)
if ! grep -q "^MODULES=.*nvidia" /etc/mkinitcpio.conf; then
    sudo sed -i 's/^MODULES=(\(.*\))/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' \
        /etc/mkinitcpio.conf
    sudo mkinitcpio -P || log_warning "Falha ao recompilar initramfs. Tente manualmente: sudo mkinitcpio -P"
    log_success "Módulos Nvidia adicionados ao initramfs."
else
    log_skip "Módulos Nvidia já presentes no initramfs."
fi

log_success "Drivers Nvidia configurados."

# =============================================================================
# FASE 3 — AUR (yay) E APLICATIVOS PRINCIPAIS
# =============================================================================
log_step "Fase 3 — yay e aplicativos"

ensure_yay

# Pacotes AUR (-git): podem ser instáveis — erros são registrados mas não fatais
log_info "Instalando Noctalia Shell e dependências (AUR)..."
AUR_PKGS=(
    noctalia-shell-git
    noctalia-qs-git
    xwayland-satellite-git   # compatibilidade X11 no Niri
    ghostty                  # terminal GPU-acelerado
    vivaldi                  # navegador
    lemurs                   # display manager TUI
    ttf-material-design-icons-desktop-git
    otf-font-awesome
)
for pkg in "${AUR_PKGS[@]}"; do
    install_aur "$pkg"
done

# Pacotes oficiais: Niri e stack Wayland
log_info "Instalando Niri e dependências oficiais..."
sudo pacman -S --needed --noconfirm \
    niri \
    cairo glib2 libdisplay-info libinput libxkbcommon mesa pango pixman seatd \
    xdg-desktop-portal xdg-desktop-portal-gnome xdg-desktop-portal-gtk \
    swaybg swayidle swaylock mako fuzzel \
    brightnessctl playerctl udiskie \
    thunar gvfs tumbler file-roller \
    qt6-base qt6-declarative qt6-wayland qt6-svg qt6-multimedia \
    qt6-imageformats qt6-tools \
    cmake ninja pkg-config meson imagemagick \
    pavucontrol blueman \
    || log_error "Falha ao instalar pacotes oficiais do Niri."

log_success "Aplicativos instalados."

# =============================================================================
# FASE 4 — ÁUDIO (PipeWire)
# =============================================================================
log_step "Fase 4 — Áudio (PipeWire)"

install_pacman pipewire pipewire-pulse pipewire-alsa pipewire-jack wireplumber

# Remover PulseAudio se instalado (conflita com pipewire-pulse)
if pacman -Qq pulseaudio &>/dev/null; then
    log_info "Removendo PulseAudio (conflita com PipeWire)..."
    sudo pacman -Rns --noconfirm pulseaudio pulseaudio-bluetooth 2>/dev/null || true
fi

# Os serviços de usuário só podem ser habilitados com sessão D-Bus ativa.
# Tentamos aqui; se falhar, será ativado no primeiro login.
for svc in pipewire.service pipewire-pulse.service wireplumber.service; do
    enable_user_service "$svc"
done

log_success "PipeWire configurado."

# =============================================================================
# FASE 5 — BLUETOOTH
# =============================================================================
log_step "Fase 5 — Bluetooth"

install_pacman bluez bluez-utils

sudo systemctl enable --now bluetooth.service \
    || log_warning "Falha ao habilitar Bluetooth. Verifique manualmente."
log_success "Bluetooth habilitado."

# =============================================================================
# FASE 6 — FONTES
# =============================================================================
log_step "Fase 6 — Fontes"

install_pacman \
    ttf-jetbrains-mono-nerd ttf-firacode-nerd \
    ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono \
    noto-fonts noto-fonts-emoji noto-fonts-cjk ttf-liberation \
    papirus-icon-theme hicolor-icon-theme adwaita-icon-theme

# Fontconfig: renderização suave com LCD filter
mkdir -p "$HOME/.config/fontconfig"
cat > "$HOME/.config/fontconfig/fonts.conf" << 'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <include ignore_missing="yes">/etc/fonts/fonts.conf</include>
  <match target="font">
    <edit name="antialias"  mode="assign"><bool>true</bool></edit>
    <edit name="hinting"    mode="assign"><bool>true</bool></edit>
    <edit name="hintstyle"  mode="assign"><const>hintslight</const></edit>
    <edit name="rgba"       mode="assign"><const>rgb</const></edit>
    <edit name="lcdfilter"  mode="assign"><const>lcddefault</const></edit>
    <edit name="autohint"   mode="assign"><bool>false</bool></edit>
  </match>
  <!-- Prioriza fontes Nerd para símbolos -->
  <alias>
    <family>monospace</family>
    <prefer>
      <family>JetBrainsMono Nerd Font Mono</family>
      <family>FiraCode Nerd Font Mono</family>
    </prefer>
  </alias>
</fontconfig>
EOF

fc-cache -fv 2>>"$LOG_FILE" || log_warning "Falha ao regenerar cache de fontes."
log_success "Fontes instaladas e cache atualizado."

# =============================================================================
# FASE 7 — CONFIGURAÇÃO DO NIRI
# =============================================================================
log_step "Fase 7 — Configuração do Niri"

mkdir -p "$HOME/.config/niri"

# Usa variáveis do script dentro do heredoc (sem aspas simples no KDLEOF)
cat > "$HOME/.config/niri/config.kdl" << KDLEOF
// =============================================================================
// Niri Config — Noctalia Shell | Tema: ${THEME} | Monitor: ${MONITOR_OUTPUT} | ${MONITOR_RES}
// Gerado por setup-niri-noctalia-v3.0.sh
// =============================================================================

environment {
    "XDG_CURRENT_DESKTOP"                 "niri"
    "XDG_SESSION_TYPE"                    "wayland"
    "XDG_SESSION_DESKTOP"                 "niri"
    "GTK_THEME"                           "adw-gtk3-dark"
    "GTK_BACKEND"                         "wayland,x11"
    "GDK_BACKEND"                         "wayland,x11"
    "QT_QPA_PLATFORM"                     "wayland;xcb"
    "QT_WAYLAND_DISABLE_WINDOWDECORATION" "1"
    "QT_AUTO_SCREEN_SCALE_FACTOR"         "1"
    "XCURSOR_THEME"                       "Adwaita"
    "XCURSOR_SIZE"                        "24"
    "MOZ_ENABLE_WAYLAND"                  "1"
    "MOZ_WEBRENDER"                       "1"
    "ELECTRON_OZONE_PLATFORM_HINT"        "wayland"
    "SDL_VIDEODRIVER"                     "wayland"
    "CLUTTER_BACKEND"                     "wayland"
    "NOCTALIA_THEME"                      "${THEME}"

    // Nvidia — obrigatório para Wayland funcionar sem artefatos/cursor invisível
    "WLR_NO_HARDWARE_CURSORS"             "1"
    "__GLX_VENDOR_LIBRARY_NAME"           "nvidia"
    "LIBVA_DRIVER_NAME"                   "nvidia"
    "GBM_BACKEND"                         "nvidia-drm"
    "__NV_PRIME_RENDER_OFFLOAD"           "1"
}

// =============================================================================
// Serviços iniciados com o Niri
// =============================================================================
spawn-at-startup "xwayland-satellite"
spawn-at-startup "swaybg" "-m" "fill" "-i" "/usr/share/backgrounds/archlinux/archlinux-firestarter.jpg"
spawn-at-startup "udiskie" "--tray"
spawn-at-startup "mako"
spawn-sh-at-startup "swayidle -w timeout 300 'swaylock -f -c 2e3440' timeout 600 'niri msg action power-off-monitors' before-sleep 'swaylock -f -c 2e3440'"
spawn-at-startup "qs" "-c" "noctalia-shell"

// =============================================================================
// Input
// =============================================================================
input {
    keyboard {
        xkb {
            layout  "${KEYMAP}"
            variant "${VARIANT}"
            options "caps:escape"
        }
        repeat-delay 300
        repeat-rate  50
        numlock
    }
    touchpad {
        tap
        tap-button-map "left-right-middle"
        dwt
        natural-scroll
        accel-speed   0.2
        accel-profile "adaptive"
        scroll-method "two-finger"
        click-method  "clickfinger"
    }
    mouse {
        accel-speed   0.0
        accel-profile "flat"
    }
    // Oculta o cursor após inatividade (ms)
    focus-follows-mouse max-scroll-amount="0%"
}

// =============================================================================
// Monitor
// =============================================================================
// Se o Niri não reconhecer a saída, rode em outro TTY:
//   niri msg outputs
// e substitua "DP-1" pelo nome correto em ~/.config/niri/config.kdl
output "${MONITOR_OUTPUT}" {
    mode      "${MONITOR_RES}"
    scale     1.0
    transform "normal"
    position  x=0 y=0
}

// =============================================================================
// Layout
// =============================================================================
layout {
    gaps 8
    center-focused-column "never"
    always-center-single-column

    preset-column-widths {
        proportion 0.33333
        proportion 0.5
        proportion 0.66667
        fixed 1280
    }
    default-column-width { proportion 0.5; }

    // Cores Nord
    focus-ring {
        width          2
        active-color   "#88c0d0"   // Nord 8 — azul glacial
        inactive-color "#3b4252"   // Nord 1 — escuro
    }
    border { off; }
    struts { left 0; right 0; top 0; bottom 0; }
}

// =============================================================================
// Animações
// =============================================================================
animations {
    slowdown 1.0
    workspace-switch { spring damping-ratio=1.0 stiffness=1000 epsilon=0.0001; }
    window-open      { duration-ms 150; curve "ease-out-expo"; }
    window-close     { duration-ms 100; curve "ease-out-quad"; }
    window-movement  { spring damping-ratio=1.0 stiffness=800 epsilon=0.0001; }
    window-resize    { spring damping-ratio=1.0 stiffness=800 epsilon=0.0001; }
    horizontal-view-movement { spring damping-ratio=1.0 stiffness=800 epsilon=0.0001; }
}

// =============================================================================
// Regras de janela
// =============================================================================
window-rule {
    geometry-corner-radius 8
    clip-to-geometry true
}

// Aplicativos flutuantes por padrão
window-rule {
    match app-id=r#"(pavucontrol|blueman-manager|nm-applet|file-roller)"#
    open-floating true
}

// =============================================================================
// Atalhos de teclado
// =============================================================================
binds {
    // — Aplicativos principais —
    Mod+Return      { spawn "${TERMINAL}"; }
    Mod+E           { spawn "thunar"; }
    Mod+B           { spawn "${BROWSER}"; }

    // — Noctalia Shell: IPC Toggles —
    Mod+Space       { spawn "qs" "-c" "noctalia-shell" "ipc" "call" "plugin:launcher" "toggle"; }
    Mod+C           { spawn "qs" "-c" "noctalia-shell" "ipc" "call" "plugin:control-center" "toggle"; }
    Mod+P           { spawn "qs" "-c" "noctalia-shell" "ipc" "call" "plugin:power-menu" "toggle"; }
    Mod+N           { spawn "qs" "-c" "noctalia-shell" "ipc" "call" "plugin:notifications" "toggle"; }
    Mod+Shift+R     { spawn "qs" "-c" "noctalia-shell" "ipc" "call" "core:config" "reload"; }

    // — Bloqueio de tela —
    Mod+L           { spawn "swaylock" "-f" "-c" "2e3440"; }
    Super+L         { spawn "swaylock" "-f" "-c" "2e3440"; }

    // — Captura de tela —
    Print           { screenshot; }
    Ctrl+Print      { screenshot-screen; }
    Alt+Print       { screenshot-window; }

    // — Gestão de janelas —
    Mod+Q           { close-window; }
    Mod+Shift+Q     { quit skip-confirmation=true; }

    // — Navegação de foco (H/J/K/M para evitar conflito com Mod+L) —
    Mod+H           { focus-column-left; }
    Mod+M           { focus-column-right; }
    Mod+K           { focus-window-up; }
    Mod+J           { focus-window-down; }

    Mod+Shift+H     { move-column-left; }
    Mod+Shift+M     { move-column-right; }
    Mod+Shift+K     { move-window-up; }
    Mod+Shift+J     { move-window-down; }

    // Navegação rápida
    Mod+Home        { focus-column-first; }
    Mod+End         { focus-column-last; }

    // — Redimensionar —
    Mod+Minus       { set-column-width "-10%"; }
    Mod+Equal       { set-column-width "+10%"; }
    Mod+Shift+Minus { set-window-height "-10%"; }
    Mod+Shift+Equal { set-window-height "+10%"; }

    // — Maximizar / fullscreen —
    Mod+F           { maximize-column; }
    Mod+Shift+F     { fullscreen-window; }

    // — Janela flutuante —
    Mod+V           { toggle-window-floating; }
    Mod+Shift+V     { switch-focus-between-floating-and-tiling; }

    // — Centrar —
    Mod+Shift+C     { center-column; }

    // — Preset de larguras —
    Mod+R           { switch-preset-column-width; }

    // — Workspaces —
    Mod+1 { focus-workspace 1; }
    Mod+2 { focus-workspace 2; }
    Mod+3 { focus-workspace 3; }
    Mod+4 { focus-workspace 4; }
    Mod+5 { focus-workspace 5; }
    Mod+6 { focus-workspace 6; }
    Mod+7 { focus-workspace 7; }
    Mod+8 { focus-workspace 8; }
    Mod+9 { focus-workspace 9; }

    Mod+Shift+1 { move-column-to-workspace 1; }
    Mod+Shift+2 { move-column-to-workspace 2; }
    Mod+Shift+3 { move-column-to-workspace 3; }
    Mod+Shift+4 { move-column-to-workspace 4; }
    Mod+Shift+5 { move-column-to-workspace 5; }
    Mod+Shift+6 { move-column-to-workspace 6; }
    Mod+Shift+7 { move-column-to-workspace 7; }
    Mod+Shift+8 { move-column-to-workspace 8; }
    Mod+Shift+9 { move-column-to-workspace 9; }

    Mod+Tab         { focus-workspace-down; }
    Mod+Shift+Tab   { focus-workspace-up; }

    // — Controle de mídia —
    XF86AudioPlay        { spawn "playerctl" "play-pause"; }
    XF86AudioStop        { spawn "playerctl" "stop"; }
    XF86AudioNext        { spawn "playerctl" "next"; }
    XF86AudioPrev        { spawn "playerctl" "previous"; }

    // — Controle de volume —
    XF86AudioRaiseVolume  { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+"; }
    XF86AudioLowerVolume  { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }
    XF86AudioMute         { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
    XF86AudioMicMute      { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle"; }

    // — Controle de brilho —
    XF86MonBrightnessUp   { spawn "brightnessctl" "set" "5%+"; }
    XF86MonBrightnessDown { spawn "brightnessctl" "set" "5%-"; }
}
KDLEOF

log_success "Configuração do Niri (config.kdl) criada."

# =============================================================================
# FASE 8 — DISPLAY MANAGER (Lemurs)
# =============================================================================
log_step "Fase 8 — Lemurs DM"

# Desabilitar outros DMs se ativos
for dm in sddm gdm lightdm lxdm; do
    if systemctl is-enabled "$dm" &>/dev/null; then
        sudo systemctl disable "$dm" --now &>/dev/null || true
        log_info "$dm desabilitado."
    fi
done

# Arquivo de sessão Wayland para Niri
log_info "Criando /usr/share/wayland-sessions/niri.desktop..."
sudo mkdir -p /usr/share/wayland-sessions
sudo tee /usr/share/wayland-sessions/niri.desktop > /dev/null << 'EOF'
[Desktop Entry]
Name=Niri
Comment=A scrollable-tiling Wayland compositor
Exec=/usr/bin/niri-session
TryExec=niri
Type=Application
DesktopNames=niri
EOF
log_success "niri.desktop criado."

# Wrapper de sessão: garante que D-Bus e variáveis XDG estejam disponíveis
if [[ ! -f /usr/bin/niri-session ]]; then
    sudo tee /usr/bin/niri-session > /dev/null << 'EOF'
#!/usr/bin/env bash
# Wrapper de sessão Niri: garante D-Bus e variáveis XDG corretas
export XDG_SESSION_TYPE=wayland
export XDG_SESSION_DESKTOP=niri
export XDG_CURRENT_DESKTOP=niri

# Inicia D-Bus se não estiver rodando
if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
    eval "$(dbus-launch --sh-syntax --exit-with-session)"
fi

# Importa variáveis para o ambiente systemd do usuário
systemctl --user import-environment \
    XDG_SESSION_TYPE XDG_SESSION_DESKTOP XDG_CURRENT_DESKTOP \
    DBUS_SESSION_BUS_ADDRESS DISPLAY WAYLAND_DISPLAY 2>/dev/null || true

exec niri
EOF
    sudo chmod +x /usr/bin/niri-session
    log_success "niri-session wrapper criado."
fi

# Configurar Lemurs
log_info "Configurando /etc/lemurs/config.toml..."
sudo mkdir -p /etc/lemurs
sudo tee /etc/lemurs/config.toml > /dev/null << 'EOF'
# Lemurs — Display Manager Configuration

[tty]
tty = 2

[auth]
# Usa PAM para autenticação
pam_service = "lemurs"

[sessions]
# Diretório com arquivos .desktop das sessões Wayland
wayland_sessions_path = "/usr/share/wayland-sessions"
# Sessão padrão ao iniciar
default_session = "Niri"
EOF
log_success "/etc/lemurs/config.toml configurado."

# Habilitar Lemurs
sudo systemctl enable lemurs.service \
    || log_error "Falha ao habilitar Lemurs. Verifique a instalação do pacote 'lemurs'."
log_success "Lemurs habilitado (ativa no próximo boot)."

# =============================================================================
# FASE 9 — GRUPOS E SERVIÇOS DO SISTEMA
# =============================================================================
log_step "Fase 9 — Grupos e serviços"

# Ativar seatd (necessário para acesso a dispositivos sem root)
sudo systemctl enable --now seatd.service \
    || log_warning "seatd não pôde ser iniciado. Verifique manualmente."

# Adicionar usuário aos grupos necessários
sudo usermod -aG seat,video,audio,input,storage,bluetooth "$USER_NAME" \
    || log_error "Falha ao adicionar $USER_NAME aos grupos necessários."
log_success "Usuário $USER_NAME adicionado aos grupos: seat, video, audio, input, storage, bluetooth."

# Regenerar initramfs final (garante módulos Nvidia)
log_info "Regenerando initramfs..."
sudo mkinitcpio -P 2>>"$LOG_FILE" \
    || log_warning "Falha ao regenerar initramfs. Execute 'sudo mkinitcpio -P' manualmente."
log_success "Initramfs atualizado."

# =============================================================================
# CHECKLIST PÓS-INSTALAÇÃO
# =============================================================================
log_step "Instalação concluída"

echo -e "\n${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════╗"
echo -e "║        CHECKLIST PÓS-INSTALAÇÃO — LEIA ANTES DE REINICIAR   ║"
echo -e "╚══════════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${GREEN}${BOLD}1. Validar configuração do Niri:${NC}"
echo -e "   niri validate --config ~/.config/niri/config.kdl\n"

echo -e "${GREEN}${BOLD}2. Confirmar nome da saída de vídeo:${NC}"
echo -e "   Em outro TTY (Ctrl+Alt+F2): niri msg outputs"
echo -e "   → Se diferente de '${MONITOR_OUTPUT}', edite:"
echo -e "     ~/.config/niri/config.kdl → linha: output \"${MONITOR_OUTPUT}\" {...}\n"

echo -e "${GREEN}${BOLD}3. Testar áudio:${NC}"
echo -e "   speaker-test -t wav -c 2\n"

echo -e "${GREEN}${BOLD}4. Testar Bluetooth:${NC}"
echo -e "   bluetoothctl → power on → scan on → exit\n"

echo -e "${GREEN}${BOLD}5. Reiniciar:${NC}"
echo -e "   sudo reboot\n"

echo -e "${GREEN}${BOLD}6. Após primeiro login, verificar serviços:${NC}"
echo -e "   systemctl --user status pipewire wireplumber"
echo -e "   pactl info | grep 'Server Name'\n"

echo -e "${YELLOW}${BOLD}DICA — Tela preta após login:${NC}"
echo -e "   Ctrl+Alt+F2 → login → journalctl -xe | grep -i 'niri\|nvidia\|drm'\n"

echo -e "${YELLOW}${BOLD}DICA — Lemurs não aparece:${NC}"
echo -e "   journalctl -u lemurs.service --no-pager | tail -30\n"

if (( ERRORS > 0 )); then
    echo -e "${YELLOW}${BOLD}ATENÇÃO: $ERRORS pacote(s) AUR falharam. Verifique o log:${NC}"
    echo -e "   $LOG_FILE\n"
fi

echo -e "${BLUE}Log completo: $LOG_FILE${NC}\n" | tee -a "$LOG_FILE"

log_success "==========================================================="
log_success "  INSTALAÇÃO CONCLUÍDA${ERRORS:+ (com $ERRORS avisos AUR)}"
log_success "==========================================================="
log_info "REINICIE O SISTEMA AGORA: sudo reboot"
log_info "Selecione 'Niri' no Lemurs após o boot."