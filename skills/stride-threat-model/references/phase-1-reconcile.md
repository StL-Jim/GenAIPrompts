<!-- SKILL VERSION: v25-skill (2026-07-21a) -- methodology carved verbatim from PROMPT VERSION v24 (2026-07-16a) -->

Read common.md, phase-1-shared.md, STATE.md, 00-scope.md, 00-discovery.md, 00-file-manifest.txt, 01a-partial.md, 01b-partial.md, and 01c-partial.md.

## Reconciliation Procedure (in order)
1. Merge: union the Elements Found sections of the three partials, including
   documentation-artifact records. Dedupe by canonical name and evidence overlap;
   consult each partial's Notes for Reconciliation. A store found in IaC (1B) and
   referenced in code (1C) is ONE element with both citations. When partials disagree
   on component granularity (one partition split what another merged -- e.g. the docs
   partition recorded three components where the source partition recorded one),
   apply the Component granularity rule from phase-1-shared.md to settle it: collapse
   to one component when the modules share a deployable and entry-point, keeping
   every partition's evidence citations and dependencies on the merged element.
2. Apply the Section 2 component definition to the merged set: every data store,
   managed service, queue, cache, gateway, and identity provider is ALSO a component.
3. Assign IDs by the fixed-sort rule: sort each class alphabetically by canonical
   name, then number C-001..., DS-001..., EXT-001..., TB-001..., DOC-001...
4. Coverage: sum the three Partition File Accounting blocks; the three partition
   counts must sum to the manifest total (paste the partition-manifest.ps1
   reconciliation line, or recompute with (Get-Content ...).Count). Total Unaccounted
   must be 0 -- if any partial reported unfinished files, STOP and return the list.
5. Discovery Delta: union the three Comprehension Delta Candidates lists, dedupe,
   cross-check against 00-discovery.md, and record per the Coverage Report schema.
   Scope-relevant deltas are flagged in your summary for the user.
6. Write 01-inventory.md per the schema below. Section 1 (Documentation Artifacts) is
   built from the documentation-artifact records merged in step 1 -- assign DOC-NNN by
   the same fixed-sort rule as the other classes -- not re-derived from evidence
   citations scattered across other elements. The System Restatement section is
   written as: "PENDING USER CONFIRMATION: <your draft restatement paragraph>".
7. Return in your summary: the draft System Restatement (verbatim), component/data
   store/external integration/TB/assumption counts, the coverage reconciliation line,
   and scope-relevant deltas. The orchestrator relays the restatement to the user
   (GATE 2) and edits the final confirmed text into 01-inventory.md. If the user's
   GATE 2 correction affects other inventory sections (Components, Trust Boundaries,
   Data Stores, Data Flows -- e.g. a correction to the user population or the
   most-sensitive-asset can invalidate entries in those sections), the orchestrator
   must update the affected inventory sections in 01-inventory.md to match the
   confirmed restatement before Phase 2 begins.

### Phase 1 Output: `.\{PROJECT_NAME}-threat-model\01-inventory.md`

Structure:

