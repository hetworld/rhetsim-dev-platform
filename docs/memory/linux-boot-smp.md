---
name: linux-boot-smp
description: RhetSim boots 2-hart SMP Linux to /init with per-hart PLIC/CLINT wiring
metadata:
  node_type: memory
  type: project
  originSessionId: 4236ed53-3185-4e87-aa27-d61d2920e880
  modified: 2026-11-26T11:45:16.020Z
---

As of 2026-11-26, RhetSim boots a 2-hart SMP Linux to `/init`:

- Kernel config: `CONFIG_SMP=y`, `CONFIG_NR_CPUS=2`; Image at `../linux-6.1/arch/riscv/boot/Image` (SMP, initramfs embedded). Backups: `Image.before-smp`, `.config.before-smp`.
- DTB: `cpu@0`/`cpu@1`, PLIC `0x0c000000` with 4 contexts (M/S per hart), CLINT `num_harts=2`; TOML has `rv-core0`/`rv-core1`, PLIC `num_contexts=4`.
- CLI creates one RiscvCpu per hart, sets `mhartid` and `a0=hartid`, attaches CLINT/PLIC lines per hart (`PlicContextLine` context `2*hart`/`2*hart+1`), and round-robins `exec` over all CPUs.
- Boot log includes `smp: Brought up 1 node, 2 CPUs`; `/proc/interrupts` has CPU0/CPU1 columns, PLIC UART IRQ and per-CPU riscv-timer counts, plus IPI rows.
- `/init` prints markers, sleeps 1s, prints again, then `RHETSIM_INIT_OK`; CLI exits early at the marker. `linux_boot` (2 harts) passes in ~140s debug; full workspace tests green.
- OpenSBI has no platform HSM device; `sbi_hsm_hart_start` starts secondary harts via the CLINT MSIP IPI (and the warm wait loop polls HSM state).

**Why:** Multi-hart exposed the false-AIA issue; see [[aia-false-detect]].
**How to apply:** When adding more harts, extend DTB CPU nodes, PLIC contexts to `2*N`, CLINT `num_harts`, TOML CPU units, and the CLI loop.
