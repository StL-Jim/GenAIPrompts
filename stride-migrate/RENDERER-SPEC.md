# Specification: render-drawio.ps1 and validate-drawio.ps1

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
