# Security Threat Modeling and Code Audit Toolchain

Two LLM-driven prompts for security analysis of a source code repository, designed to work independently or together as a coordinated toolchain.

- **STRIDE Threat Modeling Prompt** (`stride-threat-model-prompt.md`) -- produces an architectural threat model: what could go wrong in the design, who would attack it, what to mitigate.
- **Code Security Audit Prompt** (`CodeSecurityAudit.md`) -- produces a code-level security and architecture audit: where specific defects exist in the code, mapped to OWASP Top 10 and NIST 800-53, with remediation guidance.

When both have been run against the same codebase, the audit produces a **Threat-Audit Comparison** as its headline deliverable: which anticipated threats were confirmed in code, which were not confirmed, and which code defects the threat model did not anticipate.

Tested with Claude Sonnet 4.5 on AWS Bedrock via the Continue.dev VS Code extension.

## Requirements

- VS Code with the Continue.dev extension
- An LLM with at least a 200K token context window (designed for Sonnet 4.5 via Bedrock; other capable models should work)
- Windows 11 with PowerShell (some operations use PowerShell)
- draw.io Desktop or the VS Code Draw.io Integration extension (for viewing/exporting diagrams from the threat model)
- A git repository checked out locally -- the workspace root is the code under assessment

## When to Use Each Prompt

**Threat modeling prompt only** -- New project where you want to identify what could go wrong architecturally before deep code review. Output is threat-centric: agents, attack surfaces, mitigations.

**Audit prompt only (standalone mode)** -- Existing codebase where you want to know where the actual defects are. Output is defect-centric: file:line evidence, OWASP/NIST mapping, fixes.

**Both prompts as a toolchain (coordinated mode)** -- The most valuable combination. The threat model identifies what to worry about; the audit finds what's actually wrong; the comparison output tells you which is which. The comparison reveals threats that were anticipated and confirmed, threats that appear well-mitigated, and code defects the threat model did not anticipate (often the most valuable findings).

## Running the Threat Modeling Prompt

1. Open the source repository you want to threat-model in VS Code. The workspace root must be the repo root.
2. Open the Continue.dev chat panel.
3. Paste the contents of `stride-threat-model-prompt.md` into the chat.
4. Follow the prompts. The agent pauses at the end of each phase and waits for you to type `proceed` before continuing.

A full run typically takes 60-90 minutes. Phases:

- **Phase 0** -- Initialization and scope proposal. You will be asked about deployment exposure (internet-facing, internal, hybrid).
- **Phase 1** -- Architectural inventory: components, data stores, external integrations, trust boundaries.
- **Phase 2** -- STRIDE threat enumeration, split into three sub-phases (2A context, 2B threats, 2C consolidation) for resilience.
- **Phase 3** -- Markdown, HTML, and CSV exports.
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
- `audit_state/threat_audit_comparison.html` -- **THE HEADLINE DELIVERABLE** when a threat model exists. Read this first.
- `{PROJECT_NAME}-threat-model/threat_audit_comparison.html` -- reciprocal copy in the threat model directory
- `audit_state/05_consolidated_report.html` -- complete audit report with all findings
- `audit_state/executive_briefing.html` -- Critical/High findings, executive-facing format

Key outputs (standalone mode):
- `audit_state/05_consolidated_report.html` -- the headline deliverable in standalone mode
- `audit_state/executive_briefing.html` -- Critical/High summary

## Running Them as a Coordinated Toolchain

The toolchain is most valuable when both prompts have run against the same codebase. The order matters.

1. **Run the threat modeling prompt first.** Complete all five phases. The output directory `{PROJECT_NAME}-threat-model/` should contain a complete threat model with all artifacts present.

2. **Run the audit prompt second.** Phase 1 detects the threat model directory and enters coordinated mode automatically -- you do not need to tell it. It records the threat model's timestamp as a binding contract.

3. **Do not re-run the threat model mid-audit.** The audit binds to a specific threat model version. If you re-run the threat model while the audit is in progress, the audit will detect the timestamp change at Phase 5 and stop with a binding error.

4. **The deployment exposure question is asked only once.** In coordinated mode, the audit inherits the deployment exposure from the threat model's scope. In standalone mode, the audit asks the same question itself.

