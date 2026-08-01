# SKILL VERSION: v1-skill (2026-07-30a)
# tests/code-security-audit/test-scripts.ps1
#
# Regression suite for the code-security-audit skill's DETERMINISTIC scripts. Builds a
# fixture, runs init/manifest/partition/merge in BOTH coordination modes, and asserts
# behaviour: exclusions, the partition cap, reconciliation, mode-dependent STATE.md, and
# every fail-closed path in merge-findings.
#
#   pwsh -File tests/code-security-audit/test-scripts.ps1
#
# Exit 0 = all pass. Run after any script change.
#
# Both modes are exercised deliberately. STANDALONE is a first-class path and a change
# that only works in COORDINATED is an incomplete change; without this, STANDALONE rots
# silently because it is almost never the mode used in the field.
param(
  [string]$SkillDir,
  [string]$WorkRoot = (Join-Path $env:TEMP 'csa-tests')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# $PSScriptRoot is not reliably populated during param binding under `powershell.exe -File`,
# so resolve paths here rather than in the param block.
$here = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $SkillDir) {
  $repoRoot = (Resolve-Path (Join-Path $here '..\..')).Path
  $SkillDir = Join-Path $repoRoot 'skills\code-security-audit'
}
if (-not (Test-Path -LiteralPath $SkillDir)) { Write-Error "Skill directory not found: $SkillDir"; exit 1 }
$scripts = Join-Path $SkillDir 'scripts'
$pass = 0; $fail = 0
$failures = New-Object System.Collections.Generic.List[string]

function Check([string]$name, $cond, [string]$detail = '') {
  if ($cond) { $script:pass++; Write-Host "  PASS  $name" -ForegroundColor Green }
  else {
    $script:fail++
    $script:failures.Add("$name$(if ($detail) { " -- $detail" })")
    Write-Host "  FAIL  $name$(if ($detail) { " -- $detail" })" -ForegroundColor Red
  }
}

function Invoke-Script([string]$name, [string[]]$argList) {
  # Capture output AND exit code. Exit codes matter here: several scripts are required to
  # FAIL CLOSED, and a test that only checked output text would pass against a script that
  # printed an error and exited 0.
  #
  # EAP is relaxed for the call. In PowerShell 5.1, `2>&1` on a native executable wraps
  # each stderr line in an ErrorRecord, which THROWS under ErrorActionPreference='Stop'.
  # That fires exactly when a script fails closed -- i.e. on every test that is supposed
  # to provoke a failure -- so the suite would blow up instead of recording a pass.
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scripts $name) @argList 2>&1
    return [pscustomobject]@{ Output = ($out | Out-String); Code = $LASTEXITCODE }
  } finally { $ErrorActionPreference = $prev }
}

if (Test-Path -LiteralPath $WorkRoot) { Remove-Item -Recurse -Force -LiteralPath $WorkRoot }
New-Item -ItemType Directory -Force -Path $WorkRoot | Out-Null

