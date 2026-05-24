#!/bin/bash
# =============================================================================
#  setup.sh — Arch Linux + Hyprland + DMS (DANK)
#  Hardware: Ryzen 5 5600 (AMD CPU) + GTX 1050 (NVIDIA GPU)
#  Fases: 2 → 7
# =============================================================================

set -e  # Para o script se qualquer comando falhar

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
info() { echo -e "${CYAN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[AVISO]${NC} $1"; }
fail() { echo -e "${RED}[ERRO]${NC} $1"; exit 1; }

# =============================================================================
#  FASE 2 — Atualização do sistema e instalação do yay
# =============================================================================
info "=== FASE 2: Atualizando sistema e instalando yay ==="

sudo pacman -Syu --noconfirm || fail "Falha ao atualizar o sistema"
ok "Sistema atualizado"

# Verifica se base-devel está instalado
sudo pacman -S --needed --noconfirm base-devel git || fail "Falha ao instalar base-devel/git"

# Instala o yay se não estiver presente
if ! command -v yay &>/dev/null; then
    info "Instalando yay..."
    cd /tmp
    rm -rf yay
    git clone https://aur.archlinux.org/yay.git || fail "Falha ao clonar yay"
    cd yay
    makepkg -si --noconfirm || fail "Falha ao compilar yay"
    cd ~
    ok "yay instalado"
else
    ok "yay já está instalado, pulando"
fi

yay --version || fail "yay não está funcionando"

# =============================================================================
#  FASE 2.5 — Drivers NVIDIA (GTX 1050 + Wayland)
# =============================================================================
info "=== FASE 2.5: Instalando drivers NVIDIA para Wayland ==="

sudo pacman -S --needed --noconfirm \
    nvidia \
    nvidia-utils \
    nvidia-settings \
    libva-nvidia-driver \
    || fail "Falha ao instalar drivers NVIDIA"

ok "Drivers NVIDIA instalados"

# Adiciona módulos NVIDIA ao mkinitcpio
info "Configurando módulos NVIDIA no mkinitcpio..."
if ! grep -q "nvidia nvidia_modeset nvidia_uvm nvidia_drm" /etc/mkinitcpio.conf; then
    sudo sed -i 's/^MODULES=(\(.*\))/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
    ok "Módulos NVIDIA adicionados ao mkinitcpio.conf"
else
    ok "Módulos NVIDIA já estavam no mkinitcpio.conf"
fi

