# Ghostty — Known Issues

## Sandbox escape (intentional)

`--talk-name=org.freedesktop.Flatpak` grants a full sandbox escape so the terminal emulator
can launch host processes (shells, editors, arbitrary commands). Without it Ghostty cannot
function as a terminal.

**Flathub would reject this outright.** This repo is a personal OCI remote, not a Flathub
submission. The exception is acceptable here but must never be proposed to Flathub.

If Ghostty is ever submitted to Flathub the sandbox escape must be removed or replaced with
a portal-based mechanism. Track the upstream issue tracker for portal support.

## 10-second first-launch-after-boot delay (GNOME Wayland)

**Symptom:** Ghostty takes ~10 seconds to open its window on the first launch after each
boot on GNOME Wayland.

**Root cause (two services, both cold on first boot):**

1. `org.freedesktop.portal.Desktop` (xdg-desktop-portal) — ghostty calls this on every
   startup for GlobalShortcuts registration and portal settings queries. If not yet
   running, the call stalls until the portal activates.

2. `org.freedesktop.Flatpak` (flatpak-session-helper) — required for
   `FlatpakHostCommand`, the mechanism ghostty uses (when built with `-Dflatpak=true`)
   to spawn shells on the host. If not running, the first shell spawn blocks for ~10 s.

Both services are D-Bus-activated. Cold-start D-Bus activation has a ~10-second timeout
window. Either service being cold is sufficient to trigger the symptom.

**Fix:** `ghostty-wrapper.sh` is installed as the Flatpak `command`. It makes
**real method calls** to each service before exec-ing ghostty — not just
`StartServiceByName`.  The distinction matters:

- `StartServiceByName` returns as soon as the service claims its D-Bus name.
  xdg-desktop-portal claims its name quickly but then loads backends
  asynchronously.  If both `xdg-desktop-portal-gnome` and
  `xdg-desktop-portal-gtk` are installed (common on Fedora/RHEL), backend
  arbitration can take several more seconds after the name is claimed.

- A real method call blocks until the service is **fully ready** to respond.

Method calls used:
- `org.freedesktop.portal.Settings.ReadAll ['org.freedesktop.appearance']`
  — forces xdg-desktop-portal to finish loading all backends; also pre-fetches
  appearance settings ghostty reads on startup.
- `org.freedesktop.Flatpak.SessionHelper.RequestSession`
  — proves flatpak-session-helper is ready for `FlatpakHostCommand` calls.

**Diagnosis (if the delay recurs or changes in character):**
```bash
# 1. Check which services are on the session bus before launching
gdbus call --session --dest org.freedesktop.DBus \
  --object-path /org/freedesktop/DBus \
  --method org.freedesktop.DBus.ListNames 2>/dev/null | tr ',' '\n' \
  | grep -E 'flatpak|portal'

# 2. Time the wrapper's readiness probes directly (run after a reboot, before ghostty)
time gdbus call --session --timeout 15 \
  --dest org.freedesktop.portal.Desktop \
  --object-path /org/freedesktop/portal/desktop \
  --method org.freedesktop.portal.Settings.ReadAll \
  "['org.freedesktop.appearance']"

time gdbus call --session --timeout 15 \
  --dest org.freedesktop.Flatpak \
  --object-path /org/freedesktop/Flatpak/SessionHelper \
  --method org.freedesktop.Flatpak.SessionHelper.RequestSession

# 3. Check user journal for portal/helper activation errors
journalctl --user -xe | grep -E 'portal|flatpak' | tail -30

# 4. Isolate GTK4 shader compilation (if delay survives the wrapper fix)
GSK_RENDERER=cairo flatpak run --user com.mitchellh.ghostty
# Fast with cairo → GPU shader compilation is contributing; add --env=GSK_RENDERER=gl to finish-args
```

**If the delay persists after the wrapper fix:**
Check `journalctl --user -xe` for portal errors around launch time.  The wrapper
uses `--timeout 15` and `|| true` so a failing probe is skipped rather than
hanging indefinitely — but a failing portal suggests a deeper system issue
(e.g. conflicting portal implementations) that needs to be resolved on the host.

## Aggressive cleanup globs

`cleanup` includes `"*.so"` and `"*.a"`. This is safe because Zig links statically — no
runtime `.so` files are needed. If any future module adds a shared-lib dependency these
globs will silently strip it. Verify after any new module is added.

## `--device=all`

Required for GPU (Vulkan) and PTY device access. Flathub would require narrowing this to
specific devices. Intentional for now.

## exceptions.json — lint suppressions

In addition to the standard non-Flathub exceptions, ghostty suppresses:

| Exception | Reason |
|---|---|
| `finish-args-unnecessary-xdg-config-ghostty-ro-access` | Ghostty reads its own config from XDG; linter flags this as unnecessary but it is required |
| `finish-args-flatpak-spawn-access` | Required for sandbox escape (see above) — linter flags it, intentional |
| `metainfo-missing-screenshots` | Personal hosting repo — no screenshots maintained |
