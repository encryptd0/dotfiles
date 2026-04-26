#!/usr/bin/env bash
# Bootstrap for a fresh Fedora install. Safe to `curl | bash`.
#
# Verifies Fedora, installs git if missing, clones (or fast-forward
# pulls) this repo into ~/Documents/dotfiles, then execs setup.sh.

set -euo pipefail

REPO_URL="https://github.com/encryptd0/dotfiles.git"
DEST="$HOME/Documents/dotfiles"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
err()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; }

if [[ $EUID -eq 0 ]]; then
    err "Run as your normal user (sudo will be invoked when needed)."
    exit 1
fi

if [[ ! -r /etc/os-release ]]; then
    err "/etc/os-release missing — cannot detect distro."
    exit 1
fi
# shellcheck disable=SC1091
. /etc/os-release
if [[ "${ID,,}" != "fedora" ]]; then
    err "Unsupported distro: ${ID:-unknown}. This bootstrap is Fedora-only."
    exit 1
fi
log "Detected Fedora ${VERSION_ID:-unknown}"

if ! command -v git >/dev/null 2>&1; then
    log "git missing — installing"
    sudo dnf install -y git
fi

mkdir -p "$(dirname "$DEST")"

if [[ -d "$DEST/.git" ]]; then
    log "Repo already at $DEST — fast-forward pulling"
    git -C "$DEST" pull --ff-only || warn "git pull failed — continuing with existing checkout"
elif [[ -e "$DEST" ]]; then
    err "$DEST exists and is not a git repo. Move or remove it and re-run."
    exit 1
else
    log "Cloning $REPO_URL into $DEST"
    git clone "$REPO_URL" "$DEST"
fi

cd "$DEST"
exec ./setup.sh
