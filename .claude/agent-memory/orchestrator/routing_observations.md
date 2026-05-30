# Orchestrator routing observations

Append-only log of every Tier 1 (direct) and Tier 2 (inline triage) routing decision.
This preserves the pattern-learning surface that @idea's memory would otherwise capture,
for the requests that never reached @idea.

Tier 3 routes (full pipeline) are NOT logged here — they live in @idea's memory.

## Format

One line per request. Pipe-separated, in this column order:

```
- <date> | tier <1|2> | <build-path: direct | handoff-to-executor | escalated> | <one-line classification of request> | est=<N> lines | actual=<N> lines | model=<opus|sonnet|haiku> | questions=<none | "Q1" → "A1"; "Q2" → "A2"> | notes=<free-form, optional>
```

Column meanings:

- **date**: ISO format `YYYY-MM-DD`
- **tier**: 1 (direct) or 2 (inline triage). Tier 3 routes are not logged here.
- **build-path**: `direct` (orchestrator built itself), `handoff-to-executor` (routed to @executor), or `escalated` (Tier 2 → Tier 3 because confidence stayed low)
- **classification**: terse description (e.g., "rename variable", "config tweak", "small CLI utility")
- **est**: orchestrator's estimate of artifact size in lines BEFORE building (the prediction we're validating)
- **actual**: measured artifact size in lines AFTER building. For mechanical edits, count lines changed.
- **model**: which model actually produced the artifact (opus if direct, sonnet if handed to @executor, etc.)
- **questions**: for tier 2, the inline questions and user answers; `none` for tier 1
- **notes**: anything anomalous worth flagging in retrospect (e.g., "executor overshot by 3×", "user later requested changes", "wrong tier choice in retrospect")

The `est` vs. `actual` columns are the primary telemetry: they tell us if the orchestrator's size estimates are reliable enough to drive the build-path decision in CLAUDE.md Tier 1.

**Dual-write (since 2026-05-29):** every entry appended here MUST also be appended as one JSON object to `.claude/orchestrator_telemetry.jsonl` (schema in CLAUDE.md → "Telemetry roadmap"). This human-readable log remains the primary, authoritative surface; the JSONL is the queryable mirror. The markdown is NOT scheduled for deprecation — it is retained indefinitely.

## Review cadence

Re-read this file when:
- It has >50 entries (look for misclassification clusters)
- A Tier 1/2 decision recently produced a wrong artifact (was the gray-zone bias rule violated?)
- The tier thresholds in CLAUDE.md need recalibration

## Log

- 2026-05-28 | tier 1 | direct | apply @architect's 3-part hardening to `.claude/agents/idea.md` (anchor confidence to evidence, tighten "everything upfront" edge case, add 2 checklist gates) | est=15 lines | actual=11 lines changed | model=opus | questions=none | notes=user explicitly delegated by saying "apply it"; @architect did the design pass, orchestrator did mechanical apply
- 2026-05-28 | tier 2 | direct | write deep critique knowledgebase of all 5 agents + CLAUDE.md → `.claude/knowledgebase/agent_critique.md` | est=400 lines | actual=~340 lines | model=opus | questions="scope?" → "critique + concrete fixes"; "location?" → ".claude/knowledgebase/agent_critique.md"; "tone?" → "direct, no hedging" | notes=initially spawned @idea on bare "build me something useful" prompt; after user specified scope, switched to Tier 2 + orchestrator-direct because the task is opus-grade analytical prose, not code (and per the critique itself, @reviewer is mis-calibrated for prose review)
- 2026-05-28 | tier 1 | direct | apply ALL P0-P3 fixes from agent_critique.md across `.claude/agents/*.md`, CLAUDE.md, settings.json, agent-memory/ + write ARCHITECTURE.md + spawn @architect to regenerate the critique + apply 7 P0 residuals @architect discovered during regen | est=~400 lines changed across ~10 files | actual=~600 lines net across 11 files (5 agents + CLAUDE.md + settings.json + ARCHITECTURE.md + agent_critique.md + cross_agent_findings.md + this log) | model=opus (orchestrator) + opus (@architect for critique regen) | questions=none | notes=user explicitly delegated ("fix all of those, retest"). "Retest" interpreted as disk-state validation only — true in-flight pipeline test requires Claude Code restart (cached agent prompts per known-issue #2). Architect regen surfaced 7 residuals (mostly previously-noted items only half-applied); knocked out in a follow-up sweep before reporting back.
- 2026-05-28 | tier 1 | handoff-to-executor | Python CLI: count unique IPs in nginx access log + top-N report | est=~40 lines | actual=unknown (not recorded at handoff) | model=sonnet | questions=none | notes=reformatted 2026-05-29 to match the 9-column schema in this file's header; original line followed CLAUDE.md's outdated 5-field snippet (since reconciled)
- 2026-05-29 | tier 1 | direct | fix malformed routing-log line + JSONL telemetry migration (backfill 4 entries, wire dual-write, reconcile CLAUDE.md schema) | est=~30 lines | actual=~25 lines across CLAUDE.md + this file + new orchestrator_telemetry.jsonl | model=opus | questions=none | notes=user delegated ("fix routing-log; do the jsonl migration") + follow-up "dont deprecate markdown yet"; dual-write now live, markdown retained indefinitely as primary; added build_path field to JSONL schema (markdown's load-bearing column, absent from the roadmap sketch)
- 2026-05-29 | tier 3 | escalated | new-website-astro-marketing-funnel | est=200 lines | actual=null | model=sonnet | questions="What is the purpose?" → "embraceai.ca fractional AI consulting", "Same tech as portfolio?" → "astro static", "Core sections?" → "all + detailed visual design", "Success metric?" → "visual appeal, static prototype, no errors" | notes=full-pipeline; groomer flagged 3 items (astro version, logo source, animation trigger); architect resolved all 3 inline (Path A); executor overshot to astro@6 on first pass (pinned to 5.x on revision); reviewer approved after 2 cycles
