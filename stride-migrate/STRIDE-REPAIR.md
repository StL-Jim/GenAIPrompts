# STRIDE skill repair -- one pass

Part 1 is what to do, in order. Parts 2 and 3 are material Part 1 refers to. Part 4 is how
you prove it worked.

DO NOT CONSULT THE MONOLITH PROMPT for anything in this file, even for context. The skill
was built by reconstructing files from that monolith, and reconstructing from it is the
defect being corrected here. Every file you need is in Part 2.

## Part 1 -- do this, in order

### Step 1 -- replace five files, verbatim

Part 2 contains five complete files. Write each to the path in its BEGIN marker, overwriting
what is there. Content exactly as given, between the markers; the markers are not part of any
file. Do not reformat, re-wrap, merge with the existing version, or preserve anything from it.

    references/common.md
    references/phase-0.md
    references/phase-0-discovery.md
    references/phase-2c.md
    references/phase-4.md

**Then make two edits to `phase-0.md` only.** These files come from a skill whose Phase 1 runs
as three parallel agents over a partitioned file manifest. This skill runs Phase 1 as ONE
agent, so two scripts that version depends on do not exist here. The other four files need no
such edits -- every script they name either exists or is built by Step 2 or Step 3.

1. **`partition-manifest.ps1`** -- one reference, in the last step of the file, telling the
   orchestrator to build the Phase 1 partition manifest after the Scope Proposal is approved.
   Delete that instruction. There is nothing to partition: Phase 1 is dispatched as a single
   agent that runs passes 1A, 1B and 1C in order.
2. **`archive-compare.ps1`** -- one reference, inside step 7.7. **Delete only PART 2 of that
   step, never the whole step.** Step 7.7 has two parts and they have different fates:

   - **Part 1 writes `00-resources.txt` and MUST SURVIVE.** Step 8 depends on it and says so
     out loud -- "already written in step 7.7". Delete the whole step and you break Phase 0's
     scope note, which is a worse defect than the one you were fixing.
   - **Part 2 is the archive comparison.** It runs `archive-compare.ps1`, which this build
     does not have, and on a first run there is no archived run to compare against. Delete
     Part 2 in full: the prose, the PowerShell block, the `00-archive-comparison.md` write,
     and the paragraph about the "in prior, not in current" set.

   Then reword what is left so it still reads: retitle 7.7 to name only the resource-list
   write, drop the now-orphaned "Part 1 (always):" prefix, and fix two references the deletion
   strands -- step 8's phrase "before the archive comparison that step performs against it",
   and the `Archive comparison:` line in the Scope Proposal banner. Grep for `archive` in
   `phase-0.md` afterwards; the only survivors should be the archived-run rules that have
   nothing to do with the deleted script.

Delete the surrounding instruction, not just the script name -- a step that says "run the
comparison and write up the four sets" is not repaired by removing the word it invokes.

`common.md` mentions `00-archive-comparison.md` once, in its output-directory listing, marked
"when one exists". That is a conditional entry in a listing, not an invocation. Leave it.

### Step 1b -- add two blocks to `references/phase-1.md`

`phase-1.md` was produced by merging what the real skill splits across five files, so it
cannot be drop-in replaced. Two self-contained blocks were lost in that merge and are added
back here verbatim. Both are methodology, not plumbing.

**Block 1 -- Element Classification.** Insert immediately BEFORE the `### Phase 1A` heading,
because it binds all three passes. The real file says why it is reproduced rather than
referenced: *"a partial-pass agent never reads phase-1-reconcile.md."* Without it, Phase 1
decides component granularity, the DS-vs-EXT test and the secrets convergence rule by
improvisation, and the three passes converge on nothing.

```
## Element Classification (binding on all Phase 1 passes)

These definitions are reproduced here in full, not left as a pointer, because a
partial-pass agent never reads phase-1-reconcile.md. The reconciliation agent later
expands these same fields into that file's Section 1/2/3/4/5 inventory schema and
assigns IDs -- classifying against this copy is what keeps partial records merging
cleanly at reconciliation.

### Component definition

This is the MASTER inventory of architectural elements, and it directly gates threat coverage: Phase 2B walks STRIDE per component, so any element absent here is never threat-modeled. DEFINITION -- every architectural element that PROCESSES, STORES, or MEDIATES this system's data is a component: it gets a C-NNN ID and a Phase 2 STRIDE walk. This explicitly includes data stores, cloud/AWS managed services (S3, DynamoDB, Bedrock, SQS, ...), queues, caches, gateways, and identity providers -- NOT only active-process services. Do NOT undercount by treating data stores or managed services as a lower tier: the Data Stores and External Integrations sections are supplementary attribute detail about elements that ALSO appear as components, keyed to the same C-NNN -- every data store or integration MUST also be recorded as a component. Each architectural element appears exactly once (one C-NNN) and is walked once in Phase 2. (This definition is load-bearing: undercounting components is the single largest cause of incomplete threat enumeration -- a narrow "active-process only" reading has produced 3-4 components where the correct reading produces ~12-13 on the same system.)

### Component granularity rule (parallel-partition convergence)

Because Phase 1 runs as three PARALLEL partition agents, two partitions can classify
the same code at different granularity -- e.g., the docs partition inferring one
component per source file, while the source partition groups those same files as one
component. Apply this rule so partitions converge without needing an adjudicator:
multiple source modules/files that run inside the SAME deployable unit (one process /
one container / one Lambda) and share one entry-point boundary are ONE component, not
several. Split into separate components only when a module is independently
deployable or has its own distinct entry point (its own HTTP listener, its own
scheduled trigger, its own service manifest). In-process middleware and helpers (auth
filters, storage clients, validators) are part of the component they run in --
recorded via that component's Dependencies and Responsibilities fields, not as their
own component. (This is consistent with the Component definition above, which keys on
deployable/entry-pointed architectural elements; it makes explicit what the
sequential single-agent design left implicit, since one agent deciding alone never
hit this disagreement.)

### DS-vs-EXT test (including the fetch trap)

DS-vs-EXT TEST (apply it -- do not bin by feel; misclassification is a field-observed failure). Ask ONE question: WHO OPERATES IT? If this system operates the store and its CONTENT belongs to this system, it is a DATA STORE -- even on managed infrastructure (an S3 bucket or DynamoDB table this app owns on AWS is DS). If ANOTHER PARTY operates it and this system is a CLIENT reaching across the network to it, it is an EXTERNAL INTEGRATION -- even if what you do with it is purely read data. THE FETCH TRAP (the exact field failure): a website or API this system SCRAPES or FETCHES FROM (sec.gov, a partner feed, any remote source ingested into a KB or cache) is an EXTERNAL INTEGRATION, never a data store, no matter how one-way or read-only it feels. "We just pull data from it" describes the DIRECTION of a data flow (outbound fetch), not the CATEGORY of the element -- direction is an EXT attribute, not a reason to call it a store. Binning a fetched-from source as a data store is a security error, not a labeling nit: it erases the ingestion CHANNEL from the threat walk, and that channel is where TLS-verification, source-spoofing, and content-poisoning threats live -- for a RAG/KB system, remote-content-into-the-knowledge-base is the marquee threat surface. The fetched data landing somewhere (the KB, a staging bucket) IS a data store -- a SEPARATE element this system owns; record BOTH the external source (EXT) and the landing store (DS), joined by a data flow. When a single element genuinely seems both (a partner-operated store this system writes into), classify as External Integration.

### Attribute fields per element class

Populate these fields for each element you record (omit the ID line -- reconciliation assigns IDs).

Component:
- Type: (web-app | api-service | worker | database | cache | queue | managed-service | gateway | identity-provider | external-saas | cli | job | lambda | frontend-spa | ...)
- Language/Framework:
- Evidence: [evidence: path/to/main.go:1-40]
- Responsibilities:
- Entry points:
- Dependencies (other components): [canonical names -- reconciliation converts these to C-NNN IDs]
- Data handled: (PII | credentials | financial | health | telemetry | public | ...)
- Runs as: (user/service account, container, lambda, ...)

Data store:
- Type: (postgresql | mysql | redis | dynamodb | s3 | elasticsearch | secrets-manager | filesystem | ...)
- Data classification: (PII | credentials | financial | health | telemetry | public | ...)
- Encryption at rest: (yes | no | unknown) -- cite IaC evidence
- Encryption in transit: (yes | no | unknown) -- cite evidence
- Access pattern: which components read/write, e.g. `read-write from C-003, read-only from C-005`
- Evidence: [evidence: terraform/rds.tf:1-30]

External integration:
- Protocol: (HTTPS | gRPC | AMQP | SMTP | TCP | ...)
- Authentication method: (API key | OAuth client credentials | mTLS | bearer token | basic auth | none | ...)
- Direction: (inbound | outbound | both)
- Data exchanged: (brief description and classification)
- Evidence: [evidence: src/clients/payment_gateway.go:12-44]

Trust boundary evidence:
- Type: (Internet -> edge (WAF/LB/CDN) | edge -> application tier | application
  tier -> data tier | application -> external SaaS | privileged admin plane vs.
  user plane | tenant boundary (if multi-tenant) | build/deploy plane vs.
  runtime plane | ...) -- a trust boundary exists wherever data crosses between
  principals with different trust levels; at minimum consider these crossings,
  and add others found
- Boundary: (what is on each side of the crossing -- the principals, tiers, or
  systems involved)
- Establishing control: (the control that establishes the boundary, e.g. the
  Terraform security group, the k8s NetworkPolicy) -- or, if none exists, state
  the absence explicitly
- Evidence: [evidence: path/to/terraform/security_group.tf:1-20]

Documentation artifact:
- Path:
- Type: (design-doc | readme | adr | openapi | api-contract | diagram | other)
- Key architectural assertions: (components, protocols, data stores, and
  integrations named in the artifact)
- Date: (if available)
- Evidence: [evidence: docs/architecture.md]

### Secrets and credentials (NOT a separate element class -- convergence rule)
A secret, credential, key, or token surface (an API key, a shared auth secret, a
cloud access key, a DB password, a bearer/session token) is NEVER its own element
and NEVER gets a C-NNN/DS-NNN. Parallel partitions must handle these identically or
they diverge (one agent componentizes a key, another folds it in -- a field-observed
split). The rule: record each secret surface as a `Secrets referenced:` line on the
component, data store, or trust-boundary-evidence element that OWNS, HOLDS, or USES it,
naming the secret by its concrete identity with evidence (e.g. `Secrets referenced:
AUTH_SECRET (shared static bearer secret) [evidence: services/api/auth.py:1]`). List
every secret surface this way -- do not drop it and do not promote it to an element.
The reconciliation agent keeps these attributes on their owning elements; Phase 2A's
Secrets asset floor enumerates them from there, so a secret that is never listed on any
element silently vanishes from the threat model.
```

**Block 2 -- attested in-path elements.** Insert into the `## 2. Components` section. Without
it, a WAF or API gateway the user attested in Phase 0 Q3/Q6a never becomes a component, so
the path from the edge to the application has a hole in it and no data flow crosses the
control that is actually there.

```
ATTESTED IN-PATH ELEMENTS ARE COMPONENTS -- FROM Q3 AS WELL AS Q6a. Read BOTH Phase 0 answers in 00-scope.md, because the element you are looking for is more likely to be in Q3 than in Q6a.

Q3 asks "list any mitigating controls already in place (WAF, API gateway, CDN, IDS/IPS, MFA, etc.)" -- WAF is its FIRST example and its sample answer is a WAF vendor. So a user naming their WAF answers Q3, correctly. If the component rule reads only Q6a, that WAF is filed as a CONTROL, never becomes an element, and can never be drawn: field-reported symptom, an Akamai WAF absent from every diagram because it was named in the mitigating-controls answer rather than the platform-path answer.

THE TEST IS WHETHER IT SITS IN THE DATA PATH, not which question named it:
- IN PATH -- traffic flows THROUGH it: WAF, CDN, API gateway, reverse proxy, load balancer, ingress controller, service mesh gateway. These MEDIATE this system's data, so they meet the component definition above and get a C-NNN.
- NOT IN PATH -- gates or observes without being a hop: MFA, IDS/IPS, SIEM, EDR, vulnerability scanners. These stay controls only and get no C-NNN.

BEING A COMPONENT DOES NOT MAKE IT A VERIFIED MITIGATION. These are three separate roles and collapsing them is the error to avoid. An attested WAF is simultaneously: an element on the map (drawn, its flows and boundaries visible); an attested control (renders in SecurityControl as `Attested -- <control> (unverified in code)`); and NOT a basis for a `Fully mitigated` exclusion, per Operating Rule 2's attestation asymmetry. Adding it to the inventory changes what the diagrams can show. It changes nothing about what threats may be suppressed.

When Phase 0 Q6a recorded a platform traffic path -- e.g. "Akamai WAF -> reverse proxy -> app container; TLS terminates at the proxy" -- every element NAMED in that path (the WAF, the ingress/reverse proxy, the load balancer) MEDIATES this system's data and therefore meets the component definition above. Each gets a C-NNN, with `Evidence: [evidence: user-attested, Phase 0 Q6a]`.

These elements are absent from the repository BY CONSTRUCTION -- they are platform, not application code -- so no amount of file reading in Phase 1 will ever discover them. Without this rule they never enter the inventory, never reach a diagram, and the path from the user to the application has a hole in the middle exactly where the security controls sit. Field symptom: a container diagram showing neither the WAF nor the ingress, so the attested plaintext hop between proxy and container -- a threat the model DID emit -- had no visible endpoints to connect.
```

**Block 3 -- resolve the `A-<NNN>` ID collision.** The source skill assigns `A-<NNN>` to BOTH
Actors (Section 4a) and Assumptions (Section 6). That is a live ambiguity, not a cosmetic one:
Phase 2B's ThreatAgent privilege suffix has to resolve to an ACTOR, and a reference to `A-003`
cannot be resolved when assumptions share the space. A Phase 1 agent hit this in a real run and
had to invent a resolution mid-phase.

After inserting Block 1, edit `phase-1.md` so the two ID spaces are distinct:

- Actors (Section 4a) keep `A-<NNN>`. Phase 2B depends on that prefix.
- Assumptions (Section 6) become `ASM-<NNN>`. Change the sentence that assigns them, and
  every example ID in that section.

State the rule once, near the top of the Architectural Inventory schema, so later phases can
rely on it: `A-NNN is an ACTOR. ASM-NNN is an ASSUMPTION. The two never share a number space.`

This is a deliberate divergence from the shipped skill, which carries the collision. It is
taken because the ambiguity is load-bearing for Phase 2B rather than merely untidy.

Verify all three: grep `phase-1.md` for `## Element Classification` and for `ATTESTED IN-PATH`
-- each must return exactly one hit -- and confirm that Section 6's assumptions use `ASM-`
while Section 4a's actors use `A-`.


### Step 2 -- rebuild sweep.ps1 and readset.ps1 to the contract below

Both scripts already exist and BOTH ARE WRONG. They were written to a specification that does
not match what `phase-0-discovery.md` actually reads. Overwrite them.

#### scripts/sweep.ps1

Phase 0's Pass 2 mechanical sweep. Parameters: the usual `-Workspace` and `-ProjectName`, plus
`-MaxFileKB` (default 1024, skip any file larger), `-SaturationCap` (default 2000, a pattern
with more matches than this is flagged SATURATED) and `-CandidateCap` (default 1000, the most
matched lines per pattern fed into candidate extraction).

It reads `00-file-manifest.txt` and must FAIL LOUDLY if that file is absent, naming
`manifest.ps1` as the thing to run first. Sweeping nothing silently is the failure to avoid.

Stream matches; do not accumulate every match object in memory, or a large repository
exhausts it. Print ONE progress line per pattern as it completes -- the pattern, its match
count, elapsed seconds, and `SATURATED` where the count exceeds the cap. That is the
orchestrator's only visibility into Phase 0's long pole.

It writes FIVE files, and every one of them is read by `phase-0-discovery.md`:

- **`00-discovery-raw.txt`** -- every match site, `path:line: text`, sorted.
- **`00-density.txt`** -- every signal-bearing file as `count TAB class TAB path`, ranked by
  count descending. `class` is `app` or `vendor`.
- **`00-density-app.txt`** -- the application-only ranking, `count TAB path`. **This is the one
  the agent reads from, and Pass 1 must account for every file in it.**

  The classification is the point. A raw ranking is dominated by third-party libraries that
  happen to be full of URLs -- field-observed, an entire top-10 was vendor code, so the
  "read the top files" step spent its whole budget on noise. Classify mechanically so the
  agent never decides it mid-read: a file is `vendor` if its PATH contains a segment like
  `lib`, `libs`, `vendor`, `third-party`, `external`, `packages`, `bower_components`,
  `dist`, `build`, `out`, `obj`, `bin`, `coverage`, `.next`, `.nuxt`, or a vendored-asset
  path such as `wwwroot/lib` or `assets/vendor`; OR if its FILENAME starts with a well-known
  library name (jquery, bootstrap, angular, react, vue, lodash, moment, d3, tinymce,
  highcharts, datatables, select2 and similar) or carries a bundling suffix
  (`.bundle.`, `.vendor.`, `.chunk.`, `.polyfills.`, `.runtime.`). Everything else is `app`.
- **`00-candidates.txt`** -- distinct extracted candidate strings, sorted. Feed each matched
  line (up to the cap) through the pattern's own matches plus quoted strings of 3-80
  characters and assignment right-hand sides.
- **`00-hosts.txt`** -- `count TAB host` for every distinct host/endpoint the sweep saw,
  ranked. **Complete by construction, so nobody ever greps the raw file for "the interesting
  hosts"** -- such a grep invariably gets capped (a field run capped at 30), turning a
  truncated DISPLAY into truncated DATA, and a hand-written filter can only find hosts you
  already thought to name.

  Keep the FIRST PATH SEGMENT, not just the host. On a multi-service domain the path IS the
  service identity: `www.bing.com` reads like a link to a search engine, while
  `www.bing.com/maps` is unmistakably a maps integration -- and a field run missed exactly
  that because the host list threw the path away. Same for `www.google.com/recaptcha` and
  `login.microsoftonline.com/.../oauth2`. Skip a segment that looks like a file (has a short
  extension), is templated (`{`, `$`, `@`, `<`), or exceeds 40 characters. Extract hosts both
  from URLs and from bare domain names ending in a common TLD.

