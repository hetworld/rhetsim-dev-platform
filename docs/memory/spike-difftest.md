# Spike instruction-level difftest

`./run.sh test difftest` runs `tests/spike_difftest.rs` in
`components/cpu/rhetsim-cpu-riscv`. The script builds Spike pinned at
`6e18887745c63f33048e4be3d880c65a72aad0df` into
`workspace/shared/spike/<short-ref>/bin/spike` (the build tree is deleted after
stripping; the cache is ~29 MB) and reuses the riscv-tests ELFs built by
`./run.sh test isa`.

Spike runs each `rv64*-p-*` ELF with `--log-commits`; the interpreter replays
the same image one instruction at a time and compares privilege, PC, raw
instruction, integer/FP register writes and `fflags`/`frm`/`fcsr` writes before
each committed instruction. Trapping instructions are absent from Spike's log
and are consumed as untraced steps; an interrupt is delivered by the same
`exec(1)` call that retires the first handler instruction.

ISA string: `rv64gc_zba_zbb_zbc_zbs_svnapot_smrnmi_zicclsm`.

- `smrnmi`: riscv-tests' reset vector writes `mnstatus`; without the extension
  Spike takes an illegal-instruction trap that skips the write, desynchronising
  the trace.
- `zicclsm`: Spike only executes misaligned data accesses in hardware with
  this extension.

Result: 167/171 tests, 63,592 instructions. The four skips are documented
implementation-defined differences:

- `rv64mi-p-breakpoint`: Spike has no Sdtrig, so its `tcontrol` write traps.
- `rv64mi-p-illegal`: illegal-instruction `mtval` is the instruction word in
  Spike and 0 in RhetSim.
- `rv64mi-p-ma_fetch`: Spike honours `misa` writes that clear C; RhetSim keeps
  `misa` read-only (both are permitted WARL behaviour).
- `rv64mi-p-zicntr`: Spike's `time` CSR does not advance in its default
  configuration, so the test fails under Spike.

The trace found and fixed three differences in rhetsim `ec62842`:
`mstatus.SXL` is read-only 2 on RV64, `misa.B` is set when Zba+Zbb+Zbs are all
implemented, and integer-to-FP `NX` is judged at the destination width
(`fcvt.s.wu 0xFFFFFFFE` rounds to 2^32 with NX set).
