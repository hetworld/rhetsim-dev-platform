#!/usr/bin/env bash
# RhetSim dev-platform command entry.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"

usage() {
    cat <<'EOF'
usage: ./run.sh <command> [args]

Commands:
  help                         Show this help
  version                      Show the repository version
  check-host                   Check host build dependencies
  fetch                        Fetch pinned component sources into repos/
  create <instance>            Materialize workspace/instances/<instance>
  build <instance> [opts]      Build or link an instance
  start <instance> [args]      Run the simulator; extra args go to rhetsim-cli
  console <instance>           Attach an interactive console (tmux if available)
  update <instance>            Refresh instance config from its definition
  export <instance>            Export instance artifacts as a tarball
  clean <instance> [opts]      Remove instance build/run state
  destroy <instance>           Remove the instance workspace
  sdk <instance> [opts]        Package an SDK bundle
  publish [opts]               Publish an SDK (dry run by default)
  test [smoke|boot|boot-matrix|sim|consumer]
                               Run tests (default: smoke)
  bench [opts]                 Benchmark the Linux boot (JIT stats)
  gc [opts]                    Garbage-collect the shared build cache
  pin <component> [ref]        Pin/update a component in env/versions.toml
  verify-lock                  Verify repos/ matches env/versions.toml

Examples:
  ./run.sh fetch
  ./run.sh verify-lock
  ./run.sh create riscv-virt-2hart
  ./run.sh build riscv-virt-2hart --reuse-existing /path/to/rhet
  ./run.sh start riscv-virt-2hart --batch --steps 200000000
  ./run.sh test boot riscv-virt-2hart
  ./run.sh test sim
  ./run.sh bench --runs 3
  ./run.sh sdk riscv-virt-2hart --version 0.1.0
  ./run.sh pin rhetsim dev --from-local /path/to/rhetsim
EOF
}

cmd="${1:-help}"
if [ $# -gt 0 ]; then
    shift
fi

case "$cmd" in
    help|-h|--help)
        usage
        ;;
    version)
        git -C "$ROOT" describe --tags --always --dirty 2>/dev/null || echo "0.1.0-dev"
        ;;
    check-host)
        exec "$ROOT/scripts/check-host.sh" "$@"
        ;;
    fetch)
        exec "$ROOT/scripts/fetch-sources.sh" "$@"
        ;;
    create)
        exec "$ROOT/scripts/instance-create.sh" "$@"
        ;;
    build)
        exec "$ROOT/scripts/instance-build.sh" "$@"
        ;;
    start)
        if [ $# -gt 0 ] && [[ "$1" != -* ]]; then
            inst="$1"
            shift
            exec "$ROOT/scripts/instance-run.sh" --instance "$inst" "$@"
        fi
        exec "$ROOT/scripts/instance-run.sh" "$@"
        ;;
    console)
        exec "$ROOT/scripts/instance-console.sh" "$@"
        ;;
    update)
        exec "$ROOT/scripts/instance-update.sh" "$@"
        ;;
    export)
        exec "$ROOT/scripts/instance-export.sh" "$@"
        ;;
    clean)
        exec "$ROOT/scripts/clean.sh" "$@"
        ;;
    destroy)
        exec "$ROOT/scripts/instance-destroy.sh" "$@"
        ;;
    sdk)
        if [ $# -gt 0 ] && [[ "$1" != -* ]]; then
            inst="$1"
            shift
            exec "$ROOT/scripts/package-sdk.sh" --instance "$inst" "$@"
        fi
        exec "$ROOT/scripts/package-sdk.sh" "$@"
        ;;
    publish)
        exec "$ROOT/scripts/publish-sdk.sh" "$@"
        ;;
    test)
        sub="${1:-smoke}"
        if [ $# -gt 0 ]; then
            shift
        fi
        case "$sub" in
            smoke)
                exec "$ROOT/scripts/tests/smoke.sh" "$@"
                ;;
            boot)
                if [ $# -gt 0 ] && [[ "$1" != -* ]]; then
                    inst="$1"
                    shift
                    exec "$ROOT/scripts/tests/boot-linux.sh" --instance "$inst" "$@"
                fi
                exec "$ROOT/scripts/tests/boot-linux.sh" "$@"
                ;;
            boot-matrix)
                exec "$ROOT/scripts/tests/boot-matrix.sh" "$@"
                ;;
            sim)
                exec "$ROOT/scripts/tests/sim.sh" "$@"
                ;;
            consumer)
                exec "$ROOT/scripts/tests/consumer-ci.sh" "$@"
                ;;
            *)
                die "unknown test suite: $sub (expected smoke|boot|boot-matrix|sim|consumer)"
                ;;
        esac
        ;;
    bench)
        exec "$ROOT/scripts/tests/bench.sh" "$@"
        ;;
    gc)
        exec "$ROOT/scripts/cache-gc.sh" "$@"
        ;;
    pin)
        exec "$ROOT/scripts/pin-source.sh" "$@"
        ;;
    verify-lock)
        exec "$ROOT/scripts/verify-lock.sh" "$@"
        ;;
    *)
        usage >&2
        die "unknown command: $cmd"
        ;;
esac
