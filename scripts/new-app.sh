#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: scripts/new-app.sh <github-url> <app-id> [version]" >&2
    echo "Example: scripts/new-app.sh https://github.com/owner/app io.github.owner.App v1.0.0" >&2
}

if [[ $# -lt 2 || $# -gt 3 ]]; then
    usage
    exit 1
fi

github_url="$1"
app_id="$2"
version="${3:-latest}"

normalize_github_path() {
    local url="$1"
    url="${url#git@github.com:}"
    url="${url#https://github.com/}"
    url="${url#http://github.com/}"
    url="${url#github.com/}"
    url="${url%.git}"
    url="${url%%\?*}"
    url="${url%%#*}"
    echo "$url"
}

repo_path="$(normalize_github_path "$github_url")"
owner="${repo_path%%/*}"
rest="${repo_path#*/}"
repo="${rest%%/*}"

if [[ -z "$owner" || -z "$repo" || "$owner" == "$repo_path" ]]; then
    echo "ERROR: unable to parse owner/repo from URL: $github_url" >&2
    exit 1
fi

if [[ "$version" == "latest" ]]; then
    endpoint="repos/${owner}/${repo}/releases/latest"
else
    endpoint="repos/${owner}/${repo}/releases/tags/${version}"
fi

echo "==> Fetching release data from ${owner}/${repo} (${version})" >&2

release_json="$(gh api "$endpoint")"
tag_name="$(echo "$release_json" | jq -r '.tag_name // ""')"
published_at="$(echo "$release_json" | jq -r '.published_at // .created_at // ""' | cut -dT -f1)"

if [[ -z "$tag_name" || "$tag_name" == "null" ]]; then
    echo "ERROR: release tag_name is missing" >&2
    exit 1
fi

declare -a asset_names=()
declare -a asset_urls=()

while IFS=$'\t' read -r name url; do
    [[ -z "${name:-}" || -z "${url:-}" ]] && continue
    lower_name="$(echo "$name" | tr '[:upper:]' '[:lower:]')"
    if [[ "$lower_name" == *.appimage ]] || [[ "$lower_name" == *.tar.gz ]]; then
        if [[ "$lower_name" =~ (darwin|macos|windows|win32|win64|\.exe|\.msi|\.dmg) ]]; then
            continue
        fi
        asset_names+=("$name")
        asset_urls+=("$url")
    fi
done < <(echo "$release_json" | jq -r '.assets[]? | [.name, .browser_download_url] | @tsv')

if [[ "${#asset_names[@]}" -eq 0 ]]; then
    echo "ERROR: no Linux AppImage/.tar.gz assets found in release ${tag_name}" >&2
    exit 1
fi

echo "==> Candidate assets:" >&2
for name in "${asset_names[@]}"; do
    echo "  - $name" >&2
done

has_aarch64="false"
for name in "${asset_names[@]}"; do
    lower_name="$(echo "$name" | tr '[:upper:]' '[:lower:]')"
    if [[ "$lower_name" =~ (aarch64|arm64|armv8) ]]; then
        has_aarch64="true"
        break
    fi
done

x86_index="-1"
for i in "${!asset_names[@]}"; do
    lower_name="$(echo "${asset_names[$i]}" | tr '[:upper:]' '[:lower:]')"
    if [[ "$lower_name" =~ (x86_64|amd64|x64) ]]; then
        x86_index="$i"
        break
    fi
done

if [[ "$x86_index" == "-1" ]]; then
    for i in "${!asset_names[@]}"; do
        lower_name="$(echo "${asset_names[$i]}" | tr '[:upper:]' '[:lower:]')"
        if [[ ! "$lower_name" =~ (aarch64|arm64|armv8) ]]; then
            x86_index="$i"
            break
        fi
    done
fi

if [[ "$x86_index" == "-1" ]]; then
    echo "ERROR: unable to determine x86_64 asset from release assets" >&2
    exit 1
fi

x86_asset_name="${asset_names[$x86_index]}"
x86_asset_url="${asset_urls[$x86_index]}"
lower_x86_asset="$(echo "$x86_asset_name" | tr '[:upper:]' '[:lower:]')"

echo "==> x86_64 asset: $x86_asset_name" >&2
echo "==> Computing sha256..." >&2
sha256="$(curl -fsSL "$x86_asset_url" | sha256sum | awk '{print $1}')"

is_electron="false"
if [[ "$lower_x86_asset" == *.appimage ]] || [[ "$lower_x86_asset" == *electron* ]]; then
    is_electron="true"
fi

x_version="${tag_name#v}"
repo_url="https://github.com/${owner}/${repo}"
command_name="$(echo "$repo" | tr '[:upper:]' '[:lower:]')"
command_name="$(echo "$command_name" | sed -E 's/[^a-z0-9._-]+/-/g')"
arches="[x86_64]"
if [[ "$has_aarch64" == "true" ]]; then
    arches="[x86_64, aarch64]"
fi

if [[ "$is_electron" == "true" ]]; then
    cat <<EOF
app-id: ${app_id}
runtime: org.freedesktop.Platform
runtime-version: "24.08"
sdk: org.freedesktop.Sdk
base: org.electronjs.Electron2.BaseApp
base-version: "24.08"
default-branch: stable
x-version: "${x_version}"
x-arches: ${arches}
x-chunkah-max-layers: "24"
x-skip-launch-check: true
separate-locales: false
command: ${command_name}
finish-args:
  - --device=dri
  - --share=ipc
  - --share=network
  - --socket=fallback-x11
  - --socket=wayland
  - --socket=pulseaudio
  - --talk-name=org.freedesktop.portal.Desktop
  - --talk-name=org.freedesktop.Notifications
modules:
  - name: ${repo}
    buildsystem: simple
    build-commands:
      - chmod +x "${x86_asset_name}"
      - ./"${x86_asset_name}" --appimage-extract
      - mv squashfs-root "/app/${command_name}"
    sources:
      - type: file
        url: ${x86_asset_url}
        sha256: ${sha256}
        dest-filename: ${x86_asset_name}
      - type: script
        dest-filename: ${command_name}
        commands:
          - exec zypak-wrapper /app/${command_name}/YOUR_BINARY_NAME "\$@"  # TODO: verify binary name inside extracted AppImage
      - type: file
        path: ${app_id}.metainfo.xml
      - type: file
        path: ${app_id}.desktop
      - type: file
        path: ${app_id}.512x512.png

# Source release: ${repo_url}/releases/tag/${tag_name}
# Published date: ${published_at}
EOF
else
    cat <<EOF
app-id: ${app_id}
runtime: org.gnome.Platform
runtime-version: "49"
sdk: org.gnome.Sdk
default-branch: stable
x-version: "${x_version}"
x-arches: ${arches}
x-chunkah-max-layers: "16"
x-skip-launch-check: true
command: ${command_name}
finish-args:
  - --device=dri
  - --share=ipc
  - --share=network
  - --socket=fallback-x11
  - --socket=wayland
  - --talk-name=org.freedesktop.portal.Desktop
  - --talk-name=org.freedesktop.Notifications
modules:
  - name: ${repo}
    buildsystem: simple
    build-commands:
      - tar -xf "${x86_asset_name}"
      - echo "TODO: install extracted files to /app"
    sources:
      - type: file
        url: ${x86_asset_url}
        sha256: ${sha256}
        dest-filename: ${x86_asset_name}
      - type: file
        path: ${app_id}.metainfo.xml
      - type: file
        path: ${app_id}.desktop
      - type: file
        path: ${app_id}.512x512.png

# Source release: ${repo_url}/releases/tag/${tag_name}
# Published date: ${published_at}
EOF
fi
