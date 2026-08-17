<!-- SKILL VERSION: v25-skill (2026-07-21a) -- methodology carved verbatim from PROMPT VERSION v24 (2026-07-16a) -->

### Phase 2B -- STRIDE Threat Enumeration

#### Phase 2B Rehydration (MANDATORY FIRST STEP)

Read STATE.md, 00-scope.md, 01-inventory.md, and 02a-context.md. You will reason about threats against the components in the inventory and the data flows in 02a-context.md, with particular attention to flows that cross trust boundaries. 00-scope.md is required here, not optional: the threat inclusion criteria and the ThreatAgent column both key off the deployment exposure it records, the Mitigation column keys off its governance framework, the SecurityControl column keys off the existing controls the user listed, and its out-of-scope list bounds any code verification reads.

Read these files with the Read tool (disk content overrides memory): STATE.md, 00-scope.md, 01-inventory.md, 02a-context.md.

STATE.md is orchestrator-owned. Do not read-modify-write it. Re-read source code only when verifying a specific control is absent or a flaw is present -- read targeted line ranges, not whole files. A candidate you cannot ground in the System Map does not require code verification -- it becomes an Unverified ledger row (Phase 2C), not a threat.

#### Threat Prioritization (apply during enumeration)

Include ONLY threats meeting all six criteria: CRITICAL or HIGH risk severity calculation outcome (exclude Medium/Low); Medium or High likelihood (exclude Low/Very Low); EXPLOITABLE per the already-compromised test below (the attacker gains something the prerequisite did not already give them); realistic based on known attack patterns rather than theoretical exploits; actionable through reasonable controls; and design-level per the test below.

Design-level test. A threat must be expressible as actor -> path -> asset -> missing or weak control at component, data-flow, or trust-boundary granularity. Litmus: would this finding survive a correct re-implementation of the same design? Design decisions are IN scope -- session lifetime, where the authorization check sits, the identifier scheme, what gets logged, whether a flow is encrypted -- none of them architecture, all of them surviving a rebuild of the same design, and none of them visible to SAST. If rewriting one function without changing any decision eliminates it (an injection in one function, missing sanitization at one handler, a hardcoded secret), it is a code-audit finding, not a threat-model finding -- record it in the Excluded Threats Ledger with reason `Code-level` and move on; the partner code audit consumes that ledger. A present flaw may still anchor a threat when it evidences a systemic gap (e.g., no central parameterization standard on the app-to-data-tier flow): state the threat at the design level and cite the flaw as supporting evidence.

EXPLOITABILITY TEST -- the already-compromised check. If achieving the prerequisite gives an attacker equal or greater access than the threat's impact, THE THREAT IS NOT EXPLOITABLE: there is nothing to exploit, because the attacker already has what the attack would give them. Exclude it (Excluded Threats Ledger, reason `Not exploitable -- dominated by prerequisite`).

The comparison is about what the attacker GAINS -- scope, reach, or persistence -- not about how alarming the outcome sounds. State that gain in the Description as `[Gains: ...]`; a threat whose gain you cannot name is one that does not exist, because the attacker's position is unchanged by it. Worked examples, all with a high starting privilege and not all excluded:
- L4 cluster admin sniffs pod traffic to capture a database password -> NOT EXPLOITABLE. L4 reads that secret directly; the attack changes nothing.
- L3 pod shell reads that same pod's environment variables for its secrets -> NOT EXPLOITABLE. The prerequisite already grants them.
- L3 pod shell recovers a cloud credential granting account-wide administration -> EXPLOITABLE. It crosses from one workload to the entire account; that is a real escalation.
- L1 ordinary user manipulates an identifier to read another user's record -> EXPLOITABLE. An ordinary user is not meant to reach another user's data.
- L2 application administrator exports all data, where that role legitimately holds all-data read -> NOT EXPLOITABLE. That is the design working, not a threat. The same action where the role is scoped to one tenant IS exploitable.

THERE IS NO TARGET COUNT. Emit exactly what survives the tests in this phase -- if that is five threats, emit five. Do not state or work toward a number: a count named in a prompt becomes a quota the table gets filled to, and the filler is always defence-in-depth dressed as a threat, which is what costs a threat model its credibility with the engineers who have to act on it.

