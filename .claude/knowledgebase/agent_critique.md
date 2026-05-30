# Agent & CLAUDE.md Critique — claude-workflow.md (rev. 2026-05-28b)

**Audience:** the project owner and future-Claude reading this before touching the pipeline.
**Stance:** direct, no hedging. Findings followed by concrete fixes.
**Date:** 2026-05-28 (post-fix-sweep revision).
**Sources audited:** `CLAUDE.md`, `ARCHITECTURE.md`, `.claude/agents/{idea,groomer,architect,executor,reviewer}.md`, `.claude/settings.json`, `.claude/agent-memory/*`, `.claude/workspace/`.

This document supersedes the prior revision. For the original critique that drove most of the fixes, see git history.

---

## 0. Changelog — what this revision reflects

Since the prior critique, a large fix sweep has landed. Verified on-disk state at the time of this writing:

**P0 (all done, verified):**
- `architect.md` is 110 lines (was ~240), `executor.md` is 115 lines (was ~240). The inlined ~140-line auto-memory boilerplate is gone from both. `memory: project` frontmatter handles persistence.
- `@ready hand-off` ghost reference removed from `executor.md`.
- Memory directories consolidated. `.claude/agent-memory/` contains exactly `_shared/`, `architect/`, `executor/`, `idea/`, `orchestrator/`. The duplicate `architect-planner/` and the orphan `polish-executor/` are gone. Architect's `archetype_unix_clone_script.md` was migrated.
- `SessionStart` hook in `.claude/settings.json` now clears `.claude/workspace/project_plan.md`, `.claude/project_plan.md`, AND `.claude/workspace/loop_state.json` on both `startup` and `clear`.
- Stale `.claude/project_plan.md` (word-counting plan) deleted; the fallback path is empty.
- Tool lists trimmed — then **partially restored** after the user flagged that the original trim was too aggressive. The critique had conflated "tools the agent doesn't use in the routing logic" with "tools the agent needs for context-gathering." A team that lives in Atlassian needs `@idea` to be able to read a JIRA ticket the user references, and `@architect` to be able to consult a Confluence SOP while refining. Current state: `@idea`, `@architect`, `@groomer`, `@reviewer` each carry Read/Write/Edit (or Read/Grep/Glob/Bash/Edit as appropriate) + Skill/ToolSearch + WebFetch + WebSearch + the **read-only** Atlassian MCP set (getJiraIssue, search, getConfluencePage, etc.) + GitHub auth tools on @idea/@architect + ListMcpResourcesTool/ReadMcpResourceTool on @idea/@architect. **Write-side Atlassian tools** (createJiraIssue, addComment, editJiraIssue, updateConfluencePage, etc.) are NOT restored by default — letting haiku/sonnet mutate external state is a separate policy decision; flag if you want those on. Stripped permanently: Cron, Worktree, Monitor, PushNotification, RemoteTrigger, TaskCreate/Update/etc — those genuinely don't belong on pipeline agents.

**P1 (all done, verified):**
- `@idea` description is Tier-3-only and explicitly forbids Tier 1/2 invocation. `@executor` description accepts briefs from both the full pipeline and inline orchestrator synthesis.
- CLAUDE.md added: **Cue parser semantics** (last-occurrence-wins; distinct prefix requirement; empty-cue handling), **@idea anti-fabrication enforcement** (orchestrator rejects `[BRIEF READY]` from @idea when prior turn count of user replies is zero), loop-count persistence to `.claude/workspace/loop_state.json`, canonical workspace path for `project_plan.md` with fallback discouraged.
- Known issues #1 now includes a positive-confirmation step: orchestrator must Read the plan and verify first-line + mtime after `@idea` returns.
- `@executor` EXIT PROTOCOL is size-conditional: ≤200 lines AND ≤8KB inline; otherwise save + return `Saved to: <path>` + cue, no inlining.

**P2 (partially done, verified):**
- New `.claude/agent-memory/_shared/cross_agent_findings.md` with documented record format.
- `@reviewer.md` rule #6 now requires appending a finding to the shared file in addition to the "Brief Concerns:" footer; reviewer's tool list extended with `Edit`.
- `@groomer.md` rule #0 reads cross-agent findings on entry; recent reviewer findings flip the related checklist item to failing-by-default unless explicitly defended.
- `@architect.md` rule #5 introduces a Hybrid path (refine inferable gaps and emit `[NEEDS USER INPUT:]` for residuals in the same turn, with `**[PENDING USER INPUT]**` markers). Rule #7 reads cross-agent findings on entry.
- CLAUDE.md added: **Cross-agent learning channel** section and **Telemetry roadmap (JSONL migration)** section.

