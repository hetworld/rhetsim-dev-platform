---
name: memory-sync
description: Keep the project knowledge base in docs/memory/ consistent with the Claude memory directory and MEMORY.md index. Use when a durable decision, non-obvious build fact, or debugging lesson should survive the session.
---

# Memory sync

Canonical location: `docs/memory/` (versioned with the repo). The local Claude
memory directory is symlinked to it:

```text
~/.claude/projects/-home-leo-leo-workspace-rhetsim-dev-platform/memory -> <repo>/docs/memory
```

When recording a fact:

1. One fact per file, with frontmatter:
   ```markdown
   ---
   name: short-kebab-slug
   description: one-line summary
   metadata:
     type: project | reference | feedback | user
   ---
   ```
2. Add one line to `docs/memory/MEMORY.md`:
   `- [Title](file.md) — hook`
3. Link related memories with `[[name]]`.
4. Do not duplicate what the repo already records (directory layout, build steps,
   git history, CLAUDE.md rules). Save the *why* and the non-obvious facts.
5. If a memory is wrong or stale, update or delete it rather than adding another.

Do not write secrets, credentials or absolute machine-specific paths that should
not be published unless the repository is private.
