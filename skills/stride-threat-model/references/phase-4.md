<!-- SKILL VERSION: v25-skill (2026-07-21a) -- methodology carved verbatim from PROMPT VERSION v24 (2026-07-16a) -->

## Phase 4 -- C4 Model and Data Flow Diagrams (draw.io)

### Phase 4 Rehydration (MANDATORY FIRST STEP)

Read STATE.md, 01-inventory.md, and 02-threats.md. Diagrams must be structurally grounded in the inventory (every component, trust boundary, and data flow appearing in a diagram must come from `01-inventory.md`) and annotated with threat IDs from the threat model (every threat ID marker on a diagram must exist in `02-threats.md`).

Read these files with the Read tool (disk content overrides memory): {PROJECT_NAME}-threat-model/STATE.md, {PROJECT_NAME}-threat-model/01-inventory.md, {PROJECT_NAME}-threat-model/02-threats.md.

If either inventory or threats file is missing or empty, STOP and report the error.

Disk content takes precedence over conversation memory. Component IDs (`C-NNN`), trust boundary IDs (`TB-NNN`), data store IDs (`DS-NNN`), external integration IDs (`EXT-NNN`), and threat IDs (`01`, `02`, etc.) in the diagrams must match the IDs in these two files exactly -- do not invent, rename, or re-number any ID.

STATE.md is orchestrator-owned. Do not read-modify-write it.

After reading, acknowledge in one line that you have both files loaded and are ready to generate diagrams.

### File Creation and mxGraph XML Format

Use the Write tool with the complete mxGraph XML content in ONE SHOT for each `.drawio` file. NEVER use PowerShell, multi-step edits, or the Edit tool for `.drawio` files. Each diagram is a separate file and a single tool call. The natural checkpoint is "after each diagram is on disk, the next diagram is independent" -- if context dies between diagrams, recovery is "look at which `.drawio` files exist, generate the missing ones."

XML format rules (follow exactly):
- File extension: `.drawio`
- Root: `<mxfile host="app.diagrams.net" compressed="false">` -- `compressed="false"` is mandatory for human-readable, diffable files; do NOT emit base64-deflated payloads
- Each page: `<diagram id="..." name="...">` wrapping a single `<mxGraphModel grid="1" gridSize="10" page="1" pageWidth="<W>" pageHeight="<H>">` with `<root>`. THE PAGE ATTRIBUTES ARE MANDATORY, and their absence is the single largest cause of a diagram reading as cramped: with no pageWidth/pageHeight, draw.io falls back to Letter (850x1100) and tiles the layout across a grid of pages, so every PDF export arrives chopped into fragments that each look overcrowded.
- Page size is COMPUTED with a poster-size floor so the whole diagram is always ONE page: `pageWidth = max(2400, rightmost cell's right edge + 40)`, `pageHeight = max(1600, lowest cell's bottom edge + 80)`, each rounded UP to a multiple of 40. 2400x1600 is a FLOOR and not a target, because the vertical spacing below makes a busy tier taller than 1600 on its own, and a page smaller than its content fragments the export silently instead of failing loudly.
- Every `<root>` begins with the two required base cells:
  ```xml
  <mxCell id="0"/>
  <mxCell id="1" parent="0"/>
  ```
  Edges and shapes that belong to no zone container use `parent="1"`. Components inside a zone container MUST use `parent="<zone-cell-id>"` (e.g., `parent="zone-APPLICATION"`) with geometry relative to that container -- see Zone Containers under Visual Standards
