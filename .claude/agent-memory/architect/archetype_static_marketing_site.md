---
name: archetype-static-marketing-site
description: Inference defaults for static Astro/SSG marketing-site briefs — version, logo source, and animation-trigger ambiguities that recur
metadata:
  type: feedback
---

For static-site-generator marketing briefs (Astro/SSG), these gaps recur and are almost always inferable rather than user-bounce-worthy:

- **Unspecified framework version** → default to `@latest` stable (Astro 5.x as of 2026), and make static output explicit (`output: 'static'`). Don't bounce.
- **"Publicly available logos" / brand icons with no named source** → default to **simple-icons** (MIT-licensed, npm + jsDelivr CDN). Safe because decorative/faded background usage is low-risk. Don't bounce.
- **Animation trigger ambiguity (continuous vs scroll-triggered)** → resolve from the user's descriptive language. A "zooming through an asteroid belt" / immersive description = continuous loop; withdraw any "or on scroll if preferred" hedge. Don't bounce.

**Why:** @groomer flags these as "executor must not guess," but they have established safe defaults; bouncing them to the user is the trivial-gap anti-pattern (rule #6).

**How to apply:** When a web-build brief has only these classes of gap, take Path A ([REFINED]), not Path B. Reserve user-bounce for genuinely unknowable items (business rules, real testimonial/credential content, brand voice).

Typical phase shape: setup/config → section scaffold → per-feature animation/interaction phases → secondary content/forms → responsive+QA. ~7 phases.
