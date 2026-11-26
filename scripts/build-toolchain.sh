#!/usr/bin/env bash
# Build the rv64ima/lp64 soft-float musl sysroot and soft-fp libgcc.
# Output: workspace/shared/toolchain/<abi-id>/
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"

MUSL_SRC="${MUSL_SRC:-$REPOS_DIR/toolchain/musl}"
GCC_SRC="${GCC_SRC:-$REPOS_DIR/toolchain/gcc}"
# shellcheck source=../env/configs/musl/build.conf
source "$ENV_DIR/configs/musl/build.conf"

require_dir "$MUSL_SRC"
require_dir "$GCC_SRC"
require_cmd riscv64-linux-gnu-gcc
require_cmd make

host_gcc="$(riscv64-linux-gnu-gcc --version | head -n1)"
abi_id="rv64ima-lp64-musl-${MUSL_VERSION}-$(make_build_id "$MUSL_VERSION" "$MUSL_CFLAGS" "$host_gcc")"
out="$SHARED_DIR/toolchain/$abi_id"

if [ -f "$out/.complete" ]; then
    log "toolchain cached: $out"
    printf '%s\n' "$out"
    exit 0
fi

tmp="$SHARED_DIR/toolchain/.tmp-$$"
cleanup() { [ -d "$tmp" ] && rm -rf "$tmp"; }
trap cleanup EXIT

mkdir -p "$tmp/sysroot" "$tmp/libgcc-soft"
log "building musl $MUSL_VERSION for $TARGET"
(
    cd "$MUSL_SRC"
    make distclean >/dev/null 2>&1 || true
    ./configure \
        --target="$TARGET" \
        --prefix="$tmp/sysroot" \
        CROSS_COMPILE=riscv64-linux-gnu- \
        CFLAGS="$MUSL_CFLAGS" \
        LDFLAGS="$MUSL_CFLAGS"
    # The simulated user space is static. Linking lib/libc.so would need a
    # soft-float libgcc that does not exist yet, so install the static libs only.
    make -j"$(nproc)" lib/libc.a
    make install SHARED_LIBS=
)

log "building soft-float libgcc"
distro_libgcc="$(riscv64-linux-gnu-gcc -print-libgcc-file-name)"
GCC_SRC="$GCC_SRC" \
DISTRO_LIBGCC="$distro_libgcc" \
OUT_DIR="$tmp/libgcc-soft" \
PATCHER="$ROOT/scripts/tools/patch_elf_abi.py" \
    "$ROOT/scripts/tools/build_softfp_libgcc.sh"
cp "$tmp/libgcc-soft/libgcc-soft.a" "$tmp/sysroot/lib/libgcc.a"

log "installing musl-gcc specs and wrapper"
cp "$ENV_DIR/configs/musl/musl-gcc.specs.in" "$tmp/sysroot/lib/musl-gcc.specs.in"
sed "s|@SYSROOT@|$tmp/sysroot|g" \
    "$ENV_DIR/configs/musl/musl-gcc.specs.in" > "$tmp/sysroot/lib/musl-gcc.specs"
# The wrapper generates a specs file from the template at run time so the
# sysroot stays relocatable (SDK bundles are extracted at arbitrary paths).
cat > "$tmp/sysroot/bin/musl-gcc" <<'EOF'
#!/bin/sh
set -eu
SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SYSROOT=$(CDPATH= cd -- "$SELF_DIR/.." && pwd)
SPECS=$(mktemp "${TMPDIR:-/tmp}/musl-gcc.XXXXXX.specs")
trap 'rm -f "$SPECS"' EXIT
sed "s|@SYSROOT@|$SYSROOT|g" "$SYSROOT/lib/musl-gcc.specs.in" > "$SPECS"
"${REALGCC:-riscv64-linux-gnu-gcc}" "$@" -specs "$SPECS"
EOF
chmod +x "$tmp/sysroot/bin/musl-gcc"

{
    echo "musl=$MUSL_VERSION"
    echo "target=$TARGET"
    echo "cflags=$MUSL_CFLAGS"
    echo "host_gcc=$host_gcc"
    echo "distro_libgcc=$distro_libgcc"
} > "$tmp/.complete"

mkdir -p "$(dirname "$out")"
mv "$tmp" "$out"
trap - EXIT

# Keep a concrete specs file for direct users, pointing at the final cache path.
# The musl-gcc wrapper uses the relocatable .in template instead.
sed -i "s|$tmp/sysroot|$out/sysroot|g" "$out/sysroot/lib/musl-gcc.specs"

log "toolchain ready: $out"
printf '%s\n' "$out"