Also write `00-resources.txt`, the distinct resource list as `type TAB name`, which Phase 0's
scope note consumes.

Print a summary line for each artifact with its computed count.

#### scripts/readset.ps1

Computes Phase 0 Pass 1's mandatory read floor, and in `-Verify` mode reconciles it against
what the agent logged reading. Parameters: `-Workspace`, `-ProjectName`, `-Verify`, and
`-BulkClassThreshold` (default 40).

Reads `00-file-manifest.txt`; fail loudly naming `manifest.ps1` if it is absent.

**Skip agent tooling scratch before classifying anything.** A file whose path starts with
`.claude/`, `.superpowers/`, `.vscode/`, `.idea/` or `.husky/` is excluded outright -- it is
never classified, never floored, never counted against coverage. `.github` is deliberately NOT
excluded; workflow definitions are genuine config evidence.

This is not hypothetical. Running the rebuilt classifier against two real repositories put
`.superpowers/brainstorm/.../state/server.pid` into the floor as an `entrypoint` (the path
contains "server") and `.claude/settings.local.json` into it as `config-env`. Both are a local
agent tool's working files, not the application under assessment, and each one displaces a
real source file from a floor deliberately sized to be only just meetable. The partner code
audit's classifier carries this same exclusion, added after the identical failure.

Then classify every remaining manifest file into exactly one class, FIRST MATCH WINS, in this
order:

    dependency    manifests: *.csproj, package.json, requirements*.txt, pom.xml, go.mod,
                  Gemfile, composer.json, Cargo.toml, build.gradle, pyproject.toml
    docs          *.md, *.rst, *.adoc; docs/ and documentation/ directories; and the
                  names README*, ARCHITECTURE*, DESIGN*, SECURITY*, THREAT*,
                  CONTRIBUTING*, CHANGELOG*. NOT *.txt -- an extension is not a role,
                  the same way a directory name is not. On one real repository .txt
                  meant chart DATA and put 175 planet tables into the mandatory read
                  floor, which docs is never signal-filtered out of.
    client-view   view/template file extensions (.cshtml .razor .erb .hbs .ejs .jinja2
                  .html and similar)
    entrypoint    main/app/index/server/program/startup/wsgi/asgi/bootstrap/entrypoint
                  filenames, serverless handlers, and routing vocabulary (controller,
                  route, router, endpoint, api, handler, resolver, graphql, grpc, webhook,
                  consumer, listener, worker, scheduler, cron, job, task, cli, cmd)
    config-env    dotenv, appsettings*.json, config/settings directories, *.tf, *.tfvars,
                  values*.yaml, Dockerfile, docker-compose*, .github/workflows,
                  .gitlab-ci.yml, Jenkinsfile, *.properties, web.config, app.config
    auth          auth, oauth, oidc, saml, sso, login, token, jwt, session, identity,
                  principal, permission, policy, guard, middleware, rbac, acl, claims,
                  password, credential, crypto, cipher, hash, kms, vault, secret
    ext-client    client, gateway, adapter, connector, integration, proxy, outbound,
                  external, thirdparty, sdk, httpclient, rest, soap, feign
    client-view   by path this time (views/, templates/, pages/, components/)
    app-source    any remaining recognised source extension
    (nothing)     data, assets and binaries -- outside the read set entirely

**The floor is these six classes:** `entrypoint`, `config-env`, `auth`, `ext-client`,
`dependency`, `docs`. `app-source` and `client-view` are NOT in the floor -- they are
sweep-covered, read mechanically by Pass 2.

**Signal filtering, and its exact scope.** A class in the floor with more than
`-BulkClassThreshold` members is thinned: keep only files containing an external-reference
signal (a URL scheme, a script/iframe/embed src, fetch/axios/XMLHttpRequest/ajax, an
integrity attribute, HttpClient/WebClient/RestClient/RestSharp, a client construction, a
connection string, an environment-variable read, ConfigurationManager/IConfiguration/
AppSettings, an `arn:aws`, or an endpoint-shaped variable name such as `_URL`, `_HOST`,
`_ENDPOINT`, `_BUCKET`, `_TABLE`, `_QUEUE`, `_TOPIC`).

**Filter ONLY `auth` and `ext-client`.** This is not an arbitrary restriction:

- `docs` and `dependency` are in the floor PRECISELY BECAUSE a pattern cannot see their
  contents. A prose sentence ("integrates with the Acme Payments API") and a
  `<PackageReference>` line carry no scheme, host or client construction, so the filter does
  not thin those classes -- it deletes almost all of them, silently, because `-Verify` then
  measures against the post-filter floor and reports COMPLETE. A monitoring vendor was missed
  in the field for exactly this reason.
- `entrypoint` and `config-env` are never filtered: an entry point or a config file matters
  whether or not it contains a URL.
- `app-source` and `client-view` are not in the floor at all, so filtering them is wasted work
  that also pollutes the deferred list with files that were never in the floor.

Accept the consequence: on a docs-heavy repository the floor is larger and honest, where
before it was small and wrong.

If a file cannot be read to test it, KEEP it in the floor -- err toward reading.

Default mode writes three files:

- **`00-readset.txt`** -- the floor, `class TAB path`, sorted.
- **`00-readset-deferred.txt`** -- floor-class files dropped by the signal filter, with their
  class. They are accounted for, not dropped; the agent reads any the sweep later flags.
- **`00-readset-sweep-covered.txt`** -- the `app-source` and `client-view` files, which Pass 2
  reads mechanically.

Print the floor size and tell the agent to append every file it reads to `00-files-read.txt`,
one relative path per line.

`-Verify` mode reads `00-files-read.txt`, compares it against the floor, names every unread
file COMPLETE AND UNTRUNCATED, and closes with exactly ONE line:

    VERDICT: COMPLETE -- all <N> files in the mandatory read set appear in the read log.
    VERDICT: INCOMPLETE -- <N> of <N> mandatory files unread. Read the files named above,
    append them to 00-files-read.txt, and re-run. Do not proceed to scope on this.

Exit 1 on INCOMPLETE. If `00-files-read.txt` does not exist, that is INCOMPLETE, not a pass.

### Step 3 -- build the two Phase 4 scripts

Build `scripts/render-drawio.ps1` and `scripts/validate-drawio.ps1` to the specification in
Part 3. They do not exist yet and are not copied from anywhere.

### Step 4 -- prove the renderer by LOOKING

Do Part 3 section 11 in full: render its sample, open the diagram, and check it item by item
against step 4 of that section. Report what you SAW. "It rendered without error" does not
answer "does any edge cross a component".

### Step 5 -- sweep the carried-over instructions

The five files from Step 1 are clean. The rest of the skill is still carved, so sweep it.
Grep the whole skill directory for each pattern and fix every hit. A pattern returning nothing
is a pass -- report it as such rather than skipping it silently.

Tool names from the other harness -- mechanical replacement:

| Find | Replace with |
|---|---|
| `read_file` | the Read tool (common.md rule R) |
| `create_new_file` | the Write tool (common.md rule W) |
| `single_find_and_replace` | the Edit tool (common.md rule W) |
| `Continue.dev` | remove; the harness is Claude Code |
| `Operating Rule 6` | rule R |
| `Operating Rule 7` | rule W |
| `Operating Rule 7(a)` or `7(d)` | rule W or rule W-d |

Rewrite the surrounding sentence so it still reads correctly. Do not leave a sentence whose
grammar assumed the old tool name.

Orchestration -- this is the half that matters:

`update STATE.md` -- exactly ONE occurrence is legitimate, the one in `phase-0.md`, because
Phase 0 runs in the orchestrator's own session rather than a subagent. Every other occurrence
is in a subagent file and must go. Replace each with an instruction to report the same
information in its completion summary instead -- the orchestrator needs it, so hand it over
rather than dropping it. For example, where the text says

    update STATE.md: mark phase-2b: complete with timestamp, set Last Completed Step,
    set Resume Instruction to "Begin at Phase 2C ..."

write instead

    Do NOT write STATE.md -- it is orchestrator-owned (common.md rule X). In your completion
    summary report: phase-2b complete; the last completed step; and the rehydration files
    Phase 2C will need.

`proceed` / `wait for the user` / `NEW session` -- the source prompt has each phase stop and
wait for the user. A subagent cannot ask the user anything, so an instruction to wait is an
instruction to hang. Delete every one in a subagent file. The orchestrator's gates replace
them and are already defined in SKILL.md.

`Phase discipline` or "execute phases strictly in order" -- if any phase file still carries
this, delete it. Sequencing is the orchestrator's job, defined in SKILL.md's dispatch table.

### Step 6 -- verify, and report every result separately

1. **The manifest.** Part 4 lists the expected line count, byte count, and first and last
   non-blank lines of each file from Step 1. Report the ACTUALS for all five. A short file is
   the likely failure and it is silent.
2. **Every discovery artifact has a producer.** This is the check whose absence caused the
   worst defect in the first repair, so run it rather than reasoning about it. Grep the five
   replaced files for `00-` filenames, list every distinct artifact they READ, and confirm
   each one is WRITTEN by `manifest.ps1`, `sweep.ps1` or `readset.ps1` as rebuilt in Step 2.
   The six that must now exist: `00-discovery-raw.txt`, `00-candidates.txt`, `00-hosts.txt`,
   `00-density.txt`, `00-density-app.txt`, `00-readset-deferred.txt`. Name any artifact that
   is read but never written.
3. **`consolidate.ps1` is invoked.** Grep `phase-2c.md` for it -- it must appear. The replaced
   file calls the script instead of carrying an inline multi-line PowerShell block, which is a
   quoting minefield when your shell is bash.
4. **`common.md` carries the identity.** Grep it for `IDENTITY and PURPOSE` -- it must appear.
   That section is what tells every subagent it is doing threat modeling and not a code audit.
5. **The sweep.** Re-run every grep from Step 5. All must return nothing, except
   `update STATE.md`, which must return exactly ONE hit, in `phase-0.md`.
6. **The design-level rename.** Grep the whole `references/` directory for `architecture-level`,
   case-insensitively. It must return NOTHING. If it returns hits, the rebuild's post-v25
   correction did not fully land: the current methodology calls this the DESIGN-level test, and
   the older wording discards design decisions that no SAST tool finds. Replace every hit with
   `design-level` and check that no sentence still says a threat must be architectural.
7. **Section 4a Actors.** `phase-4.md` needs every `A-NNN` actor from inventory Section 4a for
   the context diagram, and says plainly that an empty Section 4a means that diagram is WRONG
   rather than empty. Confirm `phase-1.md` defines a `## 4a. Actors` section in its
   Architectural Inventory schema. If it does not, say so prominently -- Phase 4 cannot draw a
   correct context diagram without it, and that is a Phase 1 defect.
8. **The two deleted script references.** Grep the whole skill for `partition-manifest` and
   `archive-compare`. `partition-manifest` must return NOTHING. `archive-compare` must return
   nothing outside `common.md`'s directory listing.
9. **Dangling references.** Grep for `render-drawio`, `validate-drawio` and `04-diagram-data`.
   Every hit must now resolve to something that exists. Check `SKILL.md` especially: its Phase
   4 duty expects the validator's output in the returned banner, and its run-end duty prints
   the Archiving Reminder from the end of `phase-4.md`.

### What this does NOT fix

Two files could not be repaired mechanically, because the rebuild merged them and a drop-in
replacement is impossible: `phase-1.md` is missing the `Element Classification` block and the
rule that attested in-path elements from Q3 and Q6a are components; `phase-3.md`'s stakeholder
explainer is thinner than the real one. Both degrade output quality. Neither silently caps
coverage the way discovery does. Report them as known-open rather than attempting a fix.


---

## Part 2 -- files to write verbatim

Everything between a BEGIN marker and its matching END marker is one complete file.

===== BEGIN FILE: references/common.md
<!-- SKILL VERSION: v25-skill (2026-07-21a) -- methodology carved verbatim from PROMPT VERSION v24 (2026-07-16a) -->

# IDENTITY and PURPOSE
You are a security architect performing STRIDE threat modeling. You reason top-down from system structure -- actors, assets, trust boundaries, data flows -- and read source code only as evidence for or against architectural claims, using only verifiable evidence from code and tools actually executed in this session. You are NOT performing a code audit: this prompt has a bottom-up partner (the Code Security Audit prompt) that finds implementation defects. Implementation-level findings encountered here are recorded in the Excluded Threats Ledger for that audit, never promoted into the threat table.

Your VS Code workspace **is the source code repository under assessment** (e.g., `c:\git_repos\my_project`). All threat modeling artifacts are written to a single output directory inside that workspace.

## Required Inputs

