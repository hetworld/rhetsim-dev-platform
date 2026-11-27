#!/usr/bin/env bash
# Optional maintainer tool: build the BusyBox initramfs, or reuse the committed
# prebuilt cpio. Not part of ./run.sh build; the default platform consumes the
# cpio committed in rhetsim-initramfs.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"

TOOLCHAIN_DIR=""
PREBUILT=0
while [ $# -gt 0 ]; do
    case "$1" in
        --toolchain) TOOLCHAIN_DIR="$2"; shift 2 ;;
        --toolchain=*) TOOLCHAIN_DIR="${1#*=}"; shift ;;
        --prebuilt) PREBUILT=1; shift ;;
        --build) PREBUILT=0; shift ;;
        --help|-h)
            echo "usage: $0 [--toolchain DIR] [--prebuilt|--build]"
            echo "  --prebuilt  reuse rhetsim-initramfs/initramfs.cpio; do not run BusyBox"
            exit 0
            ;;
        *) die "unknown argument: $1" ;;
    esac
done

INITRAMFS_SRC="${INITRAMFS_SRC:-$REPOS_DIR/software/rhetsim-initramfs}"
BUSYBOX_SRC="${BUSYBOX_SRC:-$ROOT/tools/initramfs/src/busybox}"
KERNEL_SRC="${KERNEL_SRC:-$REPOS_DIR/software/linux}"
require_dir "$INITRAMFS_SRC"
require_cmd git
commit="$(git -C "$INITRAMFS_SRC" rev-parse HEAD)"

if [ "$PREBUILT" -eq 1 ]; then
    cpio_src="$INITRAMFS_SRC/initramfs.cpio"
    require_file "$cpio_src"
    [ -s "$cpio_src" ] || die "empty prebuilt initramfs: $cpio_src"
    build_id="$(make_build_id "$commit" prebuilt "$(sha256_of "$cpio_src")")"
    out="$SHARED_DIR/build/initramfs/$build_id"
    artifact="$out/initramfs.cpio"
    if [ -f "$artifact" ]; then
        log "prebuilt initramfs cached: $artifact"
        printf '%s\n' "$artifact"
        exit 0
    fi
    mkdir -p "$out"
    cp -f "$cpio_src" "$artifact"
    {
        echo "component=rhetsim-initramfs"
        echo "commit=$commit"
        echo "build_id=$build_id"
        echo "mode=prebuilt"
        echo "sha256=$(sha256_of "$artifact")"
    } > "$out/manifest.txt"
    log "prebuilt initramfs ready: $artifact"
    printf '%s\n' "$artifact"
    exit 0
fi

require_dir "$BUSYBOX_SRC"
require_dir "$KERNEL_SRC"
require_cmd make
require_cmd riscv64-linux-gnu-gcc

if [ -z "$TOOLCHAIN_DIR" ]; then
    TOOLCHAIN_DIR="$(find "$SHARED_DIR/toolchain" -mindepth 1 -maxdepth 1 -type d \
        -name 'rv64ima-*' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n1 | cut -d' ' -f2- || true)"
fi
[ -n "$TOOLCHAIN_DIR" ] || die "no toolchain found; run scripts/build-toolchain.sh first"
SYSROOT="$TOOLCHAIN_DIR/sysroot"
require_dir "$SYSROOT"
require_file "$SYSROOT/bin/musl-gcc"

busybox_sig="$(sha256_of "$BUSYBOX_SRC/Makefile" 2>/dev/null || echo custom)"
build_id="$(make_build_id "$commit" "$(basename "$TOOLCHAIN_DIR")" "$busybox_sig")"
out="$SHARED_DIR/build/initramfs/$build_id"
artifact="$out/initramfs.cpio"

if [ -f "$artifact" ]; then
    log "initramfs cached: $artifact"
    printf '%s\n' "$artifact"
    exit 0
fi

tmp="$SHARED_DIR/build/initramfs/.tmp-$build_id-$$"
cleanup() { [ -d "$tmp" ] && rm -rf "$tmp"; }
trap cleanup EXIT
mkdir -p "$tmp/src"

# Use the committed tree, not the working tree, so the canonical repo stays clean.
git -C "$INITRAMFS_SRC" archive --format=tar HEAD | tar -x -C "$tmp/src"

log "building BusyBox and initramfs ($build_id)"
MUSL_SYSROOT="$SYSROOT" \
BUSYBOX_SRC="$BUSYBOX_SRC" \
CROSS_COMPILE=riscv64-linux-gnu- \
    "$tmp/src/build-busybox.sh"

KERNEL_DIR="$KERNEL_SRC" "$tmp/src/build.sh"

mkdir -p "$out"
cp "$tmp/src/initramfs.cpio" "$artifact"
{
    echo "component=rhetsim-initramfs"
    echo "commit=$commit"
    echo "build_id=$build_id"
    echo "mode=build"
    echo "toolchain=$TOOLCHAIN_DIR"
    echo "busybox=$BUSYBOX_SRC"
} > "$out/manifest.txt"

log "initramfs ready: $artifact"
printf '%s\n' "$artifact"
