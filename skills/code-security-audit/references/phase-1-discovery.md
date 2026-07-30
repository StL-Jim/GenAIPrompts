<!-- BEGIN VERBATIM CARVE src=code-security-audit.md lines=276-381 sha256=57fcbf24d53e3d9098032491e3670684807e134323d115d3690841cd87c178e6 -->
### PHASE 1 -- GLOBAL DISCOVERY
INPUT:
- audit_state/00_workspace_context.md (if present)
- audit_state/resource_inventory.md (if present)
- {PROJECT_NAME}-threat-model/ directory (if present, for coordination mode detection)

COORDINATION MODE DETECTION (FIRST STEP):

Before any other Phase 1 work, check whether a threat model exists in the workspace. Compute `{PROJECT_NAME}` as the workspace leaf directory name (same convention as the threat modeling prompt). Then check for the existence and completeness of `{PROJECT_NAME}-threat-model/`.

A threat model is considered COMPLETE for coordination purposes if all of the following files exist and are non-empty:
- `{PROJECT_NAME}-threat-model/STATE.md`
- `{PROJECT_NAME}-threat-model/00-scope.md`
- `{PROJECT_NAME}-threat-model/01-inventory.md`
- `{PROJECT_NAME}-threat-model/02-threats.md`

Set coordination mode based on what you find:

- COORDINATED mode: All four files exist and are non-empty. The audit will read the threat model's outputs, cross-reference findings against threats, and produce a comparison output in Phase 5.
- STANDALONE mode: Threat model directory does not exist, or exists but is incomplete. The audit produces its current outputs only, with no comparison.

Record the decision in a new state file `audit_state/coordination_mode.md` with this schema:

```markdown
# Audit Coordination Mode

MODE: <COORDINATED | STANDALONE>
DETECTED: <ISO 8601 timestamp>

## Threat Model Binding (COORDINATED mode only)
THREAT_MODEL_PATH: <relative path, e.g., real-world-threat-model/>
THREAT_MODEL_LAST_UPDATED: <timestamp copied from {PROJECT_NAME}-threat-model/STATE.md>
DEPLOYMENT_EXPOSURE: <Internet-facing | Internal | Hybrid | Unknown, copied from 00-scope.md>
INVENTORY_COMPONENT_COUNT: <N>
INVENTORY_TRUST_BOUNDARY_COUNT: <N>
THREAT_COUNT_MAIN: <N, threats in the main Confirmed/Likely table of 02-threats.md>
EXCLUDED_LEDGER_COUNT: <N, rows in the Excluded Threats Ledger of 02-threats.md, 0 if absent>
SEEDED_LEAD_COUNT: <N, ledger rows whose Exclusion Reason begins with Code-level, Unverified, or Attested-mitigated -- concerns the threat model deliberately routed to this audit as leads to verify, 0 if absent>

## Deployment Exposure (STANDALONE mode only)
DEPLOYMENT_EXPOSURE: <Internet-facing | Internal | Hybrid | Unknown, asked from user>
```

In COORDINATED mode:
- Read `{PROJECT_NAME}-threat-model/STATE.md` and copy the LAST_UPDATED timestamp into `coordination_mode.md`. This timestamp becomes the binding contract -- Phase 5 will verify it hasn't changed before producing the comparison output.
- Read `{PROJECT_NAME}-threat-model/00-scope.md` and extract the deployment exposure value. Record it in `coordination_mode.md`.
- Note the threat model component count, trust boundary count, and threat counts (main table and Excluded Threats Ledger separately) for sanity checking later. Count ledger rows whose reason begins with `Code-level`, `Unverified`, or `Attested-mitigated` as seeded leads -- concerns the threat model routed to this audit to verify (an `Attested-mitigated (unverified)` row asks this audit to verify a user-attested control actually exists in code/IaC).

