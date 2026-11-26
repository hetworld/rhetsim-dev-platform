#!/usr/bin/env bash
# Export an instance's runtime artifacts and config as a portable tarball.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"

INSTANCE="${1:-$DEFAULT_INSTANCE}"
validate_instance_name "$INSTANCE"
ws="$(instance_workspace "$INSTANCE")"
require_dir "$ws"
require_dir "$ws/bin"

mkdir -p "$DIST_DIR/instances"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
archive="$DIST_DIR/instances/$INSTANCE-$stamp.tar.gz"
tar -czhf "$archive" -C "$ws" bin config
sha256="$(sha256_of "$archive")"
printf '%s  %s\n' "$sha256" "$(basename "$archive")" > "$archive.sha256"
log "exported: $archive"
log "sha256:   $sha256"
