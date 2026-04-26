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

## Install (one-liner)

On a fresh Fedora Workstation install with internet connectivity:

```sh
curl -fsSL https://raw.githubusercontent.com/encryptd0/dotfiles/main/install.sh | bash
```

That's it. The bootstrap clones this repo into `~/Documents/dotfiles`
and runs `setup.sh`. After it finishes, log out and pick **Hyprland**
from the display manager's session list.

### Prefer to inspect first

```sh
curl -fsSL https://raw.githubusercontent.com/encryptd0/dotfiles/main/install.sh -o install.sh
less install.sh
bash install.sh
```

### Manual clone

```sh
sudo dnf install -y git
git clone https://github.com/encryptd0/dotfiles.git ~/Documents/dotfiles
cd ~/Documents/dotfiles
./setup.sh
```

## Requirements

- Fedora Workstation (any recent release).
- **Internet connection.** Hyprland and the rest of the desktop come
  from online repos, so connectivity is required on every machine —
  including MacBooks where the wifi driver itself is fetched online.

## What `setup.sh` does

- Verifies you're on Fedora (bails if not).
- Detects Broadcom BCM43xx wifi. On a MacBook Air A1466 (and similar
  Macs from that era), installs `akmod-wl` + `broadcom-wl` from RPM
  Fusion so wifi works going forward. On any other device this step
  is skipped. If the install fails for any reason, the script logs a
  warning and continues — it never aborts the whole run over wifi.
- Enables RPM Fusion (free + nonfree) and the `solopasha/hyprland` COPR.
- Installs Hyprland, Waybar, Kitty, Alacritty, Rofi (Wayland), btop,
  swww, swaync, nwg-panel, nwg-look, PipeWire, pavucontrol, Brave, and
  the rest via `dnf`.
- Installs Oh My Zsh + Powerlevel10k, sets zsh as the default shell.
- Installs the JetBrains Mono Nerd Font if missing.
- Symlinks `hypr/`, `waybar/`, `kitty/`, `rofi/`, `btop/`, `nwg-panel/`,
  `nwg-look/`, and `ristretto/` into `~/.config/`. Pre-existing configs
  are backed up to `~/.config/<name>.bak.<timestamp>` before linking,
  so rerunning is safe.

## MacBook Air A1466 (and similar BCM4360 machines)

The Broadcom BCM4360 wifi chip needs the proprietary `wl` driver, and
a fresh Fedora install has no wifi until that driver is installed.
`setup.sh` installs it automatically when it detects the chip — but it
needs internet to do that, so bring connectivity another way for the
first run:

- **Wired ethernet** via a USB-C/USB-A adapter (simplest).
- **USB tethering** from a phone.
- **Phone hotspot** picked up by another wifi-capable device sharing
  over USB or ethernet.

Once `setup.sh` finishes, wifi is up on the MacBook and you can use it
normally on subsequent reboots.

### `wifi/` — optional offline tooling

The `wifi/` directory contains a `download-drivers.sh` script that
pre-downloads the `wl` driver RPMs for air-gapped or repeat-install
scenarios. **It is not used by `setup.sh` anymore** — pinned RPMs can
conflict with whatever kernel-devel happens to be installed on the
target machine, which used to break the whole script. If you want the
truly offline path, see [`wifi/README.md`](wifi/README.md) and install
those RPMs manually before running `setup.sh`.

## Screenshots
![Project Screenshot](images/screenshot_1768586722.png)

![Project Screenshot](images/screenshot_1768586769.png)
