#!/usr/bin/env bash
# Benchmark the simulator's Linux boot (JIT by default).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"

INSTANCE="$DEFAULT_INSTANCE"
RUNS=3
STEPS="${BOOT_STEPS:-200000000}"
TIMEOUT="${BENCH_TIMEOUT:-180}"
NO_JIT=0
while [ $# -gt 0 ]; do
    case "$1" in
        --instance) INSTANCE="$2"; shift 2 ;;
        --instance=*) INSTANCE="${1#*=}"; shift ;;
        --runs) RUNS="$2"; shift 2 ;;
        --runs=*) RUNS="${1#*=}"; shift ;;
        --steps) STEPS="$2"; shift 2 ;;
        --steps=*) STEPS="${1#*=}"; shift ;;
        --timeout) TIMEOUT="$2"; shift 2 ;;
        --timeout=*) TIMEOUT="${1#*=}"; shift ;;
        --no-jit) NO_JIT=1; shift ;;
        --help|-h)
            echo "usage: $0 [--instance NAME] [--runs N] [--steps N] [--timeout SEC] [--no-jit]"
            echo "  runs the Linux boot with RHETSIM_JIT_STATS=1 and reports wall time/steps"
            exit 0
            ;;
        *) die "unknown argument: $1" ;;
    esac
done

validate_instance_name "$INSTANCE"
ws="$(instance_workspace "$INSTANCE")"
require_dir "$ws"
for f in bin/rhetsim-cli bin/fw_jump.bin bin/Image bin/initramfs.cpio bin/riscv-virt.dtb; do
    require_file "$ws/$f"
done
require_cmd timeout
require_cmd awk
require_cmd mktemp

args=(--instance "$INSTANCE" --batch --steps "$STEPS")
[ "$NO_JIT" -eq 1 ] && args+=(--no-jit)
export RHETSIM_JIT_STATS=1

# The simulator prints JIT counters to stderr from RiscvCpu::drop; keep stderr
# separate from the guest console so the counters can be parsed per run.
errlog="$(mktemp "${TMPDIR:-/tmp}/rhetsim-bench.XXXXXX")"
trap 'rm -f "$errlog"' EXIT

log "benchmark instance '$INSTANCE': runs=$RUNS steps=$STEPS timeout=${TIMEOUT}s no_jit=$NO_JIT"
results=()
for i in $(seq 1 "$RUNS"); do
    : > "$errlog"
    start_ns="$(date +%s%N)"
    if ! timeout "$TIMEOUT" "$ROOT/run.sh" start "${args[@]}" >/dev/null 2>"$errlog"; then
        tail -n 20 "$errlog" >&2 || true
        die "run $i failed (timeout or simulator error); see $ws/logs/latest"
    fi
    end_ns="$(date +%s%N)"
    elapsed_ms=$(( (end_ns - start_ns) / 1000000 ))
    logdir="$(readlink -f "$ws/logs/latest")"
    simlog="$logdir/sim.log"
    steps_done="$(sed -n 's/.*simulation finished steps=\([0-9]*\).*/\1/p' "$simlog" | tail -n1)"
    [ -n "$steps_done" ] || steps_done=0
    if [ "$elapsed_ms" -gt 0 ]; then
        steps_per_sec=$(( steps_done * 1000 / elapsed_ms ))
    else
        steps_per_sec=0
    fi
    jitline="$(grep -m1 'jit-stats hart=0' "$errlog" || true)"
    results+=("$i|$elapsed_ms|$steps_done|$steps_per_sec")
    printf 'run %d: %6d ms  %12s steps  %10s steps/s\n' "$i" "$elapsed_ms" "$steps_done" "$steps_per_sec"
    [ -n "$jitline" ] && printf '        %s\n' "$jitline"
done

median_ms="$(printf '%s\n' "${results[@]}" | awk -F'|' '{print $2}' | sort -n \
    | awk '{a[NR]=$1} END { if (NR==0) {print 0} else if (NR%2) {print a[(NR+1)/2]} else {print int((a[NR/2]+a[NR/2+1])/2)} }')"
best_ms="$(printf '%s\n' "${results[@]}" | awk -F'|' '{print $2}' | sort -n | head -n1)"
log "median wall time: ${median_ms} ms (best ${best_ms} ms)"
log "run logs: $ws/logs/<run-id>/{sim,uart}.log"
