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

This reads `env/versions.toml` and populates `repos/`:

- git components are cloned and checked out at the pinned commit (detached HEAD);
- tarball components are downloaded, verified against the recorded SHA-256, and
  extracted.

`repos/` is a build cache and a git worktree parent. Do not edit it directly.

## Instance lifecycle

```bash
./run.sh create riscv-virt-2hart
./run.sh build  riscv-virt-2hart
./run.sh start  riscv-virt-2hart
```

- `create` copies `env/instances/<name>/` into
  `workspace/instances/<name>/config/` and optionally creates a git worktree for
  `rhetsim` under `src/`.
- `build` reuses `workspace/shared/build/` and links the artifacts into the
  instance `bin/` by default. Use `--copy` for independent copies.
- During migration, skip a full rebuild by linking an existing `rhet/` tree:

  ```bash
  ./run.sh build riscv-virt-2hart \
      --reuse-existing /home/leo/leo/workspace/rhet
  ```

  This is a bootstrap convenience; it records `reused_from` in
  `bin/runtime.manifest.json`. It copies by default; pass `--link` to point at the
  existing tree instead.
- The underlying implementations remain in `scripts/instance-*.sh`; `./run.sh` is
  the single command entry.

## Shared artifacts and the root filesystem

`./run.sh create` never builds anything; it only materializes config and optional
worktrees. `./run.sh build` computes a content-addressed build ID for each stage
and reuses `workspace/shared/build/` across instances:

- Instance `bin/` entries are symlinks into the shared cache by default. Use
  `--copy` to materialize independent copies for a self-contained instance.
- The root filesystem is built **at most once** per (initramfs commit, BusyBox
  config, toolchain) input set. It is not rebuilt when a new instance is created.
- `--rootfs prebuilt` uses the `initramfs.cpio` committed in
  `rhetsim-initramfs`, skipping BusyBox entirely:

  ```bash
  ./run.sh build riscv-virt-2hart --rootfs prebuilt
  ```

- The kernel `Image` embeds the initramfs at build time, so changing the rootfs
  inputs triggers one kernel rebuild; the resulting `Image` is then cached and
  shared by every instance with the same inputs.
- `./run.sh export` dereferences the symlinks, so an exported instance is
  self-contained.

## Build pipeline

`scripts/build-all.sh --instance <name>` runs, in order:

1. `build-toolchain.sh` — musl 1.2.5 for `rv64ima`/`lp64`, patched musl-gcc specs,
   soft-float `libgcc.a` merged from GCC's soft-fp sources.
2. `build-simulator.sh` — `cargo build --release --bin rhetsim-cli`.
3. `build-firmware.sh` — OpenSBI `fw_jump.bin` for `generic`/RV64.
4. `build-initramfs.sh` — BusyBox + `init.sh` packed with `gen_init_cpio`.
5. `build-kernel.sh` — Linux 6.1 with the instance config and embedded initramfs.

Every stage is cached by a build ID derived from its inputs. Re-running is cheap
unless a pinned commit, config, patch or toolchain changed.

## Important details

- The CPU is `rv64ima` (no F/D), so user space must use the `lp64` soft-float ABI.
  A distro `riscv64-linux-gnu` toolchain defaults to `lp64d` and will fault.
  Always use the sysroot's `musl-gcc` for target programs.
- musl is installed static-only (`make install SHARED_LIBS=`); the sysroot has no
  `libc.so`, matching the static user space. `musl-gcc` generates its specs file
  from `lib/musl-gcc.specs.in` at run time, so sysroots and SDKs are relocatable.
- Kernel `CONFIG_INITRAMFS_SOURCE` is set at build time to the absolute path of the
  built `initramfs.cpio`; never store an absolute path in the committed defconfig.
- Build the kernel with `make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu-`. A bare
  `make` reconfigures the tree for the host architecture.
- The kernel defconfig is a full config captured from the working bring-up, not the
  stale `linux-rv64ima.config` in the simulator repository.

## Cleaning

```bash
./run.sh clean riscv-virt-2hart          # remove bin/logs/run
./run.sh clean riscv-virt-2hart --all    # remove the whole workspace
./run.sh destroy riscv-virt-2hart --yes  # remove workspace + worktrees
./run.sh gc --days 7                     # dry-run shared cache GC
```
