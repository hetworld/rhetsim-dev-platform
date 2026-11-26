# Patches

Global patches are applied by the build scripts to the corresponding component
source before building. Keep them minimal and upstreamable.

Naming: `NNNN-short-description.patch`, applied in lexical order.

- `musl/` — musl and musl-gcc specs changes.
- `gcc/` — soft-float libgcc changes.
- `linux/` — kernel changes.

Instance-specific patches live in `env/instances/<name>/patches/` and are applied
only to that instance's worktree.
