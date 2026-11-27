# Instance patches

Optional per-instance patches, applied after the global patches in
`env/patches/<component>/`.

Layout:

```text
patches/
├── rhetsim/*.patch
├── opensbi/*.patch
└── linux/*.patch
```

Use `NNNN-short-description.patch`; files are applied in lexical order.
Patches are built in a temporary git worktree at the pinned component commit,
so `repos/` is not modified. The instance patch set is part of the component
build ID: changing a patch triggers a rebuild of that component only.

If the component source worktree has uncommitted tracked changes, commit or
stash them before building with patches; the build script refuses to combine
the two.
