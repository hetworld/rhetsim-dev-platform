---
name: initramfs-setup
description: "Where RhetSim's initramfs lives and how kernel/rootfs are built (embedded legacy vs external initrd)"
metadata:
  node_type: memory
  type: project
  originSessionId: e4bea1a5-f3ee-41f7-9ee4-07224a46e9f9
  modified: 2026-11-26T14:07:17.580Z
---

The embedded initramfs source is at `/home/leo/leo/workspace/rhet/rhetsim-initramfs`: `init.sh` (BusyBox-based /init: mounts proc/sysfs, prints the `RHETSIM_INIT_*` markers, then `exec cttyhack /bin/sh -i`), `initramfs.spec`, `build.sh`, `build-busybox.sh`, a prebuilt static `busybox` (rv64ima/lp64 soft-float), and `initramfs.cpio`. `build.sh` compiles `gen_init_cpio.c` with host `gcc` and packages the cpio from the prebuilt busybox; it must never invoke the kernel Makefile without `ARCH=riscv`. The old freestanding `init.c`/`init` were removed.

Kernel build state in `/home/leo/leo/workspace/rhet/linux-6.1`:
- `.config` has `CONFIG_BLK_DEV_INITRD=y`, `CONFIG_INITRAMFS_SOURCE="/home/leo/leo/workspace/rhet/rhetsim-initramfs/initramfs.cpio"`, `CONFIG_RD_GZIP=y`, `CONFIG_INITRAMFS_COMPRESSION_GZIP=y`, `CONFIG_SOC_VIRT=y`, `CONFIG_SIFIVE_PLIC=y`, `CONFIG_SMP=y`, `CONFIG_NR_CPUS=2`.
- Backups: `.config.before-initramfs`, `.config.before-smp`, `arch/riscv/boot/Image.before-initramfs`, `Image.before-smp`, `Image.before-busybox`.
- The embedded `/init` prints `/proc/interrupts`, sleeps 1s, prints again, then `RHETSIM_INIT_OK` and starts the shell (so a timer failure fails the boot test).
- Verify embedding via `zcat usr/initramfs_inc_data | cpio -itv`.

## Dev-platform update (2026-11-27)

The dev-platform no longer embeds the initramfs in the kernel. `scripts/build-kernel.sh`
builds with `CONFIG_INITRAMFS_SOURCE=""`; `rhetsim-cli --initrd` loads the cpio into
DRAM and writes `linux,initrd-start/end` into the DTB `/chosen` node. Changing the
rootfs does not rebuild the kernel. The embedded-initramfs details above describe the
historical rhetsim tree.

The rootfs itself is a **prebuilt resource**: the default platform copies
`rhetsim-initramfs/initramfs.cpio` into `workspace/shared/resources/initramfs/<id>/`
and does not run BusyBox. Rebuilding it is an optional maintainer tool at
`tools/initramfs/build-initramfs.sh`.

Verified 2026-11-27: kernel without embedded initramfs + simulator `--initrd` boots
to `RHETSIM_INIT_OK`; the same kernel without `--initrd` panics with
`VFS: Unable to mount root fs`. The out-of-tree kernel build requires a clean source
tree (no in-tree `.config`); use a clean clone or detached worktree.

**Why:** The kernel/rootfs resources and the optional soft-float toolchain used to be
manual out-of-repo state. The dev-platform now pins the kernel source and consumes a
prebuilt rootfs, while keeping OpenSBI/Linux buildable for simulator/software sync.
**How to apply:** keep `CONFIG_INITRAMFS_SOURCE=""` and pass the cpio via `--initrd`;
the default build consumes the committed cpio. Rebuild the rootfs only with
`tools/initramfs/build-initramfs.sh`. See [[softfloat-busybox-toolchain]] for the
optional userland toolchain.
