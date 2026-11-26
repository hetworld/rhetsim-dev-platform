#!/usr/bin/env bash
# Publish a packaged SDK to the software-dev-platform repository.
# Default is a dry run; pass --execute to actually create the GitHub release.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"

VERSION="${VERSION:-0.1.0-dev}"
REPO="${REPO:-hetworld/rhetsim-software-dev-platform}"
EXECUTE=0
while [ $# -gt 0 ]; do
    case "$1" in
        --version) VERSION="$2"; shift 2 ;;
        --version=*) VERSION="${1#*=}"; shift ;;
        --repo) REPO="$2"; shift 2 ;;
        --repo=*) REPO="${1#*=}"; shift ;;
        --execute) EXECUTE=1; shift ;;
        --help|-h) echo "usage: $0 [--version VER] [--repo OWNER/REPO] [--execute]"; exit 0 ;;
        *) die "unknown argument: $1" ;;
    esac
done

archive="$DIST_DIR/rhetsim-sdk-$VERSION.tar.gz"
checksum="$archive.sha256"
require_file "$archive"
require_file "$checksum"

cmd=(gh release create "v$VERSION" "$archive" "$checksum"
     --repo "$REPO"
     --title "RhetSim SDK $VERSION"
     --notes "RhetSim SDK $VERSION. See manifest.json inside the bundle for components, checksums and licenses.")

if [ "$EXECUTE" -eq 0 ]; then
    log "dry run; would execute:"
    printf '  %q' "${cmd[@]}"
    printf '\n'
    log "rerun with --execute to publish"
    exit 0
fi

require_cmd gh
"${cmd[@]}"
