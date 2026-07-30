#!/usr/bin/env python3
"""
tests/stride-threat-model/make-sample-diagram.py

Generates a sample c4-02 container diagram by following references/phase-4.md EXACTLY --
the same arithmetic a Phase 4 agent is told to use. Not shipped with the skill.

The point is to close the verification loop on diagram layout. Every layout change to
phase-4.md so far has been reasoned from the spec text with nothing rendered, which is how
regressions like the 160/400 pitch mismatch shipped. Run this, open the .drawio, export a
PNG, and the layout can be LOOKED AT.

If this script and phase-4.md ever disagree, phase-4.md is authoritative and this is the bug.

Sample system is shaped like the field application that prompted the complaint:
a human actor, an edge tier, an application tier, three environment databases, and two
external systems -- including skip-column flows and unprotected flows.
"""
import os

# ----------------------------------------------------------------- spec constants
COL_PITCH   = 720
COL_W       = 480
V_PITCH     = 500
ZONE_Y      = 80
MEMBER_Y0   = 80
ZONE_H_BASE = 120
GAP         = 320          # node-to-node horizontal gap
NOTICE_H    = 30
LANE_Y      = 0

SZ = {"component": (400, 200), "store": (320, 240), "external": (400, 200), "actor": (120, 200)}

STYLE = {
 "component": "rounded=1;whiteSpace=wrap;html=1;fillColor=#438DD5;strokeColor=#2E6295;fontColor=#FFFFFF;fontSize=20;",
 "store":     "shape=cylinder3;whiteSpace=wrap;html=1;boundedLbl=1;backgroundOutline=1;size=15;fillColor=#438DD5;strokeColor=#2E6295;fontColor=#FFFFFF;fontSize=20;",
 "external":  "rounded=0;whiteSpace=wrap;html=1;fillColor=#999999;strokeColor=#666666;fontColor=#FFFFFF;fontSize=20;",
 "actor":     "shape=umlActor;verticalLabelPosition=bottom;verticalAlign=top;html=1;strokeColor=#666666;fontSize=20;",
}
ZONE_COLOR = {"EDGE": "#E65100", "APPLICATION": "#B58C00", "DATA": "#00695C", "SECURED": "#2E7D32"}
ZONE_STYLE = ("rounded=1;container=1;collapsible=0;whiteSpace=wrap;html=1;verticalAlign=top;"
              "fontSize=22;fontStyle=1;fillColor=none;dashed=1;strokeWidth=2;strokeColor=%s;")
EDGE_STYLE = ("edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;fontSize=16;endArrow=classic;"
              "labelBackgroundColor=#FFFFFF;jettySize=30;")
LEGEND_STYLE = "rounded=0;whiteSpace=wrap;html=1;fillColor=#F5F5F5;strokeColor=#666666;fontSize=16;align=left;verticalAlign=top;"
NOTICE_STYLE = "text;html=1;strokeColor=none;fillColor=none;align=left;verticalAlign=middle;fontSize=16;fontStyle=2;"

# ----------------------------------------------------------------- sample system
# (id, label, kind, column)
NODES = [
 ("A-01",   "End User",          "actor",     "ACTORS"),
 ("C-01",   "Akamai WAF",        "component", "EDGE"),
 ("C-02",   "Traefik Ingress",   "component", "EDGE"),
 ("C-03",   "Web Application",   "component", "APPLICATION"),
 ("C-04",   "Admin Portal",      "component", "APPLICATION"),
 ("C-05",   "Reporting API",     "component", "APPLICATION"),
 ("C-06",   "Batch Worker",      "component", "APPLICATION"),
 ("DS-01",  "Prod Database",     "store",     "DATA"),
 ("DS-02",  "Redis Cache",       "store",     "DATA"),
 ("EXT-01", "Bing Maps",         "external",  "EXTERNAL"),
 ("EXT-02", "SMTP Relay",        "external",  "EXTERNAL"),
]
# (source, target, protocol, secure?)
EDGES = [
 ("A-01", "C-01",   "HTTPS",     True),
 ("C-01", "C-02",   "HTTPS",     True),    # same column: bottom -> top attachment
 ("C-02", "C-03",   "HTTP",      False),   # attested plaintext hop after TLS termination
 ("C-02", "C-04",   "HTTP",      False),
 ("C-02", "C-05",   "HTTP",      False),
 ("C-03", "DS-01",  "TLS/5432",  True),
 ("C-03", "DS-02",  "TLS/6379",  True),
 ("C-04", "DS-01",  "TLS/5432",  True),
 ("C-05", "DS-01",  "TLS/5432",  True),
 ("C-06", "DS-01",  "TLS/5432",  True),
 ("C-06", "DS-02",  "6379",      False),
 ("C-03", "EXT-01", "HTTPS",     True),    # skips DATA -> long-haul lane
 ("C-06", "EXT-02", "SMTP",      False),   # skips DATA -> long-haul lane
]

