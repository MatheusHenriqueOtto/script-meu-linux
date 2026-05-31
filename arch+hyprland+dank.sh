#!/bin/bash

# Script de automação para Arch Linux com Hyprland e DMS
# Gerado por Manus AI para Matheus
# Versão: 1.1 (Substituído SDDM por Lemurs)

# --- Variáveis de Configuração ---
USER_NAME="matheus"
KEYBOARD_LAYOUT="br-abnt2"
TERMINAL_CHOICE="kitty"

# --- Funções de Log ---
log_info() {
    echo -e "\e[32m[INFO]\e[0m $1"
}

log_warn() {
    echo -e "\e[33m[WARN]\e[0m $1"
}

log_error() {
    echo -e "\e[31m[ERROR]\e[0m $1"
    exit 1
}

# --- Pré-requisitos e Verificações Iniciais ---
log_info "Iniciando script de configuração do Arch Linux com Hyprland e DMS."
log_info "Configuração personalizada para Matheus: Usando Lemurs como Display Manager."

if [ "$(whoami)" == "root" ]; then
    log_error "Este script NÃO deve ser executado como root. Por favor, execute como seu usuário normal: ./setup.sh"
fi

# --- Fase 1: Validação da Base Mínima ---
log_info "Fase 1: Validando a base mínima do sistema..."
sudo systemctl enable --now NetworkManager || log_error "Falha ao ativar NetworkManager."
sudo pacman -Syu --noconfirm || log_error "Falha na atualização inicial do sistema."

# --- Fase 2: Dependências Gráficas, Áudio e Sistema ---
log_info "Fase 2: Instalando dependências gráficas, áudio e sistema..."
# Removido sddm da lista de pacotes
sudo pacman -S --noconfirm --needed \
  hyprland \
  xdg-desktop-portal \
  xdg-desktop-portal-hyprland \
  xdg-user-dirs \
  pipewire \
  wireplumber \
  pipewire-alsa \
  pipewire-pulse \
  pipewire-jack \
  alsa-utils \
  pavucontrol \
  bluez \
  bluez-utils \
  blueman \
  brightnessctl \
  upower \
  acpi \
  wl-clipboard \
  cliphist \
  polkit \
  polkit-kde-agent \
  network-manager-applet \
  accountsservice \
  qt5-wayland \
  qt6-wayland \
  qt6-base \
  qt6-multimedia \
  playerctl \
  grim \
  slurp \
  curl \
  wget \
  unzip \
  nvidia-dkms \
  nvidia-utils \
  egl-wayland \
  libva-nvidia-driver \
  vulkan-icd-loader \
  libva \
  libvdpau \
  opencl-nvidia || log_error "Falha ao instalar pacotes da Fase 2."

sudo usermod -aG video "$USER_NAME"

# --- Fase 3: AUR Helper (Yay) ---
log_info "Fase 3: Instalando AUR Helper (Yay)..."
sudo pacman -S --noconfirm --needed git base-devel
cd /tmp
rm -rf yay # Limpa clones anteriores
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
cd ~
yay -Syu --noconfirm

# --- Fase 4: Fontes e Cache de Renderização ---
log_info "Fase 4: Instalando fontes..."
sudo pacman -S --noconfirm --needed \
  ttf-inter \
  ttf-fira-code \
  nerd-fonts \
  noto-fonts \
  noto-fonts-emoji \
  ttf-font-awesome \
  ttf-nerd-fonts-symbols

sudo mkdir -p /usr/share/fonts/material-symbols
sudo curl -L \
  "https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf" \
  -o /usr/share/fonts/material-symbols/MaterialSymbolsRounded.ttf

sudo fc-cache -fv && fc-cache -fv

# --- Fase 5: DMS, Quickshell e Apps Core (AUR) ---
log_info "Fase 5: Instalando DMS, Quickshell e Lemurs..."
# Adicionado lemurs na instalação via yay
yay -S --noconfirm --needed \
  quickshell-git \
  dms-shell-git \
  dgop-bin \
  matugen-bin \
  lemurs || log_error "Falha ao instalar pacotes via yay."

sudo pacman -S --noconfirm kitty cava adw-gtk-theme

# --- Fase 6: Configuração do Hyprland para o DMS ---
log_info "Fase 6: Configurando Hyprland..."
mkdir -p ~/.config/hypr

cat << EOF > ~/.config/hypr/hyprland.conf
#################################################################
# DANK Material Shell — Hyprland Config
#################################################################
$mod = SUPER
$terminal = $TERMINAL_CHOICE

