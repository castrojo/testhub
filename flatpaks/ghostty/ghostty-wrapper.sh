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
# gdbus StartServiceByName blocks until the D-Bus name is claimed (~ms when
# the service is already running, a few seconds when it must be activated).
# Running both calls here means ghostty starts with both services already up,
# so its internal D-Bus calls return immediately instead of blocking for ~10 s
# waiting for cold-start activation.
gdbus call --session \
  --dest org.freedesktop.DBus \
  --object-path /org/freedesktop/DBus \
  --method org.freedesktop.DBus.StartServiceByName \
  org.freedesktop.portal.Desktop 0 2>/dev/null || true

gdbus call --session \
  --dest org.freedesktop.DBus \
  --object-path /org/freedesktop/DBus \
  --method org.freedesktop.DBus.StartServiceByName \
  org.freedesktop.Flatpak 0 2>/dev/null || true

exec /app/bin/ghostty "$@"
