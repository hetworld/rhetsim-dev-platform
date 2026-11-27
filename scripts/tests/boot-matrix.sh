#!/usr/bin/env bash
# Boot every CPU profile, check the Linux/init markers, interrupt activity and
# (by default) the interactive shell. Golden marker signatures live in
# env/configs/golden/boot/.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"

INSTANCE="$DEFAULT_INSTANCE"
TIMEOUT="${BOOT_TIMEOUT:-180}"
STEPS="${BOOT_STEPS:-200000000}"
PROFILES="custom u74 c908 c908-full"
SHELL_CHECK=1
UPDATE_GOLDEN=0

usage() {
    cat <<EOF
usage: $0 [instance] [--instance NAME] [--timeout SEC] [--steps N]
          [--profiles "custom u74 c908 c908-full"] [--no-shell] [--update-golden]
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --instance) INSTANCE="$2"; shift 2 ;;
        --instance=*) INSTANCE="${1#*=}"; shift ;;
        --timeout) TIMEOUT="$2"; shift 2 ;;
        --timeout=*) TIMEOUT="${1#*=}"; shift ;;
        --steps) STEPS="$2"; shift 2 ;;
        --steps=*) STEPS="${1#*=}"; shift ;;
        --profiles) PROFILES="$2"; shift 2 ;;
        --profiles=*) PROFILES="${1#*=}"; shift ;;
        --no-shell) SHELL_CHECK=0; shift ;;
        --update-golden) UPDATE_GOLDEN=1; shift ;;
        --help|-h) usage; exit 0 ;;
        -*) die "unknown argument: $1 (try --help)" ;;
        *) INSTANCE="$1"; shift ;;
    esac
done

validate_instance_name "$INSTANCE"
ws="$(instance_workspace "$INSTANCE")"
require_dir "$ws"
require_file "$ws/bin/rhetsim-cli"
load_instance_env "$INSTANCE"

# Reference platform manifests live with the simulator source: prefer the
# instance worktree, then the shared component checkout.
sim_src="$ws/src/rhetsim"
[ -d "$sim_src/platforms/reference/server" ] || sim_src="$REPOS_DIR/rhetsim"

golden_dir="$ENV_DIR/configs/golden/boot"
mkdir -p "$golden_dir"

profile_manifest() {
    case "$1" in
        custom) printf '%s/config/platform.toml' "$ws" ;;
        *) printf '%s/platforms/reference/server/riscv-virt-%s.toml' "$sim_src" "$1" ;;
    esac
}

profile_dtb() {
    case "$1" in
        custom) printf '%s/bin/riscv-virt.dtb' "$ws" ;;
        *) printf '%s/platforms/reference/server/riscv-virt-%s.dtb' "$sim_src" "$1" ;;
    esac
}

check_markers() {
    local log="$1"
    local missing=0 marker
    for marker in \
        "Linux version" \
        "RHETSIM_INIT_BEGIN" \
        "RHETSIM_INIT_SLEEP" \
        "RHETSIM_INIT_SLEPT" \
        "RHETSIM_INIT_OK" \
        "SiFive PLIC" \
        "RISC-V INTC"; do
        if ! grep -aq -- "$marker" "$log"; then
            warn "  missing marker: $marker"
            missing=1
        fi
    done
    return "$missing"
}

# Both /proc/interrupts snapshots must show two CPUs and non-decreasing PLIC
# and local-interrupt counts.
check_interrupts() {
    local log="$1"
    awk '
        /RHETSIM_INIT_BEGIN/ { phase = 1; next }
        /RHETSIM_INIT_SLEPT/ { phase = 2; next }
        /RHETSIM_INIT_OK/ { phase = 0 }
        phase && /SiFive PLIC/ { plic[phase] += $2 + $3 }
        phase && /RISC-V INTC/ { intc[phase] += $2 + $3 }
        /CPU0 +CPU1/ { smp = 1 }
        END {
            if (!smp) { print "interrupts: missing CPU0/CPU1 header"; exit 1 }
            if (plic[1] <= 0 || plic[2] < plic[1]) {
                print "interrupts: PLIC counts did not increase"; exit 1
            }
            if (intc[1] <= 0 || intc[2] < intc[1]) {
                print "interrupts: RISC-V INTC counts did not increase"; exit 1
            }
        }
    ' "$log"
}

log_signature() {
    local log="$1"
    local version
    version="$(grep -a -m1 -o 'Linux version [^ ]*' "$log" || true)"
    [ -n "$version" ] && printf '%s\n' "$version"
    grep -a '^RHETSIM_' "$log" | sed 's/\r$//' || true
}

check_golden() {
    local profile="$1" log="$2"
    local golden="$golden_dir/$profile.txt"
    local actual
    actual="$(log_signature "$log")"
    if [ "$UPDATE_GOLDEN" -eq 1 ]; then
        printf '%s\n' "$actual" > "$golden"
        log "  updated golden: ${golden#$ROOT/}"
        return 0
    fi
    if [ ! -f "$golden" ]; then
        warn "  missing golden: ${golden#$ROOT/} (run with --update-golden)"
        return 1
    fi
    if ! diff -u "$golden" <(printf '%s\n' "$actual"); then
        warn "  boot signature differs from golden: ${golden#$ROOT/}"
        return 1
    fi
}

