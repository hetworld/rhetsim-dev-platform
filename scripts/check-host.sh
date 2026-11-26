#!/usr/bin/env bash
# Check the host dependencies needed to build and run the platform.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"

QUIET=0
case "${1:-}" in
    --quiet|-q) QUIET=1 ;;
    --help|-h)
        echo "usage: $0 [--quiet]"
        exit 0
        ;;
esac

required=(git make gcc bison flex bc python3 cargo rustc flock cpio file sha256sum tar curl
          riscv64-linux-gnu-gcc riscv64-linux-gnu-ar riscv64-linux-gnu-objcopy riscv64-linux-gnu-nm)
optional=(tmux jq zstd xz bzip2)

missing=0
[ "$QUIET" -eq 1 ] || echo "Required:"
for cmd in "${required[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then
        [ "$QUIET" -eq 1 ] || printf '  ok    %-28s %s\n' "$cmd" "$("$cmd" --version 2>/dev/null | head -n1 || true)"
    else
        printf '  MISS  %s\n' "$cmd"
        missing=$((missing + 1))
    fi
done

[ "$QUIET" -eq 1 ] || echo "Optional:"
for cmd in "${optional[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then
        [ "$QUIET" -eq 1 ] || printf '  ok    %-28s %s\n' "$cmd" "$("$cmd" --version 2>/dev/null | head -n1 || true)"
    else
        [ "$QUIET" -eq 1 ] || printf '  skip  %s\n' "$cmd"
    fi
done

if [ "$missing" -ne 0 ]; then
    die "$missing required command(s) missing"
fi
[ "$QUIET" -eq 1 ] || echo "Host looks good."
