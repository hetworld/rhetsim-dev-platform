# SDK specification

> Status: planned for a later phase. The current focus is simulator development and
> validation; `package-sdk.sh`/`publish-sdk.sh` are scaffolds.

The SDK is the release contract from `rhetsim-dev-platform` (source/build) to
`rhetsim-software-dev-platform` (binary/system-software development).

## Layout

See `sdk/layout.md`. The bundle contains:

- `bin/rhetsim-cli` — host x86-64 simulator binary.
- `firmware/fw_jump.bin` — OpenSBI.
- `kernel/Image` — Linux kernel; the root filesystem is not embedded.
- `platforms/riscv-virt.toml` + `riscv-virt.dtb` — topology and device tree.
- `rootfs/initramfs.cpio` — BusyBox-based root filesystem, loaded as an external
  initrd via the DTB `/chosen` node (`linux,initrd-start/end`).
- `toolchain/sysroot/` — optional `rv64ima`/`lp64` musl sysroot and `musl-gcc`.
  It is built with the optional maintainer tool `tools/toolchain/build-toolchain.sh`
  (or supplied as a pinned resource), not by the default platform build. The
  sysroot is relocatable: `musl-gcc` resolves its own path and generates a specs
  file at run time, so the SDK can be extracted anywhere.
- `examples/` — at least one consumer example.
- `scripts/run.sh` — convenience launcher.
- `manifest.json` — components, checksums, host requirements, licenses.

## Manifest

Schema: `sdk/manifest.schema.json`.

Required fields: `schema_version`, `name`, `version`, `created`, `instance`,
`artifacts`. Each artifact records its relative path, SHA-256 and size. The
`components` map mirrors `env/versions.toml` (URL, ref, path). The `licenses` map
and `source_availability` text must be preserved for GPL compliance.

## Host requirements

The simulator is currently a dynamically linked x86-64 glibc binary. The manifest
records the build host's glibc version. Options for distribution:

- pin a minimum glibc version and document it;
- ship a statically linked build;
- distribute through an OCI/devcontainer image (recommended for ergonomics).

## SDK scope

Phase 1 scope (recommended):

- fixed kernel `Image` + custom initramfs/user space;
- user-space programs and scripts;
- optionally kernel modules, which require matching kernel headers, `.config` and
  `Module.symvers` in the SDK.

Custom kernels are a later phase; supporting them turns the software platform into
a second build system.

## Distribution

- Never commit large binaries to git.
- Publish tarballs as GitHub Releases and/or OCI images; keep checksums and
  download scripts in the software-dev-platform repository.
- Consumer CI must download a released SDK, build the example, and boot/run it on
  the binary simulator.

## GPL compliance

Linux, BusyBox and OpenSBI have GPL/BSD-style obligations. Every SDK manifest
records exact component URLs and refs. Any release must also provide source access
(e.g. links or a source tarball) alongside the binaries.
