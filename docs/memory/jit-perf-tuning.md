---
name: jit-perf-tuning
description: "RISC-V JIT performance work: measured gains, uncommitted state, failed experiment"
metadata:
  node_type: memory
  type: project
  originSessionId: e4bea1a5-f3ee-41f7-9ee4-07224a46e9f9
  modified: 2026-11-26T14:44:16.779Z
---

Boot-to-init benchmark (kernel Image #7 with BusyBox initramfs, 2 harts, ~134M steps, release CLI, JIT on):

| Step | Wall | Note |
|---|---:|---|
| baseline | 78.1s | |
| `sfence.vma` no longer invalidates JIT cache | 53.2s | invalidations 2403→690, compiles 438k→254k |
| Cranelift `opt_level=none` | 37.1s | blocks average ~5.6 guest insns; compile cost dominated |
| IRQ polling every 1024 insns instead of per block | 33.4s | |
| `enable_verifier=false`, `unwind_info=false`, `enable_alias_analysis=false` | **23.6s** | final, ~5.7M steps/s |

Diagnosis came from new stats (`RHETSIM_JIT_STATS=1`, printed on CPU Drop): executions, compiles, invalidations, slow loads/stores, sfence/satp counts.

Changes live in `components/cpu/rhetsim-cpu-riscv/src/cpu.rs` and `jit.rs`, committed on `dev` as `68efa75` (2026-11-26, pushed). The `--no-jit` CLI flag was committed earlier in `8de7816`.

Failed experiment: inlining conditional-branch fall-through into the same native block (to raise the 5.6-insn average block length) made Linux hang in very early boot (only OpenSBI output; PC in `ct_kernel_exit`). It was fully reverted and not root-caused.

Remaining ideas, roughly by value: fix fall-through inlining (maybe another ~30%); tiered compilation (many compiled blocks likely run only once — interpret cold blocks); direct-mapped TB cache instead of HashMap; WFI idle fast-forward (interactive mode burns a host core while the guest is idle).

**Why:** the performance state and the negative result are not in git history yet, and the numbers/variables are easy to lose.
**How to apply:** re-measure with the same benchmark after any JIT change; keep `RHETSIM_JIT_STATS` instrumentation for A/B runs. See [[dev-platform-architecture]] for how these builds feed the planned SDK.