- Shapes: `vertex="1"` with `<mxGeometry x y width height as="geometry"/>`; integer coordinates on a 40-pixel grid (a multiple of the `gridSize="10"` above, so every coordinate lands on a grid line)
- Edges: `edge="1"` with `source` and `target` referencing cell ids, plus `<mxGeometry relative="1" as="geometry"/>`; label in `value`. Every edge ALSO carries explicit attachment keys in its style and, when it crosses a column gap, a waypoint array inside its geometry -- see Edge Routing. An edge with no attachment keys floats, and floating edges are what produce stacked lines and arrowhead pile-ups
- Cell ids derived from inventory ids exactly: `C-001`, `EXT-003`, `DS-001` (trust boundaries TB-NNN are edge annotations, not cells, so no `TB-NNN` cell id exists). Zone containers, which are not inventory objects, use the fixed ids `zone-EDGE`, `zone-APPLICATION`, `zone-DATA`, `zone-SECURED`. Edge ids: `flow-<sourceId>-<targetId>-<NN>`
- ANGLE BRACKETS ARE BANNED from label text. A single raw `<` or `>` inside a `value` attribute makes the entire file fail to load -- a field-recurring failure. Do not rely on remembering to escape: do not GENERATE the characters. Generics and comparisons are rewritten (`List[String]` not `List<String>`; "under 5" not "< 5"). The ONLY permitted angle-bracket sequence is the literal line-break idiom `&lt;br&gt;` inside labels (styles carry `html=1`). `&` in text is written `&amp;`; `"` inside a value is written `&quot;`. The mechanical enforcement is the Validation step below: a file that does not parse as XML is not done, whatever it looks like.
- Built-in draw.io shape styles only (no external stencils/plugins -- they require network access)

### Visual Standards (apply to every diagram)

Every visual choice below is PINNED. Anything left unpinned gets re-sampled per run, which is why past diagrams looked different every time. Consistency across runs matters more than beauty; a human polishes in draw.io afterward -- the deliverable is a structurally correct, loadable, consistently-styled diagram, not a pretty one.

