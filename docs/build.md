# Building

## Host prerequisites

Run:

```bash
./run.sh check-host
```

Required: `git`, `make`, `gcc`, `bison`, `flex`, `bc`, `python3` (3.8+), Rust
(`cargo`, `rustc` 1.75+), `flock`, `cpio`, `file`, `sha256sum`, `tar`, `curl`,
and the RISC-V cross toolchain (`riscv64-linux-gnu-{gcc,ar,objcopy,nm}`).

On Ubuntu 22.04 the cross toolchain comes from `gcc-riscv64-linux-gnu` and
`binutils-riscv64-linux-gnu`.

## Fetch sources

```bash
./run.sh fetch
```

This reads `env/versions.toml` and populates `repos/` with the pinned simulator,
OpenSBI, Linux and initramfs sources. Git components are cloned and checked out at
the pinned commit (detached HEAD). The lock format also supports tarball resources
(download + SHA-256 + extract), but the default platform does not use any.

`repos/` is a build cache and a git worktree parent. Do not edit it directly.

## Lock file

`env/versions.toml` is a committed lock file; builds only read it.

- Update a git component pin:
  ```bash
  ./run.sh pin <component> <commit-or-branch>
  ./run.sh pin rhetsim dev --from-local /home/leo/leo/workspace/rhet/rhetsim
  ```
  `--from-local` resolves the ref from a checkout (default `HEAD`), which is useful
  right after committing a component.
- Update a tarball SHA-256 (when a resource component uses a tarball):
  ```bash
  ./run.sh pin <component> --file <archive>
  ```
- Verify the fetched sources against the lock:
  ```bash
  ./run.sh verify-lock
  ```
  It checks git HEAD/commit/clean state and tarball checksums. Run it in CI after
  `fetch`.

## Instance lifecycle

```bash
./run.sh create riscv-virt-2hart
./run.sh build  riscv-virt-2hart
./run.sh start  riscv-virt-2hart
```

- `create` copies `env/instances/<name>/` into
  `workspace/instances/<name>/config/` and creates a `rhetsim` git worktree under
  `src/` when `repos/rhetsim` is available.
- `build` builds the simulator from `workspace/instances/<name>/src/rhetsim` when
  present (falling back to `repos/rhetsim`), builds OpenSBI/Linux from `repos/`,
  and links all artifacts into the instance `bin/` by default. Use `--copy` for
  independent copies.
- During migration, skip a full rebuild by linking an existing `rhet/` tree:

  ```bash
  ./run.sh build riscv-virt-2hart \
      --reuse-existing /home/leo/leo/workspace/rhet
  ```

  This is a bootstrap convenience; it records `reused_from` in
  `bin/runtime.manifest.json`. It copies by default; pass `--link` to point at the
  existing tree instead. It consumes the legacy tree as-is, so an old
  embedded-initramfs kernel stays embedded; use `./run.sh build` for the
  external-initrd layout.
- The underlying implementations remain in `scripts/instance-*.sh`; `./run.sh` is
  the single command entry.

Simulator validation:

```bash
./run.sh test sim                              # cargo test --workspace in src/rhetsim
./run.sh test boot riscv-virt-2hart -- --no-jit # boot test with simulator flags
./run.sh bench --runs 3                        # boot wall time + JIT counters
```

`test sim` uses the instance worktree when present. The rhetsim `linux_boot`
integration test skips when its sibling firmware/kernel artifacts are absent; use
`test boot` for the platform-level boot check.

`bench` runs the boot to `RHETSIM_INIT_OK` with `RHETSIM_JIT_STATS=1`, printing
per-run wall time, guest steps, steps/s and the hart-0 JIT counters. Use
`--no-jit` for an interpreter A/B baseline.

## Shared artifacts and the root filesystem

`./run.sh create` never builds anything; it only materializes config and optional
worktrees. `./run.sh build` builds the simulator, OpenSBI and Linux, reusing
content-addressed artifacts under `workspace/shared/build/`, then assembles the
prebuilt rootfs:

- Instance `bin/` entries are symlinks into the shared cache by default. Use
  `--copy` to materialize independent copies for a self-contained instance.
