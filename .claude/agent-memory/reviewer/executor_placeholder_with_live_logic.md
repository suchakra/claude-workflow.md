---
name: executor-placeholder-with-live-logic
description: When a brief asks for a "placeholder comment / no JS submit logic", @executor may wrap the comment inside a live attribute (e.g. onsubmit="/* TODO */ return false;") — the executable bit violates the constraint
metadata:
  type: feedback
---

When a brief specifies a handler should be "left as a placeholder comment (no JS submit logic)", @executor sometimes satisfies the *comment* part but smuggles in executable code around it — observed: `onsubmit="/* TODO: replace... */ return false;"`. The `return false;` is live JS submit logic, which the brief explicitly forbade.

**Why:** @executor reads "placeholder comment" and adds the comment, but also wants the form to behave (not navigate away), so it adds suppression logic. The constraint said no JS submit logic at all.

**How to apply:** Grep for `onsubmit=`, `onclick=`, addEventListener('submit') in any artifact whose brief asked for a comment-only handler. A bare comment with zero executable statements is the only compliant form; any `return false`, `preventDefault`, or fetch call is a violation even when a comment is present.
