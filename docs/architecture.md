# Architecture

`rhetsim-dev-platform` is the source/build domain for RhetSim. It turns pinned
component sources into a reproducible boot stack and SDK bundles. The companion
`rhetsim-software-dev-platform` is the binary domain: it consumes SDK bundles and
does not need simulator source.

## Directory responsibilities

```text
run.sh      single command entry: fetch/create/build/start/sdk/test/...
env/        declarative inputs: versions, configs, patches, instance definitions
scripts/    executable orchestration: fetch, build, instance, package, tests
repos/      canonical component clones and worktree parent (gitignored)
workspace/  instances, shared build cache, logs and release artifacts (gitignored)
sdk/        SDK layout contract, consumer examples and SDK-side scripts
docs/       architecture/build/SDK/release docs and docs/memory/
.claude/    project skills and shared Claude settings
```

`repos/` and `workspace/` are always disposable and never committed.

## Data flow

```text
env/versions.toml ──fetch──▶ repos/
env/instances/<name>/ ──create──▶ workspace/instances/<name>/{config,src}
instance/src + env/configs ──build──▶ workspace/shared/build/<id> ──link──▶ instance/bin
instance/bin + instance/config ──run──▶ instance/logs/<run-id>/ + instance/run/
instance/bin + sdk/ ──package──▶ workspace/dist/rhetsim-sdk-<version>/
```

## Instance model

An instance is a disposable environment with:

- `bin/` — simulator, firmware, kernel, DTB, initramfs.
- `logs/` — per-run UART, simulator and trace logs; `logs/latest` points at the
  most recent run.
- `src/` — optional git worktrees for components that need local changes. The
  canonical clones under `repos/` are the worktree parent.
- `config/` — materialized copy of `env/instances/<name>/`.
- `run/` — persistent disk overlays plus per-run sessions (`state`, `snapshot`,
  `ports.json`, `pid`).

Instance definitions are versioned; instance workspaces are not. You can delete
`workspace/instances/<name>/` at any time and recreate it from the definition.

## Isolation and concurrency

- Shared artifacts live under `workspace/shared/` and are content-addressed and
  read-only after publication. Instance `bin/` entries link to them by default;
  `--copy` materializes independent copies.
- The root filesystem and kernel are shared artifacts: they are built at most once
  per input set, never per instance. `--rootfs prebuilt` can consume the committed
  `initramfs.cpio` without running BusyBox.
- The kernel is built without an embedded initramfs. The rootfs is loaded as an
  external initrd: the simulator places it in DRAM and writes
  `linux,initrd-start/end` into the DTB `/chosen` node, so changing the rootfs does
  not rebuild the kernel.
- Build scripts use a cache key derived from component commit, config, patches
  and toolchain; concurrent identical builds are expected to converge on the same
  immutable entry.
- One active run per instance is enforced with `workspace/instances/<name>/run/lock`
  (`flock`). Different instances can run in parallel.
- Logs and run state are always per-run (`logs/<run-id>/`, `run/sessions/<run-id>/`),
  so parallel instances never share mutable files.
- Future work: per-instance port allocation (`workspace/locks/`), tmux consoles,
  cgroup resource limits, and an optional `--sandbox` (bubblewrap/OCI) backend.

## Build cache

Build entries are named by a short hash of their inputs:

```text
workspace/shared/build/sim/<build-id>/rhetsim-cli
workspace/shared/build/firmware/<build-id>/fw_jump.bin
workspace/shared/build/initramfs/<build-id>/initramfs.cpio
workspace/shared/build/linux/<build-id>/Image
workspace/shared/toolchain/<abi-id>/sysroot
```

`scripts/cache-gc.sh` removes unreferenced entries older than a threshold.
Instances record the build IDs they use in `bin/runtime.manifest.json`, so GC can
avoid deleting anything still in use.

## SDK boundary

The SDK is the release contract between the two repositories. It carries the
simulator binary, firmware, kernel, DTB, initramfs, optional sysroot, examples and
a `manifest.json` with component versions, checksums, host requirements and
license information. See `docs/sdk-spec.md`.