```markdown
# Architectural Inventory

ID spaces are disjoint. `C-NNN` component, `DS-NNN` data store, `EXT-NNN` external integration, `TB-NNN` trust boundary, `A-NNN` ACTOR, `ASM-NNN` ASSUMPTION. Actors and assumptions never share a number space -- later phases resolve `A-NNN` to an actor and nothing else.

## System Restatement
<the user-confirmed one-paragraph restatement written at the end of Phase 1: what the system is, what it talks to, who its users are, and the kinds of sensitive data it holds -- do NOT press the user to nominate a single most-sensitive asset; asset criticality is looked up from the Phase 0 Q4 answer in Phase 2A, not attested here>

## 1. Documentation Artifacts
| ID | Path | Type | Key Assertions |
|----|------|------|----------------|
| DOC-001 | docs/architecture.md | design-doc | ... |

## 2. Components
This is the MASTER inventory of architectural elements, and it directly gates threat coverage: Phase 2B walks STRIDE per component, so any element absent here is never threat-modeled. DEFINITION -- every architectural element that PROCESSES, STORES, or MEDIATES this system's data is a component: it gets a C-NNN ID and a Phase 2 STRIDE walk. This explicitly includes data stores, cloud/AWS managed services (S3, DynamoDB, Bedrock, SQS, ...), queues, caches, gateways, and identity providers -- NOT only active-process services. Do NOT undercount by treating data stores or managed services as a lower tier: the Data Stores (Section 3) and External Integrations (Section 4) sections are supplementary attribute detail about elements that ALSO appear here as components, keyed to the same C-NNN -- every element listed in those sections MUST also appear in this section. Each architectural element appears here exactly once (one C-NNN) and is walked once in Phase 2. (This definition is load-bearing: undercounting components is the single largest cause of incomplete threat enumeration -- a narrow "active-process only" reading has produced 3-4 components where the correct reading produces ~12-13 on the same system.)

ATTESTED IN-PATH ELEMENTS ARE COMPONENTS -- FROM Q3 AS WELL AS Q6a. Read BOTH Phase 0 answers in 00-scope.md, because the element you are looking for is more likely to be in Q3 than in Q6a.

Q3 asks "list any mitigating controls already in place (WAF, API gateway, CDN, IDS/IPS, MFA, etc.)" -- WAF is its FIRST example and its sample answer is a WAF vendor. So a user naming their WAF answers Q3, correctly. If the component rule reads only Q6a, that WAF is filed as a CONTROL, never becomes an element, and can never be drawn: field-reported symptom, an Akamai WAF absent from every diagram because it was named in the mitigating-controls answer rather than the platform-path answer.

THE TEST IS WHETHER IT SITS IN THE DATA PATH, not which question named it:
- IN PATH -- traffic flows THROUGH it: WAF, CDN, API gateway, reverse proxy, load balancer, ingress controller, service mesh gateway. These MEDIATE this system's data, so they meet the component definition above and get a C-NNN.
- NOT IN PATH -- gates or observes without being a hop: MFA, IDS/IPS, SIEM, EDR, vulnerability scanners. These stay controls only and get no C-NNN.

BEING A COMPONENT DOES NOT MAKE IT A VERIFIED MITIGATION. These are three separate roles and collapsing them is the error to avoid. An attested WAF is simultaneously: an element on the map (drawn, its flows and boundaries visible); an attested control (renders in SecurityControl as `Attested -- <control> (unverified in code)`); and NOT a basis for a `Fully mitigated` exclusion, per Operating Rule 2's attestation asymmetry. Adding it to the inventory changes what the diagrams can show. It changes nothing about what threats may be suppressed.

When Phase 0 Q6a recorded a platform traffic path -- e.g. "Akamai WAF -> reverse proxy -> app container; TLS terminates at the proxy" -- every element NAMED in that path (the WAF, the ingress/reverse proxy, the load balancer) MEDIATES this system's data and therefore meets the component definition above. Each gets a C-NNN, with `Evidence: [evidence: user-attested, Phase 0 Q6a]`.

These elements are absent from the repository BY CONSTRUCTION -- they are platform, not application code -- so no amount of file reading in Phase 1 will ever discover them. Without this rule they never enter the inventory, never reach a diagram, and the path from the user to the application has a hole in the middle exactly where the security controls sit. Field symptom: a container diagram showing neither the WAF nor the ingress, so the attested plaintext hop between proxy and container -- a threat the model DID emit -- had no visible endpoints to connect.

Mark each one `- Attested: yes (platform-inherited; not code-verified)`. That marker is load-bearing downstream: under INFRA_OWNERSHIP = PLATFORM-INHERITED these components are on the MAP but are NOT threat-walk targets for their own internal configuration. They are drawn so the path and its trust boundaries are visible. The application's own side of every flow through them stays fully in scope, as does any exposure Q6a attests. Drawing an element and threatening it are different things, and conflating them is what produces a threat table full of platform findings.

Each component gets a stable ID: `C-<NNN>`. Assign IDs by a FIXED sort, not discovery order (Operating Rule 5): discover all components first, sort them alphabetically by canonical name, then number C-001, C-002, ... in that sorted order. Discovery order is not reproducible across runs; a fixed sort is. (Cross-run identity still relies on semantic matching, since names can change -- but a stable sort removes the gratuitous reshuffling that discovery order causes.)

### C-001: <Component Name>
- Type: (web-app | api-service | worker | database | cache | queue | managed-service | gateway | identity-provider | external-saas | cli | job | lambda | frontend-spa | ...)
- Language/Framework:
- Evidence: [evidence: path/to/main.go:1-40]
- Responsibilities:
- Entry points:
- Dependencies (other components): [C-002, C-005]
- Data handled: (PII | credentials | financial | health | telemetry | public | ...)
- Runs as: (user/service account, container, lambda, ...)

## 3. Data Stores
Supplementary attribute detail (classification, encryption, access pattern) for the Section 2 components that are data stores -- NOT a separate lower tier. Every data store here MUST also appear in Section 2 as a component with its own C-NNN and Phase 2 walk; the DS-NNN is its detail-record ID cross-referencing that component. DS-vs-EXT TEST (apply it -- do not bin by feel; misclassification is a field-observed failure). Ask ONE question: WHO OPERATES IT? If this system operates the store and its CONTENT belongs to this system, it is a DATA STORE -- even on managed infrastructure (an S3 bucket or DynamoDB table this app owns on AWS is DS). If ANOTHER PARTY operates it and this system is a CLIENT reaching across the network to it, it is an EXTERNAL INTEGRATION -- even if what you do with it is purely read data. THE FETCH TRAP (the exact field failure): a website or API this system SCRAPES or FETCHES FROM (sec.gov, a partner feed, any remote source ingested into a KB or cache) is an EXTERNAL INTEGRATION, never a data store, no matter how one-way or read-only it feels. "We just pull data from it" describes the DIRECTION of a data flow (outbound fetch), not the CATEGORY of the element -- direction is an EXT attribute, not a reason to call it a store. Binning a fetched-from source as a data store is a security error, not a labeling nit: it erases the ingestion CHANNEL from the threat walk, and that channel is where TLS-verification, source-spoofing, and content-poisoning threats live -- for a RAG/KB system, remote-content-into-the-knowledge-base is the marquee threat surface. The fetched data landing somewhere (the KB, a staging bucket) IS a data store -- a SEPARATE element this system owns; record BOTH the external source (EXT) and the landing store (DS), joined by a data flow. When a single element genuinely seems both (a partner-operated store this system writes into), classify as External Integration. Each data store gets a stable ID: `DS-<NNN>`, assigned by the same fixed-sort rule as components (discover all first, sort alphabetically by canonical name, then number) -- not discovery order.

### DS-001: <Data Store Name>
- Type: (postgresql | mysql | redis | dynamodb | s3 | elasticsearch | secrets-manager | filesystem | ...)
- Data classification: (PII | credentials | financial | health | telemetry | public | ...)
- Encryption at rest: (yes | no | unknown) -- cite IaC evidence
- Encryption in transit: (yes | no | unknown) -- cite evidence
- Access pattern: which components read/write, e.g. `read-write from C-003, read-only from C-005`
- Evidence: [evidence: terraform/rds.tf:1-30]

## 4. External Integrations
Supplementary detail (protocol, auth method, direction) for the Section 2 components that are external or managed integrations -- NOT a separate lower tier. Every integration here MUST also appear in Section 2 as a component with its own C-NNN and Phase 2 walk; the EXT-NNN is its detail-record ID cross-referencing that component. Apply the DS-vs-EXT test from Section 3 -- the operator question: another party operates it and this system is a client = EXT, even if this system only reads data from it; content this system owns = DS, even on managed infrastructure. A remote source this system SCRAPES or FETCHES FROM is an EXT (the fetch trap in Section 3) -- one-way read traffic is a data-flow direction, not a store; the place the fetched data lands is a separate DS. Each external integration gets a stable ID: `EXT-<NNN>`, assigned by the same fixed-sort rule (discover all first, sort alphabetically by canonical name, then number) -- not discovery order.

### EXT-001: <Integration Name>
- Protocol: (HTTPS | gRPC | AMQP | SMTP | TCP | ...)
- Authentication method: (API key | OAuth client credentials | mTLS | bearer token | basic auth | none | ...)
- Direction: (inbound | outbound | both)
- Data exchanged: (brief description and classification)
- Evidence: [evidence: src/clients/payment_gateway.go:12-44]

## 4a. Actors

Human and machine principals that reach this system's OWN entry points while it is RUNNING. A principal that only BUILDS, DEPLOYS, HOSTS or OPERATES the system -- CI/CD pipelines, deployment credentials, cluster RBAC, registry or secret-store permissions -- is not an actor however much power it holds: if it vanished, the system would stop being UPDATED, not stop SERVING. Actors are NOT components -- they do not process, store or mediate this system's data; they are the principals on the far side of its entry points -- so they take their own ID space and are not walked in Phase 2B.

They are recorded because three things downstream need them and currently have nowhere to look: the context diagram draws every actor class, every threat names a ThreatAgent, and Phase 2B's L0-L4 prerequisite privilege levels are a claim about WHICH actor is assumed. An actor list that exists only as prose in the System Restatement cannot serve any of them -- field symptom: context diagrams with no user on them at all, because the diagram spec said "every human actor class from the inventory" and the inventory had no such section.

Each actor gets a stable ID: `A-<NNN>`, assigned by the same fixed-sort rule (discover all first, sort alphabetically by canonical name, then number).

### A-001: <Actor Name>
- Type: (anonymous-public | authenticated-user | privileged-user | application-administrator | operator | service-account | partner-system | ...)
- Privilege level: (L0 unauthenticated | L1 authenticated ordinary user | L2 privileged/application administrator | L3 infrastructure access | L4 infrastructure administrator) -- the SAME scale Phase 2B's ThreatAgent suffix uses, so a threat's prerequisite can be traced to a real actor class rather than invented
- Reaches: which components it can talk to directly, by C-NNN
- Authenticates via: (session cookie | OIDC/SSO | API key | mTLS | none | ...)
- Evidence: [evidence: src/auth/roles.go:20-58]

Derive actors from what the code and docs actually show -- authentication roles and claim types, endpoints with differing authorization requirements, admin interfaces, service accounts that CALL this system's interfaces, and the Q6a platform profile for principals the platform interposes in the request path. An application with an admin UI and a public page has at least two actor classes; recording only "user" undercounts in exactly the way that recording only active services undercounts components. If the system is internet-facing, an `anonymous-public` L0 actor exists whether or not any code names it.

## 5. Trust Boundaries
`TB-<NNN>` IDs. A trust boundary exists wherever data crosses between principals with different trust levels. At minimum consider:
- Internet -> edge (WAF/LB/CDN)
- Edge -> application tier
- Application tier -> data tier
- Application -> external SaaS
- Privileged admin plane vs. user plane
- Tenant boundaries (if multi-tenant)
- Build/deploy plane vs. runtime plane

Each TB entry must cite the evidence that establishes it (e.g., the Terraform security group, the k8s NetworkPolicy, or the absence thereof).

## 6. Assumptions Log
Any architectural claim not backed by evidence. Each assumption gets `ASM-<NNN>` and must be resolved or explicitly accepted before Phase 2.

`ASM-`, NOT `A-`. Section 4a above assigns `A-<NNN>` to actors, and a run that gives both the same prefix produces an inventory where `A-003` means two things and every downstream reference to it is ambiguous -- Phase 4 resolves `A-NNN` to an actor for the context diagram, and Phase 2B's ThreatAgent traces a prerequisite to an actor class. Field-hit: this collision was resolved mid-run by a user ruling at GATE 2, which worked only because a human noticed it.

## 7. Coverage Report
File coverage reconciliation against 00-file-manifest.txt (this is the single-run completeness check -- a non-zero Unaccounted line is a rule violation to fix, not accept):
- Manifest total files: <N>
- In-scope files (assigned to a component/data-store/integration): <N>
- Of those in-scope files, actually OPENED AND READ: <N>; unread in-scope files: <N> (MUST be 0 -- an assigned-but-unread file is a guess, not accounting, and is a rule violation to fix by reading it)
- Files in skip-buckets (counted, rolled up): tests <N>, generated <N>, vendored-third-party <N>, build-config <N>, docs <N>, assets/static <N>, non-production <N>
- Skip-bucket dependency check -- skip-bucketed files that reference an external integration / data store / secret: <none | list, each referenced resource captured in the inventory above>
- In-scope + skip-bucket totals reconcile to manifest total: <yes | Unaccounted: <N> files -- LIST THEM; unaccounted is a rule violation>
- Phase 1 Discovery Delta (found by comprehension while reading, NOT in 00-discovery.md): <none -- Phase 0 sweep was complete | list each item, flagged found-by-comprehension; note which are scope-relevant and were surfaced to the user, and which Phase 0 pattern/mechanism would have caught it>
- Known gaps: <list -- e.g. very large files read only in targeted ranges; carried into the Phase 2C Coverage and Known Gaps section for the report>
```

