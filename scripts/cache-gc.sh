#!/usr/bin/env bash
# Garbage-collect unreferenced shared build entries.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"

DAYS=7
DELETE=0
while [ $# -gt 0 ]; do
    case "$1" in
        --days) DAYS="$2"; shift 2 ;;
        --days=*) DAYS="${1#*=}"; shift ;;
        --yes|-y) DELETE=1; shift ;;
        --dry-run) DELETE=0; shift ;;
        --help|-h) echo "usage: $0 [--days N] [--dry-run|--yes]"; exit 0 ;;
        *) die "unknown argument: $1" ;;
    esac
done

[ -d "$SHARED_DIR/build" ] || { log "no shared build cache"; exit 0; }

declare -A referenced=()
while IFS= read -r build_id; do
    [ -n "$build_id" ] && referenced["$build_id"]=1
done < <(python3 - "$WORKSPACE_DIR" <<'PY'
import glob
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
for path in glob.glob(str(root / "instances" / "*" / "bin" / "runtime.manifest.json")):
    try:
        data = json.loads(Path(path).read_text())
    except (OSError, json.JSONDecodeError):
        continue
    for artifact in data.get("artifacts", {}).values():
        build_id = artifact.get("build_id")
        if build_id:
            print(build_id)
PY
)

found=0
while IFS= read -r dir; do
    [ -n "$dir" ] || continue
    build_id="$(basename "$dir")"
    if [ -n "${referenced[$build_id]:-}" ]; then
        continue
    fi
    found=$((found + 1))
    if [ "$DELETE" -eq 1 ]; then
        log "remove $dir"
        rm -rf "$dir"
    else
        echo "$dir"
    fi
done < <(find "$SHARED_DIR/build" -mindepth 2 -maxdepth 2 -type d -mtime +"$DAYS" 2>/dev/null)

if [ "$found" -eq 0 ]; then
    log "nothing to collect"
elif [ "$DELETE" -eq 0 ]; then
    log "$found entr(y/ies) unreferenced; rerun with --yes to delete"
fi
