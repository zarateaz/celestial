#!/bin/bash
# startup_wallpaper.sh - Ensures swww starts correctly without black screens

SCRIPTS_DIR="$HOME/.config/hypr/scripts"
WALL_CURRENT="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
DEFAULT_WALL="$HOME/celestial/shell/wallpapers/universo-abstracto-luces-neon_3000x2500_xtrafondos.com.jpg"

# 1. Start swww-daemon if not running
if ! pgrep -x "swww-daemon" > /dev/null; then
    swww-daemon --format xrgb &
    # Wait for the socket to be available
    for i in {1..50}; do
        if swww query > /dev/null 2>&1; then
            break
        fi
        sleep 0.1
    done
fi

# 2. Determine which wallpaper to load
if [ -f "$WALL_CURRENT" ]; then
    WALL=$(cat "$WALL_CURRENT")
    if [ ! -f "$WALL" ]; then
        WALL="$DEFAULT_WALL"
    fi
else
    WALL="$DEFAULT_WALL"
fi

# 3. Apply the wallpaper
if [ -f "$WALL" ]; then
    echo "Applying startup wallpaper: $WALL"
    swww img "$WALL" --transition-type none
    
    # 4. Trigger a full sync in the background to ensure colors and SDDM match
    if [ -f "$SCRIPTS_DIR/WallustSwww.sh" ]; then
        bash "$SCRIPTS_DIR/WallustSwww.sh" "$WALL" &
    fi
else
    echo "Error: No wallpaper found even for startup."
fi
