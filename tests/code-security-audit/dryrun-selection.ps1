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
  # Must match partition-plan.ps1's defaults, or the dry run answers a question the real run
  # is not asking.
  [int]$SliceKB = 300,
  [int]$SliceFiles = 40,
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
# TIMED per step. The owner reported a run taking over five minutes; a 1,500-file fixture here
# took 2.7 seconds, so the cost is something this machine does not reproduce -- corporate
# antivirus on every file open, or a network-backed checkout. Guessing which step is slow from
# here has already cost a round trip. Timing each one moves the measurement onto the machine
# where the problem actually happens.
$script:timings = @()

function Step($label, $file, $argv) {
  ""
  "=============================================================================="
  "  $label"
  "=============================================================================="
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  & (Join-Path $scripts $file) @argv | Tee-Object -Variable out
  $sw.Stop()
  $script:captured += @($out)
  $script:timings += [pscustomobject]@{ Step = ($file -replace '\.ps1$',''); Seconds = [math]::Round($sw.Elapsed.TotalSeconds, 1) }
  if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
    Write-Error "$file exited $LASTEXITCODE -- stopping."
    exit 1
  }
}

"FILE SELECTION DRY RUN"
"  repo   : $Repo"
"  project: $name"
"  slice  : ~$SliceKB KB / $SliceFiles files per subagent"

Step 'STEP 1/4  workspace' 'init-workspace.ps1' @{ Workspace = $Repo; ProjectName = $name; Mode = 'STANDALONE' }
Step 'STEP 2/4  manifest -- what exists, and what counts as auditable source' 'manifest.ps1' @{ Workspace = $Repo; ProjectName = $name }
Step 'STEP 3/4  slices -- how the work would be divided among subagents' 'partition-plan.ps1' @{ Workspace = $Repo; ProjectName = $name; SliceKB = $SliceKB; SliceFiles = $SliceFiles }
Step 'STEP 4/4  read list -- what each subagent would read' 'readplan.ps1' @{ Workspace = $Repo; ProjectName = $name; FloorKBPerWorker = $SliceKB; Quiet = $true }

""
"=============================================================================="
"  HOW TO READ THIS"
"=============================================================================="
@"
This is the ENTIRE partitioning decision, and it runs without an agent. Phase 1 in a real run
takes ~20 minutes because a subagent is reading the repository to build the inventory and the
entry-point index -- but none of that changes how the work is divided. That is decided here, by
script, in under a second. So you can see and judge the plan before spending the 20 minutes.

  AUDITABLE (step 2)   The real denominator. Vendored code, images, lock files and build output
                       are gone. Close to the total on a big repo means the exclusions missed
                       something for your stack -- worth reporting.

  SLICES (step 3)      How the work divides. Each slice is one subagent. Read two lines here:

                         CROSS-LAYER FEATURES KEPT TOGETHER -- features whose controller,
                         service and repository live in different directories and were kept in
                         ONE slice anyway. This is the line that matters most: splitting those
                         is what made a worker report it could not validate a finding because
                         the file it needed was in another partition.

                         CONNECTING FILES PULLED IN -- quiet siblings (a service that only
                         forwards a parameter) with no dangerous API of their own, included
                         because they are the middle of the path.

  WAVES (step 3)       Slices divided by how many subagents run at once. Two waves is normal on
                       a large codebase, not a degraded result.

Also watch for files over the single-file limit. Slicing divides BETWEEN files and never within
one, so a file larger than a subagent's whole budget defeats it entirely. Those are named, and
they need reading by hand or in named regions.

Nothing here read file contents for security purposes and no finding was produced. This measured
selection only.
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
$totalKB = 0
foreach ($rs in $readsets) {
  $rows = @(Get-Content -LiteralPath $rs.FullName | Where-Object { $_.Trim() -ne '' })
  # BYTES as well as files. A floor is a claim about one worker's context window and a file count
  # cannot make that claim -- 145 config fragments and 145 service classes differ by 10x.
  $pb = 0
  foreach ($r in $rows) {
    $fp = Join-Path $Repo ((($r -split "`t")[-1]) -replace '/','\')
    if (Test-Path -LiteralPath $fp) { $pb += (Get-Item -LiteralPath $fp).Length }
  }
  $pkb = [math]::Round($pb / 1KB)
  $totalKB += $pkb
  $floors += "$($rs.Name -replace '\.readset\.txt$','')=$($rows.Count)/${pkb}KB"
  foreach ($r in $rows) {
    $p = ($r -split "`t")[-1]
    $e = [System.IO.Path]::GetExtension($p)
    if ([string]::IsNullOrWhiteSpace($e)) { $e = '(none)' }
    if ($extCount.ContainsKey($e)) { $extCount[$e]++ } else { $extCount[$e] = 1 }
  }
}
$topExt = @($extCount.GetEnumerator() | Sort-Object -Property Value -Descending | Select-Object -First 6 |
           ForEach-Object { "$($_.Key)=$($_.Value)" })

# WHY each floored file is in the floor. Without this the only way to tune an over-matching rule
# is to change it, ship it, and ask the owner to re-run -- which is exactly the loop that just
# cost a round trip and still left .sql four times too large.
. (Join-Path $scripts 'lib-classify.ps1')
$reasonCount = @{}
foreach ($rs in $readsets) {
  foreach ($r in @(Get-Content -LiteralPath $rs.FullName | Where-Object { $_.Trim() -ne '' })) {
    $p = ($r -split "`t")[-1]
    $why = Get-SinkReason -Workspace $Repo -RelPath $p
    if (-not $why) { $why = 'role-only(no-sink-test)' }
    if ($reasonCount.ContainsKey($why)) { $reasonCount[$why]++ } else { $reasonCount[$why] = 1 }
  }
}
$topWhy = @($reasonCount.GetEnumerator() | Sort-Object -Property Value -Descending | Select-Object -First 6 |
           ForEach-Object { "$($_.Key)=$($_.Value)" })

$splitHit = @($script:captured | Where-Object { $_ -match 'SPLIT REQUIRED' })
$split = if ($splitHit.Count -gt 0) { 'YES' } else { 'no' }

""
"=============================================================================="
"  REPORT BACK -- copy the lines between the markers, nothing else"
"=============================================================================="
"---8<---"
"repo=$name"
"files=$manifestTotal auditable=$auditTotal workers=$($readsets.Count) split=$split floorKB=$totalKB"
"floor: $($floors -join ' ')"
"ext: $($topExt -join ' ')"
"why: $($topWhy -join ' ')"
"secs: $(($script:timings | ForEach-Object { "$($_.Step)=$($_.Seconds)" }) -join ' ')"
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
