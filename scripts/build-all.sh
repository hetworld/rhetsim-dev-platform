#!/usr/bin/env bash
# Build the simulator, OpenSBI and Linux, then assemble the prebuilt rootfs.
# The rootfs is a resource from rhetsim-initramfs; the platform does not build it.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"

INSTANCE="$DEFAULT_INSTANCE"
LINK_MODE=1
while [ $# -gt 0 ]; do
    case "$1" in
        --instance) INSTANCE="$2"; shift 2 ;;
        --instance=*) INSTANCE="${1#*=}"; shift ;;
        --link) LINK_MODE=1; shift ;;
        --copy) LINK_MODE=0; shift ;;
        --help|-h)
            echo "usage: $0 [--instance NAME] [--link|--copy]"
            echo "  builds rhetsim-cli, OpenSBI and Linux; assembles the prebuilt rootfs"
            exit 0
            ;;
        *) die "unknown argument: $1" ;;
    esac
done

validate_instance_name "$INSTANCE"
ws="$(instance_workspace "$INSTANCE")"
if [ ! -d "$ws" ]; then
    "$ROOT/scripts/instance-create.sh" "$INSTANCE"
fi
load_instance_env "$INSTANCE"

sim="$("$ROOT/scripts/build-simulator.sh" | tail -n1)"
fw="$("$ROOT/scripts/build-firmware.sh" | tail -n1)"
kernel="$("$ROOT/scripts/build-kernel.sh" \
    --fragment "$ENV_DIR/configs/linux/fragments/smp-2hart.config" \
    --fragment "$ENV_DIR/configs/linux/fragments/initramfs.config" \
    --fragment "$ws/config/kernel.fragment" | tail -n1)"

# Root filesystem: pinned/prebuilt resource from rhetsim-initramfs.
initramfs_src="${INITRAMFS_SRC:-$REPOS_DIR/software/rhetsim-initramfs}"
cpio_src="$initramfs_src/initramfs.cpio"
require_file "$cpio_src"
require_cmd git
initramfs_commit="$(git -C "$initramfs_src" rev-parse HEAD)"
cpio_sha="$(sha256_of "$cpio_src")"
resource_id="$(make_build_id "$initramfs_commit" "$cpio_sha")"
resource_dir="$SHARED_DIR/resources/initramfs/$resource_id"
cpio="$resource_dir/initramfs.cpio"
if [ ! -f "$cpio" ]; then
    mkdir -p "$resource_dir"
    cp -f "$cpio_src" "$cpio"
    {
        echo "component=rhetsim-initramfs"
        echo "commit=$initramfs_commit"
        echo "resource_id=$resource_id"
        echo "sha256=$cpio_sha"
        echo "mode=prebuilt"
    } > "$resource_dir/manifest.txt"
fi

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
    --build-id "initramfs.cpio=$resource_id" \
    "rhetsim-cli=$ws/bin/rhetsim-cli" \
    "fw_jump.bin=$ws/bin/fw_jump.bin" \
    "Image=$ws/bin/Image" \
    "initramfs.cpio=$ws/bin/initramfs.cpio" \
    "riscv-virt.dtb=$ws/bin/riscv-virt.dtb" >/dev/null

log "instance '$INSTANCE' built (sim + fw + kernel + prebuilt rootfs)"
