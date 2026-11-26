#!/usr/bin/env bash
# Clean instance build/run state. Keeps config/, src/ and the definition.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"

INSTANCE="$DEFAULT_INSTANCE"
ALL=0
YES=0
while [ $# -gt 0 ]; do
    case "$1" in
        --instance) INSTANCE="$2"; shift 2 ;;
        --instance=*) INSTANCE="${1#*=}"; shift ;;
        --all) ALL=1; shift ;;
        --yes|-y) YES=1; shift ;;
        --help|-h) echo "usage: $0 [--instance NAME] [--all] [--yes]"; exit 0 ;;
        *) die "unknown argument: $1" ;;
    esac
done

validate_instance_name "$INSTANCE"
ws="$(instance_workspace "$INSTANCE")"
case "$ws" in "$INSTANCES_DIR"/*) ;; *) die "refusing to clean unexpected path: $ws" ;; esac
[ -d "$ws" ] || die "instance not found: $ws"

targets=("$ws/bin" "$ws/logs" "$ws/run")
[ "$ALL" -eq 1 ] && targets=("$ws")

if [ "$YES" -eq 0 ]; then
    printf 'Will remove:\n'
    printf '  %s\n' "${targets[@]}"
    read -r -p "Continue? [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]] || { echo "aborted"; exit 1; }
fi

if [ "$ALL" -eq 1 ]; then
    rm -rf "$ws"
    log "removed instance workspace: $ws"
else
    rm -rf "${targets[@]}"
    mkdir -p "$ws/run/disks" "$ws/run/sessions"
    log "cleaned bin/, logs/ and run/ for '$INSTANCE'"
fi
