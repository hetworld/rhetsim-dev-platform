#!/usr/bin/env bash
# Build rhetsim-cli in release mode with a content-addressed cache.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/lib/patches.sh
source "$ROOT/scripts/lib/patches.sh"

PATCH_DIRS=()
while [ $# -gt 0 ]; do
    case "$1" in
        --patch-dir) PATCH_DIRS+=("$2"); shift 2 ;;
        --patch-dir=*) PATCH_DIRS+=("${1#*=}"); shift ;;
        --help|-h)
            echo "usage: $0 [--patch-dir DIR ...]"
            exit 0
            ;;
        *) die "unknown argument: $1" ;;
    esac
done

src="${RHETSIM_SRC:-$REPOS_DIR/rhetsim}"
require_dir "$src"
require_file "$src/Cargo.toml"
require_cmd cargo
require_cmd rustc
require_cmd git

commit="$(git -C "$src" rev-parse HEAD)"
status_hash="$(git -C "$src" status --porcelain | sha256sum | awk '{print $1}')"
diff_hash="$(git -C "$src" diff HEAD | sha256sum | awk '{print $1}')"
patch_sig="$(patch_signature "${PATCH_DIRS[@]}")"
if [ "$patch_sig" = "none" ]; then
    build_id="$(make_build_id "$commit" "$status_hash" "$diff_hash" "$(rustc --version)" "$(cargo --version)" release)"
else
    build_id="$(make_build_id "$commit" "$status_hash" "$diff_hash" "$(rustc --version)" "$(cargo --version)" release "$patch_sig")"
fi
out="$SHARED_DIR/build/sim/$build_id"
artifact="$out/rhetsim-cli"

if [ -f "$artifact" ]; then
    log "simulator cached: $artifact"
    printf '%s\n' "$artifact"
    exit 0
fi

prepare_patched_source rhetsim "$src" "$commit" "${PATCH_DIRS[@]}"
build_src="$PATCHED_SOURCE"
log "building rhetsim-cli ($build_id)"
mkdir -p "$out" "$SHARED_DIR/cargo-target"
CARGO_TARGET_DIR="$SHARED_DIR/cargo-target" \
    cargo build --release --bin rhetsim-cli --manifest-path "$build_src/Cargo.toml"
cp "$SHARED_DIR/cargo-target/release/rhetsim-cli" "$artifact"
chmod +x "$artifact"
{
    echo "component=rhetsim"
    echo "commit=$commit"
    echo "status_hash=$status_hash"
    echo "diff_hash=$diff_hash"
    echo "build_id=$build_id"
    echo "patches=$patch_sig"
    echo "rustc=$(rustc --version)"
    echo "cargo=$(cargo --version)"
} > "$out/manifest.txt"

log "simulator ready: $artifact"
printf '%s\n' "$artifact"
