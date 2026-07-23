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
- Each page: `<diagram id="..." name="...">` wrapping a single `<mxGraphModel>` with `<root>`
- Every `<root>` begins with the two required base cells:
  ```xml
  <mxCell id="0"/>
  <mxCell id="1" parent="0"/>
  ```
  Edges and shapes that belong to no zone container use `parent="1"`. Components inside a zone container MUST use `parent="<zone-cell-id>"` (e.g., `parent="zone-APPLICATION"`) with geometry relative to that container -- see Zone Containers under Visual Standards
- Shapes: `vertex="1"` with `<mxGeometry x y width height as="geometry"/>`; integer coordinates on a 40-pixel grid
- Edges: `edge="1"` with `source` and `target` referencing cell ids, plus `<mxGeometry relative="1" as="geometry"/>`; label in `value`
- Cell ids derived from inventory ids exactly: `C-001`, `EXT-003`, `DS-001` (trust boundaries TB-NNN are edge annotations, not cells, so no `TB-NNN` cell id exists). Zone containers, which are not inventory objects, use the fixed ids `zone-EDGE`, `zone-APPLICATION`, `zone-DATA`, `zone-SECURED`. Edge ids: `flow-<sourceId>-<targetId>-<NN>`
- ANGLE BRACKETS ARE BANNED from label text. A single raw `<` or `>` inside a `value` attribute makes the entire file fail to load -- a field-recurring failure. Do not rely on remembering to escape: do not GENERATE the characters. Generics and comparisons are rewritten (`List[String]` not `List<String>`; "under 5" not "< 5"). The ONLY permitted angle-bracket sequence is the literal line-break idiom `&lt;br&gt;` inside labels (styles carry `html=1`). `&` in text is written `&amp;`; `"` inside a value is written `&quot;`. The mechanical enforcement is the Validation step below: a file that does not parse as XML is not done, whatever it looks like.
- Built-in draw.io shape styles only (no external stencils/plugins -- they require network access)

### Visual Standards (apply to every diagram)

Every visual choice below is PINNED. Anything left unpinned gets re-sampled per run, which is why past diagrams looked different every time. Consistency across runs matters more than beauty; a human polishes in draw.io afterward -- the deliverable is a structurally correct, loadable, consistently-styled diagram, not a pretty one.

