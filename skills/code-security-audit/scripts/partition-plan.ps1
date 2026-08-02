# SKILL VERSION: v2-skill (2026-08-02a)
# skills/code-security-audit/scripts/partition-plan.ps1
#
# Proposes the Phase 2 partition plan: orders every auditable file into one bucket, cuts it into
# subagent-sized slices, writes a machine-readable file list per slice, and seeds
# partition_status.md.
#
# This is a PROPOSAL. GATE 1 exists so the owner approves it before N workers run against
# it -- a wrong partition wastes every worker downstream and is trivially cheap to fix here.
#
# The cap is 5 by design, not by capacity: beyond ~5 the orchestrator's ability to track
# which worker covered what becomes unreliable, and losing that traceability costs more than
# the parallelism gains. A large codebase gets BIGGER partitions, not more of them.
param(
  [Parameter(Mandatory=$true)][string]$Workspace,
  [Parameter(Mandatory=$true)][string]$ProjectName,
  # How many subagents run AT ONCE. Not a cap on the work -- a repository needing 15 slices gets
  # 15, dispatched in waves of this size. This number is about parallelism, nothing else; letting
  # it decide how the work was divided is precisely the mistake this script no longer makes.
  [ValidateRange(1,10)][int]$MaxParallel = 10,
  # Slice size. An ESTIMATE of what one subagent can get through, not a guarantee: a worker that
  # runs out reports where it stopped and the remainder is re-sliced.
  #
  # WAS 500 KB, and that was too aggressive -- the field run hit "parser aborted (timeout,
  # resource-limit, or over-length)". 500 KB is ~125K tokens of source; add ~15K of instructions
  # and it leaves under 60K for reading comprehension, reasoning, THINKING TOKENS, and writing
  # findings, on a 200K window. I had sized it as "what fits" rather than "what fits with room
  # left to do the work", which is the same mistake in a smaller place.
  #
  #   200,000  window
  #   -15,000  instructions and worker context
  #   -75,000  source at 300 KB
  #   =110,000 for reasoning, thinking, and findings -- a real margin rather than a rounding error
  #
  # Erring small is nearly free here: an extra slice is an extra subagent in a wave that already
  # runs 10 at a time. Erring large costs the whole worker.
  [int]$SliceKB = 300,
  [int]$SliceFiles = 40,
  # A single file bigger than this cannot be read whole by a worker with room left to think, and
  # no slicing fixes that -- slices divide BETWEEN files, never within one. Flagged rather than
  # silently packed, because a worker that aborts mid-file produces no finding and no error.
  [int]$MaxFileKB = 120
)

