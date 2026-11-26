---
name: initramfs-setup
description: "Where RhetSim's embedded RISC-V initramfs lives and how the kernel build is configured"
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

**Why:** The kernel tree and the soft-float toolchain are outside the main repo, so this state is not recorded there.
**How to apply:** Rebuild the kernel only with `make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- ...`; a bare `make` once reconfigured the tree for x86 and had to be restored. See [[softfloat-busybox-toolchain]] for the userland toolchain.
