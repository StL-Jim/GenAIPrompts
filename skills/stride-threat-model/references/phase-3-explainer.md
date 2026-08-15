<!-- SKILL VERSION: v25-skill (2026-07-21a) -- methodology carved verbatim from PROMPT VERSION v24 (2026-07-16a) -->

### Phase 3C -- Stakeholder Explainer: `.\{PROJECT_NAME}-threat-model\outputs\architecture-threat-explanation.html`

#### Phase 3C Rehydration (MANDATORY FIRST STEP)

Read these files with the Read tool (disk content overrides memory): `{PROJECT_NAME}-threat-model/STATE.md`, `{PROJECT_NAME}-threat-model/02-threats.md`.

The threat table in `02-threats.md` is authoritative. It is the table the user reviewed and approved at GATE 3, so it is the only acceptable source for this file -- do not explain a threat from conversation memory, and do not explain a threat that is not in it.

STATE.md is orchestrator-owned. Do not read-modify-write it.

This deliverable used to be written at the end of Phase 2B, before anyone had looked at the threats. It runs here instead so that every threat it explains is one the user has already reviewed and corrected.

**Goal:** For each threat in the main table, explain why it is an design-level finding and not a code-level finding, so the user can answer stakeholders -- developers, management, fellow security professionals -- who push back on a finding.

The argument you are making for each threat is the design-level test the threat had to pass to be in the table at all: the threat is expressible as actor -> path -> asset -> missing or weak control at component, data-flow, or trust-boundary granularity, and it would SURVIVE a correct re-implementation of the same design. A defect that a rewrite of one function would eliminate is a code-audit finding and is not in this table; a gap that persists no matter how well the individual functions are written is. Ground each explanation in that distinction, using the row's own Evidence, TrustBoundary, and Asset values -- the specific data flow, the specific boundary, the specific asset -- rather than restating the Title in longer words.

Use your own judgment on structure per threat. A card per threat with a short Architecture Issue / Why Not Just Code / Explain to Developers framing is a reasonable default, but prioritize a clear, accurate explanation over rigid adherence to that shape.

Write as a single self-contained HTML file (inline `<style>`, no external CSS/JS, no CDN references -- air-gapped environment), ASCII-only per Operating Rule 14. Plain and simple: this is a leave-behind for conversations, not the main report. It carries the AI-generation disclosure banner as the FIRST child of `<body>` per Operating Rule 16 (it is a stakeholder deliverable).

Every threat in the main table gets an entry. If you are concerned about output length, that is not a reason to drop threats -- use terser explanations.

Write with the Write tool per the decision table in common.md rule W. Verify per common.md rule W-d; if the file is missing or truncated, retry the Write tool call.

Return your completion banner to the orchestrator (it owns STATE.md).

**Phase 3C Completion Banner:**
```
=== PHASE 3C COMPLETE: outputs/architecture-threat-explanation.html WRITTEN ===
Threats explained: <N> of <N> in the main table
Phase status reported to orchestrator (it owns STATE.md).
Return this banner verbatim as the end of your completion summary.
```
