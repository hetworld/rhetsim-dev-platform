#!/usr/bin/env bash
# Update one component pin in env/versions.toml (the committed lock file).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"

usage() {
    cat <<'EOF'
usage: ./run.sh pin <component> [ref] [options]

Update env/versions.toml (the lock file). Builds only read this file.

Options:
  --ref <ref>            Git ref or commit (alternative to the positional ref)
  --from-local <path>    Resolve the ref from a local checkout (default: HEAD)
  --file <path>          Tarball archive for a tar component
  --dry-run              Show the change without writing

Examples:
  ./run.sh pin rhetsim 9d4a1dd3b9fb4ac263a68b9285bb197769eccb35
  ./run.sh pin rhetsim dev --from-local /home/leo/leo/workspace/rhet/rhetsim
  ./run.sh pin busybox --file repos/downloads/busybox-1.36.1.tar.bz2
EOF
}

COMPONENT=""
REF=""
FROM_LOCAL=""
FILE=""
DRY_RUN=0
while [ $# -gt 0 ]; do
    case "$1" in
        --ref) REF="$2"; shift 2 ;;
        --ref=*) REF="${1#*=}"; shift ;;
        --from-local) FROM_LOCAL="$2"; shift 2 ;;
        --from-local=*) FROM_LOCAL="${1#*=}"; shift ;;
        --file|-f) FILE="$2"; shift 2 ;;
        --file=*) FILE="${1#*=}"; shift ;;
        --dry-run) DRY_RUN=1; shift ;;
        --help|-h) usage; exit 0 ;;
        -*) die "unknown argument: $1" ;;
        *)
            if [ -z "$COMPONENT" ]; then
                COMPONENT="$1"
            elif [ -z "$REF" ]; then
                REF="$1"
            else
                die "unexpected argument: $1"
            fi
            shift
            ;;
    esac
done

[ -n "$COMPONENT" ] || { usage >&2; exit 1; }
LOCK="$ENV_DIR/versions.toml"
require_file "$LOCK"
require_cmd python3

type="$(component_get "$COMPONENT" type)"
[ -n "$type" ] || die "unknown component: $COMPONENT"

case "$type" in
    git)
        if [ -n "$FROM_LOCAL" ]; then
            require_dir "$FROM_LOCAL"
            require_cmd git
            ref="$(git -C "$FROM_LOCAL" rev-parse "${REF:-HEAD}^{commit}")"
        else
            ref="$REF"
            [ -n "$ref" ] || die "git component requires a ref or --from-local"
            if [[ ! "$ref" =~ ^[0-9a-f]{40}$ ]]; then
                url="$(component_get "$COMPONENT" url)"
                path="$(component_get "$COMPONENT" path)"
                local_repo="$REPOS_DIR/$path"
                require_cmd git
                if [ -d "$local_repo/.git" ]; then
                    ref="$(git -C "$local_repo" rev-parse "$ref^{commit}")"
                else
                    resolved=""
                    for candidate in "refs/heads/$ref" "refs/tags/$ref^{}" "refs/tags/$ref"; do
                        resolved="$(git ls-remote "$url" "$candidate" 2>/dev/null \
                            | head -n1 | awk '{print $1}')"
                        [ -n "$resolved" ] && break
                    done
                    [ -n "$resolved" ] || die "cannot resolve '$REF' for $COMPONENT; fetch it first or pass a full commit"
                    ref="$resolved"
                fi
            fi
        fi
        key="ref"
        new_value="$ref"
        ;;
    tar)
        archive="$(component_get "$COMPONENT" archive)"
        [ -n "$archive" ] || die "$COMPONENT has no archive name"
        file="${FILE:-$REPOS_DIR/downloads/$archive}"
        require_file "$file"
        key="sha256"
        new_value="$(sha256_of "$file")"
        ;;
    *)
        die "unsupported component type: $type"
        ;;
esac

old_value="$(component_get "$COMPONENT" "$key")"
if [ "$old_value" = "$new_value" ]; then
    log "$COMPONENT $key already $new_value"
    exit 0
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
python3 - "$LOCK" "$tmp" "$COMPONENT" "$key" "$new_value" <<'PY'
import re
import sys

src, dst, component, key, value = sys.argv[1:]
text = open(src, encoding="utf-8").read()
header = f"[components.{component}]"
start = text.find(header)
if start < 0:
    sys.exit(f"component section not found: {component}")
next_start = text.find("\n[components.", start + len(header))
end = len(text) if next_start < 0 else next_start
section = text[start:end]
pattern = re.compile(rf'(?m)^{re.escape(key)} = ".*"$')
if not pattern.search(section):
    sys.exit(f"{key} not found in [components.{component}]")
section = pattern.sub(f'{key} = "{value}"', section, count=1)
open(dst, "w", encoding="utf-8").write(text[:start] + section + text[end:])
PY

# Validate the temporary lock before touching the real one.
parsed="$(python3 "$(versions_tool)" --file "$tmp" get "$COMPONENT" "$key")"
[ "$parsed" = "$new_value" ] || die "internal error: temp lock did not validate"

log "component=$COMPONENT $key: $old_value -> $new_value"
if [ "$DRY_RUN" -eq 1 ]; then
    diff -u "$LOCK" "$tmp" || true
    log "dry run; $LOCK not changed"
    exit 0
fi

cp "$tmp" "$LOCK"
log "updated $LOCK"
