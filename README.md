# STRIDE Threat Modeling Prompt

A multi-phase prompt for performing STRIDE threat modeling against a source code repository using an LLM (tested with Claude Sonnet 4.5 on AWS Bedrock via the Continue.dev VS Code extension).

The prompt analyzes the code, builds an architectural inventory, enumerates threats using STRIDE-per-element methodology, and produces deliverables for stakeholder review: a Markdown report, an HTML report with interactive disposition fields, a CSV export, and four draw.io diagrams (Context, Container, Component, DFD).

## Requirements

- VS Code with the Continue.dev extension
- An LLM with at least a 200K token context window (the prompt is designed for Sonnet 4.5 via Bedrock; other capable models should work)
- Windows 11 with PowerShell (the prompt uses PowerShell for some operations)
- draw.io Desktop or the VS Code Draw.io Integration extension (for viewing and exporting diagrams)
- A git repository checked out locally — the workspace root is the code under assessment

## How to Run

1. Open the source repository you want to threat-model in VS Code. The workspace root must be the repo root.
2. Open the Continue.dev chat panel.
3. Paste the contents of `stride-threat-model-prompt.md` into the chat.
4. Follow the prompts. The agent will pause at the end of each phase and wait for you to type `proceed` before continuing.

A full run typically takes 60-90 minutes. The phases are:

- **Phase 0** — Initialization and scope proposal. You will be asked about deployment exposure (internet-facing, internal, hybrid).
- **Phase 1** — Architectural inventory: components, data stores, external integrations, trust boundaries.
- **Phase 2** — STRIDE threat enumeration, split into three sub-phases (2A context, 2B threats, 2C consolidation) for resilience.
- **Phase 3** — Markdown, HTML, and CSV exports.
- **Phase 4** — draw.io diagrams (Context, Container, Component, DFD).

## Resuming Across Sessions

The prompt maintains a `STATE.md` file in the output directory tracking which phases have completed. If a session ends before all phases finish (context window exhaustion, network issue, end of day), the next session reads `STATE.md` and resumes at the next pending phase. You do not lose work.

## Outputs

All artifacts are written to `{PROJECT_NAME}-threat-model/` inside the workspace, where `{PROJECT_NAME}` is the workspace's leaf directory name. Key outputs:

- `outputs/threat-model.html` — primary stakeholder deliverable
- `outputs/threat-model.md` — same content in Markdown
- `outputs/threats.csv` — comprehensive CSV for Excel import or scripted analysis
- `diagrams/*.drawio` — the four architectural diagrams

## Working With the HTML Report

The HTML report is the recommended artifact for stakeholder review. It contains interactive `<select>` dropdowns for Disposition and `<textarea>` fields for Rationale on every threat.

**Recommended review workflow:**

1. Open the HTML in a browser
2. Walk through threats with stakeholders, filling in Disposition (Active / False Positive / Risk Accepted / Mitigated by Compensating Control / Duplicate / Other) and Rationale for each
3. Print the page to PDF (Ctrl+P → Save as PDF) — this captures the filled-in dispositions as a dated artifact

The HTML includes print-specific CSS that expands rationale fields to show full text in the PDF rather than the on-screen scrolling box.

Note that disposition values entered in the browser are not persisted to the source HTML file — they only live in the current browser session. The PDF is the artifact of record.

## Working With the Diagrams

LLMs generate the diagram XML without visual feedback during generation, so diagram quality varies between runs. Some runs produce clean, well-laid-out diagrams; others have missing components, missing trust boundaries, or cramped layouts.

**Recommended remediation workflow when a diagram comes out poorly:**

1. Open the `.drawio` file in draw.io Desktop or the VS Code extension
2. Export to PNG (File → Export As → PNG)
3. In a new Continue.dev session, attach the PNG and ask the agent to review it against the inventory file, looking for missing components, missing trust boundaries, missing data flows, overlaps, or unclear layout
4. The agent can then edit the `.drawio` file directly to address specific issues

This visual-feedback loop is more effective than re-running Phase 4 hoping for better luck, because the LLM CAN review an image once it has one — it just can't see the diagram during initial generation.

## Tweaking for Your Environment

The prompt produces ASCII-only output by default (no em-dashes, smart quotes, or other Unicode in Markdown/HTML/CSV) so files render correctly across Windows and other environments without BOM or encoding fallback issues.

If you are sharing the threat model with stakeholders who use Mac or Linux machines, the outputs should render correctly without modification. The `.drawio` files are XML and work on any platform with draw.io installed.

## Known Limitations

- LLM output varies between runs. Threat count typically lands within a 20-25 range; trust boundary and asset counts can differ by 1-3 between runs. Same code, same prompt, different runs — this is expected behavior, not a bug. If you need higher determinism, run the prompt twice and compare.
- A single run can exhaust the model's context window on very large codebases. The phase split mitigates this; if you still hit limits, scope the threat model to one service in a monorepo rather than the entire repo.
- Diagram quality is the weakest output, for the reason described above. Plan to use the PNG review loop for any diagram that will leave your team.

## Versioning

The prompt is maintained in a single file (`stride-threat-model-prompt.md`) and versioned in git. Updates are applied by replacing the file contents and committing. No branching strategy is needed — the prompt is small enough that direct edits work fine.
