---
name: aia-false-detect
description: "RhetSim's CPU had to trap on AIA CSRs because OpenSBI falsely detected SMAIA and broke MSIP/IPI handling"
metadata:
  node_type: memory
  type: project
  originSessionId: 4236ed53-3185-4e87-aa27-d61d2920e880
  modified: 2026-11-26T11:45:14.033Z
---

OpenSBI detects extensions by probing CSR reads. RhetSim's `CsrFile::read` used to return `Some(0)` for unknown CSRs, so OpenSBI falsely detected `smaia`. With SMAIA set, OpenSBI's M-mode trap handler used the AIA path (`sbi_trap_aia_irq`) and read `CSR_MTOPI` (0xfb0); the value was 0, so the MSIP was never processed/cleared by `sbi_ipi_process`. On a 2-hart boot CPU0 then looped forever in the MSIP trap handler while CPU1 sat idle.

**Why:** The AIA MSIP path is silently a no-op on this CPU; the non-AIA path uses `mcause` and calls `sbi_ipi_process`, which clears the IPI.

**How to apply:** `csr.rs` returns `None` for `MTOPI` (0xfb0) and `STOPI` (0xdb0), and the interpreter's CSR instruction now raises an illegal-instruction trap when `read` is `None`. OpenSBI's probe therefore does not enable SMAIA/SSAIA and falls back to `sbi_trap_nonaia_irq`. Do not change unknown-CSR reads back to unconditional 0 without re-testing multi-hart IPIs.

See [[linux-boot-smp]].