$ErrorActionPreference = 'Stop'
$WORKSPACE = $Workspace.TrimEnd('\')
if (-not (Test-Path -LiteralPath $WORKSPACE)) { Write-Error "Workspace path does not exist: $WORKSPACE"; exit 1 }
$WORKSPACE = (Resolve-Path -LiteralPath $WORKSPACE).Path.TrimEnd('\')

$outDir = Join-Path $WORKSPACE 'audit_state'
$manifestFile = Join-Path $outDir '00-file-manifest.txt'
if (-not (Test-Path -LiteralPath $manifestFile)) {
  Write-Error "00-file-manifest.txt not found at $manifestFile -- run manifest.ps1 BEFORE partitioning. Not partitioning."
  exit 1
}
$manifest = @(Get-Content -LiteralPath $manifestFile | Where-Object { $_ -ne '' })
if ($manifest.Count -eq 0) { Write-Error "Manifest is empty. Not partitioning."; exit 1 }

# ---------------------------------------------------------------------------
# GROUPING
#
# Derive a service root per file. Conventional monorepo container directories
# (services/, apps/, packages/, cmd/) mean the SECOND path segment names the
# service; otherwise the first segment does. Root-level files group as '_root'.
# ---------------------------------------------------------------------------
$containerDirs = @('services','apps','packages','cmd','modules','projects','libs','components')

# Directory names that conventionally hold code used by more than one service. These are
# CANDIDATES for Phase 3B/4B shared-component review, flagged for the owner at GATE 1.
# Name convention only -- the script does not do import analysis, so this is a lead, not a
# conclusion, and Phase 1/2 confirms it against actual usage.
$sharedNames = @('shared','common','core','lib','libs','internal','pkg','util','utils','platform')

function Get-ServiceRoot {
  param([string]$rel)
  $parts = $rel -split '/'
  if ($parts.Count -le 1) { return '_root' }
  if (($containerDirs -contains $parts[0].ToLower()) -and $parts.Count -ge 3) {
    return "$($parts[0])/$($parts[1])"
  }
  return $parts[0]
}

$groups = @{}
foreach ($rel in $manifest) {
  $root = Get-ServiceRoot -rel $rel
  if (-not $groups.ContainsKey($root)) { $groups[$root] = New-Object System.Collections.Generic.List[string] }
  $groups[$root].Add($rel)
}

# ---------------------------------------------------------------------------
# AUDITABLE WEIGHT -- size partitions by SOURCE, not by file count
#
# Weighting by raw file count sends workers to the wrong places. Measured on the owner's
# astrology repo: a 354-file directory of chart DATA outranked every real service root and got
# its own worker, as did a 67-file reports directory. Two of five workers had nothing to audit,
# while the actual auditable surface was 41 files. Adding workers to that plan adds nothing --
# the lever is pointing them at source.
#
# Weight uses exactly the definition readplan.ps1 uses for the read floor (shared in
# lib-classify.ps1), so a partition sized here is verified against the same rule later.
# ---------------------------------------------------------------------------
. (Join-Path $PSScriptRoot 'lib-classify.ps1')

$weights = @{}
foreach ($k in $groups.Keys) {
  $w = 0
  foreach ($rel in $groups[$k]) { if (Test-Auditable -Workspace $WORKSPACE -RelPath $rel) { $w++ } }
  $weights[$k] = $w
}
$totalWeight = 0
foreach ($k in $weights.Keys) { $totalWeight += $weights[$k] }

# Roots with NO auditable source are not given a worker. They are reported, not hidden: a
# silently absent directory is indistinguishable from one nobody thought to look at.
$auditableRoots    = @($groups.Keys | Where-Object { $weights[$_] -gt 0 } | Sort-Object { $weights[$_] } -Descending)
$nonAuditableRoots = @($groups.Keys | Where-Object { $weights[$_] -eq 0 } | Sort-Object)

# ---------------------------------------------------------------------------
# ONE ORDERED BUCKET, CUT INTO SLICES
#
# What this replaced, and why: partitions used to be built from SERVICE ROOTS, one worker per
# root, with a root treated as atomic. A 5,377 KB `src` tree therefore went to ONE worker that
# could hold about a seventh of it, and the machinery grown to cope -- a read floor, a byte
# budget, a recursive partition splitter, coverage arithmetic -- all existed to make that shape
# work. It was solving a problem created by the shape itself.
#
# The owner's model, and it is the right one: put every auditable file in ONE bucket, order it,
# cut it into slices a subagent can finish, and keep dispatching until the bucket is empty.
#
# Two properties matter more than any sizing arithmetic:
#
#   ORDER IS THE SELECTION. Nothing is ever excluded -- files are earlier or later. Stopping
#   after three waves means the three most valuable waves were done, not a random third. That
#   is why the old floor/deferred/SPLIT REQUIRED apparatus is gone rather than tuned: a queue
#   with an end you may choose not to reach needs no coverage guarantee to be honest.
#
#   SLICE SIZE IS AN ESTIMATE, NOT A CONTRACT. A worker that runs out says where it stopped and
#   the remainder returns to the queue. Being wrong costs one extra wave. The previous design
#   made the estimate a precondition, so being wrong blocked the entire audit.
#
# Ordering is by AREA first (service root + its first subdirectory -- where functional areas
# already live in any codebase), areas ranked by the most security-relevant class they contain,
# then within an area by class and path. Sequential slices therefore fall along area boundaries
# most of the time, which buys coherence without a splitter to manufacture it.
$classRank = @{ 'authz' = 0; 'entry-route' = 1; 'config-iac' = 2; 'dep-manifest' = 3; 'ext-call' = 4; 'data-access' = 5; 'app-source' = 6 }

function Get-AreaKey {
  param([string]$Rel, [string]$Root)
  $tail = $Rel
  if ($Root -ne '_root' -and $Rel.StartsWith("$Root/")) { $tail = $Rel.Substring($Root.Length + 1) }
  $parts = @($tail -split '/')
  if ($parts.Count -le 1) { return $Root }
  return "$Root/$($parts[0])"
}

# Every auditable file, with what ordering and sizing need.
$items = New-Object System.Collections.Generic.List[object]
foreach ($r in $auditableRoots) {
  foreach ($rel in $groups[$r]) {
    if (-not (Test-Auditable -Workspace $WORKSPACE -RelPath $rel)) { continue }
    $cls = Get-AuditClass -Path $rel
    $fp = Join-Path $WORKSPACE ($rel -replace '/','\')
    $bytes = 0
    if (Test-Path -LiteralPath $fp) { $bytes = (Get-Item -LiteralPath $fp).Length }
    $rank = 9
    if ($cls -and $classRank.ContainsKey($cls)) { $rank = $classRank[$cls] }
    $items.Add([pscustomobject]@{
      Path = $rel; Root = $r; Area = (Get-AreaKey -Rel $rel -Root $r); Class = $cls; Rank = $rank; Bytes = $bytes
    })
  }
}

# Rank each AREA by the most security-relevant file it holds, so auth and routing areas are
# reviewed before plumbing. Ties break on size (smaller first covers more distinct areas early).
$areaRank = @{}
$areaBytes = @{}
foreach ($it in $items) {
  if (-not $areaRank.ContainsKey($it.Area) -or $it.Rank -lt $areaRank[$it.Area]) { $areaRank[$it.Area] = $it.Rank }
  if (-not $areaBytes.ContainsKey($it.Area)) { $areaBytes[$it.Area] = 0 }
  $areaBytes[$it.Area] += $it.Bytes
}
$ordered = @($items | Sort-Object `
  @{ Expression = { $areaRank[$_.Area] } }, `
  @{ Expression = { $areaBytes[$_.Area] } }, `
  @{ Expression = { $_.Area } }, `
  @{ Expression = { $_.Rank } }, `
  @{ Expression = { $_.Path } })

# Cut. A slice closes when it would exceed either budget, or when the area changes and the slice
# is already substantially full -- preferring an area boundary to a hard cut keeps each worker
# looking at one coherent surface without stranding tiny slices.
$sliceBytes = $SliceKB * 1KB
$slices = New-Object System.Collections.Generic.List[object]
$cur = $null
$prevArea = $null
foreach ($it in $ordered) {
  $wouldExceed = $cur -and ((($cur.Bytes + $it.Bytes) -gt $sliceBytes) -or (($cur.Files.Count + 1) -gt $SliceFiles))
  $areaBreak   = $cur -and $prevArea -and ($it.Area -ne $prevArea) -and ($cur.Bytes -ge ($sliceBytes * 0.6))
  if (-not $cur -or $wouldExceed -or $areaBreak) {
    $cur = [pscustomobject]@{ Areas = (New-Object System.Collections.Generic.List[string]); Files = (New-Object System.Collections.Generic.List[string]); Bytes = 0 }
    $slices.Add($cur)
  }
  if (-not $cur.Areas.Contains($it.Area)) { $cur.Areas.Add($it.Area) }
  $cur.Files.Add($it.Path)
  $cur.Bytes += $it.Bytes
  $prevArea = $it.Area
}

# Name each slice after the area it mostly holds, numbered within that area. This list is what
# the owner reads at GATE 1; an id that does not say what the worker covers is unjudgeable.
$rawNames = @($slices | ForEach-Object {
  $n = ($_.Areas[0] -replace '[^A-Za-z0-9]+','-').Trim('-').ToLower()
  if ([string]::IsNullOrWhiteSpace($n)) { $n = 'slice' }
  $n
})
$seen = @{}
$partitions = New-Object System.Collections.Generic.List[object]
for ($i = 0; $i -lt $slices.Count; $i++) {
  $nm = $rawNames[$i]
  $total = @($rawNames | Where-Object { $_ -eq $nm }).Count
  if (-not $seen.ContainsKey($nm)) { $seen[$nm] = 0 }
  $seen[$nm]++
  $id = if ($total -gt 1) { "$nm-$($seen[$nm])" } else { $nm }
  $partitions.Add([pscustomobject]@{
    Id = $id; Roots = @($slices[$i].Areas); Files = @($slices[$i].Files)
    Weight = $slices[$i].Files.Count; Bytes = $slices[$i].Bytes
  })
}

# NON-AUDITABLE files inside auditable roots are not assigned to a slice -- they are not source
# a worker would review -- but the reconciliation still has to see them.
$unassigned = New-Object System.Collections.Generic.List[string]
$assignedSet = @{}
foreach ($p in $partitions) { foreach ($f in $p.Files) { $assignedSet[$f] = $true } }
foreach ($r in $auditableRoots) {
  foreach ($rel in $groups[$r]) { if (-not $assignedSet.ContainsKey($rel)) { $unassigned.Add($rel) } }
}

# OVERSIZED SINGLE FILES. Slicing divides between files and can never divide within one, so a
# file larger than a worker's whole source budget is a defect the slicer cannot solve. Naming
# them here is the point: a worker handed one aborts partway through with no finding and no
# error, which reads downstream as "nothing found in that file".
$oversize = @($ordered | Where-Object { $_.Bytes -gt ($MaxFileKB * 1KB) } | Sort-Object -Property Bytes -Descending)
if ($oversize.Count -gt 0) {
  ""
  Write-Warning "$($oversize.Count) file(s) exceed $MaxFileKB KB and cannot be read whole by one worker with room left to reason. Slicing cannot help -- slices divide between files, never within one. Review these by hand, or brief a worker to read named regions rather than the whole file:"
  foreach ($o in ($oversize | Select-Object -First 15)) { "    {0,7} KB  {1}" -f [math]::Round($o.Bytes/1KB), $o.Path }
  if ($oversize.Count -gt 15) { "    ... and $($oversize.Count - 15) more" }
  ""
}

$waves = [math]::Ceiling($partitions.Count / [double]$MaxParallel)
"BUCKET: $($ordered.Count) auditable files, $([math]::Round((($ordered | Measure-Object -Property Bytes -Sum).Sum)/1KB)) KB"
"SLICES: $($partitions.Count) (~$SliceKB KB / $SliceFiles files each)"
"WAVES : $waves at $MaxParallel subagents in parallel"
if ($waves -gt 1) {
  "        Dispatch $MaxParallel, wait for the wave, then the next. A worker that runs out of room"
  "        reports where it stopped and the remainder is re-sliced -- it is not lost."
}
# Non-auditable roots still belong to the reconciliation -- every manifest file must be
# accounted for -- but they get no worker.
$nonAuditableFiles = New-Object System.Collections.Generic.List[string]
foreach ($r in $nonAuditableRoots) { foreach ($x in $groups[$r]) { $nonAuditableFiles.Add($x) } }
$partDir = Join-Path $outDir 'partitions'
New-Item -ItemType Directory -Path $partDir -Force | Out-Null

$plan = New-Object System.Collections.Generic.List[string]
$plan.Add('# Partition Plan (PROPOSAL -- requires GATE 1 approval)')
$plan.Add('')
$plan.Add("Generated: $(Get-Date -Format 'yyyy-MM-ddTHH:mm')")
$plan.Add("Manifest total: $($manifest.Count) files")
$plan.Add("Slices: $($partitions.Count), dispatched $MaxParallel at a time")
$plan.Add('')
$plan.Add('| partition_id | files | AUDITABLE | pct of audit surface | service roots |')
$plan.Add('|---|---|---|---|---|')

$assignedTotal = 0
foreach ($p in $partitions) {
  $assignedTotal += $p.Files.Count
  $pct = if ($totalWeight -gt 0) { [math]::Round(100.0 * $p.Weight / $totalWeight, 1) } else { 0 }
  $plan.Add("| $($p.Id) | $($p.Files.Count) | $($p.Weight) | $pct% | $($p.Roots -join ', ') |")
  $listPath = Join-Path $partDir "$($p.Id).txt"
  $p.Files | Set-Content -LiteralPath $listPath -Encoding ASCII
  $chk = Get-Item -LiteralPath $listPath
  if ($chk.Length -eq 0 -and $p.Files.Count -gt 0) { Write-Error "Partition list $listPath wrote zero bytes"; exit 1 }
}

$plan.Add('')
$plan.Add('## Not assigned to any worker (no auditable source)')
$plan.Add('')
if ($nonAuditableRoots.Count -gt 0) {
  $plan.Add("$($nonAuditableFiles.Count) files across $($nonAuditableRoots.Count) root(s) contain no auditable source")
  $plan.Add('and are deliberately given no worker. Listed so their absence is a visible decision:')
  $plan.Add('')
  foreach ($r in $nonAuditableRoots) { $plan.Add("- $r ($($groups[$r].Count) files)") }
  $plan.Add('')
  $plan.Add('If one of these SHOULD be audited, the classifier missed it -- raise it at GATE 1 rather')
  $plan.Add('than assuming the audit covered it.')
} else {
  $plan.Add('None -- every service root holds auditable source.')
}

$plan.Add('')
$plan.Add('## Reconciliation')
$plan.Add('')
$plan.Add("Files assigned to partitions: $assignedTotal")
$plan.Add("Files in non-auditable roots:  $($nonAuditableFiles.Count)")
# Non-auditable files that live INSIDE an auditable root -- docs, tests, assets sitting beside
# real source. They belong to no slice because no worker would review them, but they are still
# manifest files and the reconciliation must see them. Omitting them lost 2 files on a 17-file
# fixture and the suite caught it immediately.
$plan.Add("Non-auditable files inside audited roots: $($unassigned.Count)")
$plan.Add("Manifest total: $($manifest.Count)")
$plan.Add("Auditable surface: $totalWeight files")
$plan.Add("Slices: $($partitions.Count) at ~$SliceKB KB / $SliceFiles files, $MaxParallel in parallel per wave")
$reconTotal = $assignedTotal + $nonAuditableFiles.Count + $unassigned.Count
$plan.Add("Match: $(if ($reconTotal -eq $manifest.Count) { 'yes' } else { "NO -- $reconTotal accounted vs $($manifest.Count) in manifest, FILES LOST, DO NOT PROCEED" })")

# Shared-component candidates, by directory-name convention.
$sharedHits = @($groups.Keys | Where-Object {
  $leaf = ($_ -split '/')[-1].ToLower()
  $sharedNames -contains $leaf
} | Sort-Object)
$plan.Add('')
$plan.Add('## Shared-component candidates (name convention only -- confirm against real usage)')
$plan.Add('')
if ($sharedHits.Count -gt 0) {
  foreach ($s in $sharedHits) { $plan.Add("- $s ($($groups[$s].Count) files)") }
  $plan.Add('')
  $plan.Add('These are LEADS, not conclusions. This script does no import analysis. Phase 2 confirms')
  $plan.Add('which are genuinely cross-service before Phase 3B/4B reviews them.')
} else {
  $plan.Add('None matched by name convention. Phase 2 must still check for cross-service usage.')
}

$planPath = Join-Path $outDir 'partition_plan.md'
$plan | Set-Content -LiteralPath $planPath -Encoding ASCII

# Seed partition_status.md. Every partition starts pending; Phase 3A sets security_complete
# and Phase 4A sets done. No other value is used.
$status = New-Object System.Collections.Generic.List[string]
$status.Add('# Partition Status')
$status.Add('')
$status.Add("Generated: $(Get-Date -Format 'yyyy-MM-ddTHH:mm')")
$status.Add('')
$status.Add('| partition_id | files | status |')
$status.Add('|---|---|---|')
foreach ($p in $partitions) { $status.Add("| $($p.Id) | $($p.Files.Count) | pending |") }
$statusPath = Join-Path $outDir 'partition_status.md'
$status | Set-Content -LiteralPath $statusPath -Encoding ASCII

# ---------------------------------------------------------------------------
# REPORT (every number here is computed, per common.md rule 8)
# ---------------------------------------------------------------------------
"Manifest total: $($manifest.Count)"
"Service-root groups found: $($groups.Keys.Count)"
"  with auditable source: $($auditableRoots.Count) | with none: $($nonAuditableRoots.Count)"
"AUDITABLE SURFACE: $totalWeight files (this, not file count, drives worker count)"
"Slices created: $($partitions.Count) -- dispatch $MaxParallel per wave"
foreach ($p in $partitions) { "  $($p.Id): $($p.Files.Count) files, $($p.Weight) auditable  [$($p.Roots -join ', ')]" }
if ($nonAuditableRoots.Count -gt 0) {
  "NO WORKER ASSIGNED (no auditable source): $($nonAuditableFiles.Count) files across $($nonAuditableRoots.Count) root(s)"
  foreach ($r in $nonAuditableRoots) { "  $r ($($groups[$r].Count) files)" }
}
"Files sliced: $assignedTotal | non-auditable roots: $($nonAuditableFiles.Count) | non-auditable in-root: $($unassigned.Count) | total accounted: $reconTotal"
"Reconciliation: $(if ($reconTotal -eq $manifest.Count) { 'OK' } else { 'MISMATCH' })"
"Written: $planPath, $statusPath, $partDir\*.txt"
"NEXT: run readplan.ps1 to compute each worker's read floor before dispatching anyone."

if ($reconTotal -ne $manifest.Count) {
  Write-Error "Partition reconciliation FAILED: $reconTotal accounted vs $($manifest.Count) in manifest. Files were lost. Refusing to report success."
  exit 1
}

# A repo whose whole auditable surface fits one worker gets one worker. Say so plainly rather
# than letting the owner wonder why five partitions became two -- the count is derived from what
# is actually there to audit, and a small number is the right answer for a small surface.