**P3 (partially done, verified):**
- All five agent .md files carry `<!-- last-reviewed: 2026-05-28 against claude-opus-4-7 -->` trailers.
- CLAUDE.md has a **Deferred items** section enumerating the five intentionally-unbuilt things.

**Architectural addition:** `ARCHITECTURE.md` at repo root, with Mermaid + ASCII diagrams for the component view, the 3-tier routing decision, the full pipeline sequence, the cue state machine, the cross-agent learning channel, the file layout, the hooks, and the model-tier rationale. This critique links to it where appropriate rather than duplicating.

**What did NOT get done (covered in §7 below):** pipeline test harness, `/calibrate` skill, `@editor` agent, `description:` splitting investigation, pre-spawn agent-hash check, and the routing-log review-cadence problem (orchestrators still have no heartbeat).

**Follow-up P0 pass (applied AFTER this critique was first written, on the same day):** The seven §8 P0 items below were knocked out in a second sweep:
- `@idea` now has the cross-findings reader rule (`**ON ENTRY** Read .claude/agent-memory/_shared/cross_agent_findings.md`) and a new "User delegates" edge case.
- `@groomer` rule #6 contradiction fixed: now says "Don't add new constraints; flag missing structure only" while explicitly acknowledging items 1 and 4 are about wording quality.
- `@executor` now has an explicit `tools:` frontmatter line with a `# intentionally broad` comment, plus a binary-artifact carve-out in the exit protocol.
- `@architect` self-verification now includes a Hybrid-path checklist (4 items).
- CLAUDE.md routing table now has two rows for `[NEEDS USER INPUT:]`: one for Path B (route back to @groomer after @idea), one for Hybrid (route back to @architect after @idea).

**Net P0 state after the follow-up:** all seven §8 P0 items below are resolved on disk. §1 item 3 (the @idea wiring gap) is closed. Verification gap in §7.1 remains — still no in-flight test.

---

## 1. TL;DR — the things that still matter

Most of the prior P0-P1 list is gone. The remaining sharp edges:

