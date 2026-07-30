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
  [ValidateRange(1,5)][int]$MaxPartitions = 5
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

$ordered = @($groups.GetEnumerator() | Sort-Object { $_.Value.Count } -Descending)

# ---------------------------------------------------------------------------
# CAP TO MaxPartitions
#
# Keep the largest groups as coherent partitions; merge the remaining tail into a single
# 'assorted' partition and report exactly what went into it. Coherence is preferred over
# balance because a worker reviewing one service reasons better than one reviewing a
# balanced but arbitrary slice. If the assorted partition ends up larger than the largest
# coherent one, that is surfaced as a WARNING rather than silently accepted -- it means the
# repo's shape does not fit the cap and the owner should see that at GATE 1.
# ---------------------------------------------------------------------------
$partitions = New-Object System.Collections.Generic.List[object]
if ($ordered.Count -le $MaxPartitions) {
  foreach ($g in $ordered) {
    $partitions.Add([pscustomobject]@{ Id = ($g.Key -replace '[^A-Za-z0-9]+','-').Trim('-').ToLower(); Roots = @($g.Key); Files = @($g.Value) })
  }
} else {
  $keep = $ordered[0..($MaxPartitions - 2)]
  $tail = $ordered[($MaxPartitions - 1)..($ordered.Count - 1)]
  foreach ($g in $keep) {
    $partitions.Add([pscustomobject]@{ Id = ($g.Key -replace '[^A-Za-z0-9]+','-').Trim('-').ToLower(); Roots = @($g.Key); Files = @($g.Value) })
  }
  $tailFiles = New-Object System.Collections.Generic.List[string]
  $tailRoots = @()
  foreach ($g in $tail) { $tailRoots += $g.Key; foreach ($f in $g.Value) { $tailFiles.Add($f) } }
  $partitions.Add([pscustomobject]@{ Id = 'assorted'; Roots = $tailRoots; Files = @($tailFiles) })
}

# ---------------------------------------------------------------------------
# WRITE
# ---------------------------------------------------------------------------
$partDir = Join-Path $outDir 'partitions'
New-Item -ItemType Directory -Path $partDir -Force | Out-Null

$plan = New-Object System.Collections.Generic.List[string]
$plan.Add('# Partition Plan (PROPOSAL -- requires GATE 1 approval)')
$plan.Add('')
$plan.Add("Generated: $(Get-Date -Format 'yyyy-MM-ddTHH:mm')")
$plan.Add("Manifest total: $($manifest.Count) files")
$plan.Add("Partitions: $($partitions.Count) (cap $MaxPartitions)")
$plan.Add('')
$plan.Add('| partition_id | files | pct | service roots |')
$plan.Add('|---|---|---|---|')

$assignedTotal = 0
foreach ($p in $partitions) {
  $assignedTotal += $p.Files.Count
  $pct = [math]::Round(100.0 * $p.Files.Count / $manifest.Count, 1)
  $plan.Add("| $($p.Id) | $($p.Files.Count) | $pct% | $($p.Roots -join ', ') |")
  $listPath = Join-Path $partDir "$($p.Id).txt"
  $p.Files | Set-Content -LiteralPath $listPath -Encoding ASCII
  $chk = Get-Item -LiteralPath $listPath
  if ($chk.Length -eq 0 -and $p.Files.Count -gt 0) { Write-Error "Partition list $listPath wrote zero bytes"; exit 1 }
}

$plan.Add('')
$plan.Add('## Reconciliation')
$plan.Add('')
$plan.Add("Files assigned to partitions: $assignedTotal")
$plan.Add("Manifest total: $($manifest.Count)")
$plan.Add("Match: $(if ($assignedTotal -eq $manifest.Count) { 'yes' } else { 'NO -- FILES LOST, DO NOT PROCEED' })")

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
"Service-root groups found: $($ordered.Count)"
"Partitions created: $($partitions.Count) (cap $MaxPartitions)"
foreach ($p in $partitions) { "  $($p.Id): $($p.Files.Count) files  [$($p.Roots -join ', ')]" }
"Files assigned: $assignedTotal"
"Reconciliation: $(if ($assignedTotal -eq $manifest.Count) { 'OK' } else { 'MISMATCH' })"
"Written: $planPath, $statusPath, $partDir\*.txt"

if ($assignedTotal -ne $manifest.Count) {
  Write-Error "Partition reconciliation FAILED: $assignedTotal assigned vs $($manifest.Count) in manifest. Files were lost. Refusing to report success."
  exit 1
}

$assorted = $partitions | Where-Object { $_.Id -eq 'assorted' }
if ($assorted) {
  # Windows PowerShell 5.1's Measure-Object -Property does NOT accept a scriptblock, so
  # project the counts first rather than measuring a calculated property.
  $coherentCounts = @($partitions | Where-Object { $_.Id -ne 'assorted' } | ForEach-Object { $_.Files.Count })
  $largestCoherent = if ($coherentCounts.Count -gt 0) { ($coherentCounts | Measure-Object -Maximum).Maximum } else { 0 }
  if ($assorted.Files.Count -gt $largestCoherent) {
    Write-Warning "The 'assorted' partition ($($assorted.Files.Count) files, $($assorted.Roots.Count) roots) is larger than the largest coherent partition ($largestCoherent). This repo's shape does not fit a $MaxPartitions-partition cap cleanly. Raise this at GATE 1 -- the owner may want different groupings."
  }
}
