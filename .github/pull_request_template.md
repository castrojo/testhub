## Package checklist

- [ ] `just validate <app>` passes (schema + appstreamcli + flatpak-builder-lint)
- [ ] `just loop <app>` passes (full local build + local registry push)
- [ ] Icon present at 128×128 minimum (`/app/share/icons/hicolor/128x128/apps/<app-id>.png`)
- [ ] `x-version` (manifest.yaml) or `version` (release.yaml) field set to upstream version
- [ ] Source URL is immutable — no rolling `tip`, `latest`, or branch archive URLs
- [ ] `sha256` matches downloaded artifact
- [ ] `finish-args` reviewed — each permission justified; non-obvious ones have inline comments
- [ ] MetaInfo XML present and passes `appstreamcli validate --no-net`
- [ ] Proprietary app: first `<p>` in description contains disclaimer
