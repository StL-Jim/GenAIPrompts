<!-- SKILL VERSION: v25-skill (2026-07-21a) -- methodology carved verbatim from PROMPT VERSION v24 (2026-07-16a) -->

### Phase 2B -- STRIDE Threat Enumeration

#### Phase 2B Rehydration (MANDATORY FIRST STEP)

Read STATE.md, 00-scope.md, 01-inventory.md, and 02a-context.md. You will reason about threats against the components in the inventory and the data flows in 02a-context.md, with particular attention to flows that cross trust boundaries. 00-scope.md is required here, not optional: the threat inclusion criteria and the ThreatAgent column both key off the deployment exposure it records, the Mitigation column keys off its governance framework, the SecurityControl column keys off the existing controls the user listed, and its out-of-scope list bounds any code verification reads.

Read these files with the Read tool (disk content overrides memory): STATE.md, 00-scope.md, 01-inventory.md, 02a-context.md.

STATE.md is orchestrator-owned. Do not read-modify-write it. Re-read source code only when verifying a specific control is absent or a flaw is present -- read targeted line ranges, not whole files. A candidate you cannot ground in the System Map does not require code verification -- it becomes an Unverified ledger row (Phase 2C), not a threat.

#### Threat Prioritization (apply during enumeration)

Include ONLY threats meeting all five criteria: CRITICAL or HIGH risk severity calculation outcome (exclude Medium/Low); Medium or High likelihood (exclude Low/Very Low); realistic based on known attack patterns rather than theoretical exploits; actionable through reasonable controls; and architecture-level per the test below.

Architecture-level test. A threat must be expressible as actor -> path -> asset -> missing or weak control at component, data-flow, or trust-boundary granularity. Litmus: would this finding survive a correct re-implementation of the same design? If rewriting the code without changing the architecture eliminates it (an injection in one function, missing sanitization at one handler, a hardcoded secret), it is a code-audit finding, not a threat-model finding -- record it in the Excluded Threats Ledger with reason `Code-level` and move on; the partner code audit consumes that ledger. A present flaw may still anchor a threat when it evidences a systemic gap (e.g., no central parameterization standard on the app-to-data-tier flow): state the threat at the architectural level and cite the flaw as supporting evidence.

Maximum 20-25 threats in the main threat table (Confirmed and Likely). This is a ceiling, NOT a target: if only 7 threats qualify, emit 7. A small table of verified architectural exposures is worth more than a padded one -- never backfill with code-level or generic findings to reach the range. If more than 25 qualify, rank by risk severity (Likelihood x Impact) and select the top 20-25; record the count of lower-priority threats excluded in the Phase 2C Filtering Summary.

Scales used in the risk severity calculation (defined here once; no other values are valid):
- Likelihood scale: Very Low, Low, Medium, High
- Impact scale: Low, Medium, High, Critical

Likelihood anchors -- score against the ThreatAgent named in the row, and do NOT inflate a likelihood to get a threat past the inclusion gate (a threat that misses the gate belongs in the Excluded Threats Ledger):
- High: the agent can attempt the attack from its starting position with no prerequisite compromise, using a widely known technique (e.g., an unauthenticated internet-reachable path for an External Attacker).
- Medium: requires one prerequisite the agent plausibly achieves (valid low-privilege credentials, internal network position, one phished user).
- Low / Very Low: requires chained prerequisites, insider collusion, or nation-state resources. Excluded by the gate.

Impact anchors:
- Critical: bulk exposure of the highest-classification data the system handles, cross-tenant boundary crossing, or code execution / full control in production.
- High: compromise scoped to a single user, session, or component; partial data exposure; sustained outage of a critical service.
- Medium / Low: degraded service, or exposure of internal metadata or non-sensitive data.

Risk severity calculation:
- CRITICAL = High Likelihood x Critical Impact
- HIGH = High Likelihood x High Impact, OR Medium Likelihood x Critical Impact

