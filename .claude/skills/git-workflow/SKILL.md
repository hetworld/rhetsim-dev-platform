---
name: git-workflow
description: Git branch and pull-request workflow for RhetSim. Use when starting a large rhetsim task, creating a feature branch, preparing commits, or opening a PR.
---

# Git workflow

## Repositories

- `rhetsim`: `dev` is the development/integration base; `main` is the stable line.
- `rhetsim-dev-platform`: use `main` for platform integration.

## Large rhetsim tasks

A large task is a feature, refactor, ISA/CPU-profile addition, device model or
architectural change that spans multiple commits or needs review. Start it from
the latest `dev`, not from another feature branch:

```bash
git fetch origin
git switch dev
git pull --ff-only
git switch -c <task-name>
```

Rules:

- One branch per large task.
- Branch names are task-scoped kebab-case, for example:
  - `jit-parity`
  - `cpu-profiles`
  - `cpu-u74-fd`
  - `cpu-c908`
  - `topology-soc-board-machine`
- Do not stack a new feature on an unmerged feature branch. If work depends on
  another task, merge that task into `dev` first, then branch again from `dev`.
- Small fixes may go directly on `dev`; large or risky changes use a branch.
- Push the task branch and open a PR against `dev`, not `main`.
- CI must run pull-request checks for `dev` as well as `main`.
- After merge, delete the feature branch.

## Commit and pin rules

- Every commit ends with:

  ```text
  Signed-off-by: Leo Hou <leohou1402@gmail.com>
  ```

- Do not add `Co-Authored-By` lines or any AI attribution.
- Never commit `repos/`, `workspace/`, or `.claude/settings.local.json`.
- After a rhetsim change lands on `dev`, update the dev-platform pin with
  `./run.sh pin rhetsim <commit>` and keep `env/versions.toml`'s `branch = "dev"`.
- Run the format/validation checks before committing; see the `build` skill.
