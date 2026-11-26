#!/usr/bin/env bash
# Shared helpers for RhetSim dev-platform scripts.
set -euo pipefail

ROOT="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
ENV_DIR="$ROOT/env"
REPOS_DIR="$ROOT/repos"
WORKSPACE_DIR="$ROOT/workspace"
INSTANCES_DIR="$WORKSPACE_DIR/instances"
SHARED_DIR="$WORKSPACE_DIR/shared"
LOCKS_DIR="$WORKSPACE_DIR/locks"
DIST_DIR="$WORKSPACE_DIR/dist"
DEFAULT_INSTANCE="${DEFAULT_INSTANCE:-riscv-virt-2hart}"

log()  { printf '\033[1;34m[%s]\033[0m %s\n' "${0##*/}" "$*" >&2; }
warn() { printf '\033[1;33m[%s]\033[0m %s\n' "${0##*/}" "$*" >&2; }
die()  { printf '\033[1;31m[%s]\033[0m %s\n' "${0##*/}" "$*" >&2; exit 1; }

require_cmd()  { command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"; }
require_file() { [ -f "$1" ] || die "missing required file: $1"; }
require_dir()  { [ -d "$1" ] || die "missing required directory: $1"; }

validate_instance_name() {
    local name="$1"
    [[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || die "invalid instance name: $name"
    case "$name" in
        shared|dist|locks) die "reserved instance name: $name" ;;
    esac
}

instance_workspace()  { printf '%s/%s' "$INSTANCES_DIR" "${1:?instance name required}"; }
instance_definition() { printf '%s/instances/%s' "$ENV_DIR" "${1:?instance name required}"; }

# Where an instance worktree for a component lives, relative to the instance dir.
instance_src_path() {
    case "$1" in
        rhetsim) printf 'src/rhetsim' ;;
        opensbi|linux|rhetsim-initramfs|busybox) printf 'src/software/%s' "$1" ;;
        musl|gcc) printf 'src/toolchain/%s' "$1" ;;
        *) printf 'src/%s' "$1" ;;
    esac
}

new_run_id() { date -u +%Y%m%dT%H%M%SZ; }

ensure_workspace_dirs() {
    mkdir -p "$INSTANCES_DIR" "$SHARED_DIR" "$LOCKS_DIR" "$DIST_DIR"
}

# Source an instance's config/env.sh with automatic export.
load_instance_env() {
    local inst="$1" f
    f="$(instance_workspace "$inst")/config/env.sh"
    [ -f "$f" ] || return 0
    # shellcheck disable=SC1090
    set -a
    source "$f"
    set +a
}

versions_tool() { printf '%s/scripts/lib/versions.py' "$ROOT"; }

component_get() {
    local name="$1" key="$2"
    python3 "$(versions_tool)" get "$name" "$key"
}

component_ref() { component_get "$1" ref; }

sha256_of() { sha256sum "$1" | awk '{print $1}'; }

# Short, stable build id from a list of inputs.
make_build_id() {
    printf '%s\n' "$@" | sha256sum | awk '{print substr($1, 1, 16)}'
}
