# MacBook Air A1466 offline wifi drivers

The BCM4360 wifi chip in the MacBook Air A1466 needs the proprietary
`wl` driver. A fresh Fedora install has no wifi until this driver is
installed — a chicken-and-egg problem. This directory holds pre-
downloaded RPMs so `setup.sh` can install them without internet.

On a PC (no Broadcom BCM43xx chip detected), `setup.sh` skips this
step entirely, so the bundled RPMs cost nothing there.

## Refreshing the bundled RPMs

Run on ANY Fedora machine with internet, ideally matching the Fedora
release and kernel you'll install on the MacBook:

```sh
./download-drivers.sh
git add rpms && git commit -m "refresh wifi drivers for Fedora N"
git push
```

`download-drivers.sh` enables RPM Fusion, then uses
`dnf download --resolve --alldeps` to pull `akmod-wl`, `broadcom-wl`,
`akmods`, `kernel-devel`, `kernel-headers`, and every transitive dep
into `rpms/`.

## Why `kernel-devel` matters

`akmod-wl` ships the wl-driver source. On the target machine, `akmods`
compiles it against the running kernel, which requires `kernel-devel`
matching that kernel version. If the bundled `kernel-devel` doesn't
match the kernel on the MacBook, the build will fail.

Mitigations:

- Boot the fresh Fedora ISO and, **before updating**, run `setup.sh`.
  ISO-default kernels are stable for a given Fedora release.
- If the first boot auto-updates the kernel, refresh `rpms/` from a
  machine that's already on that updated kernel and re-run.
- As a fallback, refresh online once you have wifi: `sudo dnf install
  akmod-wl broadcom-wl`.
