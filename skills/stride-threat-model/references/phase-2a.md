<!-- SKILL VERSION: v25-skill (2026-07-21a) -- methodology carved verbatim from PROMPT VERSION v24 (2026-07-16a) -->

### Phase 2A -- Assets, Trust Boundaries, Data Flows

#### Phase 2A Rehydration (MANDATORY FIRST STEP)

Read STATE.md, 00-scope.md, and 01-inventory.md. The inventory is the authoritative source for components, trust boundaries, data stores, and external integrations. 00-scope.md is small and carries the Phase 0 user inputs that Phase 2 decisions depend on -- deployment exposure, criticality, existing controls, data sensitivity, governance framework, and the out-of-scope list. Disk content takes precedence over conversation memory.

Read these files with the Read tool (disk content overrides memory): STATE.md, 00-scope.md, 01-inventory.md.

STATE.md is orchestrator-owned. Do not read-modify-write it.

After reading, acknowledge in one line how many components, trust boundaries, data stores, and external integrations the inventory contains.

#### Phase 2A Work

Produce three sections, all grounded in the inventory:

1. ASSETS -- what data, secrets, and resources need protection. Group by asset type (data, secrets, authentication, infrastructure, service availability, code/IP). Each asset references the inventory IDs (`C-NNN`, `DS-NNN`, `EXT-NNN`) that handle it.

   Assets are DERIVED from the inventory, not sampled -- these floors are MANDATORY (a missing one is a rule violation, not a judgment call), so a single run is complete without needing a prior run to compare against: (a) every distinct data classification appearing on any component's `Data handled` field or any data store's `Data classification` field MUST appear as at least one Data Asset -- a data store being enumerated as a component does NOT remove its stored data as an asset (the component is the container, the data is the asset; enumerate both); (b) every secret, credential, key, or token surface in the inventory MUST appear under Secrets; (c) the source code repository / IP MUST appear under Code / IP when source is in scope; (d) every Critical- or High-criticality component MUST have a Service Availability asset. Grouping ABOVE the floor is judgment, but the DEFAULT is granular separation, not consolidation: distinct data classifications usually have distinct threat profiles (e.g. request content vs stored response vs operational metadata differ in exposure and impact), so keep them as separate assets. Consolidate two classifications into one asset ONLY when they genuinely share the same threat profile AND the same controls -- if they would be attacked differently or protected differently, they stay separate. Over-consolidation silently drops coverage (a merged asset lets only one threat anchor where two were warranted).

2. TRUST BOUNDARIES -- restate every TB from the inventory using the same `TB-NNN` IDs. For each, name the principals on either side and the controls (or lack thereof) that establish the boundary. This is a re-statement, not a re-derivation; do not invent new boundaries that aren't in the inventory.

3. DATA FLOWS -- enumerate every data flow between components. Each flow gets a stable ID `DF-NNN`. For each flow record: source component ID, destination component ID, data classification, protocol, authentication, encryption status, and whether it crosses a trust boundary (and which one). Mark trust-boundary-crossing flows clearly because they are the focus of Phase 2B.

