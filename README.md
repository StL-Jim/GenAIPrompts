# Security Threat Modeling and Code Audit Toolchain

Four LLM-driven prompts for security analysis of a source code repository. Each prompt can be used independently; some combinations produce additional value.

The prompts:

- **STRIDE Threat Modeling Prompt** (`stride-threat-model-prompt.md`) -- produces an architectural threat model: what could go wrong in the design, who would attack it, what to mitigate.
- **Code Security Audit Prompt** (`CodeSecurityAudit.md`) -- produces a code-level security and architecture audit: where specific defects exist in the code, mapped to OWASP Top 10 and NIST 800-53, with remediation guidance.
- **Threat Model Comparison Prompt** (`threat-model-comparison.md`) -- compares two threat model runs (older archived vs current) to identify persistent threats, threats that disappeared, threats that are new, and ambiguous matches.
- **Threat Model Disposition Prompt** (`threat-model-disposition.md`) -- interactive prompt for capturing stakeholder review decisions about threats (False Positive, Risk Accepted, etc.) into a structured file.

Tested with Claude Sonnet 4.5 on AWS Bedrock via the Continue.dev VS Code extension.

## How These Prompts Relate

Use individually:
- **Threat modeling alone:** new project where you want architectural threat identification.
- **Audit alone (standalone mode):** existing codebase where you want code-level defect finding without architectural context.
- **Comparison alone:** you have two threat models from different runs and want to know what changed.
- **Disposition alone:** you have a threat model and want to capture stakeholder review decisions.

Use in combinations:
- **Threat modeling + audit (coordinated mode):** the audit detects the threat model and produces a comparison output showing which anticipated threats were confirmed in code and which code defects the threat model did not anticipate. This is the most valuable combination.
- **Threat modeling + disposition:** capture stakeholder decisions about the threat model so they're recorded in a structured file.
- **Threat modeling + disposition + repeat runs:** on subsequent threat model runs, the prompt detects archived dispositions and transfers them forward, so reviewers don't re-make decisions they've already made.
- **All four:** full toolchain. Track threats over time, capture decisions, audit against code, see what changed.

If you only want some of these, just use those. There's no requirement to run all four. Skip the others entirely.

## Requirements

- VS Code with the Continue.dev extension
- An LLM with at least a 200K token context window (designed for Sonnet 4.5 via Bedrock; other capable models should work)
- Windows 11 with PowerShell (some operations use PowerShell)
- draw.io Desktop or the VS Code Draw.io Integration extension (for viewing/exporting diagrams from the threat model)
- A git repository checked out locally -- the workspace root is the code under assessment

## Running the Threat Modeling Prompt

1. Open the source repository you want to threat-model in VS Code. The workspace root must be the repo root.
2. Open the Continue.dev chat panel.
3. Paste the contents of `stride-threat-model-prompt.md` into the chat.
4. Follow the prompts. The agent pauses at the end of each phase and waits for you to type `proceed` before continuing.

A full run typically takes 60-90 minutes. Phases:

- **Phase 0** -- Initialization and scope proposal. You will be asked about deployment exposure (internet-facing, internal, hybrid).
- **Phase 1** -- Architectural inventory: components, data stores, external integrations, trust boundaries.
- **Phase 2** -- STRIDE threat enumeration, split into three sub-phases (2A context, 2B threats, 2C consolidation) for resilience.
- **Phase 3** -- Markdown, HTML, and CSV exports. At the start of Phase 3, the prompt checks for an archived threat model directory containing a dispositions.csv file (from the disposition capture prompt). If found, prior dispositions are matched against current threats and pre-populated into the exports.
- **Phase 4** -- draw.io diagrams (Context, Container, Component, DFD).

Outputs land in `{PROJECT_NAME}-threat-model/` inside the workspace, where `{PROJECT_NAME}` is the workspace's leaf directory name.

Key outputs:
- `outputs/threat-model.html` -- primary stakeholder deliverable with interactive disposition fields
- `outputs/threat-model.md` -- same content in Markdown
- `outputs/threats.csv` -- comprehensive CSV for Excel import or scripted analysis
- `diagrams/*.drawio` -- the four architectural diagrams

## Running the Code Security Audit Prompt

1. Open the source repository you want to audit in VS Code. The workspace root must be the repo root.
2. Open the Continue.dev chat panel.
3. Paste the contents of `CodeSecurityAudit.md` into the chat.
4. Follow the prompts. The agent pauses at the end of each phase and waits for you to type `proceed`.

