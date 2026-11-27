#!/usr/bin/env bash
# Run the simulator workspace tests from the instance worktree when present.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"

INSTANCE="$DEFAULT_INSTANCE"
while [ $# -gt 0 ]; do
    case "$1" in
        --instance) INSTANCE="$2"; shift 2 ;;
        --instance=*) INSTANCE="${1#*=}"; shift ;;
        --help|-h)
            echo "usage: $0 [--instance NAME] [cargo test args...]"
            echo "  runs cargo test --workspace in the simulator source"
            exit 0
            ;;
        *) break ;;
    esac
done

validate_instance_name "$INSTANCE"
ws="$(instance_workspace "$INSTANCE")"
if [ -e "$ws/src/rhetsim/.git" ]; then
    src="$ws/src/rhetsim"
else
    src="${RHETSIM_SRC:-$REPOS_DIR/rhetsim}"
fi
require_dir "$src"
require_file "$src/Cargo.toml"
require_cmd cargo

log "cargo test --workspace in $src"
log "note: the rhetsim linux_boot test may skip without sibling artifacts; use ./run.sh test boot for the platform boot"
CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$SHARED_DIR/cargo-target}" \
    cargo test --workspace --manifest-path "$src/Cargo.toml" "$@"
