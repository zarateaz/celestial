#!/bin/bash

# Caelestia / Celestial - One-Command Installer for Arch Linux
# Optimized for Garuda / Arch based systems

set -e

# --- Colors ---
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# --- Preserve original directory (critical for relative paths) ---
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}========================================${NC}"
echo -e "${CYAN}    🌌 Celestial System Installer       ${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}    Repo: ${REPO_DIR}${NC}"
echo ""

# Check for Arch Linux
if ! command -v pacman > /dev/null 2>&1; then
    echo -e "${RED}Error: This script is only for Arch Linux based systems.${NC}"
    exit 1
fi

# --- AUR Helper Detection (FIRST — needed before any AUR installs) ---
AUR_HELPER=""
if command -v yay > /dev/null 2>&1; then
    AUR_HELPER="yay"
elif command -v paru > /dev/null 2>&1; then
    AUR_HELPER="paru"
fi

if [ -z "$AUR_HELPER" ]; then
    echo -e "${YELLOW}[0/6] No AUR helper (yay/paru) found. Installing 'yay'...${NC}"
    sudo pacman -S --needed --noconfirm git base-devel
    TMPDIR_YAY="$(mktemp -d)"
    git clone https://aur.archlinux.org/yay.git "$TMPDIR_YAY/yay"
    (cd "$TMPDIR_YAY/yay" && makepkg -si --noconfirm)
    rm -rf "$TMPDIR_YAY"
    AUR_HELPER="yay"
fi

echo -e "${GREEN}AUR helper: ${AUR_HELPER}${NC}"

# --- Base Dependencies (pacman) ---
BASE_DEPS=(
    # Build tools
    cmake extra-cmake-modules gcc make pkg-config
    # Qt6
    qt6-base qt6-declarative qt6-wayland qt6-svg qt6-tools
    # Qt5/Qt6 theme support
    qt5ct qt6ct
    # Hyprland ecosystem
    hyprland hyprlock hypridle hyprsunset
    # Wallpaper / theming
    swww waypaper wallust imagemagick
    # Bar / notification
    waybar swaync
    # Terminal / launcher / clipboard
    kitty rofi-wayland wl-clipboard cliphist
    # File manager + polkit
    thunar xfce4-terminal polkit-gnome
    # Utils
    jq curl wget grim slurp wlogout
)

echo -e "\n${CYAN}[1/6] Updating Package Database & Installing Base Dependencies...${NC}"
sudo pacman -Sy --needed --noconfirm "${BASE_DEPS[@]}"

# --- Conflict Resolution: quickshell stable vs git ---
echo -e "\n${CYAN}[1.5/6] Resolving package conflicts...${NC}"
if pacman -Qi quickshell > /dev/null 2>&1 && ! pacman -Qi quickshell-git > /dev/null 2>&1; then
    echo -e "${YELLOW}Removing conflicting 'quickshell' to allow 'quickshell-git'...${NC}"
    sudo pacman -Rns --noconfirm quickshell
fi

# --- AUR Dependencies ---
AUR_DEPS=(
    quickshell-git
    caelestia-cli
    fastfetch
    bibata-cursor-theme
    wlogout
)

echo -e "\n${CYAN}[2/6] Installing AUR Dependencies (${AUR_HELPER})...${NC}"
$AUR_HELPER -S --needed --noconfirm "${AUR_DEPS[@]}"

# --- Wallpaper Directory ---
echo -e "\n${CYAN}[2.5/6] Setting up wallpaper directory...${NC}"
mkdir -p "$HOME/Pictures/wallpapers"
# Copy bundled wallpapers if they exist in the repo
if [ -d "$REPO_DIR/shell/wallpapers" ] && [ "$(ls -A "$REPO_DIR/shell/wallpapers" 2>/dev/null)" ]; then
    cp -rn "$REPO_DIR/shell/wallpapers/." "$HOME/Pictures/wallpapers/" 2>/dev/null || true
    echo -e "${GREEN}Wallpapers copied to ~/Pictures/wallpapers${NC}"
fi

# --- Config Setup ---
echo -e "\n${CYAN}[3/6] Setting up configurations...${NC}"
mkdir -p "$HOME/.config"

# Clean old configs to avoid conflicts
rm -rf "$HOME/.config/hypr" "$HOME/.config/waypaper" "$HOME/.config/quickshell/caelestia"

