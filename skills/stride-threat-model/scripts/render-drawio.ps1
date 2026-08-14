# SKILL VERSION: v26-skill (2026-08-10a)
# skills/stride-threat-model/scripts/render-drawio.ps1
#
# Phase 4 diagram renderer. Consumes a diagram DATA file the agent writes and emits the
# .drawio files, doing every coordinate itself.
#
# Why this is a script and not prose the agent follows: the layout rules are ~50 coordinates,
# a dozen four-decimal attachment fractions and a channel assignment per edge, for every
# diagram. An agent computing that by hand on a 25-component system will get some of it
# wrong, and one wrong coordinate is a visibly broken diagram. The agent supplies the DATA --
# which element is in which tier, which flows exist, which are unprotected -- which is
# classification, and it is good at that. Geometry is arithmetic, and arithmetic belongs here.
#
# Every rule below was confirmed by rendering a sample and looking at the exported PNG.
# Six defects found that way were invisible in the spec text, most of them two individually
# correct rules interacting at a case neither anticipated. See references/phase-4.md.
param(
  [Parameter(Mandatory=$true)][string]$Workspace,
  [Parameter(Mandatory=$true)][string]$ProjectName,
  [string]$DataFile = ''      # defaults to <workspace>\<project>-threat-model\04-diagram-data.json
)

$ErrorActionPreference = 'Stop'
$WORKSPACE    = $Workspace.TrimEnd('\')
$PROJECT_NAME = $ProjectName
$root = "$WORKSPACE\$PROJECT_NAME-threat-model"
if ($DataFile -eq '') { $DataFile = "$root\04-diagram-data.json" }
$outDir = "$root\diagrams"
if (-not (Test-Path $DataFile)) { Write-Error "diagram data not found: $DataFile"; exit 1 }
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Force $outDir | Out-Null }

# ---------------------------------------------------------------- geometry constants
# Nodes sit in cells of a GLOBAL grid. Between every pair of adjacent grid columns is a
# vertical GUTTER, and between every pair of adjacent rows a horizontal one. Gutters hold no
# nodes BY CONSTRUCTION, and every edge travels only through gutters plus a short stub inside
# its own cell -- so no edge can cross a component. The previous model routed in the gap
# between TIERS, which works only while each tier is a single file of nodes; it is why a tier
# could not be wrapped without sending every edge through a box.
$MARGIN = 40; $CELL_W = 400; $CELL_H = 240; $VG = 255; $HG = 187
$MAX_ROWS = 5; $NOTICE_H = 30

$SZ = @{
  component = @(400,200); store = @(320,240); external = @(400,200)
  actor     = @(120,200); process = @(400,200); dfdstore = @(320,240)
}
$STYLE = @{
  component = 'rounded=1;whiteSpace=wrap;html=1;fillColor=#438DD5;strokeColor=#2E6295;fontColor=#FFFFFF;fontSize=20;'
  process   = 'rounded=1;whiteSpace=wrap;html=1;fillColor=#438DD5;strokeColor=#2E6295;fontColor=#FFFFFF;fontSize=20;'
  store     = 'shape=cylinder3;whiteSpace=wrap;html=1;boundedLbl=1;backgroundOutline=1;size=15;fillColor=#438DD5;strokeColor=#2E6295;fontColor=#FFFFFF;fontSize=20;'
  dfdstore  = 'shape=partialRectangle;whiteSpace=wrap;html=1;left=0;right=0;top=1;bottom=1;fillColor=#DAE8FC;strokeColor=#2E6295;fontSize=20;'
  external  = 'rounded=0;whiteSpace=wrap;html=1;fillColor=#999999;strokeColor=#666666;fontColor=#FFFFFF;fontSize=20;'
  actor     = 'shape=umlActor;verticalLabelPosition=bottom;verticalAlign=top;html=1;strokeColor=#666666;fontSize=20;'
}
$ZONE_COLOR = @{ EDGE='#E65100'; APPLICATION='#B58C00'; DATA='#00695C'; SECURED='#2E7D32' }
$ZONE_STYLE = 'rounded=1;container=1;collapsible=0;whiteSpace=wrap;html=1;verticalAlign=top;fontSize=22;fontStyle=1;fillColor=none;dashed=1;strokeWidth=2;strokeColor='
$EDGE_STYLE = 'edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;fontSize=16;endArrow=classic;labelBackgroundColor=#FFFFFF;jettySize=30;jumpStyle=arc;jumpSize=10;'
$LEGEND_STYLE = 'rounded=0;whiteSpace=wrap;html=1;fillColor=#F5F5F5;strokeColor=#666666;fontSize=16;align=left;verticalAlign=top;'
$NOTICE_STYLE = 'text;html=1;strokeColor=none;fillColor=none;align=left;verticalAlign=middle;fontSize=16;fontStyle=2;'
$COL_ORDER = @('ACTORS','EDGE','APPLICATION','DATA','SECURED','EXTERNAL')
$CONTAINED = @('EDGE','APPLICATION','DATA','SECURED')

