---
name: softfloat-busybox-toolchain
description: How the rv64ima soft-float musl/BusyBox toolchain and initramfs are built
metadata:
  node_type: memory
  type: project
  originSessionId: e4bea1a5-f3ee-41f7-9ee4-07224a46e9f9
  modified: 2026-11-26T15:52:00.000Z
---

RhetSim's CPU is rv64ima (no F/D), so userspace needs the lp64 soft-float ABI. Build tree lives outside the repos at `/home/leo/leo/workspace/rhet/softfloat/`:

- `musl/musl-1.2.5`: built with `CROSS_COMPILE=riscv64-linux-gnu- CFLAGS='-march=rv64ima -mabi=lp64'`, prefix `softfloat/sysroot`.
- `sysroot/bin/musl-gcc` + `sysroot/lib/musl-gcc.specs`: specs hand-patched to use musl `crt1.o/crti.o/crtn.o` (no gcc crtbegin, which is lp64d) and an absolute `*libgcc` pointing at the soft libgcc.
- `sysroot/lib/libgcc.a`: merged archive built by `softfloat/tools/build_softfp_libgcc.sh`. Ubuntu's `libgcc.a` is compiled for rv64gc/lp64d: its objects get e_flags float-ABI cleared (`tools/patch_elf_abi.py`) and its TF helpers are replaced by soft-fp objects compiled from `gcc-11.4.0/libgcc/soft-fp`. The distro libgcc has **no** SF/DF helpers at all (hardware F/D assumed), hence the soft-fp build.
- `busybox/busybox-1.36.1`: built static via `/home/leo/leo/workspace/rhet/rhetsim-initramfs/build-busybox.sh`.

The initramfs repo (`../rhetsim-initramfs`) now uses `init.sh` + static `busybox`; `build.sh` only regenerates the cpio (requires `busybox` present). The historical embedded setup required a kernel rebuild after changing the cpio; the dev-platform now uses an external initrd, so a rootfs change does not rebuild the kernel. Backup: `/home/leo/leo/workspace/rhet/linux-6.1/arch/riscv/boot/Image.before-busybox`.

## dev-platform toolchain (optional, 2026-11-27)

The dev-platform keeps this toolchain as an **optional maintainer tool** at
`tools/toolchain/build-toolchain.sh`; `./run.sh build` does not build it. The
default platform consumes the prebuilt rootfs and builds simulator + OpenSBI + Linux.

- musl is installed **static-only** (`make lib/libc.a`, `make install SHARED_LIBS=`)
  because linking `libc.so` needs the soft-float libgcc that does not exist yet.
  The sysroot intentionally has no `libc.so`; user space is static.
- The sysroot is relocatable: `bin/musl-gcc` locates its own sysroot at run time and
  generates a temporary specs file from `lib/musl-gcc.specs.in`, so a sysroot or SDK
  copied to another path still compiles.
- The soft-fp libgcc is built from GCC's `libgcc/soft-fp` and merged with the distro
  archive (float-ABI flags cleared by `patch_elf_abi.py`).
- Verified on 2026-11-26: rebuild from the existing musl/GCC sources, compile the SDK
  example, compile from a relocated sysroot and a relocated SDK, and boot the packaged
  SDK to `RHETSIM_INIT_OK`.

**Why:** recreating this toolchain is non-obvious (patched specs, ABI flags, soft-fp
merge) and it used to be manual out-of-repo state. Keeping it as a tool keeps the
default platform focused on simulator/OpenSBI/Linux development.
**How to apply:** run `tools/toolchain/build-toolchain.sh` with `MUSL_SRC`/`GCC_SRC`
when you need a sysroot (for example to ship one in the SDK). Do not swap in a
standard riscv64 glibc/musl toolchain, which is lp64d and faults on this CPU.
See [[initramfs-setup]], [[dev-platform-layout]].
