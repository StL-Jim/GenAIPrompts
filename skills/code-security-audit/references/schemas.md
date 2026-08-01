<!-- BEGIN VERBATIM CARVE src=code-security-audit.md lines=1031-1220 sha256=bd371de2a76de49463dcf42c8df1e1253c1f4dae877dff573dec048ed84c79f2 -->
FINDING SCHEMA (COMPACT)
Use this compact schema for findings_registry.md and worker findings:

FIELD DEFINITIONS:
- id: Unique finding identifier (format: F-NNN, e.g., F-001)
- pid: Partition/service identifier (e.g., auth-service, payment-api)
- src: Source file path(s) with line numbers (e.g., src/auth/login.py:45-52)
- class: Classification (Confirmed | Suspected | Not Assessable)
- sev: Severity (Critical | High | Medium | Low | Info). The audit only ever produces Critical or High findings -- see SEVERITY SCOPE in GLOBAL RULES. Medium/Low/Info are listed here only because the field shares its enum with other contexts (e.g., a future manual status update); workers must never assign them.
- conf: Confidence (High | Medium | Low)
- score: Risk score (0-100, calculated per RISK SCORING section)
- cat: OWASP category (e.g., A01:2021, A03:2021), or `ARCH` for architecture findings from Phase 4A/4B that have no meaningful OWASP mapping (coupling, resilience, operational fragility). Do not force-fit an OWASP category onto a non-security architecture finding.
- sub: Subcategory (e.g., IDOR, SQL Injection, Missing Authentication; for ARCH findings e.g., Tight Coupling, Missing Bulkhead, Single Point of Failure)
- title: Short descriptive title (<=80 chars)
- scope: Impact scope (local | service-wide | cross-service | global)
- deps: Dependency classification (local | shared | boundary-crossing)
- ev: Evidence (file:line references, command outputs, tool results). For class=Confirmed findings, ev MUST include at least one exact line quoted from the cited source -- a citation without a quoted line is not verification.
- issue: Technical description of the vulnerability or architectural issue
- impact: Business/security impact analysis (data exposure, availability, compliance)
- fix: Remediation guidance (specific, actionable steps)
- verify: Verification steps (how to confirm the fix works)
- status: Status (open | mitigated | accepted | false_positive)
- rel: Related finding IDs (comma-separated, e.g., F-002,F-005)
- sup: Suppression rationale (required if status = accepted or false_positive)
- threat_id: COORDINATED mode only. The threat model threat ID this finding corresponds to (e.g., `07`), or `null` if no matching threat. Populated by cross-reference in Phase 3A when coordination_mode.md is COORDINATED. Leave null in STANDALONE mode.
- threat_match: COORDINATED mode only. One of: `confirms` (audit found code-level evidence of a threat the model anticipated), `partial` (audit found code addressing part but not all of a threat), `contradicts-exclusion` (audit found a defect the threat model's Excluded Threats Ledger judged fully mitigated -- or, for an `Attested-mitigated (unverified)` row, found the user-attested control absent or ineffective, disproving the attestation), `excluded-by-design` (finding matches a ledger row excluded for severity/likelihood/scope reasons -- real but deliberately out of the model's scope), `confirms-seeded` (finding verifies a ledger row the threat model routed to this audit as a lead -- reason `Code-level` or `Unverified`; verifying an `Unverified` row is the audit completing verification the model could not, what older versions called promoting an Inferred threat), `unanticipated` (audit finding has no matching threat anywhere in the model -- the value-add gap finding). Set to `null` in STANDALONE mode.

Field constraints:
- class = Confirmed | Suspected | Not Assessable
- sev = Critical | High | Medium | Low | Info
- conf = High | Medium | Low
- score = 0-100
- deps = local | shared | boundary-crossing

