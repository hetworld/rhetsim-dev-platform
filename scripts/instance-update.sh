#!/usr/bin/env bash
# Refresh an instance's config from its env/instances definition.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"

INSTANCE="${1:-$DEFAULT_INSTANCE}"
validate_instance_name "$INSTANCE"
definition="$(instance_definition "$INSTANCE")"
ws="$(instance_workspace "$INSTANCE")"
require_dir "$definition"
require_dir "$ws"

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
if [ -d "$ws/config" ]; then
    cp -a "$ws/config" "$ws/config.bak.$stamp"
    log "backup: $ws/config.bak.$stamp"
fi
rm -rf "$ws/config"
mkdir -p "$ws/config"
cp -a "$definition"/. "$ws/config"/
log "config refreshed from $definition"
log "bin/, logs/, src/ and run/ were left untouched"
