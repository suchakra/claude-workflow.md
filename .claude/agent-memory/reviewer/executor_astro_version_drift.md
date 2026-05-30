---
name: executor-astro-version-drift
description: When a brief pins a major version (e.g. Astro 5.x), @executor often scaffolds with `npm create astro@latest` and lands on a newer major; always diff declared vs required version
metadata:
  type: feedback
---

When a brief pins a specific major version of a scaffolding-driven framework (e.g. "Astro 5.x"), @executor frequently runs the generic `create@latest` scaffold and ends up on whatever major is current — observed: brief said Astro 5.x, package.json shipped `astro@^6.4.2`.

**Why:** `npm create astro@latest` resolves to the newest major, ignoring the brief's pin. The drift is invisible unless you read package.json AND node_modules/<pkg>/package.json — the source code looks correct.

**How to apply:** On any framework-version-constrained brief, grep package.json for the dependency and check `node_modules/<dep>/package.json` "version" against the brief. A newer major can also raise the Node engine floor (Astro 6 needs Node >=22.12), making `astro build` hard-fail on common Node 18 LTS even though it passes on a newer local Node. Always note which Node version your build ran under.
