# REBUILD: Code Security Audit Skill

You are rebuilding a Claude Code skill on a machine that cannot install one from outside.
This file is the procedure. Three companion files -- `PART-A-core.md`, `PART-B-phases.md`,
`PART-C-review.md` -- carry the reference files verbatim. This file additionally specifies
ten PowerShell scripts you must write from their contracts.

Follow it in order. Everything here is ASCII; keep it that way in everything you write.


## 0. How this differs from the STRIDE rebuild

If you have seen `stride-migrate/REBUILD-PROMPT.md`, do not assume the same method. It does
not apply here, and the reason matters.

The STRIDE skill was CARVED from its monolithic prompt -- the text was moved verbatim and the
carve was verified by checksum. So that rebuild is a split map: it points at monolith sections
and says where each one goes.

**This skill was REWRITTEN, not carved.** The archived `code-security-audit.md` monolith is
91 KB; the skill built from it is 362 KB. Compared directly, the monolith's `PHASE 2` is a
terse `INPUT / ACTIONS / OUTPUT` block while the skill's `phase-2.md` is expansive prose with
orchestrator framing, GATE 1, and the reasoning for the phase's existence. Sampling
distinctive lines from every reference file against the monolith: `schemas.md` matched 5 of 5
and `global-rules.md` 2 of 2, but every phase file, plus `gate-2.md`, `judge.md` and
`critic.md`, matched ZERO.

So the monolith cannot supply the methodology here. It is an earlier, thinner document.
Rebuilding from it would hand you a v1 spec and silently drop the whole conversion: GATE 2,
the judge, the critic, the partition machinery, the read-floor verification.

That is why PART A/B/C carry the reference files in full. **Do not consult the monolith for
methodology.** If it is present on this machine, ignore it.

The scripts are the opposite case: they are specified here in prose and you write them. Their
correctness is checkable against a stated contract, and section 5 tells you how to check it.


## 1. Preflight -- verify, then STOP if anything is missing

**Everything is relative to the directory containing THIS file.** Call it BUILD_ROOT. It is
normally the root of a git repository created for this one skill, and it is where the rebuilt
skill will be written. The expected layout at the start:

    BUILD_ROOT/
      REBUILD-PROMPT.md      this file
      PART-A-core.md
      PART-B-phases.md
      PART-C-review.md

1. All three PART files are present in BUILD_ROOT and readable. Report each one's size.
   Expected, approximately: 67 KB, 118 KB, 37 KB. If one is somewhere else, ASK THE USER for
   the path rather than guessing or searching the filesystem.
2. **The build target.** Nothing to confirm, only to state: you will create
   `BUILD_ROOT/code-security-audit/` and write the whole skill inside it. Report that
   absolute path.

   Do NOT write to `~/.claude/skills/` and do not install anything. This rebuild produces a
   tracked source tree, not an installation. Making the skill available to Claude Code is a
   separate step the user handles afterwards, and it is deliberately not your job -- writing
   outside BUILD_ROOT puts files somewhere the user's version control cannot see them.
3. PowerShell is available. Run `powershell.exe -NoProfile -Command '$PSVersionTable.PSVersion'`
   and report what it prints. The scripts are PowerShell regardless of what your own shell is.

If any PART file is missing, STOP and say which. Do not attempt to reconstruct its contents
from anything else -- there is no other source for them on this machine.


## 2. Rules that bind this rebuild

- **The PART files are verbatim.** Write each block exactly as given. Do not reformat,
  re-wrap, renumber, fix apparent typos, or shorten anything. If a passage looks wrong, note
  it in your final report and write it as given anyway.
- **The scripts are yours to write, not to invent.** Each spec below states a contract:
  parameters, inputs, outputs, exit codes, and the principles the logic must honour. Meet the
  contract. Where the spec explains WHY a rule is shaped a certain way, carry that reasoning
  into the script as a comment -- those notes exist to stop a later reader from "simplifying"
  a rule back into a defect that was already paid for once.
- **Do not tune against numbers you cannot see.** Several constants below were originally
  derived by measurement against other repositories. The spec gives you the derivation, not
  just the number. Section 5.3 has you re-measure against THIS repository, which is the
  correct source of truth for it.
- **Count the writes.** This rebuild produces 25 files: 15 markdown, 10 scripts. One write
  each.