1. **No pipeline test harness.** Every change to an agent .md is a leap of faith. The fixes above were verified by reading files on disk; they were not exercised through an end-to-end pipeline run. This is the single biggest open risk.
2. **The agent-prompt cache means "verified on disk" ≠ "verified in a session."** Until you restart Claude Code and run the pipeline against scripted scenarios, you don't know whether any registered subagent actually obeys the edits. CLAUDE.md known-issue #2 documents this but doesn't enforce it.
3. ~~**Half-applied fix: `@idea` does not read cross-agent findings, despite CLAUDE.md saying it should.**~~ **RESOLVED in follow-up sweep:** `idea.md` now has an `**ON ENTRY**` section instructing it to read `.claude/agent-memory/_shared/cross_agent_findings.md` on every invocation. The CLAUDE.md "readers" list is now accurate.
4. **No `/calibrate` skill and no JSONL telemetry.** The roadmap is documented; the migration is not done. The `routing_observations.md` log is still append-only markdown that "the orchestrator should review periodically" — orchestrators have no heartbeat, so this still won't happen. The 90/75/<75 thresholds remain uncalibrated.
5. **Prose is still routed through code-tier infrastructure.** `@reviewer` is calibrated for code correctness; the orchestrator currently writes prose directly (correct workaround) but there's no `@editor` agent, so any Tier 1 ≥10-line prose handoff would land on `@reviewer` and be mis-reviewed. The current routing-observations log shows the orchestrator avoiding this correctly, but the rule isn't structurally enforced — only by orchestrator discipline.
6. **No agent-hash sanity check at spawn time.** A developer who edits an agent .md mid-session and tests it via the registered subagent type will run the OLD cached prompt with no warning. The deferred items list acknowledges this; the warning is documentation-only.
7. **Hybrid Path (architect rule #5) is now contractually defined but unexercised.** The mechanic — refine inferable gaps, mark residuals `**[PENDING USER INPUT]**`, emit `[NEEDS USER INPUT:]` without `[REFINED]`, route questions to `@idea`, then re-invoke @architect — is now specified in CLAUDE.md's routing table (two rows for `[NEEDS USER INPUT:]`: Path B vs. Hybrid) and `architect.md` has a Hybrid-path self-verification checklist. **Still untested in flight** — the prompt-cache means actual behavior verification waits for a session restart + scenario run (see §7.2 scenario 2).

The rest of this document is the long form, section-by-section.

---

## 2. Architectural critique (pipeline design)

### 2.1 Learning loop — now exists, but incompletely wired

**Previously:** the pipeline was a strict forward-only DAG. Reviewer's "Brief Concerns:" footer was a dead letter.

**Now:** `.claude/agent-memory/_shared/cross_agent_findings.md` exists with a documented record format (H2 timestamp / Failure class / Evidence / Recommendation), reviewer is required to append on brief-level findings, and groomer/architect read on entry. The file is currently empty (no entries yet), which is fine — it'll fill as the pipeline runs.

**Residual issues:**
- **`@idea` not actually wired as a reader.** CLAUDE.md's "Cross-agent learning channel" section names `@groomer`, `@idea`, and `@architect` as readers. `cross_agent_findings.md` repeats the same claim. Neither is true for `@idea`: `idea.md` has no rule instructing it to read the file. Fix: add a one-line rule to `idea.md` ("Read `.claude/agent-memory/_shared/cross_agent_findings.md` on entry; treat recent failures as patterns to probe in the interview"), OR drop `@idea` from the readers list in both places. Pick one.
- **No garbage-collection enforcement.** The "rotate oldest 100 to archive" rule is documented but the orchestrator has no mechanism to count entries and trigger rotation. Until that exists, the rotation rule is aspirational.
- **No back-pressure on duplicate failure classes.** If `@reviewer` writes the same failure class 5 times in a week, that should escalate to "the groomer checklist actually needs a new item," not "groomer should defend against this on each invocation." The current design treats every entry as equal-weight; a frequency-weighted view would be more useful.

### 2.2 Loop caps — now persistent

`.claude/workspace/loop_state.json` is the authoritative counter, cleared by the `SessionStart` hook. CLAUDE.md specifies the schema (`{pipeline_id, refinement_bounces, review_cycles}`) and increment-then-check semantics (both counters start at 0; increment before routing; refuse the routing if new value > 3).

**Residual issue:** the schema does not include a `pipeline_started_at` timestamp or a way to distinguish concurrent pipeline runs if (hypothetically) two were live at once. Today's harness is single-pipeline-per-session so this is theoretical. Flag it for the day FleetView background agents or `/loop` adopts the pipeline.

### 2.3 Cue protocol — now specified

CLAUDE.md "Cue parser semantics" section defines:
- Last-occurrence-wins
- Distinct prefixes required (e.g., the parser must distinguish `[NEEDS REFINEMENT:` from `[NEEDS USER INPUT:` past the second word)
- Mutually exclusive within an agent's turn
- Empty cue body is fatal

Good. **Residual issues:**
- The parser is described in prose, not code. There is no actual parser to point at — the orchestrator reads agent output and decides. So "the parser does X" is really "the orchestrator-as-LLM is instructed to do X." This works as long as the orchestrator follows the rules, which is the same brittleness as any prompt-encoded invariant.
- The new hybrid-path case (architect emits a `**[PENDING USER INPUT]**` brief + `[NEEDS USER INPUT:]`) is not explicitly enumerated in the routing table. Today the orchestrator would route `[NEEDS USER INPUT:]` to `@idea` and probably handle the partial brief correctly, but it's not contractually defined. Fix: add a row to the routing table for "architect-with-pending-markers → @idea, then back to @architect for finalization."

### 2.4 Executor inline-vs-save — now size-conditional

`@executor` rule says: ≤200 lines AND ≤8KB → inline; >200 OR >8KB → save and return path only. This is a clean fix for the prose-doubling problem.

**Residual issue:** the threshold is hard-coded. For images or binary artifacts, even tiny files shouldn't be inlined (they can't be). The current rule is correct for text artifacts; the protocol should explicitly say "this rule applies to text artifacts only; binary artifacts always use save+path-only." One line in `executor.md`.

### 2.5 No tests — **still open**

There is no `.claude/tests/` directory. The fix-sweep was applied to text files; no end-to-end pipeline run validated that the agents actually behave per the new prompts. Given known-issue #2 (agent prompts are cached at session start), even running the pipeline in this session wouldn't test the new prompts — it would test the prompts as of session-start.

This is the **single biggest open risk** in the system. Every other open issue is downstream of "we have no regression detector for prompt changes." See §8 for what a minimal harness would look like.

---

## 3. Per-agent critique

### 3.1 `@idea` (haiku)

**Strengths preserved:** one-question-at-a-time, anti-fabrication confidence floor, edge-case section for "build me something useful," tight tool list, current description correctly Tier-3-only.

**Residual issues:**

1. **Cross-agent findings reader gap** (see §1 item 3). `@idea` is named as a reader in CLAUDE.md but `idea.md` has no rule to read the file. Pick: add the rule or drop from the readers list.

2. **The "user delegates ('you decide')" edge case is still not in the prompt.** The original critique flagged this; the fix sweep did not address it. `idea.md` covers "user provides everything" and "user refuses to clarify" but the "you decide" path (where the right move is to propose defaults inside the brief, flag them as unconfirmed, then ask one confirming question) is missing. The memory file `idea/user-delegates-taste.md` exists and captures this pattern, but a memory file is not the same as a prompt rule — the model has to recall it. Fix: promote the rule into the EDGE CASES section of `idea.md`.

