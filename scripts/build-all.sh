#!/usr/bin/env bash
# Build the complete boot stack for an instance and populate its bin/.
# Artifacts are linked from the shared cache by default; use --copy to
# materialize independent copies.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"

INSTANCE="$DEFAULT_INSTANCE"
TOOLCHAIN_DIR=""
LINK_MODE=1
ROOTFS_MODE="build"
while [ $# -gt 0 ]; do
    case "$1" in
        --instance) INSTANCE="$2"; shift 2 ;;
        --instance=*) INSTANCE="${1#*=}"; shift ;;
        --toolchain) TOOLCHAIN_DIR="$2"; shift 2 ;;
        --toolchain=*) TOOLCHAIN_DIR="${1#*=}"; shift ;;
        --link) LINK_MODE=1; shift ;;
        --copy) LINK_MODE=0; shift ;;
        --rootfs) ROOTFS_MODE="$2"; shift 2 ;;
        --rootfs=*) ROOTFS_MODE="${1#*=}"; shift ;;
        --help|-h)
            echo "usage: $0 [--instance NAME] [--toolchain DIR] [--link|--copy] [--rootfs build|prebuilt]"
            echo "  --rootfs prebuilt  reuse the committed initramfs.cpio instead of rebuilding BusyBox"
            exit 0
            ;;
        *) die "unknown argument: $1" ;;
    esac
done

case "$ROOTFS_MODE" in
    build|prebuilt) ;;
    *) die "invalid --rootfs mode: $ROOTFS_MODE (expected build|prebuilt)" ;;
esac

validate_instance_name "$INSTANCE"
ws="$(instance_workspace "$INSTANCE")"
if [ ! -d "$ws" ]; then
    "$ROOT/scripts/instance-create.sh" "$INSTANCE"
fi
load_instance_env "$INSTANCE"

[ -n "$TOOLCHAIN_DIR" ] || TOOLCHAIN_DIR="$("$ROOT/scripts/build-toolchain.sh" | tail -n1)"
sim="$("$ROOT/scripts/build-simulator.sh" | tail -n1)"
fw="$("$ROOT/scripts/build-firmware.sh" | tail -n1)"
if [ "$ROOTFS_MODE" = "prebuilt" ]; then
    cpio="$("$ROOT/scripts/build-initramfs.sh" --prebuilt | tail -n1)"
else
    cpio="$("$ROOT/scripts/build-initramfs.sh" --toolchain "$TOOLCHAIN_DIR" | tail -n1)"
fi
kernel="$("$ROOT/scripts/build-kernel.sh" \
    --fragment "$ENV_DIR/configs/linux/fragments/smp-2hart.config" \
    --fragment "$ENV_DIR/configs/linux/fragments/initramfs.config" \
    --fragment "$ws/config/kernel.fragment" | tail -n1)"

rhetsim_src="${RHETSIM_SRC:-$REPOS_DIR/rhetsim}"
dtb="$rhetsim_src/platforms/reference/server/riscv-virt.dtb"
require_file "$dtb"

install_artifact() {
    local src="$1" dst="$2"
    if [ "$LINK_MODE" -eq 1 ]; then
        ln -sfn "$src" "$dst"
    else
        cp -f --remove-destination "$src" "$dst"
    fi
}

mkdir -p "$ws/bin"
install_artifact "$sim" "$ws/bin/rhetsim-cli"
install_artifact "$fw" "$ws/bin/fw_jump.bin"
install_artifact "$kernel" "$ws/bin/Image"
install_artifact "$cpio" "$ws/bin/initramfs.cpio"
# The DTB is tiny; copy it so the instance does not depend on repos/ at run time.
cp -f --remove-destination "$dtb" "$ws/bin/riscv-virt.dtb"

python3 "$ROOT/scripts/lib/write_runtime_manifest.py" \
    --instance "$INSTANCE" \
    --output "$ws/bin/runtime.manifest.json" \
    --shared-root "$SHARED_DIR" \
    --build-id "rhetsim-cli=$(basename "$(dirname "$sim")")" \
    --build-id "fw_jump.bin=$(basename "$(dirname "$fw")")" \
    --build-id "Image=$(basename "$(dirname "$kernel")")" \
    --build-id "initramfs.cpio=$(basename "$(dirname "$cpio")")" \
    "rhetsim-cli=$ws/bin/rhetsim-cli" \
    "fw_jump.bin=$ws/bin/fw_jump.bin" \
    "Image=$ws/bin/Image" \
    "initramfs.cpio=$ws/bin/initramfs.cpio" \
    "riscv-virt.dtb=$ws/bin/riscv-virt.dtb" >/dev/null

log "instance '$INSTANCE' built (rootfs=$ROOTFS_MODE, link=$LINK_MODE)"
