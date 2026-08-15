# Security Threat Modeling and Code Audit Toolchain

Two LLM-driven workflows for security analysis of a source code repository, run from Claude Code:

- **STRIDE threat model** -- an architectural threat model: what could go wrong in the design, who would attack it, what to mitigate. Delivered as a Claude Code skill at `skills/stride-threat-model/`.
- **Code security audit** -- a code-level security and architecture audit: where specific defects exist in the code, mapped to OWASP Top 10 and NIST 800-53, with remediation guidance. Currently the prompt `code-security-audit.md`; a skill conversion exists on the `audit-skill` branch and is under test.

Either can be used alone. Run together, the audit binds to the threat model and reports which anticipated threats were confirmed in code -- the most valuable combination.

Two earlier prompts, threat-model comparison and threat-model disposition, have been retired to `archive/`. See `archive/README.md` for why. The disposition workflow now lives inside the threat model's own HTML report, which carries the controls and an export button.

## Requirements

- Claude Code, with subagent (Task) support -- the skill dispatches a fresh subagent per phase
- Windows PowerShell 5.1 (the deterministic steps are PowerShell scripts)
- An LLM with at least a 200K token context window
- draw.io Desktop or the VS Code Draw.io Integration extension, for viewing and exporting the diagrams
- A git repository checked out locally -- the workspace root is the code under assessment

## Install the threat model skill

```bash
git pull
bash skills/stride-threat-model/install.sh
```

`install.ps1` is the PowerShell equivalent. Both copy the skill into
`~/.claude/skills/stride-threat-model`, resolving `$HOME` on whatever machine runs them, and
both print the installed version stamp and path so you can confirm what landed.

Use the installer rather than `cp -r`: it REPLACES the target directory, whereas `cp` merges
into it, so a file removed from the repo would linger in the installed copy and still be read
by a later run.

## Running the threat model

From a Claude Code session with your target repository as the working directory, ask it to run
the STRIDE threat model. The skill triggers on "run the threat model", "STRIDE analysis", and
resume requests.

An orchestrator (`SKILL.md`) runs the workflow and is the only participant that talks to you.
It dispatches a fresh subagent per phase, so each phase gets its own context window. Phase 1
runs as three parallel partition passes (docs / IaC / application source) plus a reconciliation
agent; Phase 3 exports and Phase 4 diagrams also run in parallel.

Review gates, rather than typing `proceed` at every phase:

- **GATE 1** after Phase 0 -- approve the scope proposal
- **GATE 2** after Phase 1 -- confirm or correct the System Restatement (mandatory, never skipped)
- **GATE 3** after Phase 2B -- the threat review, where you can walk threats individually
- a short confirm after Phase 2A on which assets were tiered `Primary`, before anything downstream ranks threats by what they target

Everything else auto-proceeds. Setting `GATE_POLICY: all-gates` in STATE.md restores a pause
after every phase -- recommended for a first run on a new machine or model.

Phases:

- **Phase 0** -- initialization and scope proposal. You are asked about deployment exposure, application criticality, existing mitigating controls, data sensitivity, and compliance requirements.
- **Phase 1** -- architectural inventory: components, data stores, external integrations, actors, trust boundaries.
- **Phase 2** -- STRIDE threat enumeration, split into 2A context, 2B threats, 2C consolidation.
- **Phase 3** -- HTML, CSV, and stakeholder-explainer exports. Phase 3 checks for an archived threat model directory containing a `dispositions.csv` and pre-populates matched decisions.
- **Phase 4** -- draw.io diagrams (Context, Container, Component, DFD).

Outputs land in `{PROJECT_NAME}-threat-model/`, where `{PROJECT_NAME}` is the workspace's leaf
directory name. Key outputs:

- `outputs/threat-model.html` -- the primary stakeholder deliverable, with interactive disposition fields, a RevisedPriority control per threat, and an 'Export dispositions.csv' button. The canonical Markdown is `02-threats.md`.
- `outputs/threats.csv` -- for Excel import or scripted analysis
- `outputs/architecture-threat-explanation.html` -- per-threat architecture-vs-code explainer, for answering stakeholder pushback
- `diagrams/*.drawio` -- the four architectural diagrams

Deterministic work -- file manifest, discovery sweep, threat-table validation, diagram layout,
drawio validation -- is done by PowerShell scripts in `scripts/`, not by the model.

## Running the code security audit

Paste the contents of `code-security-audit.md` into a Claude Code session whose working
directory is the repository under audit, and follow the prompts. The agent pauses at the end of
each phase.

Phases:

- **Phase 1** -- global discovery and coordination mode detection. If a threat model directory exists in the workspace, the audit binds to it (coordinated mode); otherwise it runs standalone.
- **Phase 2** -- risk prioritization across detected services and partitions.
- **Phase 3A** -- worker security review, one per partition, with OWASP Top 10 and NIST 800-53 mapping. In coordinated mode, findings are cross-referenced against the threat model.
- **Phase 4A** -- worker architecture review.
- **Phase 5** -- consolidation: consolidated report HTML, executive briefing HTML, and in coordinated mode the Markdown intermediate for the comparison output.
- **Phase 6** -- comparison HTML render. Coordinated mode only.

Outputs land in `audit_state/`. In coordinated mode the headline deliverable is
`audit_state/threat_audit_comparison.html`, with a reciprocal copy in the threat model
directory; in standalone mode it is `audit_state/05_consolidated_report.html`. Both modes also
produce `audit_state/executive_briefing.html`.

`code-security-audit.md` is also a BUILD INPUT, not only a prompt: `tests/code-security-audit/carve.ps1`
on the `audit-skill` branch reads it by name and verifies sha256 hashes over specific line
ranges, so the skill's reference files can never silently drift from it. Editing it requires
regenerating the carve in the same change.