3. **Confidence semantics are still slippery.** The prompt says "Confidence is a function of how many of the five HAND-OFF BRIEF sections you can fill in using statements the user has actually made" but doesn't give a numeric formula. In practice this means "the model decides." The original critique proposed a deterministic formula (20% per directly-supported section, ½ for implicit endorsement); that proposal stands and is unimplemented.

4. **Anti-fabrication is now enforced at the orchestrator** (good), but the in-prompt self-check is now redundant with the orchestrator-side check. Leave the in-prompt check in (defense in depth) but recognize it's no longer load-bearing.

### 3.2 `@groomer` (sonnet)

**Strengths preserved:** tight 9-item checklist, "bias toward escalation," lean tool list, rule #0 now reads cross-agent findings.

**Residual issues:**

1. **Rule #6 still contains the contradiction the prior critique flagged.** "Trust @idea's brief structure. Don't quibble about whether a field 'could be worded better.'" But items 1 and 4 are *about wording quality* (one unambiguous sentence; verifiable Definition of Done). The fix proposed previously ("Don't add new constraints; flag missing structure only") was not applied. Apply it.

2. **Item-numbered cues are still an implicit coupling.** `[NEEDS REFINEMENT: item 5: log path missing]` requires `@architect` to know what item 5 means. The architect prompt doesn't include groomer's checklist. Fix: either embed item *names* in the cue (e.g., `[NEEDS REFINEMENT: external-deps: log path missing | dod-verifiability: tests undefined]`) or duplicate the 9-item checklist into architect's prompt. The hybrid path (rule #5 in architect) is harder to use well without this context.

3. **No "bounce-directly-to-idea" cue.** Groomer's only outputs are `[GROOMED]` or `[NEEDS REFINEMENT:]`, the latter going to architect even when the gap is unambiguously user-domain (e.g., missing item 5: external dependencies). Architect's hybrid path partially absorbs this — architect can refine the inferable parts and bounce the user-domain parts — but for the case where 100% of the gap is user-domain, architect is a pure forwarding step that costs opus tokens. A `[BOUNCE TO IDEA:]` cue from groomer would skip the unnecessary opus call. Worth considering once the hybrid path's behavior is observed.

4. **Item weighting still equal.** Items 1, 2, 4, 5, 9 are catastrophic if violated; items 3, 6, 7, 8 are advisory. The prompt treats all 9 as equal-blocking, which over-escalates and burns architect cycles. Fix: mark a "blocking subset" explicitly. The hybrid path mitigates this on the architect side but doesn't reduce groomer-side false-positive escalations.

### 3.3 `@architect` (opus)

**Strengths preserved:** two-path structure (now three with hybrid), bias-toward-inference, lean tool list, self-verification checklist split by path, cross-agent findings reader.

**Residual issues:**

1. **Hybrid path is unexercised** (see §1 item 7). Rule #5 specifies the mechanic — write a brief with `**[PENDING USER INPUT]**` markers, emit `[NEEDS USER INPUT:]` without `[REFINED]`, route to `@idea`. The self-verification checklists at the bottom of the prompt cover only Path A and Path B; there is no Hybrid checklist. Add one: "Did you mark every unresolved section? Did you write the partial plan to disk? Does the cue end with `[NEEDS USER INPUT:]` only, with no `[REFINED]`?"

2. **The routing table in CLAUDE.md doesn't enumerate the hybrid case.** When architect emits a hybrid response, the orchestrator routes `[NEEDS USER INPUT:]` to `@idea`. After `@idea` re-emits a strengthened brief, the routing table sends it back to `@groomer`. But the brief still has `**[PENDING USER INPUT]**` markers that @idea may or may not have resolved. There's no contract for "@idea must resolve all markers" or "@groomer must re-check that no markers remain." Without this, hybrid creates a subtle path where partially-refined briefs leak into execution.

3. **Path B's questions still don't constrain `@idea`'s re-entry.** The original critique noted that `@idea`'s re-entry on `[NEEDS USER INPUT:]` is under-specified — does @idea ask only the architect's questions, or restart the full interview? `idea.md` line 90-92 says "treat those questions as your new highest-priority interview topics" which still permits an extended re-interview. For haiku this is wasteful. Fix proposed previously ("Ask only the architect's questions, in order; confidence floor for re-emission is the prior confidence + 10% per question answered") not applied.

### 3.4 `@executor` (sonnet)

**Strengths preserved:** zero-shot execution, no-filler rule, size-conditional exit protocol, EXECUTION BLOCKED escape hatch.

**Residual issues:**