- The root filesystem is a **prebuilt resource** from `rhetsim-initramfs`
  (`initramfs.cpio` at the pinned commit). The default build does not run BusyBox
  or `gen_init_cpio`; rebuilds are optional maintainer tools under `tools/initramfs/`.
- The rootfs is copied into `workspace/shared/resources/initramfs/<id>/` so every
  instance with the same input shares it.
- The kernel is built **without** an embedded initramfs. The rootfs is an external
  initrd: `instance-run.sh` passes `--initrd`, and the simulator writes
  `linux,initrd-start/end` into the DTB `/chosen` node. Changing the rootfs does not
  rebuild the kernel; the kernel and rootfs are independent artifacts.
- `./run.sh export` dereferences the symlinks, so an exported instance is
  self-contained.

## Build pipeline

`scripts/build-all.sh --instance <name>` runs, in order:

1. `build-simulator.sh` — `cargo build --release --bin rhetsim-cli`.
2. `build-firmware.sh` — OpenSBI `fw_jump.bin` for `generic`/RV64.
3. `build-kernel.sh` — Linux 6.1 with the instance config, no embedded initramfs.
4. Rootfs — copy the pinned/prebuilt `initramfs.cpio` from `rhetsim-initramfs`
   into the shared resource cache; no BusyBox build.

Every build stage is cached by a build ID derived from its inputs. Re-running is
cheap unless a pinned commit, config or patch changed.

## Patches

Component patches are applied without touching `repos/`:

- Global patches: `env/patches/<component>/*.patch` (all instances).
- Instance patches: `env/instances/<name>/patches/<component>/*.patch` (one
  instance).

`<component>` is `rhetsim`, `opensbi` or `linux`. Patches are named
`NNNN-short-description.patch` and applied in lexical order, global layer first.
The build scripts create a temporary git worktree at the pinned commit, apply
the patches there, build, and remove the worktree. The ordered patch set is
included in the component build ID, so only that component rebuilds when a patch
changes.

Patches cannot be combined with uncommitted tracked changes in the component
source worktree; commit or stash them first. Instance patches are copied into
`workspace/instances/<name>/config/patches/` by `./run.sh create`/`update` and
refreshed from the definition by `./run.sh update`.

Optional maintainer tools (not part of `./run.sh build`):

- `tools/toolchain/build-toolchain.sh` — soft-float musl sysroot (for an SDK that
  should carry a toolchain).
- `tools/initramfs/build-initramfs.sh` — rebuild BusyBox/initramfs from source.

## Important details

- The CPU is `rv64ima` (no F/D), so user space must use the `lp64` soft-float ABI.
  A distro `riscv64-linux-gnu` toolchain defaults to `lp64d` and will fault.
  Always use the sysroot's `musl-gcc` for target programs.
- The optional sysroot built by `tools/toolchain/` is static-only
  (`make install SHARED_LIBS=`); it has no `libc.so`, matching the static user
  space. `musl-gcc` generates its specs file from `lib/musl-gcc.specs.in` at run
  time, so sysroots and SDKs are relocatable.
- The kernel is built **without** an embedded initramfs. `CONFIG_INITRAMFS_SOURCE`
  stays empty; `instance-run.sh` passes the rootfs via `--initrd`, and the simulator
  writes `linux,initrd-start/end` into the DTB `/chosen` node.
- Kernel builds are out-of-tree (`make O=...`), which requires a clean source tree
  (no in-tree `.config`). Use a clean clone or a detached `git worktree`; the build
  script rejects a source tree that already has `.config`.
- Build the kernel with `make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu-`. A bare
  `make` reconfigures the tree for the host architecture.
- The kernel defconfig is a full config captured from the working bring-up, not the
  stale `linux-rv64ima.config` in the simulator repository. Fragments are merged with
  the kernel's `scripts/kconfig/merge_config.sh`, so they can override defconfig
  values without duplicate-symbol `override: reassigning` warnings.

## Cleaning

```bash
./run.sh clean riscv-virt-2hart          # remove bin/logs/run
./run.sh clean riscv-virt-2hart --all    # remove the whole workspace
./run.sh destroy riscv-virt-2hart --yes  # remove workspace + worktrees
./run.sh gc --days 7                     # dry-run shared cache GC
```
