---
name: run-debug
description: Run a RhetSim instance, capture logs, and debug boot failures (JIT, interrupts, PLIC, UART, SMP). Use for interactive runs, batch boots, traces and boot-marker checks.
---

# Run and debug

Interactive:

```bash
./run.sh start <name>
./run.sh console <name>     # tmux session when available
```

Batch (logs under `workspace/instances/<name>/logs/<run-id>/`):

```bash
./run.sh start <name> --batch --steps 200000000
tail -f workspace/instances/<name>/logs/latest/uart.log
```

Boot test:

```bash
./run.sh test boot <name>
./run.sh test boot <name> -- --no-jit       # simulator flags after --
./run.sh test sim                            # cargo test --workspace in src/rhetsim
```

Pass criteria: `Linux version` and `RHETSIM_INIT_OK` appear in `uart.log`.

Useful simulator flags:

- `--no-jit` — interpreter only; use to separate JIT bugs from emulation bugs.
- `--trace exec,int,plic,clint,uart --trace-file <path>` — execution tracing.
- `--log-level debug` / `--log-file <path>` — simulator logs (separate from UART).
- `RHETSIM_JIT_STATS=1` — JIT statistics.
- `--batch --steps N` — non-interactive run; exits after N steps.

Concurrency: one active run per instance (`run/lock`). Use `--wait` to block or
`--no-lock` only when you know what you are doing; different instances can run in
parallel.

Common failures (see `docs/memory/`):

- `RHETSIM_INIT_OK` missing and interrupts look wrong → check PLIC/SSTC wiring and
  the AIA false-detection note.
- User-space trap with illegal instruction → the binary is probably `lp64d`;
  rebuild with the soft-float `musl-gcc`.
- Kernel does not see the initramfs → `CONFIG_INITRAMFS_SOURCE` is empty or points
  at the wrong cpio.
- SMP boot hangs → check `CONFIG_SMP`, `NR_CPUS` and per-hart CLINT/PLIC state.

To stop an interactive guest, run `poweroff` inside the guest.
