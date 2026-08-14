<!-- SKILL VERSION: v25-skill (2026-07-21a) -- methodology carved verbatim from PROMPT VERSION v24 (2026-07-16a) -->

### Phase 3 Rehydration (MANDATORY FIRST STEP)

Read STATE.md and 02-threats.md. The threats file on disk is the authoritative source for every threat that will appear in the exports -- every CSV row, every HTML table cell, every markdown line must come from the content you just re-read, not from conversation memory.

Read these files with the Read tool (disk content overrides memory): {PROJECT_NAME}-threat-model/STATE.md, {PROJECT_NAME}-threat-model/02-threats.md.

If `02-threats.md` does not exist or is empty, STOP and report the error -- Phase 2C did not complete consolidation and Phase 3 cannot proceed. Re-run Phase 2C (which will rebuild `02-threats.md` from the surviving 02a/02b/02c sub-files).

Disk content takes precedence over conversation memory. If a threat ID, component name, or priority value in your memory does not appear in the on-disk threats file, do not invent it into the exports.

STATE.md is orchestrator-owned. Do not read-modify-write it.

After reading, acknowledge in one line the total threat count and priority breakdown found on disk.

If 03-dispositions-matched.md exists, read it; its rows are the matched dispositions the format sections below refer to. If absent, all disposition fields render empty/default.

### 3B -- CSV for Excel
Produce a single CSV file at `.\{PROJECT_NAME}-threat-model\outputs\threats.csv`.

`threats.csv` -- one row per threat from the main table (Confirmed and Likely); this is every threat the model emits. Header row required, columns in this exact order:

```
ThreatID,Confidence,OriginalPriority,RevisedPriority,Category,OWASP,Component,TrustBoundary,Title,ThreatAgent,Asset,Attack,AttackSurface,Impact,Description,Evidence,Likelihood,SecurityControl,ResidualRisk,Mitigation,Disposition,DispositionRationale
```

Column names must match the header row above verbatim (spacing, capitalization, no spaces inside names) so any downstream Excel templates or scripts have a stable contract. Sort rows by OriginalPriority (Priority 1 first, then Priority 2), then by Confidence (Confirmed before Likely), then by ThreatID ascending.

Column-by-column content comes from the main threat table in `02b-threats.md` (which Phase 2C rolled into `02-threats.md`). Every column except `OriginalPriority`, `RevisedPriority`, `Disposition`, and `DispositionRationale` is populated from the corresponding column in that table. The `Confidence` column carries the Confirmed/Likely value from the main table.

**OriginalPriority** is this run's Priority rating for the threat (identical to the Priority column in 02b), before any disposition. Always populated.

**RevisedPriority** is a three-state review signal: empty = the threat has never been through a stakeholder review; equal to OriginalPriority = reviewed and confirmed; different = reviewed and revised. Do not default RevisedPriority to OriginalPriority when no disposition matched -- the empty value carries information.

**Disposition** and **DispositionRationale** are populated from matched dispositions (if any) discovered in Phase 3 Disposition Discovery:
- If a disposition was matched for this threat: populate the cells with the matched values.
- If no disposition was matched: emit as empty strings.

Header row must include both columns; data rows have either populated values or empty strings.

#### CSV rules:
- Use RFC 4180 escaping. Fields containing commas, quotes, or newlines must be wrapped in double-quotes; embedded double-quotes become `""`.
- Replace internal newlines in multi-line fields with ` | ` (space-pipe-space) so Excel cells stay single-line -- important for the Description and Mitigation columns where cells can get long.
- ASCII-only content per Operating Rule 14. With pure ASCII there is no BOM concern; Excel and other consumers will render correctly without encoding fallback issues.
- Write with the Write tool per the decision table in common.md rule W. PowerShell + `Out-File` is the fallback only if the Write tool fails (e.g., on very long content).

After writing, validate by reading the first 3 lines with `Get-Content -TotalCount 3` and print them so the user can confirm the header row and the first data row look right.

**Phase 3B Completion Banner:**
```
=== PHASE 3B COMPLETE: outputs/threats.csv WRITTEN ===
Threat count: <N>  |  Priority 1: <N>  |  Priority 2: <N>
Return this banner verbatim as the end of your completion summary.
```