function Esc([string]$t) {
  if ($null -eq $t) { return '' }
  $t.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;').Replace('"','&quot;')
}
function Up40([double]$v) { return [int]([math]::Ceiling($v / 40.0) * 40) }

# vertical gutter g spans x [ MARGIN + g*(CELL_W+VG) , +VG ]
# grid column  c spans x [ MARGIN + c*(CELL_W+VG) + VG , +CELL_W ]
function VGutLeft($g) { return $MARGIN + $g * ($CELL_W + $VG) }
function ColX($c)     { return $MARGIN + $c * ($CELL_W + $VG) + $VG }
function HGutTop($h)  { return $MARGIN + $h * ($CELL_H + $HG) }
function RowY($r)     { return $MARGIN + $r * ($CELL_H + $HG) + $HG }

# The C4 label convention: name in bold, then the element type and its technology, then a
# one-line description. Rendered with html=1, which every shape style already sets.
#
# DOUBLE ESCAPING IS THE POINT HERE. User text is html-escaped FIRST so a literal '<' in a
# component name displays as a character; the markup is added around it; then the whole
# string is xml-escaped for the attribute. Single-escaping (which is what happens when the
# label is passed straight to Esc) leaves a raw '<' in the decoded value, and html=1 then
# treats it as a tag and silently EATS the rest of the name -- the text does not break the
# file, it disappears, which is far harder to notice.
$TYPE_WORD = @{
  component = 'Container'; process = 'Process'; store = 'Data Store'
  dfdstore  = 'Data Store'; external = 'External System'; actor = 'Person'
}
function HtmlEsc([string]$t) {
  if ($null -eq $t) { return '' }
  $t.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;')
}
function Build-Label($n) {
  $out = '<b>' + (HtmlEsc $n.label) + '</b>'
  $word = $TYPE_WORD[$n.kind]
  if ($n.tech) { $out += '<div style="font-size:15px">[' + $word + ': ' + (HtmlEsc $n.tech) + ']</div>' }
  elseif ($word) { $out += '<div style="font-size:15px">[' + $word + ']</div>' }
  if ($n.description) { $out += '<div style="font-size:14px">' + (HtmlEsc $n.description) + '</div>' }
  return $out
}

