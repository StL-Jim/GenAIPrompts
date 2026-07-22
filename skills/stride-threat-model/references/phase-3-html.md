<!-- SKILL VERSION: v25-skill (2026-07-21a) -- methodology carved verbatim from PROMPT VERSION v24 (2026-07-16a) -->

### Phase 3 Rehydration (MANDATORY FIRST STEP)

Read STATE.md and 02-threats.md. The threats file on disk is the authoritative source for every threat that will appear in the exports -- every CSV row, every HTML table cell, every markdown line must come from the content you just re-read, not from conversation memory.

Read these files with the Read tool (disk content overrides memory): {PROJECT_NAME}-threat-model/STATE.md, {PROJECT_NAME}-threat-model/02-threats.md.

If `02-threats.md` does not exist or is empty, STOP and report the error -- Phase 2C did not complete consolidation and Phase 3 cannot proceed. Re-run Phase 2C (which will rebuild `02-threats.md` from the surviving 02a/02b/02c sub-files).

Disk content takes precedence over conversation memory. If a threat ID, component name, or priority value in your memory does not appear in the on-disk threats file, do not invent it into the exports.

STATE.md is orchestrator-owned. Do not read-modify-write it.

After reading, acknowledge in one line the total threat count and priority breakdown found on disk.

If 03-dispositions-matched.md exists, read it; its rows are the matched dispositions the format sections below refer to. If absent, all disposition fields render empty/default.

**Goal:** Emit the threat model in three formats for different audiences.

### 3A -- HTML

Produce `.\{PROJECT_NAME}-threat-model\outputs\threat-model.html` using the Write tool with the complete HTML content in a single call (per the decision table in Operating Rule 7).

CRITICAL: produce the Write tool call with minimal preamble. Acknowledge the threat count in one line, then go directly to the tool call. Do not write planning notes or section descriptions before generating the HTML -- every line of preamble consumes output budget that should go into the file content.

MANDATORY -- every threat row required, no abbreviation: this is a stakeholder and developer review document. EVERY threat from the main table in `02-threats.md` MUST appear as its own row in the HTML output. Do NOT write a partial table, a "preview," a sample of rows, or any placeholder/summary text such as "Table shows N of M threats for brevity" or "see complete report for full list." There is no other, more complete report -- this HTML file IS the complete report. If you are concerned about output length, that is not a valid reason to drop rows: write the full table across as many tokens as it takes, using terse cell content where needed, but never omit a row. If you genuinely cannot fit all rows in one Write tool call, STOP and tell the user rather than silently truncating.

Document requirements:

- Single self-contained file: no external CSS/JS, no CDN references (air-gapped environment).
- Inline `<style>` block, system font stack like `system-ui, -apple-system, Segoe UI, sans-serif`, print-friendly.
- Priority color coding: Priority 1 `#b00020`, Priority 2 `#e65100`, with WCAG-AA contrast.
- Priority labels stand ALONE everywhere they appear (summary counts, any legend/key, threat rows): render `Priority 1` and `Priority 2` verbatim and NEVER annotate them with `Critical`, `High`, or any severity word -- the organization uses Priority 1/2 in place of Critical/High as finding ratings (see the Displayed Priority label mapping in Phase 2B). This includes the Summary section's by-priority counts and any color-key: `Priority 1: 5`, not `Priority 1 (Critical): 5`.
- ASCII-only content per Operating Rule 14.
- AI-generation disclosure banner as the FIRST child of `<body>`, before the title, per Operating Rule 16 -- visible in print.

Layout (sticky left sidebar TOC):

- The TOC MUST render as a LEFT SIDEBAR at wide viewport widths (>= 1024 px). The `<nav class="toc">` element appears BEFORE `<main>` in the markup.
- CSS for the wide-viewport layout: `nav.toc` is a fixed-width left column approximately 220 px wide with `position: sticky; top: 0;` so it stays visible during scroll. `<main>` takes the remaining viewport width with appropriate left margin.
- At narrow widths (< 1024 px), use a media query to stack the nav above main as a normal block.
- Do NOT render the TOC as a full-width horizontal block at the top of the document at any viewport width.

Reviewer metadata block:

- Position between the title heading and the summary table.
- Two fields: `Reviewed By:` and `Reviewer Notes:`.
- Both fields render as visibly empty placeholders for post-generation manual completion. Use a light-gray underlined blank or `&nbsp;` styled cell. Do NOT populate or guess values during generation. Do NOT guess at a reviewer name.

Sections in order (each gets an `<h2>` and an `id` matching its TOC link; every numbered section below is MANDATORY -- a report missing one is incomplete):