STYLE DICTIONARY -- copy these style strings VERBATIM; do not add, remove, or reorder attributes. One style per element type; the ONLY permitted per-cell deviation is the threat-priority stroke override.
- Component (internal service/worker/job): `rounded=1;whiteSpace=wrap;html=1;fillColor=#438DD5;strokeColor=#2E6295;fontColor=#FFFFFF;fontSize=14;` -- size 200x100
- Data store (C4 diagrams): `shape=cylinder3;whiteSpace=wrap;html=1;boundedLbl=1;backgroundOutline=1;size=15;fillColor=#438DD5;strokeColor=#2E6295;fontColor=#FFFFFF;fontSize=14;` -- size 160x120
- Data store (DFD only, Gane-Sarson open box): `shape=partialRectangle;whiteSpace=wrap;html=1;left=0;right=0;top=1;bottom=1;fillColor=#DAE8FC;strokeColor=#2E6295;fontSize=14;` -- size 160x120. The open box keeps the Gane-Sarson two-line form (only top and bottom edges drawn) but takes a LIGHT-BLUE FILL, not transparent: a transparent store inside a transparent zone container is unreadable (both are fillColor=none), so the fill is what makes the store legible against the zone behind it. Zone containers stay unfilled (borders only) so their contents show through; the store's fill, not the container's, resolves the transparent-on-transparent problem.
- Process (DFD only): `rounded=1;whiteSpace=wrap;html=1;fillColor=#438DD5;strokeColor=#2E6295;fontColor=#FFFFFF;fontSize=14;` -- size 200x100 (rounded rectangles, PINNED -- never circles)
- External system / SaaS / managed service operated by another party: `rounded=0;whiteSpace=wrap;html=1;fillColor=#999999;strokeColor=#666666;fontColor=#FFFFFF;fontSize=14;` -- size 200x100
- Human actor (context diagram): `shape=umlActor;verticalLabelPosition=bottom;verticalAlign=top;html=1;strokeColor=#666666;fontSize=14;` -- size 60x100
- Zone container (one per component-bearing tier -- see Component-to-Tier Assignment and Zone Containers below; trust boundaries TB-NNN are NEVER drawn as containers): `rounded=1;container=1;collapsible=0;whiteSpace=wrap;html=1;verticalAlign=top;fontSize=16;fontStyle=1;fillColor=none;dashed=1;strokeWidth=2;strokeColor=<zone color>` where the tier fixes the zone color exactly: EDGE tier uses DMZ/perimeter `#E65100`, APPLICATION tier uses internal/application `#B58C00`, DATA tier uses data tier `#00695C`, SECURED tier uses secured/isolated `#2E7D32` (the untrusted/internet `#CC0000` color names the actors/external space, which has no container)
- Edge (all flows): `edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;fontSize=12;endArrow=classic;labelBackgroundColor=#FFFFFF;jettySize=20;` -- async/queued flows (brokers, event buses) add `dashed=1`; unprotected flows take the red stroke defined under Labels. `labelBackgroundColor=#FFFFFF` is not cosmetic: without it, a label lying over its own line or over a shape is unreadable, which is a large part of what makes a dense diagram feel cramped. `jettySize=20` stops orthogonal edges hugging the shape they leave
- Threat override (on the affected component's style only): replace strokeColor with `#CC0000` and add `strokeWidth=3` when a Priority 1 threat touches it; `#E65100`/`strokeWidth=3` for Priority 2. This is the ONLY meaning of red/orange on shapes.
- Legend box: `rounded=0;whiteSpace=wrap;html=1;fillColor=#F5F5F5;strokeColor=#666666;fontSize=12;align=left;verticalAlign=top;` -- size 360x260

CONTAINMENT MODEL -- containers are TIERS derived from WHERE COMPONENTS LIVE, not from how trust boundaries are phrased. This is the standard threat-model DFD/C4 approach and is fully deterministic. Trust boundaries (TB-NNN) are the boundaries BETWEEN tiers; they annotate the crossing edges and are NEVER drawn as their own container or as an empty box.

COMPONENT-TO-TIER ASSIGNMENT -- assign EVERY component (data stores DS-NNN and external integrations EXT-NNN are components too, per this skill) to EXACTLY ONE tier by this FIXED decision table, FIRST MATCH WINS, applied in ID order so two runs assign identically:
1. Human actor / user persona (an actor class from the inventory, not a running service) -- ACTORS. Rendered in the actors column with NO container.
2. External SaaS / external system / third-party integration this system is a client of (type external-saas, or an EXT-NNN record) -- EXTERNAL. Rendered in the external column with NO container; external systems sit outside all trust zones.
3. Data store (a DS-NNN record, or Type database / cache / object-store / queue / table / secrets-manager) -- DATA tier.
4. Internet-facing edge component -- EDGE tier. Match on POSITION, not just the Type word: a component is EDGE if EITHER (a) its Type/role is gateway / CDN / WAF / load-balancer / reverse-proxy / API-gateway / ingress, OR (b) it is the component that terminates inbound internet traffic -- the first hop from the internet / the destination of the internet-to-edge trust boundary crossing in 02a-context.md, or a component the inventory marks as internet-facing / publicly exposed. A component that receives external user traffic directly is EDGE even when its Type is labeled `api-service` or `web-app` (a public API gateway service is still the edge). Use the recorded trust boundaries and exposure to decide, not the Type label alone.
5. Everything else -- internal application services, workers, background jobs, auth/authz modules, lambdas, and CI/CD pipelines that do NOT terminate inbound internet traffic -- APPLICATION tier.
Optional SECURED tier: a component the inventory EXPLICITLY marks isolated/secured (an explicit field, not an inference) -- SECURED tier; if you cannot tell, it stays APPLICATION. Do not guess -- the deterministic default is APPLICATION.
Every component matches exactly one rule, so every component lands in exactly one tier and the no-slot defect cannot occur. State the tier you assigned each component (by ID) in the diagram's notes box so a re-run confirms the same assignment.

ZONE CONTAINERS -- the containers on a diagram are the component-bearing TIERS, not the trust boundaries. Draw one container per tier that holds AT LEAST ONE component, in this FIXED left-to-right order: EDGE, APPLICATION, DATA, SECURED. A tier with zero members is not drawn (a container is never empty). ACTORS and EXTERNAL are columns WITHOUT containers. Each zone container is a draw.io container cell with a FIXED id -- `zone-EDGE`, `zone-APPLICATION`, `zone-DATA`, `zone-SECURED` (zones are not inventory objects, so they use these fixed ids, not an inventory id) -- labeled with its tier name, colored per the Zone container style (EDGE orange, APPLICATION amber, DATA teal, SECURED green). Every member component sets `parent="zone-<TIER>"` with geometry RELATIVE to its container, so containment is structural and survives manual drag-editing.

TRUST BOUNDARIES ARE STRUCTURAL -- a trust boundary TB-NNN is the boundary BETWEEN tiers, shown by an edge crossing out of one zone container and into another. It is never its own cell, and since edge labels carry the protocol only (see Labels), it is never label text either. A data-flow (or dependency) edge whose source and destination fall in DIFFERENT tiers crosses a trust boundary; the specific TB-NNN it crosses is the one 02a-context.md's "Crosses TB?" column records for that flow.
EVERY TB-NNN in the inventory must still be RECONCILED, and the reconciliation is now structural rather than textual: each TB-NNN must correspond to at least one edge on the diagram whose endpoints sit in different tiers. If a TB-NNN maps to no such edge, list it in the diagram's notes box -- do not drop it. TBs get no container cell and no separate node.
Reconciling by structure keeps the completeness guarantee while leaving the lines uncluttered. The property worth checking was never that a string appears on a line; it is that every boundary the inventory claims is actually CROSSED by something the diagram draws, and that is a fact about tiers.

LAYOUT FORMULA -- computed, not judged; every coordinate is a function of column index and ID-sorted slot, nothing eyeballed. Columns run left to right in this FIXED order, and ONLY columns that have at least one member appear (absent columns are skipped and the remaining columns close up, so column index `c` is the 0-indexed position among PRESENT columns): ACTORS (human actors, no container), EDGE, APPLICATION, DATA, SECURED, EXTERNAL (external systems, no container). EDGE/APPLICATION/DATA/SECURED are the zone-container columns (one container each, per Zone Containers); ACTORS and EXTERNAL have no container. Geometry (grid-aligned, computed):
- Column origin: column `c` sits at absolute x = 40 + c*520 (column width 260, leaving a 260px inter-column gap -- roomy per the owner's spacing guidance, and it keeps even a 5-column system near the ~2400px target while a busy system grows gracefully wider).
- Top strip: y = 0..60 is reserved for the Rule 16 AI-generation notice cell; the first content row starts at y = 80.
- Zone container cell (one per component-bearing tier): parent="1", id `zone-<TIER>`, absolute x = column origin, y = 80, width = 260, height = 80 + memberCount*400.
- Member (component inside a zone container): 0-indexed slot `s` by ascending ID, `parent="zone-<TIER>"`, geometry RELATIVE to the container at x = (260 - nodeWidth) / 2, y = 60 + s*400. The x formula CENTRES the node in the 260-wide container whatever its width -- 30 for a 200-wide component or process, 50 for a 160-wide data store -- so a mixed tier stays aligned on one centre line.
- The 400 vertical pitch leaves a 300px gap between 100-tall rows, and that gap is where edge labels and orthogonal edge runs live. The old 160 pitch left 60px, which is what forced labels on top of lines and shapes. Horizontally the 520 column pitch against a 260-wide container already leaves 320px between the nodes themselves, so only the vertical needed changing.
- Uncontained shape (human actor, external system): parent="1", absolute x = its column origin, absolute y = 80 + s*160 where `s` is its 0-indexed ID-sorted slot within that no-container column.
- Long-haul lane: `laneY` = (bottom edge of the tallest column) + 40. A horizontal routing lane, not a cell -- see Edge Routing rule 4.
- Legend box: parent="1", x = 40, y = (bottom edge of the tallest column) + 160, below the columns and below the long-haul lane -- it never adds width.

EDGE ROUTING -- computed, not judged. Every edge gets an EXPLICIT attachment point, and every edge crossing a column gap gets an EXPLICIT routing channel. Absent both, draw.io floats each edge to the nearest perimeter point and routes them all through one corridor: in a column layout that means every edge between two columns lands on the SAME two points and runs down the SAME channel. That is what produces lines stacked on top of one another and a fan of arrowheads converging on a single spot. It is a missing-geometry problem, and no amount of extra spacing fixes it -- spacing widens the corridor that all of them still share.

1. ATTACHMENT SIDE, from the column relationship (source column `cs`, target column `ct`):
   - `ct > cs` (rightward, the normal case): exit the source's RIGHT side, enter the target's LEFT side.
   - `ct < cs` (leftward backflow): exit the source's LEFT side, enter the target's RIGHT side.
   - `ct == cs` (within one tier): exit the source's BOTTOM, enter the target's TOP.

2. ATTACHMENT POINT, fanned so that no two edges share one. Order a node's edges deterministically -- by target id for its exits, by source id for its entries -- and count exits and entries SEPARATELY, so a node with 3 outgoing and 2 incoming edges fans 3 points on its exit side and 2 on its entry side. For the i-th of k edges on a side (0-indexed), with the fraction `f = (i+1)/(k+1)` rounded to 4 decimals:
   - Right side exit: `exitX=1;exitY=<f>;exitDx=0;exitDy=0;`
   - Left side entry: `entryX=0;entryY=<f>;entryDx=0;entryDy=0;`
   - Bottom exit: `exitX=<f>;exitY=1;exitDx=0;exitDy=0;`
   - Top entry: `entryX=<f>;entryY=0;entryDx=0;entryDy=0;`
   A single edge gets f = 0.5, i.e. the side's midpoint, which is what floating already did -- the fan only matters from two edges upward. This rule alone also separates a bidirectional PAIR between the same two nodes, which under floating attachment overlays perfectly and reads as one line.

3. ROUTING CHANNEL for every edge crossing a column gap. The gap between column `c` and column `c+1` runs from (column origin of `c`) + 230 to (column origin of `c+1`) + 30, so `gapLeft` = origin(c) + 230 and the gap is 320 wide. Collect every edge crossing that gap, order them by source id then target id, and give the i-th of m a single waypoint:
   `x = gapLeft + (i+1) * 320 / (m+1)`, `y` = the midpoint between that edge's exit y and entry y (absolute coordinates), both rounded to integers,
   written into the edge's geometry as `<mxGeometry relative="1" as="geometry"><Array as="points"><mxPoint x="<x>" y="<y>"/></Array></mxGeometry>`. Eight edges in a corridor gives 40px between channels, which is legible; the arithmetic degrades gracefully below that and rule 5 governs when it stops being acceptable.

4. SKIP-COLUMN EDGES take the long-haul lane, never a path through an intervening tier. When `ct - cs >= 2` the edge would otherwise cut straight across a container it has nothing to do with, crossing every node and label in it. Route it underneath everything with TWO waypoints, at `(source exit x + 40, laneY)` and `(target entry x - 40, laneY)`, where `laneY` = (bottom edge of the tallest column) + 40 -- below every container, above the legend. Record the lane in the notes box (one line: long-haul flows route below the tiers at y=`<laneY>`) so a reader recognises the low lines as deliberate rather than as routing errors.

5. CORRIDOR SATURATION -- stated, never silently degraded. If any single column gap carries more than 8 edges, 320px cannot separate them legibly whatever rule 3 computes. Do NOT shrink the channels below 40px to make them fit, and do not widen the page to chase it. Report it in the Validation output instead: `Corridor <c>-><c+1>: <m> edges -- ABOVE the 8-edge legible limit; this diagram should be split`. For a busy DFD the fix is splitting the diagram (per trust boundary, or per subsystem), because the problem is edge DENSITY and whitespace does not reduce density.
Edge crossings are NOT your problem -- slot order is by ID, period; the human untangles crossings in draw.io if they care.

LABELS -- exception-based: annotate what is dangerous, join everything else through the tables by ID.
- Component/store/external label: `ID&lt;br&gt;Name` and nothing else (no tech stack, no ports, no env vars -- those live in the inventory, joined by the ID). Line breaks are the `&lt;br&gt;` idiom only.
- Edge label: THE PROTOCOL AND NOTHING ELSE -- `HTTPS`, `HTTP`, `AMQP`, `TLS/5432` -- taken from the Protocol column of that flow's row in 02a-context.md. No DF-NNN, no glyphs, no TB-NNN, no data type, no classification, no authentication detail. Long edge labels are a primary cause of a cramped diagram: they collide with each other, with the lines, and with the shapes. Everything dropped from the label is still in the 02a-context.md data-flow table, which is where a reader goes for detail -- the diagram's job is shape and reach, not a data dictionary.
- Edge label, protocol genuinely unknown: `?` -- one character, which reads as a known gap rather than an omission.
- UNPROTECTED FLOWS ARE MARKED BY THE LINE, NOT BY TEXT. When a flow's Encryption is none/plaintext/unknown OR its AuthN is none/unknown, the edge takes `strokeColor=#CC0000;strokeWidth=3`. This carries what the old warning glyph carried and carries it better: it costs no label width and it is legible at poster viewing distance, where a small glyph is not. Secure flows keep the default stroke -- there is no "secure" marker, because the ABSENCE of a red line is the marker. This does not collide with the threat override, which applies to SHAPE strokes only; on an edge, red means an unprotected flow and nothing else.
- Edge label, dependency edge with NO backing DF-NNN: EMPTY -- a c4-02 edge derived only from a component's Dependencies field, where 02a-context.md records no corresponding DF-NNN (its coverage check excluded it as "yielded no flow"), carries NO label text (`value=""`). The arrow itself shows the dependency. Do NOT invent an "unconfirmed" or "A-NNN" label.

Trust boundaries: no TB-NNN is ever drawn as a container or a node. The containers on a diagram are the component-bearing TIERS (EDGE, APPLICATION, DATA, SECURED), each a draw.io CONTAINER cell with the fixed id `zone-<TIER>`, labeled with its tier name, zone color per the dictionary. Every member component sets `parent="zone-<TIER>"` with coordinates RELATIVE to that container -- containment is structural, not visual, so a member can never render outside its zone and survives manual drag-editing. Do NOT draw zone containers as free-floating rectangles sized to visually surround members, and do NOT draw a container for a tier with zero members -- a tier with no members is simply not drawn. Each TB-NNN is instead reconciled structurally: at least one edge whose endpoints fall in different tiers (see Trust Boundaries Are Structural). So the container count on a diagram equals the number of component-bearing tiers, and every TB-NNN is reconciled as a tier-crossing edge (or, if it backs no flow, listed in the notes box). The Validation step counts both.

Threat mapping: place threat IDs (`01`, `02`, ...) in a small text cell adjacent to the affected component; apply the threat stroke override per the dictionary. The threat IDs ARE the cross-reference to the threat table; no separate index.

Legend: every diagram includes the legend box explaining exactly: the tier zone colors present (EDGE/DMZ orange, APPLICATION/internal amber, DATA teal, SECURED green -- only those tiers that appear), the threat stroke override on SHAPES, solid vs dashed edges (synchronous vs async/queued), the red thick EDGE meaning an unencrypted or unauthenticated flow, and one line saying that edge labels name the protocol only and that full flow detail lives in the 02a-context.md data-flow table. Nothing else belongs in it.

AI-generation notice: every diagram includes the AI-generation notice cell required by Operating Rule 16, occupying the reserved top strip (y = 0..60). The notice cell is `parent="1"` at x=40, y=0, width = (rightmost cell's right edge - 40), height=30, style per Rule 16 -- a real cell in `<root>`, not a comment, so it survives PNG/PDF export. The rightmost cell may be an uncontained shape (external system or actor column), not only a container.

### Per-Diagram Specifications

Each diagram inherits all Visual Standards above. The bullets below are only what's unique to that diagram.

Content selection is MECHANICAL for diagrams 1, 2, and 4 -- what appears is a function of the inventory and 02a, not judgment:

**1. `diagrams/c4-01-context.drawio` -- Context Diagram.** Exactly: the system as ONE block (internal component style), every human actor class from the inventory, every EXT-NNN as an external-system shape, with every edge that crosses into the system from an actor or external being a trust-boundary crossing, shown structurally and carrying no TB text. Nothing else.

**2. `diagrams/c4-02-container.drawio` -- Container Diagram.** Exactly: EVERY C-NNN from inventory Section 2 (each styled per its type -- component, data store, or external) placed in its tier per Component-to-Tier Assignment, one zone container per component-bearing tier, and every TB-NNN reconciled structurally as a tier-crossing edge (per Trust Boundaries Are Structural), edges = the component Dependencies fields. A Dependencies-field edge with no backing DF-NNN carries an empty label per the Labels standard. Completeness is counted by the Validation step: C-NNN cells on this diagram MUST equal the inventory component count. Labels per the Labels standard -- no ports, replicas, endpoints, or env vars on shapes.

**3. `diagrams/c4-03-component.drawio` -- Component Diagram (the ONE judgment-permitted diagram).** Internal structure of the primary application component, grounded in what Phase 1 actually recorded for it: its Entry points field, its AuthN/AuthZ and middleware observations, its crypto operations, its data-access paths. Every element drawn must trace to a recorded inventory field or a cited file -- internal layers the inventory did not record are drawn only with a `file:line` citation in the notes box. This diagram is expected to vary between runs; the other three are not.

**4. `diagrams/dfd.drawio` -- Data Flow Diagram.** Gane-Sarson notation, PINNED (never Yourdon): processes = rounded rectangles per the dictionary, data stores = the open-box DFD store style, external entities = the external-system style. Exactly: every DF-NNN from 02a-context.md as an edge (Validation counts them against the 02a total), one zone container per component-bearing tier, and every TB-NNN reconciled structurally as a tier-crossing edge (per Trust Boundaries Are Structural). Edge labels follow the Labels standard -- the protocol and nothing else -- with unprotected flows marked by the red thick stroke rather than by label text, and trust-boundary crossings shown structurally rather than named on the line. Never data type / classification / auth details; those join via the 02a table.

### Validation (mandatory, before STATE.md -- a diagram that fails is not written)

Run this after all four files exist; paste its OUTPUT into the completion banner verbatim (Operating Rule 15). A PARSE FAIL is the unescaped-character failure that makes a file unloadable on the desktop -- fix the file and re-run until every line is clean; never leave a failing file for the user to discover:

Substitute the literal SKILL_DIR, WORKSPACE, and PROJECT_NAME values your briefing names, and use the invocation form for YOUR shell (common.md rule S -- from bash use `powershell.exe -NoProfile -ExecutionPolicy Bypass -File ...` with the same parameters):

```powershell
& '<SKILL_DIR>\scripts\validate-drawio.ps1' -Workspace '<WORKSPACE>' -ProjectName '<PROJECT_NAME>'
```

Reconcile the counts against the source files and state the result: containers on c4-02 and dfd = the number of component-bearing tiers (EDGE/APPLICATION/DATA/SECURED that have at least one member -- NOT the TB count; trust boundaries are edge annotations, not containers); every TB-NNN corresponds to at least one edge whose endpoints sit in different tiers (or is listed in the notes box if it backs no flow) -- state both the component-bearing-tier count and the count of TB-NNN reconciled as tier-crossing edges; C-NNN cells on c4-02 = inventory component count; edges on dfd = 02a DF count; bad edge refs and bad parents = 0 everywhere. ALSO report the per-corridor edge load for every column gap (`Corridor <c>-><c+1>: <m> edges`), flagging any corridor above the 8-edge legible limit per Edge Routing rule 5 -- an over-saturated corridor is a diagram that needs splitting, and it is the one layout defect that whitespace cannot repair, so it must be said out loud rather than left for the reader to discover. The validator script counts containers mechanically; it does not assert containers == TB count, because containers are tiers, not trust boundaries. Any TB-NNN that is neither reconciled to a tier-crossing edge nor listed in the notes box is a rule violation -- fix the diagram, not the number.

Return your completion banner to the orchestrator (it owns STATE.md).

**Phase 4 Completion Banner:**
```
=== PHASE 4 COMPLETE: DRAW.IO DIAGRAMS WRITTEN ===
  .\{PROJECT_NAME}-threat-model\diagrams\c4-01-context.drawio
  .\{PROJECT_NAME}-threat-model\diagrams\c4-02-container.drawio
  .\{PROJECT_NAME}-threat-model\diagrams\c4-03-component.drawio
  .\{PROJECT_NAME}-threat-model\diagrams\dfd.drawio
Validation output (pasted verbatim from the Validation step):
<paste the per-file validation lines here -- every file parsed OK, bad refs 0, counts reconciled>
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