Use the count as a SIGNAL ABOUT YOUR FILTERING, not as a limit. If you are holding more than about fifteen threats, treat that as evidence the filters were applied too loosely and go back through the exploitability test and the likelihood cap below -- the excess is almost certainly hardening that passed on a technicality. Raise the bar until the list is what genuinely survives; never truncate a genuine list to reach a number. Nothing is lost by a tight table: everything that does not survive goes to the Excluded Threats Ledger in Phase 2C, where the partner code audit consumes it as a lead.

Scales used in the risk severity calculation (defined here once; no other values are valid):
- Likelihood scale: Very Low, Low, Medium, High
- Impact scale: Low, Medium, High, Critical

Likelihood anchors -- score against the ThreatAgent named in the row, and do NOT inflate a likelihood to get a threat past the inclusion gate (a threat that misses the gate belongs in the Excluded Threats Ledger):
- High: the agent can attempt the attack from its starting position with no prerequisite compromise, using a widely known technique (e.g., an unauthenticated internet-reachable path for an External Attacker).
- Medium: requires one prerequisite the agent plausibly achieves (valid low-privilege credentials, internal network position, one phished user).
- Low / Very Low: requires chained prerequisites, insider collusion, or nation-state resources. Excluded by the gate.

PREREQUISITE PRIVILEGE LEVEL, and the cap it imposes. Every threat has a required STARTING privilege -- what the attacker must already hold before the attack begins. Classify it, and record it on the ThreatAgent cell as a suffix (see the schema):
- L0 unauthenticated / internet-reachable
- L1 authenticated ordinary user
- L2 privileged application user or application administrator
- L3 infrastructure access (a shell in a pod, a database client, a host account)
- L4 infrastructure administrator (cluster admin, cloud account admin)

A threat whose prerequisite is L3 or L4 is capped at Low likelihood -- and therefore excluded by the gate -- UNLESS the row demonstrates one of two things:
1. ESCALATION PATH: how an L0/L1/L2 attacker actually reaches L3/L4. Answers "how does anyone get there at all?"
2. ESCALATION GAIN: the impact reaches materially beyond what the prerequisite already grants. Answers "why does it matter that they did?"

Escape 2 is a BOUNDARY TEST, not a severity judgement: it applies only when the gain crosses a boundary the prerequisite does not already cross -- a different system, a different tenant, a materially wider blast radius, or durable persistence beyond the session. "The impact is severe" does not qualify; reach does. Without that discipline the escape readmits every infrastructure-admin threat and the cap means nothing.

RECORD WHICH ESCAPE APPLIED. A row whose ThreatAgent level is L3 or L4 carries a third bracketed note in its Description: `[Cap escape: path -- <one clause>]` or `[Cap escape: gain -- <one clause>]`, naming which of the two escapes above lifted the cap and stating it in one clause. An L3/L4 row with no such note has not demonstrated an escape, so the cap stands and the candidate goes to the ledger as `Low likelihood` rather than into the table. This is the discipline `[Gains: ...]` already applies to the exploitability test: an analysis that must be written down at the moment of writing the row is performed, while one described two screens up is recited. It also makes the cap auditable -- a reviewer at the threat review gate can see which escape was claimed instead of inferring that one was.

Assuming an attacker already holds L3/L4 and then enumerating what they could do from there is the single largest source of unrealistic threats. Cluster admin can read any secret, reach any pod and query any database by design; describing those capabilities is describing the platform, not finding a threat in this application.

Impact anchors:
- Critical: bulk exposure of the highest-classification data the system handles, cross-tenant boundary crossing, or code execution / full control in production.
- High: compromise scoped to a single user, session, or component; partial data exposure; sustained outage of a critical service.
- Medium / Low: degraded service, or exposure of internal metadata or non-sensitive data.

