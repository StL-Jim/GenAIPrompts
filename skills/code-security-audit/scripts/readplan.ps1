# SKILL VERSION: v1-skill (2026-07-31a)
# skills/code-security-audit/scripts/readplan.ps1
#
# Computes the PER-PARTITION READ FLOOR for a Phase 3A/4A worker, and (in -Verify mode)
# reconciles that floor against what the worker's harness transcript shows it actually read.
#
# WHY THIS IS A SCRIPT: a field run produced too few real code findings, and nothing in this
# skill computed what a worker SHOULD read or checked what it DID read. A worker can open 30 of
# 200 partition files, write a confident summary, and every existing check still passes --
# merge-findings.ps1 verifies that findings MERGED, not that source was READ. The owner spotted
# it by eye and had to intervene manually. The sibling threat-model skill hit the same wall and
# solved it in scripts/readset.ps1; this is that mechanism moved to a partitioned, parallel
# workflow.
#
# TWO THINGS ARE DIFFERENT HERE, AND BOTH MAKE IT EASIER:
#  1. The denominator already exists. readset.ps1 had to derive a read set from the whole
#     manifest because its Phase 0 has one agent over the whole repo. Here partition-plan.ps1
#     has already written audit_state/partitions/<id>.txt -- the worker's exact scope. This
#     script only decides which slice of a KNOWN list is mandatory.
#  2. The record does not have to be self-reported. A worker runs as a subagent, and the harness
#     -- not the agent -- writes every Read tool call to a per-subagent transcript. -Verify reads
#     that. A worker cannot pad it by writing prose, because it does not write it.
#
# THE FLOOR IS SIZED TO BE MEETABLE, DELIBERATELY. Twice in the field a mandatory read-set floor
# (464 files, then 289) was impossible to satisfy, and the run either fabricated compliance or
# overrode its own gate. A gate that must be overridden is not a gate. Three mechanics prevent
# that, none of which is "quietly lower the bar":
#   (a) role classes carry the floor, and ordinary application source enters it only where a
#       DANGEROUS-API pattern actually matched -- the floor tracks the partition's real defect
#       surface, not its file count;
#   (b) any floor class above -BulkClassThreshold is signal-filtered as readset.ps1 does, with
#       every deferred file named and given a mechanical reason so nothing is silently dropped;
#   (c) if the floor STILL exceeds -FloorPerWorker, this does not print a bigger number and
#       demand it. It reports SPLIT REQUIRED. Excess demand becomes a PARTITIONING decision at
#       GATE 1, not a compliance number at the end of the run.
#
# Classes are matched by ROLE via path/filename, deliberately framework-agnostic, and the match
# errs toward INCLUSION: a file wrongly included costs one read, a file wrongly excluded costs a
# missed vulnerability.
param(
  [Parameter(Mandatory=$true)][string]$Workspace,
  [Parameter(Mandatory=$true)][string]$ProjectName,
  [string]$PartitionId,
  [switch]$Verify,
  # What ONE worker can read AND still have budget left to reason and write findings.
  # Also the partitioning target -- see SPLIT REQUIRED.
  [int]$FloorPerWorker = 60,
  [int]$BulkClassThreshold = 40,
  [string]$TranscriptRoot = (Join-Path $env:USERPROFILE '.claude\projects')
)

