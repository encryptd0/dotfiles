#!/usr/bin/env bash
# Fedora-only Hyprland dotfiles setup.
#
# - Installs Hyprland + ecosystem from the solopasha/hyprland COPR.
# - On a MacBook Air A1466 (Broadcom BCM4360 wifi), installs bundled
#   offline wl-driver RPMs from wifi/rpms/ so wifi works before the
#   online package install runs. On PCs this step is skipped.
# - Symlinks each config directory in this repo into ~/.config.
# Safe to re-run; existing configs are backed up before linking.

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP_SUFFIX=".bak.$(date +%Y%m%d-%H%M%S)"
WIFI_RPMS_DIR="$DOTFILES_DIR/wifi/rpms"

# Config directories in this repo that should be symlinked into ~/.config.
CONFIG_DIRS=(hypr waybar kitty rofi btop nwg-panel nwg-look ristretto)

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
err()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; }

require_not_root() {
    if [[ $EUID -eq 0 ]]; then
        err "Run this as your normal user (the script will call sudo when it needs to)."
        exit 1
    fi
}

require_fedora() {
    if [[ ! -r /etc/os-release ]]; then
        err "/etc/os-release is missing — cannot detect distro."
        exit 1
    fi
    # shellcheck disable=SC1091
    . /etc/os-release
    if [[ "${ID,,}" != "fedora" ]]; then
        err "Unsupported distro: ${ID:-unknown}. This script is Fedora-only."
        exit 1
    fi
    log "Detected Fedora ${VERSION_ID:-unknown}"
}

# ---------------------------------------------------------------------------
# Broadcom BCM4360 wifi (MacBook Air A1466)
# ---------------------------------------------------------------------------

has_broadcom_bcm43() {
    command -v lspci >/dev/null 2>&1 || return 1
    lspci -d '14e4:*' 2>/dev/null | grep -qE 'BCM43(60|42)'
}

wl_loaded() {
    lsmod 2>/dev/null | grep -q '^wl '
}

has_network() {
    ip route show default 2>/dev/null | grep -q . || return 1
    getent hosts mirrors.fedoraproject.org >/dev/null 2>&1
}

enable_rpmfusion() {
    if ! rpm -q rpmfusion-free-release >/dev/null 2>&1; then
        sudo dnf install -y \
            "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"
    fi
    if ! rpm -q rpmfusion-nonfree-release >/dev/null 2>&1; then
        sudo dnf install -y \
            "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
    fi
}