Flow completeness (derive, don't sample): the flow graph is already implicit in 01-inventory.md -- every component dependency edge, every data store access-pattern entry, and every external integration direction MUST yield at least one DF, enumerated systematically from those inventory fields, not recalled from memory. Set each flow's Encryption and AuthN from real evidence (code, IaC, or the Q6a attested platform profile); never assume TLS. An inventory edge that yields no flow needs a one-line justification in the coverage check below.

Flow granularity -- group by SECURITY CHARACTERISTIC, not by transport detail. Between the same two components, split into separate DFs when the traffic differs in authentication, data classification, or trust boundary crossed; keep it as one DF when those are the same (do NOT split per individual HTTP method or per endpoint that share the same security characteristics -- that is noise). A read-write data store access is TWO flows (component -> store for writes, store -> component for reads), and a bidirectional exchange is two flows whenever the request and response carry different data classifications.

Flow direction validation (do this after building the table): confirm every flow's direction is correct -- external/user traffic flows FROM the outside INTO the application edge, not reversed -- and that any bidirectional relationship you represented as one row genuinely has matching request/response classification (otherwise split it into two directed rows).

The Encryption and AuthN columns use FIXED vocabularies -- no free-text synonyms -- because the Phase 2B data-flow obligation check keys off the exact words `plaintext`, `none`, and `unknown`, and a synonym like "N/A" or "not encrypted" would silently disarm it. Encryption is exactly one of: `TLS1.3`, `TLS1.2`, `mTLS`, `plaintext`, `unknown`. AuthN is exactly one of: `mTLS`, `OIDC`, `token`, `API-key`, `basic`, `none`, `unknown`. Use `unknown` (not a guess) when the flow exists but its protection could not be determined from evidence or attestation.

#### Phase 2A Output: `.\{PROJECT_NAME}-threat-model\02a-context.md`

Structure:

```markdown
# Phase 2A -- Assets, Trust Boundaries, Data Flows

## Assets

Every asset carries a CRITICALITY tier, recorded as the third field. The tier is assigned by LOOKUP, not by judgement -- it is what lets a later phase rank a threat by what it targets rather than by how the impact sounds in prose:
- `Primary` -- every asset carrying the HIGHEST classification named in the Q4 data-sensitivity answer in 00-scope.md. Q4 asks the user "What is the sensitivity of the data the application handles?", so this tier is a LOOKUP against an answer they already gave -- not your estimate, and not a judgement about which asset sounds most valuable. ANY NUMBER of assets may hold it: a system handling one class of regulated data at its top classification may have several stores, queues and caches that all carry it, and demoting all but one of them would misdescribe the system. If Q4 names no sensitive data at all, no asset is `Primary` and the tier is simply unused.
- `Sensitive` -- data matching the Q4 data-sensitivity answer in 00-scope.md (PII, PHI, financial, and the like), plus every secret, credential, and authentication or session asset. These are the assets whose loss is reportable, or which directly enable impersonation.
- `Supporting` -- everything else: internal metadata, configuration holding no secrets, service availability, non-sensitive code and infrastructure.

If the Q4 answer names a data classification that corresponds to no asset you enumerated, do NOT invent an asset and do NOT quietly promote a substitute: record the mismatch in the Asset Coverage Check. It means Phase 0 and Phase 2A disagree about what this system holds, which is worth a human's attention rather than a silent repair.

### Data Assets
- AS-001: <name> -- <classification> -- <criticality> -- handled by [C-001, C-003, DS-002] -- [evidence: ...]
### Secrets
- AS-NNN: ...
### Authentication / Sessions
- AS-NNN: ...
### Infrastructure
- AS-NNN: ...
### Service Availability
- AS-NNN: ...
### Code / IP
- AS-NNN: ...

### Asset Coverage Check
- Data classifications in 01-inventory (components + data stores): <list>
- Each represented by a Data Asset above: <yes | list of unmapped classifications -- an unmapped classification is a rule violation>
- Secret/credential surfaces in 01-inventory: <N>; each under Secrets: <yes | gaps>
- Source repository in scope: <yes/no>; if yes, present under Code / IP: <yes/no>
- Primary assets: <list of AS-NNN, and the Q4 classification each carries | none -- Q4 names no sensitive data | UNMAPPED -- Q4 names "<classification>" and no enumerated asset carries it, so Phase 0 and Phase 2A disagree>
- Every asset carries one of the three criticality tiers: <yes | list of AS-NNN missing a tier -- an untiered asset breaks the Impact test in Phase 2B>

## Trust Boundaries
| TB ID | Boundary | Principals | Establishing Control | Evidence |
|-------|----------|------------|----------------------|----------|
| TB-001 | Internet -> edge | anonymous users / WAF | AWS WAF rule set | [evidence: terraform/waf.tf:1-44] |

## Data Flows
| DF ID | Source | Destination | Data | Protocol | AuthN | Encryption | Crosses TB? | Evidence |
|-------|--------|-------------|------|----------|-------|------------|-------------|----------|
| DF-001 | C-001 (Edge) | C-003 (API) | Auth tokens, request bodies | HTTPS | mTLS | TLS1.3 | TB-002 | [evidence: src/edge/router.go:88-104]; [evidence: terraform/alb.tf:1-30] |

### Data Flow Coverage Check
- Inventory edges (component dependencies + data store access entries + external integration directions): <N>. Count each read-write data store access as TWO edges (a write edge and a read edge); count an API/integration surface as one edge per distinct security-characteristic group (shared auth + classification + boundary), not one per HTTP method.
- Data flows derived: <N> (expect >= edge count, since bidirectional exchanges with differing request/response classifications split into two)
- Inventory edges that yielded no flow, each with a one-line justification: <list, or 'none' -- an unjustified missing edge is a rule violation>
```

Write the file with the Write tool. Return your completion banner to the orchestrator (it owns STATE.md).

**Phase 2A Completion Banner:**
```
=== PHASE 2A COMPLETE: 02a-context.md WRITTEN ===
Assets: <N>  |  Trust boundaries: <N>  |  Data flows: <N>  |  Boundary-crossing flows: <N>
Phase status reported to orchestrator (it owns STATE.md).
Return this banner verbatim as the end of your completion summary.
```
