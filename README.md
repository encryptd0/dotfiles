# My Minimalist Hyprland setup (Fedora)

## Apps & Tools I Use

| Category | Tool |
|--------|------|
| 🪟 Window Manager | Hyprland |
| 📊 Status Bar | Waybar |
| 🚀 App Launcher | Rofi |
| 🖼️ Image Viewer | Ristretto |
| 🐧 Linux Distro | Fedora Workstation |
| 🐚 Shell | Zsh |
| 🎨 Shell Framework | Oh My Zsh |
| ✨ Prompt Theme | Powerlevel10k |
| 🔤 Font | JetBrains Mono (Nerd Fonts) |

## Install

```sh
git clone <this-repo> ~/Documents/dotfiles
cd ~/Documents/dotfiles
./setup.sh
```

What it does:

- Verifies you're on Fedora (bails if not).
- Detects Broadcom BCM43xx wifi. On a MacBook Air A1466, installs the
  bundled offline `wl` driver RPMs from `wifi/rpms/` so wifi works
  before the online package install runs. On a PC, this step is
  skipped automatically.
- Enables RPM Fusion (free + nonfree) and the `solopasha/hyprland` COPR.
- Installs Hyprland, Waybar, Kitty, Rofi (Wayland), btop, swww, swaync,
  nwg-panel, nwg-look, PipeWire, pavucontrol, and the rest via `dnf`.
- Installs Oh My Zsh + Powerlevel10k, sets zsh as the default shell.
- Installs the JetBrains Mono Nerd Font if missing.
- Symlinks `hypr/`, `waybar/`, `kitty/`, `rofi/`, `btop/`, `nwg-panel/`,
  `nwg-look/`, and `ristretto/` into `~/.config/`. Pre-existing configs
  are backed up to `~/.config/<name>.bak.<timestamp>` before linking,
  so rerunning is safe.

After it finishes, log out and pick **Hyprland** from the display
manager's session list.

## MacBook Air A1466 offline wifi

First install on the MacBook:

1. Install Fedora Workstation from USB.
2. Without connecting to wifi, copy this repo onto the machine (USB
   stick is easiest).
3. Run `./setup.sh`. It detects the Broadcom chip, installs the
   bundled driver RPMs offline, rebuilds the kmod against the running
   kernel, and `modprobe wl`.
4. If `modprobe wl` fails, reboot, connect to wifi via GNOME, then run
   `./setup.sh` again to continue with the package install.

To refresh the bundled drivers (e.g. new Fedora release), see
[`wifi/README.md`](wifi/README.md).

## Screenshots
![Project Screenshot](images/screenshot_1768586722.png)

![Project Screenshot](images/screenshot_1768586769.png)