# Copy Hyprland config
cp -r "$REPO_DIR/configs/hypr" "$HOME/.config/"

# Fix scripts: make all .sh files executable
find "$HOME/.config/hypr/scripts" -name "*.sh" -exec chmod +x {} \;

# Copy waypaper config
cp -r "$REPO_DIR/configs/waypaper" "$HOME/.config/"

# Copy Caelestia shell (if not empty)
mkdir -p "$HOME/.config/quickshell/caelestia"
if [ -d "$REPO_DIR/shell" ] && [ "$(ls -A "$REPO_DIR/shell" 2>/dev/null)" ]; then
    cp -r "$REPO_DIR/shell/." "$HOME/.config/quickshell/caelestia/" 2>/dev/null || true
fi

# Copy global scripts (WallustSwww.sh etc.) to hypr/scripts
cp "$REPO_DIR/scripts/WallustSwww.sh"       "$HOME/.config/hypr/scripts/WallustSwww.sh"
cp "$REPO_DIR/scripts/sddm_wallpaper.sh"    "$HOME/.config/hypr/scripts/sddm_wallpaper.sh"
cp "$REPO_DIR/scripts/sddm_root_helper.sh"  "$HOME/.config/hypr/scripts/sddm_root_helper.sh"
chmod +x "$HOME/.config/hypr/scripts/WallustSwww.sh"
chmod +x "$HOME/.config/hypr/scripts/sddm_wallpaper.sh"
chmod +x "$HOME/.config/hypr/scripts/sddm_root_helper.sh"

# --- SDDM Helper Setup ---
echo -e "\n${CYAN}[4/6] Configuring SDDM Sync Helper...${NC}"
SDDM_HELPER_PATH="$HOME/.config/hypr/scripts/sddm_root_helper.sh"
if [ -f "$SDDM_HELPER_PATH" ]; then
    sudo cp "$SDDM_HELPER_PATH" /usr/local/bin/sddm_root_helper
    sudo chmod +x /usr/local/bin/sddm_root_helper
    echo -e "${GREEN}SDDM helper installed to /usr/local/bin/sddm_root_helper${NC}"
    echo -e "${BLUE}Tip:${NC} Para actualizar SDDM sin contraseña, agrega esto a sudoers:"
    echo -e "  $(whoami) ALL=(ALL) NOPASSWD: /usr/local/bin/sddm_root_helper"
fi

# --- Enable systemd user services (if applicable) ---
echo -e "\n${CYAN}[5/6] Enabling systemd user services...${NC}"
systemctl --user enable --now wireplumber.service > /dev/null 2>&1 || true
systemctl --user enable --now pipewire.service     > /dev/null 2>&1 || true
systemctl --user enable --now pipewire-pulse.service > /dev/null 2>&1 || true

# --- Wallust initial run (generate color templates) ---
echo -e "\n${CYAN}[6/6] Running initial wallust pass...${NC}"
FIRST_WALL=""
for ext in png jpg jpeg webp; do
    FOUND=$(find "$HOME/Pictures/wallpapers" -maxdepth 2 -iname "*.$ext" 2>/dev/null | head -n1)
    if [ -n "$FOUND" ]; then
        FIRST_WALL="$FOUND"
        break
    fi
done

if [ -n "$FIRST_WALL" ]; then
    wallust run -s "$FIRST_WALL" > /dev/null 2>&1 && \
        echo -e "${GREEN}Wallust initialized with: $FIRST_WALL${NC}" || \
        echo -e "${YELLOW}Wallust ran but had warnings (normal on first run).${NC}"
else
    echo -e "${YELLOW}No wallpaper found for initial wallust run — skipped.${NC}"
    echo -e "${YELLOW}Add wallpapers to ~/Pictures/wallpapers and run: wallust run -s <image>${NC}"
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}    🌌 Installation Complete! Celestial  ${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e ""
echo -e "${CYAN}Next steps:${NC}"
echo -e "  1. Add your wallpapers to ${YELLOW}~/Pictures/wallpapers/${NC}"
echo -e "  2. Select 'Hyprland' from your display manager (SDDM)"
echo -e "  3. Or run: ${YELLOW}Hyprland${NC} (from a TTY)"
echo -e ""
echo -e "${BLUE}Para aplicar cambios si Hyprland ya está corriendo:${NC}"
echo -e "  ${YELLOW}hyprctl reload${NC}"
echo -e ""
