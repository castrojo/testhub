#!/bin/bash
# Pre-activate the org.freedesktop.Flatpak D-Bus service in the background before
# launching ghostty. Ghostty is built with -Dflatpak=true, which makes it connect to
# this service on startup to set up its host-process bridge. On first launch after boot
# the service may not yet be running; D-Bus activation takes ~10 s and blocks ghostty
# from showing its window. Firing the activation here (non-blocking) gives the service
# a head start so it is ready by the time ghostty needs it.
gdbus call --session \
  --dest org.freedesktop.DBus \
  --object-path /org/freedesktop/DBus \
  --method org.freedesktop.DBus.StartServiceByName \
  org.freedesktop.Flatpak 0 2>/dev/null &

exec /app/bin/ghostty "$@"
