# My Minimalist Hyprland setup (Fedora / Ubuntu 24.04)

## Apps & Tools I Use

| Category | Tool |
|--------|------|
| 🪟 Window Manager | Hyprland |
| 📊 Status Bar | Waybar |
| 🚀 App Launcher | Rofi |
| 🖼️ Image Viewer | Ristretto |
| 🐧 Linux Distro | Fedora or Ubuntu 24.04 LTS |
| 🐚 Shell | Zsh |
| 🎨 Shell Framework | Oh My Zsh |
| ✨ Prompt Theme | Powerlevel10k |
| 🔤 Font | JetBrains Mono (Nerd Fonts) |

## Install

Clone and run the setup script. It detects the distro, installs every
package it needs, builds Hyprland from source on Ubuntu (24.04 doesn't
ship it), and symlinks each config directory in this repo into
`~/.config/`. Pre-existing configs are backed up to
`~/.config/<name>.bak.<timestamp>` before any link is created, so rerunning
the script is safe.

```sh
git clone <this-repo> ~/Documents/dotfiles
cd ~/Documents/dotfiles
./setup.sh
```

What it does:

- **Fedora**: enables RPM Fusion + the `solopasha/hyprland` COPR, then
  installs Hyprland, Waybar, Kitty, Rofi (Wayland), btop, swww, swaync,
  nwg-panel, nwg-look, and the rest via `dnf`.
- **Ubuntu 24.04**: installs what `apt` has (Waybar, Kitty, Rofi, btop,
  PipeWire, etc.) and builds Hyprland, swww, and swaync from source into
  `~/.local/src/`. `nwg-panel` is installed via `pipx`; `nwg-look` is
  skipped (no upstream package for Noble) with a pointer to build it
  manually if you need it.
- Installs Oh My Zsh + Powerlevel10k and the JetBrains Mono Nerd Font if
  they're missing, and sets zsh as the default shell.
- Symlinks `hypr/`, `waybar/`, `kitty/`, `rofi/`, `btop/`, `nwg-panel/`,
  `nwg-look/`, and `ristretto/` into `~/.config/`.

After it finishes, log out and pick **Hyprland** from the display
manager's session list.

## Screenshots
![Project Screenshot](images/screenshot_1768586722.png)

![Project Screenshot](images/screenshot_1768586769.png)
---
