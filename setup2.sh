#!/bin/bash
# =============================================================================
#  setup2.sh — Fases 4, 5 e 6 (continua após setup.sh)
#  Hardware: Ryzen 5 5600 + GTX 1050
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
info() { echo -e "${CYAN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[AVISO]${NC} $1"; }
fail() { echo -e "${RED}[ERRO]${NC} $1"; exit 1; }

# =============================================================================
#  FASE 4 — Fontes do Material Design
# =============================================================================
info "=== FASE 4: Instalando fontes Material Design ==="

sudo mkdir -p /usr/local/share/fonts

info "Baixando Material Symbols Rounded..."
sudo curl -fL \
    "https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf" \
    -o /usr/local/share/fonts/MaterialSymbolsRounded.ttf \
    || warn "Falha ao baixar MaterialSymbolsRounded"

info "Baixando Inter Variable..."
sudo curl -fL \
    "https://github.com/rsms/inter/raw/refs/tags/v4.1/docs/font-files/InterVariable.ttf" \
    -o /usr/local/share/fonts/InterVariable.ttf \
    || warn "Falha ao baixar InterVariable"

info "Baixando Fira Code Regular..."
sudo curl -fL \
    "https://github.com/tonsky/FiraCode/releases/latest/download/FiraCode-Regular.ttf" \
    -o /usr/local/share/fonts/FiraCode-Regular.ttf \
    || warn "Falha ao baixar FiraCode-Regular"

info "Atualizando cache de fontes..."
fc-cache -fv || warn "Falha ao atualizar cache"

fc-match Inter                  && ok "Fonte Inter: OK"             || warn "Inter não encontrada"
fc-match "Fira Code"            && ok "Fonte Fira Code: OK"         || warn "Fira Code não encontrada"
fc-match "Material Symbols Rounded" && ok "Material Symbols: OK"   || warn "Material Symbols não encontrada"

# =============================================================================
#  FASE 5 — Configuração do Hyprland integrada ao DMS
# =============================================================================
info "=== FASE 5: Criando configuração do Hyprland ==="

mkdir -p ~/.config/hypr

if [ -f ~/.config/hypr/hyprland.conf ]; then
    cp ~/.config/hypr/hyprland.conf ~/.config/hypr/hyprland.conf.bak
    warn "Backup salvo em hyprland.conf.bak"
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

ok "hyprland.conf criado"

# =============================================================================
#  FASE 6 — Serviços e permissões
# =============================================================================
info "=== FASE 6: Ativando serviços e permissões ==="

sudo usermod -aG video "$USER" && ok "Usuário adicionado ao grupo video" || warn "Falha ao adicionar ao grupo video"
sudo systemctl enable --now bluetooth && ok "Bluetooth ativado" || warn "Falha no bluetooth"
sudo systemctl enable --now upower && ok "upower ativado" || warn "Falha no upower"
systemctl --user enable --now upower 2>/dev/null && ok "upower usuário ativado" || warn "upower --user não disponível"

echo ""
echo -e "${GREEN}=============================================${NC}"
echo -e "${GREEN}  Fases 4, 5 e 6 concluídas!${NC}"
echo -e "${GREEN}=============================================${NC}"
echo ""
echo -e "${YELLOW}Agora:${NC}"
echo "  1. Faça LOGOUT e LOGIN (grupo video)"
echo "  2. REINICIE a máquina (carregar NVIDIA)"
echo "  3. Entre no SDDM → sessão Hyprland"
echo "  4. DMS sobe automaticamente"
echo ""
echo -e "${YELLOW}Atalhos principais:${NC}"
echo "  SUPER + SPACE  → Spotlight"
echo "  SUPER + C      → Control Center"
echo "  SUPER + V      → Clipboard"
echo "  SUPER + N      → Notificações"
echo "  SUPER + X      → Power Menu"
echo "  SUPER + TAB    → Overview"
