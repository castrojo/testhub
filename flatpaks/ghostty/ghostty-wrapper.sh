#!/bin/bash
# Pre-warm D-Bus services synchronously before starting ghostty.
#
# On first launch after boot two services are often not yet running:
#
#   org.freedesktop.portal.Desktop  — xdg-desktop-portal, used by ghostty for
#     GlobalShortcuts (registered on every startup) and portal settings queries.
#
#   org.freedesktop.Flatpak  — flatpak-session-helper, used by ghostty's
#     FlatpakHostCommand to spawn shells/commands on the host system.
#
# We make real method calls (not just StartServiceByName) so we block until
# each service is fully initialized and ready to serve requests — not merely
# until it has claimed its D-Bus name.  This matters for xdg-desktop-portal
# in particular: it claims its name quickly but may spend several more seconds
# loading its backends (e.g. when xdg-desktop-portal-gnome and
# xdg-desktop-portal-gtk are both installed and must be arbitrated).  Without
# this deeper wait, ghostty's own portal calls arrive before backends are ready
# and block for up to ~10 s.

# Settings.ReadAll: forces xdg-desktop-portal to finish loading all backends
# before returning.  Ghostty reads appearance settings (color-scheme, etc.)
# on startup, so this also pre-fetches data ghostty will need immediately.
gdbus call --session --timeout 15 \
  --dest org.freedesktop.portal.Desktop \
  --object-path /org/freedesktop/portal/desktop \
  --method org.freedesktop.portal.Settings.ReadAll \
  "['org.freedesktop.appearance']" 2>/dev/null || true

# RequestSession: proves flatpak-session-helper is ready to accept
# FlatpakHostCommand calls (which ghostty uses to spawn shells on the host).
gdbus call --session --timeout 15 \
  --dest org.freedesktop.Flatpak \
  --object-path /org/freedesktop/Flatpak/SessionHelper \
  --method org.freedesktop.Flatpak.SessionHelper.RequestSession \
  2>/dev/null || true

exec /app/bin/ghostty "$@"
