#!/bin/bash

FILE="$HOME/.config/hypr/hyprland.conf"

DESKTOP='source = $HOME/.config/hypr/monitors-desktop.conf'
LAPTOP='source = $HOME/.config/hypr/monitors-laptop.conf'

# Check which one is ACTIVE (uncommented)
if grep -q "^[[:space:]]*$DESKTOP" "$FILE"; then
    # Desktop → Laptop
    sed -i "s|^[[:space:]]*$DESKTOP|#$DESKTOP|" "$FILE"
    sed -i "s|^[[:space:]]*#*[[:space:]]*$LAPTOP|$LAPTOP|" "$FILE"
else
    # Laptop → Desktop
    sed -i "s|^[[:space:]]*$LAPTOP|#$LAPTOP|" "$FILE"
    sed -i "s|^[[:space:]]*#*[[:space:]]*$DESKTOP|$DESKTOP|" "$FILE"
fi

hyprctl reload
