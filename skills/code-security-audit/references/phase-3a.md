<!-- SKILL VERSION: v1-skill (2026-07-29a) -->

# Phase 3A -- Worker Security Review (SUBAGENT, one per partition, RUN IN PARALLEL)

You are one of up to five workers running AT THE SAME TIME as your siblings. Everything unusual about
your instructions follows from that.

Read `common.md`, `global-rules.md` and `schemas.md` first. `schemas.md` defines every field you must
populate; `global-rules.md` carries the SEVERITY SCOPE that decides what counts as a finding at all.

## Values from your briefing

| Placeholder | Source |
|---|---|
| `<partition_id>` | your briefing -- YOUR partition, and only yours |
| `{PROJECT_NAME}` | your briefing |
| `MODE` | `audit_state/coordination_mode.md` -- read it FIRST |
| finding ID block | your briefing -- e.g. `F-021` through `F-040` |

Your exact file list is `audit_state/partitions/<partition_id>.txt`. Read it uncapped (rule R). It is
your scope: every file in it, and no file outside it except directly relevant shared or
trust-boundary files as the methodology allows.

## Your READ FLOOR is mandatory, and it is checked

`audit_state/partitions/<partition_id>.readset.txt` lists the files in your partition that carry
the audit's actual defect surface -- entry points, auth and session code, data access, external
calls, config and IaC, dependency manifests, and any source file containing a dangerous API.
**Read every one of them, in full.**

It is a computed subset, not the whole partition, precisely so it is achievable. The companion
`.readset-deferred.txt` lists files deliberately NOT required -- quiet source with no dangerous
pattern, docs, tests, generated output. You may pattern-scan those; you are not required to read
them.

After you return, the ORCHESTRATOR reconciles your floor against the harness's own record of
every file you opened -- a transcript you do not write and cannot edit. A short read comes back
as a bounded list of named files to go and read, not as an instruction to "read more."

Do NOT write a verdict about your own coverage. Not "coverage adequate", not "all relevant files
reviewed", not any verdict-shaped sentence about how much you read -- not even a true one. Report
what you found; the coverage number is computed, not claimed. If you want your own worklist, you
may append the files you read to `audit_state/workers/<partition_id>/files_read.txt`, one path per
line -- it is used as a cross-check, never as the coverage record itself.

## Finding IDs: use your assigned block and nothing else

Your briefing gives you a numeric range. Assign `F-NNN` ids from inside it, in discovery order. Never
use an id outside your block and never renumber anything. Your siblings hold adjacent blocks and are
writing at this moment; a collision corrupts the merged registry, and `merge-findings.ps1` will fail
the whole run rather than guess which finding was which.

## Write ONLY your own directory

Every file you produce goes under `audit_state/workers/<partition_id>/`:

- `security_review.md`
- `findings.md`
- `attack_paths.md`
- `evidence_index.md`

The methodology below lists `audit_state/findings_registry.md` and `audit_state/attack_paths.md` among
this phase's outputs. **Do not write them.** That instruction assumes sequential workers with a stop
between each, which is how the source prompt runs. You are parallel: concurrent read-modify-write on
one file silently discards whichever sibling got there first, and nothing detects it, because your own
write verification would pass. The orchestrator merges every worker's directory afterwards. Your
per-partition files ARE your contribution. See `common.md` rule W-p.

## You cannot see your siblings' findings

The methodology lists `audit_state/findings_registry.md (if present)` as an input. It will not be
present -- it is assembled after every worker returns. Do not wait for it, do not look for a partial
copy, and do not reference finding ids you have not written yourself.

Scope `rel:` to findings inside your own partition. Cross-partition relationships and attack paths
that span partitions are established later, by Phase 3B/4B (which runs after you and can read every
worker directory) and by Phase 5. Nothing is lost by you not doing it; something IS lost if you invent
it.

## Severity: Critical and High only

If an issue is Medium, Low or Info, do not write it up. Move on without creating a finding. Do not
record it at a higher severity to keep it -- `merge-findings.ps1` fails the run on any severity
outside Critical/High, and inflating one to survive the check is worse than dropping it.

This bar is LOWER than the threat model's, not higher: defence-in-depth findings belong here and need
no independent exploitability argument. Apply the carved RISK SCORING as written and do not import
tests from the threat-modeling prompt.

## Overrides of the carved methodology below

- **Its STOP and "type proceed" banner:** you have no user to prompt. Write your files, verify each
  write (rule W-d), return the completion banner verbatim in your summary, end your turn.
- **STATE.md and partition_status.md:** orchestrator-owned. Do NOT update either, despite the
  instruction to record your partition as `security_complete`. Report completion in your summary; the
  orchestrator records it.
