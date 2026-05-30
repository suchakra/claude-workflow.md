# Cross-agent findings

Append-only log where one agent's discovery influences another agent's next invocation.
The pipeline is otherwise forward-only; this file is the back-channel.

## Read protocol
- `@groomer`, `@idea`, `@architect` read this file at the start of every invocation.
- Treat the last 20 entries as the active context. Older entries are historical.

## Write protocol
- `@reviewer` appends when a failure traces to a **brief-level** gap (not an artifact-level bug).
- The orchestrator appends when a routing decision turned out wrong in retrospect.
- Other agents do not write here.

## Record format

```
## <iso-timestamp> | <writer-agent> → <reader-agent(s)>
**Failure class:** <short label, e.g. "DoD-missing-tests", "constraint-implicit-only">
**Evidence:** <one-line citation, e.g. "brief said 'tests pass' but never defined the suite">
**Recommendation:** <one-line for the reader, e.g. "add to groomer item-4 examples">
```

Each record is one H2 + three labeled lines. Keep it terse.

## Garbage collection

The orchestrator checks the record count at the start of every Tier 3 pipeline invocation (counting `^## ` headers). If count > 200, the oldest 100 records are moved to `cross_agent_findings.archive.md` (created if absent) before any agent reads the file in that pipeline.

## Log

(no entries yet)
