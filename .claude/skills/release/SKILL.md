---
name: release
description: Package and publish a RhetSim SDK bundle with checksums and a manifest. Use when producing a release for rhet-sim-software-dev-platform or validating the release contract.
---

# Release

1. Ensure the instance is built and the boot test passes:
   ```bash
   ./run.sh test boot <name>
   ```

2. Package:
   ```bash
   ./run.sh sdk <name> --version <version>
   ```
   Output: `workspace/dist/rhetsim-sdk-<version>/`, a `.tar.gz` and `.sha256`.

3. Inspect the bundle:
   ```bash
   python3 -m json.tool workspace/dist/rhetsim-sdk-<version>/manifest.json
   ./run.sh test consumer --require
   ```

4. Publish (dry run first):
   ```bash
   ./run.sh publish --version <version>
   ./run.sh publish --version <version> --execute
   ```
   The target defaults to `hetworld/rhetsim-software-dev-platform`.

Rules:
- Never commit large binaries or `workspace/` to git.
- Keep `manifest.json` (components, checksums, host glibc, licenses) with the
  bundle; it is the release contract.
- Include GPL source-availability information for Linux/BusyBox.
- Tag the dev-platform commit that produced the bundle.
- Consumer CI must download the released bundle, compile the example and boot it
  before announcing the release.