- If you hit something only the user can decide, do not guess: write what you have, and return the
  question in your summary for the orchestrator to relay (rule X).

## Methodology (verbatim -- do not edit inside the markers)

<!-- BEGIN VERBATIM CARVE src=code-security-audit.md lines=425-540 sha256=59941e42a7764454715737aeae912b24e579dff5c0def776590c9e493e9157ac -->
### PHASE 3A -- WORKER SECURITY REVIEW
INPUT:
- audit_state/coordination_mode.md
- audit_state/01_discovery.md
- audit_state/02_risk_prioritization.md
- audit_state/partition_plan.md
- audit_state/shared_components.md
- audit_state/findings_registry.md (if present)
- audit_state/workers/<partition_id>/worker_context.md (if present)
- {PROJECT_NAME}-threat-model/02-threats.md (in COORDINATED mode only)

SCOPE:
- one partition only
- plus directly relevant shared or trust-boundary files
- Critical and High severity findings ONLY (see SEVERITY SCOPE in GLOBAL RULES). If an issue you find is Medium, Low, or Info severity, do not write it up -- move on without creating a finding.

MODE-DEPENDENT BEHAVIOR:

Read `coordination_mode.md` first. The MODE value determines what additional work this phase performs:

In STANDALONE mode: produce findings normally. Leave `threat_id` and `threat_match` fields as `null` in all findings. Use the deployment exposure recorded in coordination_mode.md to weight Exploitability scores per RISK SCORING.

In COORDINATED mode: produce findings as in standalone mode, then perform the threat cross-reference procedure below for every finding before writing it to disk. Use the deployment exposure inherited from the threat model.

THREAT CROSS-REFERENCE PROCEDURE (COORDINATED mode only):

For each new finding the worker produces in this partition:
1. Read the threats from `{PROJECT_NAME}-threat-model/02-threats.md`. The threat model contains TWO matchable structures, both in that file:
   - The MAIN threat table (Confirmed and Likely threats), tabular with stable IDs like `01`, `02` (two digits; the threat model caps at 25 threats). Each threat has a Component (matches inventory C-NNN IDs), Title, Category (STRIDE), OWASP mapping, and Description.
   - The EXCLUDED THREATS LEDGER (EX-NNN rows, from Phase 2C of the threat model; may be absent in models generated by older prompt versions). These are candidates the model considered but did not promote to the main table, each with a reason. Three reasons are leads routed to this audit to verify: `Code-level` (a specific implementation defect the model spotted), `Unverified` (an architecturally plausible threat the model could not ground in its System Map -- these carry the confirming question to answer, and in older threat models lived in a separate Inferred table now folded into the ledger), and `Attested-mitigated (unverified)` (v24+ models: a candidate suppressed only by a user-attested control the model could not verify in code -- the row names the control and the check that would verify it). Other reasons (`Fully mitigated`, severity/likelihood/scope) are exclusions, not leads.
2. For the current finding, scan in this order and stop at the first qualifying match:
   a. MAIN table -- Strong match: same Component, same OWASP category, technical content aligns (e.g., audit found "bearer session cookie issued with no token binding at src/auth/session.go:120" and threat 01 is "Session token replay due to absent token binding" against the same C-003 component). Set `threat_id = "01"`, `threat_match = confirms`.
   b. MAIN table -- Partial match: same Component, related but not identical concern (e.g., audit found "missing CSRF token validation" and threat 11 is "session hijacking in user dashboard" against the same C-005 component -- both are session-related but addressing different aspects). Set `threat_id = "11"`, `threat_match = partial`.
   c. EXCLUDED THREATS LEDGER -- match on Component + STRIDE category + technical content, then branch on the matched row's Exclusion Reason:
      - `Code-level` or `Unverified`: set `threat_id` to the EX-NNN ID, `threat_match = confirms-seeded`. The threat model routed this concern to the audit as a lead and the audit has now verified it -- the coordinated handoff working as designed. For an `Unverified` row (the finding answers its confirming question in the affirmative) this is especially high-value: the audit supplied the code-level verification the threat model could not, completing what the model left open -- what older prompt versions called promoting an Inferred threat.
      - `Attested-mitigated (unverified)`: set `threat_id` to the EX-NNN ID, `threat_match = contradicts-exclusion`. The user attested a control and the audit found the exposure anyway -- the attestation was wrong or stale, exactly the failure mode this ledger reason exists to catch. Quote the attested control claim alongside the finding evidence; flag prominently.
      - `Fully mitigated`: set `threat_id` to the EX-NNN ID, `threat_match = contradicts-exclusion`. The threat model judged the issue mitigated and the audit found a code defect anyway -- the mitigation judgment was wrong. Flag prominently.
      - any other reason (severity floor, likelihood, scope): set `threat_id` to the EX-NNN ID, `threat_match = excluded-by-design` -- the finding is real but its absence from the main table is a scoping decision, not a miss.
   d. No match anywhere: set `threat_id = null`, `threat_match = unanticipated`.
