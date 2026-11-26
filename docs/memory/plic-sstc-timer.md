---
name: plic-sstc-timer
description: "Key non-obvious details of RhetSim's PLIC/UART IRQ and SSTC timer wiring"
metadata:
  node_type: memory
  type: project
  originSessionId: 4236ed53-3185-4e87-aa27-d61d2920e880
  modified: 2026-11-26T11:08:39.073Z
---

PLIC/UART:
- DTB PLIC is at `0x0c000000`, 64 MiB, `riscv,ndev=64`, `interrupts-extended = <&cpu0_intc 11 &cpu0_intc 9>` (context 0 M, context 1 S).
- UART `interrupt-parent = <&plic>`, `interrupts = <10>`.
- Simulator: `Uart` holds an `IrqLine` to `Plic` source 10; `PlicContextLine` wraps a context as an `IrqLineSource`; CPU polls MTIP/MSIP/MEIP/SEIP in `sync_irq_lines()` before `pending_interrupt()`.
- PLIC claim leaves pending set and complete only clears claimed, so a still-asserted level source (UART RX/THRE) re-delivers.

Timer:
- OpenSBI detects extension support by probing CSR reads; `CsrFile::read` returns `Some(0)` for unknown CSRs, so OpenSBI falsely detected `sstc`. It then writes `stimecmp` (0x14D) instead of programming CLINT `mtimecmp`.
- Rendering `stimecmp` as a real CSR and setting `mip.STIP` when `insn_count >= stimecmp` made Linux's timer work. `CLINT mtimecmp` remains `u64::MAX` and is unused on this path.
- `mip` is writable by M-mode for MSIP/SSIP/STIP/SEIP; this is needed if OpenSBI falls back to software STIP injection.

See [[linux-boot-initramfs]].
