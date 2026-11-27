# toolchain (optional)

Builds the rv64ima/lp64 soft-float musl sysroot and soft-fp libgcc. This is
maintainer tooling, not part of `./run.sh build`.

Required source trees:

- `MUSL_SRC` — musl 1.2.5
- `GCC_SRC` — GCC source containing `libgcc/soft-fp`

They default to `tools/toolchain/src/{musl,gcc}`.

```bash
MUSL_SRC=/path/to/musl-1.2.5 \
GCC_SRC=/path/to/gcc-11.4.0 \
./tools/toolchain/build-toolchain.sh
```

Output:

```text
workspace/shared/toolchain/<abi-id>/sysroot
```

The sysroot is static-only (no `libc.so`) and relocatable; `musl-gcc` generates
its specs at run time. `scripts/package-sdk.sh` includes it when present.