A full run typically takes 60-90 minutes; longer for monorepos that partition into multiple worker reviews. Phases:

- **Phase 1** -- Global discovery and coordination mode detection. If a threat model directory exists in the workspace, the audit binds to it (coordinated mode); otherwise it runs standalone.
- **Phase 2** -- Risk prioritization across detected services and partitions.
- **Phase 3A** -- Worker security review (one per partition). OWASP Top 10 and NIST 800-53 mapping. In coordinated mode, findings are cross-referenced against the threat model's threats.
- **Phase 4A** -- Worker architecture review.
- **Phase 5** -- Consolidation. Produces consolidated report HTML, executive briefing HTML, and (in coordinated mode) the Markdown intermediate for the comparison output.
- **Phase 6** -- Comparison HTML render. **Coordinated mode only** -- skipped entirely in standalone mode.

Outputs land in `audit_state/` inside the workspace.

Key outputs (coordinated mode):
- `audit_state/threat_audit_comparison.html` -- **the headline deliverable** when a threat model exists. Read this first.
- `{PROJECT_NAME}-threat-model/threat_audit_comparison.html` -- reciprocal copy in the threat model directory
- `audit_state/05_consolidated_report.html` -- complete audit report with all findings
- `audit_state/executive_briefing.html` -- Critical/High findings, executive-facing format

Key outputs (standalone mode):
- `audit_state/05_consolidated_report.html` -- the headline deliverable in standalone mode
- `audit_state/executive_briefing.html` -- Critical/High summary

## Running the Threat Model Comparison Prompt

This prompt compares two threat model runs against the same codebase. Run it whenever you have two threat models worth comparing.

The workflow:

1. **Prepare the directories.** The CURRENT threat model lives at `{PROJECT_NAME}-threat-model/` as usual. An archived prior threat model should be present at `{PROJECT_NAME}-threat-model-YYYY-MM-DD/` (or any dated suffix following that pattern). Use a consistent naming convention so the comparison prompt can find archives by pattern.

2. **Open the workspace in VS Code.** Both threat model directories should be visible from the workspace root.

3. **Paste the prompt.** Open the Continue.dev chat panel and paste the contents of `threat-model-comparison.md` into the chat.

4. **Follow the discovery step.** The prompt's first action is identifying which two directories to compare. If there's exactly one archive, it confirms with you. If there are multiple archives, it lists them and asks which one. Respond with your choice.

5. **Let it run.** The comparison runs as a single phase -- no STOP/proceed checkpoints needed. Typically completes in one session.

A full run typically takes 15-30 minutes, much shorter than the threat modeling or audit prompts because there is no code analysis -- just synthesis across two threat model directories.

Outputs land in `{PROJECT_NAME}-threat-model/`:

- `threat_model_comparison.md` -- the long, comprehensive comparison (typically 30+ pages when printed). Reference material for the security architect. Seven sections: executive summary, persistent threats, threats only in older model, threats only in newer model, ambiguous matches, inventory and assumption changes, coverage and trend analysis.
- `threat_model_comparison_summary.md` -- the brief summary (2-3 pages). Verdict, counts at a glance, action items prioritized by severity, "things to verify mitigation," inventory changes, pointers back to the long document. Suitable for developers and stakeholders who need actionable information without reading the full comparison.
- `threat_model_comparison_summary.html` -- HTML version of the brief summary with severity color coding. Suitable for stakeholder distribution.

## Running the Threat Model Disposition Prompt

This prompt captures stakeholder review decisions about a threat model into a structured CSV file. Run it during stakeholder review meetings to record decisions as they happen.

The workflow:

1. **Have a threat model on disk.** The prompt requires `{PROJECT_NAME}-threat-model/02-threats.md` to exist.
2. **Open the workspace in VS Code.** The threat model HTML report should ideally also be open in a browser so the reviewers can see threats as they're discussed.
3. **Paste the prompt.** Open the Continue.dev chat panel and paste the contents of `threat-model-disposition.md`.
4. **Follow the session start.** The prompt asks who's reviewing and presents progress against the threat model.
5. **Walk through threats.** Type a threat ID (e.g., `0007`) to begin dispositioning it. The agent presents threat context and a numbered menu of disposition options. Respond with format like `1 - rationale text` or `3, rationale text, severity high`.
6. **End the session.** Type `done` when finished. The agent presents a summary.

