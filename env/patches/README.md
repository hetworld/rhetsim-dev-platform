# Patches

Component patches are applied to a temporary git worktree at the pinned commit,
so `repos/` stays clean and instances can build concurrently.

Two layers, applied in order:

1. Global: `env/patches/<component>/*.patch` — every instance.
2. Instance: `env/instances/<name>/patches/<component>/*.patch` — that instance
   only.

Components are `rhetsim`, `opensbi` and `linux`. Create the component directory
when you add the first patch. Naming: `NNNN-short-description.patch`; files are
applied in lexical order within a directory.

The ordered patch set is hashed into the component build ID, so changing a patch
rebuilds that component (and reuses the cache for the others). A component
source worktree with uncommitted tracked changes cannot be combined with
patches: commit or stash first. Toolchain/rootfs patches are optional tools
under `tools/toolchain/patches/`.