In STANDALONE mode:
- STOP and prompt the user with: "How is this application exposed?"
  - Internet-facing (public internet access)
  - Internal (corporate network/VPN only)
  - Hybrid (mixed exposure)
  - Unknown/Unclear
- Wait for explicit user response. Record the answer in `coordination_mode.md`.
- This question is the same one the threat modeling prompt asks. In COORDINATED mode the audit inherits the answer; in STANDALONE mode the audit asks directly.

The deployment exposure value affects risk scoring throughout the audit -- specifically the Exploitability scale (see RISK SCORING section). Apply this consistently across all subsequent phases.

ACTIONS (after mode detection):
- If this is a fresh run (no audit_state/STATE.md existed at Session-Start), initialize audit_state/STATE.md per the schema in the STATE FILE SYSTEM section: PROJECT_NAME, WORKSPACE, MODE (from coordination_mode.md just detected above), all phases marked `pending` except Phase 6 which is `not_applicable` when MODE is STANDALONE, Resume Instruction = "Begin Phase 1 (Global Discovery)." If this is a resumed run continuing into Phase 1 work, update LAST_UPDATED only.
- Exclude the audit output directory from the source repo's git tracking, using the repo-local un-committed exclude file (same technique as the threat modeling prompt). Add an `audit_state/` entry AND a `security_architecture_audit.md` entry to `.git/info/exclude` if not already present; if `.git/info/exclude` does not exist, warn the user that both will appear in `git status`. This matters because audit state files and the cross-run log contain findings and secret locations and must not be accidentally committed.
- Perform full repo scan
- Build:
  - repository map
  - detected stack
  - service/package/module map
  - trust boundaries
  - high-risk zones
  - unknowns
- In COORDINATED mode, the inventory built here should reference the threat model's inventory rather than duplicating it. Components, data stores, trust boundaries, and external integrations from `{PROJECT_NAME}-threat-model/01-inventory.md` are authoritative -- the audit's discovery confirms and extends rather than rebuilds.
- If repository is large or multi-service, create audit partitions
  - Create partitions if:
    - Repository has >10,000 SLOC (source lines of code)
    - Multiple deployable services detected (e.g., microservices)
    - Distinct security boundaries between modules
  - For each partition, WRITE audit_state/workers/<partition_id>/worker_context.md now, as a Phase 1 output: partition name, root path, entrypoints, key dependencies, data ownership, trust-boundary relevance, and the highest-risk files to start from. This is the file Phase 3A rehydrates from -- it is created here, not by the worker phases.
  - Each partition's worker context summary (worker_context.md plus the evidence index) should fit in ~5,000-10,000 tokens; the worker then reads targeted files within the partition as needed during review. The partition's full source can be larger -- the budget applies to what must be rehydrated, not to the code itself.
- Identify shared components requiring separate review

OUTPUT FILES:
- audit_state/coordination_mode.md (new in Stage 2)
- audit_state/00_workspace_context.md
- audit_state/01_discovery.md
- audit_state/resource_inventory.md
- audit_state/c4_input.md (populated with services, dependencies, trust boundaries for C4 diagram generation)
- audit_state/shared_components.md
- audit_state/partition_plan.md
- audit_state/partition_status.md (if multiple partitions detected; every partition initialized as pending)
- audit_state/workers/<partition_id>/worker_context.md (one per partition, when partitioning is used)

Before printing the banner, update audit_state/STATE.md: mark Phase 1 done; Resume Instruction = "Begin Phase 2 (Risk Prioritization)."

**Phase 1 Completion Banner:**
```
=== PHASE 1 COMPLETE: GLOBAL DISCOVERY DONE ===
  audit_state/coordination_mode.md
  audit_state/01_discovery.md
  audit_state/resource_inventory.md
  audit_state/partition_plan.md
STATE.md updated: Phase 1 marked done.
Type 'proceed' to begin Phase 2 (Risk Prioritization).
```

STOP
<!-- END VERBATIM CARVE -->