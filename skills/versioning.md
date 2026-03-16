# Versioning

Every package must carry an explicit version tag on ghcr.io in addition to `:latest`.

## When to Use
- Changing `x-version`, `version`, source URL, or OCI tag logic
- Adding a new app and setting its version fields

## When NOT to Use
- OCI label mechanics → `skills/flatpak-labels.md`
- Renovate version tracking → `skills/renovate.md`

## Tag convention

| Build path | Version source | Tags pushed |
|---|---|---|
| `release.yaml` (bundle-repack) | `version:` field | `latest-<arch>`, `v1.2.3-<arch>`, `stable-<arch>` |
| `manifest.yaml` (flatpak-builder) | `x-version:` field | `latest-<arch>`, `1.2.3-<arch>`, `stable-<arch>` |

## Rules

- `release.yaml` apps: `version` is a required field — CI errors if missing.
- `manifest.yaml` apps: add `x-version: "<version>"` as a top-level field.
  flatpak-builder ignores `x-`-prefixed fields — safe to add.
- If `x-version` is absent **or set to an empty string (`x-version: ''`)**, the build
  warns and pushes `:latest` only. Both cases are equivalent failures — always set a
  real version string.
- Version strings must reflect the actual upstream app version — not build dates,
  git shas, or repo versions.
- When upgrading an app, update `x-version` (or `version`) in the same commit that
  updates the source URL and sha256.
- **Checking the current version:** use the Flathub API:
  `curl -s https://flathub.org/api/v2/appstream/<app-id> | python3 -c "import json,sys; d=json.load(sys.stdin); print([r['version'] for r in d.get('releases',[])][:3])"`

## Source URL convention (manifest.yaml apps)

Always use immutable versioned tag archive URLs:

```
# Correct
https://github.com/ghostty-org/ghostty/archive/refs/tags/v1.3.0.tar.gz

# Wrong — content changes without notice
https://github.com/ghostty-org/ghostty/archive/refs/heads/main.tar.gz
https://github.com/ghostty-org/ghostty/archive/tip.tar.gz
```

Never use rolling `tip`, `latest`, or branch archive URLs. Find the exact tag URL and
update sha256 in the same commit.

### Exception: Mozilla nightly apps (intentional rolling URLs)

`firefox-nightly` and `thunderbird-nightly` are an intentional exception to the rule above.
They use Mozilla's rolling `latest-mozilla-central` and `latest-comm-central` CDN paths
because Mozilla does not publish versioned archives for nightly builds — only the single
"latest" tarball is available.

Consequences:
- **aarch64 sha256 is stale by design** for firefox-nightly. Do not attempt to permanently
  pin it; the ETag-based update workflow refreshes it when Mozilla rebuilds.
- **x-version stays fixed** (`150.0a1`) — Mozilla never increments the nightly version
  string; each daily rebuild is a new binary at the same URL.
- The ETag-based `update-mozilla-nightly.yml` workflow handles SHA256 refresh; it opens
  a PR on `chore/nightly-sha256-YYYYMMDD` when Mozilla rebuilds.

Never "fix" these apps to use pinned versioned URLs — no such URLs exist.
