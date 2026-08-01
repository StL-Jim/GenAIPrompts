# tests/code-security-audit/dryrun-selection.ps1
#
# FILE SELECTION DRY RUN -- answers "what would the audit choose to read?" without running one.
#
# The selection stage is pure PowerShell: manifest -> partitions -> read floor. No agent, no
# tokens, no findings, nothing to triage. That makes it the one part of this skill that can be
# field-tested on a large repository at zero cost and zero risk, which is exactly the part that
# has never been exercised at scale.
#
#   ...\dryrun-selection.ps1 -Repo C:\path\to\repo
#
# Creates audit_state\ inside the repo. Nothing else is written and no repo file is modified.
# Remove it afterwards with:  Remove-Item -Recurse -Force <repo>\audit_state
param(
  [Parameter(Mandatory=$true)][string]$Repo,
  [int]$FloorPerWorker = 60,
  # Deletes audit_state\ on the way out. Off by default so the outputs stay readable.
  [switch]$Clean
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Repo)) { Write-Error "No such path: $Repo"; exit 1 }
$Repo = (Resolve-Path -LiteralPath $Repo).Path.TrimEnd('\')
$name = Split-Path -Leaf $Repo

# Scripts live one directory up from tests/, under the skill.
$scripts = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'skills\code-security-audit\scripts'
if (-not (Test-Path -LiteralPath $scripts)) { Write-Error "Cannot locate skill scripts at $scripts"; exit 1 }

$script:captured = @()

function Step($label, $file, $argv) {
  ""
  "=============================================================================="
  "  $label"
  "=============================================================================="
  & (Join-Path $scripts $file) @argv | Tee-Object -Variable out
  $script:captured += @($out)
  if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
    Write-Error "$file exited $LASTEXITCODE -- stopping."
    exit 1
  }
}

"FILE SELECTION DRY RUN"
"  repo   : $Repo"
"  project: $name"
"  floor  : $FloorPerWorker auditable files per worker"

Step 'STEP 1/4  workspace' 'init-workspace.ps1' @{ Workspace = $Repo; ProjectName = $name; Mode = 'STANDALONE' }
Step 'STEP 2/4  manifest -- what exists, and what counts as auditable source' 'manifest.ps1' @{ Workspace = $Repo; ProjectName = $name }
Step 'STEP 3/4  partitions -- how the work would be divided among workers' 'partition-plan.ps1' @{ Workspace = $Repo; ProjectName = $name; FloorPerWorker = $FloorPerWorker }
Step 'STEP 4/4  read floor -- what each worker would be REQUIRED to read in full' 'readplan.ps1' @{ Workspace = $Repo; ProjectName = $name; FloorPerWorker = $FloorPerWorker }

""
"=============================================================================="
"  HOW TO READ THIS"
"=============================================================================="
@"
The three numbers that matter, in order:

  AUDITABLE files (step 2)   Total files is noise -- vendored code, images, lock files and
                             build output are excluded. Auditable is the real denominator.
                             If this is close to the total on a big repo, the exclusions are
                             not catching something and that is a defect worth reporting.

  PARTITION shape (step 3)   How many workers, and whether any partition holds source that
                             does not belong together. A partition with almost no auditable
                             files is wasted; one holding most of them is the bottleneck.

  READ FLOOR (step 4)        The files a worker MUST read in full. This is the number that
                             has never been tested at scale. If it says SPLIT REQUIRED, the
                             floor exceeds what one worker can hold and the selection stage
                             is telling you it cannot cover the repository as partitioned.

SPLIT REQUIRED on a large repository is an EXPECTED result, not a failure. It is the known
gap: selection currently ranks a file as must-read if it holds a dangerous API call, without
requiring that untrusted input reach it. On a large codebase that over-selects. Seeing how
badly, on real code, is the point of this run.

Nothing here read file contents for security purposes and no finding was produced. This
measured selection only.
"@

$stateDir = Join-Path $Repo 'audit_state'

# ---------------------------------------------------------------------------
# REPORT BACK
#
# Everything above is diagnostic prose. This block is the deliverable: the few numbers that
# actually decide whether the selection stage can cover a repository of this size, arranged so
# that reporting them requires no interpretation from the person running it. Deciding which
# output "looks important" is a judgement, and asking a non-developer to make it on a wall of
# script output is how the useful number gets left out.
#
# Read from DISK, not from the console text above -- the files are stable, the prose is not.
# ---------------------------------------------------------------------------
$manifestTotal = 0
$manifestFile = Join-Path $stateDir '00-file-manifest.txt'
if (Test-Path -LiteralPath $manifestFile) {
  $manifestTotal = @(Get-Content -LiteralPath $manifestFile | Where-Object { $_.Trim() -ne '' }).Count
}

$auditTotal = 0
$planFile = Join-Path $stateDir 'partition_plan.md'
if (Test-Path -LiteralPath $planFile) {
  foreach ($row in [regex]::Matches((Get-Content -LiteralPath $planFile -Raw), '(?m)^\|\s*([^|\s][^|]*?)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|')) {
    $auditTotal += [int]$row.Groups[3].Value
  }
}

$readsets = @(Get-ChildItem -LiteralPath (Join-Path $stateDir 'partitions') -Filter '*.readset.txt' -ErrorAction SilentlyContinue)
$floors = @()
$extCount = @{}
foreach ($rs in $readsets) {
  $rows = @(Get-Content -LiteralPath $rs.FullName | Where-Object { $_.Trim() -ne '' })
  $floors += "$($rs.Name -replace '\.readset\.txt$','')=$($rows.Count)"
  foreach ($r in $rows) {
    $p = ($r -split "`t")[-1]
    $e = [System.IO.Path]::GetExtension($p)
    if ([string]::IsNullOrWhiteSpace($e)) { $e = '(none)' }
    if ($extCount.ContainsKey($e)) { $extCount[$e]++ } else { $extCount[$e] = 1 }
  }
}
$topExt = @($extCount.GetEnumerator() | Sort-Object -Property Value -Descending | Select-Object -First 6 |
           ForEach-Object { "$($_.Key)=$($_.Value)" })

$splitHit = @($script:captured | Where-Object { $_ -match 'SPLIT REQUIRED' })
$split = if ($splitHit.Count -gt 0) { 'YES' } else { 'no' }

""
"=============================================================================="
"  REPORT BACK -- copy the lines between the markers, nothing else"
"=============================================================================="
"---8<---"
"repo=$name"
"files=$manifestTotal auditable=$auditTotal workers=$($readsets.Count) split=$split"
"floor: $($floors -join ' ')"
"ext: $($topExt -join ' ')"
"---8<---"
""
"That is the whole report. You are not expected to judge which numbers matter -- these are"
"the ones that do, and 'split=YES' on a large repository is an expected result, not a fault."

""
if ($Clean) {
  Remove-Item -Recurse -Force -LiteralPath $stateDir
  "Removed $stateDir"
} else {
  "Outputs left in: $stateDir"
  "  00-file-manifest.txt   every file, with its classification"
  "  partition_plan.md      the proposed division of work"
  "Remove with: Remove-Item -Recurse -Force `"$stateDir`""
}
