#!/usr/bin/env bash
# Build or link the boot artifacts for an instance.
# Instances consume shared, content-addressed artifacts; they never rebuild the
# root filesystem or kernel unless the shared cache is missing that input set.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"

INSTANCE=""
REUSE=""
LINK_MODE=""   # empty: default (link for build-all, copy for --reuse-existing)
ROOTFS_MODE=""
while [ $# -gt 0 ]; do
    case "$1" in
        --instance) INSTANCE="$2"; shift 2 ;;
        --instance=*) INSTANCE="${1#*=}"; shift ;;
        --reuse-existing) REUSE="$2"; shift 2 ;;
        --reuse-existing=*) REUSE="${1#*=}"; shift ;;
        --link) LINK_MODE=1; shift ;;
        --copy) LINK_MODE=0; shift ;;
        --rootfs) ROOTFS_MODE="$2"; shift 2 ;;
        --rootfs=*) ROOTFS_MODE="${1#*=}"; shift ;;
        --help|-h)
            echo "usage: $0 [<instance>] [--reuse-existing DIR] [--link|--copy] [--rootfs build|prebuilt]"
            echo "  default build uses the shared cache and links artifacts into bin/"
            echo "  --copy           materialize independent copies in the instance"
            echo "  --rootfs prebuilt reuse the committed initramfs.cpio (no BusyBox build)"
            exit 0
            ;;
        -*) die "unknown argument: $1" ;;
        *) INSTANCE="$1"; shift ;;
    esac
done

INSTANCE="${INSTANCE:-$DEFAULT_INSTANCE}"
validate_instance_name "$INSTANCE"
ws="$(instance_workspace "$INSTANCE")"
if [ ! -d "$ws" ]; then
    "$ROOT/scripts/instance-create.sh" "$INSTANCE"
fi
load_instance_env "$INSTANCE"

if [ -z "$REUSE" ]; then
    args=(--instance "$INSTANCE")
    if [ -n "$LINK_MODE" ]; then
        if [ "$LINK_MODE" -eq 1 ]; then args+=(--link); else args+=(--copy); fi
    fi
    if [ -n "$ROOTFS_MODE" ]; then
        args+=(--rootfs "$ROOTFS_MODE")
    fi
    exec "$ROOT/scripts/build-all.sh" "${args[@]}"
fi

[ -z "$ROOTFS_MODE" ] || die "--rootfs is only valid without --reuse-existing"
require_dir "$REUSE"
sim="$REUSE/rhetsim/target/release/rhetsim-cli"
fw="$REUSE/opensbi/build/platform/generic/firmware/fw_jump.bin"
kernel="$REUSE/linux-6.1/arch/riscv/boot/Image"
dtb="$REUSE/rhetsim/platforms/reference/server/riscv-virt.dtb"
cpio="$REUSE/rhetsim-initramfs/initramfs.cpio"
for f in "$sim" "$fw" "$kernel" "$dtb" "$cpio"; do
    require_file "$f"
done

COPY_MODE=1
if [ -n "$LINK_MODE" ] && [ "$LINK_MODE" -eq 1 ]; then
    COPY_MODE=0
fi

install_artifact() {
    local src="$1" dst="$2"
    if [ "$COPY_MODE" -eq 1 ]; then
        cp -f --remove-destination "$src" "$dst"
    else
        ln -sfn "$src" "$dst"
    fi
}

mkdir -p "$ws/bin"
install_artifact "$sim" "$ws/bin/rhetsim-cli"
install_artifact "$fw" "$ws/bin/fw_jump.bin"
install_artifact "$kernel" "$ws/bin/Image"
install_artifact "$dtb" "$ws/bin/riscv-virt.dtb"
install_artifact "$cpio" "$ws/bin/initramfs.cpio"

python3 "$ROOT/scripts/lib/write_runtime_manifest.py" \
    --instance "$INSTANCE" \
    --output "$ws/bin/runtime.manifest.json" \
    --reused-from "$REUSE" \
    "rhetsim-cli=$ws/bin/rhetsim-cli" \
    "fw_jump.bin=$ws/bin/fw_jump.bin" \
    "Image=$ws/bin/Image" \
    "initramfs.cpio=$ws/bin/initramfs.cpio" \
    "riscv-virt.dtb=$ws/bin/riscv-virt.dtb" >/dev/null

log "instance '$INSTANCE' linked from $REUSE (copy=$COPY_MODE)"
