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
  Edges and shapes that belong to no trust boundary use `parent="1"`. Components inside a trust boundary MUST use `parent="<TB-cell-id>"` (e.g., `parent="TB-002"`) with geometry relative to that container -- see Trust boundaries under Visual Standards
- Shapes: `vertex="1"` with `<mxGeometry x y width height as="geometry"/>`; integer coordinates on a 40-pixel grid
- Edges: `edge="1"` with `source` and `target` referencing cell ids, plus `<mxGeometry relative="1" as="geometry"/>`; label in `value`
- Cell ids derived from inventory ids exactly: `C-001`, `TB-002`, `EXT-003`, `DS-001`. Edge ids: `flow-<sourceId>-<targetId>-<NN>`
- ANGLE BRACKETS ARE BANNED from label text. A single raw `<` or `>` inside a `value` attribute makes the entire file fail to load -- a field-recurring failure. Do not rely on remembering to escape: do not GENERATE the characters. Generics and comparisons are rewritten (`List[String]` not `List<String>`; "under 5" not "< 5"). The ONLY permitted angle-bracket sequence is the literal line-break idiom `&lt;br&gt;` inside labels (styles carry `html=1`). `&` in text is written `&amp;`; `"` inside a value is written `&quot;`. The mechanical enforcement is the Validation step below: a file that does not parse as XML is not done, whatever it looks like.
- Built-in draw.io shape styles only (no external stencils/plugins -- they require network access)

### Visual Standards (apply to every diagram)

Every visual choice below is PINNED. Anything left unpinned gets re-sampled per run, which is why past diagrams looked different every time. Consistency across runs matters more than beauty; a human polishes in draw.io afterward -- the deliverable is a structurally correct, loadable, consistently-styled diagram, not a pretty one.

