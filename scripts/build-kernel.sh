#!/usr/bin/env bash
# Build the Linux Image. The root filesystem is NOT embedded; it is loaded as an
# external initrd and passed through the DTB /chosen node at boot.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/lib/patches.sh
source "$ROOT/scripts/lib/patches.sh"

CONFIG="$ENV_DIR/configs/linux/rv64imac_defconfig"
FRAGMENTS=()
PATCH_DIRS=()
while [ $# -gt 0 ]; do
    case "$1" in
        --config) CONFIG="$2"; shift 2 ;;
        --config=*) CONFIG="${1#*=}"; shift ;;
        --fragment) FRAGMENTS+=("$2"); shift 2 ;;
        --fragment=*) FRAGMENTS+=("${1#*=}"); shift ;;
        --patch-dir) PATCH_DIRS+=("$2"); shift 2 ;;
        --patch-dir=*) PATCH_DIRS+=("${1#*=}"); shift ;;
        --help|-h)
            echo "usage: $0 [--config FILE] [--fragment FILE ...] [--patch-dir DIR ...]"
            echo "  The kernel is built without an embedded initramfs; pass the rootfs at boot."
            exit 0
            ;;
        *) die "unknown argument: $1" ;;
    esac
done

require_file "$CONFIG"
LINUX_SRC="${LINUX_SRC:-$REPOS_DIR/software/linux}"
require_dir "$LINUX_SRC"
if [ -e "$LINUX_SRC/.config" ]; then
    die "Linux source tree has an in-tree .config; out-of-tree builds require a clean clone/worktree"
fi
require_cmd make
require_cmd git

commit="$(git -C "$LINUX_SRC" rev-parse HEAD)"
frag_sig=""
for f in "${FRAGMENTS[@]}"; do
    frag_sig+="$(sha256_of "$f")"
done
patch_sig="$(patch_signature "${PATCH_DIRS[@]}")"
if [ "$patch_sig" = "none" ]; then
    build_id="$(make_build_id "$commit" "$(sha256_of "$CONFIG")" "$frag_sig" "$(riscv64-linux-gnu-gcc --version | head -n1)")"
else
    build_id="$(make_build_id "$commit" "$(sha256_of "$CONFIG")" "$frag_sig" "$(riscv64-linux-gnu-gcc --version | head -n1)" "$patch_sig")"
fi
out="$SHARED_DIR/build/linux/$build_id"
artifact="$out/Image"

if [ -f "$artifact" ]; then
    log "kernel cached: $artifact"
    printf '%s\n' "$artifact"
    exit 0
fi

prepare_patched_source linux "$LINUX_SRC" "$commit" "${PATCH_DIRS[@]}"
build_src="$PATCHED_SOURCE"
log "building Linux without embedded initramfs ($build_id)"
mkdir -p "$out/build"
if [ ${#FRAGMENTS[@]} -eq 0 ]; then
    cp "$CONFIG" "$out/build/.config"
else
    # Merge fragments instead of appending them: appending duplicates symbols
    # already present in the full defconfig, which makes olddefconfig print
    # "override: reassigning to symbol ..." warnings.
    merge_tool="$build_src/scripts/kconfig/merge_config.sh"
    require_file "$merge_tool"
    config_abs="$(readlink -f -- "$CONFIG")"
    fragments_abs=()
    for f in "${FRAGMENTS[@]}"; do
        require_file "$f"
        fragments_abs+=("$(readlink -f -- "$f")")
    done
    if ! merge_output="$(cd "$out/build" && \
        "$merge_tool" -m -O . "$config_abs" "${fragments_abs[@]}" 2>&1)"; then
        printf '%s\n' "$merge_output" >&2
        die "failed to merge kernel config fragments"
    fi
fi

make -C "$build_src" O="$out/build" ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- olddefconfig
make -C "$build_src" O="$out/build" ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- -j"$(nproc)"

cp "$out/build/arch/riscv/boot/Image" "$artifact"
cp "$out/build/.config" "$out/kernel.config"
{
    echo "component=linux"
    echo "commit=$commit"
    echo "build_id=$build_id"
    echo "patches=$patch_sig"
    echo "config=$CONFIG"
    echo "initramfs=external"
} > "$out/manifest.txt"

log "kernel ready: $artifact"
printf '%s\n' "$artifact"
