# SKILL VERSION: v26-skill (2026-07-30a)
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
$COL_PITCH = 720; $COL_W = 480; $V_PITCH = 400; $ZONE_Y = 80; $MEMBER_Y0 = 80
$GAP = 320; $NOTICE_H = 30; $UNCONTAINED_GAP = 160; $ENTRY_SEP = 45; $ENTRY_INSET = 30

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

  $pos = @{}; $cells = New-Object System.Collections.ArrayList

  # ---- containers and members ------------------------------------------------
  foreach ($c in $present) {
    $ox = 40 + $cidx[$c] * $COL_PITCH
    $isContained = $CONTAINED -contains $c
    if ($isContained) {
      $mh = ($members[$c] | ForEach-Object { $SZ[$_.kind][1] } | Measure-Object -Maximum).Maximum
      $h  = $MEMBER_Y0 + ($members[$c].Count - 1) * $V_PITCH + $mh + 80
      [void]$cells.Add(('<mxCell id="zone-{0}" value="{0}" style="{1}{2};" vertex="1" parent="1"><mxGeometry x="{3}" y="{4}" width="{5}" height="{6}" as="geometry"/></mxCell>' -f `
        $c, $ZONE_STYLE, $ZONE_COLOR[$c], $ox, $ZONE_Y, $COL_W, $h))
    }
    for ($s=0; $s -lt $members[$c].Count; $s++) {
      $n = $members[$c][$s]; $w = $SZ[$n.kind][0]; $hh = $SZ[$n.kind][1]
      $sty = $STYLE[$n.kind]
      # THREAT OVERRIDE -- the only meaning of a red or orange shape border.
      if ($n.threat -eq 'P1') { $sty = $sty -replace 'strokeColor=#[0-9A-Fa-f]{6}','strokeColor=#CC0000'; $sty += 'strokeWidth=3;' }
      elseif ($n.threat -eq 'P2') { $sty = $sty -replace 'strokeColor=#[0-9A-Fa-f]{6}','strokeColor=#E65100'; $sty += 'strokeWidth=3;' }
      if ($isContained) {
        $rx = [int](($COL_W - $w) / 2); $ry = $MEMBER_Y0 + $s * $V_PITCH
        [void]$cells.Add(('<mxCell id="{0}" value="{1}" style="{2}" vertex="1" parent="zone-{3}"><mxGeometry x="{4}" y="{5}" width="{6}" height="{7}" as="geometry"/></mxCell>' -f `
          $n.id, (Esc $n.label), $sty, $c, $rx, $ry, $w, $hh))
        $pos[$n.id] = @{ x=$ox+$rx; y=$ZONE_Y+$ry; w=$w; h=$hh; col=$cidx[$c]; cell=$cells.Count-1; contained=$true }
      } else {
        # provisional slot; the barycentre pass below moves it
        $pos[$n.id] = @{ x=$ox; y=$ZONE_Y + $s*$V_PITCH; w=$w; h=$hh; col=$cidx[$c]; cell=-1; contained=$false; kind=$n.kind; label=$n.label; sty=$sty }
      }
    }
  }

  # ---- BARYCENTRE PLACEMENT for uncontained columns --------------------------
  # Each node sits at the mean y of the CENTRES of what it connects to elsewhere. ID order is
  # arbitrary with respect to connectivity: it once left an SMTP relay at the top of a diagram
  # joined to its only neighbour at the bottom by a full-height vertical.
  foreach ($c in $present) {
    if ($CONTAINED -contains $c) { continue }
    $want = @()
    foreach ($n in $members[$c]) {
      $ns = @()
      foreach ($e in $edges) {
        $other = $null
        if ($e.source -eq $n.id) { $other = $e.target } elseif ($e.target -eq $n.id) { $other = $e.source }
        if ($other -and $pos.ContainsKey($other) -and $pos[$other].col -ne $cidx[$c]) {
          $ns += ($pos[$other].y + $pos[$other].h / 2)
        }
      }
      $h = $SZ[$n.kind][1]
      if ($ns.Count -gt 0) { $y = (($ns | Measure-Object -Average).Average) - $h/2 } else { $y = $pos[$n.id].y }
      $want += [pscustomobject]@{ y=$y; id=$n.id; h=$h }
    }
    $prevBottom = $ZONE_Y
    foreach ($it in ($want | Sort-Object y)) {
      $y = [int]$it.y; if ($y -lt $prevBottom) { $y = $prevBottom }
      $pos[$it.id].y = $y
      $prevBottom = $y + $it.h + $UNCONTAINED_GAP
    }
    foreach ($n in $members[$c]) {
      $p = $pos[$n.id]
      [void]$cells.Add(('<mxCell id="{0}" value="{1}" style="{2}" vertex="1" parent="1"><mxGeometry x="{3}" y="{4}" width="{5}" height="{6}" as="geometry"/></mxCell>' -f `
        $n.id, (Esc $n.label), $p.sty, $p.x, $p.y, $p.w, $p.h))
    }
  }

  $tallest = 0
  foreach ($c in $present) {
    $b = ($members[$c] | ForEach-Object { $pos[$_.id].y + $pos[$_.id].h } | Measure-Object -Maximum).Maximum
    if ($CONTAINED -contains $c) { $b += 80 }
    if ($b -gt $tallest) { $tallest = $b }
  }
  $laneY = $tallest + 40

  # ---- EXIT FAN, ordered by the TARGET's centre y (geometric, not id) ---------
  $exits = @{}
  foreach ($e in $edges) {
    if (-not $exits.ContainsKey($e.source)) { $exits[$e.source] = @() }
    $exits[$e.source] += $e.target
  }
  foreach ($k in @($exits.Keys)) {
    $exits[$k] = @($exits[$k] | Sort-Object { $pos[$_].y + $pos[$_].h / 2 })
  }
  $exitY = @{}
  foreach ($src in $exits.Keys) {
    $k = $exits[$src].Count
    for ($i=0; $i -lt $k; $i++) {
      $exitY["$src|$($exits[$src][$i])"] = [math]::Round(($i + 1) / ($k + 1), 4)
    }
  }

  # ---- ENTRY ALIGNMENT (not a blind fan) -------------------------------------
  # Each entry wants its source's exit height and moves only to avoid a collision. Fanning
  # both ends independently steps an edge whose endpoints are already level.
  $entries = @{}
  foreach ($e in $edges) {
    if (-not $entries.ContainsKey($e.target)) { $entries[$e.target] = @() }
    $entries[$e.target] += $e.source
  }
  $entryY = @{}
  foreach ($tgt in $entries.Keys) {
    $tp = $pos[$tgt]
    $want = @()
    foreach ($src in $entries[$tgt]) {
      $sp = $pos[$src]
      $want += [pscustomobject]@{ y = $sp.y + $sp.h * $exitY["$src|$tgt"]; src = $src }
    }
    $lo = $tp.y + $ENTRY_INSET; $hi = $tp.y + $tp.h - $ENTRY_INSET
    $ordered = @($want | Sort-Object y)
    $k = $ordered.Count
    # Alignment first: each entry wants its source's exit height. But clamping into the band
    # and then nudging by ENTRY_SEP STACKS every saturated want on the same bound -- and
    # saturation is the NORMAL case, because a target's sources usually sit well above or
    # below it. That drew three separate flows into one data store as a SINGLE arrowhead.
    # So: if the clamped wants cannot be separated by ENTRY_SEP, abandon alignment for this
    # target and distribute evenly across the band instead. A slight jog on every edge is
    # vastly better than several edges rendered as one.
    $needed = ($k - 1) * $ENTRY_SEP
    if ($k -gt 1 -and $needed -gt ($hi - $lo)) { $step = ($hi - $lo) / [math]::Max(1, $k - 1) }
    else { $step = $ENTRY_SEP }
    $clamped = @(); foreach ($it in $ordered) { $clamped += [math]::Min([math]::Max($it.y, $lo), $hi) }
    $distinct = @($clamped | Sort-Object -Unique).Count
    if ($k -gt 1 -and $distinct -lt $k) {
      # wants collapsed -- spread evenly, preserving their relative order
      for ($i = 0; $i -lt $k; $i++) { $entryY["$($ordered[$i].src)|$tgt"] = $lo + $i * (($hi - $lo) / ($k - 1)) }
    } else {
      $prev = $null
      foreach ($it in $ordered) {
        $y = [math]::Min([math]::Max($it.y, $lo), $hi)
        if ($null -ne $prev -and ($y - $prev) -lt $step) { $y = $prev + $step }
        if ($y -gt $hi) { $y = $hi }
        $entryY["$($it.src)|$tgt"] = $y
        $prev = $y
      }
    }
  }

  # ---- corridor channels ------------------------------------------------------
  $corridor = @{}
  foreach ($e in $edges) {
    $cs = $pos[$e.source].col; $ct = $pos[$e.target].col
    if ($ct -eq $cs + 1) {
      if (-not $corridor.ContainsKey($cs)) { $corridor[$cs] = @() }
      $corridor[$cs] += "$($e.source)|$($e.target)"
    }
  }
  # Order channels GEOMETRICALLY (by the edge's mid height), not by the "src|tgt" string.
  # Alphabetical order threw away the same principle the exit fan establishes above, and let
  # two edges whose endpoints are both near the top take the leftmost and rightmost channels
  # -- crossing each other in the corridor for no reason.
  foreach ($k in @($corridor.Keys)) {
    $corridor[$k] = @($corridor[$k] | Sort-Object {
      $p = $_ -split '\|'
      ($pos[$p[0]].y + $pos[$p[0]].h / 2) + ($pos[$p[1]].y + $pos[$p[1]].h / 2)
    }, { $_ })
  }

  $gutterIdx = @{}
  # ---- edges ------------------------------------------------------------------
  foreach ($e in $edges) {
    $sp = $pos[$e.source]; $tp = $pos[$e.target]
    $cs = $sp.col; $ct = $tp.col
    $fOut = $exitY["$($e.source)|$($e.target)"]
    $yOut = [int]($sp.y + $sp.h * $fOut)
    $yIn  = [int]$entryY["$($e.source)|$($e.target)"]
    $fIn  = [math]::Round((($yIn - $tp.y) / $tp.h), 4)

    $pts = ''
    if ($ct -gt $cs) {
      $att = "exitX=1;exitY=$fOut;exitDx=0;exitDy=0;exitPerimeter=0;entryX=0;entryY=$fIn;entryDx=0;entryDy=0;entryPerimeter=0;"
    } elseif ($ct -lt $cs) {
      $att = "exitX=0;exitY=$fOut;exitDx=0;exitDy=0;exitPerimeter=0;entryX=1;entryY=$fIn;entryDx=0;entryDy=0;entryPerimeter=0;"
    } else {
      # SAME COLUMN. Straight down (bottom -> top) is correct ONLY when nothing sits between
      # the two nodes. With a nine-member tier it is not: a wrapper feeding a generator four
      # slots below drove its edge straight THROUGH two unrelated components. Test for an
      # intervening node and, if there is one, run down the container's left gutter instead.
      $between = $false
      $loY = [math]::Min($sp.y + $sp.h, $tp.y); $hiY = [math]::Max($sp.y, $tp.y + $tp.h)
      foreach ($kv in $pos.GetEnumerator()) {
        if ($kv.Key -eq $e.source -or $kv.Key -eq $e.target) { continue }
        if ($kv.Value.col -eq $cs -and $kv.Value.y -lt $hiY -and ($kv.Value.y + $kv.Value.h) -gt $loY) { $between = $true; break }
      }
      if ($between) {
        # nodes are 400 wide centred in a 480 container, so the 40px margin is free space.
        # FAN the gutter across that margin: a single shared x drew every gutter edge in the
        # column on top of every other, which is the same collapse the corridor channels
        # exist to prevent.
        if (-not $gutterIdx.ContainsKey($cs)) { $gutterIdx[$cs] = 0 }
        $gi = $gutterIdx[$cs]; $gutterIdx[$cs] = $gi + 1
        $gut = (40 + $cs * $COL_PITCH) + 8 + (($gi % 4) * 9)
        $att = "exitX=0;exitY=$fOut;exitDx=0;exitDy=0;exitPerimeter=0;entryX=0;entryY=$fIn;entryDx=0;entryDy=0;entryPerimeter=0;"
        $pts = '<Array as="points"><mxPoint x="{0}" y="{1}"/><mxPoint x="{0}" y="{2}"/></Array>' -f $gut, $yOut, $yIn
      } else {
        # adjacent: entry is on the TOP edge, so the fraction is an X position. A Y-derived
        # value here produces an S-bend. Align on X.
        $att = "exitX=$fOut;exitY=1;exitDx=0;exitDy=0;exitPerimeter=0;entryX=$fOut;entryY=0;entryDx=0;entryDy=0;entryPerimeter=0;"
      }
    }

    $st = $EDGE_STYLE + $att
    if ($e.async) { $st += 'dashed=1;' }
    if (-not $e.secure) { $st += 'strokeColor=#CC0000;strokeWidth=3;' }

    if (($ct - $cs) -ge 2) {
      # DETOUR ONLY WHEN NECESSARY, and only as far as necessary.
      $blockers = @()
      foreach ($kv in $pos.GetEnumerator()) {
        if ($kv.Value.col -gt $cs -and $kv.Value.col -lt $ct) {
          $blockers += ,@($kv.Value.y, $kv.Value.y + $kv.Value.h)
        }
      }
      $isClear = {
        param($y)
        foreach ($b in $blockers) { if ($y -gt ($b[0] - 60) -and $y -lt ($b[1] + 60)) { return $false } }
        return $true
      }
      if (-not (& $isClear $yOut)) {
        $cands = @()
        foreach ($b in $blockers) { $cands += ($b[0] - 80); $cands += ($b[1] + 80) }
        # a band clear of every NODE can still run through the tier titles
        $cands = @($cands | Where-Object { (& $isClear $_) -and $_ -gt ($ZONE_Y + 100) })
        if ($cands.Count -gt 0) {
          $band = ($cands | Sort-Object { [math]::Abs($_ - $yOut) })[0]
        } else { $band = $laneY }
        $pts = '<Array as="points"><mxPoint x="{0}" y="{1}"/><mxPoint x="{2}" y="{1}"/></Array>' -f `
               ($sp.x + $sp.w + 40), $band, ($tp.x - 40)
      }
    } elseif ($ct -eq $cs + 1 -and $corridor.ContainsKey($cs)) {
      $lst = $corridor[$cs]; $m = $lst.Count
      $i = [array]::IndexOf($lst, "$($e.source)|$($e.target)")
      $gapLeft = 40 + $cs * $COL_PITCH + 440
      $wx = [int]($gapLeft + ($i + 1) * $GAP / ($m + 1))
      # TWO waypoints. One lets the router collapse neighbouring edges onto a shared segment.
      # two identical points are junk in the model and two stacked drag handles in the editor
      if ($yOut -eq $yIn) { $pts = '<Array as="points"><mxPoint x="{0}" y="{1}"/></Array>' -f $wx, $yOut }
      else { $pts = '<Array as="points"><mxPoint x="{0}" y="{1}"/><mxPoint x="{0}" y="{2}"/></Array>' -f $wx, $yOut, $yIn }
    }

    # The label sits at x=-0.4 along the edge (-1 is the source end, 1 the target). At the
    # DEFAULT midpoint a label lands on whatever the line happens to cross: rendering a real
    # repo put 'in-process' on top of a component's own title and 'HTTPS' on a database
    # cylinder. Biasing toward the source keeps it in the gutter or corridor just left.
    [void]$cells.Add(('<mxCell id="e-{0}-{1}" value="{2}" style="{3}" edge="1" parent="1" source="{0}" target="{1}"><mxGeometry x="-0.4" relative="1" as="geometry">{4}</mxGeometry></mxCell>' -f `
      $e.source, $e.target, (Esc $e.protocol), $st, $pts))
  }

  # ---- legend (leftmost column dead space) and AI notice ----------------------
  $firstColBottom = ($members[$present[0]] | ForEach-Object { $pos[$_.id].y + $pos[$_.id].h } | Measure-Object -Maximum).Maximum
  $legendY = $firstColBottom + 160
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
  $ph = [math]::Max(1600, (Up40 ([math]::Max($tallest, $legendY + 360) + 80)))

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

  return [pscustomobject]@{ xml=$sb.ToString(); pw=$pw; ph=$ph; nodes=$pos.Count; edges=$edges.Count; corridor=$corridor }
}

# ---------------------------------------------------------------- main
$data = Get-Content -Raw -LiteralPath $DataFile | ConvertFrom-Json
foreach ($d in $data.diagrams) {
  $r = Render-Diagram $d
  if ($null -eq $r) { Write-Host ("SKIP {0}: no nodes" -f $d.name); continue }
  $path = "$outDir\$($d.name).drawio"
  [System.IO.File]::WriteAllText($path, $r.xml, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host ("WROTE {0}  page {1}x{2}  nodes {3}  edges {4}" -f $d.name, $r.pw, $r.ph, $r.nodes, $r.edges)
  foreach ($k in ($r.corridor.Keys | Sort-Object)) {
    $m = $r.corridor[$k].Count
    $flag = ''
    if ($m -gt 8) { $flag = '  <-- ABOVE the 8-edge legible limit; this diagram should be split' }
    Write-Host ("  corridor {0}->{1}: {2} edges{3}" -f $k, ($k+1), $m, $flag)
  }
}
Write-Host "RENDER COMPLETE"
