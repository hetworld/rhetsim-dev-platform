#!/usr/bin/env bash
# Build rhetsim-cli in release mode with a content-addressed cache.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"

src="${RHETSIM_SRC:-$REPOS_DIR/rhetsim}"
require_dir "$src"
require_file "$src/Cargo.toml"
require_cmd cargo
require_cmd rustc
require_cmd git

commit="$(git -C "$src" rev-parse HEAD)"
dirty="$(git -C "$src" status --porcelain | sha256sum | awk '{print $1}')"
build_id="$(make_build_id "$commit" "$dirty" "$(rustc --version)" "$(cargo --version)" release)"
out="$SHARED_DIR/build/sim/$build_id"
artifact="$out/rhetsim-cli"

if [ -f "$artifact" ]; then
    log "simulator cached: $artifact"
    printf '%s\n' "$artifact"
    exit 0
fi

log "building rhetsim-cli ($build_id)"
mkdir -p "$out" "$SHARED_DIR/cargo-target"
CARGO_TARGET_DIR="$SHARED_DIR/cargo-target" \
    cargo build --release --bin rhetsim-cli --manifest-path "$src/Cargo.toml"
cp "$SHARED_DIR/cargo-target/release/rhetsim-cli" "$artifact"
chmod +x "$artifact"
{
    echo "component=rhetsim"
    echo "commit=$commit"
    echo "dirty=$dirty"
    echo "build_id=$build_id"
    echo "rustc=$(rustc --version)"
    echo "cargo=$(cargo --version)"
} > "$out/manifest.txt"

log "simulator ready: $artifact"
printf '%s\n' "$artifact"
