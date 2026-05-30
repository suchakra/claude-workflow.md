---
name: archetype-unix-clone-script
description: How to refine briefs for "tiny CLI utility that mirrors a Unix tool" (wc/grep/cut clones) when @idea under-specified semantics
metadata:
  type: project
---

Brief archetype: "Python/shell script that does X" where X has an obvious Unix coreutils analogue (`wc`, `grep`, `cut`, `sort`, `head`, `tail`, etc.).

**Why:** When @idea leaves word/line/field semantics, output format, encoding, and error handling unspecified for these scripts, the gaps are almost never user-knowable mysteries — they are answered by "do what the analogue tool does." Bouncing to the user via Path B is wasted round-trips.

**How to apply:**
- Default semantics to the analogue tool's behavior (e.g., `wc -w` uses whitespace-run tokenization → `str.split()` with no args).
- Default output format to "minimal machine-parseable": one value per line, no labels, unless the brief implies a human is reading it.
- Default encoding to UTF-8 strict; decoding errors → exit 1 with stderr message.
- Default exit codes: 0 success, 1 user error, no tracebacks for expected error modes.
- Default location: `scripts/<name>.py` (or `bin/<name>` if the repo already has one) with `#!/usr/bin/env python3` shebang and executable bit.
- Add a verification step that diffs the script's output against the analogue tool on a shared fixture — this catches semantic drift cheaply.

Phase shape that works well: (1) scaffold + argparse + exec bit, (2) core logic, (3) error handling, (4) verification suite. 4 phases is the right size; do not over-decompose tiny utilities into 6+.
