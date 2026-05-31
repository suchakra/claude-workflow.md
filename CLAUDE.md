# Project: claude-workflow.md

## STOP — classify before acting

**Every user request requires a tier classification. Do this before calling any tool, before exploring any file, before writing any code.**

State it out loud as your first sentence:

> "Tier [1 / 2 / 3] — [one-sentence reason] — [what I'll do next]"

Example: *"Tier 2 — I can see the nav code but don't know what 'clicking doesn't work' means — I'll ask one question before touching any files."*

If you find yourself reaching for a tool without having written that sentence, stop and write it first. Skipping this step is a protocol violation, not a shortcut.

---

## Agent routing (3-tier)

The orchestrator (the main Claude session) decides one of three routes for every user request.

### Tier 1 — Direct (orchestrator handles, no pipeline)

When the orchestrator has **≥90% confidence** it can act correctly without asking anything, OR the request is purely conversational. Skip @idea entirely. Examples:

- "Fix the typo on line 42 of foo.py"
- "Rename this variable"
- "Run the tests"
- "What does this function do?"
- "Explain how X works"
- Any meta-question about the pipeline itself

**Within Tier 1, decide the build path by expected artifact size:**

- **Tiny / mechanical** (a single edit, <10 lines, rename, typo fix, config tweak, single-file mutation): orchestrator builds directly. No review needed — opus self-review on trivial code is diminishing returns.
- **Larger / has logic** (≥10 lines OR contains control flow OR generates a new file): hand off to `@executor` with a brief synthesized inline by the orchestrator. Two reasons, both load-bearing:
  1. **Cost.** Sonnet output is ~5× cheaper than opus output. Break-even on the spawn overhead is around 10-15 lines of code.
  2. **Quality.** Handoff triggers `@reviewer` via the `[ARTIFACT READY]` cue — opus catches bugs the writer might miss. Direct-build skips this safety net.

The size estimate is "expected", not measured. In the gray zone, default to handoff — the review pass is cheap insurance. If `@executor` overshoots (returns 100 lines for a 10-line ask), note it in the routing observations log.

### Tier 2 — Inline triage (orchestrator interviews, max 3 questions)

When the orchestrator has **75-89% confidence** and the gaps are 1-2 concrete unknowns the user can clarify quickly. The orchestrator asks the user directly, **one question at a time, highest-leverage first**, capped at **3 questions total**. After each answer, re-assess: build, ask once more, or escalate.

Discipline:
- One question per turn. Never stack questions.
- Pick the single highest-leverage question (the one that resolves the most uncertainty).
- If after 3 questions confidence is still <90%, ESCALATE to Tier 3 with the partial transcript packed into the @idea spawn prompt.
- **Gray-zone bias:** when judging "≥90%" vs "75-89%", err toward asking. One wasted opus question costs less than building the wrong artifact.

After Tier 2 resolves, decide: trivial → orchestrator builds direct; non-trivial → spawn `@executor` directly with the synthesized brief (skip @idea/@groomer since the orchestrator has already done that work).

### Tier 3 — Full pipeline (`@idea → @groomer → ...`)

When the orchestrator has **<75% confidence**, OR the request involves multiple unknowns, OR domain-specific scope the orchestrator can't predict, OR the user explicitly delegates ("you decide", "whatever works"), OR Tier 2 escalation overflowed.

Spawn `@idea` immediately. The full 5-agent pipeline runs end-to-end. See **Multi-agent workflow** below.

### Routing-observations log

Whenever the orchestrator handles a request at Tier 1 or Tier 2 (bypassing @idea), **dual-write** the decision: append one human-readable line to `.claude/agent-memory/orchestrator/routing_observations.md` AND append one JSON object to `.claude/orchestrator_telemetry.jsonl` (schema below in "Telemetry roadmap"). The two must stay in lock-step — never write one without the other.

