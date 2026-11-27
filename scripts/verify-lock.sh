#!/usr/bin/env bash
# Verify that repos/ matches env/versions.toml.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"

usage() {
    cat <<'EOF'
usage: ./run.sh verify-lock

Checks every component in env/versions.toml:
  - git: canonical clone exists, has the pinned commit, HEAD is at it, no tracked changes.
  - tar: downloaded archive matches sha256 and the extracted tree exists.
EOF
}

case "${1:-}" in
    --help|-h) usage; exit 0 ;;
    "") ;;
    *) die "unknown argument: $1" ;;
esac

LOCK="$ENV_DIR/versions.toml"
require_file "$LOCK"
require_cmd git
require_cmd sha256sum

fail=0
count=0
while IFS='|' read -r name type url ref path sha archive _strip; do
    [ -n "$name" ] || continue
    count=$((count + 1))
    dest="$REPOS_DIR/$path"
    case "$type" in
        git)
            if [ ! -d "$dest/.git" ]; then
                echo "MISSING $name: $dest"
                fail=1
                continue
            fi
            if ! git -C "$dest" cat-file -e "$ref^{commit}" 2>/dev/null; then
                echo "BADREF  $name: commit $ref not found in $dest"
                fail=1
                continue
            fi
            head="$(git -C "$dest" rev-parse HEAD)"
            if [ "$head" != "$ref" ]; then
                echo "DRIFT   $name: HEAD=$head expected=$ref"
                fail=1
            fi
            if ! git -C "$dest" diff --quiet HEAD --; then
                echo "DIRTY   $name: tracked changes in $dest"
                fail=1
            fi
            ;;
        tar)
            archive_path="$REPOS_DIR/downloads/$archive"
            if [ ! -f "$archive_path" ]; then
                echo "MISSING $name: $archive_path"
                fail=1
                continue
            fi
            actual="$(sha256_of "$archive_path")"
            if [ "$actual" != "$sha" ]; then
                echo "SHA     $name: $actual != $sha"
                fail=1
            fi
            if [ ! -d "$dest" ] || [ -z "$(ls -A "$dest" 2>/dev/null)" ]; then
                echo "MISSING $name: extracted tree $dest"
                fail=1
            fi
            ;;
        *)
            echo "TYPE    $name: unknown type '$type'"
            fail=1
            ;;
    esac
done < <(python3 "$(versions_tool)" list)

if [ "$fail" -ne 0 ]; then
    die "lock verification failed ($count components); run ./run.sh fetch or fix the pin"
fi
log "lock verified: $count components"
