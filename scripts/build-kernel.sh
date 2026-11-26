#!/usr/bin/env bash
# Build the Linux Image with an embedded initramfs.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"

CONFIG="$ENV_DIR/configs/linux/rv64ima_defconfig"
INITRAMFS=""
FRAGMENTS=()
while [ $# -gt 0 ]; do
    case "$1" in
        --config) CONFIG="$2"; shift 2 ;;
        --config=*) CONFIG="${1#*=}"; shift ;;
        --initramfs) INITRAMFS="$2"; shift 2 ;;
        --initramfs=*) INITRAMFS="${1#*=}"; shift ;;
        --fragment) FRAGMENTS+=("$2"); shift 2 ;;
        --fragment=*) FRAGMENTS+=("${1#*=}"); shift ;;
        --help|-h) echo "usage: $0 --initramfs PATH [--config FILE] [--fragment FILE ...]"; exit 0 ;;
        *) die "unknown argument: $1" ;;
    esac
done

[ -n "$INITRAMFS" ] || die "--initramfs is required"
require_file "$INITRAMFS"
require_file "$CONFIG"
LINUX_SRC="${LINUX_SRC:-$REPOS_DIR/software/linux}"
require_dir "$LINUX_SRC"
require_cmd make
require_cmd git
require_file "$LINUX_SRC/scripts/config"

commit="$(git -C "$LINUX_SRC" rev-parse HEAD)"
frag_sig=""
for f in "${FRAGMENTS[@]}"; do
    frag_sig+="$(sha256_of "$f")"
done
build_id="$(make_build_id "$commit" "$(sha256_of "$CONFIG")" "$(sha256_of "$INITRAMFS")" "$frag_sig" "$(riscv64-linux-gnu-gcc --version | head -n1)")"
out="$SHARED_DIR/build/linux/$build_id"
artifact="$out/Image"

if [ -f "$artifact" ]; then
    log "kernel cached: $artifact"
    printf '%s\n' "$artifact"
    exit 0
fi

log "building Linux ($build_id)"
mkdir -p "$out/build"
cp "$CONFIG" "$out/build/.config"
for f in "${FRAGMENTS[@]}"; do
    require_file "$f"
    cat "$f" >> "$out/build/.config"
done
"$LINUX_SRC/scripts/config" --file "$out/build/.config" \
    --set-str INITRAMFS_SOURCE "$(realpath "$INITRAMFS")"

make -C "$LINUX_SRC" O="$out/build" ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- olddefconfig
make -C "$LINUX_SRC" O="$out/build" ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- -j"$(nproc)"

cp "$out/build/arch/riscv/boot/Image" "$artifact"
cp "$out/build/.config" "$out/kernel.config"
{
    echo "component=linux"
    echo "commit=$commit"
    echo "build_id=$build_id"
    echo "initramfs=$INITRAMFS"
    echo "config=$CONFIG"
} > "$out/manifest.txt"

log "kernel ready: $artifact"
printf '%s\n' "$artifact"
