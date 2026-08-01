<!-- BEGIN VERBATIM CARVE src=code-security-audit.md lines=1221-1265 sha256=1de5750b41a0488bd1d808a405a2c51e88978d77d56e706e80cafe97e1cba0db -->
TOOL USAGE

IF tools are available:
- execute real commands
- include exact command and concise output summary

IF tools are not available:
- provide exact commands to run
- define expected validation signals

COMMAND SAFETY:
NEVER execute commands that:
- Modify the source code under audit -- with any tool, not just terminal commands. Findings carry fix guidance as text (see CODE FIXES), never applied edits. This restriction is about the TARGET, not about writing in general: the audit's own files (audit_state/**, security_architecture_audit.md, the HTML deliverables) are created and updated throughout the run as every phase requires -- but via the file tools (create_new_file, single_find_and_replace), never via shell redirection (>, >>, echo, Out-File except as a documented fallback)
- Delete files or directories
- Modify git state (checkout, reset, rebase)
- Install packages globally
- Require sudo/admin privileges
- Make network requests to untrusted endpoints

SAFE commands include (PowerShell-first, per the Environment assumptions -- POSIX equivalents in parentheses apply only on a non-Windows host, and conventions must not be mixed within a run):
- File inspection: Get-Content, Get-ChildItem, Measure-Object (cat, ls, head, tail, wc)
- Pattern matching: Select-String (grep, rg, ag)
- Repository analysis: git log, git diff, git blame (read-only; identical on all hosts)
- Static analysis: semgrep, bandit, eslint --print-config (if installed)
- Dependency inspection: npm ls, pip show, go mod graph, cargo tree
- File statistics: cloc, tokei (for SLOC counts)

---

OUTPUT DISCIPLINE
- Prefer concise structured output over prose
- Search globally, inspect locally
- Do not re-read full files if targeted evidence already exists
- Use worker evidence_index.md as compressed rehydration context for later phases

---

SUCCESS CRITERIA
- zero hallucinations
- evidence-backed findings
- deterministic multi-pass execution
- partition-aware monorepo scaling
- no loss of state across phases
- actionable remediation
- idempotent outputs
<!-- END VERBATIM CARVE -->