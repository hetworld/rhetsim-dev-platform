#!/usr/bin/env bash
# Build and run the riscv-tests p-tests against the simulator.
#
# The suite is fetched at a pinned commit into workspace/shared/isa-tests/ and
# built with the Linux RISC-V cross toolchain. The Rust integration test runs
# every test through both the JIT and the interpreter.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"

INSTANCE="$DEFAULT_INSTANCE"
REF="${RISCV_TESTS_REF:-1b3f8bd665d79e5985753a558dae4e3718e2edc8}"
URL="${RISCV_TESTS_URL:-https://github.com/riscv-software-src/riscv-tests.git}"
PREFIX="${RISCV_PREFIX:-riscv64-linux-gnu-}"
BUILD_ONLY=0

usage() {
    cat <<EOF
usage: $0 [instance] [--instance NAME] [--ref COMMIT] [--prefix PREFIX] [--build-only]
  Builds the pinned riscv-tests p-tests and runs them through the JIT and the
  interpreter. RHETSIM_ISA_TESTS is set automatically for the Rust test.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --instance) INSTANCE="$2"; shift 2 ;;
        --instance=*) INSTANCE="${1#*=}"; shift ;;
        --ref) REF="$2"; shift 2 ;;
        --ref=*) REF="${1#*=}"; shift ;;
        --prefix) PREFIX="$2"; shift 2 ;;
        --prefix=*) PREFIX="${1#*=}"; shift ;;
        --build-only) BUILD_ONLY=1; shift ;;
        --help|-h) usage; exit 0 ;;
        -*) die "unknown argument: $1 (try --help)" ;;
        *) INSTANCE="$1"; shift ;;
    esac
done

validate_instance_name "$INSTANCE"
ws="$(instance_workspace "$INSTANCE")"
require_dir "$ws"
load_instance_env "$INSTANCE"

require_cmd git
require_cmd make
require_cmd cargo
require_cmd "${PREFIX}gcc"

sim_src="$ws/src/rhetsim"
[ -f "$sim_src/Cargo.toml" ] || sim_src="$REPOS_DIR/rhetsim"
require_file "$sim_src/Cargo.toml"

# The rv64mzicbo group cannot be assembled with binutils 2.38 (the zicboz
# march string drops Zicsr); CMO is covered by the unit and random difftests.
TEST_GROUPS="rv64ui rv64uc rv64um rv64ua rv64uf rv64ud rv64uzba rv64uzbb rv64uzbc rv64uzbs rv64ssvnapot rv64si rv64mi"

short_ref="$(printf '%s' "$REF" | cut -c1-12)"
cache="$SHARED_DIR/isa-tests/$short_ref"
src="$cache/riscv-tests"
isa="$src/isa"

if [ ! -d "$src/.git" ]; then
    log "fetching riscv-tests $short_ref"
    mkdir -p "$cache"
    git init -q "$src"
    git -C "$src" remote add origin "$URL"
    if ! git -C "$src" fetch -q --depth 1 origin "$REF" 2>/dev/null; then
        git -C "$src" fetch -q origin "$REF"
    fi
    git -C "$src" checkout -q --detach FETCH_HEAD
    git -C "$src" submodule update -q --init --depth 1
else
    log "using cached riscv-tests $short_ref"
fi

log "building p-tests grouped as: $TEST_GROUPS"
targets="$(make -C "$isa" -pn "RISCV_PREFIX=$PREFIX" 2>/dev/null \
    | sed -n 's/^\(rv64[a-z0-9_]*-p-[A-Za-z0-9_]*\):.*/\1/p' \
    | sort -u \
    | grep -E "^($(printf '%s' "$TEST_GROUPS" | tr ' ' '|'))-p-")"
[ -n "$targets" ] || die "no riscv-tests targets matched: $TEST_GROUPS"
# shellcheck disable=SC2086
make -C "$isa" -j"$(nproc)" "RISCV_PREFIX=$PREFIX" $targets >/dev/null

built="$(find "$isa" -maxdepth 1 -type f -name 'rv64*-p-*' ! -name '*.dump' ! -name '*.out' | wc -l)"
log "built $built p-test ELFs under ${isa#$ROOT/}"
if [ "$BUILD_ONLY" -eq 1 ]; then
    exit 0
fi

log "running riscv-tests (JIT + interpreter)"
(
    cd "$sim_src"
    RHETSIM_ISA_TESTS="$isa" cargo test -p rhetsim-cpu-riscv \
        --test isa_compliance -- --nocapture
)
