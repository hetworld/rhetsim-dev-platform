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
- [ ] Add instance-specific patches.
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
