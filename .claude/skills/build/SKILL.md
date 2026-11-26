---
name: build
description: Build a RhetSim instance or individual components (toolchain, simulator, OpenSBI, initramfs, kernel). Use when artifacts are missing, a pinned ref changed, or a build fails.
---

# Build

Build the whole stack for an instance:

```bash
./run.sh build <instance>
```

`./run.sh` is the command entry; the individual scripts below remain the
implementation and are useful for debugging a single stage.

Or run individual stages (each prints its cached artifact path):

```bash
scripts/build-toolchain.sh
scripts/build-simulator.sh
scripts/build-firmware.sh
scripts/build-initramfs.sh --toolchain <toolchain-dir>
scripts/build-kernel.sh --initramfs <cpio> --fragment <fragment>...
```

Artifacts are content-addressed under:

```text
workspace/shared/toolchain/<abi-id>/sysroot
workspace/shared/build/{sim,firmware,initramfs,linux}/<build-id>/
```

Re-running a stage reuses its cache unless the component commit, config, patch or
toolchain changed. `scripts/build-all.sh --instance <name>` orchestrates the full
pipeline and populates the instance `bin/`.

Instances link to shared cache artifacts by default (`--copy` for independent
copies). The root filesystem is built at most once per input set, never per
instance; `--rootfs prebuilt` skips BusyBox and uses the `initramfs.cpio` committed
in `rhetsim-initramfs`. The kernel `Image` embeds the initramfs, so a rootfs change
triggers one kernel rebuild, then the result is cached and shared.

Failure points to check first:

- Toolchain: musl must be configured for `-march=rv64ima -mabi=lp64`; `musl-gcc`
  specs must point at the soft-float `libgcc.a`.
- Kernel: build with `ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu-`; verify
  `CONFIG_INITRAMFS_SOURCE` points at the built cpio.
- Initramfs: BusyBox must be static and built with the sysroot's `musl-gcc`.
- Simulator: `cargo build --release --bin rhetsim-cli` must succeed before boot.

Never edit `repos/`. Put changes in `env/patches/` or an instance worktree.
