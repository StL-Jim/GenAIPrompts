<!-- SKILL VERSION: v25-skill (2026-07-21a) -- methodology carved verbatim from PROMPT VERSION v24 (2026-07-16a) -->

### Phase 2C -- Questions, Assumptions, and Consolidation

#### Phase 2C Rehydration (MANDATORY FIRST STEP)

Read STATE.md, 00-scope.md, 01-inventory.md, 02a-context.md, and 02b-threats.md. (00-scope.md informs the Excluded Threat Categories rationale and the 02-threats.md header's deployment exposure line.)

Read these files with the Read tool (disk content overrides memory): STATE.md, 00-scope.md, 01-inventory.md, 02a-context.md, 02b-threats.md, and 02b-excluded.md (the excluded-candidate working list Phase 2B wrote -- it is the VERBATIM source for the Excluded Threats Ledger below; you carry its rows forward, you do not reconstruct them from counts).

STATE.md is orchestrator-owned. Do not read-modify-write it.

#### Phase 2C Work

Two outputs in this sub-phase:

**Output 1: `02c-assumptions.md`** -- Questions and Assumptions, with the threat filtering summary required by the original prompt structure.

Required sections:

```markdown
# Phase 2C -- Questions and Assumptions

## Threat Filtering Summary
- Total threats identified during STRIDE matrix walk: <N>
- Threats included in the model: <N> (25 is a ceiling, not a target -- emit only what qualifies per Phase 2B prioritization)
  - Confirmed (main table): <N>
  - Likely (main table): <N>
- Threats not promoted to the main table:
  - <N> Medium severity (excluded per scope constraints)
  - <N> Low likelihood (not realistic for this system)
  - <N> Fully mitigated (no residual risk; code/IaC-verified controls only)
  - <N> Attested-mitigated (unverified) (suppressed only by a Phase 0 attested control; routed to the code audit as a verification lead)
  - <N> Out of scope (e.g., client-side only, physical security)
  - <N> Code-level (routed to the code security audit via the Excluded Threats Ledger)
  - <N> Unverified (plausible but not grounded in the System Map; routed to the code audit via the ledger)

## Excluded Threat Categories
- <Category>: <one-line rationale for deprioritization>
- ...

## Excluded Threats Ledger
BUILD THIS FROM `02b-excluded.md`, NOT FROM MEMORY OR COUNTS. Phase 2B wrote every excluded candidate to `02b-excluded.md` (one line: `component ID | STRIDE category | short title | exclusion reason`). Carry each of those lines forward into one ledger row here, verbatim in substance -- assign the `EX-NN` id, map the four fields to the columns, and expand the exclusion reason to satisfy the per-reason requirements below. Do NOT reconstruct or guess the ledger from the Filtering Summary's rolled-up counts: the counts tell you HOW MANY rows to expect, `02b-excluded.md` tells you WHICH candidates they are with 2B's actual reasoning. If `02b-excluded.md` is missing or its line count is less than the not-promoted total, STOP and report it (Phase 2B did not persist the working list) rather than inventing rows to hit the count.

One row per candidate threat that was considered during the Phase 2B matrix walk but not promoted to the main table -- excluded (severity, likelihood, scope, or full code/IaC-verified mitigation), suppressed only by an attested control (`Attested-mitigated (unverified)`), or admitted-but-Unverified (architecturally plausible, but its asset or path could not be grounded in the System Map). This ledger exists so a downstream code audit (COORDINATED mode) can distinguish "considered and not promoted" from "never considered" -- an audit finding that contradicts a "fully mitigated" exclusion, that verifies (or disproves) an attested mitigation, or that verifies an "Unverified" lead, is a significant result. Keep each row to one line; do not expand into full threat rows.

| ExcludedID | Component | STRIDE Category | Short Title | Exclusion Reason |
|------------|-----------|-----------------|-------------|------------------|
| EX-01 | C-003 | Tampering | SQL injection in admin report filter | Fully mitigated -- parameterized queries verified [evidence: src/admin/reports.go:40-66] |
| EX-02 | C-001 | Denial of Service | Generic volumetric DDoS on edge | Generic-to-all-systems; CDN/WAF absorbs; Low likelihood |
| EX-03 | C-005 | Elevation of Privilege | Reporting export may lack row-level authorization | Unverified -- confirm whether the export query in the reporting service applies a tenant or row-level authorization filter |

Exclusion Reason must begin with one of: `Fully mitigated`, `Attested-mitigated (unverified)`, `Medium severity`, `Low likelihood`, `Out of scope`, `Generic-to-all-systems`, `Code-level`, `Unverified`. For `Fully mitigated` rows, cite the CODE or IaC evidence for the mitigating control -- a user-attested citation alone does not support this reason (Operating Rule 2 asymmetry); if attestation is all you have, the reason is `Attested-mitigated (unverified)`. For `Attested-mitigated (unverified)` rows, name the attested control AND the specific code/IaC check that would verify it, e.g. `Attested-mitigated (unverified) -- Q3 attests Okta SSO fronts this service; verify the ingress/authn middleware for the admin API actually enforces OIDC` -- the code audit consumes these as seeded verification leads. For `Code-level` rows, add one clause naming the suspected defect and its location so the partner code audit can use the row as a seeded lead. For `Unverified` rows, add the specific question a reviewer or the code audit would answer to confirm the threat (the content earlier prompt versions recorded in an Inferred table's WhatWouldConfirm column), e.g. `Unverified -- confirm whether the reporting export applies a row-level authorization filter`.

Ledger completeness (mandatory reconciliation -- this ledger is where a rich foundation produces the most content and is the most likely thing to truncate): the ledger MUST contain exactly one row for every candidate counted as not-promoted in the Threat Filtering Summary above (the sum of the Medium / Low likelihood / Fully mitigated / Attested-mitigated (unverified) / Out of scope / Code-level / Unverified counts). Before finishing 2C, state the check verbatim: `Ledger rows: <N>; 02b-excluded.md lines: <N>; not-promoted candidates in Filtering Summary: <N>; match: <yes | DEFICIT of X rows -- truncation, fix before finishing>` (all three counts must agree). A ledger shorter than the sum is a truncation, not a small exclusion set -- a rule violation to repair, never to accept. With a rich inventory this ledger routinely exceeds 30 rows; write it as the LAST section of 02c-assumptions.md, and if it is long, append its rows in a separate Edit tool step so it is never dropped when the file is first generated.

## Control Coverage Summary
The reverse index from governance-framework controls to the threats whose Mitigation cites them. Build it by extracting every parenthesized control identifier from the main threat table's Mitigation column (for NIST 800-53 the `AC-3` / `SC-8(1)` form; other Q5 frameworks use their own identifier form). One row per distinct control; sort by Count descending, then control ID. This is the "which controls keep recurring" view -- heavily-cited controls and families indicate where the system's protection gaps concentrate.

| Control | Name | Family | Cited By | Count |
|---------|------|--------|----------|-------|
| AC-3 | Access Enforcement | AC | 01, 04, 09 | 3 |
| SC-8 | Transmission Confidentiality and Integrity | SC | 02, 07 | 2 |

## Questions for Stakeholders
- <Specific question about unclear architecture or security controls>
- ...

## Assumptions Made
- <Assumption about security controls, architecture, or deployment, with the gap that drove the assumption>
- ...

## Coverage and Known Gaps
Copied from 01-inventory.md's Coverage Report (2C rehydration already reads that file): files read <N>, files skipped <N> with reasons, and every known gap with a one-line explanation of what could not be fully analyzed and why (e.g., very large files read only in targeted ranges). Honest gaps belong in front of stakeholders -- a threat model that hides what it could not see overstates its own coverage.
- Files read: <N> | Files skipped: <N> (<reasons>)
- Gap 1: <what and why>
- ...
```

**Output 2: `02-threats.md`** -- the canonical, consolidated Phase 2 output that Phase 3 reads. The consolidation is intentionally done with PowerShell rather than by reading each sub-file into the agent's context and writing the union with the Write tool -- the latter forces all sub-files' content through the working window for no reasoning benefit, just file gluing. PowerShell streams the content through the OS and keeps Phase 2C's context cost low.

The `02-threats.md` file should consist of, in order: a header section (title, project name, current date, the System Restatement copied verbatim from 01-inventory.md, one-paragraph summary of threat counts by priority, components reviewed, deployment exposure), then the verbatim contents of `02a-context.md`, `02b-threats.md`, `02c-assumptions.md`.

Steps:

1. Write `02c-assumptions.md` with the Write tool per the schema above.

2. Write the header section to `02-header.md` using the Write tool (title, project name, date, the System Restatement copied verbatim from 01-inventory.md, summary paragraph).

3. Concatenate header + three sub-files into `02-threats.md` using PowerShell:
   ```powershell
   $WORKSPACE    = '<workspace path from your briefing>'
   $PROJECT_NAME = '<project name from your briefing>'
   $outDir = Join-Path $WORKSPACE "$PROJECT_NAME-threat-model"
   Get-Content `
     "$outDir\02-header.md",
     "$outDir\02a-context.md",
     "$outDir\02b-threats.md",
     "$outDir\02c-assumptions.md" |
     Set-Content "$outDir\02-threats.md" -Encoding UTF8
   Remove-Item "$outDir\02-header.md"
   ```

4. Verify per common.md rule W-d. If `02-threats.md` is missing, zero bytes, or shorter than the sum of inputs, retry the PowerShell step. Do NOT fall back to having the agent read all sub-files and write the concatenation manually -- that defeats the purpose.

Return your completion banner to the orchestrator (it owns STATE.md).

**Phase 2C Completion Banner:**
```
=== PHASE 2C COMPLETE: PHASE 2 CONSOLIDATED ===
  .\{PROJECT_NAME}-threat-model\02c-assumptions.md
  .\{PROJECT_NAME}-threat-model\02-threats.md   <-- canonical Phase 2 output, used by Phase 3
Sub-files retained for recovery: 02a-context.md, 02b-threats.md
Phase status reported to orchestrator (it owns STATE.md).
Return this banner verbatim as the end of your completion summary.
```
