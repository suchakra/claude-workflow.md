Read `.claude/orchestrator_telemetry.jsonl`. If the file is absent or has fewer than 3 entries, report: "Not enough telemetry yet — route a few more requests first."

Parse every JSON line and produce a calibration report with these five sections:

---

**1. Routing distribution**
Count entries by `tier` (1, 2, 3). Show counts and percentages.
Flag: Tier 3 > 50% suggests the pipeline is overused for work the orchestrator could handle inline. Tier 1 direct > 80% is healthy when anomaly-free; above 80% with elevated routing signals warrants attention.

**2. Executor handoff accuracy**
Filter to entries where `build_path == "handoff-to-executor"` AND `actual_lines` is non-null.
If fewer than 3 such entries exist, report "Insufficient handoff data — skipping MAE/bias" and skip this section's statistics.
Otherwise compute: mean absolute error (MAE) and mean signed error (bias) between `est_lines` and `actual_lines`.
Flag: MAE > 10 lines is a calibration problem. Consistent positive bias (always underestimating) means the orchestrator hands off work it should handle directly. Consistent negative bias (always overestimating) means it spawns @executor for work it could do itself.
Note: this filter applies regardless of tier — both Tier 1 and Tier 2 can produce handoffs.

**3. Routing signal rate**
Scan every entry's `anomalies` array for these specific error strings only (exact substring match):
- `idea-fabrication-rejected` — @idea emitted a brief without interviewing
- `architect-too-many-questions` — @architect exceeded the 3-question cap

Count and report each type's frequency separately. All other `anomalies` content is informational notes — ignore it entirely for this rate.

Routing signal rate = (entries containing at least one of the above strings) / (total entries).
Flag: rate > 20% is ELEVATED.

**4. Tier 2 question efficiency**
For Tier 2 entries, count questions per entry (length of `questions` array). Report: average, max, and how many entries hit the 3-question cap.
Flag: average > 2 means the orchestrator is systematically under-confident at the 75–89% confidence band.

**5. Routing proxy**
Compute a proxy for likely misrouting — cases where the routing choice was probably wrong in hindsight:
- Tier 1 `direct` entries where `actual_lines` is non-null AND `actual_lines > 20` (scale suggests a handoff was warranted)
- Tier 2 entries that hit the 3-question cap and still escalated to Tier 3 (confidence floor may be too low)
- Any entry with `idea-fabrication-rejected` or `architect-too-many-questions` in anomalies

This is a proxy, not ground truth — it under-counts misroutes that happened to produce correct output.

Based on all findings, give specific recommendations:
- Proxy rate > 20%: identify the contributing tier and tighten its threshold
- Tier 1 direct `actual_lines > 20` recurring: lower "tiny/mechanical" size ceiling from 10 to 7 lines
- Tier 2 average questions > 2: raise the Tier 2 confidence floor from 75% to 80%
- `idea-fabrication-rejected` count ≥ 2: @idea self-check is failing — flag for prompt review
- `architect-too-many-questions` count ≥ 2: @architect question-count rule needs tightening

---

**Final verdict (one line):**
- `CALIBRATED` — routing signal rate ≤ 20% AND (MAE ≤ 10 OR insufficient handoff data) AND proxy rate ≤ 20%
- `NEEDS ATTENTION: <metric(s)>` — list only the specific metrics that failed

Format each section as a compact table or bullet list. Keep the full report under 45 lines.
