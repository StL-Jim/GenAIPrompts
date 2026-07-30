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
- Component (internal service/worker/job): `rounded=1;whiteSpace=wrap;html=1;fillColor=#438DD5;strokeColor=#2E6295;fontColor=#FFFFFF;fontSize=20;` -- size 400x200
- Data store (C4 diagrams): `shape=cylinder3;whiteSpace=wrap;html=1;boundedLbl=1;backgroundOutline=1;size=15;fillColor=#438DD5;strokeColor=#2E6295;fontColor=#FFFFFF;fontSize=20;` -- size 320x240
- Data store (DFD only, Gane-Sarson open box): `shape=partialRectangle;whiteSpace=wrap;html=1;left=0;right=0;top=1;bottom=1;fillColor=#DAE8FC;strokeColor=#2E6295;fontSize=20;` -- size 320x240. The open box keeps the Gane-Sarson two-line form (only top and bottom edges drawn) but takes a LIGHT-BLUE FILL, not transparent: a transparent store inside a transparent zone container is unreadable (both are fillColor=none), so the fill is what makes the store legible against the zone behind it. Zone containers stay unfilled (borders only) so their contents show through; the store's fill, not the container's, resolves the transparent-on-transparent problem.
- Process (DFD only): `rounded=1;whiteSpace=wrap;html=1;fillColor=#438DD5;strokeColor=#2E6295;fontColor=#FFFFFF;fontSize=20;` -- size 400x200 (rounded rectangles, PINNED -- never circles)
- External system / SaaS / managed service operated by another party: `rounded=0;whiteSpace=wrap;html=1;fillColor=#999999;strokeColor=#666666;fontColor=#FFFFFF;fontSize=20;` -- size 400x200
- Human actor (context diagram): `shape=umlActor;verticalLabelPosition=bottom;verticalAlign=top;html=1;strokeColor=#666666;fontSize=20;` -- size 120x200
- Zone container (one per component-bearing tier -- see Component-to-Tier Assignment and Zone Containers below; trust boundaries TB-NNN are NEVER drawn as containers): `rounded=1;container=1;collapsible=0;whiteSpace=wrap;html=1;verticalAlign=top;fontSize=22;fontStyle=1;fillColor=none;dashed=1;strokeWidth=2;strokeColor=<zone color>` where the tier fixes the zone color exactly: EDGE tier uses DMZ/perimeter `#E65100`, APPLICATION tier uses internal/application `#B58C00`, DATA tier uses data tier `#00695C`, SECURED tier uses secured/isolated `#2E7D32` (the untrusted/internet `#CC0000` color names the actors/external space, which has no container)
- Edge (all flows): `edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;fontSize=16;endArrow=classic;labelBackgroundColor=#FFFFFF;jettySize=30;` -- async/queued flows (brokers, event buses) add `dashed=1`; unprotected flows take the red stroke defined under Labels. `labelBackgroundColor=#FFFFFF` is not cosmetic: without it, a label lying over its own line or over a shape is unreadable, which is a large part of what makes a dense diagram feel cramped. `jettySize=20` stops orthogonal edges hugging the shape they leave
- Threat override (on the affected component's style only): replace strokeColor with `#CC0000` and add `strokeWidth=3` when a Priority 1 threat touches it; `#E65100`/`strokeWidth=3` for Priority 2. This is the ONLY meaning of red/orange on shapes.
- Legend box: `rounded=0;whiteSpace=wrap;html=1;fillColor=#F5F5F5;strokeColor=#666666;fontSize=16;align=left;verticalAlign=top;` -- size 480x360

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
- Column origin: column `c` sits at absolute x = 40 + c*720 (column width 480, leaving a 240px inter-column gap -- roomy per the owner's spacing guidance, and it keeps even a 5-column system near the ~2400px target while a busy system grows gracefully wider).
- Top strip: y = 0..60 is reserved for the Rule 16 AI-generation notice cell; the first content row starts at y = 80.
- Zone container cell (one per component-bearing tier): parent="1", id `zone-<TIER>`, absolute x = column origin, y = 80, width = 480, height = 80 + (memberCount - 1)*400 + (tallest member's height) + 80. Do NOT use `120 + memberCount*400`: that allocates a full 500 pitch for the LAST member instead of just its height, leaving roughly 300px of dead space below the final node in every container. Rendered and confirmed 2026-07-30.
- Member (component inside a zone container): 0-indexed slot `s` by ascending ID, `parent="zone-<TIER>"`, geometry RELATIVE to the container at x = (480 - nodeWidth) / 2, y = 80 + s*400. The x formula CENTRES the node in the 480-wide container whatever its width -- 40 for a 400-wide component or process, 80 for a 320-wide data store -- so a mixed tier stays aligned on one centre line.
- BARYCENTRE PLACEMENT for uncontained columns (actors, external systems). Their slot pitch above is provisional. Replace it: put each node at the mean y of the CENTRES of everything it connects to in other columns, minus half its own height; sort by that value; then walk the sorted list pushing each down as needed so consecutive nodes keep a 160px gap. Nodes with no connections keep their provisional slot.
  Ordering by ID is arbitrary with respect to connectivity, and rendering showed exactly what that costs: an SMTP relay sat at the top of the diagram while its only neighbour sat at the bottom, joined by a pointless full-height vertical. After the barycentre pass it sits level with its neighbour and the edge is a straight line. This is the standard layered-graph crossing-reduction heuristic and it applies to the contained columns too, but their membership is fixed by tier so only the uncontained ones are reordered here.
- Shapes were doubled at the owner's request (2026-07-29): components 400x200, data stores 320x240, actors 120x200, with fonts scaled to match. The layout arithmetic scaled WITH them so the gaps are PRESERVED rather than halved -- the 400 vertical pitch leaves a 200px gap between 200-tall rows, which rendering confirmed is ample for the edge labels and orthogonal runs that gap exists for, and the 720 column pitch against a 480-wide container leaves the same 320px between nodes horizontally. Bigger shapes in the same amount of air, which is the point: doubling everything uniformly would just be a zoom.
- Uncontained shape (human actor, external system): parent="1", absolute x = its column origin, absolute y = 80 + s*400 where (this is a PROVISIONAL slot -- the barycentre rule below moves it) `s` is its 0-indexed ID-sorted slot within that no-container column.
- Long-haul lane: `laneY` = (bottom edge of the tallest column) + 40. A horizontal routing lane, not a cell -- see Edge Routing rule 4.
- Legend box: parent="1", x = 40, y = (bottom edge of the LEFTMOST column's last node) + 160. It goes in the leftmost column's dead space -- the area under the actors, empty in every diagram of this shape -- and NOT below all the columns. Placing it below everything buys a small box a full-width band of empty page across a very wide diagram, which is what produced an unused bottom third; from here it costs no page height at all.

EDGE ROUTING -- computed, not judged. Every edge gets an EXPLICIT attachment point, and every edge crossing a column gap gets an EXPLICIT routing channel. Absent both, draw.io floats each edge to the nearest perimeter point and routes them all through one corridor: in a column layout that means every edge between two columns lands on the SAME two points and runs down the SAME channel. That is what produces lines stacked on top of one another and a fan of arrowheads converging on a single spot. It is a missing-geometry problem, and no amount of extra spacing fixes it -- spacing widens the corridor that all of them still share.

1. ATTACHMENT SIDE, from the column relationship (source column `cs`, target column `ct`):
   - `ct > cs` (rightward, the normal case): exit the source's RIGHT side, enter the target's LEFT side.
   - `ct < cs` (leftward backflow): exit the source's LEFT side, enter the target's RIGHT side.
   - `ct == cs` (within one tier): exit the source's BOTTOM, enter the target's TOP.

2. EXIT POINTS, fanned so that no two share one. Order a node's exits by the TARGET's centre y -- geometric order, not target id, which is arbitrary with respect to where the edges actually go and creates crossings for no reason. For the i-th of k exits (0-indexed), the fraction is `f = (i+1)/(k+1)` rounded to 4 decimals:
   - Right side exit: `exitX=1;exitY=<f>;exitDx=0;exitDy=0;exitPerimeter=0;`
   - Bottom exit: `exitX=<f>;exitY=1;exitDx=0;exitDy=0;exitPerimeter=0;`
   `exitPerimeter=0` is required, not optional: without it draw.io routes out to the shape perimeter instead of starting at the point you specified, and the fan silently stops working. A single edge gets f = 0.5. The fan also separates a bidirectional PAIR between two nodes, which under floating attachment overlays perfectly and reads as one line.

2a. ENTRY POINTS ARE ALIGNED, NOT FANNED. Each entry WANTS its source's exit height, and moves only when two entries would collide. Compute each incoming edge's desired entry y as its source's exit y, clamp into the target's band (30px inset top and bottom), sort, then walk them applying a 45px minimum separation. Convert to `entryY=<(y - targetTop) / targetHeight>`, with `entryX=0;entryDx=0;entryDy=0;entryPerimeter=0;` on a left-side entry (`entryX=1` on a right-side entry).
   Fanning both ends independently puts a step in an edge whose endpoints are already level: a source with three exits sends its third at 0.75 of its height while a target with one entry receives at 0.50, and the router jogs between them. Rendered and confirmed 2026-07-30.

2b. SAME-COLUMN EDGES ALIGN ON X. When source and target are in one column the entry sits on the target's TOP edge, so its fraction is an X position and the alignment rule above -- which computes a Y -- is meaningless. Use `entryX = exitX`, which for two nodes in a column is straight down. Feeding a Y-derived fraction to `entryX` produces an S-bend.

3. ROUTING CHANNEL for every edge crossing a column gap. The gap between column `c` and column `c+1` runs from (column origin of `c`) + 440 to (column origin of `c+1`) + 40, so `gapLeft` = origin(c) + 440 and the gap is 320 wide. Collect every edge crossing that gap, order them by source id then target id, and give the i-th of m a single waypoint:
   `x = gapLeft + (i+1) * 320 / (m+1)`, and give it TWO waypoints at that x -- one at the edge's exit y, one at its entry y (absolute coordinates, rounded to integers):
   `<mxGeometry relative="1" as="geometry"><Array as="points"><mxPoint x="<x>" y="<exit y>"/><mxPoint x="<x>" y="<entry y>"/></Array></mxGeometry>`.
   TWO, not one. A single waypoint leaves the run between the attachment point and the waypoint to the router, which collapses neighbouring edges back onto a shared segment -- rendered 2026-07-30 with one waypoint and seven edges in a corridor still merged into a visible tangle with their labels stacked. Two waypoints pin the entire middle run to the channel. Eight edges in a corridor gives 40px between channels, which is legible; rule 5 governs when it stops being acceptable.

4. SKIP-COLUMN EDGES (`ct - cs >= 2`) DETOUR ONLY WHEN THEY MUST, and then only as far as they must. Test the straight path first: if the edge's exit y clears every node in the intervening columns (60px margin), route it straight across and add no waypoints at all. Only when it would strike a node does it detour, to the NEAREST CLEAR HORIZONTAL BAND -- candidates are 80px above each blocking node's top and 80px below each blocking node's bottom, and you take whichever is closest to the exit y -- with two waypoints at `(source exit x + 40, band)` and `(target entry x - 40, band)`.
   A candidate band must ALSO clear the container header strip: reject anything at or above `zone top + 100`. A band can be clear of every NODE and still run straight through the tier titles.
   Both conditions were learned by rendering. An unconditional floor lane sent a top-row-to-top-row flow on an 1100px round trip to avoid a 480px container, and a header-blind band search then routed that same edge over the top of the entire diagram. If NO candidate band is clear, fall back to a lane below every container at (bottom edge of the tallest column) + 40, and note it in the notes box so the low lines read as deliberate.

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
