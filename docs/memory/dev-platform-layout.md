---
name: dev-platform-layout
description: Final directory layout, instance model and build conventions for rhetsim-dev-platform
metadata:
  node_type: memory
  type: project
---

As of 2026-11-26 the repository `/home/leo/leo/workspace/rhetsim-dev-platform` uses:

- `env/` — declarative inputs: `versions.toml`, `sdk.toml`, `host-deps.toml`,
  `configs/`, `patches/`, and `instances/<name>/`.
- `scripts/` — executable orchestration: fetch, build-*, instance-*, package-sdk,
  publish-sdk, and `tests/`.
- `repos/` — canonical component clones (gitignored); instance `src/` entries are
  git worktrees of these.
- `workspace/` — gitignored: `shared/{toolchain,build,images}`, `dist/`, `locks/`,
  and `instances/<name>/{bin,logs,src,config,run}`.
- Root files: `CLAUDE.md`, `Makefile`, `run.sh`, committed `.claude/skills/<name>/SKILL.md`,
  `docs/memory/`, `sdk/`.
- `./run.sh` is the project command entry (`fetch`, `create`, `build`, `start`,
  `sdk`, `test`, ...); `Makefile` targets are thin aliases. `scripts/` keeps the
  implementations.

Rules:

- Instance definitions are versioned; instance workspaces are disposable.
- Shared artifacts are content-addressed and read-only; instance `bin/` entries link
  to them by default (`--copy` materializes copies). The root filesystem and kernel
  are built at most once per input set, never per instance; `--rootfs prebuilt` uses
  the `initramfs.cpio` committed in `rhetsim-initramfs`.
- The kernel is built **without** an embedded initramfs. The rootfs is an external
  initrd: the simulator loads it into DRAM and writes `linux,initrd-start/end` into
  the DTB `/chosen` node. Rootfs changes do not rebuild the kernel.
- One active run per instance is enforced with `run/lock` (`flock`).
- Never commit `repos/`, `workspace/`, or `.claude/settings.local.json`.
- The Claude project memory directory is symlinked to `docs/memory/`.
- Commits must carry `Signed-off-by: Leo Hou <leohou1402@gmail.com>` and no AI
  attribution.

**Why:** the layout and instance model came out of design discussion and are not
derivable from the scripts alone. The root stays small by grouping declarative
inputs under `env/` and executable logic under `scripts/`.

**How to apply:** keep `env/` declarative, `scripts/` executable and `workspace/`
disposable when adding features. Related: [[dev-platform-architecture]],
[[initramfs-setup]], [[softfloat-busybox-toolchain]], [[jit-perf-tuning]].
