#!/usr/bin/env bash
# Download the Broadcom wl-driver RPMs and their transitive deps for
# offline install on a MacBook Air A1466 (BCM4360 wifi).
#
# Run this on ANY Fedora machine with internet. It writes RPMs to
# ./rpms/ next to this script. Commit the contents and push.
#
# Important: kernel-devel is kernel-version-specific. For akmods to
# successfully rebuild the wl module on the target machine, the bundled
# kernel-devel must match (or be very close to) the kernel that will be
# running on the MacBook when setup.sh executes. Safest approach: run
# this script on a Fedora machine with the same Fedora release as the
# ISO you'll install, and without pending kernel updates.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$HERE/rpms"
mkdir -p "$OUT"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
err()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; }

if [[ ! -r /etc/os-release ]]; then
    err "Not a Linux system with /etc/os-release."
    exit 1
fi
# shellcheck disable=SC1091
. /etc/os-release
if [[ "${ID,,}" != "fedora" ]]; then
    err "Run this on a Fedora machine (detected: ${ID:-unknown})."
    exit 1
fi

log "Fedora $(rpm -E %fedora) — downloading into $OUT"

# RPM Fusion provides akmod-wl / broadcom-wl. Enable it if missing.
if ! rpm -q rpmfusion-free-release >/dev/null 2>&1; then
    log "Enabling RPM Fusion free"
    sudo dnf install -y \
        "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"
fi
if ! rpm -q rpmfusion-nonfree-release >/dev/null 2>&1; then
    log "Enabling RPM Fusion nonfree"
    sudo dnf install -y \
        "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
fi

log "Cleaning any stale RPMs in $OUT"
rm -f "$OUT"/*.rpm

log "Downloading akmod-wl, broadcom-wl, akmods, kernel-devel + transitive deps"
# --resolve pulls dep chain; --alldeps also pulls deps already installed
# on this host so the offline install has every piece it needs.
dnf download \
    --resolve --alldeps \
    --destdir="$OUT" \
    akmod-wl broadcom-wl akmods kernel-devel kernel-headers

count="$(ls -1 "$OUT"/*.rpm 2>/dev/null | wc -l)"
log "Wrote $count RPMs to $OUT"
log "Review, then: git add wifi/rpms && git commit -m 'refresh wifi drivers for Fedora $(rpm -E %fedora)'"
