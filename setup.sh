#!/usr/bin/env bash
# Dotfiles setup for Hyprland on Fedora or Ubuntu 24.04 LTS.
# Detects the distro, installs packages, builds Hyprland when the distro
# does not ship it, and symlinks every config directory in this repo into
# ~/.config. Safe to re-run; existing configs are backed up before linking.

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP_SUFFIX=".bak.$(date +%Y%m%d-%H%M%S)"

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

detect_distro() {
    if [[ ! -r /etc/os-release ]]; then
        err "/etc/os-release is missing — cannot detect distro."
        exit 1
    fi
    # shellcheck disable=SC1091
    . /etc/os-release
    case "${ID,,}" in
        fedora)
            DISTRO="fedora"
            ;;
        ubuntu)
            DISTRO="ubuntu"
            if [[ "${VERSION_ID:-}" != "24.04" ]]; then
                warn "Tested on Ubuntu 24.04 — found ${VERSION_ID:-unknown}. Continuing anyway."
            fi
            ;;
        *)
            err "Unsupported distro: ${ID:-unknown}. This script supports Fedora and Ubuntu only."
            exit 1
            ;;
    esac
    log "Detected distro: $DISTRO"
}

# ---------------------------------------------------------------------------
# Package installation
# ---------------------------------------------------------------------------

install_fedora_packages() {
    log "Enabling RPM Fusion (free) and the solopasha/hyprland COPR"
    sudo dnf install -y \
        "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" || true
    sudo dnf install -y dnf-plugins-core
    sudo dnf copr enable -y solopasha/hyprland

    log "Installing Hyprland + ecosystem via dnf"
    sudo dnf install -y \
        hyprland hyprpaper hypridle hyprlock hyprpicker xdg-desktop-portal-hyprland \
        waybar kitty rofi-wayland btop \
        swww swaync \
        nwg-panel nwg-look \
        dolphin ristretto \
        pipewire wireplumber pipewire-pulseaudio \
        pavucontrol \
        brightnessctl playerctl \
        polkit-gnome network-manager-applet \
        grim slurp wl-clipboard cliphist \
        zsh git curl unzip \
        jetbrains-mono-fonts-all google-noto-emoji-fonts \
        qt5-qtwayland qt6-qtwayland
}

install_ubuntu_packages() {
    log "Ensuring 'universe' repo is enabled"
    # libxcb-errors-dev, libtomlplusplus-dev, and several waybar/rofi deps
    # live in universe. Desktop images enable it by default; minimal/cloud
    # images don't.
    sudo apt-get update -y
    sudo apt-get install -y software-properties-common
    sudo add-apt-repository -y universe
    sudo apt-get update -y

    log "Installing base packages via apt"
    # Everything available in Noble (24.04) main/universe. Hyprland itself is
    # NOT here — we build it from source below.
    sudo apt-get install -y \
        build-essential cmake meson ninja-build pkg-config \
        git curl wget unzip ca-certificates \
        waybar kitty rofi btop \
        dolphin ristretto \
        pipewire wireplumber pipewire-pulse \
        pavucontrol \
        brightnessctl playerctl \
        policykit-1-gnome network-manager-gnome \
        grim slurp wl-clipboard \
        zsh \
        fonts-jetbrains-mono fonts-noto-color-emoji \
        qtwayland5 qt6-wayland

    # Hyprland runtime/build deps on 24.04.
    log "Installing Hyprland build dependencies"
    sudo apt-get install -y \
        libwayland-dev wayland-protocols libxkbcommon-dev libinput-dev \
        libudev-dev libseat-dev libdrm-dev libgbm-dev libgl1-mesa-dev \
        libegl-dev libpixman-1-dev libcairo2-dev libpango1.0-dev \
        libjpeg-dev libwebp-dev libmagic-dev libgirepository1.0-dev \
        libtomlplusplus-dev libzip-dev librsvg2-dev libre2-dev \
        libxcb1-dev libxcb-composite0-dev libxcb-ewmh-dev libxcb-icccm4-dev \
        libxcb-res0-dev libxcb-xinput-dev \
        hwdata glslang-tools

    # libxcb-errors isn't packaged on Noble; build it first so Hyprland's
    # cmake finds it via pkg-config.
    build_libxcb_errors_from_source

    # Hyprland's own helper libs (hyprutils/hyprlang/etc.) aren't in apt;
    # build each from the latest release tag.
    build_hypr_deps

    build_hyprland_from_source
    build_xdph_from_source
    build_missing_ubuntu_tools
}

