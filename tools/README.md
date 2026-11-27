# tools/

Optional maintainer tooling. **Not part of `./run.sh build`.**

The default platform build is:

```text
rhetsim-cli + OpenSBI + Linux + prebuilt rootfs (rhetsim-initramfs)
```

Tooling moved out of the default path:

- `toolchain/` — build the rv64ima/lp64 soft-float musl sysroot. Useful when you
  want the SDK to carry a sysroot or need to rebuild BusyBox.
- `initramfs/` — rebuild the BusyBox cpio. The default platform consumes the
  `initramfs.cpio` committed in `rhetsim-initramfs`.

Keeping these here keeps the platform focused on simulator development while
still allowing maintainers to rebuild the resources when needed.
