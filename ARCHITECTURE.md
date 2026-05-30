# claude-workflow.md — Architecture

This document explains how the orchestrator and the 5-agent pipeline cooperate. For the operational rules, see `CLAUDE.md`. For the rationale-and-critique knowledgebase, see `.claude/knowledgebase/agent_critique.md`.

**Last-reviewed:** 2026-05-28 against `claude-opus-4-7`.

---

## 1. System at a glance

```mermaid
flowchart LR
    U([User]) --> O{Orchestrator<br/>opus 4.7}
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

ASCII fallback:

```
                    ┌───────────────┐
                    │     User      │
                    └───────┬───────┘
                            │
                    ┌───────▼────────┐
                    │  Orchestrator  │  (opus 4.7, the main session)
                    │  3-tier router │
                    └───┬────┬────┬──┘
                Tier 1  │    │    │  Tier 3
                        │    │ Tier 2: orchestrator
                        │    │ asks user 1-3 Qs
                        │    │ then routes Tier 1 or Tier 3
                        ▼    ▼    ▼
            ┌───────────────────┐  ┌──────────┐
            │ direct edit       │  │ @idea    │ haiku
            │   OR              │  │ interview│
            │ @executor sonnet  │  └────┬─────┘
            │  + @reviewer opus │       │ [BRIEF READY]
            └───────────────────┘       ▼
                                   ┌──────────┐
                                   │ @groomer │ sonnet
                                   │ audit    │
                                   └────┬─────┘
                            [GROOMED]   │   [NEEDS REFINEMENT]
                              ┌─────────┴─────────┐
                              │                   ▼
                              │             ┌──────────┐
                              │             │@architect│ opus
                              │             │ refine   │
                              │             └────┬─────┘
                              │       [REFINED]  │  [NEEDS USER INPUT]
                              │           ┌──────┘
                              ▼           ▼              └──→ back to @idea
                          ┌──────────┐
                          │ @executor│ sonnet
                          │ build    │
                          └────┬─────┘
                               │ [ARTIFACT READY]
                               ▼
                          ┌──────────┐
                          │ @reviewer│ opus
                          │ audit    │
                          └────┬─────┘
                  [APPROVED]   │   [CHANGES REQUESTED]
                       │       └─→ back to @executor
                       ▼
                    user gets the artifact
```

---

## 2. The 3-tier routing decision

Every user request enters this decision tree BEFORE any tool use.

```mermaid
flowchart TD
    Start([User request]) --> Conf{Orchestrator<br/>confidence?}
    Conf -- ≥ 90% --> T1{Artifact size?}
    Conf -- 75-89% --> T2[Tier 2:<br/>ask 1-3 questions inline]
    Conf -- &lt; 75%<br/>OR user delegates<br/>OR multiple unknowns --> T3[Tier 3:<br/>spawn @idea]
    T1 -- &lt; 10 lines,<br/>mechanical --> D1[Direct build<br/>orchestrator writes]
    T1 -- ≥ 10 lines<br/>OR control flow<br/>OR new file --> D2[Hand off to<br/>@executor + @reviewer]
    T2 -- resolved → trivial --> D1
    T2 -- resolved → non-trivial --> D2
    T2 -- still &lt; 90% after 3 Qs --> T3
    T3 --> Pipeline[5-agent pipeline]
