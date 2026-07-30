<!-- BEGIN VERBATIM CARVE src=code-security-audit.md lines=65-150 sha256=a302a4c1bd3fcd95e69027edb1dcd51fc2ba77e16c17790cf9eb145cb12f0807 -->
GLOBAL RULES
- ASCII-ONLY OUTPUT (mandatory, all generated artifacts): every file this audit writes -- Markdown state files, findings, the comparison Markdown intermediate, and HTML deliverables -- uses ASCII characters only. No em-dashes, en-dashes, smart quotes, right-arrows, or ellipsis characters; use the substitution table in the threat modeling prompt's Operating Rule 14 (`--`, `-`, `->`, straight quotes, `...`). Rationale is the same as there: viewers defaulting to Windows-1252 garble stylistic Unicode, and Phase 6 renders the comparison Markdown into a stakeholder HTML deliverable by mechanical fill, so Unicode in any state file flows through unfixed.
- SEVERITY SCOPE (mandatory): this audit reports Critical and High severity findings ONLY. Do not produce, score, or write up Medium, Low, or Info findings -- not in worker findings.md files, not in findings_registry.md, not in any deliverable. If a worker notices a Medium/Low/Info-level issue while reviewing code, do not analyze it further, do not draft an issue/impact/fix/verify write-up for it, and do not assign it a finding ID. This keeps worker output budget concentrated on the findings that matter and prevents the consolidated report from being diluted with low-value entries. This applies identically in COORDINATED and STANDALONE mode.
- Use ONLY evidence from:
  - Files in the workspace
  - Executed commands and tool outputs actually produced in this session
- NEVER hallucinate:
  - vulnerabilities
  - runtime behavior
  - scan results
  - missing evidence
- NEVER reference a specific CVE identifier unless it literally appears in repository files (e.g., a lockfile comment, SECURITY.md, an advisory file) or in executed tool output produced in this session. CWE references are allowed because they are a stable taxonomy; CVEs are not. This matters most in A06 dependency analysis, where CVE invention is the most tempting failure mode.
- SECRETS REDACTION (mandatory): when a secret value is discovered (API key, password, token, connection string, private key), record the file path and line, the key/variable name, and a masked fragment only (first 4 characters followed by `****`, e.g., `AKIA****`). NEVER write the full secret value into any state file, finding, report, or chat output. The finding is the LOCATION of the secret, not the secret itself -- audit state files and HTML deliverables get shared, mailed, and committed, and must never become a second copy of the credential.
- Missing evidence != proof of safety
- Prefer repository-wide search for discovery, then partition-scoped inspection for depth
- Optimize for:
  - precision over coverage
  - deterministic outputs
  - token and context efficiency
- Deprioritize:
  - generated files
  - vendored code
  - lockfiles
  - build artifacts
  unless directly relevant to risk

---

MONOREPO / MULTI-SERVICE STRATEGY
You MUST detect whether the repository is:
- monolith
- monorepo
- multi-service

If multiple deployable services, modules, or packages exist:
- use orchestrator + worker partitioning
- partition by deployable service first
- then review security-critical shared components separately

After partitioning:
- inspect only the current partition
- include only directly relevant shared files or trust-boundary files
- record cross-service issues as:
  - shared
  - upstream
  - downstream
  - boundary-crossing
- consolidate duplicates later; do not expand scope unnecessarily

---

AUTO-DISCOVERY REQUIREMENTS (MANDATORY FIRST STEP)
You MUST:
- scan the repository recursively
- detect:
  - repo structure and boundaries
  - services/modules/packages
  - languages, runtimes, frameworks
  - manifests and lockfiles
  - APIs, routes, workers, schedulers, CLIs
  - CI/CD, Docker, Kubernetes, Terraform, Helm
  - auth/authz patterns
  - config and secret-loading patterns
  - data stores, queues, and storage layers
  - external integrations
  - trust boundaries
  - secrets stored in config.json, .env or other files. Use PowerShell `Get-Content <filename>` or `Select-String -Pattern 'password|secret|api[_-]?key|token'` if necessary, and apply the SECRETS REDACTION rule from GLOBAL RULES to anything found -- never persist the full secret value

Monorepo signals include:
- apps/, services/, packages/, modules/, cmd/, projects/
- multiple deployables
- multiple manifests
- multiple Dockerfiles, Helm charts, Terraform modules, or CI jobs

For each service or partition infer:
- name
- type
- root path
- entrypoints
- dependencies
- data ownership
- trust-boundary relevance
- blast radius

---
<!-- END VERBATIM CARVE -->