# ---------------------------------------------------------------------------
# Ubuntu: build Hyprland + companions from source
# ---------------------------------------------------------------------------

SRC_DIR="$HOME/.local/src"

clone_or_update() {
    local url="$1" dir="$2"
    if [[ -d "$dir/.git" ]]; then
        git -C "$dir" fetch --tags --quiet
    else
        git clone --recursive "$url" "$dir"
    fi
}

ensure_modern_cmake() {
    # Hyprland 0.50+ needs CMake >= 3.30; Noble ships 3.28.
    local cmake_version
    cmake_version="$(cmake --version 2>/dev/null | awk 'NR==1 {print $3}')"
    if [[ -n "$cmake_version" ]] && \
       printf '%s\n%s\n' '3.30' "$cmake_version" | sort -V -C 2>/dev/null; then
        log "cmake $cmake_version already meets requirement"
        return
    fi
    log "Installing modern cmake from Kitware APT repo"
    sudo apt-get install -y ca-certificates gpg wget
    wget -qO - https://apt.kitware.com/keys/kitware-archive-latest.asc \
        | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/kitware.gpg
    echo "deb https://apt.kitware.com/ubuntu/ $(lsb_release -cs) main" \
        | sudo tee /etc/apt/sources.list.d/kitware.list >/dev/null
    sudo apt-get update -y
    sudo apt-get install -y cmake
}

build_hypr_lib() {
    local repo="$1" pc_name="$2"
    if [[ -n "$pc_name" ]] && pkg-config --exists "$pc_name" 2>/dev/null; then
        log "$repo already installed — skipping"
        return
    fi
    if [[ -z "$pc_name" ]] && command -v "$repo" >/dev/null 2>&1; then
        log "$repo already installed — skipping"
        return
    fi
    log "Building $repo from source"
    mkdir -p "$SRC_DIR"
    clone_or_update "https://github.com/hyprwm/$repo" "$SRC_DIR/$repo"
    (
        cd "$SRC_DIR/$repo"
        local latest_tag
        latest_tag="$(git tag --list 'v*' --sort=-v:refname | head -n1)"
        [[ -n "$latest_tag" ]] && git checkout --quiet "$latest_tag"
        git submodule update --init --recursive --quiet
        cmake -B build -S . -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release
        cmake --build build -j "$(nproc)"
        sudo cmake --install build
    )
}

build_hypr_deps() {
    # Extra apt deps that weren't in the first install batch.
    sudo apt-get install -y libliftoff-dev libdisplay-info-dev uthash-dev || true

    ensure_modern_cmake
    # Order matters — later deps link against earlier ones.
    build_hypr_lib "hyprwayland-scanner" ""
    build_hypr_lib "hyprutils"  "hyprutils"
    build_hypr_lib "hyprlang"   "hyprlang"
    build_hypr_lib "hyprcursor" "hyprcursor"
    build_hypr_lib "hyprgraphics" "hyprgraphics"
    build_hypr_lib "aquamarine" "aquamarine"
    sudo ldconfig
}

build_libxcb_errors_from_source() {
    if pkg-config --exists xcb-errors 2>/dev/null; then
        log "libxcb-errors already installed — skipping"
        return
    fi
    log "Building libxcb-errors from source (not packaged on Noble)"
    sudo apt-get install -y autoconf automake libtool xutils-dev xcb-proto python3
    mkdir -p "$SRC_DIR"
    clone_or_update "https://gitlab.freedesktop.org/xorg/lib/libxcb-errors.git" \
        "$SRC_DIR/libxcb-errors"
    (
        cd "$SRC_DIR/libxcb-errors"
        git submodule update --init --recursive
        ./autogen.sh --prefix=/usr
        make
        sudo make install
        sudo ldconfig
    )
}

