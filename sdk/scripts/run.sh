#!/usr/bin/env bash
# Run the SDK's simulator with the bundled firmware, kernel and DTB.
set -euo pipefail

SDK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${RHETSIM_BIN:-$SDK_ROOT/bin/rhetsim-cli}"
MANIFEST="${RHETSIM_MANIFEST:-$SDK_ROOT/platforms/riscv-virt.toml}"
FIRMWARE="${RHETSIM_FIRMWARE:-$SDK_ROOT/firmware/fw_jump.bin}"
KERNEL="${RHETSIM_KERNEL:-$SDK_ROOT/kernel/Image}"
INITRD="${RHETSIM_INITRD:-$SDK_ROOT/rootfs/initramfs.cpio}"
DTB="${RHETSIM_DTB:-$SDK_ROOT/platforms/riscv-virt.dtb}"

for f in "$BIN" "$MANIFEST" "$FIRMWARE" "$KERNEL" "$INITRD" "$DTB"; do
    [ -f "$f" ] || { echo "missing SDK file: $f" >&2; exit 1; }
done

exec "$BIN" "$MANIFEST" --firmware "$FIRMWARE" --kernel "$KERNEL" --initrd "$INITRD" --dtb "$DTB" "$@"