install_broadcom_wifi() {
    if ! has_broadcom_bcm43; then
        log "Broadcom BCM43xx wifi not detected — skipping wl driver install"
        return
    fi
    if wl_loaded; then
        log "wl kernel module already loaded — skipping"
        return
    fi

    if has_network; then
        log "Broadcom BCM43xx detected and online — installing wl driver via dnf"
        enable_rpmfusion
        sudo dnf install -y akmod-wl broadcom-wl
    else
        if [[ ! -d "$WIFI_RPMS_DIR" ]] || ! compgen -G "$WIFI_RPMS_DIR/*.rpm" >/dev/null; then
            err "Broadcom BCM43xx detected and no network, but no RPMs at $WIFI_RPMS_DIR"
            err "Run wifi/download-drivers.sh on a Fedora machine with internet, commit the result, then re-run."
            exit 1
        fi
        log "Installing bundled Broadcom wl driver RPMs (offline)"
        sudo dnf install -y --disablerepo='*' "$WIFI_RPMS_DIR"/*.rpm
    fi

    log "Building wl kernel module for running kernel (akmods)"
    sudo akmods --force || warn "akmods build failed — see /var/cache/akmods for logs"

    log "Loading wl kernel module"
    if sudo modprobe wl; then
        log "wl loaded — you can now connect to wifi"
    else
        warn "modprobe wl failed. Reboot, connect to wifi via GNOME/nmcli, then re-run ./setup.sh to continue."
        exit 0
    fi
}

# ---------------------------------------------------------------------------
# Package installation
# ---------------------------------------------------------------------------

install_fedora_packages() {
    if ! has_network; then
        err "No network connectivity. Connect to the internet and re-run ./setup.sh."
        exit 1
    fi

    enable_rpmfusion
    sudo dnf install -y dnf-plugins-core
    sudo dnf copr enable -y solopasha/hyprland

    log "Installing Hyprland + ecosystem via dnf"
    sudo dnf install -y \
        hyprland hyprpaper hypridle hyprlock hyprpicker xdg-desktop-portal-hyprland \
        waybar kitty alacritty rofi-wayland btop \
        swww swaync \
        nwg-panel nwg-look \
        dolphin ristretto \
        pipewire wireplumber pipewire-pulseaudio pavucontrol \
        brightnessctl playerctl \
        hyprpolkitagent network-manager-applet \
        grim slurp wl-clipboard cliphist \
        zsh git curl unzip \
        jetbrains-mono-fonts-all google-noto-emoji-fonts \
        qt5-qtwayland qt6-qtwayland
}

install_brave() {
    if rpm -q brave-browser >/dev/null 2>&1; then
        log "Brave already installed"
        return
    fi
    log "Adding Brave repo and installing brave-browser"
    if [[ ! -f /etc/yum.repos.d/brave-browser.repo ]]; then
        sudo dnf config-manager addrepo \
            --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
    fi
    sudo dnf install -y brave-browser
}

# ---------------------------------------------------------------------------
# Shell + fonts
# ---------------------------------------------------------------------------

install_oh_my_zsh() {
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        log "oh-my-zsh already present"
    else
        log "Installing oh-my-zsh"
        RUNZSH=no CHSH=no sh -c \
            "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    fi

    local p10k="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
    if [[ -d "$p10k" ]]; then
        log "powerlevel10k already present"
    else
        log "Installing powerlevel10k"
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k"
    fi

    if [[ "${SHELL:-}" != *zsh ]]; then
        log "Changing default shell to zsh (may prompt for password)"
        chsh -s "$(command -v zsh)" || warn "chsh failed — change your shell manually"
    fi
}

install_nerd_font() {
    local font_dir="$HOME/.local/share/fonts"
    if compgen -G "$font_dir/JetBrainsMono*NerdFont*.ttf" >/dev/null; then
        log "JetBrainsMono Nerd Font already installed"
        return
    fi
    log "Installing JetBrainsMono Nerd Font"
    mkdir -p "$font_dir"
    local tmp; tmp="$(mktemp -d)"
    curl -fsSL -o "$tmp/JetBrainsMono.zip" \
        "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
    unzip -qo "$tmp/JetBrainsMono.zip" -d "$font_dir"
    rm -rf "$tmp"
    fc-cache -f >/dev/null || true
}

# ---------------------------------------------------------------------------
# Config symlinking
# ---------------------------------------------------------------------------

link_configs() {
    mkdir -p "$CONFIG_DIR"
    for name in "${CONFIG_DIRS[@]}"; do
        local src="$DOTFILES_DIR/$name"
        local dest="$CONFIG_DIR/$name"
        if [[ ! -d "$src" ]]; then
            warn "Skipping $name — not in repo"
            continue
        fi

        if [[ -L "$dest" ]]; then
            if [[ "$(readlink "$dest")" == "$src" ]]; then
                log "Already linked: $dest"
                continue
            fi
            rm "$dest"
        elif [[ -e "$dest" ]]; then
            log "Backing up $dest -> $dest$BACKUP_SUFFIX"
            mv "$dest" "$dest$BACKUP_SUFFIX"
        fi

        ln -s "$src" "$dest"
        log "Linked $src -> $dest"
    done
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
    require_not_root
    require_fedora
    install_broadcom_wifi
    install_fedora_packages
    install_brave
    install_oh_my_zsh
    install_nerd_font
    link_configs

    log "Done."
    log "Log out and pick 'Hyprland' from your display manager's session list."
    log "On first zsh launch the powerlevel10k wizard will run — follow its prompts."
}

main "$@"
