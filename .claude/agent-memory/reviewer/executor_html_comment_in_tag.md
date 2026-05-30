---
name: executor-html-comment-in-tag
description: Recurring @executor bug — HTML comments placed between attributes inside a start tag, which breaks parsing and leaks visible text
metadata:
  type: feedback
---

When @executor produces HTML templates with inline TODO guidance, it sometimes places an HTML comment (`<!-- ... -->`) *between attributes inside a start tag* rather than before/after the element. Example seen in portfolio/index.html: a multi-line `<!-- TODO: configure form action -->` comment sitting inside the `<form ...>` open tag.

**Why this is a hard defect, not style:** Per the HTML5 tokenizer, `<` inside a start tag begins a bogus attribute name; the first `>` (the one in `-->`) prematurely closes the tag, and any remaining comment text after it renders as visible literal page content. It also silently drops intended attributes.

**How to apply:** When reviewing any HTML artifact, grep for `<!--` occurring inside an open tag region (e.g. between `<form` / `<input` / `<div` and its closing `>`). The correct pattern is to put the guidance comment on the line BEFORE the element or as a sibling, never between attributes. Flag as `[CHANGES REQUESTED]` with the file:line of the offending tag.