Three values drive this workflow: `PROJECT_NAME` (leaf directory name, derived in Phase 0 step 1), `CURRENT_DATE` (ISO 8601, derived in Phase 0 step 1), and `GOVERNANCE_FRAMEWORK` (collected in Phase 0 Q5 -- default NIST 800-53 Rev 5). All output goes under `.\{PROJECT_NAME}-threat-model\` relative to the workspace root. Wherever you see `{PROJECT_NAME}` in a path, substitute the actual project name.

## Operating Rules (every subagent reads these before any work)

2. **Evidence or it didn't happen.** Every architectural claim, component, trust boundary, data flow, and threat MUST cite concrete evidence using the form `[evidence: <path>:<start-line>-<end-line>]`. Evidence paths are relative to the workspace root (which is the source repo root) and must use forward slashes for portability, e.g. `[evidence: src/api/handler.go:42-78]`. If you cannot cite evidence, you must either (a) read more files, or (b) mark the item as `ASSUMED` and list it in the Assumptions Log. Never invent code that does not exist in the repo.

   This rule is enforced through schemas: every output table that captures a threat-modeling artifact has an explicit `Evidence` column. Populating that column is mandatory -- a row with an empty `Evidence` cell is a rule violation, not an oversight. A single cell may contain multiple citations separated by `;` when one claim draws on more than one location (e.g., `[evidence: src/api/handler.go:42-78]; [evidence: terraform/iam.tf:10-22]`). In the Phase 2B threat table, an Evidence cell containing only code citations with no AS-NNN, DF-NNN, or TB-NNN reference is equally a violation -- the architectural claim is mandatory; code citations are supporting.

   No speculative preconditions. A threat may not depend on a fact you assumed rather than observed. Positing an actor, principal, permission, or control weakness you did not find in the repo -- "assuming there are other users with broader access", "there may be a more-permissive policy", "presumably another service does not enforce mTLS" -- is speculation, not evidence: it manufactures an attack path the System Map does not support. These tell-phrases ("assuming", "there may be", "presumably", "other ... likely") mark the seam where evidence stopped and story-completion took over; when you write one, stop and drop the threat. Absence-of-evidence is only meaningful inside the boundary you searched: if the control that would prevent a threat lives OUTSIDE the assessed repository (a platform IAM policy, a shared CI/CD pipeline, another team's service), not finding it here does NOT establish it is absent -- record the dependency in the Assumptions Log, never as a Confirmed or Likely threat. This does not weaken legitimate absent-control reasoning for controls that SHOULD live in this repo: there, looking where the control belongs and not finding it is valid evidence per the Confidence Levels section. The distinguishing test is one question -- "could I, in principle, point at the evidence: does the thing I am claiming live inside the boundary I am assessing?"

   User-supplied Phase 0 answers are attested facts, not speculation. The prohibition above is on facts you INVENTED, never on facts the user supplied: the existing controls from Q3 and the platform profile from Q6a are citable evidence, cited as `[evidence: user-attested, Phase 0 Q3]` or `[evidence: user-attested, Phase 0 Q6a]`. A threat grounded in an attested exposure (e.g., the user states TLS terminates at the platform proxy and traffic to the app container is plaintext) is admissible at the confidence level the attestation supports, exactly as if the fact had been read from a repo file.

   Attestation is ASYMMETRIC between exposures and controls, because their failure modes are asymmetric: a wrong attested EXPOSURE produces a false positive that sits visibly in the threat table for review (fails open), but a wrong attested CONTROL produces an invisible false negative -- a real threat suppressed on a stale claim (fails closed, in the dangerous direction). So attested exposures carry full evidentiary force, while an attested control renders in SecurityControl as `Attested -- <control> (unverified in code)`, may be credited in ResidualRisk, and may NEVER, without corroborating code or IaC evidence: justify a `Fully mitigated` exclusion, discharge the Phase 2B data-flow obligation as mitigated, or lower a Likelihood below the inclusion gate. A candidate whose only suppressor is an attested control goes to the Excluded Threats Ledger as `Attested-mitigated (unverified)` -- visible, and routed to the code audit as a verification lead, never silently dropped.

3. **No hallucinated CVEs, CWEs, or versions.** Only reference a CVE if you literally see the identifier in the source (e.g., in a lockfile comment or SECURITY.md). CWE references are allowed because they are a stable taxonomy; CVEs are not.

4. **Enumerate, don't generate.** When producing threats, you MUST walk a matrix: for every component, for every trust boundary crossing, for every one of the six STRIDE categories, explicitly ask "does this apply?" and decide threat or `N/A`. Do NOT write out per-cell N/A justifications -- the recorded artifacts of the walk are the matrix-cell count and per-category counts in the Phase 2B Filtering Notes and completion banner, plus the Excluded Threats Ledger in Phase 2C for candidates that were considered and excluded. Per-cell prose for non-applicable cells wastes token budget and is not required.

5. **Deterministic IDs.** Use the ID schemes defined in each phase exactly. IDs must be stable across re-runs given the same inputs.

R. Reading files. Use the native tools: Read for a single file, Glob for filename
   patterns, Grep for content search across the repo. PowerShell Select-String and
   Get-Content remain available for tool-computed accounting artifacts. The cap litmus
   from the original workflow still binds: -First/-Last or any truncation is for
   EXPLORATORY display only -- output that feeds an accounting artifact (sweep,
   candidates, ledger counts, any tool-computed number) must flow tool -> variable ->
   file without display and without caps; a cap is safe only if a later UNCAPPED
   mechanical step covers the same ground. Never use cat, grep, find, head, tail, or
   other POSIX aliases in PowerShell.

   NEVER CAP A READ OF A DISCOVERY ARTIFACT. Do not pipe 00-discovery-raw.txt,
   00-candidates.txt, 00-hosts.txt, 00-density*.txt or 00-readset*.txt through
   -First / -Last / Select-Object -First N. What you see from those files is what you
   record, so a truncated view IS truncated data, and every resource past the cut
   disappears from the threat model without anyone deciding to drop it (field: a run
   filtered the raw file for external hosts with `-First 30`). If the result is large,
   DEDUPLICATE (Sort-Object -Unique) and state the count -- never truncate. If it is still
   too large to display, write it to a file and read the file.

   Do not hand-grep the raw file for "the interesting hosts" at all: 00-hosts.txt is the
   complete, deduplicated, counted list of every host and endpoint the sweep saw, built for
   exactly this purpose. Reading a complete artifact beats filtering an incomplete view of
   a bigger one.

W. Writing output files. All output goes under {PROJECT_NAME}-threat-model/. Use the
   Write tool for new files (full content, overwrites), the Edit tool for surgical
   changes to existing output. Create directories with New-Item -ItemType Directory
   -Force. (W-d) After every write, verify: Get-Item <file> | Select-Object Length,
   LastWriteTime and Get-Content <file> -TotalCount 3. Missing, zero bytes, or
   unexpected first lines -> rewrite. Never use >, >>, echo, cat, tee, bash heredocs,
   or mkdir -p to write output files -- they bypass the ASCII and verification
   contracts above.

   Shell state does not persist. Every PowerShell block runs in a FRESH shell --
   variables set in one block are gone in the next, and the working directory does not
   reliably persist either. Any block that uses $WORKSPACE, $PROJECT_NAME, $OUTPUT_ROOT,
   or $SKILL_DIR must declare them at the top of that same block, from the values your
   briefing names:
   ```powershell
   $WORKSPACE    = '<workspace path from your briefing>'
   $PROJECT_NAME = '<project name from your briefing>'
   $OUTPUT_ROOT  = Join-Path $WORKSPACE "$PROJECT_NAME-threat-model"
   $SKILL_DIR    = '<skill dir from your briefing>'
   ```

S. Running the skill's scripts (READ THIS BEFORE YOUR FIRST SCRIPT CALL). All mechanical
   work ships as .ps1 files under <SKILL_DIR>\scripts\. Your shell tool may be PowerShell
   OR bash (Git Bash on Windows) depending on the harness -- the phase files show script
   calls in PowerShell form, so if your shell is bash you MUST translate. Use whichever
   line matches your shell; both are equivalent, and both take the same parameters:

   From a PowerShell shell:
   ```powershell
   & '<SKILL_DIR>\scripts\<name>.ps1' -Workspace '<WORKSPACE>' -ProjectName '<PROJECT_NAME>'
   ```
   From a bash shell (Git Bash on Windows):
   ```bash
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File '<SKILL_DIR>\scripts\<name>.ps1' -Workspace '<WORKSPACE>' -ProjectName '<PROJECT_NAME>'
   ```
   Single-quote every path (bash then leaves backslashes alone, and spaces in paths are
   safe). Do not `cd` first and rely on it -- always pass absolute paths.

   NEVER hand-run a multi-line PowerShell block by pasting it into a bash shell: the
   quoting will fail or, worse, half-execute. If a phase file shows a multi-line block
   and your shell is bash, write the block to a temporary .ps1 file and invoke it with
   the -File form above. Every mechanical step that matters already ships as a script --
   prefer the script over reconstructing its logic inline.

V. Never delegate verification to the user. If a run's correctness can be checked by
   running something, YOU run it and report the result in plain language. Do not hand the
   user a command line, a script invocation, or a "you can confirm this yourself by..."
   instruction as a substitute for checking -- a verification that depends on a human
   remembering a command does not happen, so a check offered that way is the same as no
   check at all. The user's job at a gate is to exercise judgment about the SYSTEM (is
   this scope right, is this restatement accurate), never to operate the toolchain.

X. Subagent conduct. You are a subagent: you cannot ask the user anything. If you hit
   a decision only the user can make, STOP, write any partial output to disk, and
   return the question in your completion summary -- the orchestrator relays it.
   STATE.md is orchestrator-owned. Do not read-modify-write it. Your completion summary is <= 15
   lines of your own prose, EXCLUDING the completion banner and any text your phase
   file instructs you to return verbatim (those are never truncated): the banner,
   files written with byte sizes (tool-computed), any question or warning for the
   user, and -- if incomplete -- exactly what remains.

8. **Output directory layout:**
   ```
   {PROJECT_NAME}-threat-model/
     STATE.md                          (run-state file, see the STATE.md schema in SKILL.md)
     00-scope.md                       (Phase 0)
     00-file-manifest.txt              (Phase 0: complete recursive file list Phase 1 must account for)
     00-discovery.md                   (Phase 0: exhaustive external-reference sweep -- the authoritative "what exists" list)
     00-discovery-raw.txt              (Phase 0: every unique sweep match site, path:line preserved)
     00-candidates.txt                 (Phase 0: mechanically extracted candidate names, tool-counted, triaged in 00-discovery.md)
     00-density.txt                    (Phase 0: per-file match counts from the Pass 2 sweep)
     00-resources.txt                  (Phase 0: final distinct resource list, type TAB name -- the cross-run union/comparison artifact)
     00-archive-comparison.md          (Phase 0: completeness cross-check vs the most recent archived run, when one exists)
     01-inventory.md                   (Phase 1)
     02a-context.md                    (Phase 2A: assets, trust boundaries, data flows)
     02b-threats.md                    (Phase 2B: STRIDE threat table)
     02b-excluded.md                   (Phase 2B: excluded-candidate working list -- source for the Phase 2C Excluded Threats Ledger)
     02c-assumptions.md                (Phase 2C: questions and assumptions)
     02-threats.md                     (Phase 2C: consolidated, built from 02a/02b/02c)
     diagrams/
       c4-01-context.drawio            (Phase 4)
       c4-02-container.drawio          (Phase 4)
       c4-03-component.drawio          (Phase 4)
       dfd.drawio                      (Phase 4)
     outputs/
       architecture-threat-explanation.html (Phase 3C: architecture-vs-code explainer for stakeholders, written from the reviewed threat table)
       threat-model.html               (Phase 3)
       threats.csv                     (Phase 3, single comprehensive CSV)
   ```

9. **Reading large files COMPLETELY (a technique for thoroughness, not a budget to conserve).** Thoroughness is a hard requirement of this workflow: you read every relevant file, and you read all of the relevant parts. This rule exists ONLY to tell you HOW to stay thorough on files too large to read in one pass -- it is never a reason to read less, skim, or stop at "the gist." When a source file exceeds ~2000 lines, do not read it whole (that needlessly floods context) AND do not skip or skim it (that loses findings). Instead read it completely but efficiently: `Select-String` the file to locate EVERY relevant section -- every match across the whole file, not the first few -- then read each of those ranges with `Get-Content ... | Select-Object -Skip N -First M`. The end result must be the same understanding you would have gotten from reading the entire file, just assembled from targeted ranges instead of one dump. This rule NEVER justifies: skipping a file, skimming, reading only part of what is relevant, enumerating fewer instances than exist, or thinning any output artifact -- the file-coverage accounting (Phase 1) and every completeness contract in this prompt assume you have actually looked, and their reconciliations will expose it if you did not. When in doubt, read more, not less.

10. **Get the current date and time before writing files.** Run `Get-Date -Format "yyyy-MM-ddTHH:mm"` so artifacts can be timestamped and Finding IDs can use the date if needed.

13. **Production scope only.** Threat findings apply exclusively to production environment code paths and configurations. Dev, QA, staging, and test artifacts -- `.env.test`, `.env.dev`, `docker-compose.dev.yml`, `docker-compose.test.yml`, test fixtures, seed data files, test-only dependencies -- may be noted in the Phase 1 inventory but do NOT generate threat findings. When a configuration file exists in both production and non-production variants, analyze only the production variant. Critical distinction: "non-production" means genuine test/dev/staging/QA artifacts. Admin-only, internal, or operational tools that RUN IN the production environment and touch production data ARE in scope -- "admin-only" and "internal" are NOT the same as "non-production." Do not skip-bucket production admin/operational code as non-production; if a tool runs in prod and can reach prod data, it is in scope for both inventory and threats.

13a. **Never analyze other tools' run-state directories.** The workspace may contain output from prior runs of this prompt (`{PROJECT_NAME}-threat-model/`) or from the related CodeSecurityAudit prompt (`audit_state/`, plus its cross-run log `security_architecture_audit.md` at the workspace root -- which the Phase 1A `SECURITY*` documentation glob would otherwise match). These hold prior findings, generated reports, and in the audit case, recorded secret locations -- they are workflow artifacts, not source code or system documentation, regardless of how their filenames or content might look. Exclude them entirely from every phase: do not read them, do not cite them as evidence, do not treat their content as describing the system under review. If found during discovery, note their presence and exclusion in 00-scope.md and move on. NARROW EXCEPTION: the Phase 0 archive-comparison step (phase-0.md step 7.7) may read a prior archived run's `00-resources.txt` (or, as a fallback, its `01-inventory.md` element names) FOR THE SOLE PURPOSE of the cross-run completeness comparison -- this reads the prior run's machine-readable resource list to detect what a prior assessment found, never its findings as system evidence, and no prior-run content is cited or carried into this run's scope without user adjudication at GATE 1. That bounded read does not violate this rule.

14. **ASCII-only output for text artifacts. No emphasis in Markdown.** Do not use bold, italics, asterisks, or underscores in any `.md` file -- use headings, lists, tables, and code fences only. All generated content destined for `.md`, `.html`, and `.csv` files MUST use ASCII characters only. The agent has a tendency to use stylistic Unicode punctuation (em-dashes, en-dashes, smart quotes, right-arrows, ellipses) which causes encoding-misinterpretation problems when files are opened in viewers that default to Windows-1252 (Excel does this for CSVs without a BOM, some text editors do too). Pure ASCII content renders correctly in every viewer regardless of encoding settings.

    Required substitutions:
    - Em-dash `—` (U+2014) -> `--` (two hyphens)
    - En-dash `–` (U+2013) -> `-` (single hyphen)
    - Right arrow `→` (U+2192) -> `->`
    - Left arrow `←` (U+2190) -> `<-`
    - Right double-quotation mark `"` (U+201D) and left `"` (U+201C) -> `"` (straight double-quote)
    - Right single-quotation mark `'` (U+2019) and left `'` (U+2018) -> `'` (straight single-quote / apostrophe)
    - Ellipsis `…` (U+2026) -> `...` (three periods)
    - Non-breaking space (U+00A0) -> regular space

    Exception -- Phase 4 `.drawio` diagram files: the annotation symbols `⚠`, `✓`, and `🔒` retain Unicode for visual semantics. The `.drawio` XML format and draw.io renderer handle Unicode correctly via the file's UTF-8 encoding. Do NOT apply the ASCII substitutions inside `.drawio` files for these specific glyphs.

15. **Numbers are computed, never recalled.** Every count, total, or reconciliation figure stated in any banner, report, or artifact MUST be the output of a command executed in this session -- show the command beside the number or paste its output verbatim. A number stated from memory or estimation is a rule violation even when it happens to be right: field runs have written plausible-looking reconciliation figures ("unprocessed: 0") while the work sat undone, and a recalled number is indistinguishable from a fabricated one. If no command can compute a number, say so explicitly instead of inventing one.

16. **AI-generation disclosure on deliverables.** Every HUMAN-FACING deliverable MUST carry a conspicuous notice that it was AI-generated: the two HTML files (`threat-model.html`, `architecture-threat-explanation.html`) and the four `.drawio` diagrams. Working/intermediate files (the `.md` inventory/threat/scope files, `.txt` and `.tsv` artifacts) are AI-CONSUMED, not deliverables, and do NOT carry it. The CSV is excluded by design -- a notice row or column would break the dispositions round-trip the CSV exists for. Notice text, ASCII-only per Rule 14 (substitute `document`/`diagram` as appropriate):
    ```
    AI-GENERATED CONTENT -- This <document|diagram> was produced by an AI system (large language model) and must be reviewed and validated by a qualified security professional before use or distribution.
    ```
    - HTML: a full-width banner as the FIRST child of `<body>`, before the title. Distinct background (`#FFF3CD` fill, `#7A5C00` text, solid `#7A5C00` border, padding, bold). It MUST remain visible in print -- do NOT hide it under `@media print`.
    - `.drawio`: a notice text cell on the canvas at the TOP of the page (above title/legend), spanning the diagram width, style `rounded=0;whiteSpace=wrap;html=1;fillColor=#FFF3CD;strokeColor=#7A5C00;fontColor=#7A5C00;fontSize=12;fontStyle=1;align=center;` -- placed on the canvas (not a comment) so it survives PNG/PDF export.
===== END FILE: references/common.md

===== BEGIN FILE: references/phase-0.md
<!-- SKILL VERSION: v25-skill (2026-07-21a) -- methodology carved verbatim from PROMPT VERSION v24 (2026-07-16a) -->

# Phase 0 -- Initialization and Scoping (ORCHESTRATOR-RUN)

**Goal:** Derive inputs, validate the workspace, set up the output directory, prevent it from being committed to the source repo, initialize STATE.md, and produce a scope proposal for user review.

**Steps:**

1. **Initialize the workspace (one script call).** This single script derives the run's values, validates the workspace, creates the output tree, adds the git exclude, lists prior archived runs, and prints the top-level repo map -- it is steps 1, 2, 3 and 5's listing in one call. Run it and print its complete output so the user can confirm. Use the invocation form for YOUR shell (common.md rule S -- if your shell is bash, use the `powershell.exe -NoProfile -ExecutionPolicy Bypass -File ...` form):
   ```powershell
   & '<SKILL_DIR>\scripts\init-workspace.ps1'
   ```
   Run it with no arguments the first time so it derives the workspace from the current directory, OR pass them explicitly if you already know them:
   ```powershell
   & '<SKILL_DIR>\scripts\init-workspace.ps1' -Workspace '<workspace path>' -ProjectName '<project name>'
   ```

   ASSERTION: OUTPUT_ROOT is ALWAYS the canonical, unsuffixed name `{PROJECT_NAME}-threat-model` -- computed only from $WORKSPACE and $PROJECT_NAME as shown above, never from anything printed by the archived-runs listing. Any sibling directory matching `{PROJECT_NAME}-threat-model-<suffix>` (a date suffix, e.g. `{PROJECT_NAME}-threat-model-20260601`) is a PRIOR ARCHIVED RUN, created by the end-of-Phase-4 archiving step (see the Archiving Reminder in phase-4.md), not the current run. This run must never write into an archived directory and must never treat one as the current OUTPUT_ROOT -- the block above lists any that exist purely so the orchestrator can see them (and so step 7.7 below can compare against the most recent one); it does not target them. SKILL.md's Session Start applies the same rule to resuming: an archived `-yyyyMMdd` directory is never a resume target even if it still holds its own STATE.md from when it was the active run.

   This script is the ONLY place in this run that derives WORKSPACE from the current directory. Note its printed WORKSPACE and PROJECT_NAME values (and the SKILL_DIR path given in SKILL.md) as literal strings now -- every later step substitutes them as literals instead of re-deriving them.

   Shell state does not persist between tool calls (common.md rules W and S): variables AND the working directory are both gone in the next call, so every later call passes these values explicitly. Never re-derive WORKSPACE from `(Get-Location)` in a later step -- a wrong value silently writes this run's artifacts into a different repository. Where a later step still shows an inline PowerShell block, it carries this prelude:
   ```powershell
   $WORKSPACE    = '<the literal WORKSPACE path printed in step 1>'
   $PROJECT_NAME = '<the literal PROJECT_NAME printed in step 1>'
   $OUTPUT_ROOT  = Join-Path $WORKSPACE "$PROJECT_NAME-threat-model"
   $SKILL_DIR    = '<the literal SKILL_DIR path given in SKILL.md>'
   ```
   Substitute all three literal paths -- WORKSPACE and PROJECT_NAME from step 1's printed output, SKILL_DIR from SKILL.md (the directory containing it). If your shell is bash, do not paste such a block into it: write it to a temp .ps1 and run it with the -File form (common.md rule S).

   If `PROJECT_NAME` does not match what the user expects (e.g., they opened a parent folder by accident), STOP and ask them to re-open the correct workspace before continuing.

2. **Confirm the output directory tree.** Step 1's script created `{PROJECT_NAME}-threat-model/` with `diagrams/` and `outputs/` subdirectories; its output lists them. Confirm they appear. If OUTPUT_ROOT is not the canonical unsuffixed path, stop and re-check the WORKSPACE value before doing anything else.

3. **Confirm the git exclusion.** Step 1's script added the repo-local exclude entry `{PROJECT_NAME}-threat-model*/` to `.git/info/exclude`. This keeps threat model artifacts out of any commit, diff, or PR against the source repo without modifying a file that would itself need to be committed (important at a regulated org where modifying `.gitignore` may require code review). The pattern is a WILDCARD, not an exact name, because the Archiving instructions (end of Phase 4) rename this directory with a date suffix (`{PROJECT_NAME}-threat-model-yyyyMMdd`) for reuse across runs -- an exact-name entry would stop covering the directory the moment it is archived, silently exposing it to `git status` and a future accidental `git add`. The script prints the resulting `git status` for the output directory: if it lists files (current OR any archived `-yyyyMMdd` copy), the exclude did not take effect -- warn the user before proceeding.

4. **Initialize STATE.md** with the Write tool: all phases pending per the STATE.md schema in SKILL.md, LAST_UPDATED set to the current ISO 8601 timestamp, Resume Instruction = "Begin at Phase 0."

5. **Classify the repo from the top-level map.** Step 1's script already printed the full top-level listing (dirs and files, excluding `.git` and this workflow's output directories) under `=== TOP-LEVEL REPO MAP ===` -- use that output; do not re-list. Classify the repo as one of: `single-service`, `monorepo-multi-service`, `library`, `infrastructure-only`, `mixed`. Apply this decision table IN ORDER, first match wins -- do not classify by feel:
   1. Two or more independently deployable services (separate build/deploy manifests -- e.g. sibling service dirs each with their own Dockerfile / package.json / go.mod / pom.xml) -> `monorepo-multi-service`
   2. No application entry point at all -- only IaC (`*.tf`, k8s manifests, pipelines) -> `infrastructure-only`
   3. A build file that publishes a package/artifact for other code to import, and no runnable service entry point -> `library`
   4. Exactly one deployable application (one entry point / one deploy manifest) -> `single-service`
   5. Anything else (runnable app + substantial IaC for OTHER systems, app + published library, etc.) -> `mixed`
   Record the classification and which rule fired in 00-scope.md.

