#!/usr/bin/env bash
# Attach an interactive console to an instance, using tmux when available.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"

INSTANCE="${1:-${RHETSIM_INSTANCE:-$DEFAULT_INSTANCE}}"
validate_instance_name "$INSTANCE"
[ -d "$(instance_workspace "$INSTANCE")" ] || die "instance '$INSTANCE' not found"

if command -v tmux >/dev/null 2>&1; then
    exec tmux new-session -A -s "rhetsim-$INSTANCE" \
        "cd '$ROOT' && ./run.sh start '$INSTANCE'"
fi

warn "tmux not installed; running directly in this terminal"
exec "$ROOT/run.sh" start "$INSTANCE"