EXAMPLE FINDING:
```yaml
id: F-001
pid: auth-service
src: src/auth/user_controller.py:45-52
class: Confirmed
sev: High
conf: High
score: 85
cat: A01:2021
sub: Broken Access Control - IDOR
title: User ID enumeration via GET /api/users/:id without authorization
scope: service-wide
deps: local
ev: |
  File: src/auth/user_controller.py:45
  Function: get_user_by_id()
  No ownership check before returning user data
  Verified with: Select-String -Path 'src\*' -Pattern 'get_user_by_id' -Recurse
issue: |
  Endpoint returns any user's data without verifying the request caller
  owns the resource. Any authenticated user can access other users' PII
  by iterating user IDs.
impact: |
  - Unauthorized access to PII for all 100K users
  - Potential GDPR Article 32 violation (data breach notification)
  - Blast radius: entire user base
fix: |
  1. Add authorization check in get_user_by_id():
     if session.user_id != requested_user_id and not session.has_role('admin'):
         raise Forbidden()
  2. Implement attribute-based access control (ABAC)
  3. Add audit logging for all user data access
verify: |
  1. Add test: test_get_user_unauthorized_access()
  2. Attempt cross-user access with valid non-admin session
  3. Verify 403 Forbidden returned
  4. Confirm audit log entry created
status: open
rel: F-012
sup: null
threat_id: "07"
threat_match: confirms
```

Notes on the new threat-coordination fields:
- In STANDALONE mode, set both fields to `null`. They exist in the schema for consistency across modes but carry no information.
- In COORDINATED mode, populate them by cross-referencing the audit finding against the threats in `{PROJECT_NAME}-threat-model/02-threats.md` (see Phase 3A for the cross-reference procedure).
- `unanticipated` findings -- ones with no matching threat in the model -- and `contradicts-exclusion` findings -- ones disproving a "fully mitigated" judgment or a user attestation (`Attested-mitigated` rows) -- are the highest-value output of the coordinated toolchain. They reveal what the threat model didn't see or got wrong. Flag them clearly; they get prominence in the Phase 5 comparison report. `confirms-seeded` findings against `Unverified` ledger rows are the next most valuable: they complete verification the threat model could not finish (the former promote-an-Inferred-threat outcome).

---

ATTACK PATH SCHEMA
attack_paths.md (global and per-worker) uses this compact schema. It is read and written across five phases and feeds the "Top Attack Paths" sections of two deliverables, so its format must be as stable as the finding schema.

FIELD DEFINITIONS:
- id: AP-NNN, assigned in discovery order, stable within a run
- title: Short descriptive name (<=80 chars), e.g., "Anonymous user to full PII exfiltration via IDOR chain"
- entry: The entry point (component/endpoint and the trust boundary crossed, e.g., "public /api/users/:id, internet -> app tier")
- steps: Ordered list. Each step is one line: action, the finding ID(s) it exploits (F-...), and what the attacker holds afterward
- terminal_impact: What the attacker ends up with (data classes, privileges, persistence)
- findings: Comma-separated list of every finding ID referenced in steps
- partitions: Partition IDs the path traverses (single-partition paths are allowed but cross-partition paths rank higher)
- composite_score: The maximum risk score among the path's findings, +10 if the path crosses partitions or trust boundaries (cap 100). Phase 5 selects "Top Attack Paths" by composite_score descending.

Every step MUST reference at least one finding in findings_registry.md; do not include speculative steps with no evidence-backed finding behind them.

C4 INPUT SCHEMA
c4_input.md accumulates the structural facts the Phase 5 C4 generation needs. Three sections, each a simple table:
- Systems/Containers: id, name, type (service | db | queue | cache | external | frontend), partition, evidence
- Relationships: source id, target id, protocol, auth, crosses-trust-boundary (yes/no), evidence
- Trust Boundaries: id, description, what establishes it, evidence
In COORDINATED mode, reuse the threat model inventory's IDs (C-NNN, DS-NNN, EXT-NNN, TB-NNN) verbatim rather than inventing a parallel ID scheme.

---

CODE FIXES
Provide code_fix only if:
- the issue is Confirmed
- confidence is High
- remediation is localized and evidence-backed

---

RISK SCORING
FORMULA:
risk_score = (severity x confidence x blast_radius x exploitability) / 10

Normalize to 0-100.

SCALE DEFINITIONS:

