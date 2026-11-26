# RhetSim Dev Platform

Source/build domain for [RhetSim](https://github.com/hetworld/rhetsim): fetch pinned
component sources, build the cross toolchain, simulator, firmware, kernel and
initramfs, run isolated instances, and package SDK bundles for
`rhetsim-software-dev-platform`.

> **Status: P0 complete.** The instance lifecycle, per-instance locking, Linux
> boot, SDK packaging and the soft-float toolchain rebuild are verified. The
> remaining simulator/firmware/initramfs/kernel pipeline is being validated (P2);
> during migration an instance can link an existing `rhet/` build tree with
> `./run.sh build <instance> --reuse-existing`.

## Layout

```text
env/        declarative environment definitions (versions, configs, patches, instances)
scripts/    executable orchestration (build, instance, package, tests)
repos/      fetched component sources (gitignored; worktree parent)
workspace/  instances and build artifacts (gitignored)
sdk/        SDK contract, examples and consumer scripts
docs/       architecture/build/SDK/release docs and docs/memory/
.claude/    project skills and shared Claude settings
```

`env/` is the only place where build inputs are defined. `scripts/` turns those
definitions into artifacts under `workspace/`. Nothing under `repos/` or
`workspace/` is ever committed.

## Quick start

```bash
./run.sh check-host
./run.sh fetch
./run.sh create riscv-virt-2hart
./run.sh build riscv-virt-2hart
./run.sh start riscv-virt-2hart
```

During migration, reuse an existing build tree instead of rebuilding everything:

```bash
./run.sh create riscv-virt-2hart
./run.sh build riscv-virt-2hart --reuse-existing /home/leo/leo/workspace/rhet
./run.sh start riscv-virt-2hart --batch
```

`--reuse-existing` consumes the old tree as-is (including an embedded-initramfs
kernel); use `./run.sh build` for the external-initrd layout.

`./run.sh help` lists all commands. `make` targets are thin aliases. The default
instance is `riscv-virt-2hart`.

## Instance model

Each instance is a disposable, self-contained environment:

```text
workspace/instances/<name>/
├── bin/      simulator, firmware, kernel, DTB, initramfs
├── logs/     per-run UART/sim/trace logs (logs/latest points at the last run)
├── src/      optional git worktrees for components you modify
├── config/   materialized from env/instances/<name>/
└── run/      persistent disk overlays and per-run state
```

- Instance definitions are versioned in `env/instances/<name>/`.
- One active run per instance is enforced with `run/lock`; different instances
  can run in parallel.
- Expensive artifacts are shared, content-addressed and read-only under
  `workspace/shared/`; instance `bin/` entries link to them by default. The root
  filesystem is built at most once per input set, not per instance; use
  `./run.sh build <name> --rootfs prebuilt` to consume the committed
  `initramfs.cpio` directly, or `--copy` to materialize copies.
- The kernel does not embed the root filesystem. The rootfs is loaded as an external
  initrd via the simulator's `--initrd`; changing it does not rebuild the kernel.

## Build and run

- `./run.sh build <name>` builds or links the boot stack.
- `./run.sh start <name>` starts the simulator interactively.
- `./run.sh start <name> --batch` runs non-interactively and writes
  `workspace/instances/<name>/logs/<run-id>/uart.log`.
- `./run.sh test boot <name>` boots Linux and asserts the `RHETSIM_INIT_OK` marker.

Details: [docs/build.md](docs/build.md), [docs/architecture.md](docs/architecture.md).

## SDK

`./run.sh sdk <name> --version <ver>` produces `workspace/dist/rhetsim-sdk-<ver>/`,
a tarball and checksums. The SDK carries the
simulator binary, firmware, kernel, DTB, initramfs, sysroot/toolchain, examples
and consumer scripts. See [sdk/layout.md](sdk/layout.md) and
[docs/sdk-spec.md](docs/sdk-spec.md).

Never commit large binaries to git: release them through GitHub Releases, an OCI
image, or the software-dev-platform's download scripts.

## Claude assets

- Commit rules and working boundaries: [CLAUDE.md](CLAUDE.md).
- Project skills: `.claude/skills/` (`bootstrap`, `build`, `run-debug`, `release`,
  `memory-sync`).
- Project knowledge base: [docs/memory/MEMORY.md](docs/memory/MEMORY.md).

The local Claude memory directory is symlinked to `docs/memory/`, so memory
updates are versioned with the repository.

## License

Apache-2.0. Copyright 2026 OpenFunTech.