A full session typically takes 30-60 minutes for a threat model of 20-25 threats. Sessions are resumable -- if interrupted, re-running the prompt picks up where the prior session left off.

The disposition file `{PROJECT_NAME}-threat-model/dispositions.csv` is the output. Columns: ThreatID, Title, Component, OriginalSeverity, RevisedSeverity, Disposition, Rationale, Reviewer, ReviewDate.

The file becomes input to the threat modeling prompt on subsequent runs. When you re-run the threat modeling prompt after archiving the current threat model (by renaming the directory with a date suffix), Phase 3 of the new run detects the archived dispositions.csv and transfers matched dispositions forward.

## Resuming Across Sessions

The threat modeling and audit prompts maintain a state file in their output directory that tracks completed phases. If a session ends before all phases finish (context window exhaustion, network issue, end of day), start a new session and paste the same prompt. The agent reads the state file and resumes at the next pending phase.

The disposition prompt saves to disk after every disposition is captured, so interrupted sessions can resume by re-running the prompt. It picks up at whichever threat hasn't been dispositioned yet.

The threat model comparison prompt does not use a state file because it runs as a single phase and is short enough to complete in one session. If a comparison run fails partway through, re-run the prompt from the beginning.

## Working With the Threat Model HTML Report

The HTML report contains interactive `<select>` dropdowns for Disposition and `<textarea>` fields for Rationale on every threat. These can be filled in directly in the browser during stakeholder review.

Two paths for capturing review decisions:

**Path A: Fill in the HTML directly during review, then print to PDF.** Walk through threats with stakeholders, set the dropdown and rationale in the browser, then print to PDF (Ctrl+P → Save as PDF). The PDF is the dated artifact of record. Disposition values entered in the browser are NOT persisted to the source HTML file -- they only live in the current browser session, but they appear in the PDF.

**Path B: Use the disposition prompt to capture decisions to a CSV file alongside the meeting.** This is faster for capture, produces a structured file, and feeds back into subsequent threat model runs to preserve decisions across re-runs. See "Running the Threat Model Disposition Prompt" above.

Path A is simpler for a single review with no expected re-runs. Path B is more useful when you'll re-run the threat model periodically and want decisions to compound across runs.

## Working With the Audit Comparison Output

The comparison output (`threat_audit_comparison.html`) is structured into seven sections:

1. **Executive Summary** -- one-paragraph synthesis plus counts table.
2. **Threats Confirmed by Audit** -- threats the model anticipated AND the audit found in code. Highest-priority for remediation.
3. **Threats Not Confirmed by Audit** -- threats the model anticipated but the audit did not find. Each entry includes the agent's reasoning category: well-mitigated, audit didn't reach this code, architectural only, or unable to determine.
4. **Audit Findings Not Anticipated by Threat Model** -- code defects the threat model missed. Often the most valuable section because it reveals threat modeling gaps.
5. **Partial Matches** -- threats where the audit confirmed part but not all.
6. **Coverage Analysis** -- coverage percentages and severity correlation.
7. **Recommended Next Steps** -- prioritized remediation list.

Each entry in sections 2, 3, 4, and 5 contains full content from the threat model and findings registry -- you do not need to open other files to act on a single entry.

## Working With the Threat Model Comparison Output

The comparison prompt produces three files. The right one to start with depends on who's reading:

**For developers and stakeholders:** open `threat_model_comparison_summary.html` (or the Markdown equivalent). The verdict at the top tells you in plain language what changed. The "Things to investigate or remediate" list gives action items sorted by severity. The "Things to verify mitigation" list flags threats that disappeared from the newer model without explicit evidence -- worth investigating if you want to confirm they're actually fixed.

**For the security architect:** start with the brief summary for the verdict and counts, then open `threat_model_comparison.md` for full reference detail. Use the Reading Guide at the top of the long document to navigate -- you don't need to read all 30+ pages linearly. Section 6 (Inventory and Assumption Changes) is often the second-most-useful section after the executive summary because it surfaces architectural shifts between runs.

The comparison cannot directly assess code-level mitigation. The reasoning categories acknowledge this. Threats absent in the newer model that have the category "Absent from newer model, no explicit exclusion noted" are NOT claims of mitigation -- they're observations that the agent has no observable evidence either way. If you want to confirm a threat was actually mitigated in code, that requires the audit prompt or manual code review.

