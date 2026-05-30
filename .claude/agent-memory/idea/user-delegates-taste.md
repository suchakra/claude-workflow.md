---
name: user-delegates-taste
description: User signals delegation of taste (explicit "I don't know" or trust-implying metaphors) → stop interviewing, pick defaults, note them in the brief
metadata:
  type: feedback
---

When the user signals they are delegating taste/judgment to you, stop asking clarifying questions and switch to default-picking. Trigger signals include:

- Explicit delegation: "I don't know", "you choose", "whatever you think is best", "up to you"
- Trust-implying metaphors: e.g., *"I sweep tiny dust from the floor, but of course I move out broken furniture first"* (signals: trust your prioritization, focus on biggest-impact first)
- Combinations of "I don't know" answers across multiple consecutive questions on the same dimension

**Why:** Continuing the interview after delegation has been signaled is friction that produces no new information. The user has already told you they trust your judgment on the remaining knobs. Confidence is climbing on the *meta* axis (trust granted), so the brief is closer to ready than the per-knob count suggests. Documented incident: smoke test on 2026-05-28, request "Help me write a small script to clean up something on my machine", user delegated at Q4 with the dust/furniture metaphor — proceeding with defaults produced a clean single-pass execution.

**How to apply:**
1. When a delegation signal fires, do NOT ask the next planned clarifying question.
2. Pick concrete defaults for every remaining unknown. Bias toward the most common, most useful interpretation in the project's context.
3. In the brief's **Strict Constraints** list, name every default you picked, prefixed with "default:" so downstream agents (@groomer, @architect, @reviewer) know which dimensions were not user-chosen. Example: `- default: top-N = 50 (user delegated, no count specified)`.
4. In the **Idea's Confidence** section of `project_plan.md`, set the lowest-confidence area to the highest-stakes delegated dimension. This tells @groomer where to audit hardest.
5. Confidence score can be reported normally (e.g., 80-85%) — delegation does not lower confidence, it just shifts the locus of decision-making.

**Edge cases:**
- If the user *partially* delegates (gives some details, delegates the rest), apply this pattern only to the delegated portion.
- If the user later objects to a default you picked, treat that as a normal pivot — reset confidence on that dimension and re-interview.
- Distinguish delegation ("I don't know, you pick") from genuine uncertainty about their own needs ("I'm not sure what I want") — the latter warrants more interviewing, not less.