# Variáveis Wayland / Nvidia
env = XDG_CURRENT_DESKTOP,Hyprland
env = XDG_SESSION_TYPE,wayland
env = XDG_SESSION_DESKTOP,Hyprland
env = QT_QPA_PLATFORM,wayland;xcb
env = QT_WAYLAND_DISABLE_WINDOWDECORATION,1
env = QT_AUTO_SCREEN_SCALE_FACTOR,1
env = MOZ_ENABLE_WAYLAND,1
env = ELECTRON_OZONE_PLATFORM_HINT,wayland
env = LIBVA_DRIVER_NAME,nvidia
env = GBM_BACKEND,nvidia-drm
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = WLR_NO_HARDWARE_CURSORS,1

monitor=,preferred,auto,1

exec-once = dbus-update-activation-environment --all
exec-once = systemctl --user import-environment DISPLAY WAYLAND_DISPLAY SWAYSOCK
exec-once = /usr/lib/polkit-kde-authentication-agent-1
exec-once = dms run &

# Atalhos Básicos
bind = \$mod, RETURN, exec, \$terminal
bind = \$mod, Q,      killactive
bind = \$mod, F,      fullscreen
bind = \$mod SHIFT, F, togglefloating

# Workspaces
bind = \$mod, 1, workspace, 1
bind = \$mod, 2, workspace, 2
bind = \$mod, 3, workspace, 3
bind = \$mod, 4, workspace, 4
bind = \$mod, 5, workspace, 5
bind = \$mod, 6, workspace, 6
bind = \$mod, 7, workspace, 7
bind = \$mod, 8, workspace, 8
bind = \$mod, 9, workspace, 9

bind = \$mod SHIFT, 1, movetoworkspace, 1
bind = \$mod SHIFT, 2, movetoworkspace, 2
bind = \$mod SHIFT, 3, movetoworkspace, 3
bind = \$mod SHIFT, 4, movetoworkspace, 4
bind = \$mod SHIFT, 5, movetoworkspace, 5
bind = \$mod SHIFT, 6, movetoworkspace, 6
bind = \$mod SHIFT, 7, movetoworkspace, 7
bind = \$mod SHIFT, 8, movetoworkspace, 8
bind = \$mod SHIFT, 9, movetoworkspace, 9

# Mouse
bindm = \$mod, mouse:272, movewindow
bindm = \$mod, mouse:273, resizewindow

# Aparência
general {
    gaps_in = 4
    gaps_out = 8
    border_size = 2
    col.active_border = rgba(88c0d0ff) rgba(81a1c1ff) 45deg
    col.inactive_border = rgba(2e3440aa)
}

decoration {
    rounding = 12
    blur {
        enabled = true
        size = 6
        passes = 3
    }
}

input {
    kb_layout = $KEYBOARD_LAYOUT
    follow_mouse = 1
    touchpad {
        natural_scroll = true
    }
}

misc {
    disable_hyprland_logo = true
    vfr = true
}
EOF

# --- Fase 7: Ativação de Serviços e Lemurs ---
log_info "Fase 7: Configurando Lemurs e Serviços..."

# 7.1 - Ativar Lemurs
sudo systemctl enable lemurs || log_error "Falha ao ativar Lemurs."

# 7.2 - Configurar Lemurs para Wayland (Hyprland)
# O Lemurs procura scripts em /etc/lemurs/wms ou usa arquivos .desktop em /usr/share/wayland-sessions/
# Vamos garantir que ele tenha acesso ao Hyprland.
sudo mkdir -p /etc/lemurs/wms
if [ ! -f "/etc/lemurs/wms/hyprland" ]; then
    echo "exec Hyprland" | sudo tee /etc/lemurs/wms/hyprland
    sudo chmod +x /etc/lemurs/wms/hyprland
fi

# 7.3 - Outros serviços
sudo systemctl enable bluetooth
systemctl --user enable pipewire pipewire-pulse wireplumber

# --- Fase 8: Wallpapers ---
log_info "Fase 8: Wallpapers..."
mkdir -p ~/Pictures/wallpapers
git clone https://github.com/mylinuxforwork/wallpaper ~/Pictures/wallpapers || log_warn "Falha ao clonar wallpapers."

# --- Instalação do Vivaldi ---
log_info "Instalando Vivaldi..."
yay -S --noconfirm vivaldi || log_error "Falha ao instalar Vivaldi."

# --- Finalização ---
log_info "Script concluído!"
log_info "Reinicie o sistema: sudo reboot"
log_info "No Lemurs, use as setas para selecionar 'hyprland' e digite seu usuário e senha."
