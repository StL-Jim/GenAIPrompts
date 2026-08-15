# SKILL VERSION: v2-skill (2026-08-14a)
# skills/code-security-audit/scripts/merge-findings.ps1
#
# Assembles the GLOBAL audit_state/findings_registry.md, attack_paths.md and
# evidence_index.md from every audit_state/workers/<partition_id>/ directory, then computes
# the counts GATE 2 reports.
#
# WHY THIS EXISTS: the carved methodology has each worker phase append to the global
# registry. That is safe for SEQUENTIAL workers, which is what the source prompt mandates.
# This skill runs workers in PARALLEL, where concurrent read-modify-write on one file
# silently drops whichever worker wrote first -- undetectably, since each worker's own write
# verification passes. So workers write only their own partition directory and the
# orchestrator merges here, once, single-threaded.
#
# Runs AFTER all workers return and BEFORE Gate 2, because findings_registry.md is the
# artifact Gate 2 reviews. Phase 5's report assembly is a separate, later step.
param(
  [Parameter(Mandatory=$true)][string]$Workspace,
  [Parameter(Mandatory=$true)][string]$ProjectName
)

$ErrorActionPreference = 'Stop'
$WORKSPACE = $Workspace.TrimEnd('\')
if (-not (Test-Path -LiteralPath $WORKSPACE)) { Write-Error "Workspace path does not exist: $WORKSPACE"; exit 1 }
$WORKSPACE = (Resolve-Path -LiteralPath $WORKSPACE).Path.TrimEnd('\')

$outDir    = Join-Path $WORKSPACE 'audit_state'
$workerDir = Join-Path $outDir 'workers'
if (-not (Test-Path -LiteralPath $workerDir)) {
  Write-Error "No worker directory at $workerDir. Workers have not run, or ran against a different workspace. Nothing to merge."
  exit 1
}

$partitionDirs = @(Get-ChildItem -LiteralPath $workerDir -Directory | Sort-Object Name)
if ($partitionDirs.Count -eq 0) { Write-Error "No partition directories under $workerDir. Nothing to merge."; exit 1 }

# ---------------------------------------------------------------------------
# COMPLETENESS GATE
#
# Cross-check against partition_status.md. A partition that never reached 'done' means a
# worker did not finish, and merging anyway would produce a registry that looks complete.
# ---------------------------------------------------------------------------
$statusPath = Join-Path $outDir 'partition_status.md'
$notDone = @()
if (Test-Path -LiteralPath $statusPath) {
  foreach ($line in Get-Content -LiteralPath $statusPath) {
    if ($line -match '^\|\s*([^|\s]+)\s*\|\s*\d+\s*\|\s*(\w+)\s*\|') {
      if ($Matches[1] -ne 'partition_id' -and $Matches[2] -ne 'done') {
        $notDone += "$($Matches[1]) ($($Matches[2]))"
      }
    }
  }
} else {
  Write-Warning "partition_status.md not found -- cannot cross-check completeness."
}

# ---------------------------------------------------------------------------
# MERGE
# ---------------------------------------------------------------------------
$sources = @(
  @{ Name = 'findings.md';           Target = 'findings_registry.md';   Heading = 'Findings Registry' }
  @{ Name = 'attack_paths.md';       Target = 'attack_paths.md';        Heading = 'Attack Paths' }
  @{ Name = 'evidence_index.md';     Target = 'evidence_index.md';      Heading = 'Evidence Index' }
  # Candidates workers considered and rejected. This is what makes the precondition test
  # checkable rather than merely trusted: without it, a wrongly-rejected finding looks exactly
  # like code nobody examined. Surfaced at GATE 2 as a count by reason, never as a deliverable.
  @{ Name = 'excluded_candidates.md'; Target = 'excluded_candidates.md'; Heading = 'Excluded Candidates' }
  # Questions a worker could establish only half of, because the other half was in a different
  # slice. A field run lost a real vulnerability here: the worker found code building SQL from a
  # parameter, could not tell whether that parameter was attacker-controlled because the caller was
  # outside its slice, correctly declined to file an ungrounded finding, and returned NOTHING.
  # Every step was right and the finding evaporated. Phase 3B resolves these; merging them means
  # an unresolved one is visible instead of sitting in a worker directory nobody opens.
  @{ Name = 'cross_partition_leads.md'; Target = 'cross_partition_leads.md'; Heading = 'Cross-Partition Leads' }
)

$mergeReport = New-Object System.Collections.Generic.List[string]
$allFindingText = ''

foreach ($s in $sources) {
  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add("# $($s.Heading)")
  $lines.Add('')
  $lines.Add("Assembled: $(Get-Date -Format 'yyyy-MM-ddTHH:mm')")
  $lines.Add("Source: $($partitionDirs.Count) partition directories under audit_state/workers/")
  $lines.Add('')

  $inputBytes = 0
  $present = 0
  foreach ($pd in $partitionDirs) {
    $f = Join-Path $pd.FullName $s.Name
    if (-not (Test-Path -LiteralPath $f)) {
      $lines.Add("<!-- partition '$($pd.Name)': no $($s.Name) produced -->")
      $lines.Add('')
      continue
    }
    $present++
    $inputBytes += (Get-Item -LiteralPath $f).Length
    $lines.Add("## Partition: $($pd.Name)")
    $lines.Add('')
    $content = Get-Content -LiteralPath $f
    foreach ($c in $content) { $lines.Add($c) }
    $lines.Add('')
  }

  $targetPath = Join-Path $outDir $s.Target
  $lines | Set-Content -LiteralPath $targetPath -Encoding ASCII
  $chk = Get-Item -LiteralPath $targetPath
  if ($chk.Length -eq 0) { Write-Error "$($s.Target) wrote zero bytes"; exit 1 }
  # A merge must be at least as large as the sum of its inputs (it adds headings).
  if ($inputBytes -gt 0 -and $chk.Length -lt ($inputBytes * 0.95)) {
    Write-Error "$($s.Target) ($($chk.Length) bytes) is materially smaller than its inputs ($inputBytes bytes) -- merge truncated. Do NOT proceed to Gate 2."
    exit 1
  }
  $mergeReport.Add("$($s.Target): $($chk.Length) bytes from $present/$($partitionDirs.Count) partitions (inputs $inputBytes bytes)")
  if ($s.Target -eq 'findings_registry.md') { $allFindingText = (Get-Content -LiteralPath $targetPath -Raw) }
  if ($s.Target -eq 'excluded_candidates.md') { $allExcludedText = (Get-Content -LiteralPath $targetPath -Raw) }
}
if (-not (Test-Path Variable:allExcludedText)) { $allExcludedText = '' }

# ---------------------------------------------------------------------------
# GATE 2 COUNTS
#
# Every number Gate 2 states must be computed command output, never recalled
# (common.md rule N). This is where those numbers come from.
# ---------------------------------------------------------------------------
# The optional leading bullet is not cosmetic tolerance -- it is a bug fix. A field worker
# rendered the compact schema as a markdown bullet list (`- id: F-001`), which is a reasonable
# reading of the schema's example, and the stricter regex matched nothing. The merge then
# reported "Total findings: 0" and exited 0 on a run that had found a leaked API key. Silent
# total loss, reported as success. Accept both shapes.
$ids  = @([regex]::Matches($allFindingText, '(?m)^\s*[-*]?\s*id:\s*(F-\d+)')  | ForEach-Object { $_.Groups[1].Value })
$sevs = @([regex]::Matches($allFindingText, '(?m)^\s*[-*]?\s*sev:\s*(\w+)')   | ForEach-Object { $_.Groups[1].Value })
$clss = @([regex]::Matches($allFindingText, '(?m)^\s*[-*]?\s*class:\s*([\w ]+?)\s*$') | ForEach-Object { $_.Groups[1].Value })
$tms  = @([regex]::Matches($allFindingText, '(?m)^\s*[-*]?\s*threat_match:\s*([\w-]+)') | ForEach-Object { $_.Groups[1].Value })

$dupes = @($ids | Group-Object | Where-Object { $_.Count -gt 1 })

"=== MERGE ==="
$mergeReport | ForEach-Object { "  $_" }

# WHAT WAS NEVER REVIEWED.
#
# Slice size is an estimate, so a worker may return INCOMPLETE and write its remainder to
# unreviewed.txt. Stopping the audit with files still unreviewed is a legitimate choice -- order
# is the selection, and the owner may decide the remaining tail is not worth another wave. What
# is NOT legitimate is that choice being invisible.
#
# Counted here because GATE 2 is where the owner decides what to do with the run. "18 findings"
# and "18 findings, and 143 files were never opened" are different reports, and only one of them
# lets him judge whether to run another wave before sending anything to developers.
$unreviewedFiles = @()
$workersDir = Join-Path $outDir 'workers'
if (Test-Path -LiteralPath $workersDir) {
  foreach ($u in @(Get-ChildItem -LiteralPath $workersDir -Recurse -Filter 'unreviewed.txt' -ErrorAction SilentlyContinue)) {
    $unreviewedFiles += @(Get-Content -LiteralPath $u.FullName | Where-Object { $_.Trim() -ne '' })
  }
}
$unreviewedFiles = @($unreviewedFiles | Sort-Object -Unique)

"=== GATE 2 COUNTS (computed -- quote these, do not restate from memory) ==="
"  Total findings: $($ids.Count)"
# Cross-partition leads that Phase 3B has not yet resolved. A lead is a HALF-ESTABLISHED
# vulnerability -- the most dangerous thing to leave sitting quietly in a worker directory,
# because "no findings in that partition" is exactly how it reads if nobody counts it.
$leadPath = Join-Path $outDir 'cross_partition_leads.md'
$leadCount = 0
if (Test-Path -LiteralPath $leadPath) {
  $leadCount = @(Get-Content -LiteralPath $leadPath | Where-Object { $_ -match '^\s*\S+:\d+\s*\|' }).Count
}
if ($leadCount -gt 0) {
  "  CROSS-PARTITION LEADS: $leadCount -- each is half of a possible finding that one worker"
  "    could not ground because the other half was in a different slice. Phase 3B must resolve"
  "    every one to confirmed, refuted, or explicitly unresolved. If Phase 3B has not run, these"
  "    are NOT 'no findings' -- they are findings nobody finished checking."
}
if ($unreviewedFiles.Count -gt 0) {
  "  NEVER REVIEWED: $($unreviewedFiles.Count) file(s) -- one or more workers ran short of room."
  "    These are listed in audit_state/workers/*/unreviewed.txt and can be picked up by another"
  "    wave. Say this number out loud at GATE 2 alongside the findings count: the audit did not"
  "    look at them, which is not the same as looking and finding nothing."
}
"  By severity:"
if ($sevs.Count -gt 0) { $sevs | Group-Object | Sort-Object Name | ForEach-Object { "    $($_.Name): $($_.Count)" } } else { "    (none parsed)" }
"  By class:"
if ($clss.Count -gt 0) { $clss | Group-Object | Sort-Object Name | ForEach-Object { "    $($_.Name): $($_.Count)" } } else { "    (none parsed)" }
# Only in COORDINATED mode. In STANDALONE every finding carries threat_match: null by
# design, so printing the breakdown adds a line of noise to a report read at GATE 2.
$realTms = @($tms | Where-Object { $_ -ne 'null' })
if ($realTms.Count -gt 0) {
  "  By threat_match (COORDINATED mode):"
  $realTms | Group-Object | Sort-Object Name | ForEach-Object { "    $($_.Name): $($_.Count)" }
  $contra = @($realTms | Where-Object { $_ -eq 'contradicts-exclusion' }).Count
  if ($contra -gt 0) {
    "  NOTE: $contra finding(s) CONTRADICT a threat model exclusion -- the model examined"
    "        that exact concern and judged it handled. Lead with these at GATE 2."
  }
}
# The exclusion profile. One line at GATE 2 unless a number looks wrong, at which point the
# candidates behind any reason are one file away.
$exReasons = @([regex]::Matches($allExcludedText, '(?m)\|\s*(Precondition not reachable|Below severity floor|Fully mitigated|Duplicate of F-\d+)') |
  ForEach-Object { $_.Groups[1].Value -replace 'Duplicate of F-\d+', 'Duplicate' })
"  Excluded candidates: $($exReasons.Count)"
if ($exReasons.Count -gt 0) {
  $exReasons | Group-Object | Sort-Object Count -Descending | ForEach-Object { "    $($_.Name): $($_.Count)" }
  "    (full list: audit_state/excluded_candidates.md -- not a deliverable, read it only if a count looks wrong)"
}

"  Findings per partition:"
$unparseable = @()
$missingFindings = @()
foreach ($pd in $partitionDirs) {
  $f = Join-Path $pd.FullName 'findings.md'
  $n = 0
  $bytes = 0
  $otherFields = 0
  if (Test-Path -LiteralPath $f) {
    $bytes = (Get-Item -LiteralPath $f).Length
    $raw = Get-Content -LiteralPath $f -Raw
    $n = @([regex]::Matches($raw, '(?m)^\s*[-*]?\s*id:\s*F-\d+')).Count
    # Other schema fields present WITHOUT any id is the decisive signal: the worker wrote
    # findings, and this script cannot see them.
    $otherFields = @([regex]::Matches($raw, '(?m)^\s*[-*]?\s*(sev|class|src|impact|fix):\s*\S')).Count
  } else {
    # NO findings.md AT ALL. A worker that ran and produced other output but no findings file
    # has not necessarily found nothing -- it may have written the findings somewhere this
    # script does not read. Field case: a worker wrote findings.csv, and this merge reported
    # "web: 0" and exited 0 while five findings, three of them Critical, were dropped.
    #
    # A stray findings.* is the loud version of the same signal, so name it if present.
    $stray = @(Get-ChildItem -LiteralPath $pd.FullName -File -Filter 'findings.*' -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -ne 'findings.md' })
    $others = @(Get-ChildItem -LiteralPath $pd.FullName -File -ErrorAction SilentlyContinue)
    if ($stray.Count -gt 0) {
      $missingFindings += "$($pd.Name) (no findings.md, but found $(($stray.Name) -join ', ') -- wrong extension)"
    } elseif ($others.Count -gt 0) {
      $missingFindings += "$($pd.Name) (no findings.md; the directory holds $($others.Count) other file(s), so the worker ran)"
    }
    # A completely empty partition directory is not flagged here -- the partition_status gate
    # above already catches a worker that never finished.
  }
  "    $($pd.Name): $n"
  # ZERO parseable findings in a file that plainly CONTAINS findings is not "this partition
  # found nothing" -- it is total silent loss, and the two must never look the same. A real
  # worker rendered the schema as a markdown bullet list and this merge reported success on a
  # run that had found a leaked API key.
  if ($n -eq 0 -and ($otherFields -gt 0 -or $bytes -gt 400)) {
    $unparseable += "$($pd.Name) ($bytes bytes, $otherFields schema field line(s), 0 parseable findings)"
  }
}

# ---------------------------------------------------------------------------
# FAIL CLOSED
# ---------------------------------------------------------------------------
$fatal = @()
if ($dupes.Count -gt 0) {
  $fatal += "DUPLICATE FINDING IDS: $(($dupes | ForEach-Object { "$($_.Name) x$($_.Count)" }) -join ', '). Workers were given overlapping ID blocks, or a worker renumbered another's findings. The registry cannot be trusted."
}
if ($notDone.Count -gt 0) {
  $fatal += "PARTITIONS NOT DONE: $($notDone -join ', '). A worker did not finish. Merging anyway would produce a registry that looks complete."
}
# FIELD VALUES, not just field presence. A block can carry a valid `id:` and `sev:` -- so it
# counts as a finding and passes every guard above -- while other fields hold nonsense. Field run:
# a worker emitted CSV whose header declared 22 columns and one row supplied 21, so every value
# from `verify` onward shifted left and `status` ended up holding the `rel` value `F-001;F-002`.
# Well-formed block, meaningless contents, and nothing detected it. Check the closed enums.
$statuses = @([regex]::Matches($allFindingText, '(?m)^\s*[-*]?\s*status:\s*(\S+)\s*$') | ForEach-Object { $_.Groups[1].Value })
$badStatus = @($statuses | Where-Object { $_ -notin @('open','mitigated','accepted','false_positive') } | Sort-Object -Unique)
if ($badStatus.Count -gt 0) {
  $fatal += "INVALID status VALUE(S): $($badStatus -join ', '). Allowed: open, mitigated, accepted, false_positive. A value outside the enum usually means a worker's fields are misaligned -- the block will look well-formed and its other fields will be wrong too. Check the whole finding, not just this line."
}
$badClass = @($clss | Where-Object { $_ -notin @('Confirmed','Suspected','Not Assessable') } | Sort-Object -Unique)
if ($badClass.Count -gt 0) {
  $fatal += "INVALID class VALUE(S): $($badClass -join ', '). Allowed: Confirmed, Suspected, Not Assessable."
}

$badSev = @($sevs | Where-Object { $_ -notin @('Critical','High') })
if ($badSev.Count -gt 0) {
  $fatal += "SEVERITY SCOPE VIOLATION: $($badSev.Count) finding(s) carry severity outside Critical/High ($(($badSev | Sort-Object -Unique) -join ', ')). The audit never emits these -- a worker kept a finding that did not reach the bar."
}
if ($missingFindings.Count -gt 0) {
  $fatal += "NO findings.md IN: $($missingFindings -join '; '). The worker produced output but this merge found no findings file to read, so whatever it found is invisible to the registry and to GATE 2. Do NOT treat this as 'the partition found nothing'. Fix the filename or re-create findings.md per references/schemas.md, then re-run."
}
if ($unparseable.Count -gt 0) {
  $fatal += "UNPARSEABLE FINDINGS: $($unparseable -join '; '). The file has substantial content but no line matching 'id: F-NNN', so every finding in it is invisible to this merge and to GATE 2. Do NOT treat this as 'the partition found nothing'. Open the file, check the schema shape against references/schemas.md, and re-dispatch or correct the format before proceeding."
}

if ($fatal.Count -gt 0) {
  "=== MERGE FAILED ==="
  $fatal | ForEach-Object { Write-Error $_ }
  exit 1
}

"=== merge-findings complete -- findings_registry.md ready for GATE 2 ==="
