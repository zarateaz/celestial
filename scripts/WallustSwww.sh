#!/bin/bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# Wallust: derive colors from the current wallpaper and update templates.
#
# Usage:
#   WallustSwww.sh [absolute_path_to_wallpaper]
#
# When called WITH a path (e.g. from waypaper post_command), the wallpaper
# has ALREADY been applied by waypaper/swww — this script only runs wallust
# to regenerate the color palette and refreshes UI components.
#
# When called WITHOUT a path (standalone), it detects the current wallpaper
# from the awww cache and applies it with the grow transition effect.

set -euo pipefail

# ── Paths ────────────────────────────────────────────────────────────────────
passed_path="${1:-}"
cache_dir="$HOME/.cache/awww/"
rofi_link="$HOME/.config/rofi/.current_wallpaper"
wallpaper_current="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"

# ── Helper: get focused monitor name ─────────────────────────────────────────
get_focused_monitor() {
  if command -v jq >/dev/null 2>&1; then
    hyprctl monitors -j | jq -r '.[] | select(.focused) | .name'
  else
    hyprctl monitors | awk '/^Monitor/{name=$2} /focused: yes/{print name}'
  fi
}

# ── Determine wallpaper path ──────────────────────────────────────────────────
wallpaper_path=""

if [[ -n "$passed_path" && -f "$passed_path" ]]; then
  # Called by waypaper or other scripts
  wallpaper_path=$(realpath "$passed_path")
else
  # Standalone call — detect current wallpaper
  current_monitor="$(get_focused_monitor)"
  
  # Try to query swww/awww directly
  if command -v swww >/dev/null 2>&1; then
      wallpaper_path=$(swww query | grep "$current_monitor" | awk -F 'image: ' '{print $2}' || true)
  fi

  # Fallback: check awww cache
  if [[ -z "${wallpaper_path:-}" || ! -f "$wallpaper_path" ]]; then
      cache_file="$cache_dir$current_monitor"
      if [[ -f "$cache_file" ]] && command -v awww >/dev/null 2>&1; then
        wallpaper_path=$(awww query | grep "$current_monitor" | awk '{print $9}' || true)
      fi
  fi

  # Final fallback: use saved current wallpaper
  if [[ -z "${wallpaper_path:-}" || ! -f "$wallpaper_path" ]]; then
    [[ -f "$wallpaper_current" ]] && wallpaper_path=$(cat "$wallpaper_current" || true)
  fi
fi

# ── Bail if no valid wallpaper found ─────────────────────────────────────────
if [[ -z "${wallpaper_path:-}" || ! -f "$wallpaper_path" ]]; then
  echo "Error: No valid wallpaper found." >&2
  exit 1
fi

# ── Apply wallpaper ──────────────────────────────────────────────────────────
# We ALWAYS apply to ensure synchronization, even if called from waypaper
_POS="$(hyprctl cursorpos | tr -d ' ' 2>/dev/null || echo 'center')"

# Detect engine
if command -v awww >/dev/null 2>&1; then
    ENGINE="awww"
else
    ENGINE="swww"
fi

if [[ "$ENGINE" == "awww" ]]; then
    # awww doesn't support swww transition flags
    awww img "$wallpaper_path" || true
else
    swww img "$wallpaper_path" \
        --transition-type  grow            \
        --transition-fps   144             \
        --transition-duration 1.2          \
        --transition-bezier "0.25,0.46,0.45,0.94" \
        --transition-pos   "$_POS"         \
        --resize           crop || true
fi

# ── Save current wallpaper path ───────────────────────────────────────────────
ln -sf "$wallpaper_path" "$rofi_link" || true
mkdir -p "$(dirname "$wallpaper_current")"
echo "$wallpaper_path" > "$wallpaper_current"

# ── Run wallust to regenerate color templates ─────────────────────────────────
# Optimization: For very large images (like 8K), wallust can be slow.
# We create a low-res preview for color extraction to speed it up (~20s -> <1s).
if command -v magick >/dev/null 2>&1; then
    magick "$wallpaper_path" -resize 720x720\> /tmp/wallust_preview.jpg
    wallust run -s /tmp/wallust_preview.jpg || wallust run -s "$wallpaper_path" || true
else
    wallust run -s "$wallpaper_path" || true
fi

# ── Sync with Caelestia Shell ──────────────────────────────────────────────────
# This ensures Caelestia shows the correct background and updates its state
mkdir -p "$HOME/.local/state/caelestia/wallpaper"
echo "$wallpaper_path" > "$HOME/.local/state/caelestia/wallpaper/path.txt"

# Trigger Caelestia wallpaper change (works with shell IPC)
caelestia shell wallpaper set "$wallpaper_path" || true

# ── Refresh UI components ─────────────────────────────────────────────────────
pkill -SIGUSR2 waybar 2>/dev/null || true   # Waybar colors
pkill -SIGUSR1 kitty  2>/dev/null || true   # Kitty colors

# ── Update SDDM login screen wallpaper ───────────────────────────────────────
if [[ -f "$HOME/.config/hypr/scripts/sddm_wallpaper.sh" ]]; then
  # Ensure the wallpaper path is absolute and exists
  if [[ -f "$wallpaper_path" ]]; then
    # Run in background to avoid blocking the main script or waypaper UI
    # We use a dedicated log file to help debugging quality issues
    (bash "$HOME/.config/hypr/scripts/sddm_wallpaper.sh" --normal "$wallpaper_path" >> /tmp/sddm_update.log 2>&1 &)
  fi
fi