**Phase 1 completion gate (resume until complete).** Before marking phase-1 complete, check the Coverage Report reconciliation. If Unaccounted > 0 because you ran out of room -- not because those files legitimately belong in a skip-bucket -- Phase 1 is INCOMPLETE. Do NOT rationalize the remaining files into skip-buckets to force the count to zero, and do NOT proceed to Phase 2 on a partial inventory. Instead, write what you have to 01-inventory.md so far, and RETURN the still-unaccounted manifest files (<list or count>) to the orchestrator in your completion summary so it can re-dispatch a continuation covering exactly those files. STATE.md is orchestrator-owned. Do not read-modify-write it. The orchestrator marks phase status. Phase 1 is a resumable, multi-session phase whenever the repo is large -- running out of room is normal and is handled by continuing, never by skimming or by mislabeling unread files as skipped. Mark phase-1 `complete` ONLY when Unaccounted = 0: every manifest file is genuinely assigned to a component/store/integration or to a legitimately-reasoned skip-bucket.

**Phase 1 Completion Banner:**
```
=== PHASE 1 COMPLETE: INVENTORY WRITTEN TO .\{PROJECT_NAME}-threat-model\01-inventory.md ===
Component count: <N>  |  Data stores: <N>  |  External integrations: <N>  |  Trust boundaries: <N>  |  Assumptions: <N>
File coverage: <N> of <N> manifest files accounted for  |  Unaccounted: <N> (must be 0)
System Restatement: draft recorded in 01-inventory.md (PENDING USER CONFIRMATION).
Phase status reported to orchestrator (it owns STATE.md).
Return this banner verbatim as the end of your completion summary.
```