5. **Open `threat_audit_comparison.html` first.** This is the headline deliverable. The consolidated report and executive briefing are still produced and useful, but the comparison is what justifies the toolchain.

## Resuming Across Sessions

Both prompts maintain a state file in their output directory that tracks completed phases. If a session ends before all phases finish (context window exhaustion, network issue, end of day), start a new session and paste the same prompt. The agent reads the state file and resumes at the next pending phase.

You do not lose work between sessions. This is by design -- a full toolchain run can span hours and naturally crosses session boundaries.

## Working With the Threat Model HTML Report

The HTML report contains interactive `<select>` dropdowns for Disposition and `<textarea>` fields for Rationale on every threat.

Recommended review workflow:

1. Open the HTML in a browser
2. Walk through threats with stakeholders, filling in Disposition (Active / False Positive / Risk Accepted / Mitigated by Compensating Control / Duplicate / Other) and Rationale for each
3. Print the page to PDF (Ctrl+P -> Save as PDF) -- this captures the filled-in dispositions as a dated artifact

The HTML includes print-specific CSS that expands rationale fields to show full text in the PDF rather than the on-screen scrolling box.

Disposition values entered in the browser are not persisted to the source HTML file -- they only live in the current browser session. The PDF is the artifact of record.

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

## Working With the Audit Findings Registry

The complete list of audit findings is in `audit_state/findings_registry.md`. This is the canonical source -- every finding in the consolidated report comes from here. The Markdown format is git-diffable, grep-able, and parseable by external tools if you want to feed findings into a ticketing system.

The schema includes severity, confidence, OWASP/NIST mapping, evidence with file:line references, fix guidance, and verification steps. In coordinated mode, each finding also has `threat_id` and `threat_match` fields linking it to the threat model.

## Working With the Diagrams (Threat Model Only)

LLMs generate diagram XML without visual feedback during generation, so diagram quality varies between runs. Some runs produce clean, well-laid-out diagrams; others have missing components, missing trust boundaries, or cramped layouts.

Recommended remediation workflow when a diagram comes out poorly:

1. Open the `.drawio` file in draw.io Desktop or the VS Code extension
2. Export to PNG (File -> Export As -> PNG)
3. In a new Continue.dev session, attach the PNG and ask the agent to review it against the inventory file, looking for missing components, missing trust boundaries, missing data flows, overlaps, or unclear layout
4. The agent edits the `.drawio` file directly to address specific issues

This visual-feedback loop is more effective than re-running Phase 4 hoping for better luck, because the LLM CAN review an image once it has one -- it just can't see the diagram during initial generation.

## Output Encoding

Both prompts produce ASCII-only output by default (no em-dashes, smart quotes, or other Unicode in Markdown/HTML/CSV) so files render correctly across Windows and other environments without BOM or encoding fallback issues.

If you are sharing outputs with stakeholders on Mac or Linux, files render correctly without modification.

## Known Limitations

- **Run-to-run variation.** Both prompts produce different findings between runs against the same code. The threat model lands in a 20-25 threat range; the audit lands in a 20-30 finding range. This is expected behavior driven by LLM sampling -- not a bug. For higher determinism, run twice and compare.
- **Large codebases can exhaust context.** The phase splits and state-file resume mechanism mitigate this. If you still hit limits, scope the analysis to one service in a monorepo rather than the entire repo.
- **Diagram quality is the weakest output of the threat model.** Plan to use the PNG review loop for any diagram that will leave your team.
- **The comparison output can be large.** A comparison with 20-25 threats and 25-30 findings produces 100-200KB of Markdown and several pages of HTML. Phase 6's scaffold-and-fill approach handles this, but expect the audit to take a full session for Phase 6 alone in coordinated mode.
- **Coordinated audits require a threat model in the workspace.** If you delete or rename the threat model directory between threat model and audit runs, the audit will run in standalone mode without producing the comparison output.

## Versioning

Both prompts are maintained as single files (`stride-threat-model-prompt.md` and `CodeSecurityAudit.md`) and versioned in git. Updates are applied by replacing the file contents and committing. No branching strategy is needed for normal use -- the prompts are small enough that direct edits and git history are sufficient.
