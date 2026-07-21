<!-- SKILL VERSION: v25-skill (2026-07-21a) -- methodology carved verbatim from PROMPT VERSION v24 (2026-07-16a) -->

**Goal:** Build a complete architectural inventory from existing artifacts and source code. This phase produces the ground truth that every later phase depends on.

**FILE COVERAGE ACCOUNTING (mandatory).** Discovery is an accounting exercise over 00-file-manifest.txt, not a sampled walk. EVERY file in the manifest ends this phase in exactly one of two states, and the distinction between them is the single most important thing in this phase:
- (a) IN SCOPE -- assigned to a component/data-store/integration. An in-scope file MUST be OPENED AND READ, not labeled from its path or filename. READING IT IS THE POINT: it is how you extract the resource references, integrations, data stores, and secrets defined inside. Classifying a file into a component WITHOUT opening it is not accounting for it -- it is guessing from the filename, and it is the exact failure that lets a data store or integration referenced inside that file vanish silently (assigning 71 files to components but reading only 16 is NOT coverage). Rule: if you assigned a file to a component, you have opened and read it. No exceptions.
- (b) SKIP-BUCKET -- a named, one-line-reasoned bucket rolled up by category so it stays cheap: `tests`, `generated`, `vendored-third-party`, `build-config`, `docs`, `assets/static`, `non-production` (per Operating Rule 13). Only skip-bucket files may be labeled without a full read. Skip-buckets are CONSERVATIVE: when unsure whether a file is relevant, READ it -- do not skip it. And before finalizing, DEPENDENCY-CHECK the skip-buckets: if any skip-bucketed file references an external integration, data store, or secret, that referenced resource is still IN SCOPE for the inventory even though the file itself is not threat-walked -- capture it (this is how skipped files silently drop real integrations).

A file in neither state is UNACCOUNTED -- a rule violation. Operating Rule 9 governs HOW you read a large in-scope file (targeted ranges, not whole-file dumps) but NEVER whether you read it. The Coverage Report (section 7) reconciles BOTH accounting and READING -- and the reading line (in-scope files opened vs. in-scope files that exist) is the one that actually forces depth; a large gap there is the signal that you classified instead of read.

**ENUMERATE BY IDENTITY (semantic completeness -- the complement to file coverage above).** Opening every file is necessary but not sufficient: one file can contain many elements, and file-accounting does not by itself force you to list them all. So the inventory MUST enumerate every instance of every element type -- every component, data store, external integration, trust boundary, and secret location -- by its concrete identity, never by a count or a generic quantifier. "Several agents" / "various services" / "multiple queues" / "etc." in place of a full list is a rule violation, not shorthand: enumerate them (`Select-String` the pattern, read the ranges, list each). This phase OWNS the complete enumeration -- do not assume Phase 0 captured every instance; Phase 0 named what is in bounds, this inventory names and evidences every one.

**COMPREHENSION CROSS-CHECK (Phase 1's own discovery -- a second pass by a DIFFERENT mechanism than Phase 0's grep).** Do not merely inherit 00-discovery.md. Phase 0's sweep is PATTERN-based: exhaustive for literal matches, but blind to references no pattern can catch -- a resource name built dynamically (`f"{prefix}-{env}-data"`), a dependency mentioned only in prose or a comment, a reference split across lines. You are already READING every in-scope file deeply (above), which is a DIFFERENT discovery mechanism: comprehension. Use it deliberately. As you read, extract every external service / data store / integration / endpoint you UNDERSTAND to be referenced -- whether or not it would match a pattern -- and cross-check each against 00-discovery.md:
- Already in 00-discovery.md: it is confirmed.
- NOT in 00-discovery.md: a real find the sweep missed. Add it to the inventory AND record it in the Phase 1 Discovery Delta (Coverage Report, section 7), flagged as found-by-comprehension. If it is scope-relevant (a component/integration the approved scope did not include), surface it to the user before finalizing -- do not silently expand the scope they signed off on.
This is defense-in-depth, NOT permission for Phase 0 to be incomplete (scope still depends on Phase 0's sweep being complete). And every delta item is a signal about which Phase 0 pattern or mechanism to strengthen -- the grep pass and the comprehension pass have different blind spots, so running both catches more than either alone, and each delta makes the other better.

**Reminder:** Every file read in this phase targets the current workspace (which IS the source repo). Use the Read tool for specific files and Glob for directory listings per Operating Rule 6. Use PowerShell `Select-String` when you need to search across the repo for patterns, and `Get-Content ... | Select-Object -Skip -First` when you need a line range of a large file.

EXCLUDED from all Phase 1 passes, regardless of how plausible the filenames look: `audit_state/` (the CodeSecurityAudit prompt's own run-state directory -- contains findings and secret locations from a separate workflow, not source documentation), `security_architecture_audit.md` at the workspace root (that prompt's cross-run findings log -- it matches the `SECURITY*` glob below but is a workflow artifact), and `{PROJECT_NAME}-threat-model/` (this prompt's own output directory from prior runs). Do not read, cite as evidence, or treat content from either directory as part of the system under review.

## Partition Contract (parallel passes)
Phase 1 runs as three parallel agents, one per manifest partition (docs / iac / rest,
written by scripts/partition-manifest.ps1). Your accounting universe is YOUR partition
file: every file in it ends as read-and-assigned or skip-bucketed, per the coverage
rules above. You may READ any file in the repo for context (a doc references code, IaC
references an app dir), but you ACCOUNT only for your partition. Do not assign final
IDs -- the reconciliation agent discovers all elements first, sorts alphabetically by
canonical name, then numbers (the fixed-sort rule requires the full set). Refer to
elements by canonical name.

## Partial Inventory Schema (write EXACTLY this structure)
# Phase 1<A|B|C> Partial Inventory -- partition: <docs|iac|rest>
## Elements Found
### <canonical name>
- Element class: component | data-store | external-integration | trust-boundary-evidence
- <then the attribute fields for that class, copied from the 01-inventory.md schema
  sections 2/3/4/5 in phase-1-reconcile.md -- same field names, no ID line>
## Partition File Accounting
- Partition file count: <N> (tool-computed: (Get-Content <partition file>).Count)
- Read and assigned: <N> | Skip-bucketed: tests <N>, generated <N>, vendored-third-party <N>, build-config <N>, docs <N>, assets/static <N>, non-production <N> | Unaccounted: <N>
- Skip-bucket dependency check: <none | list>
- Files read: <list>
## Comprehension Delta Candidates (referenced but NOT in 00-discovery.md)
- <name> -- [evidence: ...]
## Notes for Reconciliation
- <dedupe hints: "the S3 bucket in terraform/s3.tf is the same store main.py calls DATA_BUCKET", cross-partition references, uncertainties>
