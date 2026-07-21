<!-- SKILL VERSION: v25-skill (2026-07-21a) -- methodology carved verbatim from PROMPT VERSION v24 (2026-07-16a) -->

Read common.md, phase-1-shared.md, STATE.md, 00-scope.md, 00-discovery.md, 00-file-manifest.txt, 01a-partial.md, 01b-partial.md, and 01c-partial.md.

## Reconciliation Procedure (in order)
1. Merge: union the Elements Found sections of the three partials. Dedupe by canonical
   name and evidence overlap; consult each partial's Notes for Reconciliation. A store
   found in IaC (1B) and referenced in code (1C) is ONE element with both citations.
2. Apply the Section 2 component definition to the merged set: every data store,
   managed service, queue, cache, gateway, and identity provider is ALSO a component.
3. Assign IDs by the fixed-sort rule: sort each class alphabetically by canonical
   name, then number C-001..., DS-001..., EXT-001..., TB-001...
4. Coverage: sum the three Partition File Accounting blocks; the three partition
   counts must sum to the manifest total (paste the partition-manifest.ps1
   reconciliation line, or recompute with (Get-Content ...).Count). Total Unaccounted
   must be 0 -- if any partial reported unfinished files, STOP and return the list.
5. Discovery Delta: union the three Comprehension Delta Candidates lists, dedupe,
   cross-check against 00-discovery.md, and record per the Coverage Report schema.
   Scope-relevant deltas are flagged in your summary for the user.
6. Write 01-inventory.md per the schema below. The System Restatement section is
   written as: "PENDING USER CONFIRMATION: <your draft restatement paragraph>".
7. Return in your summary: the draft System Restatement (verbatim), component/TB/
   assumption counts, the coverage reconciliation line, and scope-relevant deltas.
   The orchestrator relays the restatement to the user (GATE 2) and edits the final
   confirmed text into 01-inventory.md. If the user's GATE 2 correction affects other
   inventory sections (Components, Trust Boundaries, Data Stores, Data Flows -- e.g. a
   correction to the user population or the most-sensitive-asset can invalidate entries
   in those sections), the orchestrator must update the affected inventory sections
   in 01-inventory.md to match the confirmed restatement before Phase 2 begins.

### Phase 1 Output: `.\{PROJECT_NAME}-threat-model\01-inventory.md`

Structure:

```markdown
# Architectural Inventory

## System Restatement
<the user-confirmed one-paragraph restatement written at the end of Phase 1: what the system is, what it talks to, who its users are, its single most sensitive asset>

## 1. Documentation Artifacts
| ID | Path | Type | Key Assertions |
|----|------|------|----------------|
| DOC-001 | docs/architecture.md | design-doc | ... |

## 2. Components
This is the MASTER inventory of architectural elements, and it directly gates threat coverage: Phase 2B walks STRIDE per component, so any element absent here is never threat-modeled. DEFINITION -- every architectural element that PROCESSES, STORES, or MEDIATES this system's data is a component: it gets a C-NNN ID and a Phase 2 STRIDE walk. This explicitly includes data stores, cloud/AWS managed services (S3, DynamoDB, Bedrock, SQS, ...), queues, caches, gateways, and identity providers -- NOT only active-process services. Do NOT undercount by treating data stores or managed services as a lower tier: the Data Stores (Section 3) and External Integrations (Section 4) sections are supplementary attribute detail about elements that ALSO appear here as components, keyed to the same C-NNN -- every element listed in those sections MUST also appear in this section. Each architectural element appears here exactly once (one C-NNN) and is walked once in Phase 2. (This definition is load-bearing: undercounting components is the single largest cause of incomplete threat enumeration -- a narrow "active-process only" reading has produced 3-4 components where the correct reading produces ~12-13 on the same system.)

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
Any architectural claim not backed by evidence. Each assumption gets `A-<NNN>` and must be resolved or explicitly accepted before Phase 2.

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

**Phase 1 completion gate (resume until complete).** Before marking phase-1 complete, check the Coverage Report reconciliation. If Unaccounted > 0 because you ran out of room -- not because those files legitimately belong in a skip-bucket -- Phase 1 is INCOMPLETE. Do NOT rationalize the remaining files into skip-buckets to force the count to zero, and do NOT proceed to Phase 2 on a partial inventory. Instead, write what you have to 01-inventory.md so far, and RETURN the still-unaccounted manifest files (<list or count>) to the orchestrator in your completion summary so it can re-dispatch a continuation covering exactly those files. STATE.md is orchestrator-owned. Do not read-modify-write it; the orchestrator marks phase status. Phase 1 is a resumable, multi-session phase whenever the repo is large -- running out of room is normal and is handled by continuing, never by skimming or by mislabeling unread files as skipped. Mark phase-1 `complete` ONLY when Unaccounted = 0: every manifest file is genuinely assigned to a component/store/integration or to a legitimately-reasoned skip-bucket.
