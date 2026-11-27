#!/usr/bin/env bash
# Build the OpenSBI fw_jump.bin used by the RISC-V boot path.
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

src="${OPENSBI_SRC:-$REPOS_DIR/software/opensbi}"
# shellcheck source=../env/configs/opensbi/generic-rv64.mk
source "$ENV_DIR/configs/opensbi/generic-rv64.mk"

require_dir "$src"
require_cmd make
require_cmd riscv64-linux-gnu-gcc
require_cmd git

commit="$(git -C "$src" rev-parse HEAD)"
patch_sig="$(patch_signature "${PATCH_DIRS[@]}")"
if [ "$patch_sig" = "none" ]; then
    build_id="$(make_build_id "$commit" "$PLATFORM" "$CROSS_COMPILE" "$FW_JUMP_ADDR")"
else
    build_id="$(make_build_id "$commit" "$PLATFORM" "$CROSS_COMPILE" "$FW_JUMP_ADDR" "$patch_sig")"
fi
out="$SHARED_DIR/build/firmware/$build_id"
artifact="$out/fw_jump.bin"

if [ -f "$artifact" ]; then
    log "firmware cached: $artifact"
    printf '%s\n' "$artifact"
    exit 0
fi

prepare_patched_source opensbi "$src" "$commit" "${PATCH_DIRS[@]}"
build_src="$PATCHED_SOURCE"
log "building OpenSBI ($build_id)"
make -C "$build_src" \
    CROSS_COMPILE="$CROSS_COMPILE" \
    PLATFORM="$PLATFORM" \
    FW_JUMP_ADDR="$FW_JUMP_ADDR" \
    -j"$(nproc)"

src_artifact="$build_src/build/platform/generic/firmware/fw_jump.bin"
require_file "$src_artifact"
mkdir -p "$out"
cp "$src_artifact" "$artifact"
{
    echo "component=opensbi"
    echo "commit=$commit"
    echo "build_id=$build_id"
    echo "patches=$patch_sig"
    echo "platform=$PLATFORM"
    echo "fw_jump_addr=$FW_JUMP_ADDR"
    echo "cross_compile=$CROSS_COMPILE"
} > "$out/manifest.txt"

log "firmware ready: $artifact"
printf '%s\n' "$artifact"
