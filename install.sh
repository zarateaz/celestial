#!/bin/bash

# Caelestia / Celestial - One-Command Installer for Arch Linux
# Optimized for Garuda / Arch based systems

set -e

# --- Colors ---
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${CYAN}    Celestial System Installer         ${NC}"
echo -e "${BLUE}========================================${NC}"

# Check for Arch Linux
if ! command -v pacman >/dev/null 2>&1; then
    echo -e "${RED}Error: This script is only for Arch Linux based systems.${NC}"
    exit 1
fi

# --- Dependencies ---
BASE_DEPS=(cmake extra-cmake-modules qt6-base qt6-declarative qt6-wayland qt6-svg gcc make pkg-config imagemagick hyprland wallust swww waypaper)
AUR_DEPS=(quickshell-git caelestia-cli fastfetch)

echo -e "\n${CYAN}[1/5] Updating Package Database & Installing Base Dependencies...${NC}"
sudo pacman -Sy --needed --noconfirm "${BASE_DEPS[@]}"

# --- AUR Helper Detection ---
AUR_HELPER=""
if command -v yay >/dev/null 2>&1; then
    AUR_HELPER="yay"
elif command -v paru >/dev/null 2>&1; then
    AUR_HELPER="paru"
fi

if [ -z "$AUR_HELPER" ]; then
    echo -e "${RED}Warning: No AUR helper (yay/paru) found. Attempting to install 'yay'...${NC}"
    sudo pacman -S --needed --noconfirm git
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay && makepkg -si --noconfirm
    cd -
    AUR_HELPER="yay"
fi

# --- Conflict Resolution ---
echo -e "\n${CYAN}[1.5/5] Resolving package conflicts...${NC}"
# Explicitly remove quickshell stable to allow quickshell-git installation
if pacman -Qi quickshell >/dev/null 2>&1 && ! pacman -Qi quickshell-git >/dev/null 2>&1; then
    echo -e "${BLUE}Removing conflicting 'quickshell' to install 'quickshell-git'...${NC}"
    sudo pacman -Rns --noconfirm quickshell
fi

echo -e "\n${CYAN}[2/5] Installing AUR Dependencies (${AUR_HELPER})...${NC}"
$AUR_HELPER -S --needed --noconfirm "${AUR_DEPS[@]}"

# --- Config Setup ---
echo -e "\n${CYAN}[3/5] Setting up configurations...${NC}"
mkdir -p "$HOME/.config"

# Clean old configs to avoid "dangling symlinks" or conflicts
rm -rf "$HOME/.config/hypr" "$HOME/.config/waypaper" "$HOME/.config/quickshell/caelestia"

cp -r configs/hypr "$HOME/.config/"
cp -r configs/waypaper "$HOME/.config/"
mkdir -p "$HOME/.config/quickshell/caelestia"
cp -r shell/* "$HOME/.config/quickshell/caelestia/"

# --- Build Plugin ---
echo -e "\n${CYAN}[4/5] Building Caelestia Plugin...${NC}"
cd "$HOME/.config/quickshell/caelestia"
mkdir -p build && cd build
cmake ..
make
sudo make install
cd -

# --- SDDM Helper Setup ---
echo -e "\n${CYAN}[5/5] Configuring SDDM Sync Helper...${NC}"
SDDM_HELPER_PATH="$HOME/.config/hypr/scripts/sddm_root_helper.sh"
if [ -f "$SDDM_HELPER_PATH" ]; then
    sudo cp "$SDDM_HELPER_PATH" /usr/local/bin/sddm_root_helper
    sudo chmod +x /usr/local/bin/sddm_root_helper
    echo -e "${GREEN}SDDM helper installed to /usr/local/bin/sddm_root_helper${NC}"
    
    # Optional: Instructions for sudoers
    echo -e "${BLUE}Instruction:${NC} To update SDDM without password, add this to sudoers:"
    echo -e "  $(whoami) ALL=(ALL) NOPASSWD: /usr/local/bin/sddm_root_helper"
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}    Installation Complete! Go Caelestia! ${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Restart Hyprland to see changes."