3. Record the match decision in the finding's `threat_id` and `threat_match` fields.
4. Do NOT invent new threats during this phase. If a finding has no matching threat, it is `unanticipated` -- that's the value-add of the audit.
5. A single threat may be confirmed by multiple findings (one threat, multiple code defects implementing the vulnerability). A single finding may only point to one threat (the closest match). If a finding genuinely matches two threats, choose the strongest match and record the other in `rel`.

The `unanticipated` and `contradicts-exclusion` findings are the most important output for stakeholders. They represent code defects the threat model did not anticipate (or wrongly judged mitigated). Flag them clearly in worker findings files.

ANALYZE (mapped to OWASP Top Ten 2021 and NIST 800-53r5):
- **A01:2021 - Broken Access Control** (NIST: AC-*, IA-*)
  - auth/authz patterns
  - IDOR vulnerabilities
  - privilege escalation
- **A02:2021 - Cryptographic Failures** (NIST: SC-8, SC-12, SC-13, SC-28)
  - secrets management + crypto
  - sensitive data exposure
  - insecure transmission
- **A03:2021 - Injection** (NIST: SI-10, SI-11)
  - SQL, NoSQL, OS command, LDAP injection
  - XSS, template injection
- **A04:2021 - Insecure Design** (NIST: PL-8, SA-8, RA-3)
  - missing security controls
  - threat modeling gaps
- **A05:2021 - Security Misconfiguration** (NIST: CM-6, CM-7, CM-8)
  - config integrity
  - default credentials
  - unnecessary features enabled
- **A06:2021 - Vulnerable and Outdated Components** (NIST: RA-5, SI-2)
  - supply-chain-visible risks
  - dependency vulnerabilities
- **A07:2021 - Identification and Authentication Failures** (NIST: IA-2, IA-5, IA-8)
  - session management
  - credential management
- **A08:2021 - Software and Data Integrity Failures** (NIST: SI-7, SA-10, SA-15)
  - deserialization vulnerabilities
  - insecure CI/CD
- **A09:2021 - Security Logging and Monitoring Failures** (NIST: AU-2, AU-3, AU-6, AU-12)
  - logging and audit
  - incident detection
- **A10:2021 - Server-Side Request Forgery (SSRF)** (NIST: SC-7, SI-10)
  - SSRF / outbound calls
  - URL validation

Additional analysis:
- validation patterns
- error handling
- race conditions

**COMPLIANCE FRAMEWORK:**
- Map all findings to NIST 800-53 Rev 5 controls
- Document control family (AC, IA, SC, SI, AU, CM, etc.)
- Identify control failures and recommended control enhancements

OUTPUT FILES:
- audit_state/workers/<partition_id>/security_review.md
- audit_state/workers/<partition_id>/findings.md
- audit_state/workers/<partition_id>/attack_paths.md
- audit_state/workers/<partition_id>/evidence_index.md
- audit_state/findings_registry.md
- audit_state/attack_paths.md
- audit_state/partition_status.md (this partition set to security_complete)

Before printing the banner, perform both state updates:
1. Update audit_state/partition_status.md: set partition '<partition_id>' to security_complete.
2. Update audit_state/STATE.md: mark partition '<partition_id>' done under Phase 3A. Before writing Resume Instruction, check the Phase 3A per-partition list in STATE.md (or partition_plan.md) for ANY partition still pending or in_progress -- never assume the partition just completed was the last one without checking this list. If at least one partition still needs Phase 3A, Resume Instruction = "Begin Phase 3A for partition '<next_pending_partition_id>'." Only if EVERY partition shows Phase 3A done should Resume Instruction = "Begin Phase 4A for partition '<first_partition_id>'."

**Phase 3A Completion Banner:**
```
=== PHASE 3A COMPLETE: SECURITY REVIEW DONE FOR PARTITION '<partition_id>' ===
  audit_state/workers/<partition_id>/security_review.md
  audit_state/workers/<partition_id>/findings.md
  audit_state/findings_registry.md
STATE.md and partition_status.md updated: partition '<partition_id>' recorded as security_complete.
Resume Instruction set to: <the instruction written in the state update above>
Type 'proceed' to continue.
```

STOP
<!-- END VERBATIM CARVE -->