1. **No explicit `tools:` line in the frontmatter.** Executor inherits the full default tool set, which is correct (it needs Bash, Write, Edit, Read, Grep, Glob, etc.) but undocumented. A maintainer who reads the other four agents (all with explicit `tools:` lines) may assume the omission is a bug and "fix" it by restricting. Add a `tools:` line that's deliberately broad, with a comment that says "intentionally broad — executor needs full toolset to build arbitrary artifacts."

2. **Size threshold doesn't handle binary artifacts** (see §2.4). One-line fix.

3. **The "RECEIVING REVIEW FEEDBACK" section doesn't acknowledge the loop cap.** When `[CHANGES REQUESTED:]` arrives and `review_cycles` is at the cap, the orchestrator surfaces to the user — but `@executor` has no signal to handle "this is the last attempt, do something different." Today executor just re-applies changes mechanically. For one-shot brittle changes, an awareness signal would help. Probably not worth fixing now; flag for later.

### 3.5 `@reviewer` (opus)

**Strengths preserved:** contract-is-law, no-style-nags, runs Feedback Loop via Bash, brief-concerns footer + cross-agent finding write.

**Residual issues:**

1. **Bash is still unrestricted by tool-list.** Reviewer is told "you do NOT modify the artifact" but has full Bash + Edit access. The Edit grant is new (needed for the cross-agent findings append) and creates a genuine writability concern: reviewer COULD edit the artifact, the brief, or anything else. The current guard is prompt-discipline only. This is acceptable for opus (which tends to follow role boundaries) but is worth one line of explicit warning: "Edit is granted ONLY for appending to `_shared/cross_agent_findings.md`. Never Edit the artifact, the brief, the plan, or any other file." Otherwise the role boundary is invisible against the tool grant.