## 3. Target file tree

All of it inside BUILD_ROOT, alongside this file and the three PART files. Nothing is written
outside BUILD_ROOT.

    BUILD_ROOT/
      REBUILD-PROMPT.md               (this file, already here)
      PART-A-core.md                  (already here)
      PART-B-phases.md                (already here)
      PART-C-review.md                (already here)
      code-security-audit/            <- everything below is what you create
        SKILL.md                      <- PART A
        references/
          common.md                   <- PART A
          global-rules.md             <- PART A
          tool-usage.md               <- PART A
          schemas.md                  <- PART A
          phase-1-discovery.md        <- PART B
          phase-2.md                  <- PART B
          phase-3a.md                 <- PART B
          phase-4a.md                 <- PART B
          phase-3b-4b.md              <- PART B
          phase-5.md                  <- PART B
          phase-6.md                  <- PART B
          gate-2.md                   <- PART C
          judge.md                    <- PART C
          critic.md                   <- PART C
        scripts/
          lib-classify.ps1            <- spec S-1   WRITE THIS FIRST
          manifest.ps1                <- spec S-2
          init-workspace.ps1          <- spec S-3
          partition-plan.ps1          <- spec S-4
          readplan.ps1                <- spec S-5
          merge-findings.ps1          <- spec S-6
          apply-dispositions.ps1      <- spec S-7
          score-judge.ps1             <- spec S-8
          renumber-findings.ps1       <- spec S-9
          verify-deliverables.ps1     <- spec S-10


## 4. Write the reference files

Work through PART A, then PART B, then PART C. Each block is delimited:

    ===== BEGIN FILE: <relative path>
    ...content...
    ===== END FILE: <relative path>

The markers are not part of the file. The path in each marker is relative to
`BUILD_ROOT/code-security-audit/` -- so a block headed `references/phase-2.md` is written to
`BUILD_ROOT/code-security-audit/references/phase-2.md`.

The source files were checked and none contains either marker, so a marker line inside a
block is impossible -- if you think you see one, you have lost your place.


## 5. Write the scripts

### 5.1 Order

Write `lib-classify.ps1` FIRST. `partition-plan.ps1` and `readplan.ps1` both dot-source it,
and they must agree exactly. Then the rest in the order listed in section 3.

### 5.2 Common preamble