Displayed Priority label mapping (explicit, not left to inference): the threat table's `Priority` column is the display label for this calculation's outcome -- CRITICAL displays as **Priority 1**, HIGH displays as **Priority 2**. Likelihood and Impact themselves are never renamed or displayed as Priority; only the final CRITICAL/HIGH outcome is relabeled. CRITICAL and HIGH here are INTERNAL calculation vocabulary -- the SOURCE of the Priority label, not a co-label for it. They MUST NOT appear beside a Priority in any rendered or stakeholder-facing output: never `Priority 1 (Critical)`, never a `Critical`/`High` column, legend entry, or summary line paired with a Priority. Priority 1 and Priority 2 stand alone -- the organization deliberately replaced Critical/High finding ratings with Priority 1/2. (The ONE permitted appearance of these words in output is the risk-calc note's Impact and Likelihood SCALE values, e.g. `[Risk calc: High likelihood x Critical impact]` -- a different axis, explicitly labeled as likelihood/impact, not a finding rating.)

Each threat must be specific to this application's architecture, worth defending against given the deployment exposure recorded in 00-scope.md, and clear on why it matters for this system.

Infrastructure ownership gate (INFRA_OWNERSHIP in 00-scope.md). When PLATFORM-INHERITED: do NOT emit threats against the managed platform's internal configuration, and never predicate a threat on an unobserved principal or a hypothesized more-permissive policy (Operating Rule 2, no speculative preconditions). An infrastructure or IAM threat IS admissible here when grounded in either of two evidence sources: (a) a file in this repo that the app team owns -- its k8s manifests, its IaC, its listener/port/TLS configuration; the app's side of every data flow is always in this repo and always in scope, so a plaintext listener behind the platform's TLS-terminating proxy is admissible app-evidenced exposure, or (b) the attested platform profile from Phase 0 Q6a, cited as `[evidence: user-attested, Phase 0 Q6a]` -- e.g., a threat on the attested plaintext hop between the platform proxy and the app container. Reliance on UNATTESTED platform behavior is an Assumption (Assumptions Log), not a threat. When SELF-MANAGED: assess this repo's IaC normally -- absent-control findings against infrastructure the app team owns are valid, because those controls should live in this repo.

#### Verify against the system model, not the code

A threat model reasons top-down: an actor, a goal, a path, an asset, a trust boundary. The question is not "is there a flawed line of code?" but "is this exposure real for THIS system?" A threat is reputation-grade when its architectural conditions are confirmed against the system model from Phase 1 and Phase 2A:

1. **The asset exists.** The thing being attacked is a real asset in 02a-context.md (an AS-NNN entry).
2. **The path exists.** There is a data flow or access path that reaches the asset, ideally one that crosses a trust boundary (a DF-NNN in 02a-context.md, a TB-NNN it crosses).
3. **The control is absent or partial.** The control that would prevent or detect this exposure is not present, or is present but incomplete. This is the crux: most serious threats are about something MISSING (no token binding, no authorization check, no detective control on a sensitive path), and absence is harder to verify than presence. To claim a control is absent, you must have looked in the places it should be -- the relevant code, the IaC, the inventory's control listings -- and not found it.

For threats about a flaw that IS present (e.g., a concatenated SQL query), you confirm by reading the cited code and finding the flaw. For threats about a control that is ABSENT (the more common and more important case), you confirm by showing the asset, the path, and that you looked where the control should be and it was not there.

Code citations serve the architectural claim; they are not the claim itself. The evidence for "insider can exfiltrate the PII table undetected" is: the PII asset exists, a path reaches it, and no logging/DLP control sits on that path -- with code or IaC citations supporting the "no control" part. The evidence is architectural; the citations are in support.

#### Confidence levels

Every threat carries a confidence level that reflects WHAT YOU VERIFIED against the system model, not how sure you feel. It is recorded in the Confidence column of the main threat table.

- **Confirmed**: All three architectural conditions are verified. The asset and path are present in 02a-context.md, and the control-state (absent or partial) is verified -- for a present-flaw threat, the flaw is confirmed in cited code; for an absent-control threat, you looked where the control should be and it was not there. This is the reputation-grade level.
- **Likely**: The asset and path are confirmed, but the control-state is uncertain. A control might exist that the system model did not capture, or runtime configuration determines whether the exposure is real. State explicitly what you would need to check to reach Confirmed.
Confirmed and Likely are the only two confidence levels, and both go in the main threat table -- they are the only threats the model emits. There is no third "Inferred" level and no separate Inferred table. A candidate that cannot reach at least Likely -- its asset or path cannot be confirmed against the System Map in 02a-context.md -- is NOT written as a threat. Record it instead as an `Unverified` row in the Excluded Threats Ledger (Phase 2C), stating the specific question a reviewer or the code audit would answer to confirm it. This keeps the main table to threats the top-down method actually grounded, and hands the unconfirmable leads to the code audit, which verifies them bottom-up.

The verification effort is bounded: spend the rigor on candidates aiming for Confirmed or Likely. A candidate you cannot ground in the System Map is cheap by definition -- do not burn budget trying to verify it; record it as an `Unverified` ledger row and move on.

Realistic threat assessment -- for each candidate threat, ask:
1. Is this an OWASP Top 10 item? (If yes, prioritize and tag in the table.)
2. Has this attack been seen in the wild? (CVE databases, incident reports.)
3. Is it exploitable given our architecture, not just theoretically possible?
4. Attacker ROI: effort vs. value of compromise?
5. Are we a likely target? (Financial and government systems carry higher value.)
6. Do existing controls reduce this to acceptable residual risk? (If yes, exclude -- but ONLY when the control is verified in code or IaC. If the only evidence for the control is a Phase 0 attestation, the candidate is NOT excludable as mitigated: route it to the Excluded Threats Ledger as `Attested-mitigated (unverified)` per Operating Rule 2's attestation asymmetry.)

Categories to NOT include: theoretical attacks with no known exploits; threats already fully mitigated by existing code/IaC-verified controls (attested-only mitigation routes to the ledger as `Attested-mitigated (unverified)` instead); generic vulnerabilities common to all systems (e.g., "DDoS is possible"); out-of-scope threats (physical security, end-user device security).

Prioritize for government/financial systems: authentication bypass and credential theft; authorization failures and privilege escalation; PII/sensitive data exfiltration; supply chain attacks (compromised dependencies); secrets exposure (keys, passwords in logs/code); availability attacks on critical services.

De-prioritize unless specific evidence justifies inclusion: APT requiring nation-state resources; zero-day exploits in third-party managed services (AWS, Login.gov); social engineering of end users; physical attacks on data centers.

#### Phase 2B Work

Walk the STRIDE-per-element matrix as required by Operating Rule 4: for every component (and every boundary-crossing data flow), for every one of the six STRIDE categories, ask "does this apply?" Apply the prioritization rules above, including the architecture-level test; the 20-25 range is a ceiling, not a quota to fill.

Data-flow obligation: the System Map compels findings, not just context. Every data flow in 02a-context.md whose Encryption or AuthN column records none, plaintext, or unknown MUST end the phase accounted for -- either cited by a threat in the main table or recorded as an Excluded Threats Ledger row stating why it does not rise to one (fully mitigated by a code/IaC-EVIDENCED control; `Attested-mitigated (unverified)` when the only mitigation evidence is a Phase 0 attestation -- the flow is still accounted for, but the mitigation claim stays visible as a verification lead; out of scope; or Unverified with its confirming question). There is no silent third option: an observed unprotected flow that appears in no output is a rule violation, reported in the Filtering Notes check below.

While walking the matrix, keep a compact working list of every candidate threat that was considered but EXCLUDED (by the severity floor, likelihood floor, full code/IaC-verified mitigation, attested-only mitigation, scope rules, or the architecture-level test). For each excluded candidate record one line: component ID, STRIDE category, a short title, and the exclusion reason. WRITE this working list to `{PROJECT_NAME}-threat-model/02b-excluded.md` with the Write tool -- one line per excluded candidate in the form `component ID | STRIDE category | short title | exclusion reason` (exclusion reason beginning with one of the reason keywords the Phase 2C ledger uses: Fully mitigated, Attested-mitigated (unverified), Medium severity, Low likelihood, Out of scope, Generic-to-all-systems, Code-level, Unverified). This file MUST persist on disk because Phase 2C runs as a SEPARATE session and builds the Excluded Threats Ledger by carrying these rows forward VERBATIM -- it is not in your context then, so a candidate you exclude but do not write here is lost, and 2C would be forced to reconstruct (guess) the ledger from rolled-up counts. Its line count MUST equal the sum of the not-promoted counts in your Filtering Notes. This ledger is how a downstream code audit distinguishes "the threat model considered this and excluded it" from "the threat model never considered it." Do not expand these into full threat rows.

For each selected threat, verify its architectural conditions against the system model and assign a confidence level (Confirmed or Likely) per the Confidence Levels section above. Confirmed and Likely threats are filled into the main threat table. A candidate that cannot reach Likely -- asset or path not confirmable from the System Map -- is recorded as an `Unverified` row in the Excluded Threats Ledger (Phase 2C), not emitted as a threat.

Self-check before finalizing: for each Confirmed or Likely threat you must be able to write the architecture-vs-code explanation required by the Stakeholder Explainer below. If the honest explanation reduces to a specific implementation defect, the threat fails the architecture-level test -- move it to the Excluded Threats Ledger (`Code-level`) before writing 02b-threats.md.

Citation audit (Confirmed threats only): before writing 02b-threats.md, re-open the cited line range of each Confirmed threat and verify the exact lines support the control-state claim. If the cited code does not actually show the flaw or the absence of the control, fix the citation or demote the threat to Likely. This is bounded work -- only Confirmed rows, only the already-cited ranges -- and it is what makes the Evidence column trustworthy rather than merely plausible-looking.

Speculation audit (every row): also before writing 02b-threats.md, scan every threat's Description and Evidence cells for the anti-speculation tell-phrases from Operating Rule 2 ("assuming", "there may be", "if there exists", "presumably", "other users/roles/services likely") and for any precondition naming a principal, role, permission, or policy that no repo file and no Phase 0 attestation establishes. A failing row has exactly two exits: re-ground it (fix the Evidence cell to cite the repo file or user-attested fact that establishes the precondition) or remove it to the Excluded Threats Ledger as `Unverified` with its confirming question. No third option; a row may not stay in the table on the strength of plausibility. This audit is bounded, mechanical work -- a scan of cells just written -- and it exists because stated rules degrade as the context window fills; the audit at the end catches what the rule missed in the middle.

IAM / access-control hard gate (this is the failure mode that keeps recurring, so treat it mechanically, not as judgment): for ANY threat whose control-state claim concerns an IAM role, policy, permission, or a principal's access scope, the Evidence cell MUST cite the specific repo file that DEFINES that role or policy (its Terraform / IaC / manifest), or a Phase 0 Q6a attestation about it. An architectural citation alone (an `AS-`/`DF-`/`TB-` reference with no defining-file citation) does NOT ground an IAM-configuration claim -- the IAM config is neither the asset nor the flow, it is a specific file. If neither a defining-file citation nor an attestation is present -- the NORM in PLATFORM_INHERITED mode, where the IAM baseline lives outside this repo -- the threat is ungrounded: remove it, or record it `Unverified` in the ledger with its confirming question. Never carry an IAM threat into the main table on an architectural citation while the role or policy it names is defined in no file here.

For each Confirmed or Likely threat, fill in every column of the main threat table schema below.

#### Threat Table Schema (main table: Confirmed and Likely threats)

Only Confirmed and Likely threats go in this table -- and they are the only threats the model emits. Candidates that cannot be grounded in the System Map are routed to the Excluded Threats Ledger (Phase 2C, reason `Unverified`), not given a threat row here.

| Column | Description |
|--------|-------------|
| ThreatID | `01`, `02`, etc. Stable across re-runs. Maximum 25 threats so two digits is sufficient. |
| Confidence | One of: `Confirmed`, `Likely`. Reflects what was verified against the system model per the Confidence Levels section. Confirmed = asset, path, and control-state all verified. Likely = asset and path verified, control-state uncertain (the Description must state what would confirm it). |
| Priority | One of: Priority 1, Priority 2. Priority 1 = threats meeting the risk severity calculation's CRITICAL outcome; Priority 2 = threats meeting the HIGH outcome. (Medium and Low risk-calc outcomes are excluded entirely by the prioritization rules.) |
| Category | STRIDE category, exactly one: Spoofing, Tampering, Repudiation, Information Disclosure, Denial of Service, Elevation of Privilege. |
| OWASP | The OWASP Top 10 item this maps to (e.g., A01:2021), or `N/A`. |
| Component | The architectural component from the inventory. Use the exact same name as in 01-inventory.md and the Phase 4 diagrams. |
| TrustBoundary | The trust boundary this threat crosses or operates within, by TB-NNN ID. `N/A` if the threat is within a single trust zone. |
| Title | Specific, detailed name, stated at architectural granularity. Not "Broken Access Control" but "Tenant report-export path (DF-007) crosses TB-003 with no row-level authorization between the API tier and the reporting store." Never title a threat after a single function's defect. |
| ThreatAgent | The actor profile: External Attacker, Insider Attacker (a legitimate insider account acting under compromise or negligence -- phished credentials, malware on a workstation, careless misuse), Malicious Insider (a trusted person intentionally abusing their own legitimate access), Compromised Container, Rogue Developer, Supply Chain Attacker, Opportunistic Scanner, Competitor, or Nation State Actor. Choose per the deployment exposure recorded in 00-scope.md: Internet-facing favors External Attacker / Opportunistic Scanner / Competitor; Internal favors Insider Attacker / Malicious Insider / Compromised Container / Rogue Developer; Hybrid uses both profiles for respective components; all deployments always consider Supply Chain Attacker. |
| Asset | The specific asset targeted, by AS-NNN ID from 02a-context.md. |
| Attack | The specific attack technique. Reference MITRE ATT&CK techniques (e.g., `T1190 Exploit Public-Facing Application`) where applicable. |
| AttackSurface | Pick from: External Interfaces, Internal Network, Development & Deployment, Infrastructure & Orchestration, Configuration & Secrets, Observability & Operations, Supply Chain, Authentication & Identity, Data Storage, Client-Side. |
| Impact | Confidentiality, Integrity, and/or Availability. |
| Description | Why this threat matters for this component, how it would be exploited, and what the attacker gets. Combines what earlier versions called Why Applicable and Attack Path. Multi-sentence prose, but kept tight. For a Likely threat, state explicitly what would need to be checked to reach Confirmed. Every Description ends with the risk-calculation note in brackets: `[Risk calc: <Likelihood> likelihood x <Impact severity> impact]`, e.g. `[Risk calc: High likelihood x Critical impact]` -- this records the Impact severity value that produced the Priority (it appears nowhere else; the Impact column records CIA categories, not the severity scale), so a reviewer can audit the Priority rating from the row itself. |
| Evidence | The ARCHITECTURAL claim that makes this threat real, with code/IaC citations in support. Lead with the architectural conditions -- the asset (AS-NNN), the path (DF-NNN and the TB-NNN it crosses), and the control-state (absent or partial) -- then cite the code or IaC that supports the control-state claim. Example: `AS-004 (customer PII) reachable via DF-007 crossing TB-003; no query-logging or DLP control on this path [evidence: infra/db/reporting_role.tf:12-30 grants broad SELECT; no audit config in infra/db/]`. The citation supports the architectural claim; it is not the claim by itself. Mandatory per Operating Rule 2; multiple citations separated by `;`. Never cite `audit_state/` or `{PROJECT_NAME}-threat-model/` paths (Operating Rule 13a). |
| Likelihood | One of: Medium, High. The likelihood of exploitation given the architecture and real-world risk. (Low likelihood threats are excluded by prioritization rules.) |
| SecurityControl | EXISTING controls already in place that affect this threat. Use `None` if no controls exist. Use `Partial -- <what's missing>` if controls are incomplete. A control whose only evidence is a Phase 0 attestation renders as `Attested -- <control> (unverified in code)` with its `[evidence: user-attested, Phase 0 Q3/Q6a]` citation -- it may inform ResidualRisk, but per Operating Rule 2 it never removes the threat from this table or justifies a fully-mitigated exclusion. |
| ResidualRisk | The residual risk remaining after existing SecurityControl is applied but before recommended Mitigation. One of: Severe, Elevated. Re-run the risk severity calculation crediting the existing SecurityControl as it actually operates, then map the outcome: CRITICAL -> Severe, HIGH -> Elevated. Because existing controls can lower the outcome, ResidualRisk may map lower than the Priority column, which reflects the calculation before existing controls are credited (the schema example row is Priority 1 with ResidualRisk Elevated for exactly this reason). The words Critical and High never appear as ratings in stakeholder-facing artifacts. |
| Mitigation | Specific, actionable controls to add or strengthen. Each recommended action ends with its governance-framework control identifier in parentheses, e.g. `Enforce row-level authorization on the export path (AC-3); add query audit logging (AU-2); enforce TLS on the internal hop (SC-8(1))`. The framework is GOVERNANCE_FRAMEWORK from Phase 0 Q5 (default NIST 800-53 Rev 5); always use its specific control identifiers, never just the framework name. A Mitigation cell containing no parenthesized control identifier is a rule violation, not an oversight -- the same standard the Evidence column carries. These parenthesized identifiers are machine-extractable and are what the Phase 2C Control Coverage Summary aggregates. Reference OWASP and CIS Benchmarks where they add specificity. |
| Disposition | Post-review tracking field. EMIT AS EMPTY STRING during generation. Reviewers fill this in after the threat model is reviewed (e.g., `Active`, `False Positive`, `Risk Accepted`, `Mitigated by Compensating Control`, `Duplicate of 09`). |
| DispositionRationale | Post-review tracking field. EMIT AS EMPTY STRING during generation. Reviewers fill this in with the reason for the disposition above. |

(Count check: the schema lists 21 columns. ThreatID, Confidence, Priority, Category, OWASP, Component, TrustBoundary, Title, ThreatAgent, Asset, Attack, AttackSurface, Impact, Description, Evidence, Likelihood, SecurityControl, ResidualRisk, Mitigation, Disposition, DispositionRationale = 21 columns total. The Disposition pair is the post-review block and stays empty during generation, so the agent is populating 19 columns of content during enumeration.)

Sort the table by Priority (Priority 1 first), then by Confidence (Confirmed before Likely), then by OWASP Top 10 item, then by ThreatID.

#### Phase 2B Output: `.\{PROJECT_NAME}-threat-model\02b-threats.md`

Structure:

```markdown
# Phase 2B -- STRIDE Threat Tables

## Threat Filtering Notes
- Matrix cells evaluated ((components + boundary-crossing flows) x 6 STRIDE categories): <N>
- Data-flow obligation check: DFs in 02a-context.md with Encryption or AuthN = none/plaintext/unknown: <N>; every one accounted for as a threat or an Excluded Threats Ledger row: <yes | list of unaccounted DF-NNN -- an unaccounted flow is a rule violation>
- Component coverage: every C-NNN from the inventory MUST appear at least once in the Threat Table or the Excluded Threats Ledger. Components appearing in neither, each with a one-line justification: <list, or 'none'>
- Total candidate threats identified during STRIDE matrix walk: <N>
- Confirmed threats (main table): <N>
- Likely threats (main table): <N>
- Threats excluded as Medium severity: <N>
- Threats excluded as Low likelihood: <N>
- Threats excluded as fully mitigated (code/IaC-verified controls only): <N>
- Candidates routed as Attested-mitigated (unverified) (suppressed only by an attested control; verification lead for the code audit): <N>
- Threats excluded as out of scope: <N>
- Threats excluded as Code-level (routed to code audit): <N>
- Candidates recorded as Unverified (plausible but not grounded in the System Map; routed to code audit): <N>

## Threat Table (Confirmed and Likely)
| ThreatID | Confidence | Priority | Category | OWASP | Component | TrustBoundary | Title | ThreatAgent | Asset | Attack | AttackSurface | Impact | Description | Evidence | Likelihood | SecurityControl | ResidualRisk | Mitigation | Disposition | DispositionRationale |
|----------|------------|----------|----------|-------|-----------|---------------|-------|-------------|-------|--------|---------------|--------|-------------|----------|------------|-----------------|--------------|------------|-------------|----------------------|
| 01 | Confirmed | Priority 1 | Spoofing | A07:2021 | C-003 (Auth Service) | TB-002 | Session token replay due to absent token binding | External Attacker | AS-002 (Auth tokens) | Captured session cookie replayed against API (MITRE T1550.004) | External Interfaces | Confidentiality, Integrity | After intercepting a session cookie via XSS or network capture, attacker replays it against the API to impersonate the user. Edge terminates TLS, no token binding present, no anomaly detection. | AS-002 (auth tokens) reachable via DF-003 crossing TB-002; no token binding or anomaly detection on the session path [evidence: src/auth/session.go:120-158 issues bearer cookie with no binding; no device-binding config in src/auth/] | High | Partial -- TLS 1.3 on edge, no token binding | Elevated | Implement RFC 8473 token binding (SC-8); reduce session lifetime to 30 min (AC-12); add anomalous-IP detection (SI-4). | | |

```

MANDATORY -- exactly this one table, nothing else: `02b-threats.md` contains the Threat Filtering Notes and the Threat Table, in that order, and no other section. (The excluded-candidate working list is NOT part of 02b-threats.md -- it is written to the separate `02b-excluded.md` file described above; keeping it out of 02b-threats.md is what preserves the "one table only" rule while still persisting the ledger source for Phase 2C.) There is no Inferred Threats table -- it has been removed; candidates that could not be grounded in the System Map are recorded in the Excluded Threats Ledger (reason `Unverified`) during Phase 2C, not here. Do NOT add a "Threat Narratives," "Threat Details," or similar prose section with one block per threat -- every piece of detail (Title, ThreatAgent, Attack, Impact, Description, Evidence, Mitigation, etc.) belongs in its own column of the Threat Table row, per the schema above, not in a separate narrative. If the table feels too wide or dense, that is not a valid reason to restructure the file -- use terse cell content instead, but keep every threat as a single table row.

Write the file with the Write tool. Return your completion banner to the orchestrator (it owns STATE.md).

#### Phase 2B Stakeholder Explainer: `.\{PROJECT_NAME}-threat-model\outputs\architecture-threat-explanation.html`

For each threat in the table above, explain why it is an architecture-level finding and not a code-level finding, so the user can use this to answer stakeholders (developers, management, fellow security professionals) who push back on a finding. Use your own judgment on explanation and structure per threat; a card per threat with a short Architecture Issue / Why Not Just Code / Explain to Developers framing is a reasonable default, but prioritize a clear, accurate explanation over rigid adherence to that shape.

Write as a single self-contained HTML file (inline `<style>`, no external CSS/JS), ASCII-only per Operating Rule 14. Plain and simple -- this is a leave-behind for conversations, not the main report. It carries the AI-generation disclosure banner as the first child of `<body>` per Operating Rule 16 (it is a stakeholder deliverable).

Write with the Write tool. Verify per common.md rule W-d.

**Phase 2B Completion Banner:**
```
=== PHASE 2B COMPLETE: 02b-threats.md WRITTEN ===
Main table: <N>  (Confirmed: <N>  |  Likely: <N>)   Priority 1: <N>  |  Priority 2: <N>
Unverified candidates routed to ledger: <N>
STRIDE coverage: S=<N> T=<N> R=<N> I=<N> D=<N> E=<N>
Excluded working list: 02b-excluded.md written (<N> rows = not-promoted count, source for the 2C ledger)
Stakeholder explainer: outputs/architecture-threat-explanation.html written
Phase status reported to orchestrator (it owns STATE.md).
Return this banner verbatim as the end of your completion summary.
```
