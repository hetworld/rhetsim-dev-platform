#!/usr/bin/env bash
# Remove an instance workspace and prune its git worktrees. Keeps the definition.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"

INSTANCE="${1:-$DEFAULT_INSTANCE}"
YES=0
while [ $# -gt 0 ]; do
    case "$1" in
        --yes|-y) YES=1; shift ;;
        --help|-h) echo "usage: $0 <instance> [--yes]"; exit 0 ;;
        -*) die "unknown argument: $1" ;;
        *) INSTANCE="$1"; shift ;;
    esac
done
validate_instance_name "$INSTANCE"
ws="$(instance_workspace "$INSTANCE")"
case "$ws" in "$INSTANCES_DIR"/*) ;; *) die "refusing to remove unexpected path: $ws" ;; esac
[ -d "$ws" ] || die "instance not found: $ws"

if [ "$YES" -eq 0 ]; then
    read -r -p "Destroy instance '$INSTANCE' at $ws? [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]] || { echo "aborted"; exit 1; }
fi

rm -rf "$ws"
for repo in "$REPOS_DIR/rhetsim" "$REPOS_DIR/software/linux" "$REPOS_DIR/software/opensbi" \
            "$REPOS_DIR/software/rhetsim-initramfs"; do
    [ -d "$repo/.git" ] && git -C "$repo" worktree prune
done
log "destroyed instance '$INSTANCE' (definition kept in env/instances/$INSTANCE)"