COL_ORDER = ["ACTORS", "EDGE", "APPLICATION", "DATA", "SECURED", "EXTERNAL"]
CONTAINED = {"EDGE", "APPLICATION", "DATA", "SECURED"}


def build():
    present = [c for c in COL_ORDER if any(n[3] == c for n in NODES)]
    cidx = {c: i for i, c in enumerate(present)}
    origin = lambda c: 40 + cidx[c] * COL_PITCH

    members = {c: [n for n in NODES if n[3] == c] for c in present}
    pos, cells = {}, []

    # zone containers + members
    for c in present:
        ox = origin(c)
        if c in CONTAINED:
            mh = max(SZ[n[2]][1] for n in members[c])
            h = MEMBER_Y0 + (len(members[c]) - 1) * V_PITCH + mh + 80
            cells.append('<mxCell id="zone-%s" value="%s" style="%s" vertex="1" parent="1">'
                         '<mxGeometry x="%d" y="%d" width="%d" height="%d" as="geometry"/></mxCell>'
                         % (c, c, ZONE_STYLE % ZONE_COLOR[c], ox, ZONE_Y, COL_W, h))
        for s, (nid, label, kind, _) in enumerate(members[c]):
            w, hh = SZ[kind]
            if c in CONTAINED:
                rx, ry = (COL_W - w) // 2, MEMBER_Y0 + s * V_PITCH
                cells.append('<mxCell id="%s" value="%s" style="%s" vertex="1" parent="zone-%s">'
                             '<mxGeometry x="%d" y="%d" width="%d" height="%d" as="geometry"/></mxCell>'
                             % (nid, label, STYLE[kind], c, rx, ry, w, hh))
                pos[nid] = (ox + rx, ZONE_Y + ry, w, hh, cidx[c])
            else:
                ax, ay = ox, ZONE_Y + s * V_PITCH
                cells.append('<mxCell id="%s" value="%s" style="%s" vertex="1" parent="1">'
                             '<mxGeometry x="%d" y="%d" width="%d" height="%d" as="geometry"/></mxCell>'
                             % (nid, label, STYLE[kind], ax, ay, w, hh))
                pos[nid] = (ax, ay, w, hh, cidx[c])

    tallest = max((ZONE_Y + MEMBER_Y0 + (len(members[c]) - 1) * V_PITCH
                   + max(SZ[n[2]][1] for n in members[c]) + 80) if c in CONTAINED
                  else (ZONE_Y + (len(members[c]) - 1) * V_PITCH + max(SZ[n[2]][1] for n in members[c]))
                  for c in present)
    global LANE_Y
    LANE_Y = tallest + 40

    # fan attachment points: exits ordered by target id, entries by source id
    exits, entries = {}, {}
    for src, tgt, _, _ in EDGES:
        exits.setdefault(src, []).append(tgt)
        entries.setdefault(tgt, []).append(src)
    for d in (exits, entries):
        for k in d:
            d[k].sort()

    corridor = {}
    for src, tgt, _, _ in EDGES:
        cs, ct = pos[src][4], pos[tgt][4]
        if ct > cs:
            corridor.setdefault(cs, []).append((src, tgt))
    for k in corridor:
        corridor[k].sort()

    for src, tgt, proto, secure in EDGES:
        sx, sy, sw, sh, cs = pos[src]
        tx, ty, tw, th, ct = pos[tgt]
        ei, ek = exits[src].index(tgt), len(exits[src])
        ni, nk = entries[tgt].index(src), len(entries[tgt])
        f_out, f_in = round((ei + 1) / (ek + 1), 4), round((ni + 1) / (nk + 1), 4)

        if ct > cs:
            att = "exitX=1;exitY=%s;exitDx=0;exitDy=0;exitPerimeter=0;entryX=0;entryY=%s;entryDx=0;entryDy=0;entryPerimeter=0;" % (f_out, f_in)
        elif ct < cs:
            att = "exitX=0;exitY=%s;exitDx=0;exitDy=0;exitPerimeter=0;entryX=1;entryY=%s;entryDx=0;entryDy=0;entryPerimeter=0;" % (f_out, f_in)
        else:
            att = "exitX=%s;exitY=1;exitDx=0;exitDy=0;exitPerimeter=0;entryX=%s;entryY=0;entryDx=0;entryDy=0;entryPerimeter=0;" % (f_out, f_in)

        st = EDGE_STYLE + att + ("" if secure else "strokeColor=#CC0000;strokeWidth=3;")

        pts = ""
        y_out, y_in = int(sy + sh * f_out), int(ty + th * f_in)
        if ct - cs >= 2:
            # rule 4: long-haul lane below every container
            pts = ('<Array as="points"><mxPoint x="%d" y="%d"/><mxPoint x="%d" y="%d"/></Array>'
                   % (sx + sw + 40, LANE_Y, tx - 40, LANE_Y))
        elif ct > cs and cs in corridor:
            lst = corridor[cs]
            i, m = lst.index((src, tgt)), len(lst)
            gap_left = 40 + cs * COL_PITCH + 440
            wx = int(gap_left + (i + 1) * GAP / (m + 1))
            # TWO waypoints pin the whole middle run: enter the channel at the exit
            # height, leave it at the entry height. One waypoint let the router
            # collapse neighbouring edges onto a shared segment.
            pts = ('<Array as="points"><mxPoint x="%d" y="%d"/><mxPoint x="%d" y="%d"/></Array>'
                   % (wx, y_out, wx, y_in))

        cells.append('<mxCell id="e-%s-%s" value="%s" style="%s" edge="1" parent="1" source="%s" target="%s">'
                     '<mxGeometry relative="1" as="geometry">%s</mxGeometry></mxCell>'
                     % (src, tgt, proto, st, src, tgt, pts))

    right = max(x + w for x, y, w, h, _ in pos.values())
    legend_y = tallest + 160
    cells.append('<mxCell id="legend" value="%s" style="%s" vertex="1" parent="1">'
                 '<mxGeometry x="40" y="%d" width="480" height="360" as="geometry"/></mxCell>'
                 % ("LEGEND&#10;&#10;EDGE / DMZ (orange)&#10;APPLICATION (amber)&#10;DATA (teal)"
                    "&#10;&#10;Red thick edge = unencrypted or&#10;unauthenticated flow"
                    "&#10;Dashed edge = async / queued"
                    "&#10;&#10;Edge labels show the PROTOCOL only.&#10;Full flow detail is in 02a-context.md.",
                    LEGEND_STYLE, legend_y))
    cells.insert(0, '<mxCell id="notice" value="%s" style="%s" vertex="1" parent="1">'
                    '<mxGeometry x="40" y="0" width="%d" height="%d" as="geometry"/></mxCell>'
                    % ("AI-GENERATED -- this diagram was produced by an AI tool and requires human review.",
                       NOTICE_STYLE, right - 40, NOTICE_H))

    up40 = lambda v: ((v + 39) // 40) * 40
    pw, ph = max(2400, up40(right + 40)), max(1600, up40(legend_y + 360 + 80))

    xml = ('<mxfile host="app.diagrams.net">\n'
           '  <diagram id="c4-02" name="Container">\n'
           '    <mxGraphModel grid="1" gridSize="10" page="1" pageWidth="%d" pageHeight="%d">\n'
           '      <root>\n        <mxCell id="0"/>\n        <mxCell id="1" parent="0"/>\n        %s\n'
           '      </root>\n    </mxGraphModel>\n  </diagram>\n</mxfile>\n'
           % (pw, ph, "\n        ".join(cells)))

    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sample-c4-02-container.drawio")
    open(out, "w", encoding="utf-8", newline="\n").write(xml)
    print("wrote %s" % out)
    print("  page      : %d x %d" % (pw, ph))
    print("  columns   : %s" % ", ".join(present))
    print("  cells     : %d nodes, %d edges" % (len(pos), len(EDGES)))
    for c in sorted(corridor):
        n = len(corridor[c])
        flag = "  <-- ABOVE the 8-edge legible limit" if n > 8 else ""
        print("  corridor %d->%d: %d edges%s" % (c, c + 1, n, flag))


if __name__ == "__main__":
    build()