$ErrorActionPreference = 'Stop'
$WORKSPACE = $Workspace.TrimEnd('\')
if (-not (Test-Path -LiteralPath $WORKSPACE)) { Write-Error "Workspace path does not exist: $WORKSPACE"; exit 1 }
$WORKSPACE = (Resolve-Path -LiteralPath $WORKSPACE).Path.TrimEnd('\')

$outDir  = Join-Path $WORKSPACE 'audit_state'
$partDir = Join-Path $outDir 'partitions'
if (-not (Test-Path -LiteralPath $partDir)) {
  Write-Error "No partition lists at $partDir -- run partition-plan.ps1 BEFORE computing read floors."
  exit 1
}

# ASCII, LF, no NUL: Set-Content -Encoding ASCII emits CRLF, and these lists are diffed
# alongside the partition lists.
function Write-AsciiLines([string]$Path, [string[]]$Lines) {
  $text = ''
  if ($Lines.Count -gt 0) { $text = ($Lines -join "`n") + "`n" }
  [System.IO.File]::WriteAllText($Path, $text, [System.Text.Encoding]::ASCII)
}

# --- SHARED CLASSIFICATION -------------------------------------------------
# Dot-sourced so partition-plan.ps1 and this script cannot drift apart: partitions are SIZED by
# the same definition of auditable source that the read floor is VERIFIED against.
. (Join-Path $PSScriptRoot 'lib-classify.ps1')
$floorClasses = $script:FloorClasses
$allClasses   = $script:AllClasses

$partFiles = @(Get-ChildItem -LiteralPath $partDir -Filter '*.txt' -File |
  Where-Object { $_.BaseName -notmatch '\.readset(-deferred)?$' } | Sort-Object Name)
if ($PartitionId) {
  $partFiles = @($partFiles | Where-Object { $_.BaseName -eq $PartitionId })
  if ($partFiles.Count -eq 0) { Write-Error "No partition list for '$PartitionId' at $partDir\$PartitionId.txt"; exit 1 }
}
if ($partFiles.Count -eq 0) { Write-Error "No partition lists found under $partDir."; exit 1 }
if ($Verify -and -not $PartitionId) { Write-Error "-Verify needs -PartitionId: coverage is verified one worker at a time."; exit 1 }

# Thin adapter over lib-classify's Test-Sink, which is dot-sourced above.
#
# This was a full COPY of that function until a field run showed why that is dangerous: the copy
# read $sinkRe directly, so a fix to the shared sink logic silently did not apply here -- in the
# one script whose whole job is deciding what must be read. partition-plan.ps1 already shares the
# classifier for exactly this reason ("a partition sized here is verified against the same rule
# later"); the sink test has to share it too or the two drift apart without any test failing.
function Test-Sink([string]$rel) {
  return (Test-SinkShared -Workspace $WORKSPACE -RelPath $rel)
}

# ===========================================================================
# PLAN MODE
# ===========================================================================
if (-not $Verify) {
  $splitNeeded = @()
  foreach ($pf in $partFiles) {
    $pname = $pf.BaseName
    $files = @(Get-Content -LiteralPath $pf.FullName | Where-Object { $_ -ne '' })

    $set = @(foreach ($rel in $files) {
      $c = Get-AuditClass $rel
      if ($c) { [pscustomobject]@{ Class = $c; Path = $rel } }
    })

    $deferred = New-Object System.Collections.Generic.List[object]
    $floor    = New-Object System.Collections.Generic.List[object]
    foreach ($item in $set) {
      if ($floorClasses -notcontains $item.Class) { continue }
      if ($item.Class -eq 'app-source') {
        if (Test-Sink $item.Path) { $floor.Add($item) }
        else { $deferred.Add([pscustomobject]@{ Class = $item.Class; Path = $item.Path; Reason = 'no-dangerous-api-pattern' }) }
      } else {
        $floor.Add($item)
      }
    }

    # Signal-filter high-cardinality ROLE classes (readset.ps1's mechanic). Small classes are
    # never filtered -- a config file matters whether or not it holds a dangerous call.
    foreach ($c in @('authz','entry-route','data-access','ext-call','config-iac')) {
      $inClass = @($floor | Where-Object { $_.Class -eq $c })
      if ($inClass.Count -le $BulkClassThreshold) { continue }
      foreach ($item in $inClass) {
        if (-not (Test-Sink $item.Path)) {
          $deferred.Add([pscustomobject]@{ Class = $item.Class; Path = $item.Path; Reason = "bulk-class-over-$BulkClassThreshold-no-signal" })
          $null = $floor.Remove($item)
        }
      }
    }

    $floorList    = @($floor    | Sort-Object Class, Path)
    $deferredList = @($deferred | Sort-Object Class, Path)

    $floorPath    = Join-Path $partDir "$pname.readset.txt"
    $deferredPath = Join-Path $partDir "$pname.readset-deferred.txt"
    Write-AsciiLines $floorPath    @($floorList    | ForEach-Object { "$($_.Class)`t$($_.Path)" })
    Write-AsciiLines $deferredPath @($deferredList | ForEach-Object { "$($_.Class)`t$($_.Path)`t$($_.Reason)" })
    if ($floorList.Count -gt 0 -and (Get-Item -LiteralPath $floorPath).Length -eq 0) {
      Write-Error "Read floor $floorPath wrote zero bytes"; exit 1
    }

    "=== PARTITION '$pname' ==="
    "  {0,-14} {1,8} {2,9} {3,10}" -f 'class', 'in part', 'IN FLOOR', 'deferred'
    foreach ($c in $allClasses) {
      $tot = @($set          | Where-Object { $_.Class -eq $c }).Count
      if ($tot -eq 0) { continue }
      $flo = @($floorList    | Where-Object { $_.Class -eq $c }).Count
      $def = @($deferredList | Where-Object { $_.Class -eq $c }).Count
      "  {0,-14} {1,8} {2,9} {3,10}" -f $c, $tot, $flo, $def
    }
    "  {0,-14} {1,8} {2,9} {3,10}" -f 'TOTAL', $files.Count, $floorList.Count, $deferredList.Count
    "  Partition files: $($files.Count) | classified: $($set.Count) | non-code/asset: $($files.Count - $set.Count)"
    "  READ FLOOR: $($floorList.Count) files -> $floorPath"

    if ($floorList.Count -eq 0) {
      Write-Warning "Partition '$pname' has a read floor of ZERO -- it contains no auditable source. Dispatching a worker to it spends a worker on nothing. Raise this at GATE 1."
    }
    if ($floorList.Count -gt $FloorPerWorker) {
      $needed = [math]::Ceiling($floorList.Count / [double]$FloorPerWorker)
      $splitNeeded += "$pname (floor $($floorList.Count), needs $needed workers)"
      Write-Warning "SPLIT REQUIRED: partition '$pname' has a floor of $($floorList.Count) files against a per-worker capacity of $FloorPerWorker. Do NOT hand this to one worker and do NOT lower the floor -- split it into $needed partitions at GATE 1. An unmeetable floor is the failure this script exists to prevent."
    }
    ""
  }

  "NEXT: brief each worker with its floor file (audit_state/partitions/<id>.readset.txt) and tell"
  "      it every file listed is read IN FULL. After the worker returns, the ORCHESTRATOR runs"
  "      this script with -Verify -PartitionId <id>. The worker does not verify itself."
  if ($splitNeeded.Count -gt 0) { "SPLIT REQUIRED before dispatch: $($splitNeeded -join '; ')" }
  exit 0
}

# ===========================================================================
# VERIFY MODE -- run by the ORCHESTRATOR, not the worker
#
# The record of what a worker read is the HARNESS TRANSCRIPT, not anything the worker wrote.
# Claude Code writes one JSONL per subagent under
#   <TranscriptRoot>\<encoded-cwd>\<session-id>\subagents\agent-<id>.jsonl
# and every Read appears as {"name":"Read","input":{"file_path":"..."}}. The worker does not
# author that file and cannot append to it, which makes it the most tamper-resistant coverage
# signal available. files_read.txt is still read, but only as a CROSS-CHECK: a path claimed
# there and absent from the transcript is a fabricated read, worth knowing on its own.
# ===========================================================================
$pname = $PartitionId
$floorPath = Join-Path $partDir "$pname.readset.txt"
if (-not (Test-Path -LiteralPath $floorPath)) {
  Write-Error "No read floor at $floorPath -- run this script WITHOUT -Verify first."
  exit 1
}
$floorRows = @(Get-Content -LiteralPath $floorPath | Where-Object { $_ -ne '' } | ForEach-Object {
  $parts = $_ -split "`t", 2
  [pscustomobject]@{ Class = $parts[0]; Path = $parts[1] }
})

$wsKey = $WORKSPACE.Replace('\','/').ToLower().TrimEnd('/') + '/'
$observed = @{}
$agentFiles = @()

# Attribution is by BRIEFING CONTENT: the orchestrator's briefing names the workspace and the
# worker's partition list, so the first line of the transcript identifies the partition without
# depending on how the harness encodes directory names.
if (Test-Path -LiteralPath $TranscriptRoot) {
  $candidates = @(Get-ChildItem -LiteralPath $TranscriptRoot -Recurse -Filter 'agent-*.jsonl' -File -ErrorAction SilentlyContinue |
    Where-Object { $_.DirectoryName -match '\\subagents$' })
  foreach ($cf in $candidates) {
    $head = ''
    try { $head = (Get-Content -LiteralPath $cf.FullName -TotalCount 1) } catch { continue }
    if (-not $head) { continue }
    $headKey = $head.Replace('\\','\').Replace('\','/').ToLower()
    if ($headKey -notmatch [regex]::Escape($WORKSPACE.Replace('\','/').ToLower())) { continue }
    if ($headKey -notmatch [regex]::Escape("partitions/$($pname.ToLower())")) { continue }
    $agentFiles += $cf
  }
}

foreach ($af in $agentFiles) {
  $hits = @(Select-String -LiteralPath $af.FullName -Pattern '"name":"Read","input":(\{[^}]*\})' -AllMatches -ErrorAction SilentlyContinue)
  foreach ($h in $hits) {
    foreach ($m in $h.Matches) {
      $inputJson = $m.Groups[1].Value
      $fm = [regex]::Match($inputJson, '"file_path":"([^"]*)"')
      if (-not $fm.Success) { continue }
      $fp = $fm.Groups[1].Value.Replace('\\','\').Replace('\','/').ToLower()
      if (-not $fp.StartsWith($wsKey)) { continue }
      $rel = $fp.Substring($wsKey.Length)
      # A Read carrying "limit" saw part of the file. Recorded and reported, never gated on --
      # failing a run for a partial read of a 4000-line file recreates an unmeetable demand.
      $isFull = ($inputJson -notmatch '"limit"\s*:')
      if ($observed.ContainsKey($rel)) { if ($isFull) { $observed[$rel] = $true } }
      else { $observed[$rel] = $isFull }
    }
  }
}

$claimPath = Join-Path $outDir "workers\$pname\files_read.txt"
$claimed = @()
if (Test-Path -LiteralPath $claimPath) {
  $claimed = @(Get-Content -LiteralPath $claimPath | Where-Object { $_ -ne '' } | ForEach-Object { $_.Trim().Replace('\','/').ToLower() })
}

"READ-FLOOR RECONCILIATION for partition '$pname' (tool-computed):"
"  Transcripts matched: $($agentFiles.Count)"

# DEGRADE, DO NOT BLOCK. If the harness stores transcripts where this script cannot see them,
# the run must not fail every partition for lack of a log the WORKER never controlled. A
# verification that blocks on its own plumbing gets switched off, and a switched-off check is
# the 464-file floor all over again.
$corroborated = ($agentFiles.Count -gt 0)
if (-not $corroborated) {
  Write-Warning "No harness transcript found for partition '$pname' under $TranscriptRoot. Falling back to the worker's own files_read.txt. Coverage below is SELF-REPORTED and UNCORROBORATED: the worker wrote the record it is being judged against. Report it to the user as provisional."
  if ($claimed.Count -eq 0) {
    Write-Error "No transcript AND no audit_state/workers/$pname/files_read.txt. There is no record of what this worker read, from any source. Re-dispatch it; do not accept its summary as the record."
    exit 1
  }
  foreach ($c in $claimed) { $observed[$c] = $false }
}
"  Distinct workspace files observed read: $($observed.Keys.Count)  (source: $(if ($corroborated) { 'harness transcript' } else { 'SELF-REPORTED files_read.txt' }))"

$totalUnread = 0
$totalPartial = 0
foreach ($c in @($floorRows | ForEach-Object { $_.Class } | Sort-Object -Unique)) {
  $files   = @($floorRows | Where-Object { $_.Class -eq $c } | ForEach-Object { $_.Path })
  $unread  = @($files | Where-Object { -not $observed.ContainsKey($_.ToLower()) })
  $partial = @($files | Where-Object { $observed.ContainsKey($_.ToLower()) -and -not $observed[$_.ToLower()] })
  $totalUnread  += $unread.Count
  $totalPartial += $partial.Count
  "  {0,-14} floor {1,5} | read {2,5} | unread {3,5} | partial-only {4,4}  {5}" -f $c, $files.Count, ($files.Count - $unread.Count), $unread.Count, $partial.Count, $(if ($unread.Count -eq 0) { 'OK' } else { 'UNREAD' })
  if ($unread.Count -gt 0) { $unread | Select-Object -First 25 | ForEach-Object { "        UNREAD: $_" } }
}

# Claimed-but-not-observed is an INTEGRITY number, not a coverage one.
$fabricated = @()
if ($claimed.Count -gt 0 -and $agentFiles.Count -gt 0) {
  $fabricated = @($claimed | Where-Object { -not $observed.ContainsKey($_) })
}

$suffix = if ($corroborated) { '' } else { ' (SELF-REPORTED -- no transcript found)' }
"  TOTAL UNREAD IN FLOOR: $totalUnread of $($floorRows.Count)"
"  Read only in part (offset/limit, never in full): $totalPartial"
if ($claimed.Count -gt 0) {
  "  Worker's files_read.txt: $($claimed.Count) entries | claimed but ABSENT from the transcript: $($fabricated.Count)"
  if ($fabricated.Count -gt 0) {
    $fabricated | Select-Object -First 10 | ForEach-Object { "        CLAIMED-NOT-OBSERVED: $_" }
    Write-Warning "$($fabricated.Count) path(s) appear in the worker's own read log but in no Read call in its transcript. That is a fabricated read record, not a coverage gap. Raise it at GATE 2 regardless of the verdict."
  }
}
"  [readplan.ps1 $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss') | floor $($floorRows.Count) | transcripts $($agentFiles.Count) | observed $($observed.Keys.Count)]"

if ($totalUnread -gt 0) {
  "VERDICT: SHORT$suffix -- $totalUnread of $($floorRows.Count) floor files unread in partition '$pname'."
  "  RE-DISPATCH the worker with exactly the UNREAD paths above in its briefing. That is a bounded"
  "  worklist, not an instruction to read more. If a SECOND pass is still short, record the residual"
  "  in the registry and at GATE 2 -- a visible, counted gap beats a met number nobody can trust."
  exit 1
}
"VERDICT: COMPLETE$suffix -- all $($floorRows.Count) floor files for partition '$pname' appear in the read record."
exit 0
