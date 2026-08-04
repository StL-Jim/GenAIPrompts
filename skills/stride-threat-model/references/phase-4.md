<!-- SKILL VERSION: v26-skill (2026-07-30a) -->

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

Everything the script owns, and which you must therefore NOT attempt: page size, column and row positions, zone container geometry, shape sizes and style strings, edge attachment points, routing channels, detour bands, node ordering within the actor and external columns, the legend, and the AI-generation notice. All of it is settled, and all of it was verified by rendering sample diagrams and inspecting the exported images. Do not second-guess it and do not hand-edit the output.

### The data file: `{PROJECT_NAME}-threat-model/04-diagram-data.json`

Write it with the Write tool, in one call, as valid JSON:

```json
{
  "diagrams": [
    {
      "name": "c4-02-container",
      "title": "Container Diagram",
      "nodes": [
        { "id": "C-001", "label": "Web Application", "kind": "component", "tier": "APPLICATION", "threat": "P1" },
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
- `threat` is optional: `"P1"` when a Priority 1 threat in 02-threats.md touches that component, `"P2"` for Priority 2, omitted otherwise. This is the ONLY meaning of a red or orange shape border.
- `secure` is `false` when the flow's Encryption is none/plaintext/unknown OR its AuthN is none/unknown, per its row in 02a-context.md. The script draws those as thick red edges, which is the diagram's at-a-glance answer to "what is unprotected".
- `async` is `true` for broker and event-bus flows; the script dashes them.
- `protocol` is the protocol AND NOTHING ELSE -- `HTTPS`, `HTTP`, `AMQP`, `TLS/5432`, or `?` if genuinely unknown. No DF-NNN, no TB-NNN, no data classification, no auth detail. Long edge labels collide with each other and with the shapes; everything omitted here is still in the 02a-context.md data-flow table, which is where a reader goes for detail.
- `notes` is free text rendered in the diagram's notes box. Put the tier you assigned each component (by ID) here, plus any TB-NNN that backs no flow.

ANGLE BRACKETS ARE BANNED from every label and note. A raw `<` or `>` breaks the file. Do not rely on escaping -- do not generate the characters: write `List[String]` not `List<String>`, "under 5" not "< 5".

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

ONE DIAGRAM, ONE PAGE -- owner requirement, 2026-07-30. Each diagram is a single page. Do NOT split a diagram across multiple pages, and do not propose multi-page decomposition with drill-down links as a fix for a crowded or tall diagram: draw.io supports it and it is a natural fit for C4's context/container/component structure, which is exactly why it keeps getting suggested. It is rejected. A reader must be able to see the whole system at once; a diagram that requires clicking through pages to follow a data flow defeats the purpose of drawing it. Crowding is addressed by layout, or by accepting a large page.

### RENDER

Substitute the literal SKILL_DIR, WORKSPACE and PROJECT_NAME from your briefing, and use the invocation form for YOUR shell (common.md rule S -- from bash use `powershell.exe -NoProfile -ExecutionPolicy Bypass -File ...` with the same parameters):

```powershell
& '<SKILL_DIR>\scripts\render-drawio.ps1' -Workspace '<WORKSPACE>' -ProjectName '<PROJECT_NAME>'
```

Paste its output. It reports, per diagram, the page size, node and edge counts, and the per-corridor edge load. A corridor carrying more than 8 edges is flagged: that is a diagram which should be SPLIT, because the problem is edge density and no amount of spacing reduces density. Do not try to fix it by editing the output.

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
<paste the render-drawio.ps1 lines -- page sizes, counts, corridor loads>
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