foreach ($mode in @('STANDALONE','COORDINATED')) {

  Write-Host ""
  Write-Host "=== MODE: $mode ===" -ForegroundColor Cyan

  $fx = Join-Path $WorkRoot "fx-$($mode.ToLower())"
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here 'make-fixture.ps1') -Path $fx -Mode $mode -Force | Out-Null
  $proj  = Split-Path -Leaf $fx
  $state = Join-Path $fx 'audit_state'

  # ---------------------------------------------------------------- init ----
  $r = Invoke-Script 'init-workspace.ps1' @('-Workspace', $fx, '-ProjectName', $proj, '-Mode', $mode, '-ExecutorModel', 'test-model')
  Check "[$mode] init-workspace exits 0" ($r.Code -eq 0) "exit $($r.Code)"
  Check "[$mode] audit_state created" (Test-Path (Join-Path $state 'STATE.md'))
  Check "[$mode] workers/ created" (Test-Path (Join-Path $state 'workers'))

  # The cross-run log must survive untouched -- clobbering it destroys every prior run.
  $log = Join-Path $fx 'security_architecture_audit.md'
  Check "[$mode] cross-run log NOT clobbered" ((Get-Content -LiteralPath $log -Raw) -match 'CROSS-RUN LOG SENTINEL')

  # Prior run detected by presence, never read.
  Check "[$mode] prior audit run detected" ($r.Output -match 'audit_state-20260101')
  Check "[$mode] prior run contents NOT read" ($r.Output -notmatch 'MUST NOT BE READ')

  # Phase 6 must be not_applicable in STANDALONE so resume never waits on it.
  $stateTxt = Get-Content -LiteralPath (Join-Path $state 'STATE.md') -Raw
  $want = if ($mode -eq 'STANDALONE') { 'not_applicable' } else { 'pending' }
  Check "[$mode] STATE.md Phase 6 = $want" ($stateTxt -match "Phase 6 \(Comparison HTML Render\): $want")
  Check "[$mode] STATE.md records MODE" ($stateTxt -match "MODE: $mode")

  # Re-running init must NOT overwrite an existing STATE.md (that would silently reset a resume).
  $r2 = Invoke-Script 'init-workspace.ps1' @('-Workspace', $fx, '-ProjectName', $proj, '-Mode', $mode)
  Check "[$mode] init is idempotent (STATE.md preserved)" ($r2.Output -match 'NOT overwritten')

  # ------------------------------------------------------------ manifest ----
  $r = Invoke-Script 'manifest.ps1' @('-Workspace', $fx, '-ProjectName', $proj)
  Check "[$mode] manifest exits 0" ($r.Code -eq 0) "exit $($r.Code)"
  $manifest = @(Get-Content -LiteralPath (Join-Path $state '00-file-manifest.txt'))
  Check "[$mode] manifest non-empty" ($manifest.Count -gt 0)
  Check "[$mode] excludes node_modules" (-not ($manifest -match 'node_modules'))
  Check "[$mode] excludes vendor" (-not ($manifest -match '(^|/)vendor/'))
  Check "[$mode] excludes audit_state*" (-not ($manifest -match '^audit_state'))
  Check "[$mode] excludes root cross-run log" (-not ($manifest -contains 'security_architecture_audit.md'))
  Check "[$mode] excludes .git" (-not ($manifest -match '^\.git/'))
  Check "[$mode] includes real source" ($manifest -contains 'services/auth/src/login.py')
  if ($mode -eq 'COORDINATED') {
    Check "[$mode] excludes threat-model dir" (-not ($manifest -match 'threat-model'))
  }

  # ----------------------------------------------------------- partition ----
  $r = Invoke-Script 'partition-plan.ps1' @('-Workspace', $fx, '-ProjectName', $proj)
  Check "[$mode] partition-plan exits 0" ($r.Code -eq 0) "exit $($r.Code)"
  $plan = Get-Content -LiteralPath (Join-Path $state 'partition_plan.md') -Raw
  Check "[$mode] reconciliation says yes" ($plan -match 'Match: yes')
  Check "[$mode] no files lost" ($plan -notmatch 'FILES LOST')

  # Exclude the readset sidecar files readplan.ps1 writes alongside the partition lists.
  $partFiles = @(Get-ChildItem -LiteralPath (Join-Path $state 'partitions') -Filter *.txt |
    Where-Object { $_.BaseName -notmatch '\.readset(-deferred)?$' })
  Check "[$mode] partition count within cap of 10" ($partFiles.Count -le 10) "got $($partFiles.Count)"
  Check "[$mode] at least one partition created" ($partFiles.Count -ge 1)

  # Partitions are now weighted by AUDITABLE SOURCE, so roots holding none get no worker
  # deliberately. Coverage is therefore assigned + non-auditable == manifest, and the plan must
  # SAY which roots got no worker -- a silently absent directory is indistinguishable from one
  # nobody thought to look at.
  $assigned = @($partFiles | ForEach-Object { Get-Content -LiteralPath $_.FullName })
  $nonAudit = 0
  if ($plan -match '(?m)^Files in non-auditable roots:\s+(\d+)') { $nonAudit = [int]$Matches[1] }
  Check "[$mode] assigned + non-auditable == manifest" (($assigned.Count + $nonAudit) -eq $manifest.Count) "assigned $($assigned.Count) + nonaudit $nonAudit vs manifest $($manifest.Count)"
  Check "[$mode] plan names the roots given no worker" ($plan -match 'Not assigned to any worker')
  $dupeAssign = @($assigned | Group-Object | Where-Object { $_.Count -gt 1 })
  Check "[$mode] no file in two partitions" ($dupeAssign.Count -eq 0)
  Check "[$mode] plan reports the auditable surface" ($plan -match 'Auditable surface')

  # ----------------------------------------------------------- score-judge ---
  # The scorecard is how the owner finds out whether the judge can shorten his review. What
  # matters is not the agreement rate but the DIRECTION of disagreement, so both directions are
  # planted deliberately: a rejection he overturned (dangerous) and an uphold he dropped
  # (permissive). A scorecard that reported only a percentage would hide the difference.
  Set-Content -LiteralPath (Join-Path $state 'judge_rulings.md') -Encoding ASCII -Value @(
    'id: F-001','ruling: uphold','reason: unchallenged','',
    'id: F-002','ruling: reject','grounds: precondition','reason: not reachable here','',
    'id: F-003','ruling: unresolved','reason: is that endpoint still live?','',
    'id: F-004','ruling: reject','grounds: not-security','reason: no attacker gain','')
  Set-Content -LiteralPath (Join-Path $state 'gate2_progress.md') -Encoding ASCII -Value @(
    '| F-001 | keep | real | judge:uphold | t |',
    '| F-002 | not real | agreed | judge:reject | t |',
    '| F-003 | keep | still live | judge:unresolved | t |',
    '| F-004 | keep | this one IS real | judge:reject | t |')
  $r = Invoke-Script 'score-judge.ps1' @('-Workspace', $fx, '-ProjectName', $proj)
  Check "[$mode] score-judge exits 0" ($r.Code -eq 0) "exit $($r.Code)"
  Check "[$mode] scorecard names the dangerous error" ($r.Output -match 'JUDGE REJECTED, OWNER KEPT\s*:\s*1')
  Check "[$mode] scorecard names the permissive error" ($r.Output -match 'JUDGE UPHELD, OWNER DROPPED\s*:\s*0')
  Check "[$mode] scorecard says keep reviewing after a dangerous error" ($r.Output -match 'Keep reviewing every')
  Check "[$mode] unresolved routed to owner is counted separately" ($r.Output -match 'UNRESOLVED \(routed to the owner\): 1')

  # Fails closed when the owner's decisions are absent -- there is nothing to score against.
  Remove-Item -LiteralPath (Join-Path $state 'gate2_progress.md') -Force
  $r = Invoke-Script 'score-judge.ps1' @('-Workspace', $fx, '-ProjectName', $proj)
  Check "[$mode] score-judge fails closed with no owner decisions" ($r.Code -ne 0) "exit $($r.Code)"

  # ------------------------------------------------------------- readplan ---
  $r = Invoke-Script 'readplan.ps1' @('-Workspace', $fx, '-ProjectName', $proj)
  Check "[$mode] readplan exits 0" ($r.Code -eq 0) "exit $($r.Code)"
  $readsets = @(Get-ChildItem -LiteralPath (Join-Path $state 'partitions') -Filter '*.readset.txt')
  Check "[$mode] a read floor per partition" ($readsets.Count -eq $partFiles.Count) "$($readsets.Count) floors vs $($partFiles.Count) partitions"
  # The floor must be a SUBSET of the partition it belongs to -- a floor naming a file outside
  # the worker's scope is a floor the worker cannot meet.
  $escapes = @()
  foreach ($rs in $readsets) {
    $owner = $rs.BaseName -replace '\.readset$',''
    $scope = @(Get-Content -LiteralPath (Join-Path $state "partitions\$owner.txt"))
    foreach ($line in (Get-Content -LiteralPath $rs.FullName | Where-Object { $_ -ne '' })) {
      $p = ($line -split "`t", 2)[1]
      if ($scope -notcontains $p) { $escapes += "$owner : $p" }
    }
  }
  Check "[$mode] every floor file is inside its own partition" ($escapes.Count -eq 0) ($escapes -join '; ')
  # Verify must fail closed when there is no record of what a worker read, from any source.
  $anyPart = $partFiles[0].BaseName
  $r = Invoke-Script 'readplan.ps1' @('-Workspace', $fx, '-ProjectName', $proj, '-Verify', '-PartitionId', $anyPart, '-TranscriptRoot', (Join-Path $WorkRoot 'no-such-transcripts'))
  Check "[$mode] readplan -Verify fails closed with no read record" ($r.Code -ne 0) "exit $($r.Code)"

  Check "[$mode] shared-component candidate flagged" ($plan -match '(?m)^- shared')
  $status = Get-Content -LiteralPath (Join-Path $state 'partition_status.md') -Raw
  Check "[$mode] partition_status seeded pending" ($status -match '\| pending \|')

  # ------------------------------------------------------- merge-findings ---
  # Fake worker output: disjoint ID blocks, as the orchestrator assigns.
  $ids = 1
  $partitionIds = @($partFiles | ForEach-Object { [IO.Path]::GetFileNameWithoutExtension($_.Name) })
  foreach ($pid_ in $partitionIds) {
    $wd = Join-Path $state "workers\$pid_"
    New-Item -ItemType Directory -Force -Path $wd | Out-Null
    $tm = if ($mode -eq 'COORDINATED') { 'confirms' } else { 'null' }
    Set-Content -LiteralPath (Join-Path $wd 'findings.md') -Encoding ASCII -Value @(
      "id: F-$('{0:D3}' -f $ids)"
      "pid: $pid_"
      "src: $pid_/src/x.py:10-20"
      'class: Confirmed'
      'sev: High'
      'conf: High'
      'score: 80'
      "threat_match: $tm"
      ''
    )
    Set-Content -LiteralPath (Join-Path $wd 'attack_paths.md')   -Encoding ASCII -Value @("id: AP-001", "findings: F-$('{0:D3}' -f $ids)")
    Set-Content -LiteralPath (Join-Path $wd 'evidence_index.md') -Encoding ASCII -Value @("$pid_/src/x.py:10-20")
    $ids += 20
  }
  $doneRows = @('# Partition Status', '', '| partition_id | files | status |', '|---|---|---|')
  $doneRows += ($partitionIds | ForEach-Object { "| $_ | 1 | done |" })
  Set-Content -LiteralPath (Join-Path $state 'partition_status.md') -Encoding ASCII -Value $doneRows

  # The excluded ledger. It is what makes the precondition test checkable instead of merely
  # trusted, so its absence must be visible: a filter whose rejections leave no trace turns a
  # wrongly-dropped finding into something indistinguishable from code nobody examined.
  Set-Content -LiteralPath (Join-Path $state "workers\$($partitionIds[0])\excluded_candidates.md") -Encoding ASCII -Value @(
    'a/b.py:1 | A02 | intercepted on private WAN | Precondition not reachable: attacker on the wire',
    'a/c.py:2 | A10 | DNS hijack | Precondition not reachable: org runs that resolver',
    'a/d.py:3 | A09 | missing audit log | Below severity floor')

  $r = Invoke-Script 'merge-findings.ps1' @('-Workspace', $fx, '-ProjectName', $proj)
  Check "[$mode] merge exits 0 on clean input" ($r.Code -eq 0) "exit $($r.Code)"
  Check "[$mode] excluded ledger merged" (Test-Path (Join-Path $state 'excluded_candidates.md'))
  Check "[$mode] exclusion profile reported by reason" ($r.Output -match 'Excluded candidates: 3' -and $r.Output -match 'Precondition not reachable: 2')
  Check "[$mode] findings_registry.md written" (Test-Path (Join-Path $state 'findings_registry.md'))
  Check "[$mode] global attack_paths.md written" (Test-Path (Join-Path $state 'attack_paths.md'))
  Check "[$mode] evidence_index.md written" (Test-Path (Join-Path $state 'evidence_index.md'))
  Check "[$mode] GATE 2 counts computed" ($r.Output -match 'Total findings: \d+')
  Check "[$mode] counts broken out by severity" ($r.Output -match 'By severity:')
  if ($mode -eq 'COORDINATED') {
    Check "[$mode] threat_match counts reported" ($r.Output -match 'By threat_match')
  }

  # --- fail-closed paths. A gate that cannot fail is not a gate. -------------
  $firstPart = $partitionIds[0]
  $ff = Join-Path $state "workers\$firstPart\findings.md"
  $backup = Get-Content -LiteralPath $ff -Raw

  # 1. duplicate finding ids. Injected by appending a second finding carrying an id already
  #    used, which works whether the plan produced one partition or ten -- source-weighted
  #    partitioning makes the count depend on the fixture's auditable surface.
  Add-Content -LiteralPath $ff -Encoding ASCII -Value @(
    '', 'id: F-001', "pid: $firstPart", 'src: dup/x.py:1-2', 'class: Confirmed', 'sev: High', '')
  $r = Invoke-Script 'merge-findings.ps1' @('-Workspace', $fx, '-ProjectName', $proj)
  Check "[$mode] FAIL-CLOSED on duplicate finding ids" ($r.Code -ne 0) "exit $($r.Code)"
  Set-Content -LiteralPath $ff -Encoding ASCII -NoNewline -Value $backup

  # 2. severity outside Critical/High
  Set-Content -LiteralPath $ff -Encoding ASCII -NoNewline -Value ($backup -replace 'sev: High', 'sev: Medium')
  $r = Invoke-Script 'merge-findings.ps1' @('-Workspace', $fx, '-ProjectName', $proj)
  Check "[$mode] FAIL-CLOSED on out-of-scope severity" ($r.Code -ne 0) "exit $($r.Code)"
  Set-Content -LiteralPath $ff -Encoding ASCII -NoNewline -Value $backup

  # 3. a partition that never finished
  Set-Content -LiteralPath (Join-Path $state 'partition_status.md') -Encoding ASCII -Value ($doneRows -replace '\| done \|', '| security_complete |')
  $r = Invoke-Script 'merge-findings.ps1' @('-Workspace', $fx, '-ProjectName', $proj)
  Check "[$mode] FAIL-CLOSED on unfinished partition" ($r.Code -ne 0) "exit $($r.Code)"
  Set-Content -LiteralPath (Join-Path $state 'partition_status.md') -Encoding ASCII -Value $doneRows

  # 4. findings present but in a shape the parser does not recognise. A real Haiku worker wrote
  #    the schema as a markdown bullet list; the merge matched nothing, printed
  #    "Total findings: 0" and exited 0 on a run that had found a leaked API key. Silent total
  #    loss reported as success. Both halves are asserted: the bullet form must now PARSE, and a
  #    genuinely unreadable file must FAIL rather than look like "found nothing".
  $bulletForm = ($backup -replace '(?m)^(\s*)(id|pid|src|class|sev|conf|score):', '$1- $2:')
  Set-Content -LiteralPath $ff -Encoding ASCII -NoNewline -Value $bulletForm
  $r = Invoke-Script 'merge-findings.ps1' @('-Workspace', $fx, '-ProjectName', $proj)
  Check "[$mode] markdown-bullet schema still parses" (($r.Code -eq 0) -and ($r.Output -notmatch 'Total findings: 0')) "exit $($r.Code)"
  Set-Content -LiteralPath $ff -Encoding ASCII -NoNewline -Value $backup

  Set-Content -LiteralPath $ff -Encoding ASCII -NoNewline -Value ($backup -replace '(?m)^(\s*[-*]?\s*)id:', '$1identifier:')
  $r = Invoke-Script 'merge-findings.ps1' @('-Workspace', $fx, '-ProjectName', $proj)
  Check "[$mode] FAIL-CLOSED on unparseable findings file" (($r.Code -ne 0) -and ($r.Output -match 'UNPARSEABLE')) "exit $($r.Code)"
  Set-Content -LiteralPath $ff -Encoding ASCII -NoNewline -Value $backup

  # 5. back to green, so the failures above were the injected faults and not something sticky
  $r = Invoke-Script 'merge-findings.ps1' @('-Workspace', $fx, '-ProjectName', $proj)
  Check "[$mode] recovers to green after faults removed" ($r.Code -eq 0) "exit $($r.Code)"
}