function Render-Diagram($d) {
  $nodes = @($d.nodes); $edges = @($d.edges)
  if ($nodes.Count -eq 0) { return $null }

  # NOTE: @() around the inner pipeline is required. In PowerShell 5.1 a Where-Object that
  # matches exactly ONE object returns that object, not an array, and a PSCustomObject has no
  # .Count -- so a tier with a single member silently tested as empty and the whole column was
  # dropped from the layout.
  $present = @($COL_ORDER | Where-Object { $t = $_; @($nodes | Where-Object { $_.tier -eq $t }).Count -gt 0 })
  $cidx = @{}; for ($i=0; $i -lt $present.Count; $i++) { $cidx[$present[$i]] = $i }
  $members = @{}; foreach ($c in $present) { $members[$c] = @($nodes | Where-Object { $_.tier -eq $c }) }

  # ---- BARYCENTRE ORDERING WITHIN TIERS --------------------------------------
  # Decide WHICH member sits in WHICH slot before any coordinate is computed. Members arrive
  # in inventory-id order, which is arbitrary with respect to what connects to what. Each node
  # is pulled toward the average position of everything it connects to, and the columns are
  # swept forward then backward, because reordering one column changes the right answer for
  # its neighbours. SAME-COLUMN EDGES COUNT TOO -- they are exactly the edges that produce
  # long in-tier runs, so leaving them out means the ordering cannot fix what it exists for.
  $order = @{}
  foreach ($c in $present) { $order[$c] = @($members[$c] | ForEach-Object { $_.id }) }
  $colOf = @{}
  foreach ($c in $present) { foreach ($id in $order[$c]) { $colOf[$id] = $c } }
  $nbr = @{}
  foreach ($e in $edges) {
    if (-not $colOf.ContainsKey($e.source) -or -not $colOf.ContainsKey($e.target)) { continue }
    if (-not $nbr.ContainsKey($e.source)) { $nbr[$e.source] = @() }
    if (-not $nbr.ContainsKey($e.target)) { $nbr[$e.target] = @() }
    $nbr[$e.source] += $e.target; $nbr[$e.target] += $e.source
  }
  function Get-NormPos($id, $ord) {
    $c = $colOf[$id]; $k = $ord[$c].Count
    if ($k -le 1) { return 0.5 }
    return ([array]::IndexOf($ord[$c], $id)) / ($k - 1)
  }
  for ($sweep = 0; $sweep -lt 4; $sweep++) {
    $seq = if ($sweep % 2 -eq 0) { $present } else { @($present)[($present.Count-1)..0] }
    foreach ($c in $seq) {
      if ($order[$c].Count -lt 3) { continue }
      $score = @{}
      for ($i = 0; $i -lt $order[$c].Count; $i++) {
        $id = $order[$c][$i]
        if ($nbr.ContainsKey($id) -and $nbr[$id].Count -gt 0) {
          $acc = 0.0; foreach ($o in $nbr[$id]) { $acc += (Get-NormPos $o $order) }
          $score[$id] = $acc / $nbr[$id].Count
        } else { $score[$id] = $i / [math]::Max(1, $order[$c].Count - 1) }
      }
      $order[$c] = @($order[$c] | Sort-Object @{Expression={$score[$_]}}, @{Expression={$_}})
    }
  }
  foreach ($c in $present) {
    $byId = @{}; foreach ($m in $members[$c]) { $byId[$m.id] = $m }
    $members[$c] = @($order[$c] | ForEach-Object { $byId[$_] })
  }

  # ---- GRID ASSIGNMENT --------------------------------------------------------
  # Each tier claims a contiguous RANGE of global grid columns, and a tier with more than
  # MAX_ROWS members WRAPS into more than one of them. This is the point of the whole model:
  # nine components in a single file down the page is not a shape anyone would draw by hand,
  # and it is what forced every other tier to stretch to match.
  $tierCols = @{}; $tierRows = @{}; $tierC0 = @{}
  $cursor = 0
  foreach ($c in $present) {
    $n = $members[$c].Count
    $cols = [int][math]::Ceiling($n / [double]$MAX_ROWS)
    if ($cols -lt 1) { $cols = 1 }
    $tierCols[$c] = $cols
    $tierRows[$c] = [int][math]::Ceiling($n / [double]$cols)
    $tierC0[$c] = $cursor
    $cursor += $cols
  }
  $nCols = $cursor
  $nRows = ($present | ForEach-Object { $tierRows[$_] } | Measure-Object -Maximum).Maximum

  # Column-major fill preserves the barycentre ordering as a vertical sequence; row-major
  # would scatter neighbours across the grid and undo it. Short tiers are CENTRED vertically
  # rather than pinned to the top row -- a one-member edge tier sitting at row 0 while the
  # application tier runs five rows deep leaves its edges climbing the full height.
  $cellOf = @{}
  foreach ($c in $present) {
    $rowOff = [int][math]::Floor(($nRows - $tierRows[$c]) / 2)
    for ($s = 0; $s -lt $members[$c].Count; $s++) {
      $sub = [int][math]::Floor($s / $tierRows[$c])
      $row = $s % $tierRows[$c]
      $cellOf[$members[$c][$s].id] = @{ r = $row + $rowOff; c = $tierC0[$c] + $sub }
    }
  }

  # ---- CELL REFINEMENT --------------------------------------------------------
  # Which SUB-COLUMN a member lands in is decided above by its place in a vertical ordering,
  # which has nothing to do with what it connects to. On a real repo that put two components
  # called directly by the edge tier two sub-columns away from it. Wrapping a tier shortens
  # the column but LENGTHENS the edges unless placement is told to care, and those
  # manufactured long edges are most of the crossings.
  #
  # So: swap members within their own tier while it reduces total edge span. Horizontal span
  # is weighted heavier than vertical because a long horizontal run crosses every vertical run
  # it passes. A BLOCKED route is priced separately: it is not merely longer, it is a
  # different shape -- the edge leaves its row entirely and runs the width of the detour in a
  # shared gutter. Fixed pass count and a strict-improvement test keep this deterministic.
  $edgePairs = @()
  foreach ($e in $edges) {
    if ($cellOf.ContainsKey($e.source) -and $cellOf.ContainsKey($e.target)) {
      $edgePairs += ,@($e.source, $e.target)
    }
  }
  function Span-Cost($cells) {
    $occ = @{}
    foreach ($id in $cells.Keys) { $occ["$($cells[$id].r)|$($cells[$id].c)"] = $true }
    $t = 0.0
    foreach ($p in $edgePairs) {
      $a = $cells[$p[0]]; $b = $cells[$p[1]]
      $t += 3.0 * [math]::Abs($a.c - $b.c) + [math]::Abs($a.r - $b.r)
      $lo = [math]::Min($a.c, $b.c) + 1; $hi = [math]::Max($a.c, $b.c) - 1
      for ($cc = $lo; $cc -le $hi; $cc++) {
        if ($occ["$($b.r)|$cc"]) { $t += 9.0; break }
      }
    }
    return $t
  }
  for ($pass = 0; $pass -lt 6; $pass++) {
    $improved = $false
    foreach ($c in $present) {
      $ids = @($members[$c] | ForEach-Object { $_.id })
      for ($i = 0; $i -lt $ids.Count; $i++) {
        for ($j = $i+1; $j -lt $ids.Count; $j++) {
          $before = Span-Cost $cellOf
          $tmp = $cellOf[$ids[$i]]; $cellOf[$ids[$i]] = $cellOf[$ids[$j]]; $cellOf[$ids[$j]] = $tmp
          $after = Span-Cost $cellOf
          if ($after -lt $before) { $improved = $true }
          else { $tmp = $cellOf[$ids[$i]]; $cellOf[$ids[$i]] = $cellOf[$ids[$j]]; $cellOf[$ids[$j]] = $tmp }
        }
      }
    }
    if (-not $improved) { break }
  }

  # ---- absolute geometry ------------------------------------------------------
  $pos = @{}; $cells = New-Object System.Collections.ArrayList
  foreach ($c in $present) {
    foreach ($n in $members[$c]) {
      $cell = $cellOf[$n.id]
      $w = $SZ[$n.kind][0]; $hh = $SZ[$n.kind][1]
      $x = (ColX $cell.c) + [int](($CELL_W - $w) / 2)
      $y = (RowY $cell.r) + [int](($CELL_H - $hh) / 2)
      $pos[$n.id] = @{ x=$x; y=$y; w=$w; h=$hh; r=$cell.r; c=$cell.c; tier=$c }
    }
  }

  # ---- exit / entry fans ------------------------------------------------------
  # Order each node's edges by the other end's centre y so parallel runs do not cross in front
  # of the shape they leave.
  #
  # PER-NODE PHASE: every node in a grid row spans the same band of y, so a plain (i+1)/(k+1)
  # fan puts node A's second exit at exactly the height of node B's second entry -- and those
  # two horizontal stubs then overlay inside the shared gutter and draw as ONE line. Shifting
  # each node's fan by a fraction of a lane, keyed to its position in the row, separates them
  # without a global lane allocation that would be far too tight to see.
  $exits = @{}; $entries = @{}
  foreach ($e in $edges) {
    if (-not $pos.ContainsKey($e.source) -or -not $pos.ContainsKey($e.target)) { continue }
    if (-not $exits.ContainsKey($e.source))   { $exits[$e.source] = @() }
    if (-not $entries.ContainsKey($e.target)) { $entries[$e.target] = @() }
    $exits[$e.source]   += $e.target
    $entries[$e.target] += $e.source
  }
  $rowMembers = @{}
  foreach ($id in $pos.Keys) {
    $r = $pos[$id].r
    if (-not $rowMembers.ContainsKey($r)) { $rowMembers[$r] = @() }
    $rowMembers[$r] += $id
  }
  $phase = @{}
  foreach ($r in @($rowMembers.Keys)) {
    $ord = @($rowMembers[$r] | Sort-Object { $pos[$_].x }, { $_ })
    for ($i=0; $i -lt $ord.Count; $i++) { $phase[$ord[$i]] = $i / [double]([math]::Max(1, $ord.Count)) }
  }
  $exitF = @{}; $entryF = @{}
  foreach ($k in @($exits.Keys)) {
    $sorted = @($exits[$k] | Sort-Object { $pos[$_].y + $pos[$_].h / 2 }, { $_ })
    $n = $sorted.Count
    for ($i=0; $i -lt $n; $i++) {
      $exitF["$k|$($sorted[$i])"] = [math]::Round(0.10 + 0.80 * (($i + 0.5 + 0.4 * $phase[$k]) / $n), 4)
    }
  }
  foreach ($k in @($entries.Keys)) {
    $sorted = @($entries[$k] | Sort-Object { $pos[$_].y + $pos[$_].h / 2 }, { $_ })
    $n = $sorted.Count
    for ($i=0; $i -lt $n; $i++) {
      $entryF["$($sorted[$i])|$k"] = [math]::Round(0.10 + 0.80 * (($i + 0.5 + 0.4 * $phase[$k]) / $n), 4)
    }
  }

  $y1Of = @{}; $y2Of = @{}
  foreach ($e in $edges) {
    if (-not $pos.ContainsKey($e.source) -or -not $pos.ContainsKey($e.target)) { continue }
    $k = "$($e.source)|$($e.target)"
    $y1Of[$k] = [int]($pos[$e.source].y + $pos[$e.source].h * $exitF[$k])
    $y2Of[$k] = [int]($pos[$e.target].y + $pos[$e.target].h * $entryF[$k])
  }

  # ---- ROUTE PLAN -------------------------------------------------------------
  # Forward (target to the right): leave by the source's RIGHT into vertical gutter c1+1,
  # arrive at the target's LEFT out of vertical gutter c2. When those are the same gutter the
  # route is one vertical run and needs no horizontal gutter at all.
  #
  # NOTE the per-edge horizontal-gutter index is $hgIdx, never $hg: PowerShell variable names
  # are CASE-INSENSITIVE, so $hg and the $HG gutter-height constant are ONE variable, and
  # assigning a row index to it silently set $HG to 1 -- collapsing every horizontal channel
  # into a 1px band that read as four edges sharing a single line through two data stores.
  $occupied = @{}
  foreach ($id in $pos.Keys) { $occupied["$($pos[$id].r)|$($pos[$id].c)"] = $true }
  $plan = @{}
  $hCount = @{}
  # Deterministic order: the gutter choice is greedy and congestion-aware, so the order edges
  # are planned in has to be fixed or the same input would render differently each run.
  foreach ($e in @($edges | Sort-Object { "$($_.source)|$($_.target)" })) {
    if (-not $pos.ContainsKey($e.source) -or -not $pos.ContainsKey($e.target)) { continue }
    $sp = $pos[$e.source]; $tp = $pos[$e.target]
    $k = "$($e.source)|$($e.target)"
    if ($tp.c -gt $sp.c) {
      $vg1 = $sp.c + 1; $vg2 = $tp.c; $exSide = 'R'; $enSide = 'L'
    } elseif ($tp.c -lt $sp.c) {
      $vg1 = $sp.c; $vg2 = $tp.c + 1; $exSide = 'L'; $enSide = 'R'
    } else {
      $vg1 = $sp.c + 1; $vg2 = $vg1; $exSide = 'R'; $enSide = 'R'
    }
    $hgIdx = $null
    if ($vg1 -ne $vg2) {
      # DETOUR ONLY WHEN THE WAY IS ACTUALLY BLOCKED. The final horizontal approach runs at
      # the TARGET's height across the columns between the two nodes, so it is the TARGET's
      # row that must be clear -- not the source's. An unconditional detour was sending edges
      # over the top of the page that had a clear run straight in.
      $lo = [math]::Min($sp.c, $tp.c) + 1; $hi = [math]::Max($sp.c, $tp.c) - 1
      $blocked = $false
      for ($cc = $lo; $cc -le $hi; $cc++) {
        if ($occupied["$($tp.r)|$cc"]) { $blocked = $true; break }
      }
      if ($blocked) {
        # NEAREST USABLE GUTTER, not always the one above the target. "Above the target" is
        # the outer top margin for anything in row 0, which put most of the long traffic in
        # one lane across the top of the whole page. Cost is the vertical detour both ends
        # must make plus a congestion charge, so a popular lane stops being the cheapest.
        $best = $null; $bestCost = [double]::MaxValue
        for ($h = 0; $h -le $nRows; $h++) {
          $yc = (HGutTop $h) + $HG / 2
          $used = 0; if ($hCount.ContainsKey($h)) { $used = $hCount[$h] }
          $cost = [math]::Abs($yc - $y1Of[$k]) + [math]::Abs($yc - $y2Of[$k]) + 140 * $used
          if ($cost -lt $bestCost) { $bestCost = $cost; $best = $h }
        }
        $hgIdx = $best
        if (-not $hCount.ContainsKey($best)) { $hCount[$best] = 0 }
        $hCount[$best] = $hCount[$best] + 1
      }
    }
    $plan[$k] = @{ vg1=$vg1; vg2=$vg2; hg=$hgIdx; exSide=$exSide; enSide=$enSide }
  }

  # ---- channel allocation inside every gutter ---------------------------------
  # Two runs in the same gutter must not share an x (or a y). Collect every user of each
  # gutter, sort geometrically so neighbours stay neighbours, then spread them evenly.
  $vUse = @{}; $hUse = @{}
  foreach ($k in $plan.Keys) {
    $p = $plan[$k]
    foreach ($g in @($p.vg1, $p.vg2) | Select-Object -Unique) {
      if (-not $vUse.ContainsKey($g)) { $vUse[$g] = @() }
      $vUse[$g] += $k
    }
    if ($null -ne $p.hg) {
      if (-not $hUse.ContainsKey($p.hg)) { $hUse[$p.hg] = @() }
      $hUse[$p.hg] += $k
    }
  }
  function Mid($k, $axis) {
    $ids = $k -split '\|'
    $a = $pos[$ids[0]]; $b = $pos[$ids[1]]
    if ($axis -eq 'y') { return ($a.y + $a.h/2) + ($b.y + $b.h/2) }
    return ($a.x + $a.w/2) + ($b.x + $b.w/2)
  }
  $vChan = @{}; $hChan = @{}
  foreach ($g in @($vUse.Keys)) {
    $lst = @($vUse[$g] | Sort-Object { Mid $_ 'y' }, { $_ })
    for ($i=0; $i -lt $lst.Count; $i++) {
      $vChan["$g|$($lst[$i])"] = [int]((VGutLeft $g) + ($i+1) * $VG / ($lst.Count+1))
    }
  }
  foreach ($h in @($hUse.Keys)) {
    $lst = @($hUse[$h] | Sort-Object { Mid $_ 'x' }, { $_ })
    for ($i=0; $i -lt $lst.Count; $i++) {
      $hChan["$h|$($lst[$i])"] = [int]((HGutTop $h) + ($i+1) * $HG / ($lst.Count+1))
    }
  }

  # ---- emit zones and members -------------------------------------------------
  foreach ($c in $present) {
    $isContained = $CONTAINED -contains $c
    $xs = @(); $ys = @()
    foreach ($n in $members[$c]) { $q = $pos[$n.id]; $xs += $q.x; $xs += ($q.x+$q.w); $ys += $q.y; $ys += ($q.y+$q.h) }
    $zx = ($xs | Measure-Object -Minimum).Minimum - 60
    $zy = ($ys | Measure-Object -Minimum).Minimum - 90
    $zw = ($xs | Measure-Object -Maximum).Maximum - $zx + 60
    $zh = ($ys | Measure-Object -Maximum).Maximum - $zy + 60
    if ($isContained) {
      [void]$cells.Add(('<mxCell id="zone-{0}" value="{0}" style="{1}{2};" vertex="1" parent="1"><mxGeometry x="{3}" y="{4}" width="{5}" height="{6}" as="geometry"/></mxCell>' -f `
        $c, $ZONE_STYLE, $ZONE_COLOR[$c], $zx, $zy, $zw, $zh))
    }
    foreach ($n in $members[$c]) {
      $q = $pos[$n.id]
      $sty = $STYLE[$n.kind]
      # THREAT OVERRIDE -- the only meaning of a red or orange shape border.
      if ($n.threat -eq 'P1') { $sty = $sty -replace 'strokeColor=#[0-9A-Fa-f]{6}','strokeColor=#CC0000'; $sty += 'strokeWidth=3;' }
      elseif ($n.threat -eq 'P2') { $sty = $sty -replace 'strokeColor=#[0-9A-Fa-f]{6}','strokeColor=#E65100'; $sty += 'strokeWidth=3;' }
      if ($isContained) {
        [void]$cells.Add(('<mxCell id="{0}" value="{1}" style="{2}" vertex="1" parent="zone-{3}"><mxGeometry x="{4}" y="{5}" width="{6}" height="{7}" as="geometry"/></mxCell>' -f `
          $n.id, (Esc (Build-Label $n)), $sty, $c, ($q.x-$zx), ($q.y-$zy), $q.w, $q.h))
      } else {
        [void]$cells.Add(('<mxCell id="{0}" value="{1}" style="{2}" vertex="1" parent="1"><mxGeometry x="{3}" y="{4}" width="{5}" height="{6}" as="geometry"/></mxCell>' -f `
          $n.id, (Esc (Build-Label $n)), $sty, $q.x, $q.y, $q.w, $q.h))
      }
    }
  }

  # ---- emit edges -------------------------------------------------------------
  foreach ($e in $edges) {
    if (-not $pos.ContainsKey($e.source) -or -not $pos.ContainsKey($e.target)) { continue }
    $k = "$($e.source)|$($e.target)"; $p = $plan[$k]
    $fo = $exitF[$k]; $fi = $entryF[$k]
    $y1 = $y1Of[$k]; $y2 = $y2Of[$k]

    if ($p.exSide -eq 'R') { $ax = 'exitX=1;exitY={0};' -f $fo } else { $ax = 'exitX=0;exitY={0};' -f $fo }
    if ($p.enSide -eq 'L') { $bx = 'entryX=0;entryY={0};' -f $fi } else { $bx = 'entryX=1;entryY={0};' -f $fi }
    $att = $ax + 'exitDx=0;exitDy=0;exitPerimeter=0;' + $bx + 'entryDx=0;entryDy=0;entryPerimeter=0;'

    $x1 = $vChan["$($p.vg1)|$k"]; $x2 = $vChan["$($p.vg2)|$k"]
    # ArrayList, NOT @(@(..),@(..)). PowerShell UNWRAPS a one-element array of arrays, so the
    # single-waypoint case collapsed into two scalars and emitted <mxPoint x="890" y=""/>.
    $wp = New-Object System.Collections.ArrayList
    if ($null -eq $p.hg) {
      [void]$wp.Add(@($x1,$y1))
      if ($y1 -ne $y2) { [void]$wp.Add(@($x1,$y2)) }
    } else {
      $yh = $hChan["$($p.hg)|$k"]
      [void]$wp.Add(@($x1,$y1)); [void]$wp.Add(@($x1,$yh))
      [void]$wp.Add(@($x2,$yh)); [void]$wp.Add(@($x2,$y2))
    }
    $pts = '<Array as="points">' + (($wp | ForEach-Object { '<mxPoint x="{0}" y="{1}"/>' -f $_[0], $_[1] }) -join '') + '</Array>'

    $st = $EDGE_STYLE + $att
    if ($e.async) { $st += 'dashed=1;' }
    if (-not $e.secure) { $st += 'strokeColor=#CC0000;strokeWidth=3;' }

    # The label sits at x=-0.4 along the edge (-1 is the source end, 1 the target). At the
    # DEFAULT midpoint a label lands on whatever the line happens to cross: rendering a real
    # repo put 'in-process' on top of a component's own title and 'HTTPS' on a database
    # cylinder. Biasing toward the source keeps it in the gutter just outside the shape.
    [void]$cells.Add(('<mxCell id="e-{0}-{1}" value="{2}" style="{3}" edge="1" parent="1" source="{0}" target="{1}"><mxGeometry x="-0.4" relative="1" as="geometry">{4}</mxGeometry></mxCell>' -f `
      $e.source, $e.target, (Esc $e.protocol), $st, $pts))
  }

  # ---- legend (leftmost column dead space) and AI notice ----------------------
  # LEGEND PLACEMENT. Centring short tiers vertically is worth 23 -> 9 edge crossings, but it
  # opens a large void at the TOP LEFT: a one-member edge tier now sits mid-height while the
  # application tier runs the full five rows. Parking the legend below all content then left
  # that void empty AND stretched the page. So the legend fills the void when the void exists,
  # and falls back below the content when it does not -- checked against the actual node
  # rectangles rather than assumed, because a diagram whose first tier IS tall has no void and
  # a legend pinned to the top would land on a component.
  $bottom = ($pos.Values | ForEach-Object { $_.y + $_.h } | Measure-Object -Maximum).Maximum
  $legendY = $NOTICE_H + 40
  foreach ($q in $pos.Values) {
    if ($q.x -lt 1100 -and $q.y -lt ($legendY + 360 + 60) -and ($q.y + $q.h) -gt ($legendY - 60)) {
      $legendY = $bottom + 160; break
    }
  }
  $legendLines = @('LEGEND','')
  foreach ($c in $present) { if ($ZONE_COLOR.ContainsKey($c)) { $legendLines += "$c tier" } }
  $legendLines += @('','Red thick edge = unencrypted or unauthenticated flow',
                    'Dashed edge = async / queued',
                    'Thick red/orange SHAPE border = a Priority 1/2 threat touches it','',
                    'Edge labels show the PROTOCOL only.','Full flow detail is in 02a-context.md.')
  [void]$cells.Add(('<mxCell id="legend" value="{0}" style="{1}" vertex="1" parent="1"><mxGeometry x="40" y="{2}" width="480" height="360" as="geometry"/></mxCell>' -f `
    ((Esc ($legendLines -join "`n")).Replace("`n",'&#10;')), $LEGEND_STYLE, $legendY))

  if ($d.notes -and @($d.notes).Count -gt 0) {
    $noteText = (Esc (@('NOTES','') + @($d.notes) -join "`n")).Replace("`n",'&#10;')
    [void]$cells.Add(('<mxCell id="notes" value="{0}" style="{1}" vertex="1" parent="1"><mxGeometry x="560" y="{2}" width="480" height="360" as="geometry"/></mxCell>' -f `
      $noteText, $LEGEND_STYLE, $legendY))
  }

  $right = ($pos.Values | ForEach-Object { $_.x + $_.w } | Measure-Object -Maximum).Maximum
  $cells.Insert(0, ('<mxCell id="notice" value="{0}" style="{1}" vertex="1" parent="1"><mxGeometry x="40" y="0" width="{2}" height="{3}" as="geometry"/></mxCell>' -f `
    'AI-GENERATED -- this diagram was produced by an AI tool and requires human review.', $NOTICE_STYLE, ($right - 40), $NOTICE_H))

  $pw = [math]::Max(2400, (Up40 ($right + 40)))
  $ph = [math]::Max(1600, (Up40 ([math]::Max($bottom, $legendY + 360) + 80)))

  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine('<mxfile host="app.diagrams.net">')
  [void]$sb.AppendLine(('  <diagram id="{0}" name="{1}">' -f $d.name, (Esc $d.title)))
  [void]$sb.AppendLine(('    <mxGraphModel grid="1" gridSize="10" page="1" pageWidth="{0}" pageHeight="{1}">' -f $pw, $ph))
  [void]$sb.AppendLine('      <root>')
  [void]$sb.AppendLine('        <mxCell id="0"/>')
  [void]$sb.AppendLine('        <mxCell id="1" parent="0"/>')
  foreach ($c in $cells) { [void]$sb.AppendLine('        ' + $c) }
  [void]$sb.AppendLine('      </root>')
  [void]$sb.AppendLine('    </mxGraphModel>')
  [void]$sb.AppendLine('  </diagram>')
  [void]$sb.AppendLine('</mxfile>')

  return [pscustomobject]@{ xml=$sb.ToString(); pw=$pw; ph=$ph; nodes=$pos.Count; edges=$edges.Count; grid=("{0}x{1}" -f $nCols,$nRows); gutters=$vUse }
}

# ---------------------------------------------------------------- main
$data = Get-Content -Raw -LiteralPath $DataFile | ConvertFrom-Json
foreach ($d in $data.diagrams) {
  $r = Render-Diagram $d
  if ($null -eq $r) { Write-Host ("SKIP {0}: no nodes" -f $d.name); continue }
  $path = "$outDir\$($d.name).drawio"
  [System.IO.File]::WriteAllText($path, $r.xml, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host ("WROTE {0}  page {1}x{2}  grid {3}  nodes {4}  edges {5}" -f $d.name, $r.pw, $r.ph, $r.grid, $r.nodes, $r.edges)
  foreach ($k in ($r.gutters.Keys | Sort-Object)) {
    $m = @($r.gutters[$k]).Count
    $flag = ''
    if ($m -gt 8) { $flag = '  <-- ABOVE the 8-edge legible limit; this diagram should be split' }
    Write-Host ("  gutter {0}: {1} vertical runs{2}" -f $k, $m, $flag)
  }
}
Write-Host "RENDER COMPLETE"
