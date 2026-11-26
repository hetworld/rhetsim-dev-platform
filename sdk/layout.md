# SDK layout

An SDK bundle is a self-contained target environment for developing low-level
system software without the simulator source:

```text
rhetsim-sdk-<version>/
├── README.md
├── manifest.json          # components, checksums, host requirements, licenses
├── bin/rhetsim-cli        # host x86-64 simulator binary
├── firmware/fw_jump.bin   # OpenSBI
├── kernel/Image           # Linux with embedded initramfs
├── platforms/
│   ├── riscv-virt.toml    # chip topology / manifest
│   └── riscv-virt.dtb
├── rootfs/initramfs.cpio  # embedded root filesystem
├── toolchain/
│   └── sysroot/           # optional rv64ima/lp64 musl sysroot + musl-gcc
├── examples/hello/        # consumer example
└── scripts/run.sh         # convenience launcher
```

## Run

```bash
./scripts/run.sh --batch
```

## Compile

```bash
toolchain/sysroot/bin/musl-gcc -march=rv64ima -mabi=lp64 -static hello.c -o hello
```

## Contract

- `manifest.json` is the source of truth for component versions and artifact
  checksums. Consumers must verify checksums before use.
- GPL/LGPL binaries are distributed with source availability information in
  `manifest.json`; keep that information with the bundle.
- Large binaries are distributed as release assets or OCI layers, never committed
  to the platform repository.