```

**Why three tiers?** Cost asymmetry. Opus is expensive, sonnet is mid, haiku is cheap. A request the orchestrator (opus) can answer alone shouldn't spawn anyone. A trivial edit doesn't need a sonnet review. A genuinely ambiguous request needs a structured interview, which haiku is competent for and cheap at. The tiers route work to the cheapest competent tier.

| Tier | Confidence | Cost profile | What runs |
|---|---|---|---|
| 1 (direct) | ≥ 90% | One opus turn (if mechanical) or 1 opus + 1 sonnet handoff + 1 opus review (if ≥ 10 lines) | orchestrator alone, OR orchestrator + @executor + @reviewer |
| 2 (inline triage) | 75-89% | Same as Tier 1 plus 1-3 conversational turns | orchestrator + user dialogue, then Tier 1's two paths |
| 3 (full pipeline) | < 75% | ≥ 5 agent spawns (haiku + sonnet + opus + sonnet + opus) | the full pipeline below |

**Tier 1's "Tiny vs Larger" split** is itself a sub-router: tiny work stays on opus (faster end-to-end); larger work hands off to sonnet for the build and opus for the review (cheaper per token + catches bugs).

---

## 3. Full pipeline sequence (Tier 3)

```mermaid
sequenceDiagram
    autonumber
    actor U as User
    participant O as Orchestrator (opus)
    participant I as @idea (haiku)
    participant G as @groomer (sonnet)
    participant A as @architect (opus)
    participant E as @executor (sonnet)
    participant R as @reviewer (opus)

    U->>O: vague request
    O->>I: spawn (Tier 3)
    loop interview
        I->>U: 1 question
        U->>I: 1 answer
    end
    I-->>O: [HAND-OFF BRIEF] + [BRIEF READY] confidence=N
    Note over O: anti-fab check:<br/>was an interview held?
    O->>G: brief + project_plan.md
    alt brief is groomed
        G-->>O: [GROOMED]
        O->>E: brief + plan
    else needs refinement
        G-->>O: [NEEDS REFINEMENT: ...]
        O->>A: brief + plan + groomer reasons
        alt architect can infer
            A-->>O: refined brief + [REFINED]
            O->>E: refined brief + plan
        else architect needs user
            A-->>O: questions + [NEEDS USER INPUT: ...]
            O->>I: bounce questions (loop cap: 3)
        else hybrid
            A-->>O: partial brief + [NEEDS USER INPUT: ...]
            O->>I: bounce residual questions
        end
    end
    E-->>O: artifact + [ARTIFACT READY]
    O->>R: brief + plan + artifact
    loop review (cap: 3)
        alt approved
            R-->>O: [APPROVED]
        else changes
            R-->>O: [CHANGES REQUESTED: ...]
            O->>E: artifact + changes
            E-->>O: revised + [ARTIFACT READY]
            O->>R: re-review
        end
    end
    O->>U: deliver artifact
```

**Loop caps** (3 cycles each) are enforced by the orchestrator using `.claude/workspace/loop_state.json`. Working memory is unreliable across context compaction; the file is authoritative.

---

## 4. Cue state machine

The agents communicate exclusively via bracketed cues parsed by the orchestrator. Last-occurrence wins.

```mermaid
stateDiagram-v2
    [*] --> IdeaInterview: Tier 3 spawn
    IdeaInterview --> Groom: [BRIEF READY] (initial or post-Path-B re-emit)
    IdeaInterview --> Refine: [BRIEF READY] (post-Hybrid re-emit)
    Groom --> Execute: [GROOMED]
    Groom --> Refine: [NEEDS REFINEMENT:]
    Refine --> Execute: [REFINED]
    Refine --> IdeaInterview: [NEEDS USER INPUT:] (Path B — body has no PENDING markers)
    Refine --> IdeaInterview: [NEEDS USER INPUT:] (Hybrid — body has PENDING markers)
    Execute --> Review: [ARTIFACT READY]
    Execute --> Halted: "EXECUTION BLOCKED:"
    Review --> Done: [APPROVED]
    Review --> Execute: [CHANGES REQUESTED:]
    Done --> [*]
    Halted --> [*]

    note right of IdeaInterview
        Post-Hybrid re-emit goes back to
        @architect to resolve PENDING
        markers before reaching @groomer.
    end note