build_hyprland_from_source() {
    if command -v Hyprland >/dev/null 2>&1; then
        log "Hyprland already installed — skipping source build"
        return
    fi
    mkdir -p "$SRC_DIR"
    log "Cloning and building Hyprland (this takes a while)"
    clone_or_update "https://github.com/hyprwm/Hyprland" "$SRC_DIR/Hyprland"
    (
        cd "$SRC_DIR/Hyprland"
        # main can be mid-refactor; stick to the latest release tag.
        local latest_tag
        latest_tag="$(git tag --list 'v*' --sort=-v:refname | head -n1)"
        if [[ -n "$latest_tag" ]]; then
            log "Checking out Hyprland $latest_tag"
            git checkout --quiet "$latest_tag"
            git submodule update --init --recursive --quiet
        fi
        # Deps (hyprutils/hyprlang/hyprcursor/hyprgraphics/aquamarine/
        # hyprwayland-scanner) were built by build_hypr_deps above.
        make all
        sudo make install
    )
}

build_xdph_from_source() {
    if command -v xdg-desktop-portal-hyprland >/dev/null 2>&1; then return; fi
    log "Building xdg-desktop-portal-hyprland from source"
    sudo apt-get install -y libpipewire-0.3-dev libsdbus-c++-dev \
        qt6-base-dev qt6-wayland-dev || true
    clone_or_update "https://github.com/hyprwm/xdg-desktop-portal-hyprland" \
        "$SRC_DIR/xdg-desktop-portal-hyprland"
    (
        cd "$SRC_DIR/xdg-desktop-portal-hyprland"
        local latest_tag
        latest_tag="$(git tag --list 'v*' --sort=-v:refname | head -n1)"
        [[ -n "$latest_tag" ]] && git checkout --quiet "$latest_tag"
        cmake -B build -S . -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release
        cmake --build build
        sudo cmake --install build
    )
}

build_missing_ubuntu_tools() {
    # swww — wallpaper daemon (written in Rust)
    if ! command -v swww >/dev/null 2>&1; then
        ensure_cargo
        log "Building swww via cargo"
        cargo install --locked swww
    fi

    # swaync — notification daemon
    if ! command -v swaync >/dev/null 2>&1; then
        log "Building swaync from source"
        sudo apt-get install -y libgtk-3-dev libgtk-layer-shell-dev \
            libgee-0.8-dev libjson-glib-dev libgranite-dev scdoc valac || true
        clone_or_update "https://github.com/ErikReider/SwayNotificationCenter" \
            "$SRC_DIR/SwayNotificationCenter"
        (
            cd "$SRC_DIR/SwayNotificationCenter"
            meson setup --prefix=/usr build --reconfigure
            ninja -C build
            sudo ninja -C build install
        )
    fi

    # nwg-panel + nwg-look via pipx (pure python where possible)
    if ! command -v nwg-panel >/dev/null 2>&1; then
        sudo apt-get install -y pipx python3-gi gir1.2-gtk-3.0
        pipx ensurepath
        pipx install nwg-panel || warn "nwg-panel install failed — install manually if you need it"
    fi
    if ! command -v nwg-look >/dev/null 2>&1; then
        warn "nwg-look is not packaged for Ubuntu 24.04; install from https://github.com/nwg-piotr/nwg-look if you need it"
    fi
}

ensure_cargo() {
    if command -v cargo >/dev/null 2>&1; then return; fi
    log "Installing rustup toolchain (needed for cargo builds)"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
    # shellcheck disable=SC1091
    . "$HOME/.cargo/env"
}

# ---------------------------------------------------------------------------
# Shell + fonts (cross-distro)
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
    detect_distro

    case "$DISTRO" in
        fedora) install_fedora_packages ;;
        ubuntu) install_ubuntu_packages ;;
    esac

    install_oh_my_zsh
    install_nerd_font
    link_configs

    log "Done."
    log "Log out and pick 'Hyprland' from your display manager's session list."
    log "On first zsh launch the powerlevel10k wizard will run — follow its prompts."
}

main "$@"