Every script takes at least these, unless its spec says otherwise:

    param(
      [Parameter(Mandatory=$true)][string]$Workspace,
      [Parameter(Mandatory=$true)][string]$ProjectName
    )
    $ErrorActionPreference = 'Stop'
    $WORKSPACE = (Resolve-Path -LiteralPath $Workspace.TrimEnd('\')).Path.TrimEnd('\')
    $STATE = "$WORKSPACE\audit_state"

Output goes under `audit_state/`. Exit 0 on success; exit 1 on a failure the caller must act
on. Print what you did -- these scripts are read by an orchestrator that has to report to a
person, and a silent success is indistinguishable from a silent skip.

### 5.3 Calibrate, do not transplant

Two numbers govern whether this audit can run at all: the slice size in `partition-plan.ps1`
and the read floor in `readplan.ps1`. Both are derived from the CONTEXT WINDOW of the model
running the workers. The derivations in S-4 and S-5 assume a 200,000-token window.

After you have written `lib-classify.ps1`, `manifest.ps1` and `readplan.ps1`, and before any
audit is run for real:

1. Build the manifest for this repository.
2. Run the classifier over it and print a count per class.
3. Print, for each floor class, how many files it would put in the floor.
4. Compare the total against `-FloorPerWorker`.

**Read the result as a statement about your rules, not about the repository.** If one pattern
floors most files of a given type, that pattern is matching the LANGUAGE rather than a risk --
finding SQL inside a `.sql` file, or HTML inside a view, tells you nothing. That is the single
failure mode that has broken this floor before, and S-1 is written to prevent it.

Report the numbers. If the window in use here is not 200,000, redo the arithmetic in S-4 and
S-5 with the real number and report both the old and new values.


## 6. Finish in place -- do not install

The tree is already where it belongs: `BUILD_ROOT/code-security-audit/`. There is no install
step, and you should not perform one. Do not copy the tree to `~/.claude/skills/`, do not
create symlinks, and do not modify anything outside BUILD_ROOT. The user keeps this under
version control and installs from it on their own terms; a helpful copy placed elsewhere
becomes a second, untracked version that drifts silently.

Two checks while you are still here, both cheap now and annoying later:

- **SKILL.md frontmatter.** The file must begin with `---` on line 1 and carry both `name:`
  and `description:`. That is what makes it loadable as a skill at all, and it is the first
  thing to be wrong if it later fails to appear.
- **Git.** If BUILD_ROOT is a git repository, run `git status` and report what is untracked,
  so the user sees the full set of new files in one place. Do NOT stage, commit, or write a
  `.gitignore` -- what gets committed is the user's decision, not yours.


## 7. Verify

Run every check and report each result separately. Do not report success on a check you did
not run.

1. **25 files exist and are non-empty.** List the tree with sizes.
2. **The verbatim files are intact.** For each of the 15, confirm its first and last
   non-blank lines match the PART file's block. A truncated write is the likely failure and
   it is silent.
3. **No marker leakage.** Grep the written tree for `===== BEGIN FILE` and `===== END FILE`.
   Any hit means a delimiter was written into a file.
4. **Every script parses.** For each: `powershell.exe -NoProfile -Command "$null = [System.Management.Automation.Language.Parser]::ParseFile('<path>', [ref]$null, [ref]$null)"`.
   A parse error here is cheap; the same error mid-audit is not.
5. **The two consumers agree.** Confirm `partition-plan.ps1` and `readplan.ps1` both
   dot-source `lib-classify.ps1` and that neither defines its own copy of any classification
   rule. This is the defect that would look like a coverage failure rather than a definition
   failure.
6. **The calibration from 5.3**, with its numbers.
7. **Shell form.** If your shell is bash, confirm you can invoke one script through
   `powershell.exe -NoProfile -ExecutionPolicy Bypass -File '<path>' -Workspace '<abs>' -ProjectName '<name>'`.
   This is common.md rule S and it is where rebuilds usually break first.

Then report: files written, checks passed, checks failed, any constant you changed and why,
and anything you did differently from this specification.


## Appendix S -- script specifications

---

### S-1. lib-classify.ps1  (write this first)

**Role.** Shared file-role classification, dot-sourced by `partition-plan.ps1` and
`readplan.ps1`. Not run directly.

**Why one file.** Both consumers must agree EXACTLY. `partition-plan.ps1` sizes partitions by
how much auditable source each root holds; `readplan.ps1` turns the same judgement into the
per-worker read floor. If the two ever disagreed, partitions would be sized against one
definition of "source" and verified against another -- and the mismatch would present as a
coverage failure rather than a definition failure, which is a much harder thing to diagnose.
Do not duplicate any rule into either consumer.

**Matching principles.** By ROLE, via path and filename. Deliberately framework-agnostic.
FIRST MATCH WINS. And it errs toward INCLUSION: a file wrongly included costs one read, a
file wrongly excluded costs a missed vulnerability.

**Classification order.** Evaluate in exactly this order and return on the first hit:

| # | Class | What it is |
|---|---|---|
| 1 | `excluded` | Generated, vendored, binary, build output, lockfiles, and AGENT TOOLING SCRATCH. Never floored, never counted against coverage. |
| 2 | `test` | Dev/QA/test artifacts. May be inventoried; do not generate findings (common.md rule P). |
| 3 | `dep-manifest` | Dependency manifests. Few, small, and the only place A06 evidence exists at all. |
| 4 | `config-iac` | Config, CI, IaC. A05 lives here, and deployment facts set every other finding's score. |
| 5 | `docs` | Documentation and prose. |
| 6 | `authz` | Anything touching authentication, authorization, session, identity, secrets or crypto. |
| 7 | `entry-route` | Entry points: mains, handlers, controllers, routes, jobs, consumers, CLI. |
| 8 | `data-access` | Repositories, DAOs, entities, queries, ORM, migrations, `.sql`. |
| 9 | `ext-call` | Outbound: clients, gateways, adapters, connectors, proxies, SDKs. |
| 10 | `app-source` | Any remaining recognised source file, by extension. |
| -- | `$null` | Matched nothing. Not auditable. |

**Two classes that are NOT in the floor: `test` and `docs`** (and `excluded`, obviously).

`docs` is the sharpest departure from the threat model's equivalent, which floors all docs
because prose names integrations that no pattern can see. This audit is not hunting
integrations. `schemas.md` requires a quoted SOURCE line for any Confirmed finding, so a
README can never be that line.

**The floor set** is: `authz`, `entry-route`, `data-access`, `ext-call`, `config-iac`,
`dep-manifest`, `app-source`.

**Auditability test.** A file is auditable when: it classified to something; that class is in
the floor set; AND, if the class is `app-source`, it also matches a dangerous-API pattern.

That last condition is what keeps the floor meetable. Twice in the field a mandatory floor was
set so high the audit could not run and the floor was abandoned wholesale. Ordinary
application source enters the floor only where a dangerous-API pattern actually matched, so
the floor tracks the partition's real defect surface rather than its file count. Quiet source
is not dropped -- it lands in the deferred list with a mechanical reason.

If a file cannot be read to test it, treat it as matching. Err toward reading.

**Rules to encode, by class.** Write regexes that express these. They are principles, not
transcriptions -- get the idea right rather than matching some exact pattern.

- **excluded** -- editor and tool directories (`.vscode`, `.idea`, `.husky`, and agent tool
  scratch such as `.claude` or `.superpowers`); every common lockfile; minified and sourcemap
  files; binaries, archives, media, fonts, office documents, database files; and build output
  directories (`dist`, `build`, `out`, `bin`, `obj`, `coverage`, `__snapshots__`).
  **`.github` is deliberately NOT excluded** -- workflow definitions are genuine A05 config.
  The tooling-scratch entry was added after a real run put `server.pid`, `server-stopped` and
  a stray `.html` into a worker's mandatory floor, because the role matchers legitimately saw
  "state", "server" and ".html" in a local agent tool's working directory. Every one of those
  displaced a real source file from a worker's attention.
- **test** -- test and spec directories, `*.test.*` / `*.spec.*` filename forms,
  `test_*.py`-style prefixes, and `*Tests.cs|java|kt|scala`.
- **dep-manifest** -- the project-file and manifest names for the ecosystems you expect:
  `.csproj`/`.fsproj`/`.vbproj`, `packages.config`, `package.json`, `requirements*.txt`,
  `pyproject.toml`, `Pipfile`, `pom.xml`, `build.gradle(.kts)`, `go.mod`, `Gemfile`,
  `composer.json`, `Cargo.toml`, `mix.exs`, `pubspec.yaml`.
- **config-iac** -- dotenv files, `appsettings*.json`, config/settings directories,
  `values*.yaml`, `kustomization.yaml`, overlay directories, Terraform, configmap and secret
  manifests, `web.config`/`app.config`, `.properties`, GitHub workflows, `.gitlab-ci.yml`,
  `Jenkinsfile`, `Dockerfile`, `docker-compose*.yml`, and Helm.

  **Match Helm by its own marker files** -- `Chart.yaml`, a `helm/` directory, or a
  `templates/` directory beneath a chart -- and NOT by a bare `charts/` prefix. A bare
  `charts/` was tried and swept 252 chart DATA files (an astrology application) into the
  config class, which bulk filtering then had to throw 226 back out. **A directory name is not
  a role; the marker files are.** Apply that principle beyond Helm.
- **authz** -- the vocabulary of identity and secrets: auth, oauth, oidc, saml, sso, login,
  token, jwt, session, identity, principal, permission, policy, guard, middleware, rbac, acl,
  claims, password, credential, crypto, cipher, hash, kms, vault, secret.
- **entry-route** -- entry filenames (`main`, `app`, `index`, `server`, `program`, `startup`,
  `wsgi`, `asgi`, `bootstrap`, `entrypoint`, and the serverless forms `handler`,
  `lambda_function`, `function_app`) plus routing and dispatch vocabulary (controller, route,
  router, endpoint, api, handler, resolver, graphql, grpc, servlet, webhook, consumer,
  listener, subscriber, worker, scheduler, cron, job, task, cli, cmd, command).
- **data-access** -- repository, dao, entity, model, schema, query, orm, dbcontext, database,
  store, persistence, mapper, migration; and any `.sql`.
- **ext-call** -- client, gateway, adapter, connector, integration, proxy, outbound, external,
  thirdparty, sdk, httpclient, rest, soap, feign.
- **app-source** -- by extension, across the languages and template formats you expect to
  meet. Include shell and PowerShell; include server-rendered view formats (`.cshtml`,
  `.razor`, `.erb`, `.hbs`, `.ejs`, `.jinja2`, `.twig`) and `.html`.

**The dangerous-API pattern.** This is what promotes ordinary `app-source` into the floor. The
question it asks is "could this file contain an exploitable defect", and every alternative
should map to an OWASP category the methodology already analyses:

- command or code execution
- raw SQL construction
- unescaped output
- unsafe deserialization
- weak or disabled crypto, and disabled certificate validation
- path handling from caller-controlled input
- authorization annotations and privilege checks

Keep it **deliberately narrower than "any source file."** Every source file could in principle
hold a defect, and a floor that says so is a floor of hundreds -- the unmeetable floor that
was discarded wholesale in the field.

**File-type-aware sinks -- the most important rule in this file.**

The default pattern assumes a general-purpose language, where finding raw SQL or raw HTML
output is itself the signal. Inside a file whose ENTIRE PURPOSE is SQL or HTML, the same match
means nothing: it is the language, not a risk.

Measured on a real 1,479-file application, a general `SELECT ... FROM` alternative put 378 of
380 `.sql` files into the must-read floor -- a floor of 567 against a per-worker capacity of
60. The audit could not run, and every one of those matches was a stored procedure containing
SQL.

So for such extensions the default is **REPLACED, not extended**. For `.sql`, what matters is:
SQL built as a string, reach outside the database, privilege change, and weak crypto. For
server-rendered views, what matters is output written without escaping.

Hold these as NAMED GROUPS rather than one merged string, so a match can be ATTRIBUTED. A
single pattern can only report that a file is in the floor; it cannot say which idea put it
there, and without that the only way to tune an over-matching rule is to guess and re-measure.

One narrowing worth stating explicitly, because the obvious version is wrong: **do not floor
on a bare `GRANT`.** Shipping a stored procedure alongside `GRANT EXECUTE ON dbo.P TO AppRole`
is how a SQL Server database is SUPPOSED to be wired -- the permission is the deployment, not
a defect, and a rule matching it carries no information. What is worth reading in any codebase
is: a grant to a broad principal (public, guest, everyone); a grant of a sweeping permission
(ALL, CONTROL, ALTER ANY, IMPERSONATE, TAKE OWNERSHIP, UNSAFE ASSEMBLY, EXTERNAL ACCESS);
delegation via `WITH GRANT OPTION`; impersonation of a named principal; and server- or
database-role escalation. That is a security statement that stands on its own, not an
accommodation of one codebase's convention.

**Exports.** The consumers need: a function returning a file's class; the floor-class set; a
function testing auditability; and a function returning WHICH named sink group matched, for
attribution. Memoize the sink test -- both consumers call it over the same files.

**Verification.** Run the classifier over this repository's manifest and print a count per
class, plus the floor size per floor class. Then apply 5.3.

---

### S-2. manifest.ps1

**Role.** Builds `audit_state/00-file-manifest.txt`: the complete list of SOURCE FILES under
audit. Phase 2 partitions this list; Phase 3A/4A workers audit the files in their partition.

**Output.** One workspace-relative path per line, forward slashes, sorted.

**Excludes.** `.git`, and `audit_state/` itself. Everything else is decided by
`lib-classify.ps1` -- do not write a second exclusion list here. A file whose class is
`excluded` or `$null` does not belong in the manifest.

**Prints.** The total count, and a count per class. That total is the denominator every later
coverage number is computed against, so it is computed here and never estimated afterwards.

---

### S-3. init-workspace.ps1

**Role.** Phase 1 bootstrap in ONE call. It exists so that multi-line inline PowerShell stays
out of the phase files -- inline blocks are a quoting minefield when the agent's shell is bash
(Git Bash), which is common.md rule S.

**Parameters.** Differs from the common preamble:

    [string]$Workspace = (Get-Location).Path
    [string]$ProjectName
    [ValidateSet('COORDINATED','STANDALONE')][string]$Mode = 'STANDALONE'
    [string]$ExecutorModel = 'unknown'

`-Workspace` defaulting to the current directory is the ONE place the run may derive it rather
than be told it. `-ExecutorModel` is self-reported by the agent; a recorded `unknown` is more
useful than a wrong guess, which is why that is the default.

**Does, in order, printing each step:**
1. Derive and print the literal values: WORKSPACE, PROJECT_NAME, audit_state path, timestamp.
2. Validate the workspace exists and is a directory; exit 1 with a clear message if not.
3. Create `audit_state/` and its subdirectories, including `audit_state/workers/` and
   `audit_state/partitions/`. Idempotent.
4. Add git excludes to `.git/info/exclude` -- the repo-local, uncommitted file, never
   `.gitignore`, which at a regulated organisation may require code review to change. Use a
   WILDCARD covering `audit_state*`. Skip with a printed note if `.git` is absent.
5. Prior-audit acknowledgment check: look for an existing `audit_state/` or archived audit
   directories and report what was found, so a re-run is a decision rather than an accident.
6. Initialise `STATE.md` with all phases `pending`, recording PROJECT_NAME, WORKSPACE, Mode
   and ExecutorModel. Use the schema in SKILL.md -- do not invent one.
7. Print a top-level repo map to depth 2 with sizes.

---

### S-4. partition-plan.ps1

**Role.** Proposes the Phase 2 partition plan: orders every auditable file into one bucket,
cuts it into subagent-sized slices, writes a machine-readable file list per slice, and seeds
`partition_status.md`.

**Parameters** (beyond the common two):

    [ValidateRange(1,10)][int]$MaxParallel = 10
    [int]$SliceKB    = 300
    [int]$SliceFiles = 40
    [int]$MaxFileKB  = 120

**`-MaxParallel` is how many subagents run AT ONCE.** It is not a cap on the work. A repository
needing 15 slices gets 15, dispatched in waves of this size. This number is about parallelism
and nothing else; letting it decide how the work is divided is precisely the mistake this
script must not make.

**`-SliceKB` is an ESTIMATE of what one subagent can get through, not a guarantee.** A worker
that runs out reports where it stopped, and the remainder is re-sliced.

It was 500 KB and that was too aggressive -- a field run hit "parser aborted (timeout,
resource-limit, or over-length)". 500 KB is about 125K tokens of source; add ~15K of
instructions and it leaves under 60K for reading comprehension, reasoning, thinking tokens,
and writing findings, in a 200K window. The derivation for 300:

        200,000  window
        -15,000  instructions and worker context
        -75,000  source at 300 KB
        =110,000 for reasoning, thinking, and findings

Erring small is nearly free: an extra slice is an extra subagent in a wave that already runs
ten at a time. Erring large costs the whole worker.

**`-MaxFileKB`** is a file that cannot be read whole by a worker with room left to think. No
slicing fixes it, because slices divide BETWEEN files and never within one. FLAG such files
explicitly rather than silently packing them -- a worker that aborts mid-file produces no
finding and no error, which is the worst of both.

**Weighting.** Size partitions by auditable source only, using `lib-classify.ps1`'s definition
-- the same definition the read floor is later verified against. Do not weight by raw file
count or raw bytes.

**Outputs.**
- `audit_state/partitions/<partition_id>.txt` -- one file path per line, per slice.
- `audit_state/partition_plan.md` -- the human-readable plan: per partition, its id, file
  count, total KB, and the roots it covers.
- `audit_state/partition_status.md` -- seeded with every partition marked pending.

**Prints** a reconciliation: total auditable files, total sliced, and the difference. The
difference must be zero. Exit 1 if it is not -- a file that is in the manifest and in no
partition is a file nobody audits, and nothing downstream detects it.

**Ends by printing** the next command to run: `readplan.ps1`, to compute each worker's read
floor before anyone is dispatched.

---

### S-5. readplan.ps1

**Role.** Computes the PER-PARTITION READ FLOOR for a Phase 3A/4A worker and, in `-Verify`
mode, reconciles that floor against what the worker's harness transcript shows it actually
read.

**Parameters** (beyond the common two):

    [string]$PartitionId
    [switch]$Verify
    [switch]$Quiet
    [int]$FloorPerWorker    = 60
    [int]$FloorKBPerWorker  = 500
    [int]$BulkClassThreshold = 40
    [string]$TranscriptRoot = (Join-Path $env:USERPROFILE '.claude\projects')

**The floor is sized to be MEETABLE, deliberately.** Twice in the field a mandatory floor was
set so high that the audit could not run, and the floor was then abandoned wholesale -- which
is worse than a smaller floor honoured. Three mechanisms keep it meetable:

- (a) Role classes carry the floor. Ordinary application source enters only where a
  dangerous-API pattern actually matched, so the floor tracks the partition's real defect
  surface rather than its file count.
- (b) Any floor class above `-BulkClassThreshold` files is signal-filtered rather than taken
  whole.
- (c) If the floor STILL exceeds `-FloorPerWorker`, do NOT print a bigger number. Emit
  **SPLIT REQUIRED** naming the partition, so the partition is re-cut instead of the floor
  being quietly exceeded.

**`-FloorKBPerWorker` is the same claim in the unit that actually binds.** Derived against a
200,000-token window:

        200,000  context window
        -14,700  worker instructions (measured: common + global-rules + schemas
                 + tool-usage + phase-3a)
         -2,000  worker_context, partition list, readset
        -45,000  reserve for reasoning, findings, and the excluded ledger
        =138,000 tokens for source  ~=  550 KB at ~4 bytes/token

Held at 500 KB for headroom. Raise it only alongside a larger window. If the reserve ever
proves too small, the symptom is truncated findings rather than a refusal to read.

**`-Quiet`** collapses the per-partition class table to one line each. Every line this prints
lands in the ORCHESTRATOR's context, and the orchestrator has to survive the whole run; at 22
slices the full tables are roughly 250 lines of detail it never acts on. A field run exhausted
the orchestrator mid-audit. The detail is not lost -- it is in the readset files on disk.

**Outputs**, per partition: `<partition_id>.readset.txt` (the floor) and
`<partition_id>.readset-deferred.txt` (auditable but not floored, each line carrying a
mechanical reason).

**`-Verify` mode.** Read the harness transcript under `-TranscriptRoot` for this run, extract
the files the worker actually read, and diff against the floor. Print the floor size, the read
count, coverage as a percentage, then `UNREAD:` and every unread floor file, complete and
untruncated. Close with exactly one line: `VERDICT: COMPLETE` or
`VERDICT: INCOMPLETE (<n> unread)`. Exit 1 on INCOMPLETE.

If the transcript cannot be found or parsed, say so and exit 1. Do not treat an unreadable
transcript as a pass.

---

### S-6. merge-findings.ps1

**Role.** Assembles the GLOBAL `audit_state/findings_registry.md`, `attack_paths.md` and
`evidence_index.md` from every `audit_state/workers/<partition_id>/` directory, then computes
the counts GATE 2 reports.

**Inputs.** Each worker directory's own findings, attack paths and evidence files. Follow the
schemas in `references/schemas.md` -- that file is authoritative for every field, and you have
it verbatim in PART A.

**Behaviour.**
- Concatenate, preserving each finding's originating partition id.
- Do not renumber here. Workers hold disjoint id blocks precisely so they cannot collide;
  renumbering is S-9's job and happens after GATE 2.
- Detect duplicates ACROSS partitions and record them rather than deleting them -- a finding
  present in two partitions is a fact about the system.
- Recognise the closed exclusion vocabulary when tallying excluded findings:
  `Precondition not reachable`, `Below severity floor`, `Fully mitigated`,
  `Duplicate of F-NNN`.

**Prints** the counts GATE 2 needs: total findings, by severity, by partition, and excluded by
reason. Computed, never estimated.

**Exit 1** if any worker directory named in `partition_status.md` is missing or empty. A
partition that produced nothing is either a failed worker or a genuinely clean partition, and
the difference must be a decision rather than a silence.

---

### S-7. apply-dispositions.ps1

**Role.** Applies the owner's GATE 2 decisions from `gate2_progress.md` to
`findings_registry.md`.

**Parameter.** Adds `[switch]$WhatIf` -- report what would change and write nothing. Run this
first, and say so in the output of the real run.

**Why it exists.** The owner's answers land in `gate2_progress.md`, which is durable and
written first by design. But `renumber-findings.ps1` and Phase 5 read `status:` from the
REGISTRY -- so a rejection has to reach the registry or the report will not know it was
suppressed. In a field run, faced with 24 findings and a manual approval per edit, the running
agent wrote itself an `apply_disposition.py`: unreviewed code, in a language nothing else in
the toolchain used, to do a job that belongs in a reviewed script. This is that script.

**Behaviour.** For each decision in `gate2_progress.md`, set the corresponding finding's
`status:` in the registry. Match on finding id. Report every decision that matched no finding
and every finding that received no decision -- both are real conditions and neither should be
silent. Exit 1 if the two files disagree about which findings exist.

---

### S-8. score-judge.ps1

**Role.** Scores the judge's rulings against the owner's own GATE 2 decisions.

**Why it exists.** The owner wants to stop reviewing every finding before forwarding it to a
development team, but he cannot simply DECIDE to trust the judge -- he has to find out whether
it earned trust. This turns that into a measurement instead of a leap. He reviews as normal;
`gate2_progress.md` records what he decided; this compares the two.

**Behaviour.** Join the judge's ruling and the owner's decision per finding. Report agreement
count and rate, and disagreements **by direction** -- separately counting the judge accepting
what the owner rejected, and the judge rejecting what the owner accepted. The direction is the
whole point: those two errors have very different costs, and a single accuracy figure hides
which one is happening.

List every disagreement with its finding id and both verdicts. Exit 0 regardless -- this is a
measurement, not a gate.

---

### S-9. renumber-findings.ps1

**Role.** Renumbers findings into one contiguous `F-001..F-NNN` sequence for the final report.

**Parameters.** Adds `[switch]$WhatIf` and `[switch]$ExcludeSuppressed`.

**Why.** Workers are given disjoint id blocks so they cannot collide while running in
parallel, which means the merged registry reads `F-001, F-021, F-041, F-101, F-250...`. A
reader cannot tell whether the gaps mean findings were removed, lost, or never existed -- and
it invites exactly that question of every report.

**Behaviour.** Suppressed findings KEEP their place in the sequence by default, so a reader of
the GATE 2 log can still find them. `-ExcludeSuppressed` numbers only the survivors.

Renumber consistently across every file that carries a finding id -- the registry, the attack
paths, the evidence index, and any cross-reference of the form `Duplicate of F-NNN`. **A
renumber that updates the registry alone silently breaks every cross-reference**, so verify
afterwards that no stale id remains anywhere, and report the count of references rewritten per
file.

---

### S-10. verify-deliverables.ps1

**Role.** Checks that Phase 5's deliverables actually contain every finding the registry
holds.

**Why it exists.** The methodology states plainly that the consolidated report MUST include
every finding from `findings_registry.md`, and that selecting which to include is filtering
and is wrong. It also documents the failure that rule exists to prevent: an agent reads a
registry of N findings, writes planning prose, exhausts its per-response output budget
mid-report, and produces a summarised findings list instead of a complete one. The findings
that fall off the end leave no trace in the report that they ever existed.

**Behaviour.** Extract every finding id from the registry. Extract every finding id present in
each Phase 5 deliverable. Report per deliverable: registry count, deliverable count, and every
MISSING id by name.

Exit 1 if any deliverable is missing any finding. **A summarised report is a FAILURE, not a
stylistic choice** -- that is the entire point of this script.


## Appendix D -- what this rebuild does and does not give you

Report this to the user on completion.

**What it gives you.** The skill as it stood at `v2-skill (2026-08-14)`: all 15 reference
files verbatim, and ten scripts written to their contracts.

**Where the risk sits.** Not in the reference files -- those are byte-for-byte. It sits in the
scripts, and unevenly:

- `lib-classify.ps1` is the one to watch. Its rules are principled and stated as principles
  here, but the ORIGINAL constants were arrived at by measuring against real repositories.
  Yours are new. Section 5.3 exists for exactly this reason, and its output is the evidence
  that your classifier is sane. Do not skip it, and do not report the rebuild complete without
  its numbers.
- `partition-plan.ps1` and `readplan.ps1` carry window-derived constants. If the model running
  the workers does not have a 200,000-token window, those numbers are wrong and section 5.3
  says how to redo them.
- The remaining seven are mechanical: their contracts fully determine them.

**What is NOT included.** `install.ps1` and `install.sh` from the original skill -- this
rebuild produces a tracked source tree and performs no installation, so they have no job here.
The archived monolith is also not used, for the reason given in section 0.