STYLE DICTIONARY -- copy these style strings VERBATIM; do not add, remove, or reorder attributes. One style per element type; the ONLY permitted per-cell deviation is the threat-priority stroke override.
- Component (internal service/worker/job): `rounded=1;whiteSpace=wrap;html=1;fillColor=#438DD5;strokeColor=#2E6295;fontColor=#FFFFFF;fontSize=12;` -- size 200x100
- Data store (C4 diagrams): `shape=cylinder3;whiteSpace=wrap;html=1;boundedLbl=1;backgroundOutline=1;size=15;fillColor=#438DD5;strokeColor=#2E6295;fontColor=#FFFFFF;fontSize=12;` -- size 200x120
- Data store (DFD only, Gane-Sarson open box): `shape=partialRectangle;whiteSpace=wrap;html=1;left=0;right=0;top=1;bottom=1;fillColor=#DAE8FC;strokeColor=#2E6295;fontSize=12;` -- size 200x80. The open box keeps the Gane-Sarson two-line form (only top and bottom edges drawn) but takes a LIGHT-BLUE FILL, not transparent: a transparent store inside a transparent trust-boundary container is unreadable (both are fillColor=none), so the fill is what makes the store legible against the zone behind it. Trust boundaries stay unfilled (borders only) so their contents show through; the store's fill, not the boundary's, resolves the transparent-on-transparent problem.
- Process (DFD only): `rounded=1;whiteSpace=wrap;html=1;fillColor=#438DD5;strokeColor=#2E6295;fontColor=#FFFFFF;fontSize=12;` -- size 200x100 (rounded rectangles, PINNED -- never circles)
- External system / SaaS / managed service operated by another party: `rounded=0;whiteSpace=wrap;html=1;fillColor=#999999;strokeColor=#666666;fontColor=#FFFFFF;fontSize=12;` -- size 200x100
- Human actor (context diagram): `shape=umlActor;verticalLabelPosition=bottom;verticalAlign=top;html=1;strokeColor=#666666;fontSize=12;` -- size 60x100
- Trust boundary container (ZONE-type only; CROSSING-type boundaries are NOT drawn as containers -- see Trust Boundary Typing below): `rounded=1;container=1;collapsible=0;whiteSpace=wrap;html=1;verticalAlign=top;fontSize=14;fontStyle=1;fillColor=none;dashed=1;strokeWidth=2;strokeColor=<zone color>` where zone color is exactly: untrusted/internet `#CC0000`, DMZ/perimeter `#E65100`, internal/application `#B58C00`, data tier `#00695C`, secured/isolated `#2E7D32`
- Edge (all flows): `edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;fontSize=11;endArrow=classic;` -- async/queued flows (brokers, event buses) add `dashed=1`; NO other line-style variation exists
- Threat override (on the affected component's style only): replace strokeColor with `#CC0000` and add `strokeWidth=3` when a Priority 1 threat touches it; `#E65100`/`strokeWidth=3` for Priority 2. This is the ONLY meaning of red/orange on shapes.
- Legend box: `rounded=0;whiteSpace=wrap;html=1;fillColor=#F5F5F5;strokeColor=#666666;fontSize=11;align=left;verticalAlign=top;` -- size 320x220

TRUST BOUNDARY TYPING -- classify EVERY TB-NNN before laying anything out; the classification is mechanical, so two runs classify identically. Each boundary is exactly one of:
- ZONE: a region that CONTAINS one or more components -- a network tier such as internet/edge, DMZ/perimeter, internal/application, data tier, or secured/isolated. Drawn as a container cell (the ZONE-type trust-boundary container style), with its member components parented into it, exactly as before.
- CROSSING: a boundary BETWEEN two specific named endpoint elements with nothing contained inside it (e.g. `application -> external SaaS`, `CI runner -> AWS account`, `unauthenticated route -> authenticated route`). NOT drawn as a container -- a container with no members is the empty-box defect. Instead the boundary rides the data-flow edge that crosses it: append ` | TB-NNN` to that crossing edge's existing label, and the legend explains the ` | TB-NNN` marker. If more than one edge crosses the same CROSSING boundary, every such edge carries the marker.

DETERMINISTIC CLASSIFICATION TEST (apply to each TB-NNN, in ID order, from 01-inventory.md Section 5 and 02a-context.md's Trust Boundaries table):
1. If 1+ components map INTO the boundary -- i.e. its name is one of the standard zone names (internet/edge, DMZ/perimeter, internal/application, data tier, secured/isolated) OR the inventory/02a explicitly places one or more C-NNN "inside" it -- it is ZONE.
2. Otherwise, if it names two specific endpoint elements (`X -> Y`, `X vs Y`, `X to Y`) and no component is placed inside it, it is CROSSING.
3. A boundary that satisfies neither (no zone name, no two named endpoints) is treated as ZONE by default and its members are whatever components the inventory assigns to it; if it still has zero members it is re-typed CROSSING and rides the edge nearest its two implied endpoints. State the type you assigned each TB-NNN in the diagram's notes so a re-run can confirm the same split.

COMPONENT-TO-ZONE ASSIGNMENT -- every component maps to EXACTLY ONE zone column, computed, never judged:
- If the inventory/02a places the component inside a ZONE-type boundary, its column is that zone.
- FALLBACK (so no component is ever unplaceable): a component whose inventory record assigns it NO trust boundary, or ONLY a CROSSING-type boundary, is placed in the default internal/application zone column. Data stores whose record names a data tier go in the data-tier column; otherwise they too fall back to internal/application. No component is ever left without a column.

LAYOUT FORMULA -- computed, not judged; every coordinate is a function of column index and ID-sorted slot, nothing eyeballed. Columns run left to right in this FIXED order, and ONLY columns that have at least one member appear (absent columns are skipped and the remaining columns close up, so column index `c` is the 0-indexed position among PRESENT columns): human actors (no container), untrusted/internet, DMZ/perimeter, internal/application, data tier, secured/isolated, external systems (no container). Only ZONE-type boundaries produce container columns; CROSSING-type boundaries occupy no column. Geometry (grid-aligned, computed):
- Column origin: column `c` sits at absolute x = 40 + c*520 (column width 260, leaving a 260px inter-column gap -- roomy per the owner's spacing guidance, and it keeps even a 5-column system near the ~2400px target while a busy system grows gracefully wider).
- Top strip: y = 0..60 is reserved for the Rule 16 AI-generation notice cell; the first content row starts at y = 80.
- Container cell (ZONE-type TB only): parent="1", absolute x = column origin, y = 80, width = 260, height = 80 + memberCount*160.
- Member (component inside a container): 0-indexed slot `s` by ascending ID, parented to its TB container, geometry RELATIVE to the container at x = 30, y = 60 + s*160 (a 200-wide node leaves 30px side padding; a 100-tall node leaves a 60px vertical gap between rows).
- Uncontained shape (human actor, external system): parent="1", absolute x = its column origin, absolute y = 80 + s*160 where `s` is its 0-indexed ID-sorted slot within that no-container column.
- Legend box: parent="1", x = 40, y = (bottom edge of the tallest column) + 80, below the columns -- it never adds width.
Edge crossings are NOT your problem -- slot order is by ID, period; the human untangles crossings in draw.io if they care.

LABELS -- exception-based: annotate what is dangerous, join everything else through the tables by ID.
- Component/store/external label: `ID&lt;br&gt;Name` and nothing else (no tech stack, no ports, no env vars -- those live in the inventory, joined by the ID). Line breaks are the `&lt;br&gt;` idiom only.
- Edge label, secure flow (Encryption TLS/mTLS AND AuthN not none/unknown): `DF-NNN 🔒` -- nothing else.
- Edge label, insecure or unknown flow: `DF-NNN ⚠ <protocol>` (e.g. `DF-007 ⚠ HTTP`). The ⚠ flow labels are the only place a protocol name appears on a diagram.
- Edge label, dependency edge with NO backing DF-NNN: EMPTY -- a c4-02 edge derived only from a component's Dependencies field, where 02a-context.md records no corresponding DF-NNN (its coverage check excluded it as "yielded no flow"), carries NO label text (`value=""`). The arrow itself shows the dependency. Do NOT invent an "unconfirmed" or "A-NNN" label -- only a real DF-NNN edge ever gets a `DF-NNN` label with its 🔒/⚠ glyph.
- Boundary-crossing flows across a ZONE-type trust boundary need no extra marker -- the crossing is visible because containment is structural. A flow that crosses a CROSSING-type trust boundary (which has no container) DOES carry a marker: append ` | TB-NNN` to that edge's existing label (so a secure flow crossing TB-004 reads `DF-007 🔒 | TB-004`, and a bare dependency edge crossing it reads just ` | TB-004`). The legend explains the ` | TB-NNN` marker.

Trust boundaries: each TB-NNN is first classified ZONE or CROSSING per the Trust Boundary Typing rule above. A ZONE-type boundary is a draw.io CONTAINER cell, cell id exactly `TB-NNN`, labeled `TB-NNN&lt;br&gt;Name`, zone color per the dictionary. Every component belonging to a ZONE sets `parent="TB-NNN"` with coordinates RELATIVE to that container -- containment is structural, not visual, so a member can never render outside its zone and survives manual drag-editing. Do NOT draw boundaries as free-floating rectangles sized to visually surround members, and do NOT draw a container that would have zero members -- an empty container is the defect this typing rule exists to prevent. A CROSSING-type boundary is NOT a cell at all: it is represented as the ` | TB-NNN` marker on the crossing edge's label (see Labels). So the container count on a diagram equals the number of ZONE-type TB-NNN, and the CROSSING-type TB-NNN are reconciled separately as edge boundary-markers (the Validation step counts both). A component whose zone the inventory/02a does not establish falls back to the internal/application zone column per the Component-to-Zone Assignment rule and is noted in the diagram's notes box.

Threat mapping: place threat IDs (`01`, `02`, ...) in a small text cell adjacent to the affected component; apply the threat stroke override per the dictionary. The threat IDs ARE the cross-reference to the threat table; no separate index.

Legend: every diagram includes the legend box explaining exactly: the zone colors present (untrusted/internet, DMZ/perimeter, internal/application, data tier, secured/isolated -- only those that appear), the threat stroke override, solid vs dashed edges, the 🔒/⚠ glyphs, and the ` | TB-NNN` crossing-boundary marker. Nothing else belongs in it.

AI-generation notice: every diagram includes the AI-generation notice cell required by Operating Rule 16, occupying the reserved top strip (y = 0..60). The notice cell is `parent="1"` at x=40, y=0, width = (rightmost cell's right edge - 40), height=30, style per Rule 16 -- a real cell in `<root>`, not a comment, so it survives PNG/PDF export. The rightmost cell may be an uncontained shape (external system or actor column), not only a container.

### Per-Diagram Specifications

Each diagram inherits all Visual Standards above. The bullets below are only what's unique to that diagram.

Content selection is MECHANICAL for diagrams 1, 2, and 4 -- what appears is a function of the inventory and 02a, not judgment:

**1. `diagrams/c4-01-context.drawio` -- Context Diagram.** Exactly: the system as ONE block (internal component style), every human actor class from the inventory, every EXT-NNN as an external-system shape, and the internet/untrusted boundary. Nothing else.

**2. `diagrams/c4-02-container.drawio` -- Container Diagram.** Exactly: EVERY C-NNN from inventory Section 2 (each styled per its type -- component, data store, or external), every ZONE-type TB-NNN as a container and every CROSSING-type TB-NNN as a ` | TB-NNN` marker on its crossing edge (per Trust Boundary Typing), edges = the component Dependencies fields. A Dependencies-field edge with no backing DF-NNN carries an empty label per the Labels standard. Completeness is counted by the Validation step: C-NNN cells on this diagram MUST equal the inventory component count. Labels per the Labels standard -- no ports, replicas, endpoints, or env vars on shapes.

**3. `diagrams/c4-03-component.drawio` -- Component Diagram (the ONE judgment-permitted diagram).** Internal structure of the primary application component, grounded in what Phase 1 actually recorded for it: its Entry points field, its AuthN/AuthZ and middleware observations, its crypto operations, its data-access paths. Every element drawn must trace to a recorded inventory field or a cited file -- internal layers the inventory did not record are drawn only with a `file:line` citation in the notes box. This diagram is expected to vary between runs; the other three are not.

**4. `diagrams/dfd.drawio` -- Data Flow Diagram.** Gane-Sarson notation, PINNED (never Yourdon): processes = rounded rectangles per the dictionary, data stores = the open-box DFD store style, external entities = the external-system style. Exactly: every DF-NNN from 02a-context.md as an edge (Validation counts them against the 02a total), every ZONE-type TB-NNN as a container and every CROSSING-type TB-NNN as a ` | TB-NNN` marker on its crossing edge (per Trust Boundary Typing). Edge labels follow the exception-based Labels standard -- `DF-NNN 🔒` or `DF-NNN ⚠ protocol`, with ` | TB-NNN` appended when the edge crosses a CROSSING-type boundary, never data type / classification / auth details (those join via the 02a table).

### Validation (mandatory, before STATE.md -- a diagram that fails is not written)

Run this after all four files exist; paste its OUTPUT into the completion banner verbatim (Operating Rule 15). A PARSE FAIL is the unescaped-character failure that makes a file unloadable on the desktop -- fix the file and re-run until every line is clean; never leave a failing file for the user to discover:

Set $SKILL_DIR, $WORKSPACE, and $PROJECT_NAME from the values your briefing names, in the same block as the call (shell state does not persist between tool calls):

```powershell
$SKILL_DIR    = '<SKILL_DIR from your briefing>'
$WORKSPACE    = '<WORKSPACE from your briefing>'
$PROJECT_NAME = '<PROJECT_NAME from your briefing>'

& $SKILL_DIR\scripts\validate-drawio.ps1 -Workspace $WORKSPACE -ProjectName $PROJECT_NAME
```

Reconcile the counts against the source files and state the result: containers on c4-02 and dfd = ZONE-type TB count (NOT the total TB count -- CROSSING-type boundaries are not containers); the CROSSING-type TBs are reconciled separately as edge boundary-markers -- count the ` | TB-NNN` markers on the edges and confirm ZONE-count + CROSSING-count = inventory TB count, stating both numbers; C-NNN cells on c4-02 = inventory component count; edges on dfd = 02a DF count; bad edge refs and bad parents = 0 everywhere. The validator script counts containers mechanically; it does not assert containers == total TB count, because that equality no longer holds once CROSSING-type boundaries ride edges instead of forming containers. Any mismatch in the ZONE + CROSSING reconciliation is a rule violation -- fix the diagram, not the number.

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