# Habilita DRM para Wayland (necessário para Hyprland + NVIDIA)
info "Habilitando nvidia-drm.modeset=1 no bootloader..."
GRUB_CONF="/etc/default/grub"
SYSTEMD_BOOT_ENTRY=$(ls /boot/loader/entries/*.conf 2>/dev/null | head -n1)

if [ -f "$GRUB_CONF" ]; then
    if ! grep -q "nvidia-drm.modeset=1" "$GRUB_CONF"; then
        sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 nvidia-drm.modeset=1"/' "$GRUB_CONF"
        sudo grub-mkconfig -o /boot/grub/grub.cfg
        ok "nvidia-drm.modeset=1 adicionado ao GRUB"
    else
        ok "nvidia-drm.modeset=1 já estava no GRUB"
    fi
elif [ -n "$SYSTEMD_BOOT_ENTRY" ]; then
    if ! grep -q "nvidia-drm.modeset=1" "$SYSTEMD_BOOT_ENTRY"; then
        sudo sed -i 's/^options \(.*\)/options \1 nvidia-drm.modeset=1/' "$SYSTEMD_BOOT_ENTRY"
        ok "nvidia-drm.modeset=1 adicionado ao systemd-boot"
    else
        ok "nvidia-drm.modeset=1 já estava no systemd-boot"
    fi
else
    warn "Bootloader não detectado automaticamente. Adicione nvidia-drm.modeset=1 manualmente nos parâmetros do kernel."
fi

sudo mkinitcpio -P || fail "Falha ao regenerar initramfs"
ok "initramfs regenerado"

# =============================================================================
#  FASE 3 — Pacotes AUR do DMS
# =============================================================================
info "=== FASE 3: Instalando pacotes AUR do DMS ==="

yay -S --needed --noconfirm \
    dms-shell-git \
    quickshell-git \
    matugen-bin \
    dgop-bin \
    || fail "Falha ao instalar pacotes AUR do DMS"

ok "Pacotes AUR do DMS instalados"

pacman -Q dms-shell-git quickshell-git matugen-bin dgop-bin \
    && ok "Verificação dos pacotes AUR: OK" \
    || warn "Alguns pacotes AUR podem não ter sido instalados corretamente"

# =============================================================================
#  FASE 4 — Fontes do Material Design
# =============================================================================
info "=== FASE 4: Instalando fontes Material Design ==="

sudo mkdir -p /usr/local/share/fonts

info "Baixando Material Symbols Rounded..."
sudo curl -fL \
    "https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf" \
    -o /usr/local/share/fonts/MaterialSymbolsRounded.ttf \
    || warn "Falha ao baixar MaterialSymbolsRounded — verifique manualmente"

info "Baixando Inter Variable..."
sudo curl -fL \
    "https://github.com/rsms/inter/raw/refs/tags/v4.1/docs/font-files/InterVariable.ttf" \
    -o /usr/local/share/fonts/InterVariable.ttf \
    || warn "Falha ao baixar InterVariable — verifique manualmente"

info "Baixando Fira Code Regular..."
sudo curl -fL \
    "https://github.com/tonsky/FiraCode/releases/latest/download/FiraCode-Regular.ttf" \
    -o /usr/local/share/fonts/FiraCode-Regular.ttf \
    || warn "Falha ao baixar FiraCode-Regular — verifique manualmente"

info "Atualizando cache de fontes..."
fc-cache -fv || warn "Falha ao atualizar cache de fontes"

ok "Fontes instaladas"

# Verificação
fc-match Inter       && ok "Fonte Inter: OK"    || warn "Fonte Inter não encontrada"
fc-match "Fira Code" && ok "Fonte Fira Code: OK" || warn "Fonte Fira Code não encontrada"
fc-match "Material Symbols Rounded" \
    && ok "Fonte Material Symbols: OK" \
    || warn "Fonte Material Symbols não encontrada"

# =============================================================================
#  FASE 5 — Configuração do Hyprland integrada ao DMS
# =============================================================================
info "=== FASE 5: Criando configuração do Hyprland ==="

mkdir -p ~/.config/hypr

# Faz backup se já existir
if [ -f ~/.config/hypr/hyprland.conf ]; then
    cp ~/.config/hypr/hyprland.conf ~/.config/hypr/hyprland.conf.bak
    warn "Backup do hyprland.conf existente salvo em hyprland.conf.bak"
fi

cat > ~/.config/hypr/hyprland.conf << 'EOF'
# =============================================================
#  Hyprland config — Ryzen 5 5600 + GTX 1050 + DMS (DANK)
# =============================================================

$mainMod = SUPER

# --- Variáveis de ambiente Wayland + NVIDIA ---
env = XDG_CURRENT_DESKTOP,Hyprland
env = XDG_SESSION_TYPE,wayland
env = WAYLAND_DISPLAY,wayland-1
env = QT_QPA_PLATFORM,wayland
env = QT_WAYLAND_DISABLE_WINDOWDECORATION,1
env = GDK_BACKEND,wayland,x11
env = SDL_VIDEODRIVER,wayland
env = LIBVA_DRIVER_NAME,nvidia
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = WLR_NO_HARDWARE_CURSORS,1

monitor=,preferred,auto,1

# --- Autostart ---
exec-once = dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
exec-once = wl-paste --type text --watch cliphist store
exec-once = wl-paste --type image --watch cliphist store
exec-once = dms run

# --- Atalhos DMS ---
bind = $mainMod, SPACE, exec, dms ipc call spotlight toggle
bind = $mainMod, C,     exec, dms ipc call control-center toggle
bind = $mainMod, V,     exec, dms ipc call clipboard toggle
bind = $mainMod, N,     exec, dms ipc call notifications toggle
bind = $mainMod, X,     exec, dms ipc call powermenu toggle
bind = $mainMod, Y,     exec, dms ipc call dankdash wallpaper
bind = $mainMod, TAB,   exec, dms ipc call hypr toggleOverview

# --- Áudio ---
bindl = , XF86AudioRaiseVolume, exec, dms ipc call audio increment 3
bindl = , XF86AudioLowerVolume, exec, dms ipc call audio decrement 3
bindl = , XF86AudioMute,        exec, dms ipc call audio mute
bindl = , XF86AudioMicMute,     exec, dms ipc call audio micmute

# --- Brilho ---
bindl = , XF86MonBrightnessUp,   exec, dms ipc call brightness increment 5 ""
bindl = , XF86MonBrightnessDown, exec, dms ipc call brightness decrement 5 ""

# --- Layout e visual ---
general {
    gaps_in  = 5
    gaps_out = 10
    border_size = 2
}

decoration {
    rounding = 10
}
EOF

ok "hyprland.conf criado em ~/.config/hypr/hyprland.conf"

grep -n "dms run"   ~/.config/hypr/hyprland.conf && ok "exec-once dms run: presente"
grep -n "cliphist"  ~/.config/hypr/hyprland.conf && ok "cliphist: presente"
grep -n "nvidia"    ~/.config/hypr/hyprland.conf && ok "variáveis NVIDIA: presentes"

# =============================================================================
#  FASE 6 — Serviços e permissões
# =============================================================================
info "=== FASE 6: Ativando serviços e permissões ==="

info "Adicionando $USER ao grupo video..."
sudo usermod -aG video "$USER" || warn "Falha ao adicionar $USER ao grupo video"

info "Habilitando Bluetooth..."
sudo systemctl enable --now bluetooth || warn "Falha ao habilitar bluetooth"

info "Habilitando upower (sistema)..."
sudo systemctl enable --now upower || warn "Falha ao habilitar upower no sistema"

info "Habilitando upower (usuário)..."
systemctl --user enable --now upower 2>/dev/null || warn "upower --user não disponível (normal em alguns setups)"

ok "Serviços configurados"

echo ""
echo "--- Verificação final ---"
id "$USER"
systemctl status bluetooth --no-pager | head -4
systemctl status upower    --no-pager | head -4
brightnessctl -l 2>/dev/null && ok "brightnessctl: OK" || warn "brightnessctl não listou dispositivos (pode ser normal em desktop)"

# =============================================================================
#  RESUMO FINAL
# =============================================================================
echo ""
echo -e "${GREEN}=============================================${NC}"
echo -e "${GREEN}  Setup concluído!${NC}"
echo -e "${GREEN}=============================================${NC}"
echo ""
echo -e "${YELLOW}Próximos passos:${NC}"
echo "  1. Faça LOGOUT e LOGIN para o grupo 'video' valer"
echo "  2. Reinicie para carregar os módulos NVIDIA e o novo initramfs"
echo "  3. Entre no SDDM → sessão Hyprland"
echo "  4. O DMS inicia automaticamente via exec-once"
echo ""
echo -e "${YELLOW}Atalhos principais após entrar no Hyprland:${NC}"
echo "  SUPER + SPACE  → Spotlight (launcher)"
echo "  SUPER + C      → Control Center"
echo "  SUPER + V      → Clipboard"
echo "  SUPER + N      → Notificações"
echo "  SUPER + X      → Power Menu"
echo "  SUPER + Y      → Wallpaper"
echo "  SUPER + TAB    → Overview"
echo ""
