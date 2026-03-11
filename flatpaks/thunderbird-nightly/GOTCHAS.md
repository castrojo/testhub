# Thunderbird Nightly — Known Issues

## x86_64 only — no aarch64

Thunderbird Nightly does not ship aarch64 Linux binaries. The manifest uses
`only-arches: [x86_64]` on all source blocks. There is no stale-sha256 issue
(unlike firefox-nightly which has aarch64).

## Icon revision pinning (comm-central, not mozilla-central)

Icons come from `comm-central` (not `mozilla-central`). The hg-edge URL pattern is:
```
https://hg-edge.mozilla.org/comm-central/raw-file/<rev>/mail/branding/nightly/default*.png
```

When bumping `x-version`, fetch the new comm-central revision:
```bash
curl -fsSL "https://hg.mozilla.org/comm-central/json-log/tip" \
  | python3 -c "import sys,json; data=json.load(sys.stdin); print(data['changesets'][0]['node'])"
```
Update the revision hash and all icon sha256 values.

## Profile isolation from stable Thunderbird

Uses `--persist=.thunderbird-nightly` (not `.thunderbird`). This keeps the nightly
profile completely separate from any stable `org.mozilla.Thunderbird` installation.

## `.metainfo.xml` extension

The metainfo file uses the `.metainfo.xml` extension (renamed from `.appdata.xml` when the
app-id was changed to `org.mozilla.thunderbird.nightly`). The `appstreamcli validate` step
in `build.yml` globs for `*.metainfo.xml` — this file is now picked up by validation.

## No BaseApp dependency

Thunderbird Nightly does not have a published BaseApp on Flathub (unlike Firefox which
has `org.mozilla.firefox.BaseApp`). Uses `org.freedesktop.Platform//24.08` directly.
No pre-install step needed in clean environments.