STYLE DICTIONARY -- copy these style strings VERBATIM; do not add, remove, or reorder attributes. One style per element type; the ONLY permitted per-cell deviation is the threat-priority stroke override.
- Component (internal service/worker/job): `rounded=1;whiteSpace=wrap;html=1;fillColor=#438DD5;strokeColor=#2E6295;fontColor=#FFFFFF;fontSize=12;` -- size 200x100
- Data store (C4 diagrams): `shape=cylinder3;whiteSpace=wrap;html=1;boundedLbl=1;backgroundOutline=1;size=15;fillColor=#438DD5;strokeColor=#2E6295;fontColor=#FFFFFF;fontSize=12;` -- size 200x120
- Data store (DFD only, Gane-Sarson open box): `shape=partialRectangle;whiteSpace=wrap;html=1;left=0;right=0;top=1;bottom=1;fillColor=#DAE8FC;strokeColor=#2E6295;fontSize=12;` -- size 200x80. The open box keeps the Gane-Sarson two-line form (only top and bottom edges drawn) but takes a LIGHT-BLUE FILL, not transparent: a transparent store inside a transparent zone container is unreadable (both are fillColor=none), so the fill is what makes the store legible against the zone behind it. Zone containers stay unfilled (borders only) so their contents show through; the store's fill, not the container's, resolves the transparent-on-transparent problem.
- Process (DFD only): `rounded=1;whiteSpace=wrap;html=1;fillColor=#438DD5;strokeColor=#2E6295;fontColor=#FFFFFF;fontSize=12;` -- size 200x100 (rounded rectangles, PINNED -- never circles)
- External system / SaaS / managed service operated by another party: `rounded=0;whiteSpace=wrap;html=1;fillColor=#999999;strokeColor=#666666;fontColor=#FFFFFF;fontSize=12;` -- size 200x100
- Human actor (context diagram): `shape=umlActor;verticalLabelPosition=bottom;verticalAlign=top;html=1;strokeColor=#666666;fontSize=12;` -- size 60x100
- Zone container (one per component-bearing tier -- see Component-to-Tier Assignment and Zone Containers below; trust boundaries TB-NNN are NEVER drawn as containers): `rounded=1;container=1;collapsible=0;whiteSpace=wrap;html=1;verticalAlign=top;fontSize=14;fontStyle=1;fillColor=none;dashed=1;strokeWidth=2;strokeColor=<zone color>` where the tier fixes the zone color exactly: EDGE tier uses DMZ/perimeter `#E65100`, APPLICATION tier uses internal/application `#B58C00`, DATA tier uses data tier `#00695C`, SECURED tier uses secured/isolated `#2E7D32` (the untrusted/internet `#CC0000` color names the actors/external space, which has no container)
- Edge (all flows): `edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;fontSize=11;endArrow=classic;` -- async/queued flows (brokers, event buses) add `dashed=1`; NO other line-style variation exists
- Threat override (on the affected component's style only): replace strokeColor with `#CC0000` and add `strokeWidth=3` when a Priority 1 threat touches it; `#E65100`/`strokeWidth=3` for Priority 2. This is the ONLY meaning of red/orange on shapes.
- Legend box: `rounded=0;whiteSpace=wrap;html=1;fillColor=#F5F5F5;strokeColor=#666666;fontSize=11;align=left;verticalAlign=top;` -- size 320x220

CONTAINMENT MODEL -- containers are TIERS derived from WHERE COMPONENTS LIVE, not from how trust boundaries are phrased. This is the standard threat-model DFD/C4 approach and is fully deterministic. Trust boundaries (TB-NNN) are the boundaries BETWEEN tiers; they annotate the crossing edges and are NEVER drawn as their own container or as an empty box.

COMPONENT-TO-TIER ASSIGNMENT -- assign EVERY component (data stores DS-NNN and external integrations EXT-NNN are components too, per this skill) to EXACTLY ONE tier by this FIXED decision table, FIRST MATCH WINS, applied in ID order so two runs assign identically:
1. Human actor / user persona (an actor class from the inventory, not a running service) -- ACTORS. Rendered in the actors column with NO container.
2. External SaaS / external system / third-party integration this system is a client of (type external-saas, or an EXT-NNN record) -- EXTERNAL. Rendered in the external column with NO container; external systems sit outside all trust zones.
3. Data store (a DS-NNN record, or Type database / cache / object-store / queue / table / secrets-manager) -- DATA tier.
4. Internet-facing edge component (Type or role is gateway / CDN / WAF / load-balancer / reverse-proxy / API-gateway / ingress -- the component that terminates inbound internet traffic) -- EDGE tier.
5. Everything else (application services, workers, APIs, auth modules, jobs, lambdas, pipelines) -- APPLICATION tier.
Optional SECURED tier: a component the inventory EXPLICITLY marks isolated/secured (an explicit field, not an inference) -- SECURED tier; if you cannot tell, it stays APPLICATION. Do not guess -- the deterministic default is APPLICATION.
Every component matches exactly one rule, so every component lands in exactly one tier and the no-slot defect cannot occur. State the tier you assigned each component (by ID) in the diagram's notes box so a re-run confirms the same assignment.

ZONE CONTAINERS -- the containers on a diagram are the component-bearing TIERS, not the trust boundaries. Draw one container per tier that holds AT LEAST ONE component, in this FIXED left-to-right order: EDGE, APPLICATION, DATA, SECURED. A tier with zero members is not drawn (a container is never empty). ACTORS and EXTERNAL are columns WITHOUT containers. Each zone container is a draw.io container cell with a FIXED id -- `zone-EDGE`, `zone-APPLICATION`, `zone-DATA`, `zone-SECURED` (zones are not inventory objects, so they use these fixed ids, not an inventory id) -- labeled with its tier name, colored per the Zone container style (EDGE orange, APPLICATION amber, DATA teal, SECURED green). Every member component sets `parent="zone-<TIER>"` with geometry RELATIVE to its container, so containment is structural and survives manual drag-editing.

TRUST BOUNDARIES AS EDGE ANNOTATIONS -- a trust boundary TB-NNN is the boundary BETWEEN tiers, drawn on the crossing edge, never as its own cell. A data-flow (or dependency) edge whose source and destination fall in DIFFERENT tiers crosses a trust boundary; the specific TB-NNN it crosses is the one 02a-context.md's "Crosses TB?" column records for that flow. Append ` | TB-NNN` to that edge's existing label (a secure flow crossing TB-002 reads `DF-003 🔒 | TB-002`; a bare dependency edge crossing it reads just ` | TB-002`; an edge crossing two boundaries chains them, `DF-001 🔒 | TB-005 | TB-006`). The crossing is BOTH structural (the edge visibly leaves one zone container and enters another) AND named by the ` | TB-NNN` marker. EVERY TB-NNN in the inventory must appear as a ` | TB-NNN` annotation on at least one crossing flow; if a TB-NNN maps to no data-flow edge at all, list it in the diagram's notes box (do not drop it). TBs get no container cell and no separate node.

LAYOUT FORMULA -- computed, not judged; every coordinate is a function of column index and ID-sorted slot, nothing eyeballed. Columns run left to right in this FIXED order, and ONLY columns that have at least one member appear (absent columns are skipped and the remaining columns close up, so column index `c` is the 0-indexed position among PRESENT columns): ACTORS (human actors, no container), EDGE, APPLICATION, DATA, SECURED, EXTERNAL (external systems, no container). EDGE/APPLICATION/DATA/SECURED are the zone-container columns (one container each, per Zone Containers); ACTORS and EXTERNAL have no container. Geometry (grid-aligned, computed):
- Column origin: column `c` sits at absolute x = 40 + c*520 (column width 260, leaving a 260px inter-column gap -- roomy per the owner's spacing guidance, and it keeps even a 5-column system near the ~2400px target while a busy system grows gracefully wider).
- Top strip: y = 0..60 is reserved for the Rule 16 AI-generation notice cell; the first content row starts at y = 80.
- Zone container cell (one per component-bearing tier): parent="1", id `zone-<TIER>`, absolute x = column origin, y = 80, width = 260, height = 80 + memberCount*160.
- Member (component inside a zone container): 0-indexed slot `s` by ascending ID, `parent="zone-<TIER>"`, geometry RELATIVE to the container at x = 30, y = 60 + s*160 (a 200-wide node leaves 30px side padding; a 100-tall node leaves a 60px vertical gap between rows).
- Uncontained shape (human actor, external system): parent="1", absolute x = its column origin, absolute y = 80 + s*160 where `s` is its 0-indexed ID-sorted slot within that no-container column.
- Legend box: parent="1", x = 40, y = (bottom edge of the tallest column) + 80, below the columns -- it never adds width.
Edge crossings are NOT your problem -- slot order is by ID, period; the human untangles crossings in draw.io if they care.

LABELS -- exception-based: annotate what is dangerous, join everything else through the tables by ID.
- Component/store/external label: `ID&lt;br&gt;Name` and nothing else (no tech stack, no ports, no env vars -- those live in the inventory, joined by the ID). Line breaks are the `&lt;br&gt;` idiom only.
- Edge label, secure flow (Encryption TLS/mTLS AND AuthN not none/unknown): `DF-NNN 🔒` -- nothing else.
- Edge label, insecure or unknown flow: `DF-NNN ⚠ <protocol>` (e.g. `DF-007 ⚠ HTTP`). The ⚠ flow labels are the only place a protocol name appears on a diagram.
- Edge label, dependency edge with NO backing DF-NNN: EMPTY -- a c4-02 edge derived only from a component's Dependencies field, where 02a-context.md records no corresponding DF-NNN (its coverage check excluded it as "yielded no flow"), carries NO label text (`value=""`). The arrow itself shows the dependency. Do NOT invent an "unconfirmed" or "A-NNN" label -- only a real DF-NNN edge ever gets a `DF-NNN` label with its 🔒/⚠ glyph.
- Edge label, trust-boundary crossing: when an edge's source and destination fall in DIFFERENT tiers it crosses a trust boundary -- append ` | TB-NNN` (the TB-NNN 02a records for that flow in its "Crosses TB?" column) to the edge's existing label. A secure flow crossing TB-004 reads `DF-007 🔒 | TB-004`; a bare dependency edge crossing it reads just ` | TB-004`; an edge crossing two boundaries chains them (`DF-001 🔒 | TB-005 | TB-006`). The crossing is ALSO visible structurally (the edge leaves one zone container and enters another), but the ` | TB-NNN` names which boundary. The legend explains the ` | TB-NNN` marker.

Trust boundaries: no TB-NNN is ever drawn as a container or a node. The containers on a diagram are the component-bearing TIERS (EDGE, APPLICATION, DATA, SECURED), each a draw.io CONTAINER cell with the fixed id `zone-<TIER>`, labeled with its tier name, zone color per the dictionary. Every member component sets `parent="zone-<TIER>"` with coordinates RELATIVE to that container -- containment is structural, not visual, so a member can never render outside its zone and survives manual drag-editing. Do NOT draw zone containers as free-floating rectangles sized to visually surround members, and do NOT draw a container for a tier with zero members -- a tier with no members is simply not drawn. Each TB-NNN is instead an edge annotation: the ` | TB-NNN` marker on every flow whose endpoints fall in different tiers (see Labels). So the container count on a diagram equals the number of component-bearing tiers, and every TB-NNN is reconciled as an edge boundary-marker (or, if it backs no flow, listed in the notes box). The Validation step counts both.

Threat mapping: place threat IDs (`01`, `02`, ...) in a small text cell adjacent to the affected component; apply the threat stroke override per the dictionary. The threat IDs ARE the cross-reference to the threat table; no separate index.

Legend: every diagram includes the legend box explaining exactly: the tier zone colors present (EDGE/DMZ orange, APPLICATION/internal amber, DATA teal, SECURED green -- only those tiers that appear), the threat stroke override, solid vs dashed edges, the 🔒/⚠ glyphs, and the ` | TB-NNN` trust-boundary-crossing marker on edges. Nothing else belongs in it.

AI-generation notice: every diagram includes the AI-generation notice cell required by Operating Rule 16, occupying the reserved top strip (y = 0..60). The notice cell is `parent="1"` at x=40, y=0, width = (rightmost cell's right edge - 40), height=30, style per Rule 16 -- a real cell in `<root>`, not a comment, so it survives PNG/PDF export. The rightmost cell may be an uncontained shape (external system or actor column), not only a container.

### Per-Diagram Specifications

Each diagram inherits all Visual Standards above. The bullets below are only what's unique to that diagram.

Content selection is MECHANICAL for diagrams 1, 2, and 4 -- what appears is a function of the inventory and 02a, not judgment:

**1. `diagrams/c4-01-context.drawio` -- Context Diagram.** Exactly: the system as ONE block (internal component style), every human actor class from the inventory, every EXT-NNN as an external-system shape, and the ` | TB-NNN` marker on each edge that crosses into the system from an actor or external. Nothing else.

**2. `diagrams/c4-02-container.drawio` -- Container Diagram.** Exactly: EVERY C-NNN from inventory Section 2 (each styled per its type -- component, data store, or external) placed in its tier per Component-to-Tier Assignment, one zone container per component-bearing tier, and every TB-NNN as a ` | TB-NNN` marker on its crossing edge (per Trust Boundaries as Edge Annotations), edges = the component Dependencies fields. A Dependencies-field edge with no backing DF-NNN carries an empty label per the Labels standard. Completeness is counted by the Validation step: C-NNN cells on this diagram MUST equal the inventory component count. Labels per the Labels standard -- no ports, replicas, endpoints, or env vars on shapes.

**3. `diagrams/c4-03-component.drawio` -- Component Diagram (the ONE judgment-permitted diagram).** Internal structure of the primary application component, grounded in what Phase 1 actually recorded for it: its Entry points field, its AuthN/AuthZ and middleware observations, its crypto operations, its data-access paths. Every element drawn must trace to a recorded inventory field or a cited file -- internal layers the inventory did not record are drawn only with a `file:line` citation in the notes box. This diagram is expected to vary between runs; the other three are not.

**4. `diagrams/dfd.drawio` -- Data Flow Diagram.** Gane-Sarson notation, PINNED (never Yourdon): processes = rounded rectangles per the dictionary, data stores = the open-box DFD store style, external entities = the external-system style. Exactly: every DF-NNN from 02a-context.md as an edge (Validation counts them against the 02a total), one zone container per component-bearing tier, and every TB-NNN as a ` | TB-NNN` marker on its crossing edge (per Trust Boundaries as Edge Annotations). Edge labels follow the exception-based Labels standard -- `DF-NNN 🔒` or `DF-NNN ⚠ protocol`, with ` | TB-NNN` appended when the edge crosses a tier boundary, never data type / classification / auth details (those join via the 02a table).

### Validation (mandatory, before STATE.md -- a diagram that fails is not written)

Run this after all four files exist; paste its OUTPUT into the completion banner verbatim (Operating Rule 15). A PARSE FAIL is the unescaped-character failure that makes a file unloadable on the desktop -- fix the file and re-run until every line is clean; never leave a failing file for the user to discover:

Set $SKILL_DIR, $WORKSPACE, and $PROJECT_NAME from the values your briefing names, in the same block as the call (shell state does not persist between tool calls):

```powershell
$SKILL_DIR    = '<SKILL_DIR from your briefing>'
$WORKSPACE    = '<WORKSPACE from your briefing>'
$PROJECT_NAME = '<PROJECT_NAME from your briefing>'

& $SKILL_DIR\scripts\validate-drawio.ps1 -Workspace $WORKSPACE -ProjectName $PROJECT_NAME
```

Reconcile the counts against the source files and state the result: containers on c4-02 and dfd = the number of component-bearing tiers (EDGE/APPLICATION/DATA/SECURED that have at least one member -- NOT the TB count; trust boundaries are edge annotations, not containers); every TB-NNN appears as a ` | TB-NNN` annotation on at least one boundary-crossing flow (or is listed in the notes box if it backs no flow) -- state both the component-bearing-tier count and the count of TB-NNN reconciled as edge markers; C-NNN cells on c4-02 = inventory component count; edges on dfd = 02a DF count; bad edge refs and bad parents = 0 everywhere. The validator script counts containers mechanically; it does not assert containers == TB count, because containers are tiers, not trust boundaries. Any TB-NNN that appears as neither an edge marker nor a notes-box entry is a rule violation -- fix the diagram, not the number.

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
