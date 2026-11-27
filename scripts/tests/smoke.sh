#!/usr/bin/env bash
# Repository smoke test: syntax, required files, version manifest parsing.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"

fail=0
check_file() { [ -f "$ROOT/$1" ] || { echo "MISSING file: $1"; fail=1; }; }

while IFS= read -r script; do
    bash -n "$script" || { echo "SYNTAX error: ${script#$ROOT/}"; fail=1; }
done < <(find "$ROOT/scripts" "$ROOT/sdk/scripts" "$ROOT/tools" -name '*.sh' -type f; echo "$ROOT/run.sh")

for f in \
    CLAUDE.md Makefile run.sh .gitignore \
    env/versions.toml env/sdk.toml env/host-deps.toml \
    env/instances/riscv-virt-2hart/instance.toml \
    env/instances/riscv-virt-2hart/platform.toml \
    .claude/skills/bootstrap/SKILL.md \
    .claude/skills/build/SKILL.md \
    .claude/skills/run-debug/SKILL.md \
    .claude/skills/release/SKILL.md \
    .claude/skills/memory-sync/SKILL.md \
    docs/memory/MEMORY.md \
    sdk/layout.md sdk/manifest.schema.json; do
    check_file "$f"
done

if ! python3 "$ROOT/scripts/lib/versions.py" list | grep -q '^rhetsim|'; then
    echo "versions.toml: rhetsim component not parsed"
    fail=1
fi

if ! (cd "$ROOT" && ./run.sh help >/dev/null); then
    echo "./run.sh help failed"
    fail=1
fi

if ! (cd "$ROOT" && make help >/dev/null); then
    echo "make help failed"
    fail=1
fi

if [ "$fail" -ne 0 ]; then
    die "smoke test failed"
fi
log "smoke test passed"
