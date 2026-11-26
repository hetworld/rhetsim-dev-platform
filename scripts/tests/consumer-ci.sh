#!/usr/bin/env bash
# Consumer-side check: inspect the latest SDK bundle and compile the example.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"

REQUIRE=0
while [ $# -gt 0 ]; do
    case "$1" in
        --require) REQUIRE=1; shift ;;
        --help|-h) echo "usage: $0 [--require]"; exit 0 ;;
        *) die "unknown argument: $1" ;;
    esac
done

sdk="$(find "$DIST_DIR" -mindepth 1 -maxdepth 1 -type d -name 'rhetsim-sdk-*' 2>/dev/null \
    | sort | tail -n1 || true)"
if [ -z "$sdk" ]; then
    if [ "$REQUIRE" -eq 1 ]; then
        die "no SDK bundle under $DIST_DIR"
    fi
    warn "no SDK bundle; skipping consumer CI (run scripts/package-sdk.sh first)"
    exit 0
fi

require_file "$sdk/manifest.json"
python3 -m json.tool "$sdk/manifest.json" >/dev/null
require_file "$sdk/bin/rhetsim-cli"
"$sdk/bin/rhetsim-cli" --list-units >/dev/null
log "SDK manifest and simulator binary are usable: $sdk"

musl_gcc="$sdk/toolchain/sysroot/bin/musl-gcc"
if [ -x "$musl_gcc" ]; then
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    cp -a "$sdk/examples/hello" "$tmp/hello"
    make -C "$tmp/hello" SDK_ROOT="$sdk" CC="$musl_gcc" >/dev/null
    file "$tmp/hello/hello" | grep -q 'ELF 64-bit LSB.*RISC-V' \
        || die "example did not build as a RISC-V ELF"
    log "example cross-compiled successfully"
else
    warn "SDK has no bundled toolchain; skipping example compile"
fi

log "consumer CI passed"
