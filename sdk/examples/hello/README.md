# Hello example

Cross-compile a static rv64ima/lp64 program against the SDK's sysroot:

```bash
make SDK_ROOT=/path/to/rhetsim-sdk-<version>
```

Run it inside the simulated Linux guest by placing the binary in your initramfs
or a disk image. The example only validates the toolchain and ABI.
