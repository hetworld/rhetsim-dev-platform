#!/usr/bin/env bash
# Run the instruction-level difftest against Spike.
#
# Spike is built from a pinned commit into workspace/shared/spike/ (cached) and
# the pinned riscv-tests p-tests are reused from ./run.sh test isa. The Rust
# integration test replays every test in the interpreter and compares the
# privilege level, PC, instruction and architectural writes against Spike's
# --log-commits output.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"

INSTANCE="$DEFAULT_INSTANCE"
SPIKE_REF="${SPIKE_REF:-6e18887745c63f33048e4be3d880c65a72aad0df}"
SPIKE_URL="${SPIKE_URL:-https://github.com/riscv-software-src/riscv-isa-sim.git}"
RISCV_TESTS_REF="${RISCV_TESTS_REF:-1b3f8bd665d79e5985753a558dae4e3718e2edc8}"
ISA="${RHETSIM_SPIKE_ISA:-rv64gc_zba_zbb_zbc_zbs_svnapot_smrnmi_zicclsm}"

usage() {
    cat <<EOF
usage: $0 [instance] [--instance NAME] [--ref COMMIT] [--isa ISA]
          [--isa-tests DIR]
  Builds the pinned Spike at workspace/shared/spike/<ref>/, ensures the
  riscv-tests p-tests are built, and runs the instruction-level difftest.
  RHETSIM_SPIKE and RHETSIM_ISA_TESTS are set automatically.
EOF
}

ISA_TESTS=""
while [ $# -gt 0 ]; do
    case "$1" in
        --instance) INSTANCE="$2"; shift 2 ;;
        --instance=*) INSTANCE="${1#*=}"; shift ;;
        --ref) SPIKE_REF="$2"; shift 2 ;;
        --ref=*) SPIKE_REF="${1#*=}"; shift ;;
        --isa) ISA="$2"; shift 2 ;;
        --isa=*) ISA="${1#*=}"; shift ;;
        --isa-tests) ISA_TESTS="$2"; shift 2 ;;
        --isa-tests=*) ISA_TESTS="${1#*=}"; shift ;;
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
require_cmd c++

sim_src="$ws/src/rhetsim"
[ -f "$sim_src/Cargo.toml" ] || sim_src="$REPOS_DIR/rhetsim"
require_file "$sim_src/Cargo.toml"

short_ref="$(printf '%s' "$SPIKE_REF" | cut -c1-12)"
cache="$SHARED_DIR/spike/$short_ref"
src="$cache/src"
spike="$cache/bin/spike"

if [ ! -x "$spike" ]; then
    log "building Spike $short_ref"
    if [ ! -d "$src/.git" ]; then
        mkdir -p "$cache"
        git init -q "$src"
        git -C "$src" remote add origin "$SPIKE_URL"
        if ! git -C "$src" fetch -q --depth 1 origin "$SPIKE_REF" 2>/dev/null; then
            git -C "$src" fetch -q origin "$SPIKE_REF"
        fi
        git -C "$src" checkout -q --detach FETCH_HEAD
        git -C "$src" submodule update -q --init --depth 1
    fi
    mkdir -p "$cache/build"
    configure_log="$cache/configure.log"
    if ! (cd "$cache/build" && "$src/configure" --prefix="$cache/install") \
        >"$configure_log" 2>&1; then
        tail -20 "$configure_log" >&2
        die "Spike configure failed (log: ${configure_log#$ROOT/})"
    fi
    build_log="$cache/build.log"
    if ! make -C "$cache/build" -j"$(nproc)" >"$build_log" 2>&1; then
        tail -30 "$build_log" >&2
        die "Spike build failed (log: ${build_log#$ROOT/})"
    fi
    mkdir -p "$cache/bin"
    cp "$cache/build/spike" "$spike"
    # The build tree is ~4 GiB; keep only the stripped binary so the shared
    # cache stays small. Rebuilding is only needed when the pinned ref changes.
    strip "$spike" 2>/dev/null || true
    rm -rf "$cache/build"
else
    log "using cached Spike $short_ref"
fi
require_file "$spike"

if [ -z "$ISA_TESTS" ]; then
    "$ROOT/scripts/tests/isa.sh" "$INSTANCE" --build-only
    tests_short="$(printf '%s' "$RISCV_TESTS_REF" | cut -c1-12)"
    ISA_TESTS="$SHARED_DIR/isa-tests/$tests_short/riscv-tests/isa"
fi
require_dir "$ISA_TESTS"

log "running Spike difftest (isa: $ISA)"
(
    cd "$sim_src"
    RHETSIM_SPIKE="$spike" RHETSIM_ISA_TESTS="$ISA_TESTS" RHETSIM_SPIKE_ISA="$ISA" \
        cargo test -p rhetsim-cpu-riscv --test spike_difftest -- --nocapture
)
