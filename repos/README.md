# repos/

Fetched component sources live here. The directory is **gitignored**; only this
README is tracked.

- Populated by `scripts/fetch-sources.sh` from `env/versions.toml`.
- Do not edit files here. Put changes in `env/patches/` or an instance worktree at
  `workspace/instances/<name>/src/`.
- Instance worktrees are created from these canonical clones with
  `git worktree add --detach`.

Default layout:

```text
repos/
├── rhetsim/
└── software/
    ├── opensbi/
    ├── linux/
    └── rhetsim-initramfs/    # also provides the prebuilt initramfs.cpio
```

Optional toolchain/rootfs sources are not fetched here; see `tools/`.
