#!/usr/bin/env bash
# Boot the instance and assert the Linux/init markers appear in the UART log.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"

INSTANCE="$DEFAULT_INSTANCE"
TIMEOUT="${BOOT_TIMEOUT:-180}"
STEPS="${BOOT_STEPS:-200000000}"
PASSTHROUGH=()
while [ $# -gt 0 ]; do
    case "$1" in
        --instance) INSTANCE="$2"; shift 2 ;;
        --instance=*) INSTANCE="${1#*=}"; shift ;;
        --timeout) TIMEOUT="$2"; shift 2 ;;
        --timeout=*) TIMEOUT="${1#*=}"; shift ;;
        --steps) STEPS="$2"; shift 2 ;;
        --steps=*) STEPS="${1#*=}"; shift ;;
        --) shift; PASSTHROUGH=("$@"); break ;;
        --help|-h)
            echo "usage: $0 [--instance NAME] [--timeout SEC] [--steps N] [-- simulator args...]"
            echo "  e.g. $0 riscv-virt-2hart -- --no-jit"
            exit 0
            ;;
        *) die "unknown argument: $1 (use -- before simulator args)" ;;
    esac
done

validate_instance_name "$INSTANCE"
ws="$(instance_workspace "$INSTANCE")"
require_dir "$ws"
for f in bin/rhetsim-cli bin/fw_jump.bin bin/Image bin/riscv-virt.dtb bin/initramfs.cpio; do
    require_file "$ws/$f"
done

log "booting instance '$INSTANCE' (timeout ${TIMEOUT}s, steps $STEPS)"
set +e
timeout "$TIMEOUT" "$ROOT/run.sh" start "$INSTANCE" --batch --steps "$STEPS" "${PASSTHROUGH[@]}"
rc=$?
set -e

logfile="$ws/logs/latest/uart.log"
if [ ! -f "$logfile" ]; then
    die "no UART log at $logfile"
fi

ok=1
grep -q 'Linux version' "$logfile" || { echo "missing 'Linux version' in $logfile"; ok=0; }
grep -q 'RHETSIM_INIT_OK' "$logfile" || { echo "missing 'RHETSIM_INIT_OK' in $logfile"; ok=0; }

if [ "$ok" -ne 1 ]; then
    echo "---- tail of $logfile ----"
    tail -n 60 "$logfile" || true
    die "boot test failed (simulator exit code $rc)"
fi

log "boot test passed (simulator exit code $rc)"