2. **No "I genuinely cannot tell" exit cue.** The original critique proposed `[NEEDS HUMAN REVIEW:]` for cases where the artifact looks plausible but the Feedback Loop is non-executable and reviewer lacks the domain knowledge. Still not added. The current default is "approve when in doubt" (rule #4), which biases toward false positives. For low-stakes artifacts this is fine; for high-stakes ones it's not. Worth adding the third cue when a high-stakes scenario surfaces.

3. **"Tests are missing" still ambiguous.** If the brief's Feedback Loop names a check that doesn't exist (no test file, no lint config), is that a `[CHANGES REQUESTED:]` (executor's gap) or a brief problem (brief assumed infrastructure)? The prompt doesn't say. Original fix proposal stands and is unimplemented.

---

## 4. CLAUDE.md critique

### 4.1 The 3-tier routing rules

Largely unchanged. The 90/75/<75 thresholds remain uncalibrated. The `/calibrate` skill is documented in **Deferred items** but not built. Re-stating the residual:

1. **Thresholds are vibes.** Until `/calibrate` exists, there's no feedback path. The `routing_observations.md` log accumulates entries the orchestrator never reads. CLAUDE.md still says "Review this log periodically" — this is a no-op instruction.

2. **Prose-vs-code routing is not in the tier rules.** Tier 1's "Larger / has logic" branch sends artifacts ≥10 lines to `@executor` + `@reviewer`. For prose, `@reviewer` is mis-calibrated. The orchestrator currently sidesteps this by writing prose directly (per routing_observations.md: this critique itself was Tier-2-direct), but the routing rules don't structurally distinguish prose. Without an `@editor` agent, the orchestrator's discipline is the only guard.

3. **The "Routing-observations log" is still markdown.** The JSONL migration is documented as a roadmap; no migration done. Concurrent appends to markdown (unlikely but possible under `/loop` or background agents) would interleave-corrupt. JSONL is line-atomic.

### 4.2 Multi-agent workflow tables

The routing table is the most useful section. **Residual issues:**

1. **Hybrid path not in the routing table** (see §3.3 item 2). Add the row.

2. **Context discipline rules are correct but unenforced.** "Forward only what the next agent needs, not the full transcript" is right; nothing checks it. A telemetry field `context_passed_bytes` (proposed in the JSONL schema) would surface anomalies. Until JSONL exists, this remains an aspirational rule.

3. **`project_plan.md` location section is now clean.** Canonical workspace path declared, fallback discouraged, hook clears both. The orchestrator's `mkdir -p .claude/workspace/` is still implicit — the section says "MUST mkdir before invoking @idea for the first time" but there's no enforcement. Acceptable for now; revisit if the fallback path appears in practice.

### 4.3 Known issues & workarounds

**Bug #1 ("@idea doesn't always overwrite project_plan.md")** — workaround is solid (hook + positive-confirmation step). The root cause is still uninvestigated. Two cycles of this fix have layered protection without diagnosing why haiku sometimes skips Write. Possible cause: the prompt's "Step 1 — Write the plan to disk" instruction comes BEFORE the brief template in the prompt; under instruction-following pressure, haiku may treat the brief emission as the "real" output and skip the file write. Worth testing once the harness exists.

**Bug #2 ("agent .md edits don't take effect until restart")** — workaround documented (use `general-purpose` for iteration). The pre-spawn agent-hash check is deferred. **This bug means every fix in this document is unverified in a session.** When the harness exists, the first scenario it should run is "edit an agent .md → restart → verify behavior." Until then, the fix sweep is "verified on disk, untested in flight."

### 4.4 Cross-agent learning channel section

Mostly clean. **Residual:**
- `@idea` listed as reader but not wired (see §1 item 3).
- Garbage collection mechanism is undefined (see §2.1).

### 4.5 Telemetry roadmap section

Clean as a roadmap; nothing built. Calling out one thing: the "dual-write to both files for one week" migration plan only works if there's an orchestrator instructed to do the dual-write. There isn't. The roadmap is a roadmap.

### 4.6 Deferred items section

Honest acknowledgment of what didn't get built. This is good documentation hygiene. The five deferred items are the bulk of the §7 backlog below.

---

## 5. Cross-cutting issues

### 5.1 Agent .md structure is now uniform

Comparison after the fix sweep:

| Section | idea | groomer | architect | executor | reviewer |
|---|---|---|---|---|---|
| Tool restrictions | tight (5) | tight (6) | tight (6) | none (default-all) | tight (8) |
| Inlined memory boilerplate | no | no | **no** (was 140 lines) | **no** (was 140 lines) | no |
| Self-verification checklist | yes | yes | yes | yes | yes |
| Cross-findings read on entry | **no** (gap) | yes (rule #0) | yes (rule #7) | n/a | n/a (writes only) |
| Version stamp trailer | yes | yes | yes | yes | yes |
| Description Tier-aware | yes | yes (implicit) | yes (implicit) | yes | yes (implicit) |

The largest cross-cutting inconsistency is now the `@idea` cross-findings gap. Fix that and the structure is genuinely uniform.

### 5.2 Description examples still ship with every invocation

This was a P3 item in the original critique and remains unverified. The fix-list notes that "splitting `description:` from examples depends on unverified harness behavior" — i.e., we don't know whether the harness passes the `description:` field into the child agent's context. The original critique asserted (with low confidence) that it does NOT. If correct, the examples are fine — they shrink the routing surface for the parent agent without bloating the child. If incorrect, each invocation pays for ~200-500 words of conversational scaffolding.

Investigation cost is low (one print statement in a child agent: log the system prompt at startup). Hasn't been done. **Add to the backlog.**

### 5.3 Prompt-as-code vs. prompt-as-doc tension

The agent .md files are now much closer to runtime-only. Background and rationale live in `CLAUDE.md`, `ARCHITECTURE.md`, and this knowledgebase document. The previous bloat (inlined memory boilerplate) was the worst offender and is gone. **No active issue here**; flag as resolved.

---

## 6. State on disk — what's clean now

Snapshot at the time of this revision:

| Path | State |
|---|---|
| `.claude/project_plan.md` | Absent (correct — hook clears it) |
| `.claude/workspace/project_plan.md` | Absent (correct — no pipeline in flight) |
| `.claude/workspace/loop_state.json` | Absent (correct — hook clears it) |
| `.claude/agent-memory/_shared/cross_agent_findings.md` | Exists; no entries yet (correct — no failures recorded) |
| `.claude/agent-memory/architect-planner/` | Absent (correct — consolidated) |
| `.claude/agent-memory/polish-executor/` | Absent (correct — never an agent) |
| `.claude/agent-memory/{architect,executor,idea,orchestrator,_shared}/` | All present |
| `.claude/agents/architect.md` | 110 lines, no inlined memory |
| `.claude/agents/executor.md` | 115 lines, no inlined memory, no `@ready` reference |
| All five agent .md files | Have `<!-- last-reviewed: 2026-05-28 against claude-opus-4-7 -->` trailers |
| `.claude/settings.json` | `SessionStart` hook clears all three transient files on `startup` and `clear` |
| `ARCHITECTURE.md` | Exists at repo root with full diagrams |

Nothing on disk currently contradicts the fix list, with the exception noted in §1 item 3 (the `@idea` cross-findings reader gap is a prompt-level gap, not a disk-level one).

---

## 7. Verification gaps

This section is **new** in this revision. It records what was NOT verified by reading files.

### 7.1 None of the prompt edits have been pipeline-tested

All five agent .md files were edited in the fix sweep. None have been exercised through a full pipeline run since editing, and per known-issue #2 the agent-prompt cache means even running the pipeline NOW would test the prompts as of session-start, not as of the latest edit. **Verification is currently "the file looks right when I `cat` it."**

### 7.2 What a restart-then-test minimal validation would look like

After a Claude Code restart, run these three scenarios and observe the routing trace:

1. **Tier 3 happy path.** User input: "build me a Python CLI that counts unique IP addresses in an nginx access log." Expected: `@idea` asks 2-4 questions (log path, output format, edge cases for malformed lines, "first column or X-Forwarded-For"); `@groomer` either grooms or escalates; if escalation, `@architect` refines using the `archetype_unix_clone_script.md` memory; `@executor` builds; `@reviewer` approves on first pass (likely) or returns one concrete issue.

2. **Hybrid-path probe.** User input: "deploy this microservice." This brief is missing inferable structure (build process, runtime) AND user-domain detail (target cloud, region). Expected: `@idea` interviews; `@groomer` likely escalates with multiple items; `@architect` should take the Hybrid path — fill inferable structure, mark cloud/region as `**[PENDING USER INPUT]**`, emit `[NEEDS USER INPUT:]` without `[REFINED]`. Verify the orchestrator routes back to `@idea` correctly and the partial plan is on disk.

3. **Anti-fabrication probe.** User input: "build something useful." `@idea` should ask a real first question. If `@idea` instead returns `[BRIEF READY] confidence=80` with no interview, the orchestrator-side anti-fabrication check must reject and re-invoke. Verify this rejection actually fires; verify the rejection event is logged to `routing_observations.md` as `idea-fabrication-rejected`.

4. **Cross-agent finding feedback probe.** During scenario 1's review pass, force a brief-level finding by giving `@executor` a brief whose Definition of Done is "tests pass" without specifying which tests. `@reviewer` should append a `DoD-missing-tests` finding to `cross_agent_findings.md`. Run scenario 1 again with a similar brief and verify `@groomer` reads the finding and flags item 4 as failing by default.

5. **Loop-cap probe.** Craft a brief where `@executor` and `@reviewer` will disagree for >3 cycles (e.g., a constraint @executor can't satisfy). Verify the orchestrator stops at cycle 3, reads `loop_state.json`, and surfaces to the user.

None of these have been run. The harness in §8 P2 item #12 would automate them.

### 7.3 Things that are verifiable without restart

These can be checked with `Read` tools alone (and were checked while writing this revision):
- File sizes of `architect.md` / `executor.md` after boilerplate removal.
- Tool lists in frontmatter.
- Memory directory consolidation.
- `SessionStart` hook commands in `settings.json`.
- Presence of cross-agent findings file with correct format.
- Presence of version stamps and deferred-items section.
- ARCHITECTURE.md and CLAUDE.md cross-references.

These checks all pass. They do not exercise the prompts.

---

## 8. Prioritized backlog (what's left to do)

The original P0 and P1 sections are mostly gone. The new backlog is what survived plus the previously-deferred items.

### P0 — DONE in follow-up sweep (status: ✅ verified on disk)

All seven items below were applied immediately after this critique was first written. Kept here for the audit trail.

1. ✅ **`@idea` cross-findings reader gap resolved.** `idea.md` has a new `**ON ENTRY**` section that instructs reading `.claude/agent-memory/_shared/cross_agent_findings.md` on every invocation.
2. ✅ **`@groomer` rule #6 contradiction fixed.** Now reads "Don't add new constraints; flag missing structure only" with an explicit note that items 1 and 4 are intentionally about wording quality.
3. ✅ **`@idea`'s "user delegates" edge case promoted to the prompt.** New edge-case bullet covers the "you decide / whatever works / use your judgment" pattern with a defensible-default + one-confirming-question protocol.
4. ✅ **Explicit `tools:` line on `@executor.md`** added, with an inline `# intentionally broad` comment so future maintainers don't restrict it.
5. ✅ **Binary-artifact carve-out** added to the exit protocol: "These rules apply to text artifacts only. Binary artifacts (images, PDFs, archives, executables) ALWAYS take the Large path."
6. ✅ **Hybrid self-verification checklist** added to `architect.md` — 4 items covering: markers placed, partial plan written, cue ends with `[NEEDS USER INPUT:]` only (no `[REFINED]`), questions match the gaps exactly.
7. ✅ **Hybrid-path routing row** added to CLAUDE.md. The `[NEEDS USER INPUT:]` cue now has TWO rows: Path B (re-route to @groomer after @idea) and Hybrid (re-route to @architect after @idea).

### P1 — fix this sprint (moderate effort, real impact)

8. **Build the minimal test harness** described in §7.2. Even three scripted scenarios in `.claude/tests/*.md` with a small driver would catch 80% of prompt regressions. The driver can be a shell script that spawns the orchestrator with the scripted input and grep-asserts on the trace.
9. **Restart-then-run the harness.** Without a restart, no test result is trustworthy. This is the only way to verify the fix sweep actually landed in-flight.
10. **Promote the "Brief Concerns:" footer behavior to a contract.** Reviewer is supposed to append both to the artifact (as footer) and to the shared file. Verify reviewer actually does both, not one-or-the-other.
11. **Investigate whether `description:` is injected into the child agent's context** (see §5.2). One print at child startup answers it. Then decide: split into `.examples.md` sibling files, or leave as-is.
12. **Build the `/calibrate` skill** (deferred item #2). At minimum: read `routing_observations.md`, count tier-1 outcomes with `notes=wrong tier choice in retrospect`, print a ratio. If >20%, recommend threshold tightening. This unlocks the calibration loop that the 90/75/<75 thresholds need.

### P2 — fix this quarter (higher effort, strategic)

13. **Implement the JSONL telemetry migration.** Dual-write for one week, then deprecate the markdown log. Schema is in CLAUDE.md.
14. **Build the `@editor` agent** for prose review. Until it exists, the orchestrator's prose-direct discipline is the only guard against `@reviewer` being mis-applied to prose.
15. **Pre-spawn agent-hash check** (deferred item #5). Maintain `.claude/workspace/agent_hashes.json` per session; warn on mismatch. This makes known-issue #2 enforceable instead of documentation-only.
16. **Garbage-collection mechanism for `cross_agent_findings.md`.** Either a hook, a periodic orchestrator action, or a manual `/rotate-findings` skill.

### P3 — wishlist

17. **`[NEEDS HUMAN REVIEW:]` cue for `@reviewer`** for genuinely under-determined cases.
18. **Frequency-weighted cross-agent findings.** When a failure class recurs N times, promote it from "groomer should defend on each invocation" to "groomer checklist needs a new item." Could be part of `/calibrate`.
19. **Confidence formula for `@idea`** — replace the prose-encoded confidence rule with the numeric formula proposed in the prior critique (20% per directly-supported section, ½ for implicit endorsement).
20. **`@idea` re-entry surgical-questioning rule.** "When re-invoked with `[NEEDS USER INPUT:]`, ask ONLY the architect's questions, in order; floor is prior confidence + 10% per answered question, not 80%."

---

## 9. What this critique did NOT cover

- **Empirical performance.** No data on tier-misclassification rate, brief-rejection rate, or review-loop-length distribution. Telemetry doesn't exist yet.
- **Cost accounting.** The fix sweep reduced architect/executor prompt size by ~140 lines each. The actual token savings per invocation is estimable but unmeasured. Until telemetry exists, the savings are theoretical.
- **Model-tier suitability.** Whether haiku is genuinely competent at `@idea` (vs. just cheap) isn't tested. The fix-sweep did not address this.
- **User-facing UX of Tier 2.** Whether users find "1-3 inline questions" pleasant or annoying isn't measured. Orchestrator discipline assumes yes.
- **Concurrent pipeline runs.** The loop_state.json schema is single-pipeline. FleetView / `/loop` scenarios are out of scope.
- **`/btw` continuity.** The hook deliberately doesn't fire on `resume` / `compact`. This preserves in-flight state, but if a session is `compact`ed mid-pipeline, the loop counts persist correctly but the agent prompts may have been silently re-cached on a different model — untested.
- **The cross-agent findings file under high write volume.** Concurrent Edit-append from two agents (theoretical) would corrupt. Today only `@reviewer` writes during pipeline runs and the orchestrator writes between runs, so collision is unlikely. Flag for the day this changes.

---

## 10. Closing

The pipeline is in noticeably better shape than at the prior critique. The forward-only DAG now has a back-channel (cross-agent findings). The cue protocol is specified. Loop caps are persistent. The auto-memory boilerplate is gone. The fallback `project_plan.md` is no longer a footgun. Each of these was a structural concern in the original critique and each has a concrete fix on disk.

The remaining open issues cluster into three groups:

1. **Untested.** The fix sweep was applied to text and verified by reading. It has not been exercised. Until there is a restart-then-run harness, every fix is "probably works."
2. **Half-applied.** The `@idea` cross-findings reader gap, the groomer rule #6 contradiction, the architect hybrid path's missing self-checklist, the missing executor `tools:` line. None are catastrophic; all are cheap to close.
3. **Deferred.** Test harness, `/calibrate`, `@editor`, agent-hash check, description-splitting investigation. Each unlocks a feedback or safety mechanism that the current design assumes but doesn't enforce.

P0 in §8 is a one-afternoon cleanup pass. P1 is where the real risk reduction is — without the harness, the system is uncalibrated and the prompt-cache bug means it'll stay that way.

See `ARCHITECTURE.md` §4 for the cue state machine, `ARCHITECTURE.md` §5 for the cross-agent learning channel diagram, and `CLAUDE.md` "Deferred items" for the live deferred-work list.

<!-- last-reviewed: 2026-05-28 against claude-opus-4-7 -->
