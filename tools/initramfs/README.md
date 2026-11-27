# initramfs (optional)

Rebuilds the BusyBox initramfs. This is maintainer tooling, not part of
`./run.sh build`; the default platform consumes the `initramfs.cpio` committed in
`rhetsim-initramfs`.

Required:

- `BUSYBOX_SRC` — BusyBox source tree (default `tools/initramfs/src/busybox`)
- `KERNEL_SRC` — Linux source for `usr/gen_init_cpio.c`
- A toolchain in `workspace/shared/toolchain/` (see `tools/toolchain/`) or
  `--toolchain DIR`

```bash
BUSYBOX_SRC=/path/to/busybox-1.36.1 \
./tools/initramfs/build-initramfs.sh --toolchain workspace/shared/toolchain/<abi-id>
```

`--prebuilt` copies the committed cpio without running BusyBox.
