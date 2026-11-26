---
name: dev-platform-architecture
description: Planned two-repo RhetSim development/SDK platform architecture and open decisions
metadata:
  node_type: memory
  type: project
  originSessionId: e4bea1a5-f3ee-41f7-9ee4-07224a46e9f9
  modified: 2026-11-26T14:43:06.180Z
---

As of 2026-11-26 two GitHub repos are created but still empty, defining the intended platform split:

- `git@github.com:hetworld/rhetsim-dev-platform.git` — source/build domain: fetch pinned component sources (`rhetsim`, `rhetsim-initramfs`, `opensbi`, `linux-6.1`, soft-float musl/BusyBox toolchain), build toolchain + simulator + firmware + kernel + DTB + initramfs, run tests, package and publish an SDK bundle.
- `git@github.com:hetworld/rhetsim-software-dev-platform.git` — binary domain for low-level system-software development: RhetSim is shipped as a binary (no simulator source); the SDK should carry the simulator, fw/kernel/DTB/rootfs, cross toolchain + sysroot, kernel headers/source, examples and scripts.

My assessment (user asked for an opinion): the split is sound and matches Buildroot/Yocto-style SDK distribution; success depends on engineering discipline, not the repo count. Recommendations:
- Automate the release contract: dev-platform CI produces a versioned bundle + `manifest.json` (component commits, checksums, host requirements) and publishes; never hand-copy artifacts.
- Do not commit large binaries (Image 13MB, initramfs 1.5MB, simulator 7.6MB, sysroot tens of MB) to git; use GitHub Releases/LFS, ideally an OCI/devcontainer image. The simulator is a dynamically linked glibc x86-64 PIE — pin host compatibility or ship static/containerized.
- GPL compliance: Linux/OpenSBI/BusyBox binaries require source availability with exact commits/links in the SDK.
- Decide SDK scope early: fixed Image + userland/initramfs + kernel modules (needs matching headers, `.config`, `Module.symvers`) versus allowing custom kernels.
- Add consumer-side CI that downloads the released SDK, builds a sample, boots it.
- Ship debug facilities (UART log, `--trace`, `--no-jit`, `rhetsim-dbg`) as part of the SDK.
- Keep the software platform thin while the team is small: version manifest + download scripts + examples + docs.

Current gaps to close in dev-platform: the soft-float toolchain is a manual out-of-repo build (see [[softfloat-busybox-toolchain]]); kernel `.config`/`Image` live outside repos (see [[initramfs-setup]]); `run.sh` hardcodes `../opensbi` and `../linux-6.1`; host/distribution story for the simulator binary.

Open questions for the user: artifact distribution method; SDK scope (kernel modules/custom kernel?); toolchain distribution (sysroot only vs full cross toolchain); CI platform and signing.

**Why:** none of this is in git yet; both repos are empty and the decisions were made in conversation.
**How to apply:** use this as the design baseline when bootstrapping `rhetsim-dev-platform` and the first SDK release; confirm the open questions first. Related: [[jit-perf-tuning]].
