#!/usr/bin/env bash
# Materialize env/instances/<name>/ into workspace/instances/<name>/.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"

INSTANCE=""
FORCE=0
WORKTREES=()
while [ $# -gt 0 ]; do
    case "$1" in
        --instance) INSTANCE="$2"; shift 2 ;;
        --instance=*) INSTANCE="${1#*=}"; shift ;;
        --force) FORCE=1; shift ;;
        --worktree) WORKTREES+=("$2"); shift 2 ;;
        --worktree=*) WORKTREES+=("${1#*=}"); shift ;;
        --no-worktrees) WORKTREES=("__none__"); shift ;;
        --help|-h)
            echo "usage: $0 <instance> [--force] [--worktree COMPONENT]... [--no-worktrees]"
            exit 0
            ;;
        -*) die "unknown argument: $1" ;;
        *) INSTANCE="$1"; shift ;;
    esac
done

INSTANCE="${INSTANCE:-$DEFAULT_INSTANCE}"
validate_instance_name "$INSTANCE"
[ "${WORKTREES[0]:-}" = "__none__" ] && WORKTREES=()
[ ${#WORKTREES[@]} -eq 0 ] && WORKTREES=(rhetsim)

definition="$(instance_definition "$INSTANCE")"
ws="$(instance_workspace "$INSTANCE")"
require_dir "$definition"

mkdir -p "$ws/bin" "$ws/logs" "$ws/src" "$ws/run/disks" "$ws/run/sessions"

if [ -d "$ws/config" ] && [ "$FORCE" -eq 0 ]; then
    log "instance '$INSTANCE' already exists at $ws"
    log "use --force to refresh config from $definition"
else
    rm -rf "$ws/config"
    mkdir -p "$ws/config"
    cp -a "$definition"/. "$ws/config"/
    log "config materialized from $definition"
fi

entries=()
for comp in "${WORKTREES[@]}"; do
    repo_path="$(component_get "$comp" path)"
    repo="$REPOS_DIR/$repo_path"
    ref="$(component_ref "$comp")"
    rel="$(instance_src_path "$comp")"
    dest="$ws/$rel"
    if [ ! -d "$repo/.git" ]; then
        warn "worktree skipped for $comp: $repo is not a git checkout (run scripts/fetch-sources.sh)"
        continue
    fi
    if [ -e "$dest" ]; then
        log "worktree already present: $rel"
    else
        mkdir -p "$(dirname "$dest")"
        git -C "$repo" worktree add --detach "$dest" "$ref"
        log "worktree $comp at $ref -> $rel"
    fi
    entries+=("$comp|$rel|$repo_path|$ref")
done

python3 - "$ws/src/.checkouts.json" "${entries[@]}" <<'PY'
import json
import sys

path = sys.argv[1]
entries = {}
for item in sys.argv[2:]:
    name, rel, repo, ref = item.split("|", 3)
    entries[name] = {"kind": "worktree", "path": rel, "repo": repo, "ref": ref}
with open(path, "w", encoding="utf-8") as f:
    json.dump(entries, f, indent=2, sort_keys=True)
    f.write("\n")
PY

log "instance '$INSTANCE' ready at $ws"
log "next: scripts/instance-build.sh $INSTANCE"
