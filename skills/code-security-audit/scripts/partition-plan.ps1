# SKILL VERSION: v1-skill (2026-07-29a)
# skills/code-security-audit/scripts/partition-plan.ps1
#
# Proposes the Phase 2 partition plan: groups the file manifest into at most -MaxPartitions
# service-scoped partitions, writes a machine-readable file list per partition, and seeds
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
  [ValidateRange(1,10)][int]$MaxPartitions = 10,
  # Auditable files one worker can read and still have budget to reason and write findings.
  [int]$FloorPerWorker = 60
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

# N is derived from the auditable surface, not from how many directories exist. Most repos need
# fewer workers than the cap allows; a repo justifying 8 needs a floor around 480 files.
$surfaceN = [math]::Ceiling($totalWeight / [double]$FloorPerWorker)
if ($surfaceN -lt 1) { $surfaceN = 1 }
$targetN = $surfaceN
if ($targetN -gt $MaxPartitions) { $targetN = $MaxPartitions }
# A service root is ATOMIC here: roots can be merged into fewer workers but one root is never
# split across two. So the achievable parallelism is bounded by how many auditable roots exist,
# regardless of how much source any one of them holds. Remember WHY the clamp bound, because the
# two reasons need opposite messages -- a small surface is fine, an unsplittable root is not.
$clampedByRoots = ($targetN -gt $auditableRoots.Count -and $auditableRoots.Count -gt 0)
if ($targetN -gt $auditableRoots.Count) { $targetN = [math]::Max(1, $auditableRoots.Count) }

# Greedy first-fit-decreasing into $targetN bins. Service coherence is preserved -- a worker
# reviewing one service reasons better than one reviewing a balanced but arbitrary slice -- and
# only the WEIGHT changes, not the grouping principle.
$bins = @()
for ($i = 0; $i -lt $targetN; $i++) {
  $bins += ,[pscustomobject]@{ Roots = New-Object System.Collections.Generic.List[string]; Weight = 0 }
}
foreach ($r in $auditableRoots) {
  $lightest = $bins[0]
  foreach ($b in $bins) { if ($b.Weight -lt $lightest.Weight) { $lightest = $b } }
  $lightest.Roots.Add($r)
  $lightest.Weight += $weights[$r]
}

$partitions = New-Object System.Collections.Generic.List[object]
foreach ($b in $bins) {
  if ($b.Roots.Count -eq 0) { continue }
  $files = New-Object System.Collections.Generic.List[string]
  foreach ($r in $b.Roots) { foreach ($x in $groups[$r]) { $files.Add($x) } }
  # Name the partition after its heaviest root so the id stays meaningful.
  $lead = $b.Roots[0]
  $id = ($lead -replace '[^A-Za-z0-9]+','-').Trim('-').ToLower()
  if ($b.Roots.Count -gt 1) { $id = "$id-plus" }
  $partitions.Add([pscustomobject]@{ Id = $id; Roots = @($b.Roots); Files = @($files); Weight = $b.Weight })
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
$plan.Add("Partitions: $($partitions.Count) (cap $MaxPartitions)")
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
$plan.Add("Manifest total: $($manifest.Count)")
$plan.Add("Auditable surface (drives worker count): $totalWeight files")
$plan.Add("Workers: $($partitions.Count) (cap $MaxPartitions, target from surface / $FloorPerWorker per worker)")
$reconTotal = $assignedTotal + $nonAuditableFiles.Count
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
"Workers created: $($partitions.Count) (cap $MaxPartitions, ~$FloorPerWorker auditable files per worker)"
foreach ($p in $partitions) { "  $($p.Id): $($p.Files.Count) files, $($p.Weight) auditable  [$($p.Roots -join ', ')]" }
if ($nonAuditableRoots.Count -gt 0) {
  "NO WORKER ASSIGNED (no auditable source): $($nonAuditableFiles.Count) files across $($nonAuditableRoots.Count) root(s)"
  foreach ($r in $nonAuditableRoots) { "  $r ($($groups[$r].Count) files)" }
}
"Files assigned: $assignedTotal | non-auditable: $($nonAuditableFiles.Count) | total accounted: $reconTotal"
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
if ($clampedByRoots) {
  # The reassuring message below would be FALSE here and was being printed anyway. The surface
  # justified more workers; what refused them was the root count. Saying "the surface is the
  # limit" in this case tells the owner the plan is right when it is actually short.
  Write-Warning ("WORKER COUNT CLAMPED BY ROOT COUNT, NOT BY SURFACE: {0} auditable files justify {1} workers, but there are only {2} auditable service root(s) and a root is never split across workers. Each worker therefore carries more than one worker's share. readplan.ps1 will report SPLIT REQUIRED; the split has to be made at GATE 1." -f $totalWeight, $surfaceN, $auditableRoots.Count)
} elseif ($partitions.Count -lt $MaxPartitions) {
  "NOTE: $($partitions.Count) worker(s) for $totalWeight auditable files. More workers would not"
  "      read more source -- the surface is the limit, not the parallelism."
}