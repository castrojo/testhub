# VirtualBox — Known Issues

## KVM backend required (no kernel module)

Uses the `cyberus-technology/virtualbox-kvm` fork which replaces the `vboxdrv` kernel
module with a KVM backend. Kernel modules cannot be built or loaded from a Flatpak
sandbox — this KVM fork is what makes VMs work without `vboxdrv`.

Build applies the virtualbox-kvm patch (`patch -p1 < virtualbox-kvm/patches/0001-NEM-Implement-KVM-backend.patch`) on top of the
VirtualBox OSE source tarball.

## Wayland blocked (X11 only)

`--socket=x11` only; `--socket=wayland` is intentionally absent. VBoxSVGA has an
infinite-screen bug under XWayland/Wayland. X11 socket only until upstream fixes it.

## Hardening disabled

`--disable-hardening` is required. VirtualBox normally uses EUID manipulation for privilege
separation, which is impossible inside a Flatpak sandbox. Flatpak's own sandboxing provides
isolation instead.

## gsoap builds with `-j1` (serial)

`gsoap` has a broken dependency declaration in its build system — parallel `make` races.
Forced serial build with `no-parallel: true` in the gsoap module definition.

## `--with-makeself=/usr/bin/echo`

VirtualBox's configure checks for `makeself.sh` (self-extracting archive tool). In a Flatpak
build this is irrelevant. Passing `--with-makeself=/usr/bin/echo` stubs it out. The
`0000-nomakeself.patch` is also present as a belt-and-suspenders backup.

## OCI runtime: org.kde.Platform, not GNOME or freedesktop

Uses `org.kde.Platform//6.10` (Qt-based GUI). Build container must be
`ghcr.io/flathub-infra/flatpak-github-actions:kde-6.10`.

## shared-modules inlined

SDL 1.2.15 and GLU 9.0.3 are inlined directly in the manifest (not a git submodule).
Pinned to the versions from flathub/shared-modules @ 11f1a3afd8b6b2447b49e1872a27f26d0726e4ed.
SDL patches (sdl-libx11-build.patch, sdl-check-for-SDL_VIDEO_X11_BACKINGSTORE.patch,
sdl-sysloadso-buffer-length.patch, libsdl-1.2.15-strict-prototypes.patch) are stored
in flatpaks/virtualbox/ alongside the manifest.

## Lint exceptions — permanent

VirtualBox's upstream `.metainfo.xml` contains screenshots hosted at external URLs
(not mirrored to `https://dl.flathub.org/media`). This causes two permanent lint errors:

- `appstream-external-screenshot-url` — fires at the **builddir** lint stage
- `appstream-screenshots-not-mirrored-in-ostree` — fires at the **repo** lint stage

Both are declared in `exceptions.json` under `org.virtualbox.VirtualBox`. Both must be
present; omitting either will cause the x86_64 build to fail.

Root cause of past failures: the exceptions.json initially only contained
`appid-filename-mismatch`. The screenshot exceptions were added later after CI failures
from runs on commit `2fb7cf5` (the Justfile-First pipeline refactor).
