#!/usr/bin/env bash
# Run an instance. Root run.sh delegates here.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"

INSTANCE="${RHETSIM_INSTANCE:-$DEFAULT_INSTANCE}"
RUN_ID=""
NO_LOCK=0
WAIT_LOCK=0
PASSTHROUGH=()

usage() {
    cat <<EOF
usage: ./run.sh start [--instance NAME] [--run-id ID] [--wait|--no-lock] [simulator args...]

Instance selection:
  --instance NAME   Instance to run (default: $DEFAULT_INSTANCE, env RHETSIM_INSTANCE)
  --run-id ID       Use a specific run id (default: UTC timestamp)
  --wait            Wait for an already-running instance to finish
  --no-lock         Do not take the per-instance run lock

Everything else is passed to rhetsim-cli, e.g. --batch, --steps N, --trace ...,
--no-jit, --log-level debug.

Artifacts come from workspace/instances/<name>/bin; override with
RHETSIM_BIN, RHETSIM_MANIFEST, RHETSIM_FIRMWARE, RHETSIM_KERNEL,
RHETSIM_INITRD, RHETSIM_DTB.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --instance) INSTANCE="$2"; shift 2 ;;
        --instance=*) INSTANCE="${1#*=}"; shift ;;
        --run-id) RUN_ID="$2"; shift 2 ;;
        --run-id=*) RUN_ID="${1#*=}"; shift ;;
        --wait) WAIT_LOCK=1; shift ;;
        --no-lock) NO_LOCK=1; shift ;;
        --help|-h) usage; exit 0 ;;
        *) PASSTHROUGH+=("$1"); shift ;;
    esac
done

validate_instance_name "$INSTANCE"
ws="$(instance_workspace "$INSTANCE")"
[ -d "$ws" ] || die "instance '$INSTANCE' not found; run scripts/instance-create.sh $INSTANCE"
load_instance_env "$INSTANCE"

BIN="${RHETSIM_BIN:-$ws/bin/rhetsim-cli}"
MANIFEST="${RHETSIM_MANIFEST:-$ws/config/platform.toml}"
FIRMWARE="${RHETSIM_FIRMWARE:-$ws/bin/fw_jump.bin}"
KERNEL="${RHETSIM_KERNEL:-$ws/bin/Image}"
INITRD="${RHETSIM_INITRD:-$ws/bin/initramfs.cpio}"
DTB="${RHETSIM_DTB:-$ws/bin/riscv-virt.dtb}"
for f in "$BIN" "$MANIFEST" "$FIRMWARE" "$KERNEL" "$INITRD" "$DTB"; do
    require_file "$f"
done
[ -x "$BIN" ] || die "simulator is not executable: $BIN"

if [ "$NO_LOCK" -eq 0 ]; then
    exec 9>"$ws/run/lock"
    if [ "$WAIT_LOCK" -eq 1 ]; then
        flock 9
    else
        flock -n 9 || die "instance '$INSTANCE' is already running (use --wait or --no-lock)"
    fi
fi

RUN_ID="${RUN_ID:-$(new_run_id)}"
session="$ws/run/sessions/$RUN_ID"
logdir="$ws/logs/$RUN_ID"
mkdir -p "$session" "$logdir"
ln -sfn "$RUN_ID" "$ws/logs/latest"

cd "$ROOT"

batch=0
for a in "${PASSTHROUGH[@]}"; do
    [ "$a" = "--batch" ] && batch=1
done

cmd=("$BIN" "$MANIFEST" --firmware "$FIRMWARE" --kernel "$KERNEL" --initrd "$INITRD" --dtb "$DTB")
if [ "$batch" -eq 1 ]; then
    has_uart=0 has_logfile=0 has_trace=0 has_tracefile=0
    for a in "${PASSTHROUGH[@]}"; do
        case "$a" in
            --uart-log|--uart-log=*) has_uart=1 ;;
            --log-file|--log-file=*) has_logfile=1 ;;
            --trace-file|--trace-file=*) has_tracefile=1 ;;
            --trace|--trace=*) has_trace=1 ;;
        esac
    done
    [ "$has_uart" -eq 0 ] && cmd+=(--uart-log "$logdir/uart.log")
    [ "$has_logfile" -eq 0 ] && cmd+=(--log-file "$logdir/sim.log")
    [ "$has_trace" -eq 1 ] && [ "$has_tracefile" -eq 0 ] && cmd+=(--trace-file "$logdir/trace.log")
fi

if [ -n "${RHETSIM_ARGS:-}" ]; then
    read -r -a extra_args <<< "$RHETSIM_ARGS"
    cmd+=("${extra_args[@]}")
fi
cmd+=("${PASSTHROUGH[@]}")

python3 - "$session/run.json" "$INSTANCE" "$RUN_ID" "$ROOT" "${cmd[@]}" <<'PY'
import datetime
import json
import sys

path, instance, run_id, cwd, *argv = sys.argv[1:]
payload = {
    "instance": instance,
    "run_id": run_id,
    "cwd": cwd,
    "argv": argv,
    "batch": "--batch" in argv,
    "started_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
}
with open(path, "w", encoding="utf-8") as f:
    json.dump(payload, f, indent=2)
    f.write("\n")
PY

log "instance=$INSTANCE run_id=$RUN_ID"
if [ "$batch" -eq 1 ]; then
    log "uart log: $logdir/uart.log"
fi

set +e
"${cmd[@]}"
rc=$?
set -e

python3 - "$session/run.json" "$rc" <<'PY'
import datetime
import json
import sys

path, code = sys.argv[1], int(sys.argv[2])
with open(path, encoding="utf-8") as f:
    payload = json.load(f)
payload["exit_code"] = code
payload["ended_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
with open(path, "w", encoding="utf-8") as f:
    json.dump(payload, f, indent=2)
    f.write("\n")
PY

if [ "$rc" -ne 0 ]; then
    warn "simulator exited with code $rc"
    if [ "$batch" -eq 1 ]; then
        warn "see $logdir/uart.log and $logdir/sim.log"
    fi
fi
exit "$rc"