# ------------------------------------------------------------ carve check ---
Write-Host ""
Write-Host "=== CARVE ===" -ForegroundColor Cyan
$c = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here 'carve.ps1') 2>&1
Check 'carve verification passes' ($LASTEXITCODE -eq 0)
Check 'source coverage has no unaccounted lines' (($c | Out-String) -match 'UNACCOUNTED\s+0')

# ---------------------------------------------------------------- hygiene ---
Write-Host ""
Write-Host "=== HYGIENE ===" -ForegroundColor Cyan
# NUL bytes and non-ASCII are checked; line endings deliberately are NOT, because git's
# core.autocrlf legitimately rewrites them on checkout and asserting on them produces a
# suite that fails on a clean clone.
$bad = @()
foreach ($f in Get-ChildItem -Path $SkillDir -Recurse -File) {
  $b = [System.IO.File]::ReadAllBytes($f.FullName)
  if (@($b | Where-Object { $_ -eq 0 }).Count -gt 0)   { $bad += "$($f.Name): NUL byte" }
  if (@($b | Where-Object { $_ -gt 127 }).Count -gt 0) { $bad += "$($f.Name): non-ASCII" }
}
Check 'all skill files ASCII and NUL-free' ($bad.Count -eq 0) ($bad -join '; ')

$parseErrors = @()
foreach ($f in Get-ChildItem -Path $scripts -Filter *.ps1) {
  $errs = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$errs)
  if ($errs.Count -gt 0) { $parseErrors += "$($f.Name): $($errs.Count)" }
}
Check 'all scripts parse' ($parseErrors.Count -eq 0) ($parseErrors -join '; ')

