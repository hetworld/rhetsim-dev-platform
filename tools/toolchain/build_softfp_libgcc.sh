#!/usr/bin/env bash
# Build a soft-float libgcc.a for rv64ima (-mabi=lp64).
#
# The distro libgcc is compiled for rv64gc/lp64d and has no SF/DF software
# helpers at all (it assumes F/D hardware). musl built for lp64 needs them,
# so compile the soft-fp implementations from GCC's libgcc sources and merge
# them with the distro archive (whose objects have their float-ABI e_flags
# cleared by patch_elf_abi.py, and whose soft-fp TF objects we replace).
set -euo pipefail

GCC_SRC=${GCC_SRC:?path to extracted gcc-11.4.0 source}
DISTRO_LIBGCC=${DISTRO_LIBGCC:-/usr/lib/gcc-cross/riscv64-linux-gnu/11/libgcc.a}
CC=${CC:-riscv64-linux-gnu-gcc}
AR=${AR:-riscv64-linux-gnu-ar}
NM=${NM:-riscv64-linux-gnu-nm}
OBJCOPY=${OBJCOPY:-riscv64-linux-gnu-objcopy}
PATCHER=${PATCHER:-$(dirname "$0")/patch_elf_abi.py}
OUT_DIR=${OUT_DIR:?output directory}
FLAGS="-march=rv64ima -mabi=lp64 -O2 -fno-builtin"
INC="-I$GCC_SRC/libgcc -I$GCC_SRC/libgcc/soft-fp -I$GCC_SRC/libgcc/config/riscv -I$GCC_SRC/include"

mkdir -p "$OUT_DIR/softfp" "$OUT_DIR/distro" "$OUT_DIR/mixed"
rm -f "$OUT_DIR/softfp"/*.o "$OUT_DIR/distro"/*.o "$OUT_DIR/mixed"/*.o

# 1. Soft-fp helpers for SF, DF and TF (half/extended are not RISC-V modes).
for src in "$GCC_SRC"/libgcc/soft-fp/*.c; do
    name=$(basename "$src" .c)
    case "$name" in
        *hf*|*xf*) continue ;;
    esac
    "$CC" $FLAGS $INC -c "$src" -o "$OUT_DIR/softfp/$name.o"
done

# 2. Distro archive objects, float-ABI flags cleared, attributes dropped.
(cd "$OUT_DIR/distro" && "$AR" x "$DISTRO_LIBGCC")
for obj in "$OUT_DIR"/distro/*.o; do
    "$OBJCOPY" --remove-section=.riscv.attributes "$obj" 2>/dev/null || true
done
python3 "$PATCHER" "$OUT_DIR"/distro/*.o

# 3. Merge: our soft-fp objects win; skip distro objects defining the same
#    symbols (they are the hard-float TF helpers and would clash / trap).
"$NM" -g --defined-only "$OUT_DIR"/softfp/*.o | awk '{print $3}' | sort -u > "$OUT_DIR/softfp.syms"
for obj in "$OUT_DIR"/distro/*.o; do
    skip=0
    while read -r sym; do
        if "$NM" -g --defined-only "$obj" 2>/dev/null | awk '{print $3}' | grep -qx -- "$sym"; then
            skip=1
            break
        fi
    done < "$OUT_DIR/softfp.syms"
    [ "$skip" -eq 0 ] && cp "$obj" "$OUT_DIR/mixed/"
done
for obj in "$OUT_DIR"/softfp/*.o; do cp "$obj" "$OUT_DIR/mixed/sfp_$(basename "$obj")"; done

"$AR" rcs "$OUT_DIR/libgcc-soft.a" "$OUT_DIR"/mixed/*.o
echo "libgcc-soft.a: $(stat -c '%s bytes' "$OUT_DIR/libgcc-soft.a")"