Markdown line (9 columns, authoritative format lives in the log file's own header):

```
- <date> | tier <1|2> | <build-path: direct | handoff-to-executor | escalated> | <classification> | est=<N> lines | actual=<N> lines | model=<opus|sonnet|haiku> | questions=<none | "Q1" → "A1">  | notes=<optional>
```

This preserves the routing-pattern learning surface that @idea's memory would otherwise capture. Review this log periodically — if Tier 1/2 misclassifications are accumulating, tighten the tier definitions above.

### Model-tier rationale (so future-you doesn't second-guess)

- **@architect = opus** because catching design-phase bugs is dramatically cheaper than fixing them later. The cost of one opus pass is small compared to executor re-runs against a flawed brief.
- **@reviewer = opus** because the value of code review depends on (a) catching subtle bugs and (b) communicating them precisely. Opus's reasoning depth + writing clarity are both load-bearing here.
- **@groomer = sonnet** (same as @executor) because the right test of "can this be built?" is run by the same model that will build it.
- **@idea = haiku** because requirements interviews are mostly social and structural, not analytical. Haiku is competent here and 5-10× cheaper.

## Verification discipline (generic hard rule)

Never report a behavioral change as done, fixed, or working without observing it via an executable check. "Behavioral" means correctness is a runtime, visual, timing, or interaction effect — not something fully visible by reading the source. Code-reading proves logic shape; it does not prove behavior.

- If a behavioral change has no executable feedback loop (test, script, reproduction command), that is a **brief gap**: `@groomer` fails item 6 and the brief is refined to add one. Do not let the pipeline proceed by guessing.
- `@reviewer` may not `[APPROVED]` a behavioral fix it never observed running — see reviewer Rule 7.
- This is generic engineering discipline, not project policy. It guards every consumer against the failure mode where a plausible-looking diff ships a live bug.

## Consuming-project hard rules

This workflow ships **mechanism, not policy.** It deliberately contains no deploy rules, style constraints, or environment assumptions — those belong to the project that consumes it.

If the consuming project defines its own hard rules (in its project `CLAUDE.md`, or in Claude Code memory), the orchestrator:

1. **Honors them directly** in any work it does itself (Tier 1 / Tier 2).
2. **Embeds the relevant subset into every `[HAND-OFF BRIEF]`** it synthesizes. `@executor` and `@reviewer` do not see the consuming project's memory — so a rule that isn't in the brief won't reach them. Carry forward only the rules that bear on the current artifact (e.g. a "no push to master without approval" rule belongs in a brief that might commit/push; a numeric-literal policy belongs in a brief that writes CSS).

This is how a consumer's project-local rules get teeth without being baked into the shared submodule.

## Git policy (commit freely; push gated by protected branches)

**Branch off the target before starting.** When the interview (Tier 2 inline, or @idea's brief Source Control section at Tier 3) has established the **topic** and a **target branch** for repository/code work, create a working branch off the target branch BEFORE the first commit. Name it `<ticket>-<topic-slug>` when a tracking ticket exists (e.g. `PROJ-123-fix-login-redirect`), or `<topic-slug>` when none does. Branch off the up-to-date target (`git fetch` then branch from `origin/<target>` when a remote exists). This composes with protected branches below: you branch off a protected target like `main` but never commit to it directly — the feature branch carries the work. Skip this for non-repo artifacts and for trivial work already on an appropriate branch.

**Commit freely.** When a unit of work is complete, commit it — no permission needed. Committing is local and reversible; do not stop to ask. Use clear messages.

**Push is gated by a protected-branches list.** Before any `git push`:

1. Read `.claude/protected-branches` in the project root (one branch name per line; blank lines and `#` comments ignored). If the file is absent, default-protect `main` and `master`. Matching is by exact branch name, not substring — a feature branch like `PROJ-123-main-fix` does NOT match a protected entry `main`.
2. **The branch you are pushing is listed → protected.** Pushing may trigger a deploy or CI. Get explicit user approval before pushing, every time. (This is the branch you push TO — usually the same as the current branch — not the integration "target branch" from the Source Control section above.)
3. **The branch you are pushing is NOT listed → push freely** without asking. Working/feature branches (`<ticket>-<topic>`) are never listed, so pushes to them flow without friction; only the eventual push or merge into a protected integration branch needs approval.

This is mechanism, not policy: the workflow reads the list; the consuming project owns its contents. A project with no shared/deploy branches can leave the file empty (nothing protected); a project where `main` deploys to production lists `main` (and `release`, `production`, etc.). See README "Protected branches".

## Multi-agent workflow (5-agent pipeline)

The five custom agents in `.claude/agents/` form a cue-driven pipeline. The orchestrator (the main Claude session) reads each agent's output cue and routes to the next agent. **Agents never invoke each other** — only the orchestrator chains them.

| # | Agent | Model | Purpose | Exit cue(s) |
|---|---|---|---|---|
| 1 | `@idea` | haiku | Interview user, produce brief + draft plan | `[BRIEF READY] confidence=<0-100>` |
| 2 | `@groomer` | sonnet | Audit brief: is it executor-ready? | `[GROOMED]` or `[NEEDS REFINEMENT: <reasons>]` |
| 3 | `@architect` | opus | Refine brief OR request more user input | `[REFINED]` or `[NEEDS USER INPUT: <questions>]` |
| 4 | `@executor` | sonnet | Build the artifact | `[ARTIFACT READY]` or `EXECUTION BLOCKED: ...` |
| 5 | `@reviewer` | opus | Code-review against brief + plan | `[APPROVED]` or `[CHANGES REQUESTED: <list>]` |

### Routing table (cue → next action)

| Cue from current agent | Orchestrator's next action |
|---|---|
| `[BRIEF READY] confidence=*` | Invoke `@groomer` with brief + `project_plan.md` path |
| `[GROOMED]` | Invoke `@executor` with brief + `project_plan.md` |
| `[NEEDS REFINEMENT: <reasons>]` | Invoke `@architect` with brief + plan + groomer's reasons |
| `[REFINED]` | Invoke `@executor` with refined brief + updated `project_plan.md` (skip re-grooming) |
| `[NEEDS USER INPUT: <questions>]` (Path B, no refined brief) | Invoke `@idea` with the questions; @idea re-interviews user; on @idea's re-emit, route to `@groomer` for re-audit |
| `[NEEDS USER INPUT: <questions>]` with a refined-but-partial brief containing `**[PENDING USER INPUT]**` markers (Hybrid path) | Invoke `@idea` with the questions; on @idea's re-emit, route back to `@architect` (NOT `@groomer`) to finalize remaining markers; `@architect` then emits `[REFINED]` for groomer re-audit |
| `[ARTIFACT READY]` | Invoke `@reviewer` with brief + plan + artifact |
| `[APPROVED]` | Pipeline complete. Deliver artifact to user. |
| `[CHANGES REQUESTED: <list>]` | Invoke `@executor` with prior artifact + changes list |
| `EXECUTION BLOCKED: <reason>` | Surface to user with the contradiction; pipeline halted |

### Cue parser semantics

The orchestrator parses agent output for the cues above. Rules:

1. **Last-occurrence wins.** If an agent's response contains multiple cues (e.g., it draft-emits `[APPROVED]` mid-narrative then concludes with `[CHANGES REQUESTED: ...]`), the LAST matching cue in the response is the routing signal. This lets the model think through and commit at the end.
2. **Distinct prefixes required.** The cues `[NEEDS REFINEMENT:` and `[NEEDS USER INPUT:` share the `[NEEDS ` prefix but diverge at the second word; the parser must match the full cue name, not the bracket prefix.
3. **Mutually exclusive within an agent.** No agent may emit two of its own cues in one turn. Where the prompts say "mutually exclusive," the parser still applies rule 1 as a safety net.
4. **Empty cue body is fatal — re-invoke.** A cue like `[CHANGES REQUESTED:]` with no payload is a malformed turn. Re-invoke the agent with a "your cue had no payload; please re-emit with the required content" reminder. Do not attempt to recover by inferring intent from adjacent cues; the model should commit cleanly.
5. **`[NEEDS USER INPUT:]` requires body-content disambiguation.** This cue has two valid sources, distinguished by body content, NOT by the cue itself:
   - **Path B (no refined brief in body):** route the questions to @idea; on @idea's re-emission, route back to @groomer for a fresh audit.
   - **Hybrid path (body contains a refined brief with `**[PENDING USER INPUT]**` markers):** route the questions to @idea; on @idea's re-emission, route back to @architect (NOT @groomer) so @architect can resolve the markers and emit `[REFINED]`.

   Disambiguator: search the response body for the literal string `**[PENDING USER INPUT]**`. Present → Hybrid; absent → Path B. This is in addition to the standard last-occurrence-wins cue match.

### @architect question-count enforcement (orchestrator-side)

@architect's prompt says Path B / Hybrid must emit 1-3 questions in `[NEEDS USER INPUT: q1 | q2 | q3]`. Self-verification is in the prompt but not enforced. The orchestrator enforces externally:

- On receiving `[NEEDS USER INPUT: ...]`, count pipe-separated questions in the cue payload.
- If count > 3, DISCARD the response and re-invoke @architect with: *"You emitted N questions; the cap is 3. Re-take Path A or Hybrid for the inferable subset, then re-emit at most 3 questions for the residual."*
- Logged in `routing_observations.md` as `architect-too-many-questions`.

### @idea anti-fabrication enforcement (orchestrator-side)

@idea's prompt has a self-check ("transcript contains at least one user reply") but in-session evidence shows it can be ignored. The orchestrator enforces it externally:

- When @idea returns `[BRIEF READY] confidence=<N>`, the orchestrator inspects the prior transcript between this @idea spawn and the user.
- If `confidence ≥ 80` AND the user has answered **zero** of @idea's questions in this spawn, the orchestrator DISCARDS the brief and re-invokes @idea with: *"You emitted a brief without conducting an interview. Confidence floor for an uninterviewed prompt is 10%. Re-engage and ask your highest-leverage question."*
- Logged in `routing_observations.md` as `idea-fabrication-rejected`.

### Loop caps (mandatory)

To prevent infinite ping-pong, two loops have iteration caps:

- **Refinement loop** (`@idea ⇄ @architect`): max **3 bounces** between the two agents. The initial groomer-driven invocation of @architect is bounce #0 (uncounted). Each subsequent `[NEEDS USER INPUT:]` → @idea → re-emit → @architect counts as one bounce. The 4th attempted bounce is refused — orchestrator escalates to user instead.
- **Review loop** (`@executor ⇄ @reviewer`): max **3 review cycles total**, where one cycle = one @executor build + one @reviewer audit. The initial build+review = cycle 1. Each `[CHANGES REQUESTED:]` that re-invokes @executor starts a new cycle. After cycle 3 ends with `[CHANGES REQUESTED:]`, orchestrator surfaces the latest changes list to the user and asks whether to accept as-is or hand-edit; it does NOT re-invoke @executor a 4th time.

**Persist counts to disk.** Working memory does not survive context compaction. The orchestrator maintains `.claude/workspace/loop_state.json`:

```json
{ "pipeline_id": "<iso-timestamp>", "refinement_bounces": 0, "review_cycles": 0 }
```

**Increment rules (increment-then-check semantics):**
- `refinement_bounces`: increment immediately BEFORE routing `[NEEDS USER INPUT:]` back to @idea. If the new value would be > 3, do NOT route — surface to user instead.
- `review_cycles`: increment immediately BEFORE invoking @executor (for ANY trigger — `[GROOMED]`, `[REFINED]`, or `[CHANGES REQUESTED:]`). If the new value would be > 3, do NOT invoke — surface to user.

Both counters start at 0 and reach 3 after the third routing. The 4th routing is refused. The `SessionStart` hook clears this file (both `startup` and `clear`).

### Context discipline

When chaining agents, **forward only what the next agent needs**, not the full transcript:

- `@idea` → `@groomer`: pass the `[HAND-OFF BRIEF]` block + path to `project_plan.md`. Drop the Q&A transcript.
- `@groomer` → `@architect`: pass the brief + plan + groomer's `[NEEDS REFINEMENT: ...]` cue. Drop groomer's audit narrative.
- `@architect` → `@executor`: pass the refined brief + updated plan. Drop architect's reasoning.
- `@executor` → `@reviewer`: pass the brief + plan + artifact. Drop @executor's internal validation.
- `@reviewer` → `@executor` (on changes): pass the artifact + the numbered changes list. Drop reviewer's narrative.

This keeps each subprocess's context small (cheap, fast, focused) and matches the pipeline's "single-purpose agent" design.

### `project_plan.md` location

- Canonical path: `.claude/workspace/project_plan.md`. The orchestrator MUST `mkdir -p .claude/workspace/` before invoking `@idea` for the first time in a session.
- Fallback path: `.claude/project_plan.md` is tolerated but discouraged. If both exist on disk, the workspace path is authoritative.
- `@idea` writes the file; `@architect` overwrites in place (never appends, never creates a sibling).
- All downstream agents read from the canonical path.
- The `SessionStart` hook clears BOTH paths on `startup` and `clear` events, so a stale plan from a prior pipeline cannot contaminate a new run.

### When to skip the pipeline

See **Agent routing (3-tier)** above. The short version: only Tier 3 runs the full pipeline. Tier 1 and Tier 2 stay with the orchestrator.

## Known issues & workarounds (from loop testing, 2026-05-28)

Real bugs uncovered by the smoke tests. Each has a workaround in place or documented.

1. **`@idea` does not always overwrite `project_plan.md`.** A second pipeline run can find stale content from a prior run on disk. **Workaround installed:** a `SessionStart` hook in `.claude/settings.json` deletes BOTH `.claude/workspace/project_plan.md` AND `.claude/project_plan.md` (plus `loop_state.json`) on `startup` and `clear` events (fresh-context boundaries). It explicitly does NOT trigger on `resume` or `compact` — those preserve `/btw` continuity and an in-flight plan is still relevant context. **Positive-confirmation step (orchestrator):** after `@idea` returns `[BRIEF READY]`, the orchestrator MUST Read the plan file and verify (a) first line is `# project_plan.md`, (b) file mtime within the last 60s. If either fails, re-invoke `@idea` explicitly instructing it to Write.

2. **Agent .md edits don't take effect for registered subagent types until the Claude Code session restarts.** The harness caches agent prompts at session start. **Workaround:** while iterating on an agent .md, invoke via `subagent_type: "general-purpose"` and tell it to read its instructions from the agent's .md file path on every call — `general-purpose` reads from disk each invocation. Once the agent is "finalized," restart Claude Code so the named subagent picks up current contents.

## Notes on agent safety with FleetView bug #59518

FleetView issue #59518 ("background agent stuck in 'working' state when it enters plan mode or asks a question") does NOT affect this pipeline, because:

- All five agents are spawned **foreground** (orchestrator awaits the result and relays). FleetView only displays background agents.
- `@idea`'s `tools:` list intentionally excludes `AskUserQuestion`. It asks the user by emitting a question as text output; the orchestrator relays it. So even if `@idea` were ever moved to background mode, it has no path to call the offending tool.

If you ever add a new agent that needs `AskUserQuestion` AND you spawn it in the background, you will hit this bug. Avoid that combination until #59518 is fixed.

## Cross-agent learning channel

Per-agent memory directories under `.claude/agent-memory/<name>/` are local to each agent. The forward-only pipeline (`@reviewer` cannot push findings back to `@groomer`/`@idea`) is patched by a shared file:

- **File:** `.claude/agent-memory/_shared/cross_agent_findings.md`
- **Format:** append-only, one record per failure. Each record:
  ```
  ## <iso-timestamp> | <writer-agent> → <reader-agent>
  **Failure class:** <short label, e.g. "DoD-missing-tests", "constraint-implicit-only">
  **Evidence:** <one-line citation, e.g. "brief said 'tests pass' but never defined the suite">
  **Recommendation:** <one-line for the reader, e.g. "add to groomer item-4 examples">
  ```
- **Read protocol:** `@groomer`, `@idea`, and `@architect` read this file at the start of every invocation (before reading the brief). It's small enough to fit; treat the last 20 entries as the active context.
- **Write protocol:** `@reviewer` appends when it finds a brief-level (not artifact-level) gap. The orchestrator also appends when it makes a routing decision that retroactively turned out wrong (per the routing observations log).
- **Garbage collection:** the orchestrator checks the record count at the **start of every Tier 3 pipeline invocation** (count `^## ` headers). If count > 200, move the oldest 100 records to `.claude/agent-memory/_shared/cross_agent_findings.archive.md` (creating it if absent), leaving the most recent 100+ in the active file. Rotation happens before any agent reads the file in that pipeline, so the active file is always ≤ 200 records when read.

The shared findings file is the only place where one agent's output influences another agent's behavior across invocations. Keep it terse and evidence-anchored.

## Telemetry roadmap (JSONL migration)

`routing_observations.md` is human-readable but not queryable, so the orchestrator also writes a queryable mirror.

- **Status:** **LIVE since 2026-05-29.** Dual-write is in effect (see "Routing-observations log" above). The JSONL was backfilled with the 4 pre-migration markdown entries.
- **File:** `.claude/orchestrator_telemetry.jsonl` (one JSON object per line).
- **Schema:** `{ ts, tier (1|2|3), build_path ("direct"|"handoff-to-executor"|"escalated"), classification, est_lines (int), actual_lines (int|null), model, questions: [{q, a}, ...], outcome, artifact_path (string|null), anomalies: [...] }`.
  - `build_path` was added beyond the original roadmap sketch — it is the markdown log's load-bearing column and must not be lost in the mirror.
  - `actual_lines` and `artifact_path` are `null` when not measured/recorded (e.g. a handoff whose artifact size wasn't captured). `questions` is `[]` for Tier 1. `anomalies` carries what the markdown `notes` column carried.
- **Why JSONL:** line-atomic writes are safe under concurrent appends; `jq` makes queries cheap; tier-misclassification rate is one `jq` away from a calibration signal. Example: `jq -s '[.[] | select(.actual_lines != null)] | map(.actual_lines - .est_lines)' .claude/orchestrator_telemetry.jsonl` surfaces estimate drift.
- **Markdown retention:** the human-readable log is **retained indefinitely and remains the primary, authoritative surface.** Deprecation is explicitly deferred — do NOT remove or stop writing the markdown log. Revisit only if/when a `/calibrate` skill exists and the team decides the JSONL fully subsumes it.

## Deferred items (from 2026-05-28 critique)

Documented for future-you. These are known gaps NOT fixed in the May-28 pass:

1. **Pipeline test harness.** No `.claude/tests/` scenarios yet. Manual smoke testing only. When added: cover (a) vague request → Tier 3, (b) specific small → Tier 1 direct, (c) mid-ambiguity → Tier 2 inline.
2. **`/calibrate` skill.** Should consume the telemetry file and print tier-misclassification rate; recommend threshold adjustments when rate > 20%.
3. **`@editor` agent.** `@reviewer` is calibrated for code correctness; prose review needs a different reviewer. Currently the orchestrator writes prose directly using opus.
4. **Splitting `description:` from examples.** Verify whether the harness injects agent `description:` into the child agent's context; if not, examples can move to a sibling `.examples.md` file and shrink invocation prompts.
5. **Pre-spawn agent-hash check.** Warn the user when `.claude/agents/<name>.md` was edited mid-session (cached prompt is stale until restart per known-issue #2).
