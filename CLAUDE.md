# RhetSim Dev Platform - Project Guidelines

## Git Commits

- All commits must include a `Signed-off-by` trailer:
  ```
  Signed-off-by: Leo Hou <leohou1402@gmail.com>
  ```
- Do **not** add any `Co-Authored-By` lines referencing Claude or any AI model in
  commit messages or PR descriptions. No AI attribution of any kind.

## Directory boundaries

- `env/` — declarative environment definitions: versions, configs, patches, instances.
- `scripts/` — executable orchestration for the default platform build.
- `tools/` — optional maintainer tooling (toolchain/initramfs rebuilds); not part
  of `./run.sh build`.
- `repos/` — fetched component sources and worktree parent (gitignored, never commit).
- `workspace/` — instances and build artifacts (gitignored, never commit).
- `sdk/` — SDK layout contract, consumer examples and SDK-side scripts.
- `docs/` — architecture/build/SDK/release docs plus `docs/memory/` knowledge base.

## Working rules

- Never edit files under `repos/`. Put changes in `env/patches/` or in the instance
  worktree at `workspace/instances/<name>/src/`.
- Never commit `repos/`, `workspace/`, or `.claude/settings.local.json`.
- `env/versions.toml` is a lock file: builds only read it. Update pins with
  `./run.sh pin`, verify fetched sources with `./run.sh verify-lock`.
- `./run.sh` is the project command entry (`fetch`, `create`, `build`, `start`,
  `sdk`, `test`, ...); `./run.sh start <name>` launches the simulator. `make help`
  lists the thin aliases.
- Prefer the project skills in `.claude/skills/` for build, run/debug, release and
  memory workflows. They are thin playbooks; the real logic is in `scripts/`.
- When historical context matters, read `docs/memory/MEMORY.md` first.
