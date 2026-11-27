---
name: build
description: Build a RhetSim instance or individual components (simulator, OpenSBI, Linux), and validate Rust changes. Use when artifacts are missing, a pinned ref changed, a build fails, or simulator Rust code was modified. The rootfs is a prebuilt resource; toolchain/initramfs rebuilds are optional tools.
---

# Build

Build the default boot stack for an instance:

```bash
./run.sh build <instance>
```

`./run.sh` is the command entry; the individual scripts below remain the
implementation and are useful for debugging a single stage.

Default stages (each prints its cached artifact path):

```bash
scripts/build-simulator.sh
scripts/build-firmware.sh
scripts/build-kernel.sh --fragment <fragment>...
```

Artifacts are content-addressed under:

```text
workspace/shared/build/{sim,firmware,linux}/<build-id>/
workspace/shared/resources/initramfs/<id>/initramfs.cpio
workspace/shared/toolchain/<abi-id>/sysroot       # optional tools/toolchain
```

Re-running a stage reuses its cache unless the component commit, config, patch or
host compiler changed. `scripts/build-all.sh --instance <name>` orchestrates the
default pipeline and populates the instance `bin/`.

Instances link to shared cache artifacts by default (`--copy` for independent
copies). The root filesystem is a **prebuilt resource** from `rhetsim-initramfs`;
the default build copies it into the resource cache and does not run BusyBox. Use
`tools/initramfs/build-initramfs.sh` only when you need to rebuild it. The kernel
is built **without** an embedded initramfs; the rootfs is passed as an external
initrd (`rhetsim-cli --initrd`, with `linux,initrd-start/end` in the DTB `/chosen`
node), so a rootfs change does not rebuild the kernel.

Simulator development: `build-all` prefers
`workspace/instances/<name>/src/rhetsim` when the worktree exists. Run the
simulator tests with `./run.sh test sim`, and pass debug flags to the boot test
after `--`, e.g. `./run.sh test boot <name> -- --no-jit`.

## Mandatory formatting check after code changes

After every change to Rust code, run this from the simulator worktree before
building, testing or committing:

```bash
cd workspace/instances/<name>/src/rhetsim
cargo fmt --all -- --check
```

If the check fails:

```bash
cargo fmt --all
cargo fmt --all -- --check
```

Include the formatting in the same change; never commit or push unformatted Rust.
This is exactly the CI "Format check" step (`cargo fmt --all -- --check`), so do
not rely on CI to catch it. For a complete validation pass, follow with:

```bash
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace
```

Optional maintainer tools (not part of `./run.sh build`):

```bash
tools/toolchain/build-toolchain.sh     # soft-float sysroot for the SDK
tools/initramfs/build-initramfs.sh     # rebuild BusyBox/cpio
```

Failure points to check first:

- Kernel: build with `ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu-`; keep
  `CONFIG_INITRAMFS_SOURCE=""` and rely on the external initrd.
- Simulator: `cargo build --release --bin rhetsim-cli` must succeed before boot.
- Rootfs: the pinned `initramfs.cpio` must exist in `rhetsim-initramfs`; rebuild it
  with `tools/initramfs` only if you changed BusyBox/init.sh.
- Toolchain (optional): musl configured for `-march=rv64ima -mabi=lp64`; `musl-gcc`
  specs point at the soft-float `libgcc.a`.

Never edit `repos/`. Put changes in `env/patches/<component>/` (global),
`env/instances/<name>/patches/<component>/` (instance), or an instance worktree.
Patches build in a temporary worktree and are part of the component build ID.
