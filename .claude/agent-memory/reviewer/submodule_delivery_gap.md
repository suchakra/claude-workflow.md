---
name: submodule-delivery-gap
description: New files under .claude/commands/ are gitignored AND not symlinked by init.sh, so they never reach a consuming project — always check tracking + init.sh wiring for any new consumer-facing artifact
metadata:
  type: feedback
---

Any new artifact meant to ship to consuming projects (commands, skills, agents) must pass a two-part reachability check, because this repo is consumed as a git submodule at `.claude/workflow/`:

1. **Is it in the committed submodule tree?** `.claude/commands/` is gitignored (`.gitignore`: "Local-only slash commands… not for public sharing"). Files there are absent from a consumer's submodule checkout. Verify with `git ls-files <path>` (tracked?) and `git check-ignore <path>` (ignored?).
2. **Does `init.sh` wire it in?** `init.sh` symlinks only `agents/*.md` into the consumer's `.claude/agents/`. It has no loop for commands/skills. An artifact not covered by an init.sh symlink loop never appears in the consuming project even if tracked.

**Why:** caught in the /calibrate skill meta-review (2026-06-01) — the skill was both gitignored and unwired, so it was doubly unreachable by consumers. The brief explicitly flagged this as a DoD item; future briefs may not.

**How to apply:** for any new consumer-facing file, confirm BOTH (tracked in submodule tree) AND (symlinked/imported by init.sh). If gitignored intentionally for one purpose but needed by consumers, the fix is to relocate it out of the ignored path or carve a tracked `.gitignore` exception, plus add the corresponding init.sh wiring.
