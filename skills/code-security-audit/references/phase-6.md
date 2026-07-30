<!-- BEGIN VERBATIM CARVE src=code-security-audit.md lines=916-1008 sha256=a39f4fa9bfacfab8f7a12dfb6809612b44090f41bdd9848dabd9cc9eb8d2a856 -->
### PHASE 6 -- COMPARISON HTML RENDER (COORDINATED mode only)

In STANDALONE mode, Phase 6 is SKIPPED entirely. The audit ends at Phase 5.

Phase 6 exists as a separate phase from Phase 5 because Phase 5's accumulated work (consolidated report HTML, executive briefing HTML, comparison Markdown, C4 architecture, security_architecture_audit update) typically consumes 70-80% of a session's response budget by the time the Markdown comparison is complete. The remaining session budget is not enough to reliably produce a complete comparison HTML via scaffold-and-fill (seven tool calls of substantial content each). Phase 6 gets its own fresh session budget for the HTML rendering work.

INPUT (ALL REQUIRED):
- audit_state/coordination_mode.md (MODE must be COORDINATED; if STANDALONE, STOP with error)
- audit_state/threat_audit_comparison.md (must exist and be non-empty)

PRE-FLIGHT CHECKS:

Read `audit_state/coordination_mode.md` first. If MODE is STANDALONE, STOP immediately and report: "Phase 6 invoked but coordination mode is STANDALONE. Phase 6 is only relevant when a threat model exists. The audit is already complete after Phase 5; no further work is needed."

Read `audit_state/threat_audit_comparison.md`. If the file is missing or empty, STOP and report: "Phase 6 invoked but the comparison Markdown intermediate is missing or empty. Phase 5 did not produce the required input. Re-run Phase 5 (which will rebuild the Markdown from findings_registry.md and the threat model)."

CRITICAL EXECUTION DISCIPLINE:

Phase 6 produces the comparison HTML using a scaffold-and-fill pattern. Minimize preamble before producing each tool call. Do NOT write extensive prose describing what the HTML will contain before producing it. Each tool call is small and bounded; the budget concern in Phase 6 is the number of calls accumulated across the phase, not the size of any one call.

Do NOT re-think, re-summarize, or compress content during HTML rendering. The Markdown intermediate is authoritative. Each fill takes its section's existing content and wraps it in HTML markup. If you find yourself shortening entries to "fit" during rendering, STOP -- you are doing the wrong thing. The whole point of the scaffold-and-fill approach is that each fill has enough budget to render its section's content faithfully.

STEP 1 -- Write the HTML skeleton.

Use `create_new_file` to write `audit_state/threat_audit_comparison.html` containing:
- Full DOCTYPE and `<html>` opening
- `<head>` with `<meta charset="UTF-8">`, title, and complete inline `<style>` block covering severity colors (Critical #b00020, High #e65100 -- per SEVERITY SCOPE no other severities exist in audit content), system-ui font stack, print-friendly layout, sticky left-side TOC
- `<body>` opening
- Title heading and a brief introductory paragraph (1-2 sentences identifying this as the headline deliverable of the audit)
- A `<nav class="toc">` element containing a placeholder comment
- A `<main>` element containing one `<section>` per content area, each with its heading and a unique placeholder comment

The seven placeholder comments to include in the skeleton, in order:
1. `<!-- COMPARISON-TOC -->` (inside the `<nav>`)
2. `<!-- COMPARISON-EXECUTIVE-SUMMARY -->`
3. `<!-- COMPARISON-CONFIRMED-THREATS -->`
4. `<!-- COMPARISON-UNCONFIRMED-THREATS -->`
5. `<!-- COMPARISON-UNANTICIPATED-FINDINGS -->`
6. `<!-- COMPARISON-PARTIAL-MATCHES -->`
7. `<!-- COMPARISON-COVERAGE -->`

The skeleton itself is small (5-10KB) and reliably fits in one call. Section 6 (Coverage Analysis) fills the final placeholder.

STEP 2 -- Fill each placeholder.

Seven `single_find_and_replace` calls, one per placeholder. For each fill:
- Read the corresponding section from `audit_state/threat_audit_comparison.md`
- Render that section's content into HTML, preserving the per-entry detail
- Apply the styling rules: severity-colored entry borders, structured layout per entry, no collapsibles for primary content
- Each fill is a separate generation call with fresh capacity, which is how this approach avoids the per-call ceiling

Section fill rules:

1. TOC: a `<ul>` of `<li><a href="#section-id">Section Name</a></li>` entries linking to each main section by id. Brief and structural.

2. Executive Summary: the executive summary content from the Markdown (synthesis paragraph plus counts table).

3. Confirmed Threats: each entry from Section 2 of the Markdown becomes an `<article class="entry severity-{level}">` block containing the threat-model context, the confirming finding(s), and the synthesis. Preserve all the content from the Markdown -- do NOT compress for the HTML rendering.

4. Unconfirmed Threats: each entry from Section 3 becomes an `<article>` block. Include the threat description and the agent's reasoning category with explanation.

5. Unanticipated Findings: each entry from Section 4 becomes an `<article class="entry unanticipated severity-{level}">` block with full finding content. These are the highest-value entries; ensure they get prominent visual treatment.

6. Partial Matches: each entry from Section 5 becomes an `<article>` block.

7. Coverage: render Section 6 from the Markdown as its HTML equivalent (coverage statistics).

If any single_find_and_replace fails (placeholder not found, or the fill content itself truncates), retry only that one fill. The other completed sections remain on disk and are unaffected. If a single fill (most likely the Confirmed Threats or Unanticipated Findings fill, since those are the largest) truncates, the recovery is to manually split that section in half and run two fills against it -- but this should be a rare case and is not the expected workflow.

STEP 3 -- Copy the HTML deliverable to the threat model directory.

After all seven fills complete and the HTML is verified intact, copy the file:
- From: `audit_state/threat_audit_comparison.html`
- To: `{PROJECT_NAME}-threat-model/threat_audit_comparison.html`

This is a one-way copy; do not modify any other files in the threat model directory. The Markdown intermediate stays in `audit_state/` only and is not copied.

WRITE (Phase 6):
- audit_state/threat_audit_comparison.html (HTML deliverable, produced via scaffold-and-fill)
- {PROJECT_NAME}-threat-model/threat_audit_comparison.html (copy for threat model directory)

Before printing the banner, update audit_state/STATE.md: mark Phase 6 done; Resume Instruction = "Audit complete."

**Phase 6 Completion Banner:**
```
=== PHASE 6 COMPLETE: AUDIT FINISHED ===
  audit_state/threat_audit_comparison.html
  {PROJECT_NAME}-threat-model/threat_audit_comparison.html (reciprocal copy)
STATE.md updated: Phase 6 marked done.
The audit is complete.
```

STOP
<!-- END VERBATIM CARVE -->