# Every reference file SKILL.md names must exist -- a dangling pointer sends a subagent
# looking for methodology that is not there.
$skillLines = Get-Content -LiteralPath (Join-Path $SkillDir 'SKILL.md')
$refNames = New-Object System.Collections.Generic.List[string]
foreach ($line in $skillLines) {
  # Skip lines about the COMPANION threat-model tool: they legitimately name files that
  # belong to that workflow (02-threats.md, its STATE.md) and which must NOT exist here.
  if ($line -match 'threat-model') { continue }
  foreach ($m in [regex]::Matches($line, '`([a-z0-9][a-z0-9-]*\.md)`')) {
    $refNames.Add($m.Groups[1].Value)
  }
}
$refNames = @($refNames | Sort-Object -Unique)
$missingRefs = @($refNames | Where-Object { -not (Test-Path (Join-Path $SkillDir "references\$_")) })
Check 'every reference file named in SKILL.md exists' ($missingRefs.Count -eq 0) ($missingRefs -join ', ')

# ----------------------------------------------------------------- report ---
Write-Host ""
Write-Host "================================"
Write-Host "PASS: $pass   FAIL: $fail"
if ($fail -gt 0) {
  Write-Host "FAILURES:" -ForegroundColor Red
  $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
  exit 1
}
Write-Host "ALL TESTS PASSED" -ForegroundColor Green
exit 0
