# Patches

Global patches are applied by the build scripts to the corresponding component
source before building. Keep them minimal and upstreamable.

Naming: `NNNN-short-description.patch`, applied in lexical order.

- `linux/` — kernel changes.

Toolchain/rootfs patches are optional tools under `tools/toolchain/patches/`.
Instance-specific patches live in `env/instances/<name>/patches/` and are applied
only to that instance's worktree.
