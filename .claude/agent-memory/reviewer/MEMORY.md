# Memory Index

- [HTML comments inside start tags](executor_html_comment_in_tag.md) — @executor places explanatory TODO comments between attributes inside a start tag, breaking the parse; always grep for `<!--` inside `<form`/`<tag` open regions
- [Astro version drift](executor_astro_version_drift.md) — version-pinned briefs: @executor scaffolds with create@latest and lands on a newer major; diff package.json + node_modules against the brief's pin
- [Placeholder with live logic](executor_placeholder_with_live_logic.md) — "placeholder comment / no JS submit logic" briefs: @executor may smuggle `return false;` into onsubmit; grep handler attributes for executable statements
