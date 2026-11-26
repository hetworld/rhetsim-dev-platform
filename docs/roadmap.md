# Roadmap

| Phase | Status | Goal |
|---|---|---|
| P0 | Done | Repository skeleton, instance model, scripts, Claude assets, reuse-existing boot path |
| P1 | In progress | Fetch + version lock + full toolchain rebuild reproducibility |
| P2 | Planned | Reproducible simulator/firmware/initramfs/kernel builds through the cache |
| P3 | Planned | SDK packaging, consumer example, consumer-side CI |
| P4 | Planned | Release automation, OCI image, sandboxed/parallel instance runs |

## P0 — skeleton (done)

- Final directory layout: `env/`, `scripts/`, `repos/`, `workspace/`, `sdk/`, `docs/`.
- `./run.sh` project command entry (`fetch/create/build/start/sdk/test/...`) with
  thin `make` aliases.
- Instance definition + materialization + per-instance run lock and run IDs.
- Bootstrap via an existing `rhet/` tree (`./run.sh build <instance> --reuse-existing`).
- Project skills, memory base and commit rules committed with the repository.
- Verified: Linux boot to `RHETSIM_INIT_OK`, per-instance lock, SDK package +
  consumer compile, SDK boot, soft-float toolchain rebuild with a relocatable
  sysroot, shared artifact links, `--rootfs prebuilt` (committed cpio, no BusyBox
  rebuild, cached on the second run), and an external-initrd boot with a kernel
  that has no embedded initramfs (no-initrd control panics with "unable to mount
  root fs").

## P1 — sources and toolchain

- [x] Rebuild musl + soft-float libgcc from scratch (`scripts/build-toolchain.sh`);
  the static-only sysroot and relocatable `musl-gcc` are verified (example compile,
  relocated sysroot/SDK compile, SDK boot).
- [ ] Validate `fetch-sources.sh` end to end for all git/tarball components.
- [ ] Replace any remaining manual out-of-repo state with `env/configs` + `env/patches`.

## P2 — full build

- Make every `build-*.sh` stage reproducible and cached by content hash.
- Add instance-specific patches and worktree builds.
- Verify `build-all.sh` boots Linux without `--reuse-existing`.

## P3 — SDK and consumer

- Produce the first SDK bundle with sysroot and kernel config/headers.
- Compile the `sdk/examples/hello` example against the bundle.
- Add consumer-side CI that downloads a released bundle and boots it.

## P4 — release and isolation

- Automate release packaging/publishing with a build runner.
- Provide an OCI/devcontainer image (also solves the simulator's glibc host issue).
- Add per-instance port allocation, tmux consoles, cgroup limits and an optional
  bubblewrap/container sandbox backend.
