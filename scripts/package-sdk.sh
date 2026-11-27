#!/usr/bin/env bash
# Package an instance's runtime artifacts into an SDK bundle.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"

INSTANCE="$DEFAULT_INSTANCE"
VERSION="${VERSION:-0.1.0-dev}"
FORCE=0
ARCHIVE=1
WITH_TOOLCHAIN=1
while [ $# -gt 0 ]; do
    case "$1" in
        --instance) INSTANCE="$2"; shift 2 ;;
        --instance=*) INSTANCE="${1#*=}"; shift ;;
        --version) VERSION="$2"; shift 2 ;;
        --version=*) VERSION="${1#*=}"; shift ;;
        --force) FORCE=1; shift ;;
        --no-archive) ARCHIVE=0; shift ;;
        --no-toolchain) WITH_TOOLCHAIN=0; shift ;;
        --help|-h)
            echo "usage: $0 [--instance NAME] [--version VER] [--force] [--no-archive] [--no-toolchain]"
            exit 0
            ;;
        *) die "unknown argument: $1" ;;
    esac
done

validate_instance_name "$INSTANCE"
ws="$(instance_workspace "$INSTANCE")"
require_dir "$ws/bin"
for f in rhetsim-cli fw_jump.bin Image riscv-virt.dtb initramfs.cpio; do
    require_file "$ws/bin/$f"
done
require_file "$ws/config/platform.toml"

sdk_root="$DIST_DIR/rhetsim-sdk-$VERSION"
if [ -d "$sdk_root" ]; then
    [ "$FORCE" -eq 1 ] || die "SDK directory exists: $sdk_root (use --force)"
    rm -rf "$sdk_root"
fi

mkdir -p "$sdk_root"/{bin,firmware,kernel,platforms,rootfs,toolchain,examples,scripts}
cp -f "$ws/bin/rhetsim-cli"       "$sdk_root/bin/rhetsim-cli"
cp -f "$ws/bin/fw_jump.bin"       "$sdk_root/firmware/fw_jump.bin"
cp -f "$ws/bin/Image"             "$sdk_root/kernel/Image"
cp -f "$ws/bin/riscv-virt.dtb"    "$sdk_root/platforms/riscv-virt.dtb"
cp -f "$ws/config/platform.toml"  "$sdk_root/platforms/riscv-virt.toml"
python3 - "$sdk_root/platforms/riscv-virt.toml" <<'PY'
import re
import sys

path = sys.argv[1]
text = open(path, encoding="utf-8").read()
text = re.sub(r"(?m)^firmware = .*$", 'firmware = "../firmware/fw_jump.bin"', text)
text = re.sub(r"(?m)^kernel = .*$", 'kernel = "../kernel/Image"', text)
text = re.sub(r"(?m)^initrd = .*$", 'initrd = "../rootfs/initramfs.cpio"', text)
text = re.sub(r"(?m)^dtb = .*$", 'dtb = "riscv-virt.dtb"', text)
open(path, "w", encoding="utf-8").write(text)
PY
cp -f "$ws/bin/initramfs.cpio"    "$sdk_root/rootfs/initramfs.cpio"
cp -a "$ROOT/sdk/examples/hello"  "$sdk_root/examples/hello"
cp -f "$ROOT/sdk/scripts/run.sh"  "$sdk_root/scripts/run.sh"
chmod +x "$sdk_root/bin/rhetsim-cli" "$sdk_root/scripts/run.sh"

if [ "$WITH_TOOLCHAIN" -eq 1 ]; then
    toolchain="$(find "$SHARED_DIR/toolchain" -mindepth 1 -maxdepth 1 -type d \
        -name 'rv64ima-*' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n1 | cut -d' ' -f2- || true)"
    if [ -n "$toolchain" ] && [ -d "$toolchain/sysroot" ]; then
        log "including toolchain sysroot from $toolchain"
        cp -a "$toolchain/sysroot" "$sdk_root/toolchain/sysroot"
    else
        warn "no built toolchain found; SDK will not include a sysroot"
        echo "No sysroot was bundled. Build one with tools/toolchain/build-toolchain.sh." \
            > "$sdk_root/toolchain/README.md"
    fi
fi

cat > "$sdk_root/README.md" <<EOF
# RhetSim SDK $VERSION

Instance: $INSTANCE

Layout:
- bin/rhetsim-cli       RISC-V simulator (host x86-64 binary)
- firmware/fw_jump.bin  OpenSBI firmware
- kernel/Image          Linux kernel (rootfs is an external initrd)
- platforms/            Platform manifest and DTB
- rootfs/initramfs.cpio Root filesystem loaded as initrd
- toolchain/            Optional cross sysroot
- examples/hello        Example user-space program
- scripts/run.sh        Convenience launcher

Run:
    ./scripts/run.sh --batch

Cross-compile (if a sysroot is bundled):
    toolchain/sysroot/bin/musl-gcc -march=rv64ima -mabi=lp64 -static hello.c -o hello

See manifest.json for component versions, artifact checksums and licenses.
EOF

python3 "$ROOT/scripts/lib/write_sdk_manifest.py" \
    --root "$sdk_root" \
    --repo-root "$ROOT" \
    --version "$VERSION" \
    --instance "$INSTANCE" >/dev/null

if [ "$ARCHIVE" -eq 1 ]; then
    archive="$DIST_DIR/rhetsim-sdk-$VERSION.tar.gz"
    tar -czf "$archive" -C "$DIST_DIR" "rhetsim-sdk-$VERSION"
    sha256_of "$archive" | awk -v f="$(basename "$archive")" '{print $1"  "f}' > "$archive.sha256"
    log "archive: $archive"
fi

log "SDK ready: $sdk_root"
