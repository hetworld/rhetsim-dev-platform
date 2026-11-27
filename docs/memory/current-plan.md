# Current plan and progress (2026-11-27)

Completed: P0 (XThead/Smepmp/C908 full profile, FP/bitmanip JIT lowering) and
P1 (JIT/interpreter difftest, riscv-tests compliance 171/171 under both
engines, boot matrix + CI, Spike instruction-level difftest 167/171 with four
documented skips).

State when this note was written: rhetsim local `dev` = `ec62842` (Spike
difftest plus `mstatus.SXL`, `misa.B` and int->FP `NX` fixes); dev-platform
`main` pins `ec62842` and adds `./run.sh test difftest`, a CI step and the
`device-tree-compiler` dependency. `cargo fmt/clippy/test --workspace`, the
171-test ISA run, the Spike difftest and the four-profile boot matrix pass.

Next work:

- **P2 dev-platform platform integration**: let an instance select the U74 or
  C908 platform/DTS (currently the reference `custom` manifest is the default
  and profiles are picked with `RHETSIM_MANIFEST`/`RHETSIM_DTB`).
- **M4**: finalize the custom rhetsim CPU profile (stable ISA subset, name,
  default-platform wiring and documentation).
- **M5**: split simulator platform sources into SoC / Board / Machine layers
  (chip units, buses, interrupt controllers and address map; board devices and
  DTS; machine composition), with declarative manifests.
- **P3 performance**: the JIT is ~3.5x slower than the interpreter on the Linux
  boot (~26-27 s vs ~7.6 s no-JIT). Candidates: fall-through inlining, tiered
  compilation, direct-mapped translation-block cache, WFI idle fast-forward.
  Measure with `./run.sh bench --runs N` and watch the JIT stats.
- Optional: riscv-arch-test integration and a QEMU cross-check (the Spike
  difftest covers this area); the CI cache key currently uses the lock hash, so
  cache hits never refresh the stored cache (a run-id suffix would fix that).
