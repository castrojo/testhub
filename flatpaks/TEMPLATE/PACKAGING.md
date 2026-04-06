# testhub packaging quick guide

## Required files for a new `flatpaks/<app>/` directory

1. `manifest.yaml` (Flatpak build definition)
2. `exceptions.json` (lint exceptions, at least `appid-filename-mismatch`)
3. `<app-id>.metainfo.xml` (AppStream metadata)
4. `<app-id>.desktop` (launcher entry; normalize `Exec` + `Icon`)
5. `<app-id>.512x512.png` (icon asset used by desktop + metainfo)

## Key `manifest.yaml` fields

- `x-version`: upstream release version (no leading `v`)
- `x-arches`: explicit supported CPU list (for example `[x86_64]` or `[x86_64, aarch64]`)
- `x-chunkah-max-layers`: chunkah split target (`"24"` for large Electron apps, `"16"` default for most)

Also common for GUI apps:

- `x-skip-launch-check: true` (headless CI launch check workaround)
- `finish-args` include at least:
  - `--socket=wayland`
  - `--socket=fallback-x11`
  - `--share=ipc`
  - `--share=network`

For Electron/AppImage apps:

- `base: org.electronjs.Electron2.BaseApp`
- `base-version: "24.08"`
- `separate-locales: false`
- install a zypak wrapper script in `sources`

## Scaffold a starting manifest

Run:

```bash
just new-app <github-url> <app-id> [version]
```

Example:

```bash
just new-app https://github.com/owner/repo io.github.owner.App
```

This command:

- queries release metadata via GitHub API,
- chooses Linux AppImage/`.tar.gz` assets,
- computes sha256 for the x86_64 asset,
- prints a pre-filled manifest template to stdout.

## Common CI failures and fixes

1. `appid-filename-mismatch`
   - Cause: `manifest.yaml` filename is not `<app-id>.yaml`
   - Fix: add exception in `exceptions.json` for your app-id.

2. `e2e-install` fails with display errors (`Failed to open display`, `no DISPLAY`)
   - Cause: GUI app launched in headless CI
   - Fix: set `x-skip-launch-check: true`.

3. Source checksum mismatch
   - Cause: upstream asset changed or wrong file selected
   - Fix: re-run `just new-app ...`, verify selected asset name, update `sha256`.