SEVERITY MAPPING:
- Critical = 10 (complete system compromise, data breach, RCE)
- High = 7 (significant data exposure, privilege escalation, auth bypass)
- Medium = 4 (limited data exposure, minor business impact)
- Low = 2 (informational, minimal business impact)
- Info = 1 (best practice, hardening recommendation)

CONFIDENCE MAPPING:
- High = 1.0 (verified with evidence, reproducible)
- Medium = 0.7 (strong indicators, not fully verified)
- Low = 0.4 (theoretical, requires specific conditions)

BLAST RADIUS:
- Global (affects all services/users) = 10
- Cross-service (affects multiple services) = 7
- Service-wide (affects single service, all users) = 5
- Partition/module (affects subset of users) = 3
- Local (single component, minimal impact) = 1

EXPLOITABILITY:

The Exploitability score must be adjusted based on the deployment exposure recorded in `audit_state/coordination_mode.md`. The same code defect has different exploitability depending on whether the application is internet-facing or internal-only. Apply the deployment exposure as a modifier to the base exploitability rating.

Base ratings (assuming internet-facing exposure):
- Trivial (no auth, public endpoint, automated exploit available) = 10
- Easy (auth required, but straightforward exploit) = 7
- Moderate (requires specific conditions or insider access) = 4
- Difficult (requires multiple preconditions, deep system knowledge) = 2

There is no band below Difficult. A defect with no reachable exploit path does not get a low exploitability score -- it does not get a finding. It goes to `excluded_candidates.md` per the PRECONDITION TEST in Phase 3A. Scoring unexploitability as a 1 and multiplying it through is what let findings survive that no attacker could ever start: severity, confidence and blast radius stayed high, the product stayed above nothing in particular, and the finding shipped.

Deployment exposure modifiers (multiply base rating):
- Internet-facing: x 1.0 (base ratings apply directly)
- Hybrid: x 0.8 (mixed exposure reduces some attack paths)
- Internal: x 0.6 (attacker must first be on the corporate network or compromise a credentialed user)
- Unknown: x 1.0 (assume worst case until confirmed)

Example: A `Trivial` exploit (unauthenticated public-facing SQL injection) is 10 in an internet-facing application. The same code pattern in an internal-only application is 10 x 0.6 = 6, because exploitation requires the attacker to already be inside the corporate network.

The internal-network modifier is NOT a license to deprioritize defects. Insider threats, compromised workstations, and lateral movement after initial access are all realistic attack paths in internal environments. The modifier reflects relative likelihood, not absolute safety.

It is equally not a license to assume any position an attacker might theoretically occupy. An insider, or a workstation already compromised, is a realistic starting point on an internal network. Sitting on the wire between two internal hosts, controlling the organization's DNS or its certificate authority, or having already taken over its build system are not -- not unless something in this repository shows that position is reachable. Where the position IS the whole exploit and the position is not available, there is no finding; see the PRECONDITION TEST in Phase 3A.

EXAMPLE CALCULATION:
Finding: SQL injection in public-facing user search endpoint
- severity = Critical (10) [RCE + data breach potential]
- confidence = High (1.0) [verified with sqlmap]
- blast_radius = Global (10) [affects all users, all data]
- exploitability = Trivial (10) [public endpoint, no auth required]
- score = (10 x 1.0 x 10 x 10) / 10 = 100

Finding: IDOR on internal admin API (internal-only deployment)
- severity = High (7) [cross-user data exposure]
- confidence = High (1.0) [verified in code, no ownership check present]
- blast_radius = Service-wide (5) [all users of the service]
- exploitability = Easy (7) x Internal modifier (0.6) = 4.2
- score = (7 x 1.0 x 5 x 4.2) / 10 = 14.7 -> 15

Note: the first example scores at the ceiling; most real Critical/High findings land between 15 and 70. No Medium/Low example is shown because, per SEVERITY SCOPE, the audit never writes up Medium/Low/Info findings.

Use explicit reasoning in findings; do not hand-wave the score.

---
<!-- END VERBATIM CARVE -->