```

| Cue | Emitter | Routes to |
|---|---|---|
| `[BRIEF READY] confidence=N` | @idea | @groomer |
| `[GROOMED]` | @groomer | @executor |
| `[NEEDS REFINEMENT: reasons]` | @groomer | @architect |
| `[REFINED]` | @architect | @executor |
| `[NEEDS USER INPUT: questions]` | @architect | @idea |
| `[ARTIFACT READY]` | @executor | @reviewer |
| `EXECUTION BLOCKED: reason` | @executor | user (halt) |
| `[APPROVED]` | @reviewer | user (done) |
| `[CHANGES REQUESTED: list]` | @reviewer | @executor |

**Parser rules:**
- Last occurrence in the response wins (lets the model think then commit).
- Distinct cue prefixes required. `[NEEDS REFINEMENT:` vs `[NEEDS USER INPUT:` diverge at the second word — match the full cue name, not the `[NEEDS ` prefix.
- Mutually exclusive cues within an agent's turn.

---

## 5. Cross-agent learning channel

The pipeline is forward-only, but `@reviewer` and the orchestrator can leave breadcrumbs that `@groomer`, `@idea`, and `@architect` read on entry.

```
                 ┌─────────────┐
                 │  @reviewer  │ writes failure class
                 └──────┬──────┘
                        │ Edit (append)
                        ▼
   ┌────────────────────────────────────────┐
   │ .claude/agent-memory/_shared/          │
   │   cross_agent_findings.md              │
   │                                        │
   │   ## 2026-05-28T... | @reviewer → @groomer │
   │   **Failure class:** DoD-missing-tests │
   │   **Evidence:** ...                    │
   │   **Recommendation:** ...              │
   └────────────────────────────────────────┘
                        │ Read (last ~20)
              ┌─────────┼─────────┐
              ▼         ▼         ▼
        ┌─────────┐ ┌──────┐ ┌──────────┐
        │@groomer │ │@idea │ │@architect│
        └─────────┘ └──────┘ └──────────┘
```

This is the only path by which one agent's discovery influences another's behavior across invocations.

---

## 6. File and directory layout

```
claude-workflow.md/
├── ARCHITECTURE.md                ← this file
├── CLAUDE.md                       ← operational rules (routing, cues, loops, hooks)
└── .claude/
    ├── agents/                     ← agent prompt files
    │   ├── idea.md      (haiku)
    │   ├── groomer.md   (sonnet)
    │   ├── architect.md (opus)
    │   ├── executor.md  (sonnet)
    │   └── reviewer.md  (opus)
    ├── agent-memory/               ← per-agent persistent memory
    │   ├── _shared/
    │   │   └── cross_agent_findings.md
    │   ├── idea/
    │   ├── groomer/         (created on first write)
    │   ├── architect/
    │   ├── executor/        (created on first write)
    │   └── orchestrator/
    │       └── routing_observations.md
    ├── knowledgebase/
    │   └── agent_critique.md       ← deep-critique knowledgebase
    ├── workspace/                  ← per-session runtime state
    │   ├── project_plan.md         (created by @idea/@architect)
    │   └── loop_state.json         (created by orchestrator)
    ├── settings.json               ← hooks
    └── settings.local.json         ← user-scoped settings
```

**State purity:** `.claude/workspace/` is treated as scratch — the `SessionStart` hook wipes `project_plan.md`, the fallback `.claude/project_plan.md`, and `loop_state.json` on `startup` and `clear` events. Persistence lives in `agent-memory/`.

---

## 7. Hooks

`.claude/settings.json` installs one `SessionStart` hook with two matchers (`startup`, `clear`). Each clears stale per-session state:

```mermaid
sequenceDiagram
    participant H as SessionStart hook
    participant FS as Filesystem
    Note over H: matcher: startup OR clear
    H->>FS: rm -f .claude/workspace/project_plan.md
    H->>FS: rm -f .claude/project_plan.md
    H->>FS: rm -f .claude/workspace/loop_state.json
    Note over H: deliberately NOT fired on resume / compact<br/>(those preserve in-flight pipeline state)
```

Why two matchers but identical commands: `startup` fires on fresh `claude` invocation, `clear` fires on `/clear`. Both are "fresh context" boundaries where keeping yesterday's plan is harmful. `resume` and `compact` deliberately don't fire because an in-flight plan IS still relevant context.

---

## 8. Model-tier rationale

| Agent | Model | Why this tier |
|---|---|---|
| @idea | haiku | Interviews are social/structural, not analytical. Haiku is competent and 5-10× cheaper than opus. |
| @groomer | sonnet | The right test of "can this be built?" is run by the SAME model that will build it. Maps 1:1 to @executor's actual capability. |
| @architect | opus | Catching design-phase bugs is much cheaper than fixing them after the build. One opus pass < several executor re-runs. |
| @executor | sonnet | Build cost. Sonnet output is ~5× cheaper than opus per token, and the brief constrains scope tightly enough that opus reasoning depth is overkill. |
| @reviewer | opus | Review quality depends on (a) catching subtle bugs and (b) communicating them precisely. Opus depth + writing clarity are both load-bearing. |
| orchestrator | opus 4.7 | Routes everything; needs strong judgment on tier classification and cue parsing. |

---

## 9. Known issues, workarounds, and deferred items

See `CLAUDE.md` sections **Known issues & workarounds** and **Deferred items** for the live list. Highlights:

- **Agent-prompt cache:** edits to `.claude/agents/*.md` do not take effect until session restart. Version stamps at the bottom of each agent file mark the last review date.
- **Stale plan defense:** the `SessionStart` hook now wipes both candidate plan paths plus `loop_state.json`. The orchestrator additionally does a positive-confirmation Read after `@idea` returns.
- **Deferred (intentionally not built yet):** pipeline test harness, `/calibrate` skill, `@editor` agent for prose, description-splitting investigation, pre-spawn agent-hash check.

---

## 10. Reading order for newcomers

1. **`ARCHITECTURE.md`** (this file) — what the system IS.
2. **`CLAUDE.md`** — operational rules the orchestrator follows.
3. **`.claude/knowledgebase/agent_critique.md`** — what's wrong with it and what would make it better.
4. **`.claude/agents/*.md`** — the actual prompts, in order of pipeline appearance.

<!-- last-reviewed: 2026-05-28 against claude-opus-4-7 -->
