#!/usr/bin/env bash
# Fetch pinned component sources into repos/ according to env/versions.toml.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"

require_cmd git
require_cmd curl
require_cmd sha256sum
require_cmd tar

mkdir -p "$REPOS_DIR" "$REPOS_DIR/downloads" \
         "$REPOS_DIR/software" "$REPOS_DIR/toolchain"

while IFS=$'\t' read -r name type url ref path sha archive strip; do
    [ -n "$name" ] || continue
    dest="$REPOS_DIR/$path"
    case "$type" in
        git)
            if [ ! -d "$dest/.git" ]; then
                log "clone $name -> $path"
                mkdir -p "$(dirname "$dest")"
                git clone "$url" "$dest"
            else
                log "fetch $name"
                git -C "$dest" fetch --all --tags --prune
            fi
            if [ -n "$ref" ]; then
                log "checkout $name at $ref"
                git -C "$dest" checkout --detach "$ref"
            fi
            ;;
        tar)
            [ -n "$archive" ] || die "$name: missing archive name"
            archive_path="$REPOS_DIR/downloads/$archive"
            if [ ! -f "$archive_path" ]; then
                log "download $name"
                curl -fL --retry 3 -o "$archive_path.part" "$url"
                mv "$archive_path.part" "$archive_path"
            fi
            if [ -n "$sha" ]; then
                actual="$(sha256_of "$archive_path")"
                [ "$actual" = "$sha" ] || die "$name: sha256 mismatch for $archive"
            fi
            if [ ! -d "$dest" ] || [ -z "$(ls -A "$dest" 2>/dev/null)" ]; then
                log "extract $name -> $path"
                mkdir -p "$dest"
                tar -xf "$archive_path" -C "$dest" --strip-components="${strip:-1}"
            else
                log "skip $name (already extracted at $path)"
            fi
            ;;
        *)
            die "$name: unknown source type '$type'"
            ;;
    esac
done < <(python3 "$(versions_tool)" list)

log "sources ready under $REPOS_DIR"
