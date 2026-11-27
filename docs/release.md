# Release

> Status: planned for a later phase. The current focus is simulator development and
> validation; the packaging/publish scripts are scaffolds, not an active workstream.

## Versioning

Use semantic versions for SDK bundles (`MAJOR.MINOR.PATCH`), optionally with a
`-dev.N` suffix for pre-releases. A bundle pins exact component commits; the SDK
version identifies the bundle, not the component versions.

## Package

```bash
./run.sh sdk riscv-virt-2hart --version 0.1.0
```

Output:

```text
workspace/dist/rhetsim-sdk-0.1.0/
workspace/dist/rhetsim-sdk-0.1.0.tar.gz
workspace/dist/rhetsim-sdk-0.1.0.tar.gz.sha256
```

`manifest.json` inside the bundle records artifact checksums, component versions,
host requirements, licenses and source-availability text.

## Publish

Dry run (default):

```bash
./run.sh publish --version 0.1.0
```

This prints the `gh release create` command. To actually publish:

```bash
./run.sh publish --version 0.1.0 --execute
```

The target repository defaults to `hetworld/rhetsim-software-dev-platform`; override
with `--repo`.

## Rules

- Never commit `workspace/` or large binaries to git.
- Keep the release contract automated: the dev-platform produces the bundle and
  checksums; the software-dev-platform keeps only version manifests, download
  scripts and examples.
- Tag the dev-platform commit that produced a bundle and reference it in the
  release notes.
- Include GPL source availability information with every release.
- Consumer CI must verify a released bundle end to end before it is announced.

## CI status

GitHub Actions currently runs the repository smoke test only. Packaging and
publishing require a runner with the full build stack; that automation is planned
for P4 (see `docs/roadmap.md`).
