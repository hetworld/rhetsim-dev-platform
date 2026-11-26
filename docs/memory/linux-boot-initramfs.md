---
name: linux-boot-initramfs
description: RhetSim RISC-V Linux boots to /init with working PLIC UART IRQ and SSTC timer
metadata:
  node_type: memory
  type: project
  originSessionId: 4236ed53-3185-4e87-aa27-d61d2920e880
  modified: 2026-11-26T11:08:37.135Z
---

As of 2026-11-26, the RISC-V Linux boot is fully working through `/init`:

- The kernel at `../linux-6.1` has `CONFIG_BLK_DEV_INITRD=y` and an embedded initramfs (source at `/home/leo/leo/workspace/rhet/rhetsim-initramfs`).
- The DTB has a PLIC node at `0x0c000000` (64 MiB, `riscv,ndev=64`, contexts M=11/S=9); UART IRQ 10 now points at the PLIC.
- The simulator wires UART IRQ 10 to PLIC source 10, PLIC context 1 to `mip.SEIP`, and CLINT/PLIC lines into the CPU.
- `/init` prints `/proc/interrupts`, sleeps 1 second, prints again, and prints `RHETSIM_INIT_OK` only after waking. The sleep only works because the CPU implements the Sstc `stimecmp` CSR (OpenSBI detects SSTC and bypasses the CLINT timer).
- `cargo test --workspace --no-fail-fast` is green; `linux_boot` asserts `RHETSIM_INIT_OK`. `./run.sh --batch` exits early at the init marker (~44M steps) with exit 0.

See [[plic-sstc-timer]] and [[initramfs-setup]].
