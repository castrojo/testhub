# Rancher Desktop — Gotchas

## finish-args lint exceptions

`flatpak-builder-lint` flags these permissions as errors (Flathub policy); all are intentional
and declared in `exceptions.json`:

- `finish-args-flatpak-spawn-access` — `--talk-name=org.freedesktop.Flatpak` required to
  spawn host processes (open browser, invoke host CLI tools). Same exception as Podman Desktop.
- `finish-args-host-os-ro-filesystem-access` — `--filesystem=host-os:ro` required to detect
  host-installed tools (docker, kubectl, nerdctl) on the host PATH.
- `finish-args-home-filesystem-access` — `--filesystem=home` required (see above).

## x-skip-launch-check: true
Rancher Desktop is an Electron GUI app. In the headless gnome-49 CI container it exits 1
("Missing X server or $DISPLAY" / Wayland not available). `x-skip-launch-check: true` is set
in `manifest.yaml` so the e2e-install job skips the launch check and exits 0 after verifying
the Flatpak installs correctly.

## x86_64 only
Upstream ships a single Linux zip (`rancher-desktop-linux-v1.22.0.zip`) for x86_64 only.
No arm64 Linux build is provided. `x-arches: [x86_64]` is set accordingly.

## --no-sandbox wrapper required
The Electron SUID chrome-sandbox is incompatible with the Flatpak sandbox (cannot set uid 0
inside the sandbox). A wrapper script at `/app/bin/rancher-desktop` passes `--no-sandbox`
to the Electron binary. Flatpak provides its own sandboxing layer.

## --device=all (KVM for Lima VMs)
Rancher Desktop uses Lima as the VM backend on Linux for container runtime isolation.
Lima requires access to `/dev/kvm`. `--device=all` is the standard Flatpak permission for
KVM access. See Podman Desktop for the same pattern.

## --filesystem=home
Rancher Desktop writes config, state, and container data to non-XDG locations under `$HOME`
(`~/.config/rancher-desktop`, `~/.local/share/rancher-desktop`, etc.) with no upstream option
to relocate to XDG paths. `--filesystem=home` is required; tightening will break the app.

## --filesystem=host-os:ro
Required to detect and invoke host-installed tools (docker CLI, nerdctl, kubectl, helm, etc.)
from the host PATH. Modeled directly on the Podman Desktop Flathub manifest.

## finish-args-home-filesystem-access lint exception
`flatpak-builder-lint` flags `--filesystem=home` as a lint warning/error. It is intentional
here; the exception is declared in `exceptions.json`.

## Zip layout (v1.22.0)
The GitHub release zip extracts as a flat directory:
- `rancher-desktop` — main Electron binary (199 MB)
- `resources/resources/icons/logo-square-512.png` — 512×512 app icon
- `resources/resources/linux/rancher-desktop.desktop` — desktop entry
- `resources/app.asar`, `resources/app.asar.unpacked/` — app bundle
- Various Electron/Chromium shared libraries at root