## Working With the Audit Findings Registry

The complete list of audit findings is in `audit_state/findings_registry.md`. This is the canonical source -- every finding in the consolidated report comes from here. The Markdown format is git-diffable, grep-able, and parseable by external tools if you want to feed findings into a ticketing system.

The schema includes severity, confidence, OWASP/NIST mapping, evidence with file:line references, fix guidance, and verification steps. In coordinated mode, each finding also has `threat_id` and `threat_match` fields linking it to the threat model.

## Working With the Diagrams (Threat Model Only)

LLMs generate diagram XML without visual feedback during generation, so diagram quality varies between runs. Some runs produce clean, well-laid-out diagrams; others have missing components, missing trust boundaries, or cramped layouts.

Recommended remediation workflow when a diagram comes out poorly:

1. Open the `.drawio` file in draw.io Desktop or the VS Code extension
2. Export to PNG (File → Export As → PNG)
3. In a new Continue.dev session, attach the PNG and ask the agent to review it against the inventory file, looking for missing components, missing trust boundaries, missing data flows, overlaps, or unclear layout
4. The agent edits the `.drawio` file directly to address specific issues

This visual-feedback loop is more effective than re-running Phase 4 hoping for better luck, because the LLM CAN review an image once it has one -- it just can't see the diagram during initial generation.

## Output Encoding

All four prompts produce ASCII-only output by default (no em-dashes, smart quotes, or other Unicode in Markdown/HTML/CSV) so files render correctly across Windows and other environments without BOM or encoding fallback issues.

If you are sharing outputs with stakeholders on Mac or Linux, files render correctly without modification.

## Known Limitations

These are real characteristics of the toolchain, not bugs. Knowing them helps set expectations.

- **Run-to-run variation in findings.** The threat modeling and audit prompts produce different findings between runs against the same code. The threat model lands in a 15-25 threat range; the audit lands in a 20-30 finding range. This is expected behavior driven by LLM sampling -- not a bug. For higher determinism, run twice and compare. The comparison prompt is the right tool for evaluating that variation across runs.

- **Disposition matching reliability varies.** When the threat modeling prompt detects an archived dispositions.csv and transfers matched dispositions to the new run, the matching is conservative (high confidence required) and probabilistic. In practice, about 50-70% of prior dispositions transfer to a new run, even when most underlying threats are unchanged. The matching may also produce different results across re-runs of the same prompt against the same data. Two implications: do not rely on disposition transfer as automatic; verify transferred dispositions during the next stakeholder review session; expect to re-disposition some threats each time even if the codebase is unchanged.

- **The threat model comparison cannot assess code-level mitigation.** It observes only what's in the threat model artifacts. Threats absent in a newer model may or may not be mitigated in code. For code-level confirmation, use the audit prompt against the current codebase.

- **Large codebases can exhaust context.** The phase splits and state-file resume mechanism mitigate this. If you still hit limits, scope the analysis to one service in a monorepo rather than the entire repo.

- **Diagram quality is the weakest output of the threat model.** Plan to use the PNG review loop for any diagram that will leave your team.

- **The audit comparison output can be large.** A comparison with 20-25 threats and 25-30 findings produces 100-200KB of Markdown and a similarly long HTML report. Phase 5/6 split handles this, but expect the audit's coordinated mode to take a full additional session for Phase 6 alone.

- **Coordinated audits require a threat model in the workspace.** If you delete or rename the threat model directory between threat model and audit runs, the audit will run in standalone mode without producing the comparison output.

- **The threat model comparison requires both a current and an archived threat model.** Archives must be named with a suffix pattern like `{PROJECT_NAME}-threat-model-YYYY-MM-DD/` so the comparison prompt can find them.

## You Don't Need to Use All Four

If you only want architectural threat identification, use the threat modeling prompt alone. The other three are optional.

If you only want code-level defect finding, use the audit prompt alone in standalone mode. You don't need a threat model present.

If you want both but no time-over-time tracking or disposition workflow, use threat modeling + audit (coordinated mode). Skip the comparison and disposition prompts entirely.

The full toolchain becomes valuable when you're running these periodically on the same codebase and want to track progress, capture decisions, and avoid re-reviewing the same threats. If that's not your use case, smaller subsets work fine.
