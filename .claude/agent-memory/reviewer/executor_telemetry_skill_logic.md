---
name: executor-telemetry-skill-logic
description: When @executor writes analytics/report skills over the telemetry JSONL, validate filter logic against the ACTUAL data file, not just the schema — empty filtered sets and notes-vs-error conflation are recurring bugs
metadata:
  type: feedback
---

When @executor (or the orchestrator) writes a skill/command that aggregates over `.claude/orchestrator_telemetry.jsonl`, run the skill's filter logic mentally against the *actual* rows, not just the schema. Two recurring bugs that pass a schema-only reading but fail on real data:

1. **`anomalies` non-empty ≠ error.** CLAUDE.md's schema says `anomalies` "carries what the markdown `notes` column carried." Most real entries have benign routing notes (e.g. "user delegated", "2-review-cycles"). A skill that counts array-non-empty as an anomaly reports ~100% anomaly rate and any "≤ 20%" verdict gate becomes unreachable. Correct logic gates on the *named* error labels (`idea-fabrication-rejected`, `architect-too-many-questions`).

2. **Per-section empty filtered sets.** A global "< 3 total entries" guard does NOT protect a section that filters to a narrow predicate. Example: filtering `build_path=="handoff-to-executor" AND actual_lines non-null` yields an empty set on the current data (the only handoff row has `actual_lines:null`), so MAE/bias are undefined despite 6 total rows.

**Why:** both bugs are invisible when reviewing the skill against the schema alone; they only surface when you replay the filter over the real `orchestrator_telemetry.jsonl`. Caught in the /calibrate skill meta-review, 2026-06-01.

**How to apply:** for any telemetry/analytics skill, read the JSONL data file and trace each section's filter to confirm (a) the filtered set is non-empty on current data and (b) any threshold/verdict gate is reachable. Also confirm error-counting distinguishes named anomaly labels from free-form notes.