run_profile() {
    local profile="$1"
    local manifest dtb run_id logfile rc ok=0
    manifest="$(profile_manifest "$profile")"
    dtb="$(profile_dtb "$profile")"
    if [ ! -f "$manifest" ]; then
        warn "  missing manifest: $manifest"
        return 1
    fi
    if [ ! -f "$dtb" ]; then
        warn "  missing DTB: $dtb"
        return 1
    fi

    run_id="matrix-${profile}-$(date -u +%Y%m%dT%H%M%SZ)"
    log "=== profile: $profile ==="
    log "  manifest: ${manifest#$ROOT/}"

    set +e
    RHETSIM_MANIFEST="$manifest" RHETSIM_DTB="$dtb" \
        timeout "$TIMEOUT" "$ROOT/run.sh" start "$INSTANCE" \
        --batch --steps "$STEPS" --run-id "$run_id"
    rc=$?
    set -e

    logfile="$ws/logs/$run_id/uart.log"
    if [ ! -f "$logfile" ]; then
        warn "  no UART log at $logfile"
        return 1
    fi
    if [ "$rc" -ne 0 ]; then
        warn "  simulator exit code $rc"
        ok=1
    fi
    check_markers "$logfile" || ok=1
    check_interrupts "$logfile" || ok=1
    check_golden "$profile" "$logfile" || ok=1

    if [ "$ok" -eq 0 ]; then
        log "  profile '$profile' passed (uart: ${logfile#$ROOT/})"
    else
        warn "  profile '$profile' FAILED (uart: ${logfile#$ROOT/})"
    fi
    return "$ok"
}

# Drive the interactive shell through a FIFO: wait for INIT_OK before sending
# commands so the kernel console cannot consume them early.
run_shell_check() {
    local profile="$1"
    local manifest dtb run_id tmpdir fifo uartlog pid deadline
    manifest="$(profile_manifest "$profile")"
    dtb="$(profile_dtb "$profile")"
    [ -f "$manifest" ] || return 1
    [ -f "$dtb" ] || return 1

    tmpdir="$(mktemp -d)"
    fifo="$tmpdir/stdin"
    uartlog="$tmpdir/uart.log"
    mkfifo "$fifo"
    run_id="matrix-shell-${profile}-$(date -u +%Y%m%dT%H%M%SZ)"

    RHETSIM_MANIFEST="$manifest" RHETSIM_DTB="$dtb" \
        setsid "$ROOT/run.sh" start "$INSTANCE" --no-lock --run-id "$run_id" \
        <"$fifo" >"$uartlog" 2>"$tmpdir/sim.log" &
    pid=$!
    exec 7>"$fifo"

    deadline=$((SECONDS + TIMEOUT))
    until grep -aq 'RHETSIM_INIT_OK' "$uartlog" 2>/dev/null; do
        if [ "$SECONDS" -ge "$deadline" ] || ! kill -0 "$pid" 2>/dev/null; then
            warn "  shell check: INIT_OK not reached"
            exec 7>&-
            kill -TERM -"$pid" 2>/dev/null || true
            rm -rf "$tmpdir"
            return 1
        fi
        sleep 0.5
    done

    # Give `exec setsid -c /bin/sh -i` a moment to attach the controlling
    # terminal; input written in that window is echoed but never executed.
    sleep 2
    printf 'echo RHETSIM_SHELL_OK\ncat /proc/cpuinfo | grep -i "^isa"\necho RHETSIM_SHELL_DONE\n' >&7

    deadline=$((SECONDS + 60))
    until grep -aq 'RHETSIM_SHELL_DONE' "$uartlog" 2>/dev/null; do
        if [ "$SECONDS" -ge "$deadline" ] || ! kill -0 "$pid" 2>/dev/null; then
            warn "  shell check: commands did not complete"
            exec 7>&-
            kill -TERM -"$pid" 2>/dev/null || true
            rm -rf "$tmpdir"
            return 1
        fi
        sleep 0.5
    done

    exec 7>&-
    kill -TERM -"$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true

    if ! grep -aq 'RHETSIM_SHELL_OK' "$uartlog"; then
        warn "  shell check: RHETSIM_SHELL_OK missing"
        rm -rf "$tmpdir"
        return 1
    fi
    if ! grep -aq 'isa.*rv64' "$uartlog"; then
        warn "  shell check: no isa line from /proc/cpuinfo"
        rm -rf "$tmpdir"
        return 1
    fi

    log "  interactive shell passed (uart: sha256 $(sha256_of "$uartlog" | cut -c1-12))"
    rm -rf "$tmpdir"
}

fail=0
for profile in $PROFILES; do
    if ! run_profile "$profile"; then
        fail=1
    fi
    if [ "$SHELL_CHECK" -eq 1 ]; then
        if ! run_shell_check "$profile"; then
            fail=1
        fi
    fi
done

if [ "$fail" -ne 0 ]; then
    die "boot matrix failed (profiles: $PROFILES)"
fi
log "boot matrix passed (profiles: $PROFILES)"