## How the two work together

The audit detects a threat model in the workspace and produces a comparison showing which
anticipated threats were confirmed in code and which code defects the threat model did not
anticipate. The threat model also routes code-shaped concerns it deliberately excludes
(`Code-level` rows in its Excluded Threats Ledger) to the audit as seeded leads, and the audit
reports back whether each was verified.

If you only want architectural threat identification, run the threat model alone. If you only
want code-level defect finding, run the audit alone in standalone mode -- no threat model
required.

## Working with the threat model HTML report

The report contains interactive `<select>` dropdowns for Disposition, a RevisedPriority control,
and `<textarea>` fields for Rationale on every threat, plus an 'Export dispositions.csv' button.
Fill these in during stakeholder review, then click Export and save the CSV into the run's output
directory -- that file is what future runs read to carry decisions forward. Print to PDF
(Ctrl+P -> Save as PDF) for the dated artifact of record.

Values entered in the browser are not saved into the HTML file itself. The exported CSV and the
PDF are the two ways to persist them.

The CSV schema is ThreatID, Title, Component, OWASP, Description, OriginalPriority,
RevisedPriority, Disposition, DispositionRationale, Reviewer, ReviewDate. OWASP and Description
are carried specifically to raise match rates when a later run transfers dispositions forward.

## Working with the audit comparison output

`threat_audit_comparison.html` has six sections:

1. **Executive Summary** -- one-paragraph synthesis plus counts table.
2. **Threats Confirmed by Audit** -- anticipated AND found in code. Highest priority.
3. **Threats Not Confirmed by Audit** -- each with the reasoning category: well-mitigated, audit didn't reach this code, architectural only, or unable to determine.
4. **Audit Findings Not Anticipated by Threat Model** -- often the most valuable section, because it reveals threat-modeling gaps.
5. **Partial Matches** -- the audit confirmed part but not all.
6. **Coverage Analysis** -- coverage percentages and priority/severity correlation.

There is deliberately no "Recommended Next Steps" section. Findings carry severity and fix
guidance; sequencing belongs to the team that owns the code.

The complete finding list is `audit_state/findings_registry.md` -- the canonical source, in a
format that is git-diffable, greppable, and parseable into a ticketing system.

## Working with the diagrams

Diagram layout is computed by `skills/stride-threat-model/scripts/render-drawio.ps1`, not written
by the model. The model supplies a data file describing what belongs on each diagram -- which
component sits in which tier, which flows exist, which are unprotected -- and the script does
every coordinate. Nodes are placed into a grid, large tiers wrap across grid columns rather than
running down the page, and edges travel only through node-free gutters so an edge cannot cross a
component.

If a diagram still needs adjustment, edit the `.drawio` directly in draw.io. The data file
(`04-diagram-data.json`) is the input to regenerate from, and the rendered `.drawio` is output.

Any change to the layout rules themselves is verified by rendering a fixture and looking at the
exported PNG. That loop is the only method that has reliably caught layout defects -- most of
them were two individually correct rules interacting at a case neither anticipated, which is
exactly what reading the spec cannot catch.

## Resuming across sessions

Both workflows maintain a state file in their output directory tracking completed phases. If a
session ends before all phases finish, start a new session and ask to resume; the state file is
read and work continues at the next pending phase.

Starting a fresh session at each phase boundary is recommended even without a failure -- the
rehydration steps make it free, and instruction adherence is measurably better in a fresh session
than late in a long-running one. This matters most for the heavy phases.

## Output encoding

Output is ASCII-only by default -- no em-dashes, smart quotes, or other Unicode in Markdown, HTML
or CSV -- so files render correctly across environments without BOM or encoding fallback issues.

## Known limitations

Real characteristics of the toolchain, not bugs.

- **Run-to-run variation in findings.** Both workflows produce different findings between runs against the same code. The threat model's ceiling is roughly 20-25 threats -- a ceiling, not a target; a clean, well-scoped run may legitimately produce far fewer, and code-level candidates are routed to the audit via the Excluded Threats Ledger rather than padded into the table. This is LLM sampling, not a defect.

- **Disposition matching is probabilistic.** When a run detects an archived `dispositions.csv` and transfers matched dispositions forward, matching is conservative and high-confidence. In practice about 50-70% transfer even when most underlying threats are unchanged, and results vary across re-runs. Verify transferred dispositions during the next review session; expect to re-disposition some threats each time.

- **Large codebases can exhaust context.** The phase splits and state-file resume mitigate this. If you still hit limits, scope to one service in a monorepo rather than the whole repo.

- **The audit comparison output can be large.** 20-25 threats against 25-30 findings produces 100-200KB of Markdown and a similarly long HTML report. Expect coordinated mode to need a full additional session for Phase 6 alone.

- **Coordinated audits require a threat model in the workspace.** Delete or rename the threat model directory between runs and the audit falls back to standalone, with no comparison output.

## Repository layout

- `skills/stride-threat-model/` -- the threat model skill: `SKILL.md` orchestrator, `references/` methodology, `scripts/` deterministic steps
- `code-security-audit.md` -- the audit prompt, and the carve source for the audit skill
- `tests/` -- deterministic regression suites for the skills' scripts
- `designs/` -- design records for changes that needed one. These state intent at a point in time; verify against `skills/` before citing anything as current behaviour.
- `docs/executor-limitations.md` -- a dated field record of what an executor would not do unless the harness forced it
- `archive/` -- frozen, superseded prompts. Not maintained. See `archive/README.md`.
- `CHANGELOG.md` -- version history for both workflows