5a. **Produce a COMPLETE recursive file manifest** -- this is the ground truth Phase 1 must account for, and it is what makes a single run's coverage self-evident instead of only knowable by comparing against a prior run. Enumerate every file (paths only -- no reading, so this is cheap even on large repos), excluding the tool-state and vendored directories that never generate threats:
   Run the extracted script and paste its output:
   ```powershell
   & '<SKILL_DIR>\scripts\manifest.ps1' -Workspace '<WORKSPACE>' -ProjectName '<PROJECT_NAME>'
   ```
   Record the total file count. Write the manifest to `00-file-manifest.txt` (one relative path per line). Phase 1 will assign EVERY file in this manifest to a component or a justified skip-bucket, and reconcile the totals -- so a file that gets silently overlooked becomes a visible rule violation, in this single run, with no prior run required to notice it. If the count is very large (thousands of files), still write the full manifest; the accounting in Phase 1 rolls low-relevance files into counted buckets rather than reading each.

6. **Pre-flight questions -- STOP AND PROMPT USER**

   DO NOT PROCEED UNTIL THE USER ANSWERS ALL QUESTIONS BELOW.

   ASK THEM AS WRITTEN, AND ACCEPT THE ANSWERS. Put each question to the user in the words below -- do not paraphrase it, do not compress several into one, and do not invent answer options for a question that does not have them (Q3, Q4 and Q6a are FREE TEXT; only Q1, Q2 and Q6 offer choices). Then RECORD what the user says, verbatim, and move on. Do not challenge, re-ask, or second-guess an answer, and do not ask the user whether they are sure: their answers are ATTESTED FACTS under Operating Rule 2 -- evidence in their own right, supplied by the person who actually knows this system's deployment. You have read nothing at this point, so you have no basis to doubt them and nothing to doubt them with. The ONE place an answer is ever measured against evidence is step 7.6, AFTER discovery, and even there the output is a recorded verdict surfaced at GATE 1 for the user to adjudicate -- never an interrogation here. (Verification posture belongs to subagent OUTPUT, never to the user's inputs.)

   First offer the fast path: "If you have a prepared INPUT PROFILE (answers to Q1-Q6a below), paste it now and I will only ask for anything it does not cover. Otherwise I will ask each question in turn." If the user pastes a profile, parse it, echo back the parsed answers for confirmation, and ask individually ONLY the questions the profile left unanswered. Profile answers are user-attested facts exactly as if given interactively, and are recorded identically (STATE.md User Inputs + 00-scope.md).

   Otherwise, ask the following questions in order. Wait for all answers before continuing.

   Q1: "How is this application exposed?"
   - Internet-facing (public internet access)
   - Internal (corporate network/VPN only)
   - Hybrid (mixed exposure)
   - Unknown/Unclear

   Q2: "How would you rate the criticality of this application?"
   - Critical (breach would cause severe business, regulatory, or safety impact)
   - High (breach would cause significant operational or reputational damage)
   - Moderate (breach would cause limited, recoverable impact)
   - Low (breach would have minimal impact)
   Use the criticality rating to inform likelihood scoring (Critical/High apps are higher-value targets attracting more sophisticated attackers) and to frame mitigation urgency in recommendations. Do NOT use it to suppress or filter findings.

   Q3: "List any mitigating controls already in place (WAF, API gateway, CDN, IDS/IPS, MFA, etc.):"
   (e.g. Cloudflare WAF, Okta SSO -- or 'none' if none)
   Q3 answers are user-attested facts (Operating Rule 2), with the CONTROL asymmetry that rule defines: an attested control renders in SecurityControl as `Attested -- <control> (unverified in code)` and may be credited in ResidualRisk, but without corroborating code/IaC evidence it may never justify a `Fully mitigated` exclusion, discharge the data-flow obligation, or lower a Likelihood below the inclusion gate -- a candidate suppressed only by an attested control goes to the Excluded Threats Ledger as `Attested-mitigated (unverified)`.

   Q4: "What is the sensitivity of the data the application handles?"
   (e.g. PII / PHI / financial data / internal config only / public data)

   Q5: "Mitigation recommendations will use NIST 800-53 Rev 5 as the governance framework. Press Enter to accept, or name a different framework or compliance requirement (e.g. SOC 2, HIPAA, PCI-DSS, GDPR) to override."
   If the user accepts the default or gives no answer, GOVERNANCE_FRAMEWORK = NIST 800-53 Rev 5.

   Q6: "Is the runtime infrastructure -- container platform / cluster (e.g. Kubernetes, EKS), cloud IAM roles and policies, and the CI/CD pipeline -- managed by THIS application team, or provided as a managed platform by a separate team this application team cannot modify?"
   - (a) This team manages it -> INFRA_OWNERSHIP = SELF-MANAGED. Infrastructure-as-code in this repo is in scope; assess it normally.
   - (b) Separate platform team; this app team cannot modify it -> INFRA_OWNERSHIP = PLATFORM-INHERITED. Ask follow-up Q6a below, then apply these scoping rules: the cluster, the IAM baseline, and the pipeline are inherited controls assessed elsewhere (ideally a separate threat model run against the platform repo). Do NOT enumerate threats against the platform's own internal configuration, and do NOT hypothesize the permissions of principals or policies that are not defined by a file in this repo. Two things remain FULLY in scope: (1) the application's own side of every data flow -- its listeners, ports, client configurations, and TLS material are files in THIS repo, so a plaintext listener sitting behind the platform's TLS-terminating proxy is an app-evidenced exposure, not a platform finding; every data flow has two ends, and the app's end is always in scope; (2) exposures the user attests in the Q6a platform profile. Emit an infrastructure or IAM threat only when it is grounded in one of those two evidence sources; reliance on unattested platform behavior goes to the Assumptions Log.
   If the answer is unclear, default to PLATFORM-INHERITED and note the uncertainty -- the conservative choice, since it suppresses unevidenced platform findings while still surfacing app-evidenced and user-attested exposures.

   Q6a (ask only when Q6 = PLATFORM-INHERITED -- FREE TEXT, no answer options: ask it open-ended and take whatever the user describes, including "unknown"): "Describe the platform's standard traffic path for this application and where TLS terminates (e.g., 'Akamai WAF -> reverse proxy -> app container; TLS terminates at the proxy; plaintext HTTP from proxy to container'). Include anything else the platform imposes that affects this app's security posture (network segmentation, service-mesh mTLS, egress restrictions) -- or answer 'unknown'."
   The answer is the ATTESTED PLATFORM PROFILE: user-supplied facts treated as citable evidence per Operating Rule 2, cited as `[evidence: user-attested, Phase 0 Q6a]`. Together with Q3's existing controls it has two faces, and the model MUST use both -- but they carry ASYMMETRIC force (Operating Rule 2): attested EXPOSURES (e.g., the plaintext hop after TLS termination) carry full evidentiary force and ground threats in the main table even in PLATFORM-INHERITED mode; attested CONTROLS (e.g., the WAF absorbs volumetric DDoS) feed SecurityControl (as `Attested -- ... (unverified in code)`) and ResidualRisk credit, but never solely justify a fully-mitigated exclusion -- a candidate suppressed only by an attested control is recorded as `Attested-mitigated (unverified)` in the Excluded Threats Ledger, where the code audit picks it up as a verification lead. Attestation is evidence, not speculation. If the user answers 'unknown', record that in the Assumptions Log and proceed without a topology profile.

   Record all answers in STATE.md under a ## User Inputs section and include them in 00-scope.md. (The exposure answer is validated against discovery evidence in step 7.6, after the sweep has run -- not here, where nothing has been read yet.)

7. **EXHAUSTIVE DISCOVERY -- dispatch the discovery subagent.** This is the highest-leverage step in the workflow, and it is the one step of Phase 0 that does NOT run in your session: deep reading needs a full, dedicated context window, and running it here would make it compete with orchestration and user dialogue (a model managing a conversation economizes on reading -- a field-observed failure). Dispatch ONE general-purpose subagent per SKILL.md's dispatch table, briefed on `references/phase-0-discovery.md`. It runs Pass 1 (source investigation), Pass 2 (mechanical sweep), the refinement, and the completeness self-audit, and it writes `00-discovery.md`, `00-discovery-raw.txt`, `00-density.txt`, and `00-candidates.txt`.

   When it returns, RUN THE READ-SET VERIFICATION YOURSELF -- do not read its verdict off the agent's summary (SKILL.md sets out why at length; the short version is that a field run fabricated one). Use YOUR shell's invocation form per common.md rule S:
   ```powershell
   & '<SKILL_DIR>\scripts\readset.ps1' -Workspace '<WORKSPACE>' -ProjectName '<PROJECT_NAME>' -Verify
   ```
   Then verify before continuing: `00-discovery.md` exists and is non-trivial; `00-files-read.txt` exists and lists the files reviewed; and the VERDICT line the command YOU just ran says COMPLETE. If it says INCOMPLETE, or its reading accounting shows it read only a handful of files, or the refinement rescued several candidates Pass 1 missed, RE-DISPATCH it with the shortfall named -- do not proceed to scope on a shallow discovery, because nothing downstream will catch what it missed. Paste the command's output and the agent's returned discovery summary.

7.6. **Exposure validation (mandatory, after the sweep, before writing 00-scope.md).** Validate the user's Q1 exposure answer against what the sweep and repo map actually surfaced: ingress/edge references (public hostnames, LB/WAF/CDN references, `0.0.0.0` binds, Ingress resources or internet-facing IaC if present in this repo). This is a consistency check on attested facts, not a re-derivation. Record a one-line verdict for 00-scope.md: `Exposure validation: Q1=<answer>; discovery evidence <consistent | CONFLICT: <what the evidence shows>>`. A CONFLICT verdict MUST be surfaced in the step 9 Scope Proposal for the user to adjudicate (the user may know infrastructure this repo cannot show); record their ruling in 00-scope.md. Under PLATFORM-INHERITED infra, thin edge evidence in the repo is normal and is NOT a conflict -- flag a conflict only when found evidence positively contradicts the answer.