IMPACT IS READ OFF THE STATED GAIN, not chosen alongside it. The `[Gains: ...]` note in the row already says what the attacker ends up holding; the Impact severity must be the anchor that gain actually matches. Critical requires the Gains to name bulk data, a tenant or system boundary crossed, or execution / full control -- a Gains scoped to one user, one session, or one component is High, however serious it sounds in prose. Impact answers to TWO axes, and Critical requires both: the gain must be broad in scope, AND the asset it targets must be tiered `Primary` or `Sensitive` in 02a-context.md. This is what finally makes the Critical anchor's phrase "the highest-classification data the system handles" a lookup instead of an estimate -- it means an asset carrying the classification the USER named in Phase 0 Q4, not whichever asset sounds most alarming while you are writing the row. A threat against a `Supporting` asset caps at High no matter how broad the gain: bulk exposure of internal metadata is a wide reach onto something the organisation does not lose sleep over. A row whose Impact outranks its own stated Gains is severity inflation: a rule violation to correct, not a judgement call to defend. The check costs nothing to apply and nothing to audit, because both values sit in the same row -- a reviewer in the stakeholder session can catch a wrong rating without leaving the table, which is the whole reason the rating is stated next to the evidence for it.

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
6. Does the implementation effort really buy that much more security? Weigh the DEFENDER's cost against the risk actually removed -- a control costing weeks that only inconveniences an attacker who already holds infrastructure access is hardening, not a fix. (Question 4 asks the same of the attacker's effort; this asks it of yours.)
7. Do existing controls reduce this to acceptable residual risk? (If yes, exclude -- but ONLY when the control is verified in code or IaC. If the only evidence for the control is a Phase 0 attestation, the candidate is NOT excludable as mitigated: route it to the Excluded Threats Ledger as `Attested-mitigated (unverified)` per Operating Rule 2's attestation asymmetry.)

Categories to NOT include: theoretical attacks with no known exploits; threats already fully mitigated by existing code/IaC-verified controls (attested-only mitigation routes to the ledger as `Attested-mitigated (unverified)` instead); generic vulnerabilities common to all systems (e.g., "DDoS is possible"); out-of-scope threats (physical security, end-user device security).

Prioritize for government/financial systems: authentication bypass and credential theft; authorization failures and privilege escalation; PII/sensitive data exfiltration; supply chain attacks (compromised dependencies); secrets exposure (keys, passwords in logs/code); availability attacks on critical services.

De-prioritize unless specific evidence justifies inclusion: APT requiring nation-state resources; zero-day exploits in third-party managed services (AWS, Login.gov); social engineering of end users; physical attacks on data centers.

#### Phase 2B Work

Walk the STRIDE-per-element matrix as required by Operating Rule 4: for every component (and every boundary-crossing data flow), for every one of the six STRIDE categories, ask "does this apply?" Apply the prioritization rules above, including the design-level test and the already-compromised exploitability test. There is no count to reach.

SAY WHERE YOU ARE AS YOU GO. After each component's six-category pass, emit exactly one line and nothing else:

    [2B] Component <n> of <N> (<C-NNN>) -- <p> promoted, <x> excluded

No commentary around it, no summary of what you found. This is the longest phase in the run and it is otherwise silent for its entire duration: without this line the user cannot distinguish a phase that is working from one that is stuck, and the only remedy available to them is to kill it and lose the walk. The line also gives them a rate, which is what tells them whether waiting is worth it.

Data-flow obligation: the System Map compels findings, not just context. Every data flow in 02a-context.md whose Encryption or AuthN column records none, plaintext, or unknown MUST end the phase accounted for -- either cited by a threat in the main table or recorded as an Excluded Threats Ledger row stating why it does not rise to one (fully mitigated by a code/IaC-EVIDENCED control; `Attested-mitigated (unverified)` when the only mitigation evidence is a Phase 0 attestation -- the flow is still accounted for, but the mitigation claim stays visible as a verification lead; out of scope; or Unverified with its confirming question). There is no silent third option: an observed unprotected flow that appears in no output is a rule violation, reported in the Filtering Notes check below.

While walking the matrix, record every candidate threat that was considered but EXCLUDED (by the severity floor, likelihood floor, full code/IaC-verified mitigation, attested-only mitigation, scope rules, or the design-level test). For each excluded candidate record one line: component ID, STRIDE category, a short title, and the exclusion reason. WRITE THESE AS YOU GO, NOT AT THE END. Create `{PROJECT_NAME}-threat-model/02b-excluded.md` with the Write tool before you walk the first component, then APPEND that component's excluded lines with the Edit tool as each component's six-category pass finishes -- the same append-as-you-go pattern Phase 2C uses for the ledger itself, and for the same reason. A single write at the end of the phase loses the ENTIRE matrix walk if the phase never reaches the end: a run that stops at component 18 of 22 should cost you four components, not twenty-two. One line per excluded candidate in the form `component ID | STRIDE category | short title | exclusion reason` (exclusion reason beginning with one of the reason keywords the Phase 2C ledger uses: Fully mitigated, Attested-mitigated (unverified), Medium severity, Low likelihood, Not exploitable, Out of scope, Generic-to-all-systems, Code-level, Unverified -- plus `Rejected at review`, which only the threat review gate adds, never you). This file MUST persist on disk because Phase 2C runs as a SEPARATE session and builds the Excluded Threats Ledger by carrying these rows forward VERBATIM -- it is not in your context then, so a candidate you exclude but do not write here is lost, and 2C would be forced to reconstruct (guess) the ledger from rolled-up counts. Its line count MUST equal the sum of the not-promoted counts in your Filtering Notes. This ledger is how a downstream code audit distinguishes "the threat model considered this and excluded it" from "the threat model never considered it." Do not expand these into full threat rows.

For each selected threat, verify its architectural conditions against the system model and assign a confidence level (Confirmed or Likely) per the Confidence Levels section above. Confirmed and Likely threats are filled into the main threat table. A candidate that cannot reach Likely -- asset or path not confirmable from the System Map -- is recorded as an `Unverified` row in the Excluded Threats Ledger (Phase 2C), not emitted as a threat.

WRITE THE TABLE, THEN AUDIT IT. For each threat that survives, fill in every column of the main threat table schema below, then write `02b-threats.md`. The four audits that follow run AGAINST THE FILE YOU JUST WROTE, as Edit operations -- not against a draft you are holding in context. Two reasons, and they compound: a phase that runs out of room still leaves a usable table on disk instead of nothing, and the audits read from a file rather than from a context window that is by now nearly full. The speculation audit below states that second reason itself -- it exists because stated rules degrade as the window fills -- and it cannot be the remedy for that problem while it is also a victim of it.

Self-check: for each threat in the table you must be able to write the architecture-vs-code explanation required by the Stakeholder Explainer below. If the honest explanation reduces to a specific implementation defect, the threat fails the design-level test -- move it out of 02b-threats.md and append it to the excluded list (`Code-level`).

Citation audit (Confirmed threats only): re-open the cited line range of each Confirmed threat and verify the exact lines support the control-state claim. If the cited code does not actually show the flaw or the absence of the control, fix the citation or demote the threat to Likely. This is bounded work -- only Confirmed rows, only the already-cited ranges -- and it is what makes the Evidence column trustworthy rather than merely plausible-looking.

Speculation audit (every row): scan every threat's Description and Evidence cells for the anti-speculation tell-phrases from Operating Rule 2 ("assuming", "there may be", "if there exists", "presumably", "other users/roles/services likely") and for any precondition naming a principal, role, permission, or policy that no repo file and no Phase 0 attestation establishes. A failing row has exactly two exits: re-ground it (fix the Evidence cell to cite the repo file or user-attested fact that establishes the precondition) or remove it to the Excluded Threats Ledger as `Unverified` with its confirming question. No third option; a row may not stay in the table on the strength of plausibility. This audit is bounded, mechanical work -- a scan of cells already on disk -- and it exists because stated rules degrade as the context window fills; the audit at the end catches what the rule missed in the middle.

IAM / access-control hard gate (this is the failure mode that keeps recurring, so treat it mechanically, not as judgment): for ANY threat whose control-state claim concerns an IAM role, policy, permission, or a principal's access scope, the Evidence cell MUST cite the specific repo file that DEFINES that role or policy (its Terraform / IaC / manifest), or a Phase 0 Q6a attestation about it. An architectural citation alone (an `AS-`/`DF-`/`TB-` reference with no defining-file citation) does NOT ground an IAM-configuration claim -- the IAM config is neither the asset nor the flow, it is a specific file. If neither a defining-file citation nor an attestation is present -- the NORM in PLATFORM_INHERITED mode, where the IAM baseline lives outside this repo -- the threat is ungrounded: remove it, or record it `Unverified` in the ledger with its confirming question. Never carry an IAM threat into the main table on an architectural citation while the role or policy it names is defined in no file here.

After the four audits you MAY run `check-threats.ps1` on 02b-threats.md as a worklist (common.md rule S for your shell's form) -- it reports the mechanically decidable violations: risk-calc arithmetic against the Priority column, asset tiers against 02a-context.md, closed vocabularies, column count, and missing bracketed notes. Fix what it names before you return. The orchestrator runs it too, and that run is the one that counts.

#### Threat Table Schema (main table: Confirmed and Likely threats)

Only Confirmed and Likely threats go in this table -- and they are the only threats the model emits. Candidates that cannot be grounded in the System Map are routed to the Excluded Threats Ledger (Phase 2C, reason `Unverified`), not given a threat row here.

| Column | Description |
|--------|-------------|
| ThreatID | `01`, `02`, etc. Stable across re-runs. Two digits, zero-padded. |
| Confidence | One of: `Confirmed`, `Likely`. Reflects what was verified against the system model per the Confidence Levels section. Confirmed = asset, path, and control-state all verified. Likely = asset and path verified, control-state uncertain (the Description must state what would confirm it). |
| Priority | One of: Priority 1, Priority 2. Priority 1 = threats meeting the risk severity calculation's CRITICAL outcome; Priority 2 = threats meeting the HIGH outcome. (Medium and Low risk-calc outcomes are excluded entirely by the prioritization rules.) |
| Category | STRIDE category, exactly one: Spoofing, Tampering, Repudiation, Information Disclosure, Denial of Service, Elevation of Privilege. |
| OWASP | The OWASP Top 10 item this maps to (e.g., A01:2021), or `N/A`. |
| Component | The architectural component from the inventory. Use the exact same name as in 01-inventory.md and the Phase 4 diagrams. |
| TrustBoundary | The trust boundary this threat crosses or operates within, by TB-NNN ID. `N/A` if the threat is within a single trust zone. |
| Title | Specific, detailed name, stated at architectural granularity. Not "Broken Access Control" but "Tenant report-export path (DF-007) crosses TB-003 with no row-level authorization between the API tier and the reporting store." Never title a threat after a single function's defect. |
| ThreatAgent | The actor profile, followed by the REQUIRED STARTING PRIVILEGE in parentheses -- `External Attacker (L0)`, `Insider Attacker (L2)`, `Compromised Container (L3)`. The level is mandatory: it is what makes "this needs cluster admin" impossible to hide, and it drives the L3/L4 likelihood cap above. PREFER AN ACTOR THE INVENTORY RECORDS: Section 4a of 01-inventory.md lists this system's actor classes with their privilege levels, so a threat's prerequisite should name one of them rather than invent a level per row. A prerequisite level with no corresponding actor class is worth a second look -- either the actor list is incomplete, or the threat assumes a principal this system does not actually have. Profiles: External Attacker, Insider Attacker (a legitimate insider account acting under compromise or negligence -- phished credentials, malware on a workstation, careless misuse), Malicious Insider (a trusted person intentionally abusing their own legitimate access), Compromised Container, Rogue Developer, Supply Chain Attacker, Opportunistic Scanner, Competitor, or Nation State Actor. Choose per the deployment exposure recorded in 00-scope.md: Internet-facing favors External Attacker / Opportunistic Scanner / Competitor; Internal favors Insider Attacker / Malicious Insider / Compromised Container / Rogue Developer; Hybrid uses both profiles for respective components; all deployments always consider Supply Chain Attacker. |
| Asset | The specific asset targeted, by AS-NNN ID from 02a-context.md, followed by its criticality tier in parentheses -- `AS-004 (Primary)`, `AS-002 (Sensitive)`, `AS-011 (Supporting)`. Carry the tier across from 02a-context.md; it is not re-judged here, and re-rating an asset upward while writing a threat is severity inflation wearing a different hat. The tier is half of the Impact test above, so the row states both halves. |
| Attack | The specific attack technique. Reference MITRE ATT&CK techniques (e.g., `T1190 Exploit Public-Facing Application`) where applicable. |
| AttackSurface | Pick from: External Interfaces, Internal Network, Development & Deployment, Infrastructure & Orchestration, Configuration & Secrets, Observability & Operations, Supply Chain, Authentication & Identity, Data Storage, Client-Side. |
| Impact | Confidentiality, Integrity, and/or Availability. |
| Description | Why this threat matters for this component, how it would be exploited, and what the attacker gets. Combines what earlier versions called Why Applicable and Attack Path. Multi-sentence prose, but kept tight. For a Likely threat, state explicitly what would need to be checked to reach Confirmed. Every Description also carries two mandatory bracketed notes, which are what the exploitability test and the likelihood cap are read from: `[Prereq: <what the attacker must already hold, or 'none'>]` and `[Gains: <what they hold afterwards that they did not hold before>]`. A `[Gains: ...]` you cannot fill means the threat is not exploitable and does not belong in this table. A third note, `[Cap escape: path | gain -- <one clause>]`, is mandatory whenever the ThreatAgent level is L3 or L4, per the L3/L4 cap above; on an L0/L1/L2 row it is omitted entirely. Every Description ends with the risk-calculation note in brackets: `[Risk calc: <Likelihood> likelihood x <Impact severity> impact]`, e.g. `[Risk calc: High likelihood x Critical impact]` -- this records the Impact severity value that produced the Priority (it appears nowhere else; the Impact column records CIA categories, not the severity scale), so a reviewer can audit the Priority rating from the row itself. |
| Evidence | The ARCHITECTURAL claim that makes this threat real, with code/IaC citations in support. Lead with the architectural conditions -- the asset (AS-NNN), the path (DF-NNN and the TB-NNN it crosses), and the control-state (absent or partial) -- then cite the code or IaC that supports the control-state claim. Example: `AS-004 (customer PII) reachable via DF-007 crossing TB-003; no query-logging or DLP control on this path [evidence: infra/db/reporting_role.tf:12-30 grants broad SELECT; no audit config in infra/db/]`. The citation supports the architectural claim; it is not the claim by itself. Mandatory per Operating Rule 2; multiple citations separated by `;`. Never cite `audit_state/` or `{PROJECT_NAME}-threat-model/` paths (Operating Rule 13a). |
| Likelihood | One of: Medium, High. The likelihood of exploitation given the architecture and real-world risk. (Low likelihood threats are excluded by prioritization rules.) |
| SecurityControl | EXISTING controls already in place that affect this threat. Use `None` if no controls exist. Use `Partial -- <what's missing>` if controls are incomplete. A control whose only evidence is a Phase 0 attestation renders as `Attested -- <control> (unverified in code)` with its `[evidence: user-attested, Phase 0 Q3/Q6a]` citation -- it may inform ResidualRisk, but per Operating Rule 2 it never removes the threat from this table or justifies a fully-mitigated exclusion. |
| ResidualRisk | The residual risk remaining after existing SecurityControl is applied but before recommended Mitigation. One of: Severe, Elevated. Re-run the risk severity calculation crediting the existing SecurityControl as it actually operates, then map the outcome: CRITICAL -> Severe, HIGH -> Elevated. Because existing controls can lower the outcome, ResidualRisk may map lower than the Priority column, which reflects the calculation before existing controls are credited (the schema example row is Priority 1 with ResidualRisk Elevated for exactly this reason). The words Critical and High never appear as ratings in stakeholder-facing artifacts. |
| Mitigation | Specific, actionable controls to add or strengthen. Each recommended action ends with its governance-framework control identifier in parentheses, e.g. `Enforce row-level authorization on the export path (AC-3); add query audit logging (AU-2); enforce TLS on the internal hop (SC-8(1))`. The framework is GOVERNANCE_FRAMEWORK from Phase 0 Q5 (default NIST 800-53 Rev 5); always use its specific control identifiers, never just the framework name. A Mitigation cell containing no parenthesized control identifier is a rule violation, not an oversight -- the same standard the Evidence column carries. These parenthesized identifiers are machine-extractable and are what the Phase 2C Control Coverage Summary aggregates. Reference OWASP and CIS Benchmarks where they add specificity. |
| Disposition | Post-review tracking field. EMIT AS EMPTY STRING during generation. Reviewers fill this in after the threat model is reviewed (e.g., `Active`, `False Positive`, `Risk Accepted`, `Mitigated by Compensating Control`, `Duplicate of 09`). |
| DispositionRationale | Post-review tracking field. EMIT AS EMPTY STRING during generation. Reviewers fill this in with the reason for the disposition above. |

(21 columns. The Disposition pair is the post-review block and stays empty during generation, so 19 carry content during enumeration. `check-threats.ps1` counts them and reports any row that does not have 21.)

Sort the table by Priority (Priority 1 first), then by Confidence (Confirmed before Likely), then by OWASP Top 10 item, then by ThreatID.

#### Phase 2B Output: `.\{PROJECT_NAME}-threat-model\02b-threats.md`

Structure:

```markdown
# Phase 2B -- STRIDE Threat Tables

## Threat Filtering Notes
- Matrix cells evaluated ((components + boundary-crossing flows) x 6 STRIDE categories): <N>
- Data-flow obligation check: DFs in 02a-context.md with Encryption or AuthN = none/plaintext/unknown: <N>; every one accounted for as a threat or an Excluded Threats Ledger row: <yes | list of unaccounted DF-NNN -- an unaccounted flow is a rule violation>
- Component coverage: every C-NNN from the inventory MUST appear at least once in the Threat Table or the Excluded Threats Ledger. Components appearing in neither, each with a one-line justification: <list, or 'none'>
- Impact-to-Gains consistency: rows whose Impact severity outranks their own `[Gains: ...]` note: <count, or 'none' -- any nonzero count is severity inflation to correct before finishing, not to report and keep>
- Primary asset coverage: threats whose Asset is the `Primary` tier: <N>, against <M> Primary assets in 02a-context.md. If N is zero while M is not, say so plainly -- it is a legitimate outcome (the most sensitive assets may genuinely be well defended), but it is the single most important line in this file for a reader deciding whether the model looked where it mattered.
- Total candidate threats identified during STRIDE matrix walk: <N>
- Confirmed threats (main table): <N>
- Likely threats (main table): <N>
- Threats excluded as Medium severity: <N>
- Threats excluded as Low likelihood: <N>
- Threats rejected at the Phase 2B threat review gate: <N> (0 when 2B first writes this file; raised only if the user drops a threat at the gate, and whoever drops it recomputes the totals here)
- Threats excluded as fully mitigated (code/IaC-verified controls only): <N>
- Candidates routed as Attested-mitigated (unverified) (suppressed only by an attested control; verification lead for the code audit): <N>
- Threats excluded as out of scope: <N>
- Threats excluded as Code-level (routed to code audit): <N>
- Candidates recorded as Unverified (plausible but not grounded in the System Map; routed to code audit): <N>

## Threat Table (Confirmed and Likely)
| ThreatID | Confidence | Priority | Category | OWASP | Component | TrustBoundary | Title | ThreatAgent | Asset | Attack | AttackSurface | Impact | Description | Evidence | Likelihood | SecurityControl | ResidualRisk | Mitigation | Disposition | DispositionRationale |
|----------|------------|----------|----------|-------|-----------|---------------|-------|-------------|-------|--------|---------------|--------|-------------|----------|------------|-----------------|--------------|------------|-------------|----------------------|
| 01 | Confirmed | Priority 2 | Spoofing | A07:2021 | C-003 (Auth Service) | TB-002 | Session token replay due to absent token binding | External Attacker (L0) | AS-002 (Auth tokens, Sensitive) | Captured session cookie replayed against API (MITRE T1550.004) | External Interfaces | Confidentiality, Integrity | After intercepting a session cookie via XSS or network capture, attacker replays it against the API to impersonate the user. Edge terminates TLS, no token binding present, no anomaly detection. [Prereq: none -- an unauthenticated attacker who has captured one session cookie] [Gains: full impersonation of that one user's session, including every action that user can perform] [Risk calc: High likelihood x High impact] | AS-002 (auth tokens) reachable via DF-003 crossing TB-002; no token binding or anomaly detection on the session path [evidence: src/auth/session.go:120-158 issues bearer cookie with no binding; no device-binding config in src/auth/] | High | Partial -- TLS 1.3 on edge, no token binding | Elevated | Implement RFC 8473 token binding (SC-8); reduce session lifetime to 30 min (AC-12); add anomalous-IP detection (SI-4). | | |

```

MANDATORY -- exactly this one table, nothing else: `02b-threats.md` contains the Threat Filtering Notes and the Threat Table, in that order, and no other section. (The excluded-candidate working list is NOT part of 02b-threats.md -- it is written to the separate `02b-excluded.md` file described above; keeping it out of 02b-threats.md is what preserves the "one table only" rule while still persisting the ledger source for Phase 2C.) There is no Inferred Threats table -- it has been removed; candidates that could not be grounded in the System Map are recorded in the Excluded Threats Ledger (reason `Unverified`) during Phase 2C, not here. Do NOT add a "Threat Narratives," "Threat Details," or similar prose section with one block per threat -- every piece of detail (Title, ThreatAgent, Attack, Impact, Description, Evidence, Mitigation, etc.) belongs in its own column of the Threat Table row, per the schema above, not in a separate narrative. If the table feels too wide or dense, that is not a valid reason to restructure the file -- use terse cell content instead, but keep every threat as a single table row.

Write this file with the Write tool as soon as the table is filled in, BEFORE the four audits above -- they edit it in place. Return your completion banner to the orchestrator (it owns STATE.md).

EXCLUSION PROFILE (compute before returning your banner). Tally the excluded candidates BY REASON and report the profile in the banner below. Count them from `02b-excluded.md` -- Operating Rule 15, counted and never recalled -- list only reasons with a nonzero count, and check that they SUM to the total: a profile that does not sum means the working list did not capture every candidate, which is a defect to fix now rather than a rounding difference.

This profile exists so the user can see the SHAPE of the filtering at the moment he is deciding whether to accept it. A run where one reason accounts for most exclusions is telling him which test did the work -- and whether that was the right test to do the work is a judgement he can make and you cannot. He may well ask to see the candidates behind any one reason; have them ready and show them all.

**Phase 2B Completion Banner:**
```
=== PHASE 2B COMPLETE: 02b-threats.md WRITTEN ===
Main table: <N>  (Confirmed: <N>  |  Likely: <N>)   Priority 1: <N>  |  Priority 2: <N>
Unverified candidates routed to ledger: <N>
STRIDE coverage: S=<N> T=<N> R=<N> I=<N> D=<N> E=<N>
Excluded working list: 02b-excluded.md written (<N> rows = not-promoted count, source for the 2C ledger)
  By reason: <reason> <N> | <reason> <N> | <reason> <N> ...   (nonzero reasons only; sums to <N>)

Would you like to review each threat individually before proceeding?
Just say so in your own words. I will show them one at a time, COMPLETE -- every field,
exactly as it will appear in the report -- and stop after each one. Questioning a threat
is a conversation: ask why it is there, whether a control you already have covers it, or
what a developer will say about it, and I will go back to the evidence and answer.
Type 'proceed' to begin Phase 2C, which consolidates the threats into the canonical
02-threats.md and builds the Excluded Threats Ledger -- the last phase before the exports.
Phase status reported to orchestrator (it owns STATE.md).
Return this banner verbatim as the end of your completion summary.
```
