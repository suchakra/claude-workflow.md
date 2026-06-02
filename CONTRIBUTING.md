# Contributing

Thanks for your interest. This is a small experiment — contributions welcome, expectations low.

## What's useful

- **Bug reports** — something breaks, a claim in the docs is wrong, the pipeline misbehaves. Open an issue with the request you sent, what you expected, and what happened.
- **Real-world calibration data** — if you use this on a project and the tier thresholds feel off, share the pattern. The routing logic is tunable.
- **Agent prompt improvements** — if you find a class of request that consistently confuses `@groomer` or `@reviewer`, a concrete example + a proposed fix is the most useful form.

## What probably isn't

- Framework abstractions, plugin systems, config file formats. The whole point is that it's just markdown — adding machinery defeats that.
- Support for other AI providers. This is Claude Code-specific by design.

## How to submit changes

Standard fork + PR. No CLA, no formal review process. Keep diffs small and focused; a PR that fixes one thing is easier to reason about than one that fixes five.

If you're unsure whether something is worth a PR, open an issue first.