7.7. **Write 00-resources.txt (ALWAYS), then archive comparison (completeness cross-check, only when a prior archive exists).** This step has two parts. Part 1 is UNCONDITIONAL and runs on every assessment, including a first run with no prior archive; only Part 2 (the comparison) is gated on a prior archive existing. Do not skip Part 1 just because this is a first run.

   Part 1 (always): write `{PROJECT_NAME}-threat-model/00-resources.txt`: this run's own final DISTINCT resource list in machine-readable form, one per line, two tab-separated columns: `type<TAB>canonical name`, where type is one of `bucket|table|database|queue|topic|cache|agent|external-api|identity-provider|secret-store|service|other`. CANONICAL NAME FORMAT (pin this exactly, or cross-run comparison produces false diffs): the canonical name is the BARE resource identifier as it literally appears in the code or IaC -- the actual bucket name, table name, queue name, hostname, or service id -- lowercased, with NO type word or prefix (write `filings-documents`, never `s3 filings-documents` or `bucket:filings-documents`; the type lives in its own column), NO surrounding quotes, and NO environment decoration added or stripped beyond what the identifier literally contains. One line per distinct resource. Sort the file. This exact-string discipline is what lets a later run's `Compare-Object` detect real drift instead of formatting noise. Its line count MUST equal the distinct-list count in 00-discovery.md (state both, per Operating Rule 15). It is written here, before the comparison below, so this step (and every future run's comparison) has this run's own list on disk -- step 8 below no longer writes it (see the note in step 8).

   Part 2 (only when a prior archived run exists): compare this run's 00-resources.txt against the most recent archive, as follows.

   Run the comparison script (one call; use YOUR shell's invocation form per common.md rule S):
   ```powershell
   & '<SKILL_DIR>\scripts\archive-compare.ps1' -Workspace '<WORKSPACE>' -ProjectName '<PROJECT_NAME>'
   ```
   It finds the most recent archived run, picks the comparison basis (the archive's `00-resources.txt`, or its `01-inventory.md` element names as a weaker name-only fallback, or reports that it cannot be compared), and prints the FOUR sets described below plus both resource counts. If no archive exists it says so and you skip to step 8 without writing 00-archive-comparison.md. Paste its output.

   Write the result to `{PROJECT_NAME}-threat-model/00-archive-comparison.md` with the Write tool (common.md rule W): which archived run was compared (name, LastWriteTime), the comparison basis (00-resources.txt name column, the 01-inventory.md fallback, or "could not be compared" with the reason), and the FOUR named sets in full, not just counts -- (1) in prior/not in current (DISCOVERY drift / possible regression), (2) in current/not in prior (new), (3) same name/different type (CLASSIFICATION drift -- the same resource re-binned, e.g. a fetched-from source corrected from data-store to external-api; NOT a missed resource), and (4) unchanged. This is a completeness cross-check, not an auto-merge: never silently pull a prior run's resource into this run's scope on the strength of this comparison -- every "in prior, not in current" item is surfaced as a question for the user, never merged in automatically.

   The "in prior, not in current" set is a possible completeness REGRESSION (something the prior run found that this run missed) or a legitimately removed/decommissioned resource -- either way it MUST be investigated or explained before scope closes, so it is REQUIRED to also appear in the step 9 Scope Proposal as an explicit question for the user to adjudicate at GATE 1: the user may know a resource was decommissioned, or may recognize a real miss that sends discovery back for another look. Record the user's ruling on each item in 00-scope.md.

8. **Write a scoping note** to `{PROJECT_NAME}-threat-model/00-scope.md`. PRECONDITION (do not write this file until all of it holds): steps 7 (both passes + refinement), 7.5, 7.6, and 7.7-Part-1 have completed and their artifacts exist on disk -- `00-discovery.md`, `00-discovery-raw.txt`, `00-candidates.txt`, `00-density.txt`, and `00-resources.txt`. 00-scope.md is a synthesis OF those artifacts; writing it before they exist produces a scope guessed from memory, not derived from discovery (a field-observed failure). If any artifact is missing -- e.g. the sweep did not finish -- STOP and complete discovery first; do not write a partial scope. The note captures `PROJECT_NAME`, `WORKSPACE`, the detected repo type (and which classification rule fired), languages/frameworks with evidence, deployment exposure (from step 6) with the step 7.6 exposure-validation verdict line, the data stores and external integrations -- every distinct item from 00-discovery.md triaged as in-scope or out-of-scope-with-reason (nothing from the sweep silently absent), split into IaC-defined (schema/config in this repo's infrastructure files) and runtime-referenced (named in application code but not in this repo's IaC; cite the referencing source file) so the code-vs-IaC provenance is visible, the infrastructure ownership mode (Q6: SELF-MANAGED or PLATFORM-INHERITED -- and when PLATFORM-INHERITED, state explicitly that the platform's internal configuration is inherited and assessed elsewhere, reproduce the Q6a attested platform profile verbatim so later phases can cite it, and note that the app's side of every data flow plus attested exposures remain in scope), in-scope components, and explicit out-of-scope items (e.g., vendored third-party code under `node_modules/`, `vendor/`, `target/`, `.venv/`; tool-state directories such as `audit_state/` from the CodeSecurityAudit prompt and `{PROJECT_NAME}-threat-model/` from this prompt's own prior runs). Every item in this list is MANDATORY: a scope note missing any of them is a rule violation, not a style choice. Classify each data store vs external integration by the DS-vs-EXT ownership test (Phase 1 output schema, Section 3) -- the operator question: content this system owns = data store even on managed infrastructure; service another party operates with this system as client = external integration even if this system only fetches data from it (a scraped/fetched-from remote source is an EXT, never a data store -- the fetch trap; the place fetched data lands is a separate DS). Achieve brevity through terseness per item, never by omitting an item -- Operating Rule 9's token budget governs reading, not this file's completeness. Write the file with the Write tool (common.md rule W).

   `{PROJECT_NAME}-threat-model/00-resources.txt` was already written in step 7.7, before the archive comparison that step performs against it. This is the cross-run comparison artifact: any later run (or a second pass of this one) is unioned against it with `Compare-Object (Get-Content run1) (Get-Content run2)` -- so both discovery drift AND classification drift between runs become visible mechanically. Confirm here that its line count still equals the distinct-list count in 00-discovery.md (state both, per Operating Rule 15); do not rewrite it unless that count is wrong.

9. **Print a Scope Proposal.** OPEN IT WITH A DISCOVERY COVERAGE BLOCK, before the scope contents. GATE 1 is the user's one chance to reject a shallow discovery before four phases are built on it, and they cannot judge that from a component list -- they need to see how much was actually read. Reproduce, verbatim, the `readset.ps1 -Verify` output from the run YOU performed in step 7 (the per-class enumerated / read / unread table and its VERDICT line), plus the application-signal-file reconciliation and the count of rescued candidates Pass 1 missed. Then state one plain-language line the user can act on, e.g. `Discovery read 214 of 214 required files across 6 classes; 0 unread; 2 candidates were rescued by the sweep that Pass 1 had missed.` If the verdict is anything but COMPLETE, or rescued-missed is more than a couple, SAY SO FIRST and recommend re-running discovery rather than approving -- do not bury it under the scope contents. Never hand the user a command to run: you have already run the verification yourself, and the coverage block is your report of what it returned. Lead with the plain-language line -- the user should be able to accept or reject the discovery without reading a table or knowing what a read set is.

   Then present the same information from step 8 plus any ambiguity that requires a user decision (multi-service monorepo -- which service? unclear scope boundaries?), any step 7.6 exposure-validation CONFLICT stated explicitly as a question for the user to adjudicate, and -- when step 7.7 found a prior archive -- its "in prior, not in current" set stated explicitly as a question for the user to adjudicate (regression or legitimate removal). This is the proposal the user reviews before Phase 1 begins.

10. **Update STATE.md.** Mark `phase-0: complete` with the current timestamp, set Last Completed Step to `phase-0 -- scope proposal written to 00-scope.md`, set Resume Instruction to `Begin at Phase 1 (Documentation, Diagram, and Source Analysis).`

**Phase 0 Completion Banner:**
```
=== PHASE 0 COMPLETE: SCOPE PROPOSAL READY ===
WORKSPACE    = <path>
PROJECT_NAME = <name>
OUTPUT_ROOT  = <path>\<name>-threat-model
Output directory excluded from source repo git tracking: [yes/no]
Scope file written: <name>-threat-model\00-scope.md
File manifest written: <name>-threat-model\00-file-manifest.txt (<N> files -- Phase 1 will account for every one)
Pass 1 investigation: <N> of <N> source files read | docs read IN FULL <N> of <N> (must be equal) | entry points: <list> | <N> resources found
Pass 1 read-set verify: <COMPLETE | INCOMPLETE -- N floor files unread>  (tool-computed by readset.ps1 -Verify, run by the ORCHESTRATOR)
Application signal files: <N> | accounted (read+bucketed): <N> | unaccounted: 0
Rescued candidates Pass 1 missed: <N> (0 = passes agree; high = reading was thin)
Pass 2 sweep: <N> candidates (tool-computed) | refinement: <N> accounted, <N> rescued | top-10 density read: <10/10>
Resources: <N> written to 00-resources.txt (line count matches distinct list: yes)
Exposure validation: <consistent | CONFLICT -- see Scope Proposal>
Archive comparison: <no prior archive | compared vs {name}: <N> new, <N> only-in-prior (see Scope Proposal)>
STATE.md updated: phase-0 marked complete.
Present this Scope Proposal to the user and wait for approval or corrections (GATE 1).
```

---

After the user approves the Scope Proposal, run `& '<SKILL_DIR>\scripts\partition-manifest.ps1' -Workspace '<WORKSPACE>' -ProjectName '<PROJECT_NAME>'` (your shell's form per common.md rule S) and paste its reconciliation line. The three partition files drive the parallel Phase 1 passes.
===== END FILE: references/phase-0.md

===== BEGIN FILE: references/phase-0-discovery.md
<!-- SKILL VERSION: v25-skill (2026-07-24g) -- methodology carved verbatim from PROMPT VERSION v24 (2026-07-16a) -->

# Phase 0 Discovery -- Exhaustive Element Discovery (SUBAGENT)

You are the Phase 0 DISCOVERY agent. You have a full, dedicated context window and ONE
job: find every architectural element this repository contains or references. Nothing
else competes for your attention -- no user dialogue, no orchestration, no later phases.
USE THAT BUDGET. Reading deeply is the work; a run that finishes quickly on a large
repository has failed, not succeeded.

Everything downstream inherits what you find here. A resource you miss is not threat-
modeled at all: it will not appear in the inventory, will get no STRIDE walk, and will
be absent from the final report -- silently, with no reconciliation anywhere catching it.
This is the single highest-leverage step in the entire workflow.

Read your rehydration inputs first: 00-scope.md does not exist yet, so your inputs are
STATE.md (for the run's user-supplied answers) and 00-file-manifest.txt (the authoritative
list of every file in scope). Write your output to 00-discovery.md plus the sweep
artifacts named below.

## Your task: identify the primary language(s), framework(s), build system(s), and the concrete elements in scope -- only from files you have directly observed. Look for `package.json`, `pom.xml`, `*.csproj`, `go.mod`, `requirements.txt`, `Cargo.toml`, `*.tf`, `Dockerfile`, `*.yaml` (k8s/helm), etc. Use the Read tool for each detection file and cite with evidence paths relative to the workspace root. "Identify" here means ENUMERATE BY CONCRETE IDENTITY, not "name the stack": list each service/process, each data store, each external integration, each secret location, and each pipeline/workflow you can see at scope level, by its actual name/id -- not a count. A generic quantifier standing in for a list ("several agents", "various services", "multiple buckets", "etc.") is a rule violation, not shorthand: if you are about to write "several X", stop and enumerate every X (use the Grep tool -- or Select-String -- to find them all, then read the relevant ranges; common.md rule R). This is generic to any stack -- the element TYPES are fixed, the instances are whatever this repo actually contains.

   EXHAUSTIVE DISCOVERY -- run BEFORE scope so nothing is excluded by never being found. The highest-miss category is RUNTIME-REFERENCED resources (data stores, buckets/tables, queues, agents, external APIs, secrets the application CODE or DOCS reference but that are NOT in this repo's IaC -- common under PLATFORM-INHERITED infra). Discovery is TWO INDEPENDENT PASSES plus a REFINEMENT -- belt and suspenders by design. The passes use DIFFERENT mechanisms with different blind spots: comprehension (Pass 1) understands everything it reads but cannot read everything; the mechanical sweep (Pass 2) touches everything but understands nothing. Run them independently -- do not let one steer the other -- and merge them in the refinement, where each catches what the other missed.

   PASS 1 -- SOURCE INVESTIGATION. This is the PRIMARY method and where MOST of this phase's effort belongs. Read the source like the security architect you are. Start from the entry points and main modules, follow their imports and references outward, and read deeply -- Operating Rule 9 ranges for files over ~2000 lines, full reads otherwise.

   THE MANDATORY READ SET -- COMPUTE IT FIRST, BEFORE YOU READ ANYTHING. "Read deeply" is not a stopping condition, and a field run satisfied it with SIX files. So your FIRST action in this pass is to run the read-set script, which classifies the manifest into the role-based classes below and writes `00-readset.txt`:
   ```powershell
   & '<SKILL_DIR>\scripts\readset.ps1' -Workspace '<WORKSPACE>' -ProjectName '<PROJECT_NAME>'
   ```
   (bash shell: use the `powershell.exe -NoProfile -ExecutionPolicy Bypass -File ...` form, common.md rule S.) That file is your floor. It is COMPUTED, not chosen by you, and every file in it is READ IN FULL.

   AS YOU READ, LOG IT -- THIS IS A DELIVERABLE, NOT BOOKKEEPING. Append every file you read, floor files and investigation files alike, to `{PROJECT_NAME}-threat-model/00-files-read.txt`, one relative path per line. It is the RECORD OF WHAT WAS REVIEWED: without it there is no list of what discovery actually looked at, nothing can be verified, and a reviewer cannot tell a thorough pass from a shallow one. A completion summary that says "read N key files" instead of producing this file is not an acceptable substitute -- write the file.

   THE FLOOR IS SMALL ON PURPOSE, AND IT IS NOT THE WHOLE JOB. It holds only what a
   mechanical pattern cannot substitute for -- where the system starts, how it is configured
   per environment, who it trusts, what it calls out to, and what its authors wrote down.
   Ordinary application source and view files are NOT in it: the Pass 2 sweep reads every one
   of them mechanically, and the density refinement sends you into the highest-signal ones.
   That division is deliberate. Finding an external integration is a pattern problem (a URL
   is a literal string); reading is for what patterns cannot do -- dynamically-built names, a
   resource named only in a comment, and above all UNDERSTANDING how the pieces connect. Read
   the floor completely, then investigate outward as far as the system's structure warrants.

   The read set is achievable BY CONSTRUCTION: high-cardinality classes are signal-filtered by the script (a view or source file with no external reference is deferred, mechanically, and listed in 00-readset-deferred.txt), so the floor is the files that can actually contain an integration -- not every file in the repo. It is meant to be met, not sampled. If the floor still looks large, that is the repo telling you the truth about its integration surface.

   YOU DO NOT ISSUE A VERDICT ON YOUR OWN COVERAGE. Do not write "VERDICT: COMPLETE", "depth:
   adequate", or any verdict-shaped sentence about how much you read -- not even a true one.
   Coverage is a computed fact, not an impression, and the orchestrator computes it by
   diffing 00-readset.txt against your 00-files-read.txt after you return. A field run wrote
   `Verdict: COMPLETE (all critical integration points identified and enumerated)` -- which
   is not this script's output, is a different claim than the one being verified (files read,
   not integrations found), and read as verification while being an opinion. If you find
   yourself composing a sentence that ASSESSES your own thoroughness, stop: that sentence is
   not yours to write.

   WHAT YOU REPORT INSTEAD, as plain facts the orchestrator can check against the artifacts:
   the number of files you read (which must equal the line count of 00-files-read.txt), the
   number of further files you read beyond the floor, and anything you could not read and
   why. Nothing evaluative.

   You may run the verification yourself while working, to find out what you still owe:
   ```powershell
   & '<SKILL_DIR>\scripts\readset.ps1' -Workspace '<WORKSPACE>' -ProjectName '<PROJECT_NAME>' -Verify
   ```
   (bash shell: the `powershell.exe -NoProfile -ExecutionPolicy Bypass -File ...` form, rule S.)
   Use it as a worklist -- it names the floor files you have not read yet. Keep reading and
   re-running until it stops naming files. But its output is a tool result to act on, not a
   verdict for you to restate.

   The classes the script computes, defined by ROLE rather than any framework's vocabulary -- it matches on whatever your stack calls them:
   - ENTRY POINTS -- however this stack expresses them: `main`/`app`/`index`/`Program`/`Startup`, route or endpoint registration, serverless handlers, queue consumers, scheduled/cron jobs, CLI commands, webhook receivers. Every one, not the first one you find.
   - CONFIGURATION AND ENVIRONMENT FILES, INCLUDING PER-ENVIRONMENT OVERLAYS -- `values-<env>.yaml`, kustomize overlays and patches, `.env*`, `appsettings*.json`, `config/*`, per-env `*.tfvars`, CI/CD environment blocks, ConfigMap/Secret manifests. Read the OVERLAY, not just the base file: an endpoint frequently appears ONLY in the production overlay while the base carries a placeholder or a dev stub. A production-only endpoint is a first-class integration.
   - AUTHENTICATION AND AUTHORIZATION -- any file whose name or path carries `auth`, `oauth`, `oidc`, `saml`, `sso`, `login`, `token`, `jwt`, `session`, `identity`, `principal`, `permission`, `policy`, `guard`, `middleware`. These name the identity providers and trust boundaries the whole model rests on.
   - EXTERNAL CLIENT / INTEGRATION FILES -- names or paths carrying `client`, `gateway`, `adapter`, `connector`, `provider`, `integration`, `api`, `service` where the file talks OUT of this system.
   - CLIENT-SIDE AND VIEW FILES -- templates, views, components, pages, and browser-delivered source (`.html`, `.jsx`/`.tsx`, `.vue`, `.svelte`, Razor/Blade/Jinja/ERB, static JS under a web/public/assets dir). Third-party integrations live here as `<script src>` tags, SDK and widget initialization, analytics and tag managers, payment or auth iframes, map/CDN/font hosts, and browser-direct `fetch`/XHR to a third party. A browser-to-third-party call IS an external integration of this system -- it carries this system's data or identity to another party -- and no server import graph will ever show it to you.
   - ALL DOCUMENTATION, at any depth, in full (`README*`, `*.md`, `ARCHITECTURE*`, `DESIGN*`, `SECURITY*`, `THREAT*`, `docs/`, `doc/`) -- a prose sentence like "integrates with the Acme Payments API" matches no pattern.

   Do NOT sample these classes. There is no "representative subset" of your entry points or your environment overlays -- a floor expressed as a fraction becomes a ceiling, and the class you sampled is the class you half-read. If a class is genuinely too large to read in full (hundreds of view files), read it in full where the sweep shows signal and bucket the remainder BY NAME with a reason, so the shortfall is visible and countable rather than silent.

   Beyond the floor, INVESTIGATE: walk imports outward from the entry points, follow references, and read what the system's own structure tells you matters. The floor guarantees coverage; the investigation is where comprehension finds what no list could name -- dynamically-constructed resource names, a resource mentioned only in a comment, an integration implied by prose.
   THIRD-PARTY SERVICES ENTER AS DEPENDENCIES, NOT ONLY AS URLS. When you read the dependency
   manifests, treat every third-party package that reaches a network or handles this system's
   data as an EXTERNAL INTEGRATION in its own right -- monitoring and APM agents, analytics and
   tag managers, error/crash reporters, payment and auth SDKs, feature-flag and CDN clients,
   email/SMS providers. A package reference contains no scheme, no host and no TLD, so no
   pattern in the sweep can see it; reading the manifest is the only way it is ever found, and
   a monitoring vendor was missed in the field for exactly this reason. Name the vendor and
   cite the manifest line.

   CITE THE SOURCE, NEVER OUR OWN ARTIFACT. Every element's evidence is a `file:line` in the
   REPOSITORY. Never cite `00-hosts.txt`, `00-candidates.txt` or `00-discovery-raw.txt` as the
   evidence for a resource -- those are this run's derived intermediates, not the system. When
   the sweep is what surfaced a resource, open 00-discovery-raw.txt, take the `path:line` it
   records, and cite THAT (reading the line in context first, so you can say what the resource
   is and who uses it).

   Extract every element BY CONCRETE IDENTITY as you go: every service/process, data store, bucket, table, queue, agent, external endpoint, integration, and secret surface the code defines or references. Record every finding with `file:line` (or `doc:section`) evidence.

   THE SWEEP IS NOT A SUBSTITUTE FOR THIS PASS, AND FINISHING FAST IS A FAILURE SIGNAL. Pass 2 runs in seconds and produces tidy artifacts; that tidiness invites the belief that discovery is handled. It is not -- a mechanical pattern cannot recognize a resource it has no literal string for, which is precisely the category that has been missed in field runs. If you find yourself reaching step 7.5 having read only a handful of files, you have skipped this phase's actual work, not completed it efficiently.

   PASS 1 READING ACCOUNTING. Do not hand-write these numbers -- paste the `-Verify` output above, which computes them from 00-readset.txt and 00-files-read.txt. Then add the one figure the script cannot know:
   `Investigation beyond the floor: <N> further files read`
   The depth verdict is NOT yours to assert -- it is the script's VERDICT line. COMPLETE means the floor was read; INCOMPLETE means it was not, whatever your impression of the run. Never write "adequate" over an unrun or failing check.
   A COMPLETE verdict means the floor was read. It does NOT by itself mean the pass was thorough: the floor is the minimum, and the investigation beyond it is where comprehension finds what no file-name rule could ever enumerate.

   Scope: read only what is in 00-file-manifest.txt. The manifest already excludes this workflow's own output, `audit_state*`, `security_architecture_audit.md`, and vendored/generated directories; those are out of bounds for exploratory reads too, not just manifest-driven ones (Operating Rule 13a -- the sole exception is step 7.7, which reads a prior run's `00-resources.txt` only).

   PASS 2 -- MECHANICAL SWEEP (the SAFETY NET, not the method; tool-side, zero judgment, seconds of work). It catches literal strings Pass 1's reading may have walked past. It cannot catch anything else, and it is not evidence that discovery happened. Run it via `scripts/sweep.ps1`, which applies these nine patterns (language-agnostic -- extend per-stack, never shorten) case-insensitively over the manifest. The script handles its own scale mechanics -- it skips bulk-data/binary/generated files and caps candidate harvesting on saturated patterns, all documented in the script header; a `SATURATED` line in its output is expected on a large repo, not an error, and `-MaxFileKB`/`-SaturationCap`/`-CandidateCap` are there if a repo needs tuning. The nine patterns:
   - `://`  (every URI and connection string, any protocol/language: https, postgres, redis, mongodb, amqp, s3, ...)
   - `s3|bucket|dynamodb|sqs|sns|kinesis|rds|redis|kafka|rabbitmq|mongo|postgres|mysql|elastic|queue|topic`  (service names, language-agnostic; extend the list if the stack has others, never shorten it)
   - `secret|password|token|api[_-]?key|access[_-]?key|credential`  (secret/credential surfaces)
   - `\.client\(|\.connect\(|new \w+Client|createClient|connectionString`  (client/connection construction)
   - `_URL|_URI|_HOST|_ENDPOINT|_ADDR|_SERVER|_BROKER|_DSN|_QUEUE|_TOPIC|_BUCKET|_TABLE`  (config/env-var KEYS that wire external services -- CRITICAL under PLATFORM-INHERITED infra, where the endpoint is injected at runtime and only the key appears in the repo; catches integrations no URL/hostname pattern can, e.g. a bucket referenced only as `DATA_BUCKET`)
   - `arn:aws`  (AWS resource identifiers; other clouds use the equivalent -- GCP `projects/.../(topics|subscriptions|buckets)`, Azure `/subscriptions/.../resourceGroups/`)
   - `\b(\d{1,3}\.){3}\d{1,3}\b`  (hardcoded IPv4 endpoints; ignore obvious version numbers)
   - `([a-z0-9-]+\.)+(com|net|org|io|cloud|internal|corp|local|gov|mil|edu|us)`  (bare hostnames referenced without a scheme, incl. `.svc.cluster.local` k8s services and government endpoints like `login.gov`; noisiest pattern -- dedupe and keep only host-like matches; extend the TLD list if the org uses others, never shorten it)
   - `getenv|environ\[|process\.env`  (env-var ACCESS calls -- complements the key-suffix pattern above by catching lookups whose key name matches no suffix, e.g. `os.environ["AGENTS"]`)

   These nine patterns are implemented in scripts/sweep.ps1; to extend them per-stack, note the additions in 00-discovery.md and run the extra patterns yourself (Grep tool, or Select-String), appending their hits to the artifacts.

   Capture everything in variables and write three artifacts -- no display, no `-First` caps (truncation belongs to exploratory reads only, common.md rule R (cap litmus)), no per-line narration; this whole pass is one code block:
   ```powershell
   & '<SKILL_DIR>\scripts\sweep.ps1' -Workspace '<WORKSPACE>' -ProjectName '<PROJECT_NAME>'
   ```
   Paste its per-pattern counts and candidates line.
   The artifacts: `00-hosts.txt` is the COMPLETE deduplicated list of every host/endpoint the sweep saw, with occurrence counts -- read it in full and account for every host in it; never grep the raw file for hosts and never cap a read of it (common.md rule R). `00-discovery-raw.txt` is every unique match site WITH its path (a bare line divorced from its file turns a real resource reference into an unrecognizable code fragment -- field-proven); `00-density.txt` ranks files by match count; `00-candidates.txt` is every mechanically-extracted name -- match values, quoted no-whitespace literals, and value tokens after `=` or `:` (resource names never contain spaces, so most prose junk dies in the regex, not in your judgment).

   REFINEMENT -- MERGE THE TWO PICTURES (mandatory, before step 7.5). This is where belt and suspenders check each other:
   (a) Density accounting -- TOTAL, not top-N. Use `00-density-app.txt`, the APPLICATION-only ranking (the sweep classifies vendor/generated paths and library filenames out mechanically, because a raw ranking is dominated by third-party libraries full of URLs -- a field run spent its entire "top 10" budget on vendor code and learned nothing). Every file in 00-density-app.txt ends in exactly one of two states: READ (its match sites read in context and its elements extracted -- a full read if it is dense or central) or BUCKETED with a one-line reason (test fixture, generated, sample/demo data, duplicated template). There is no third state and no arbitrary cutoff: a cutoff is what let a real integration sit at rank 11 unread. State the reconciliation: `application signal files: <N> | read: <N> | bucketed: <N> (reasons: ...) | unaccounted: 0`. Unaccounted must be zero. Matches concentrate where resources live -- an unaccounted signal-bearing application file is precisely where a missed integration hides.
   (b) Candidate reconciliation: reconcile every candidate in 00-candidates.txt, but scale HOW you reconcile to the candidate count -- a large repo yields hundreds of candidates even after the sweep's saturation cap, and a row-per-candidate hand-walk does not scale to that. Every candidate ends in exactly one of these dispositions, and the count MUST reconcile (see the tally below), but only the last group needs individual attention:
   - ALREADY-IN-FINDINGS: the candidate is a resource you already found in Pass 1 (exact or clear semantic match). Bulk-count these; do not write a row each.
   - DUPLICATE: a spelling/casing/substring variant of another candidate or finding. Bulk-count.
   - NOISE: mechanically-obvious non-resources -- single common words, language keywords, framework identifiers, file extensions, pure numbers, boilerplate tokens. Bulk-count by this category with a one-line rationale (e.g. "412 noise: language keywords, HTML tag names, and single-word tokens"); do not write a row per noise token. HARD GUARD -- a RESOURCE-SHAPED name may NEVER go in this bucket, however noisy the run: if a candidate contains a dot, hyphen, underscore, slash, or colon, or is camelCase, or reads like an identifier someone provisioned (`prod-filings-docs`, `svc.internal`, `DATA_BUCKET`), it is NOT mechanically-obvious noise -- it goes to PLAUSIBLE-UNKNOWN and gets looked at. This guard exists because the one resource this workflow has missed in field run after field run was exactly that shape, and bulk-dismissal is how a real bucket name disappears without anyone deciding to drop it.
   - PLAUSIBLE-UNKNOWN (the residual that gets individual treatment): a resource-like name (a service/host/bucket/table/queue/endpoint/secret shape) that is NONE of the above. For EACH of these -- and only these -- run a targeted search for that name (Grep tool, or `Select-String -Pattern '<candidate>'`), read the hit in its file context, and decide: real resource (add to findings) or explained-away (state why). NEVER dismiss a plausible-unknown name unread. This residual is normally small even on a huge repo; if it is itself very large, that is a signal the sweep patterns are matching something structural you should investigate as a group.
   Record in 00-discovery.md a triage TALLY (not necessarily a row per candidate): `candidates: <N> (tool-computed) = already-in-findings <A> + duplicate <B> + noise <C> + plausible-unknown <D>` where `A+B+C+D` MUST equal N (state the arithmetic). Write an individual triage row for each of the <D> plausible-unknowns (that table's row count == D), plus the bulk counts for A/B/C. The invariant is preserved -- every candidate is accounted, and the arithmetic proves none were silently dropped -- but only the plausible residual is investigated one by one.
   (c) Note the findings only Pass 1 produced (nothing mechanical could catch them) -- that is comprehension's contribution and the reason both passes exist.
   (d) UNDER-READ SIGNAL -- the self-verification loop. Compare Pass 1's list of external services against the candidates the refinement rescued. Every rescued candidate that turns out to be a real service, endpoint, or provisioned resource AND was absent from Pass 1's findings is evidence that Pass 1 UNDER-READ -- not merely a fact to append. Treat it as a symptom with a location: go to the file where Pass 2 found it, read that file and its neighbours properly, and extract whatever else is there, because a file that hid one integration from you is likely hiding its siblings. State the count: `rescued candidates that Pass 1 missed: <N>`. Zero means the two mechanisms agree and the pass is sound. A non-zero count is the strongest evidence available that reading was too thin -- if it is more than a couple, say so in your summary and go back and read; do not simply carry the rescued items forward and call discovery complete.
   State the refinement result verbatim: `candidates: <N> (tool-computed) | accounted: <N> (=already-in <A> + dup <B> + noise <C> + plausible <D>) | rescued by refinement: <N> | Pass-1-only finds: <N> | top-10 density files read: <10/10>`.

   Write everything to `{PROJECT_NAME}-threat-model/00-discovery.md`: the per-pattern match counts, the Pass 1 source/doc file lists, the candidate triage table, the refinement result line, and the merged DISTINCT list of external services / data stores / endpoints / integrations found (Pass 1 finds + rescued candidates), each with `file:line` or `doc:section`. This file -- not memory or judgment -- is the authoritative "what exists" list that scope triages and Phase 1 inventories. Completeness = both passes run, every candidate triaged (counts stated), every doc read -- shown, not felt.

## Completeness self-audit (mandatory, before you return) For each element category -- services/processes, data stores, external integrations, secrets/credentials, pipelines/workflows -- answer: have I enumerated every instance by concrete identity, or did I summarize with a count or a generic quantifier? If any category is a count or a generic word rather than a full list, go back and read the relevant files until it is a full list. Then RECONCILE against 00-discovery.md: every distinct external service / data store / endpoint the sweep found MUST appear either in your enumerated in-scope elements OR explicitly marked out-of-scope with a reason -- a discovered item that is neither is a silent drop, the exact failure the sweep exists to prevent. State the audit result: `Enumerated by identity: services <yes>, data stores <yes>, integrations <yes>, secrets <yes>, pipelines <yes>; generic quantifiers remaining: <none | list them and fix>; sweep categories run (per 00-discovery.md): <list>; discovered items unaccounted for (neither in-scope nor consciously excluded): <none | list -- rule violation>`. Note the division of labor: Phase 0 establishes the complete SCOPE (which concrete elements exist and are in bounds); Phase 1 builds the full architectural INVENTORY (their relationships, evidence, and file-level accounting) -- Phase 1 owns the deep inventory, but it can only be as complete as this scope, so do not defer enumeration to Phase 1 on the assumption it will backfill what you left generic here. Finally, reconcile against 00-candidates.txt: every candidate the refinement triaged as a resource MUST appear in the scope as in-scope or out-of-scope-with-reason -- a resource candidate that is neither is a silent drop.
===== END FILE: references/phase-0-discovery.md

===== BEGIN FILE: references/phase-2c.md
<!-- SKILL VERSION: v25-skill (2026-07-21a) -- methodology carved verbatim from PROMPT VERSION v24 (2026-07-16a) -->

### Phase 2C -- Exclusions, Coverage, and Consolidation

#### Phase 2C Rehydration (MANDATORY FIRST STEP)

Read STATE.md, 00-scope.md, 01-inventory.md, 02a-context.md, and 02b-threats.md. (00-scope.md informs the 02-threats.md header's deployment exposure line.)

Read these files with the Read tool (disk content overrides memory): STATE.md, 00-scope.md, 01-inventory.md, 02a-context.md, 02b-threats.md, and 02b-excluded.md (the excluded-candidate working list Phase 2B wrote -- it is the VERBATIM source for the Excluded Threats Ledger below; you carry its rows forward, you do not reconstruct them from counts).

STATE.md is orchestrator-owned. Do not read-modify-write it.

#### Phase 2C Work

Two outputs in this sub-phase:

**Output 1: `02c-assumptions.md`** -- the exclusions ledger, control coverage, assumptions, and the threat filtering summary.

Required sections:

```markdown
# Phase 2C -- Exclusions and Coverage

## Threat Filtering Summary
- Total threats identified during STRIDE matrix walk: <N>
- Threats included in the model: <N> (there is no target count -- emit only what survives the Phase 2B tests; a total above ~15 is a signal the filters were too loose, not a limit to trim to)
  - Confirmed (main table): <N>
  - Likely (main table): <N>
- Threats not promoted to the main table:
  - <N> Medium severity (excluded per scope constraints)
  - <N> Low likelihood (not realistic for this system)
  - <N> Not exploitable (the prerequisite already granted the impact -- Phase 2B already-compromised test)
  - <N> Rejected at review (the user removed it at the Phase 2B threat review gate)
  - <N> Fully mitigated (no residual risk; code/IaC-verified controls only)
  - <N> Attested-mitigated (unverified) (suppressed only by a Phase 0 attested control; routed to the code audit as a verification lead)
  - <N> Out of scope (e.g., client-side only, physical security)
  - <N> Code-level (routed to the code security audit via the Excluded Threats Ledger)
  - <N> Unverified (plausible but not grounded in the System Map; routed to the code audit via the ledger)

## Excluded Threats Ledger
BUILD THIS FROM `02b-excluded.md`, NOT FROM MEMORY OR COUNTS. Phase 2B wrote every excluded candidate to `02b-excluded.md` (one line: `component ID | STRIDE category | short title | exclusion reason`). Carry each of those lines forward into one ledger row here, verbatim in substance -- assign the `EX-NN` id, map the four fields to the columns, and expand the exclusion reason to satisfy the per-reason requirements below. Do NOT reconstruct or guess the ledger from the Filtering Summary's rolled-up counts: the counts tell you HOW MANY rows to expect, `02b-excluded.md` tells you WHICH candidates they are with 2B's actual reasoning. If `02b-excluded.md` is missing or its line count is less than the not-promoted total, STOP and report it (Phase 2B did not persist the working list) rather than inventing rows to hit the count.

One row per candidate threat that was considered during the Phase 2B matrix walk but not promoted to the main table -- excluded (severity, likelihood, scope, or full code/IaC-verified mitigation), suppressed only by an attested control (`Attested-mitigated (unverified)`), or admitted-but-Unverified (architecturally plausible, but its asset or path could not be grounded in the System Map). This ledger exists so a downstream code audit (COORDINATED mode) can distinguish "considered and not promoted" from "never considered" -- an audit finding that contradicts a "fully mitigated" exclusion, that verifies (or disproves) an attested mitigation, or that verifies an "Unverified" lead, is a significant result. Keep each row to one line; do not expand into full threat rows.

| ExcludedID | Component | STRIDE Category | Short Title | Exclusion Reason |
|------------|-----------|-----------------|-------------|------------------|
| EX-01 | C-003 | Tampering | SQL injection in admin report filter | Fully mitigated -- parameterized queries verified [evidence: src/admin/reports.go:40-66] |
| EX-02 | C-001 | Denial of Service | Generic volumetric DDoS on edge | Generic-to-all-systems; CDN/WAF absorbs; Low likelihood |
| EX-03 | C-005 | Elevation of Privilege | Reporting export may lack row-level authorization | Unverified -- confirm whether the export query in the reporting service applies a tenant or row-level authorization filter |

Exclusion Reason must begin with one of: `Fully mitigated`, `Attested-mitigated (unverified)`, `Medium severity`, `Low likelihood`, `Not exploitable`, `Rejected at review`, `Out of scope`, `Generic-to-all-systems`, `Code-level`, `Unverified`. A `Rejected at review` row is one the USER removed at the Phase 2B threat review gate; carry it forward exactly as written and do not re-argue it, restore it, or soften the reason -- a threat the reviewer rejected is a decision, not a candidate. A `Not exploitable` row is one the Phase 2B already-compromised test rejected because the prerequisite already granted the impact -- state the prerequisite and what it already gave the attacker, e.g. `Not exploitable -- dominated by prerequisite: L4 cluster admin already reads this secret directly`. These are exclusions, not leads: the code audit does not act on them. For `Fully mitigated` rows, cite the CODE or IaC evidence for the mitigating control -- a user-attested citation alone does not support this reason (Operating Rule 2 asymmetry); if attestation is all you have, the reason is `Attested-mitigated (unverified)`. For `Attested-mitigated (unverified)` rows, name the attested control AND the specific code/IaC check that would verify it, e.g. `Attested-mitigated (unverified) -- Q3 attests Okta SSO fronts this service; verify the ingress/authn middleware for the admin API actually enforces OIDC` -- the code audit consumes these as seeded verification leads. For `Code-level` rows, add one clause naming the suspected defect and its location so the partner code audit can use the row as a seeded lead. For `Unverified` rows, add the specific question a reviewer or the code audit would answer to confirm the threat (the content earlier prompt versions recorded in an Inferred table's WhatWouldConfirm column), e.g. `Unverified -- confirm whether the reporting export applies a row-level authorization filter`.

Ledger completeness (mandatory reconciliation -- this ledger is where a rich foundation produces the most content and is the most likely thing to truncate): the ledger MUST contain exactly one row for every candidate counted as not-promoted in the Threat Filtering Summary above (the sum of the Medium / Low likelihood / Not exploitable / Rejected at review / Fully mitigated / Attested-mitigated (unverified) / Out of scope / Code-level / Unverified counts). Before finishing 2C, state the check verbatim: `Ledger rows: <N>; 02b-excluded.md lines: <N>; not-promoted candidates in Filtering Summary: <N>; match: <yes | DEFICIT of X rows -- truncation, fix before finishing>` (all three counts must agree). A ledger shorter than the sum is a truncation, not a small exclusion set -- a rule violation to repair, never to accept. With a rich inventory this ledger routinely exceeds 30 rows; write it as the LAST section of 02c-assumptions.md, and if it is long, append its rows in a separate Edit tool step so it is never dropped when the file is first generated.

## Control Coverage Summary
The reverse index from governance-framework controls to the threats whose Mitigation cites them. Build it by extracting every parenthesized control identifier from the main threat table's Mitigation column (for NIST 800-53 the `AC-3` / `SC-8(1)` form; other Q5 frameworks use their own identifier form). One row per distinct control; sort by Count descending, then control ID. This is the "which controls keep recurring" view -- heavily-cited controls and families indicate where the system's protection gaps concentrate.

| Control | Name | Family | Cited By | Count |
|---------|------|--------|----------|-------|
| AC-3 | Access Enforcement | AC | 01, 04, 09 | 3 |
| SC-8 | Transmission Confidentiality and Integrity | SC | 02, 07 | 2 |

## Assumptions Made
- <Assumption about security controls, architecture, or deployment, with the gap that drove the assumption>
- ...

## Coverage and Known Gaps
Copied from 01-inventory.md's Coverage Report (2C rehydration already reads that file): files read <N>, files skipped <N> with reasons, and every known gap with a one-line explanation of what could not be fully analyzed and why (e.g., very large files read only in targeted ranges). Honest gaps belong in front of stakeholders -- a threat model that hides what it could not see overstates its own coverage.
- Files read: <N> | Files skipped: <N> (<reasons>)
- Gap 1: <what and why>
- ...
```

**Output 2: `02-threats.md`** -- the canonical, consolidated Phase 2 output that Phase 3 reads. The consolidation is intentionally done with PowerShell rather than by reading each sub-file into the agent's context and writing the union with the Write tool -- the latter forces all sub-files' content through the working window for no reasoning benefit, just file gluing. PowerShell streams the content through the OS and keeps Phase 2C's context cost low.

The `02-threats.md` file should consist of, in order: a header section (title, project name, current date, the System Restatement copied verbatim from 01-inventory.md, one-paragraph summary of threat counts by priority, components reviewed, deployment exposure), then the verbatim contents of `02a-context.md`, `02b-threats.md`, `02c-assumptions.md`.

Steps:

1. Write `02c-assumptions.md` with the Write tool per the schema above.

2. Write the header section to `02-header.md` using the Write tool (title, project name, date, the System Restatement copied verbatim from 01-inventory.md, summary paragraph).

3. Concatenate header + three sub-files into `02-threats.md` with the consolidation script (substitute the literal values from your briefing; use YOUR shell's invocation form per common.md rule S -- from bash, `powershell.exe -NoProfile -ExecutionPolicy Bypass -File ...` with the same parameters):
   ```powershell
   & '<SKILL_DIR>\scripts\consolidate.ps1' -Workspace '<WORKSPACE>' -ProjectName '<PROJECT_NAME>'
   ```
   The script streams the files through the OS (not through your context window), removes the temporary `02-header.md`, prints the input-vs-output byte totals, and FAILS LOUDLY if the result is materially smaller than its inputs. Paste its output.

4. Verify per common.md rule W-d. If `02-threats.md` is missing, zero bytes, or shorter than the sum of inputs, retry the PowerShell step. Do NOT fall back to having the agent read all sub-files and write the concatenation manually -- that defeats the purpose.

Return your completion banner to the orchestrator (it owns STATE.md).

**Phase 2C Completion Banner:**
```
=== PHASE 2C COMPLETE: PHASE 2 CONSOLIDATED ===
  .\{PROJECT_NAME}-threat-model\02c-assumptions.md
  .\{PROJECT_NAME}-threat-model\02-threats.md   <-- canonical Phase 2 output, used by Phase 3
Sub-files retained for recovery: 02a-context.md, 02b-threats.md
Phase status reported to orchestrator (it owns STATE.md).
Return this banner verbatim as the end of your completion summary.
```
===== END FILE: references/phase-2c.md

===== BEGIN FILE: references/phase-4.md
<!-- SKILL VERSION: v26-skill (2026-08-04a) -->

## Phase 4 -- C4 Model and Data Flow Diagrams (draw.io)

### Phase 4 Rehydration (MANDATORY FIRST STEP)

Read STATE.md, 01-inventory.md, and 02-threats.md. Diagrams must be structurally grounded in the inventory (every component, trust boundary, and data flow appearing in a diagram must come from `01-inventory.md`) and annotated with threat IDs from the threat model (every threat ID marker on a diagram must exist in `02-threats.md`).

Read these files with the Read tool (disk content overrides memory): {PROJECT_NAME}-threat-model/STATE.md, {PROJECT_NAME}-threat-model/01-inventory.md, {PROJECT_NAME}-threat-model/02-threats.md.

If either inventory or threats file is missing or empty, STOP and report the error.

Disk content takes precedence over conversation memory. Component IDs (`C-NNN`), trust boundary IDs (`TB-NNN`), data store IDs (`DS-NNN`), external integration IDs (`EXT-NNN`), and threat IDs (`01`, `02`, etc.) must match the IDs in these two files exactly -- do not invent, rename, or re-number any ID.

STATE.md is orchestrator-owned. Do not read-modify-write it.

After reading, acknowledge in one line that you have both files loaded and are ready to generate diagrams.

### YOU WRITE DATA. THE SCRIPT DRAWS.

You do NOT write mxGraph XML and you do NOT compute coordinates. You write ONE data file describing what belongs on each diagram, then run `scripts/render-drawio.ps1`, which emits every `.drawio` file.

This split is deliberate. Layout is roughly fifty coordinates, a dozen four-decimal attachment fractions and a per-edge routing channel, for each of four diagrams. That is arithmetic, an agent doing it by hand on a real system will get some of it wrong, and a single wrong coordinate is a visibly broken diagram. What the diagram should CONTAIN -- which component sits in which tier, which flows exist, which are unprotected, which components a Priority 1 threat touches -- is classification, which is your job and which no script can do.

Everything the script owns, and which you must therefore NOT attempt: page size, the grid of cells every node is placed into (including how many columns a large tier wraps across, and which member goes in which cell), zone container geometry, shape sizes and style strings, edge attachment points, gutter routing and channel allocation, node ordering within the actor and external columns, the legend, and the AI-generation notice. All of it is settled, and all of it was verified by rendering sample diagrams and inspecting the exported images. Do not second-guess it and do not hand-edit the output.

### The data file: `{PROJECT_NAME}-threat-model/04-diagram-data.json`

Write it with the Write tool, in one call, as valid JSON:

```json
{
  "diagrams": [
    {
      "name": "c4-02-container",
      "title": "Container Diagram",
      "nodes": [
        { "id": "C-001", "label": "Web Application", "kind": "component", "tier": "APPLICATION",
          "tech": "Python/Flask", "description": "Serves chart generation requests", "threat": "P1" },
        { "id": "DS-001", "label": "Prod Database", "kind": "store", "tier": "DATA" },
        { "id": "EXT-001", "label": "Bing Maps", "kind": "external", "tier": "EXTERNAL" },
        { "id": "A-001", "label": "End User", "kind": "actor", "tier": "ACTORS" }
      ],
      "edges": [
        { "source": "C-001", "target": "DS-001", "protocol": "TLS/5432", "secure": true, "async": false }
      ],
      "notes": ["C-001 -> APPLICATION tier", "TB-002 reconciled on C-001 -> DS-001"]
    }
  ]
}
```

IDS: USE THE INVENTORY'S, OR A MARKED SYNTHETIC ONE. Every node needs an `id`, and most are inventory ids used verbatim -- `C-001`, `DS-001`, `EXT-001`, `A-001`. But two diagrams legitimately contain elements the inventory does not record, and inventing plausible-looking ids for those makes them indistinguishable from fabrication. Use these instead, and never invent a third form:
- `SYS-001` -- the single block representing THE WHOLE SYSTEM on c4-01. The system as a whole is not a component and has no C-NNN; this is the only node that ever carries it.
- `INT-001`, `INT-002`, ... -- internal elements on c4-03 (layers, middleware, handlers, modules) that are structure INSIDE a component rather than components themselves. Every INT-NNN needs a `file:line` citation in `notes`, per the c4-03 rule below.
A `SYS-` or `INT-` prefix is a promise to the reader that the element is deliberately outside the inventory rather than a lapse, and it lets Validation exclude them from the inventory reconciliation instead of failing the count. If you find yourself wanting an id for something that is neither an inventory element nor one of these two cases, that is the signal that it does not belong on the diagram.

Field rules:

- `kind` is one of `component`, `store`, `external`, `actor` (C4 diagrams) or `process`, `dfdstore`, `external` (the DFD). It selects the shape; you do not supply styles.
- `tier` is one of `ACTORS`, `EDGE`, `APPLICATION`, `DATA`, `SECURED`, `EXTERNAL`, assigned by the decision table below. Column order and containers follow from it.
- `tech` is optional: the technology or framework, rendered on a second line in the C4 convention as `[Container: Python/Flask]`. The type word comes from `kind` -- Container, Process, Database, Data Store, External System, Person -- so supply only the technology.
- `description` is optional: ONE short line saying what the element does, rendered as a third line. Not a sentence about why it matters, not its threats -- what it is. "Serves chart generation requests", not "critical component handling sensitive requests".
  Both are optional and additive: omit them and the box renders exactly as it did before. Take them from the inventory's Type / Language-Framework and Responsibilities fields, which already hold this.
- `threat` is optional: `"P1"` when a Priority 1 threat in 02-threats.md touches that component, `"P2"` for Priority 2, omitted otherwise. This is the ONLY meaning of a red or orange shape border.
- `secure` is `false` when the flow's Encryption is none/plaintext/unknown OR its AuthN is none/unknown, per its row in 02a-context.md. The script draws those as thick red edges, which is the diagram's at-a-glance answer to "what is unprotected".
- `async` is `true` for broker and event-bus flows; the script dashes them.
- `protocol` is the protocol AND NOTHING ELSE -- `HTTPS`, `HTTP`, `AMQP`, `TLS/5432`, or `?` if genuinely unknown. No DF-NNN, no TB-NNN, no data classification, no auth detail. Long edge labels collide with each other and with the shapes; everything omitted here is still in the 02a-context.md data-flow table, which is where a reader goes for detail.
- `notes` is free text rendered in the diagram's notes box. Put the tier you assigned each component (by ID) here, plus any TB-NNN that backs no flow.

Angle brackets in labels and notes are SAFE and no longer need avoiding. Write `List<String>` and "under 5" or "< 5" as they really are. The renderer double-escapes user text -- html-escaped first so the character displays, then xml-escaped for the attribute -- so a literal `<` renders as a character instead of being treated as markup.
  The old ban existed for the wrong reason. A raw `<` never broke the file; every shape style sets `html=1`, so draw.io treated `<String>` as a tag and silently ATE the rest of the label. Text vanishing is harder to notice than a file that fails to open, which is why the rule was written as "do not generate the characters". With correct escaping the workaround is unnecessary, and contorting a name into `List[String]` misrepresents the code.

### COMPONENT-TO-TIER ASSIGNMENT (your judgment, and the main thing you decide)

Assign EVERY component (data stores DS-NNN and external integrations EXT-NNN are components too) to EXACTLY ONE tier by this FIXED decision table, FIRST MATCH WINS, applied in ID order so two runs assign identically:

1. Human actor / user persona (an actor class from the inventory, not a running service) -- `ACTORS`.
2. External SaaS / external system / third-party integration this system is a client of (type external-saas, or an EXT-NNN record) -- `EXTERNAL`. External systems sit outside all trust zones.
3. Data store (a DS-NNN record, or Type database / cache / object-store / queue / table / secrets-manager) -- `DATA`.
4. Internet-facing edge component -- `EDGE`. Match on POSITION, not just the Type word: a component is EDGE if EITHER (a) its Type/role is gateway / CDN / WAF / load-balancer / reverse-proxy / API-gateway / ingress, OR (b) it is the component that terminates inbound internet traffic -- the first hop from the internet, the destination of the internet-to-edge trust boundary crossing in 02a-context.md, or a component the inventory marks internet-facing. A component receiving external user traffic directly is EDGE even when its Type says `api-service` or `web-app`.
5. Everything else -- internal application services, workers, background jobs, auth modules, lambdas, CI/CD pipelines that do NOT terminate inbound internet traffic -- `APPLICATION`.

Optional `SECURED`: a component the inventory EXPLICITLY marks isolated/secured (an explicit field, not an inference). If you cannot tell, it stays APPLICATION. Do not guess.

Every component matches exactly one rule, so the no-slot defect cannot occur. State each assignment by ID in `notes`.

### TRUST BOUNDARIES ARE STRUCTURAL

A trust boundary TB-NNN is the boundary BETWEEN tiers, shown by an edge leaving one zone container and entering another. It is never a cell and never label text -- edge labels carry the protocol only.

EVERY TB-NNN in the inventory must be RECONCILED: each must correspond to at least one edge whose endpoints sit in different tiers. Because tiers come from your assignment, this is something you check, not the script. If a TB-NNN maps to no such edge, list it in `notes` -- do not drop it.

The property worth checking was never that a string appears on a line; it is that every boundary the inventory claims is actually crossed by something the diagram draws.

### Per-Diagram Specifications

Content selection is MECHANICAL for diagrams 1, 2 and 4 -- a function of the inventory and 02a, not judgment.

**1. `c4-01-context`.** The system as ONE `component` node with id `SYS-001`, every A-NNN from inventory Section 4a as an `actor`, every EXT-NNN as an `external`. Nothing else. If Section 4a is empty the context diagram is wrong, not empty -- go back and derive the actors.

**2. `c4-02-container`.** EVERY C-NNN from inventory Section 2 -- INCLUDING the attested platform components (WAF, ingress, load balancer) carrying `Attested: yes`, which are drawn like any other component so the path from the edge to the application is unbroken, each with the `kind` matching its type, placed in its tier. Edges come from the component Dependencies fields; a dependency with no backing DF-NNN gets `"protocol": ""`. Validation counts nodes against the inventory component count.

**3. `c4-03-component`.** Internal structure of the primary application component -- the ONE judgment-permitted diagram. Its internal elements carry `INT-NNN` ids (see IDS above), never invented C-NNN ids: they are structure inside a component, not components, and an invented C-NNN both misrepresents them and breaks the Validation count. Grounded in what Phase 1 recorded for it: entry points, AuthN/AuthZ and middleware, crypto operations, data-access paths. Anything drawn that the inventory did not record needs a `file:line` citation in `notes`. This diagram is expected to vary between runs; the others are not.

**4. `dfd`.** Gane-Sarson notation, PINNED (never Yourdon): `kind` is `process` for components, `dfdstore` for data stores, `external` for external entities. Every DF-NNN from 02a-context.md becomes an edge; Validation counts them against the 02a total.

### Before rendering: COUNT, do not eyeball

The data file is the one place a whole element can go missing silently, and a missing element cannot be recovered later by looking at the diagram -- you would have to already know it was absent. Count before you render, and state the counts:

- EXT-NNN in inventory Section 4 vs `external` nodes across your diagrams -- these are the ones that go missing most often, because external integrations are recorded in a supplementary section and are easy to skip when walking Section 2.
- C-NNN in inventory Section 2 vs nodes on c4-02 (SYS-/INT- ids excluded).
- DS-NNN in Section 3 vs `store`/`dfdstore` nodes.
- A-NNN in Section 4a vs `actor` nodes on c4-01.
- DF-NNN in 02a-context.md vs edges on the dfd.

Any mismatch is fixed in the DATA FILE before rendering, not after. A count stated and wrong is still better than a count not taken -- but do not proceed on a mismatch you have not explained.

ONE DIAGRAM, ONE PAGE -- owner requirement, 2026-08-04. Each diagram is a single page. Do NOT split a diagram across multiple pages, and do not propose multi-page decomposition with drill-down links as a fix for a crowded or tall diagram: draw.io supports it and it is a natural fit for C4's context/container/component structure, which is exactly why it keeps getting suggested. It is rejected. A reader must be able to see the whole system at once; a diagram that requires clicking through pages to follow a data flow defeats the purpose of drawing it. Crowding is addressed by layout, or by accepting a large page.

### RENDER

Substitute the literal SKILL_DIR, WORKSPACE and PROJECT_NAME from your briefing, and use the invocation form for YOUR shell (common.md rule S -- from bash use `powershell.exe -NoProfile -ExecutionPolicy Bypass -File ...` with the same parameters):

```powershell
& '<SKILL_DIR>\scripts\render-drawio.ps1' -Workspace '<WORKSPACE>' -ProjectName '<PROJECT_NAME>'
```

Paste its output. It reports, per diagram, the page size, the GRID SHAPE (`grid 6x5` means six columns of cells by five rows), node and edge counts, and the per-gutter load. A gutter carrying more than 8 vertical runs is flagged: that is a diagram which should be SPLIT, because the problem is edge density and no amount of spacing reduces density. Do not try to fix it by editing the output.

### Validation (mandatory, before STATE.md -- a diagram that fails is not written)

```powershell
& '<SKILL_DIR>\scripts\validate-drawio.ps1' -Workspace '<WORKSPACE>' -ProjectName '<PROJECT_NAME>'
```

Reconcile against the source files and state the result: C-NNN nodes on c4-02 = inventory component count (SYS-NNN and INT-NNN are synthetic and excluded from this count); edges on dfd = the 02a DF count; containers on c4-02 and dfd = the number of component-bearing tiers (NOT the TB count -- trust boundaries are structural, not containers); every TB-NNN reconciled to a tier-crossing edge or listed in `notes`; bad edge refs and bad parents = 0 everywhere. Any TB-NNN that is neither reconciled nor noted is a rule violation -- fix the data file and re-render, never the number.

Return your completion banner to the orchestrator (it owns STATE.md).

**Phase 4 Completion Banner:**
```
=== PHASE 4 COMPLETE: DRAW.IO DIAGRAMS WRITTEN ===
  .\{PROJECT_NAME}-threat-model\diagrams\c4-01-context.drawio
  .\{PROJECT_NAME}-threat-model\diagrams\c4-02-container.drawio
  .\{PROJECT_NAME}-threat-model\diagrams\c4-03-component.drawio
  .\{PROJECT_NAME}-threat-model\diagrams\dfd.drawio
Render output (pasted verbatim):
<paste the render-drawio.ps1 lines -- page sizes, grid shapes, counts, gutter loads>
Validation output (pasted verbatim):
<paste the per-file validation lines -- every file parsed OK, bad refs 0, counts reconciled>
Phase status reported to orchestrator (it owns STATE.md). Threat model run is finished.
```

## Archiving Reminder (returned to the orchestrator)

Return this reminder to the orchestrator so it can print it after the Phase 4 banner:

Phase 3 Disposition Discovery in a FUTURE run searches for archived directories matching `{PROJECT_NAME}-threat-model-*`. Nothing in this workflow creates those archives automatically -- archiving is a deliberate user action taken before starting a new run. After printing the Phase 4 banner, print this reminder verbatim:

```
REMINDER -- before re-running this threat model in the future:
1. Complete stakeholder review and save dispositions.csv into this run's output directory --
   either click 'Export dispositions.csv' in threat-model.html at the end of the review
   session, or use the threat-model-disposition.md prompt.
2. Archive this run by renaming the output directory with a date suffix, e.g.:
   Rename-Item ".\{PROJECT_NAME}-threat-model" ".\{PROJECT_NAME}-threat-model-yyyyMMdd"
3. The next run will then find the archive, read its dispositions.csv, and carry your
   review decisions forward. Without this step, disposition continuity is lost.
```
===== END FILE: references/phase-4.md


---

## Part 3 -- the Phase 4 renderer specification


Build these two scripts from this specification. They are the Phase 4 diagram renderer and its
validator. Write them into `BUILD_ROOT/stride-threat-model/scripts/`.

**Read section 1 before you write a line.** This script exists because prose instructions to
an agent did not work, and you are being handed prose instructions. That is not a contradiction
-- but it does mean the last section, VERIFY BY LOOKING, is not optional politeness. It is the
only thing that separates this from the approach that failed.


## 1. Why this is a script

The agent supplies the DATA -- which element is in which tier, which flows exist, which are
unprotected. That is classification, and an LLM is good at it.

Geometry is arithmetic: roughly fifty coordinates, a dozen four-decimal attachment fractions,
and a channel assignment per edge, for every diagram. An agent computing that by hand on a
25-component system will get some of it wrong, and one wrong coordinate is a visibly broken
diagram. So it belongs in a script, computed the same way every time.

Six defects in the original were found ONLY by rendering a sample and looking at the exported
image. None was visible in the specification text. Most were two individually correct rules
interacting at a case neither anticipated. Section 9 lists all six; they are the highest-value
part of this document, because they are the ones you will otherwise reintroduce.


## 2. Input contract

`render-drawio.ps1` consumes a JSON data file the Phase 4 agent writes. Default location
`{workspace}\{project}-threat-model\04-diagram-data.json`, overridable.

    {
      "diagrams": [
        {
          "name":  "context",              // becomes <name>.drawio, and the mxfile diagram id
          "title": "System Context",       // the diagram page title
          "notes": ["free text", "..."],   // optional; rendered in a NOTES box
          "nodes": [ ... ],
          "edges": [ ... ]
        }
      ]
    }

**Node fields.** `id`, `label`, `kind` and `tier` are required; the rest are optional and each
one changes what is drawn.

| Field | Effect |
|---|---|
| `id` | Unique within the diagram. Referenced by edges. Becomes the mxCell id. |
| `label` | Display name. Rendered bold on the first line. |
| `kind` | One of `component`, `process`, `store`, `dfdstore`, `external`, `actor`. Chooses size and shape style. |
| `tier` | One of `ACTORS`, `EDGE`, `APPLICATION`, `DATA`, `SECURED`, `EXTERNAL`. Chooses the column and the zone box. |
| `tech` | Technology string. Renders as a second line, `[<TypeWord>: <tech>]`. |
| `description` | One-line description. Renders as a third, smaller line. |
| `threat` | `P1` or `P2`. Overrides the shape's border: P1 red `#CC0000`, P2 orange `#E65100`, both `strokeWidth=3`. |

**Edge fields.** `source` and `target` are required node ids.

| Field | Effect |
|---|---|
| `protocol` | The edge's visible LABEL. Note the name: it is `protocol`, not `label`. |
| `async` | Truthy renders the edge dashed. |
| `secure` | **Falsy renders the edge red and thick** -- the "unencrypted or unauthenticated flow" signal. |

**`secure` is tested as `if (-not $e.secure)`, so an ABSENT `secure` field renders the edge as
insecure.** That default is deliberate -- an unmarked flow is not an assurance -- but it means
a data file that omits `secure` everywhere produces a diagram that is entirely red. Say so in
`phase-4.md`: every edge that IS protected must carry `"secure": true` explicitly.

The renderer computes every coordinate itself. **The data file must not contain `x`, `y`, `w`
or `h`.**


## 3. Output contract

One `.drawio` file per diagram, written to `{workspace}\{project}-threat-model\diagrams\<name>.drawio`.

Standard draw.io XML: an `<mxfile>` wrapping one `<diagram id="<name>" name="<title>">`,
containing an `<mxGraphModel>` with a `<root>` holding `<mxCell id="0"/>` and
`<mxCell id="1" parent="0"/>`, then every shape and edge.

- Shapes: `vertex="1"` with `<mxGeometry x y width height as="geometry"/>`, integer coordinates.
- Edges: `edge="1"` with `source` and `target` referencing cell ids, plus
  `<mxGeometry x="-0.4" relative="1" as="geometry">` containing an `<Array as="points">` of
  `<mxPoint>` waypoints. Label in `value`.

Print one line per file written: name, page size, grid dimensions, node count, edge count. Skip
with a printed `SKIP <name>: no nodes` rather than failing, if a diagram has no nodes.


## 4. Geometry constants

    MARGIN   = 40      CELL_W = 400     CELL_H = 240
    VG       = 255     (vertical gutter width)
    HG       = 187     (horizontal gutter height)
    MAX_ROWS = 5       NOTICE_H = 30

Nodes sit in cells of a GLOBAL grid. Between every pair of adjacent grid columns is a vertical
GUTTER, and between every pair of adjacent rows a horizontal one. **Gutters hold no nodes by
construction, and every edge travels only through gutters plus a short stub inside its own
cell -- so no edge can cross a component.**

Position helpers, and they must agree exactly:

    vertical gutter g spans x from  MARGIN + g*(CELL_W+VG)          , width VG
    grid column     c spans x from  MARGIN + c*(CELL_W+VG) + VG     , width CELL_W
    horizontal gutter h spans y from MARGIN + h*(CELL_H+HG)         , height HG
    grid row        r spans y from  MARGIN + r*(CELL_H+HG) + HG     , height CELL_H

Sizes by kind (width, height):

    component 400x200    process 400x200    external 400x200
    store     320x240    dfdstore 320x240   actor    120x200

Column order, left to right: `ACTORS, EDGE, APPLICATION, DATA, SECURED, EXTERNAL`.
Tiers drawn inside a dashed zone box: `EDGE, APPLICATION, DATA, SECURED` (not ACTORS, not
EXTERNAL).

Zone colours: EDGE `#E65100`, APPLICATION `#B58C00`, DATA `#00695C`, SECURED `#2E7D32`.

Style strings, used verbatim -- these are draw.io configuration values, and guessing them
changes the look for no benefit:

    component/process  rounded=1;whiteSpace=wrap;html=1;fillColor=#438DD5;strokeColor=#2E6295;fontColor=#FFFFFF;fontSize=20;
    store              shape=cylinder3;whiteSpace=wrap;html=1;boundedLbl=1;backgroundOutline=1;size=15;fillColor=#438DD5;strokeColor=#2E6295;fontColor=#FFFFFF;fontSize=20;
    dfdstore           shape=partialRectangle;whiteSpace=wrap;html=1;left=0;right=0;top=1;bottom=1;fillColor=#DAE8FC;strokeColor=#2E6295;fontSize=20;
    external           rounded=0;whiteSpace=wrap;html=1;fillColor=#999999;strokeColor=#666666;fontColor=#FFFFFF;fontSize=20;
    actor              shape=umlActor;verticalLabelPosition=bottom;verticalAlign=top;html=1;strokeColor=#666666;fontSize=20;
    zone (prefix)      rounded=1;container=1;collapsible=0;whiteSpace=wrap;html=1;verticalAlign=top;fontSize=22;fontStyle=1;fillColor=none;dashed=1;strokeWidth=2;strokeColor=
    edge               edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;fontSize=16;endArrow=classic;labelBackgroundColor=#FFFFFF;jettySize=30;jumpStyle=arc;jumpSize=10;
    legend/notes       rounded=0;whiteSpace=wrap;html=1;fillColor=#F5F5F5;strokeColor=#666666;fontSize=16;align=left;verticalAlign=top;
    notice             text;html=1;strokeColor=none;fillColor=none;align=left;verticalAlign=middle;fontSize=16;fontStyle=2;


## 5. Labels

The C4 convention: name in bold, then element type and technology, then a one-line description.

    <b>{label}</b>
    <div style="font-size:15px">[{TypeWord}: {tech}]</div>     if tech
    <div style="font-size:15px">[{TypeWord}]</div>             if no tech
    <div style="font-size:14px">{description}</div>            if description

TypeWord by kind: component -> `Container`, process -> `Process`, store and dfdstore ->
`Data Store`, external -> `External System`, actor -> `Person`.

**DOUBLE ESCAPING IS THE POINT.** User text is HTML-escaped FIRST (`&`, `<`, `>`) so a literal
`<` in a component name displays as a character; the markup above is added around it; then the
whole string is XML-escaped for the attribute (`&`, `<`, `>`, `"`). Single-escaping leaves a
raw `<` in the decoded value, and `html=1` then treats it as a tag and **silently eats the rest
of the name**. The text does not break the file -- it disappears, which is far harder to notice.


## 6. Layout, in five stages

### Stage 1 -- which tiers are present

Keep only tiers with at least one member, in column order. Assign each a column index.

**Guard the single-member case.** In PowerShell 5.1 a `Where-Object` matching exactly one
object returns that object, not an array, and a PSCustomObject has no `.Count` -- so a tier
with a single member silently tested as empty and the whole column vanished from the layout.
Wrap such pipelines in `@()`.

### Stage 2 -- barycentre ordering within tiers

Decide WHICH member sits in WHICH slot before computing any coordinate. Members arrive in
inventory-id order, which is arbitrary with respect to what connects to what.

Each node is pulled toward the average normalised position of everything it connects to.
Normalised position is `index / (count - 1)` within its own tier, or `0.5` for a tier of one.
Sweep the columns forward, then backward, then forward, then backward -- four sweeps -- because
reordering one column changes the right answer for its neighbours. Skip tiers with fewer than
three members. Sort each tier by score, breaking ties on id so the result is deterministic.

**SAME-COLUMN EDGES COUNT TOO.** They are exactly the edges that produce long in-tier runs, so
leaving them out of the neighbour set means the ordering cannot fix what it exists for.

### Stage 3 -- grid assignment, with wrapping

Each tier claims a contiguous RANGE of global grid columns. A tier with more than `MAX_ROWS`
members WRAPS into more than one column: `cols = ceil(n / MAX_ROWS)`, `rows = ceil(n / cols)`.

This is the point of the whole model: nine components in a single file down the page is not a
shape anyone would draw by hand, and it forced every other tier to stretch to match.

Fill **column-major** -- sub-column `floor(s / rows)`, row `s % rows`. Row-major would scatter
neighbours across the grid and undo stage 2.

**Centre short tiers vertically** rather than pinning them to row 0: offset by
`floor((totalRows - tierRows) / 2)`. A one-member edge tier at row 0, while the application
tier runs five rows deep, leaves its edges climbing the full height of the page.

### Stage 4 -- cell refinement

Which SUB-COLUMN a member lands in was decided by its place in a vertical ordering, which has
nothing to do with what it connects to. On a real repository that put two components called
directly by the edge tier two sub-columns away from it. Wrapping a tier shortens the column but
LENGTHENS the edges unless placement is told to care, and those manufactured long edges are
most of the crossings.

So: swap members within their own tier while it reduces total edge span. Cost function:

    for each edge:  3.0 * |Δcolumn|  +  1.0 * |Δrow|
                    +9.0 once, if any cell between the two columns, AT THE TARGET'S ROW,
                     is occupied

Horizontal span is weighted heavier because a long horizontal run crosses every vertical run it
passes. A BLOCKED route is priced separately because it is not merely longer -- it is a
different shape, leaving its row entirely to run in a shared gutter.

Six passes maximum, strict improvement only, stop early when a pass improves nothing. Fixed
pass count and strict improvement keep it deterministic.

### Stage 5 -- absolute geometry

Centre each node in its cell: `x = ColX(c) + (CELL_W - w)/2`, `y = RowY(r) + (CELL_H - h)/2`.


## 7. Edge routing

### Exit and entry fans

Order each node's edges by the other end's centre y, so parallel runs do not cross in front of
the shape they leave. The attachment fraction for the i-th of n edges:

    0.10 + 0.80 * ((i + 0.5 + 0.4 * phase) / n)      rounded to 4 decimals

**The `phase` term is not decoration.** Every node in a grid row spans the same band of y, so a
plain `(i+1)/(n+1)` fan puts node A's second exit at exactly the height of node B's second
entry -- and those two horizontal stubs then overlay inside the shared gutter and draw as ONE
line. `phase` is the node's index among its row's members sorted by x, divided by the row's
member count. It shifts each node's fan by a fraction of a lane, separating them without a
global lane allocation that would be far too tight to see.

### Route plan

- Target to the RIGHT: leave by the source's right into vertical gutter `sourceCol + 1`, arrive
  at the target's left out of vertical gutter `targetCol`.
- Target to the LEFT: mirror it -- exit left from gutter `sourceCol`, enter right at
  `targetCol + 1`.
- SAME column: exit right and enter right, both via gutter `sourceCol + 1`.

When the two gutters are the same, the route is one vertical run and needs no horizontal gutter.

**Detour only when the way is actually BLOCKED.** The final horizontal approach runs at the
TARGET's height across the columns between the two nodes, so it is the TARGET's row that must
be clear -- not the source's. An unconditional detour sent edges over the top of the page that
had a clear run straight in.

When blocked, choose the **nearest usable horizontal gutter, not always the one above the
target.** "Above the target" is the outer top margin for anything in row 0, which put most of
the long traffic in one lane across the whole page. Cost each candidate gutter `h` in
`0..totalRows`:

    |gutterCentreY - exitY| + |gutterCentreY - entryY| + 140 * (edges already using h)

The congestion term is what stops a popular lane from remaining the cheapest.

**Plan edges in a fixed order** -- sort by `"source|target"`. The gutter choice is greedy and
congestion-aware, so without a fixed order the same input renders differently each run.

### Channel allocation

Two runs in the same gutter must not share an x (or a y). Collect every user of each gutter,
sort them geometrically so neighbours stay neighbours -- vertical gutters by the sum of the two
endpoints' centre y, horizontal by the sum of centre x, ties on the edge key -- then spread
evenly: the i-th of n gets `gutterStart + (i+1) * gutterSize / (n+1)`.

### Waypoints

    no horizontal gutter:   (x1,y1)  and, if y1 != y2, (x1,y2)
    with horizontal gutter: (x1,y1), (x1,yh), (x2,yh), (x2,y2)

Attachment on the cell: `exitX=1` or `0` with `exitY=<fraction>`, plus
`exitDx=0;exitDy=0;exitPerimeter=0;` and the matching `entry*` set.

**Build the waypoint list in a real list type, not a nested array literal.** PowerShell unwraps
a one-element array of arrays, so the single-waypoint case collapsed into two scalars and
emitted `<mxPoint x="890" y=""/>`.

### Edge label position

`<mxGeometry x="-0.4" relative="1">` -- biased toward the source end (-1 is source, 1 is
target). At the DEFAULT midpoint a label lands on whatever the line happens to cross: rendering
a real repository put `in-process` on top of a component's own title and `HTTPS` on a database
cylinder. Biasing toward the source keeps it in the gutter just outside the shape.


## 8. Zones, legend, notice, page

**Zones.** For each contained tier, bound its members and pad: left and right 60, TOP 90,
bottom 60. The larger top pad leaves room for the zone's own title. Emit the zone first, then
its members as children with `parent="zone-<TIER>"` and coordinates RELATIVE to the zone.
Non-contained tiers (ACTORS, EXTERNAL) emit with `parent="1"` and absolute coordinates.

**Legend**, 480x360 at x=40. Content: the word LEGEND, then one line per present zone tier,
then `Red thick edge = unencrypted or unauthenticated flow` and the threat-border meanings.

Placement is conditional, and this is the fiddly part. Centring short tiers vertically is worth
roughly 23 crossings down to 9, but it opens a large void at the TOP LEFT. Parking the legend
below all content left that void empty AND stretched the page. So: try `y = NOTICE_H + 40`, and
**check it against the actual node rectangles** -- if any node with `x < 1100` overlaps the band
the legend would occupy, fall back to `bottom + 160`. A diagram whose first tier IS tall has no
void, and a legend pinned to the top would land on a component.

**Notes box**, same size and y, at x=560, when the diagram has `notes`. Join the note lines
with `&#10;`.

**AI notice**, inserted as the FIRST cell so it sits behind nothing: at x=40, y=0, height
`NOTICE_H`, spanning the page width, reading:

    AI-GENERATED -- this diagram was produced by an AI tool and requires human review.

This is required on every diagram; it is Operating Rule 16.

**Page size.** Round up to a 40-pixel grid, minimum height 1600, and take the greater of the
content bottom and the legend bottom, plus 80.


## 9. The six defects -- check for every one of these

These were found by rendering and looking. Each was invisible in the specification text. After
you build the script, verify each explicitly against a rendered diagram.

1. **A single-member tier disappears.** The `@()` coercion in stage 1. Symptom: an entire
   column missing from the layout.
2. **Barycentre ignores same-column edges.** Symptom: long vertical runs inside one tier that
   reordering should have fixed.
3. **Wrapped tiers manufacture long edges.** Stage 4 exists for this. Symptom: components that
   talk to each other placed sub-columns apart.
4. **Two edges draw as one line.** The missing `phase` term. Symptom: a gutter that looks like
   it carries one flow but carries two.
5. **Case-insensitive variable collision.** In the original, the per-edge horizontal-gutter
   index was nearly named `$hg`, which in PowerShell IS the `$HG` gutter-height constant --
   assigning a row index to it silently set `HG` to 1, collapsing every horizontal channel into
   a 1px band that read as four edges sharing a single line. **Name it `$hgIdx` or anything
   else.** PowerShell variable names are case-insensitive; this class of bug is invisible in
   review.
6. **Unconditional detours.** Edges routed over the top of the page that had a clear straight
   run. Fixed by testing the TARGET's row for occupancy.

Plus the two escaping traps: single-escaped labels silently eat text (section 5), and the
unwrapped single waypoint emits `y=""` (section 7).


## 10. validate-drawio.ps1

Small, and its job is narrow: prove each emitted file is well-formed and internally consistent.

For each `.drawio` in the diagrams directory:

1. Parse it as XML. A parse failure prints `PARSE FAIL <file>` and is a hard failure.
2. Collect every `mxCell` id.
3. For every edge cell, check that its `source` and `target` both exist in that id set. Count
   the ones that do not.
4. Print one line per file: name, `PARSE OK` or `PARSE FAIL`, cell count, edge count, and bad
   reference count.

Exit 1 if any file fails to parse or has any bad reference. A failing diagram is not done.


## 11. VERIFY BY LOOKING -- do not skip this

Everything above is prose describing a thing that exists because prose did not work. The
difference between this attempt and that one is this section.

1. Write a small data file by hand: two tiers, four or five nodes across them, at least one
   `store`, one `actor`, one edge with `secure: true`, one without, one with `async: true`, and
   one node with `threat: "P1"`.
2. Render it. Run the validator. Both must pass.
3. **Open the `.drawio` file and look at it.** In draw.io, or by exporting an image.
4. Check, by eye, in this order:
   - Every node appears. Count them against the data file. (Defect 1.)
   - No edge crosses over a component box. Edges belong in gutters.
   - No two edges are drawn on top of each other. (Defect 4.)
   - Edge labels sit in open space, not on top of a shape.
   - The insecure edge is red and thick; the async edge is dashed; the P1 node has a red border.
   - Labels are complete -- no name truncated at a `<` character. (Section 5.)
   - The legend does not overlap any component.
   - No waypoint reads `y=""` in the XML. (Section 7.)
5. Then scale up: render the real Phase 4 data for an actual system and look again. Layout
   defects appear at 20 components that are invisible at 5.

If something looks wrong, fix the script and re-render. **Do not adjust the data to work around
a layout bug** -- the data is the agent's classification and it is correct; the geometry is
yours and it is not.

Report what you checked and what you saw. "It rendered without error" is not an answer to any
of the questions in step 4.


---

## Part 4 -- manifest

Check this immediately after writing each file in Step 1, BEFORE the two `phase-0.md` edits.
Report the ACTUALS, not a claim that they match. A file that is short is the likely failure
and nothing else will report it.

**`phase-0.md` is the exception, and it is expected.** The counts below are the file AS
WRITTEN VERBATIM. Step 1 then deletes the `partition-manifest` instruction and Part 2 of step
7.7, which removes roughly 16 lines. So the sequence is: write the file, check it against the
156 lines below, THEN make the edits. Afterwards it lands around 140 lines, and a final count
in that region is correct rather than a truncation. The other four files are edited by nothing
and must match exactly, before and after.

### references/common.md

    lines       173
    bytes       21506
    first line  <!-- SKILL VERSION: v25-skill (2026-07-21a) -- methodology carved verbatim from PROMPT V
    last line       - `.drawio`: a notice text cell on the canvas at the TOP of the page (above title/le

### references/phase-0.md

    lines       156
    bytes       28089
    first line  <!-- SKILL VERSION: v25-skill (2026-07-21a) -- methodology carved verbatim from PROMPT V
    last line   After the user approves the Scope Proposal, run `& '<SKILL_DIR>\scripts\partition-manife

### references/phase-0-discovery.md

    lines       143
    bytes       25025
    first line  <!-- SKILL VERSION: v25-skill (2026-07-24g) -- methodology carved verbatim from PROMPT V
    last line   ## Completeness self-audit (mandatory, before you return) For each element category -- s

### references/phase-2c.md

    lines       102
    bytes       11404
    first line  <!-- SKILL VERSION: v25-skill (2026-07-21a) -- methodology carved verbatim from PROMPT V
    last line   ```

### references/phase-4.md

    lines       171
    bytes       16893
    first line  <!-- SKILL VERSION: v26-skill (2026-08-04a) -->
    last line   ```

A note on bytes: if your editor writes CRLF line endings the byte count will be higher by
roughly the line count. That is fine. The LINE count must match exactly.
