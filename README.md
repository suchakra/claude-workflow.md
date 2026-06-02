# claude-workflow.md

A workflow engine for Claude Code — defined entirely in natural language.

No Python. No YAML. No framework. The orchestration logic lives in a single markdown file (`CLAUDE.md`) that the Claude Code orchestrator reads and follows at runtime.

---

## What it is

A 5-agent pipeline wired into your Claude Code session via a git submodule. You describe a task; the orchestrator decides how much structure it needs and routes accordingly.

```mermaid
flowchart LR
    U([User]) --> O{Orchestrator<br/>your model}
    O -- Tier 1: trivial --> A1[Direct edit]
    O -- Tier 1: with logic --> EX1["@executor<br/>sonnet"]
    O -- Tier 2: 1-3 inline Qs --> U
    O -- Tier 3: full pipeline --> ID["@idea<br/>haiku"]
    ID --> GR["@groomer<br/>sonnet"]
    GR -- groomed --> EX2["@executor<br/>sonnet"]
    GR -- reject --> AR["@architect<br/>opus"]
    AR -- refined --> EX2
    AR -- bounce --> ID
    EX1 --> RV1["@reviewer<br/>opus"]
    EX2 --> RV2["@reviewer<br/>opus"]
    RV1 -- approved --> U
    RV2 -- approved --> U
    RV1 -- changes --> EX1
    RV2 -- changes --> EX2

    classDef tier1 fill:#cfe,stroke:#080;
    classDef tier3 fill:#fcf,stroke:#808;
    class A1,EX1,RV1 tier1;
    class ID,GR,AR,EX2,RV2 tier3;
```

**Three tiers, five agents, one markdown file.**

| Tier | When | What happens |
|------|------|--------------|
| 1 | Orchestrator is ≥90% confident | Builds directly or hands off to `@executor` — no questions asked |
| 2 | 75–89% confident, 1–2 unknowns | Orchestrator asks up to 3 inline questions, then builds |
| 3 | <75% confident or complex scope | Full pipeline: `@idea` interviews → `@groomer` audits → `@architect` refines → `@executor` builds → `@reviewer` approves |

| Agent | Model | Role |
|-------|-------|------|
| `@idea` | haiku | Requirements interview — one question at a time |
| `@groomer` | sonnet | Gate: is the brief executor-ready? |
| `@architect` | opus | Refines ambiguous briefs or sends targeted questions back |
| `@executor` | sonnet | Builds the artifact |
| `@reviewer` | opus | Code-reviews against the brief; approves or requests changes |

For the full design — cue-parsing rules, loop caps, anti-fabrication enforcement, cross-agent memory — see [`ARCHITECTURE.md`](ARCHITECTURE.md).

---

## Try it

```bash
# 1. Add the submodule
git submodule add https://github.com/suchakra/claude-workflow.md.git .claude/workflow
git submodule update --init

# 2. Wire it into your project (one-time)
bash .claude/workflow/init.sh

# 3. Restart Claude Code — agents load on session start
```

`init.sh` does four things: symlinks the five agents into `.claude/agents/`, symlinks the included slash commands (including `/calibrate`) into `.claude/commands/`, prepends `@.claude/workflow/CLAUDE.md` to your `CLAUDE.md`, and copies the `SessionStart` hooks into `.claude/settings.json` — or warns you to merge them manually if that file already exists.

### Staying current

```bash
git submodule update --remote .claude/workflow
```

---

## Design notes

- **No code** — the routing logic, cue-parsing rules, loop caps, and agent protocols are all in `CLAUDE.md`. If you can read it, you can modify it.
- **Tiered cost** — haiku for interviews, sonnet for building/auditing, opus only where reasoning depth matters (architecture, review). Tier 1 skips the pipeline entirely.
- **Accumulating memory** — each agent has its own memory directory under `.claude/agent-memory/`. Findings from `@reviewer` feed back to `@groomer` via a shared file, so the pipeline improves across sessions.
- **Hard limits** — refinement loop capped at 3 bounces, review loop at 3 cycles. State persisted to disk so limits survive context compaction.
- **No blind sign-off** — a *behavioral* change (runtime, visual, timing, interaction) can't be marked done on code-reading alone. `@groomer` requires the brief to name an executable feedback loop; `@reviewer` refuses to approve a behavioral fix it never observed running. Code looking right is exactly how blind reviews rubber-stamp live bugs.
- **`/calibrate`** — a built-in slash command that reads the telemetry log and reports tier distribution, estimate accuracy, routing signal rate, and threshold recommendations. Run it periodically to check whether the orchestrator's routing judgements are drifting.

---

## What it is not

- A general-purpose agent framework. This is Claude Code-specific: it uses `CLAUDE.md` loading, `.claude/agents/` discovery, and `settings.json` hooks. It does not port to other providers.
- A product. It is a workflow you can adopt, fork, and fix. Bugs go back upstream via the submodule.

---

## Adding your own project rules

This workflow ships **mechanism, not policy.** It has no opinion about your deploy
process, your coding style, or your toolchain — those are yours.

Put project-specific hard rules in **your own** project, not in the submodule:

- Add them to your project's root `CLAUDE.md` (the same file that imports
  `@.claude/workflow/CLAUDE.md`), or to your Claude Code memory.
- **Do not edit files under `.claude/workflow/`.** That is the submodule — your
  changes would be overwritten on `git submodule update --remote`, and they don't
  belong to your project anyway.

The orchestrator honors your rules directly and **embeds the relevant ones into each
`[HAND-OFF BRIEF]`**, so the build/review agents (which never see your project
memory) still obey them. Examples of rules a consumer might write:

- *"Don't introduce numeric literals into CSS/HTML/JS without asking — assets get
  swapped and baked-in numbers go stale."*
- *"This project pins Node via Volta; prefix npm commands accordingly."*

These are illustrations, not defaults — the submodule imposes none of them.
(Git push policy is a first-class mechanism, not a free-text rule — see
**Protected branches** below.)

---

## Protected branches

The orchestrator **commits freely** (no permission needed — commits are local and
reversible) but **asks before pushing to a protected branch**, because a push to a
shared branch often triggers a deploy or CI run.

Which branches are protected is configured by a plain-text file in **your** project:

```
.claude/protected-branches
```

One branch name per line; blank lines and `#` comments are ignored. List every branch
that triggers a deploy or is otherwise protected:

```
# pushing to any of these requires explicit approval
master
main
release
production
```

- Push to a branch **in** the list → the orchestrator asks first.
- Push to any branch **not** in the list → it pushes without asking.
- **File absent →** `main` and `master` are protected by default (safe fallback).
- No shared/deploy branches at all? Leave the file empty — nothing is gated.

Keep this file in your own project, not in `.claude/workflow/`.

### Working branches

For repository/code work, when the interview establishes a **topic** and a **target
branch** (and optionally a tracking ticket), the orchestrator opens a working branch
off the target *before the first commit* — named `<ticket>-<topic>` (e.g.
`PROJ-123-fix-login-redirect`) or `<topic>` if there's no ticket. So work on a
protected target like `main` lands on a feature branch automatically; `main` itself
stays untouched until you approve the push.

---

## Questions and ideas welcome

Open an issue or start a discussion on [GitHub](https://github.com/suchakra/claude-workflow.md). Particularly interested in: how the tier thresholds hold up across different project types, and whether the cue-driven pipeline survives model upgrades.
