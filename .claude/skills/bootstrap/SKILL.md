---
name: bootstrap
description: Set up the RhetSim dev-platform host, fetch pinned component sources, and create the first instance. Use on a fresh checkout, when repos/ is missing, or when a toolchain/kernel rebuild is needed.
---

# Bootstrap

1. Check the host:
   ```bash
   ./run.sh check-host
   ```
   Install anything reported missing before continuing.

2. Fetch pinned sources into `repos/` and verify the lock:
   ```bash
   ./run.sh fetch
   ./run.sh verify-lock
   ```
   Versions and checksums come from `env/versions.toml`; update them only with
   `./run.sh pin`.

3. Create an instance:
   ```bash
   ./run.sh create riscv-virt-2hart
   ```
   This materializes `workspace/instances/<name>/config` and, when `repos/rhetsim`
   exists, a git worktree under `src/rhetsim`.

4. Build or link the boot stack:
   ```bash
   ./run.sh build riscv-virt-2hart
   ```
   During migration, link an existing `rhet/` tree instead:
   ```bash
   ./run.sh build riscv-virt-2hart --reuse-existing /home/leo/leo/workspace/rhet
   ```

5. Verify:
   ```bash
   ./run.sh test boot riscv-virt-2hart
   ```
   Pass criteria: `Linux version` and `RHETSIM_INIT_OK` in the UART log.

Rules:
- Never edit files under `repos/`; use `env/patches/` or the instance worktree.
- Never commit `repos/`, `workspace/` or `.claude/settings.local.json`.
- See `docs/build.md` for host packages and troubleshooting.
