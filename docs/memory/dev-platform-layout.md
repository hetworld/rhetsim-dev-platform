---
name: dev-platform-layout
description: Final directory layout, instance model and build conventions for rhetsim-dev-platform
metadata:
  node_type: memory
  type: project
---

As of 2026-11-27 the repository `/home/leo/leo/workspace/rhetsim-dev-platform` uses:

- `env/` — declarative inputs: `versions.toml` (4 git components), `sdk.toml`,
  `host-deps.toml`, `configs/{linux,opensbi}`, `patches/linux`, and
  `instances/<name>/`.
- `scripts/` — orchestration for the default platform build: fetch, simulator,
  OpenSBI, Linux, instance, package, tests.
- `tools/` — optional maintainer tooling: `toolchain/` (soft-float sysroot) and
  `initramfs/` (BusyBox rebuild). Not part of `./run.sh build`.
- `repos/` — canonical component clones (gitignored); instance `src/` entries are
  git worktrees of these.
- `workspace/` — gitignored: `shared/{build,resources,toolchain,images}`, `dist/`,
  `locks/`, and `instances/<name>/{bin,logs,src,config,run}`.
- Root files: `CLAUDE.md`, `Makefile`, `run.sh`, committed `.claude/skills/<name>/SKILL.md`,
  `docs/memory/`, `sdk/`.
- `./run.sh` is the project command entry (`fetch`, `create`, `build`, `start`,
  `sdk`, `test`, ...); `Makefile` targets are thin aliases. `scripts/` keeps the
  implementations.

Rules:

- Instance definitions are versioned; instance workspaces are disposable.
- **Default build**: simulator + OpenSBI + Linux + prebuilt rootfs. The rootfs is a
  resource from `rhetsim-initramfs`; the platform does not build it. OpenSBI and
  Linux are built locally so simulator and software can be debugged in sync.
- Shared artifacts are content-addressed and read-only; instance `bin/` entries link
  to them by default (`--copy` materializes copies). The rootfs resource lives in
  `workspace/shared/resources/initramfs/<id>/`.
- The kernel is built **without** an embedded initramfs. The rootfs is an external
  initrd: the simulator loads it into DRAM and writes `linux,initrd-start/end` into
  the DTB `/chosen` node. Rootfs changes do not rebuild the kernel.
- Toolchain and rootfs rebuilds are optional maintainer tools under `tools/`; keep
  them out of the default `./run.sh build` path.
- Simulator development uses `workspace/instances/<name>/src/rhetsim`; `build-all`
  prefers it and `./run.sh test sim` runs the workspace tests. Current focus is
  simulator development/validation; SDK/release is planned.
- Component patches: global `env/patches/<component>/`, instance
  `env/instances/<name>/patches/<component>/`; applied in a temporary git worktree
  at the pinned commit and hashed into the component build ID. `repos/` stays clean.
- One active run per instance is enforced with `run/lock` (`flock`).
- Never commit `repos/`, `workspace/`, or `.claude/settings.local.json`.
- `env/versions.toml` is a committed lock file: builds only read it. Update pins
  with `./run.sh pin`; verify fetched sources with `./run.sh verify-lock`.
- The Claude project memory directory is symlinked to `docs/memory/`.
- Commits must carry `Signed-off-by: Leo Hou <leohou1402@gmail.com>` and no AI
  attribution.
- Verified 2026-11-27: `fetch` + `verify-lock` (4 components) → lean build (sim +
  OpenSBI + Linux + prebuilt rootfs) → instance boot and SDK boot to
  `RHETSIM_INIT_OK`; optional tools under `tools/` remain separate.

**Why:** the layout and instance model came out of design discussion and are not
derivable from the scripts alone. The root stays small by grouping declarative
inputs under `env/` and executable logic under `scripts/`.

**How to apply:** keep `env/` declarative, `scripts/` executable and `workspace/`
disposable when adding features. Related: [[dev-platform-architecture]],
[[initramfs-setup]], [[softfloat-busybox-toolchain]], [[jit-perf-tuning]].
