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

**Root cause:** Ghostty is built with `-Dflatpak=true`, which enables an internal D-Bus
bridge to `org.freedesktop.Flatpak` used for launching host processes (shells, editors)
outside the sandbox. On first launch after boot, if `flatpak-session-helper` is not yet
running, D-Bus must activate it synchronously — a D-Bus activation cold-start takes
exactly ~10 seconds.

**Fix:** `ghostty-wrapper.sh` is installed as the Flatpak `command`. It fires a
non-blocking `gdbus StartServiceByName org.freedesktop.Flatpak` call in the background
before exec-ing ghostty, giving the service time to start up before ghostty's internal
bridge tries to connect.

**Diagnosis (if the delay recurs or changes in character):**
```bash
# 1. Check whether org.freedesktop.Flatpak is on the session bus before launching
gdbus call --session --dest org.freedesktop.DBus \
  --object-path /org/freedesktop/DBus \
  --method org.freedesktop.DBus.ListNames 2>/dev/null | tr ',' '\n' | grep flatpak

# 2. Isolate GTK4 shader compilation (if delay survives the wrapper fix)
GSK_RENDERER=cairo flatpak run --user com.mitchellh.ghostty
# Fast with cairo → shader compilation is the remaining cause; add --env=GSK_RENDERER=gl to finish-args

# 3. Trace D-Bus calls
DBUS_VERBOSE=1 flatpak run --user com.mitchellh.ghostty 2>&1 | head -80
```

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