1. System Restatement -- the confirmed restatement from the `02-threats.md` header, rendered as a short emphasized prose paragraph (not a table): what the system is, what it talks to, who its users are, its most sensitive asset. It opens the report because it orients every reader (developer, manager, assessor) on what the system IS before they see what threatens it.
2. Summary -- a small table showing total threat count and counts by priority (Priority 1, Priority 2) and by STRIDE category (Spoofing, Tampering, Repudiation, Information Disclosure, DoS, Elevation of Privilege).
3. Control Coverage Summary -- the control-to-threats reverse index from the `02c-assumptions.md` portion of `02-threats.md`, rendered as a table (Control, Name, Family, Cited By with each ThreatID linking down to its threat row, Count). It sits here, with the Summary, because together they are the report's dashboard: what threatens the system and which governance controls answer it, visible before any detail.
4. Assets -- definition lists or sub-tables per asset class (Data Assets, Secrets, Authentication, Infrastructure, Service Availability, Code/IP), pulled from the Assets section of `02-threats.md`.
5. Trust Boundaries -- a table mirroring the schema in 02a (TB ID, Boundary, Principals, Establishing Control, Evidence).
6. Data Flows -- a table mirroring the schema in 02a (DF ID, Source, Destination, Data, Protocol, AuthN, Encryption, Crosses TB?, Evidence).
7. Threats -- the merged threat table (see detailed format below). Render with priority-colored row backgrounds and the color rules listed below.
8. Questions and Assumptions -- content from the `02c-assumptions.md` portion of `02-threats.md`: Threat Filtering Summary, Excluded Threat Categories, Questions for Stakeholders, Assumptions Made.
9. Coverage and Known Gaps -- the Coverage and Known Gaps section from the `02c-assumptions.md` portion of `02-threats.md`: files read/skipped and every known analysis gap with its explanation. This section is mandatory even when there are no gaps (state "No known gaps") -- stakeholders must see what the analysis could and could not cover.

#### Threats section format

The threats section uses a two-tier visibility pattern. Each threat is rendered as a primary row showing visible columns. Below each row is a collapsible `<details>` element containing the remaining columns.

Visible columns (primary row): ThreatID, Confidence, Priority, Component, Title, ThreatAgent, Asset, SecurityControl, Disposition.

Inside the `<details>` element (collapsible, with `<summary>Threat detail</summary>`): Category, OWASP, TrustBoundary, Attack, AttackSurface, Impact, Description, Evidence, Likelihood, ResidualRisk, Mitigation, RevisedPriority, DispositionRationale.

Color rules applied to the threats section:

- Priority 1 rows: background tinted with the Priority 1 color at low opacity.
- Priority 2 rows: background tinted with the Priority 2 color at low opacity.
- ThreatAgent column: rendered bold.
- SecurityControl cells with the exact value `None`: cell background highlighted orange (`#FFB74D` at low opacity).
- Confidence column: render `Confirmed` in a confident green (`#2e7d32`) and `Likely` in a cautionary amber (`#f9a825`) so a reader can scan verification level at a glance.

#### Disposition input fields (HTML form controls)

The `Disposition` and `DispositionRationale` cells in the threats section are NOT static text. They are interactive form controls that the reviewer fills in during stakeholder review, with the report then printed to PDF as the dated artifact of the review session.

For each threat row, render the Disposition cell as a `<select>` dropdown with options (in order): `--, Active, False Positive, Risk Accepted, Mitigated by Compensating Control, Duplicate, Other`. If a disposition was matched from a prior dispositions.csv, pre-select the matched value; otherwise default to `--`.

Render the DispositionRationale cell (inside the `<details>` collapsible) as a `<textarea rows="2">`. Populate with the matched rationale value (HTML-escaped) if one exists; otherwise leave empty.

#### Priority display with revisions (when applicable)

If a matched disposition revised the Priority (OriginalPriority != RevisedPriority), the threat row shows the revised value prominently with the original as context: `Priority 2 (originally rated Priority 1)`. Row color coding follows the RevisedPriority. If no revision exists, render the Priority normally.

#### Review capture -- RevisedPriority control and export button

Inside each threat's `<details>` element, render a `RevisedPriority` `<select>` with options (in order): `--, Priority 1, Priority 2, Medium, Low`. Pre-select the matched RevisedPriority if one exists; otherwise default to `--`.

At the top of the Threats section, render an `Export dispositions.csv` button wired to inline JavaScript (self-contained, no network access). On click it walks every threat row, reads the form control values, and downloads `dispositions.csv` with header `ThreatID,Title,Component,OWASP,Description,OriginalPriority,RevisedPriority,Disposition,DispositionRationale,Reviewer,ReviewDate` (Reviewer read from the Reviewed By field, ReviewDate = today; this is the toolchain's canonical dispositions schema, shared with the disposition prompt), RFC 4180-escaped, ASCII-only, generated via a Blob and a temporary anchor element. Two value-mapping rules the export JS MUST implement: (1) any select control whose value is `--` exports as an EMPTY string -- never the literal `--`; an empty RevisedPriority is the "never reviewed" state of the three-state signal defined in Phase 3B (CSV), and downstream consumers (the disposition prompt's validation, the next run's Disposition Discovery matching) reject `--` as a value. (2) Replace internal newlines in the DispositionRationale textarea value with `\n` (backslash-n), matching the disposition prompt's convention, so each CSV row stays on one line. This is the file a future run's Phase 3 Disposition Discovery consumes: the reviewer clicks export at the end of the review session and saves the file into the run's output directory before archiving. Hide the button under `@media print`.

#### Print CSS for the form controls

Add `@media print` CSS so dropdowns render without the arrow chrome and textareas expand to show full content without scrollbars -- the printed PDF should look like a completed form, not a screenshot of input controls.

Verify per Operating Rule 7(d) after writing. If the file is missing or truncated, retry the Write tool call.
