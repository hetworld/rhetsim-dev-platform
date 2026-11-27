# Roadmap

> Current focus: simulator development and validation (P2). SDK/release (P3/P4)
> are planned but not an active workstream.

| Phase | Status | Goal |
|---|---|---|
| P0 | Done | Repository skeleton, instance model, scripts, Claude assets, reuse-existing boot path |
| P1 | Done | Fetch + version lock + optional toolchain/rootfs tooling |
| P2 | In progress | Reproducible simulator/OpenSBI/Linux build + prebuilt rootfs |
| P3 | Planned | SDK packaging, consumer example, consumer-side CI |
| P4 | Planned | Release automation, OCI image, sandboxed/parallel instance runs |
| P5 | In progress (M3 done) | Simulator CPU profiles M1–M4 + SoC / Board / Machine topology M5 |

## P0 — skeleton (done)

- Final directory layout: `env/`, `scripts/`, `tools/`, `repos/`, `workspace/`,
  `sdk/`, `docs/`.
- `./run.sh` project command entry (`fetch/create/build/start/sdk/test/...`) with
  thin `make` aliases.
- Instance definition + materialization + per-instance run lock and run IDs.
- Bootstrap via an existing `rhet/` tree (`./run.sh build <instance> --reuse-existing`).
- Project skills, memory base and commit rules committed with the repository.
- Verified: Linux boot to `RHETSIM_INIT_OK`, per-instance lock, SDK package +
  consumer compile, SDK boot, shared artifact links, a prebuilt rootfs resource from
  `rhetsim-initramfs`, and an external-initrd boot with a kernel that has no embedded
  initramfs (no-initrd control panics with "unable to mount root fs").

## P1 — sources and lock

- [x] Lock file (`env/versions.toml`) with `./run.sh pin` and `./run.sh verify-lock`;
  builds never rewrite the lock.
- [x] Optional toolchain rebuild moved to `tools/toolchain/`; the static-only
  sysroot and relocatable `musl-gcc` are verified (example compile, relocated
  sysroot/SDK compile, SDK boot).
- [x] Validate `fetch-sources.sh` + `verify-lock` end to end for the 4 pinned git
  components.
- [x] Default platform has no manual out-of-repo build state; toolchain and rootfs
  rebuilds are documented optional tools.

## P2 — default build

- Default build: simulator + OpenSBI + Linux + prebuilt rootfs resource.
- Keep each build stage reproducible and cached by content hash.
- [x] Simulator development uses `workspace/instances/<name>/src/rhetsim`; `build-all`
  prefers it and `./run.sh test sim` runs the workspace tests.
- [x] Add global/instance component patches; applied in a temporary worktree and
  included in the component build ID.
- [x] Verified 2026-11-27: `fetch` + `verify-lock` (4 components) → lean `build-all`
  (sim + OpenSBI + Linux + prebuilt rootfs) → instance boot and SDK boot both reach
  `RHETSIM_INIT_OK`.

## P3 — SDK and consumer

- Produce the first SDK bundle with sysroot and kernel config/headers.
- Compile the `sdk/examples/hello` example against the bundle.
- Add consumer-side CI that downloads a released bundle and boots it.

## P4 — release and isolation

- Automate release packaging/publishing with a build runner.
- Provide an OCI/devcontainer image (also solves the simulator's glibc host issue).
- Add per-instance port allocation, tmux consoles, cgroup limits and an optional
  bubblewrap/container sandbox backend.

## P5 — simulator CPU profiles and topology (M1–M5)

- [x] **M1** — CPU profile infrastructure and custom `rhetsim-rv64imac`:
  `RiscvCpuType`/`CpuProfile` with declared vs implemented extensions, `misa`
  derivation, compressed-instruction gating, and DTS/kernel alignment.
- [x] **M2** — SiFive U74 alignment: F/D, Zba/Zbb, Sscofpmf, DTS/kernel config and
  boot tests.
- [x] **M3** — T-Head C908 alignment: F/D, B, CMO/Svinval/Svnapot/Svpbmt, SSTC,
  Sscofpmf, Smepmp, XThead, and optional V; DTS/kernel config and boot tests. The
  base profile and the full profile (Smepmp + XThead) both boot Linux.
- [x] Boot regression matrix for `custom`, U74, C908 base and C908 full with
  golden signatures, interrupt-count checks and an interactive-shell probe
  (`./run.sh test boot-matrix`), plus nightly CI with artifact upload.
- [x] Randomised JIT/interpreter difftest plus a Svnapot page test
  (`components/cpu/rhetsim-cpu-riscv/tests/jit_difftest.rs`).
- [x] riscv-tests compliance run under both engines (`./run.sh test isa`);
  171 p-tests cover integer, M, A, F/D, bitmanip, Svnapot, S- and M-mode CSRs.
  Remaining IEEE FP flag/canonical-NaN gaps are tracked as a known-failure list.
- [x] IEEE FP compliance: exception flags (NV/DZ/OF/UF/NX), canonical NaN
  output, NaN boxing, `fcsr` rounding modes and the integer conversions are
  modelled in the interpreter and JIT; all 171 riscv-tests pass in both
  engines. (RMM ties and non-RNE int->FP rounding remain approximated.)
- [ ] QEMU/Spike instruction-trace difftest (riscv-arch-test integration).
- [ ] **M4** — finalize the custom simulator CPU profile after U74/C908 work:
  stable ISA subset, profile name, default-platform wiring and documentation.
- [ ] **M5** — SoC / Board / Machine topology (last task):
  - Split simulator platform sources into three declarative layers:
    - **SoC** — chip-level units, buses, interrupt controllers, address map and CPU
      profile(s).
    - **Board** — DRAM/flash, external devices, clocks/resets, board DTS.
    - **Machine** — board selection plus firmware, kernel, initrd, DTB and bootargs.
  - Resolve/merge the layers into the single existing flat `Manifest` at load time;
    do not add three runtime topology object types.
  - Keep current flat manifests working as a compatibility path.
  - Validate duplicate unit IDs, address overlaps, dangling bus/IRQ references, and
    SoC CPU profile vs DTS/kernel ISA consistency.
  - Pilot on the existing `riscv-virt` platform, then add K230 (C908) and VisionFive 2
    (U74) compositions.

M5 is intentionally last: it depends on stable CPU profiles, ISA coverage and
device models from M1–M4.
