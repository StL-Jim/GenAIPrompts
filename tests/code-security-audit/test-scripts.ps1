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
  # THREE categories now, not two. Slices hold only auditable files, so a doc or test file sitting
  # beside real source inside an audited root belongs to no slice -- it is not lost, it is simply
  # not something a worker would review. Counting only two categories lost 2 files on this
  # 17-file fixture, which is exactly the arithmetic this check exists to catch.
  $assigned = @($partFiles | ForEach-Object { Get-Content -LiteralPath $_.FullName })
  $nonAudit = 0
  if ($plan -match '(?m)^Files in non-auditable roots:\s+(\d+)') { $nonAudit = [int]$Matches[1] }
  $inRoot = 0
  if ($plan -match '(?m)^Non-auditable files inside audited roots:\s+(\d+)') { $inRoot = [int]$Matches[1] }
  Check "[$mode] sliced + non-auditable == manifest" (($assigned.Count + $nonAudit + $inRoot) -eq $manifest.Count) "sliced $($assigned.Count) + nonaudit-roots $nonAudit + nonaudit-in-root $inRoot vs manifest $($manifest.Count)"
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
    'id: F-003','ruling: unresolved','route: owner','reason: is that endpoint still live?','',
    'id: F-004','ruling: reject','grounds: not-security','reason: no attacker gain','',
    'id: F-005','ruling: unresolved','route: developer','reason: grepped 18 callers, dispatch via registry. QUESTION: reachable unauthenticated?','',
    'id: F-006','ruling: unresolved','reason: no route given','',
    # uphold-corrected: the defect is real but the finder stated something wrong about it. Its
    # absence caused a real failure -- a judge with only uphold/reject substituted an invented
    # justification into an uphold and nobody checked it. The hyphen also matters: a \w+ capture
    # would read this as plain 'uphold' and the correction would never be reported.
    'id: F-007','ruling: uphold-corrected','corrected: [Precondition: filesystem access]','reason: finder said web-reachable; checked and it is not. Defect real, precondition corrected.','')
  Set-Content -LiteralPath (Join-Path $state 'gate2_progress.md') -Encoding ASCII -Value @(
    '| F-001 | keep | real | judge:uphold | t |',
    '| F-002 | not real | agreed | judge:reject | t |',
    '| F-003 | keep | still live | judge:unresolved | t |',
    '| F-004 | keep | this one IS real | judge:reject | t |',
    # 'unsure' is the CORRECT owner response to a developer-routed question -- it is not his to
    # answer. An abstain check placed ahead of the route check made exactly these items vanish
    # from the count, which an end-to-end run caught and this row now guards.
    '| F-005 | unsure | developer question, not mine | judge:unresolved | t |',
    '| F-006 | unsure | no idea | judge:unresolved | t |',
    '| F-007 | accepted | real, choosing not to act | judge:uphold-corrected | t |')
  $r = Invoke-Script 'score-judge.ps1' @('-Workspace', $fx, '-ProjectName', $proj)
  Check "[$mode] score-judge exits 0" ($r.Code -eq 0) "exit $($r.Code)"
  Check "[$mode] scorecard names the dangerous error" ($r.Output -match 'JUDGE REJECTED, OWNER KEPT\s*:\s*1')
  Check "[$mode] scorecard names the permissive error" ($r.Output -match 'JUDGE UPHELD, OWNER DROPPED\s*:\s*0')
  Check "[$mode] scorecard says keep reviewing after a dangerous error" ($r.Output -match 'Keep reviewing every')
  Check "[$mode] route:owner counted separately" ($r.Output -match 'UNRESOLVED \(route: owner\): 1')
  # A developer-routed question is not the owner's to answer, so scoring his call against it would
  # penalise the judge for correctly declining to send it to him.
  Check "[$mode] route:developer not scored against the owner" ($r.Output -match 'UNRESOLVED \(route: developer\): 1')
  # An unresolved ruling with no route reaches nobody -- neither the owner nor a developer.
  Check "[$mode] unresolved with no route is flagged" ($r.Output -match 'carry no route')
  # uphold-corrected must parse whole (the hyphen) and be reported separately, so a finding the
  # judge silently rewrote is visible rather than looking like a plain uphold.
  Check "[$mode] uphold-corrected reported separately" ($r.Output -match 'UPHELD WITH A CORRECTION: 1')
  # 'accepted' means the finding is CORRECT and the owner chose not to act. Scoring it as an
  # abstention would withhold credit for a call the judge got right -- found on the first real run.
  Check "[$mode] accepted counts as agreement, not abstention" ($r.Output -match "both kept\s*:\s*2")

  # Fails closed when the owner's decisions are absent -- there is nothing to score against.
  Remove-Item -LiteralPath (Join-Path $state 'gate2_progress.md') -Force
  $r = Invoke-Script 'score-judge.ps1' @('-Workspace', $fx, '-ProjectName', $proj)
  Check "[$mode] score-judge fails closed with no owner decisions" ($r.Code -ne 0) "exit $($r.Code)"

  # ------------------------------------------------ verify-deliverables ---
  # phase-5.md requires every registry finding to appear in the consolidated report, and the
  # carved text documents why: an agent exhausts its output budget mid-report and silently
  # degrades findings into bullet points. The report still LOOKS finished. Only counting catches
  # it, and until this script nothing counted.
  # Self-contained registry rather than depending on where the merge runs in this file -- an
  # ordering dependency between tests is a test that breaks for reasons unrelated to its subject.
  Set-Content -LiteralPath (Join-Path $state 'findings_registry.md') -Encoding ASCII -Value @(
    'id: F-901','sev: Critical','status: open','',
    'id: F-902','sev: High','status: open','',
    'id: F-903','sev: High','status: false_positive','sup: owner says decommissioned','')
  $regIds = @('F-901','F-902','F-903')
  Set-Content -LiteralPath (Join-Path $state '05_consolidated_report.html') -Encoding ASCII -Value (@('<html><body>') + ($regIds | ForEach-Object { "$_ full detail" }) + @('</body></html>'))
  Set-Content -LiteralPath (Join-Path $state 'executive_briefing.html') -Encoding ASCII -Value @('<html><body>', "Critical findings: $($regIds[0]).", '</body></html>')
  $r = Invoke-Script 'verify-deliverables.ps1' @('-Workspace', $fx, '-ProjectName', $proj)
  Check "[$mode] verify-deliverables passes on a complete report" ($r.Code -eq 0) "exit $($r.Code)"

  # Truncated report: the exact budget-exhaustion shape.
  Set-Content -LiteralPath (Join-Path $state '05_consolidated_report.html') -Encoding ASCII -Value @('<html><body>', "$($regIds[0]) full detail", '... and more findings', '</body></html>')
  $r = Invoke-Script 'verify-deliverables.ps1' @('-Workspace', $fx, '-ProjectName', $proj)
  Check "[$mode] FAIL-CLOSED on a truncated report" ($r.Code -ne 0) "exit $($r.Code)"
  Check "[$mode] truncation names the missing findings" ($r.Output -match 'MISSING: F-')

  # No deliverables at all must never read as a pass -- absence is not completeness.
  Remove-Item -LiteralPath (Join-Path $state '05_consolidated_report.html') -Force
  Remove-Item -LiteralPath (Join-Path $state 'executive_briefing.html') -Force
  $r = Invoke-Script 'verify-deliverables.ps1' @('-Workspace', $fx, '-ProjectName', $proj)
  Check "[$mode] absent deliverables do not count as verified" (($r.Code -ne 0) -and ($r.Output -match 'not a pass'))

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

  # 4b. findings written under the WRONG FILENAME. A real orchestrator run produced this: a
  #     worker wrote findings.csv, merge read only findings.md, and five findings -- three of
  #     them Critical, about unauthenticated access to real personal data -- were dropped while
  #     the merge exited 0. The unparseable guard could not catch it: a MISSING file has zero
  #     bytes and zero schema fields, so it slipped past every condition.
  Rename-Item -LiteralPath $ff -NewName 'findings.csv'
  $r = Invoke-Script 'merge-findings.ps1' @('-Workspace', $fx, '-ProjectName', $proj)
  Check "[$mode] FAIL-CLOSED when findings.md is missing entirely" (($r.Code -ne 0) -and ($r.Output -match 'NO findings.md')) "exit $($r.Code)"
  Check "[$mode] names the stray file so the cause is obvious" ($r.Output -match 'findings\.csv')
  Rename-Item -LiteralPath (Join-Path (Split-Path $ff) 'findings.csv') -NewName 'findings.md'

  # 5. back to green, so the failures above were the injected faults and not something sticky
  $r = Invoke-Script 'merge-findings.ps1' @('-Workspace', $fx, '-ProjectName', $proj)
  Check "[$mode] recovers to green after faults removed" ($r.Code -eq 0) "exit $($r.Code)"
}

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
# SKILL.md legitimately names RUN ARTEFACTS as well as reference files -- things the audit
# produces under audit_state/ rather than instructions it reads. They are not expected in
# references/ and flagging them is a false positive, which is worse than no check: it trains
# whoever sees it to ignore this test.
$runArtefacts = @(
  'findings.md','findings_registry.md','attack_paths.md','evidence_index.md','excluded_candidates.md',
  'partition_plan.md','partition_status.md','coordination_mode.md','gate2_progress.md',
  'judge_rulings.md','critic_review.md','security_review.md','architecture_review.md',
  'shared_components.md','assumptions.md','threat_audit_comparison.md',
  'security_architecture_audit.md','STATE.md','CHANGELOG.md'
)
$refNames = @($refNames | Sort-Object -Unique | Where-Object { $runArtefacts -notcontains $_ })
$missingRefs = @($refNames | Where-Object { -not (Test-Path (Join-Path $SkillDir "references\$_")) })
Check 'every reference file named in SKILL.md exists' ($missingRefs.Count -eq 0) ($missingRefs -join ', ')

# ------------------------------------------- file-type-aware sink patterns ---
#
# Regression cover for a defect measured on a real 1,479-file application: the default sink
# pattern contains `\bSELECT\b.{0,80}\bFROM\b`, which matches EVERY .sql file, because SQL is
# what a .sql file contains. It put 378 of 380 stored procedures into the mandatory read floor
# and made the repository impossible to audit -- a floor of 567 against a capacity of 60.
#
# These assert the DISCRIMINATION, not just that a pattern exists: an ordinary procedure must be
# deferred and a dynamic one floored. A test that only checked "some .sql files are excluded"
# would pass against a rule that dropped all of them, which is the opposite failure.
. (Join-Path $scripts 'lib-classify.ps1')

$sinkTmp = Join-Path ([System.IO.Path]::GetTempPath()) ("sinktest-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $sinkTmp | Out-Null
try {
  $cases = @(
    @{ F = 'plain.sql';    C = "CREATE PROC dbo.G AS BEGIN`n SELECT Id, Name FROM dbo.Thing WHERE Id=@Id;`nEND"; Sink = $false; Why = 'ordinary stored procedure -- SELECT/FROM is the language, not a signal' }
    @{ F = 'dynamic.sql';  C = "DECLARE @sql NVARCHAR(MAX); EXEC sp_executesql @sql;";  Sink = $true;  Why = 'sp_executesql builds SQL as a string' }
    @{ F = 'shell.sql';    C = "EXEC xp_cmdshell 'dir';";                               Sink = $true;  Why = 'xp_cmdshell reaches outside the database' }
    # GRANT discrimination. Measured on a real application: a bare GRANT floored 187 of 189 .sql
    # files, because shipping a procedure with its EXECUTE grant is how the database is wired.
    # These four assert the line holds in BOTH directions -- a rule that floored none of them
    # would be as wrong as one that floored all four.
    @{ F = 'grant-routine.sql'; C = "CREATE PROC dbo.P AS SELECT 1;`nGO`nGRANT EXECUTE ON dbo.P TO AppRole;"; Sink = $false; Why = 'routine EXECUTE grant to a named application role is deployment, not defect' }
    @{ F = 'grant-public.sql';  C = "GRANT EXECUTE ON SCHEMA::dbo TO public;";          Sink = $true;  Why = 'grant to a broad principal' }
    @{ F = 'grant-control.sql'; C = "GRANT CONTROL ON DATABASE::App TO AppRole;";       Sink = $true;  Why = 'sweeping permission regardless of principal' }
    @{ F = 'impersonate.sql';   C = "CREATE PROC dbo.P WITH EXECUTE AS LOGIN = 'sa' AS SELECT 1;"; Sink = $true; Why = 'impersonates a named privileged principal' }
    @{ F = 'safe.cshtml';  C = "<h1>@Model.Title</h1>";                                 Sink = $false; Why = 'Razor escapes @Model by default' }
    @{ F = 'raw.cshtml';   C = "<div>@Html.Raw(Model.Body)</div>";                      Sink = $true;  Why = 'Html.Raw writes unescaped output' }
    # The default pattern must still apply to general-purpose languages: raw SQL inside C# IS
    # the signal there, and narrowing .sql must not narrow .cs with it.
    @{ F = 'repo.cs';      C = 'var q = "SELECT * FROM Users WHERE n=" + name;';        Sink = $true;  Why = 'hand-built SQL in application code' }
    @{ F = 'quiet.cs';     C = 'public int Add(int a, int b) { return a + b; }';        Sink = $false; Why = 'no dangerous API' }
  )
  foreach ($c in $cases) {
    Set-Content -LiteralPath (Join-Path $sinkTmp $c.F) -Value $c.C -Encoding UTF8
    $got = Test-SinkShared -Workspace $sinkTmp -RelPath $c.F
    $verb = if ($c.Sink) { 'IS a sink' } else { 'is NOT a sink' }
    Check "sink: $($c.F) $verb" ($got -eq $c.Sink) $c.Why
  }
} finally { Remove-Item -Recurse -Force -LiteralPath $sinkTmp -ErrorAction SilentlyContinue }

# readplan.ps1 must not carry its own copy of the sink test. It did, and the copy read $sinkRe
# directly -- so a fix to the shared rule would silently not apply in the one script whose whole
# job is deciding what gets read.
$readplanSrc = Get-Content -LiteralPath (Join-Path $scripts 'readplan.ps1') -Raw
Check 'readplan.ps1 delegates the sink test to lib-classify' `
  ($readplanSrc -match 'Test-SinkShared' -and $readplanSrc -notmatch 'Select-String[^\n]*\$sinkRe') `
  'a private copy of the sink test drifts from the shared one without any test failing'

# ------------------------------------------- read floor is a SIZE, not a count ---
#
# A floor is a claim about what fits in one worker's context window. A file count cannot make
# that claim: 60 config fragments and 60 service classes differ by an order of magnitude, and
# the original 60-file cap was chosen with no size basis at all. The failure it allows is the
# quiet kind -- the worker does not refuse an over-large floor, it reads until the window fills
# and then reasons over whatever happened to fit.
#
# This asserts the BYTE limit can bind INDEPENDENTLY of the file limit, which is the whole point:
# the fixture is two files, far under any file cap, and must still split.
$kbTmp = Join-Path ([System.IO.Path]::GetTempPath()) ("kbtest-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path (Join-Path $kbTmp 'src') | Out-Null
try {
  $blob = ('    var q = "SELECT * FROM Users WHERE n=" + name;' + [Environment]::NewLine) * 60
  1..2 | ForEach-Object {
    Set-Content -LiteralPath (Join-Path $kbTmp "src\Svc$_.cs") -Value "public class Svc$_ {`r`n$blob`r`n}" -Encoding UTF8
  }
  $null = Invoke-Script 'init-workspace.ps1' @('-Workspace', $kbTmp, '-ProjectName', 'kbtest', '-Mode', 'STANDALONE')
  $null = Invoke-Script 'manifest.ps1'       @('-Workspace', $kbTmp, '-ProjectName', 'kbtest')
  $null = Invoke-Script 'partition-plan.ps1' @('-Workspace', $kbTmp, '-ProjectName', 'kbtest')

  # Generous file cap, tiny byte budget: only the size rule can produce a split here.
  $tight = Invoke-Script 'readplan.ps1' @('-Workspace', $kbTmp, '-ProjectName', 'kbtest', '-FloorPerWorker', '60', '-FloorKBPerWorker', '1')
  Check 'read floor reports size alongside file count' ($tight.Output -match 'READ FLOOR:\s*\d+ files,\s*\d+ KB') 'a floor stated only in files cannot be checked against a context window'
  Check 'over-budget partition reports PARTIAL COVERAGE, driven by bytes' `
    ($tight.Output -match 'PARTIAL COVERAGE' -and $tight.Output -match "budget is 1 KB") `
    'two files is far under any file cap -- if size does not bind here, it is not binding at all'

  # It must REPORT the shortfall, never refuse. Refusing is what blocked a 5,377 KB partition
  # that no split or worker cap could ever have satisfied, and it kept the audit from running
  # at all while three rounds of pattern tuning chased a number that could not come down enough.
  Check 'partial coverage does NOT block dispatch' ($tight.Code -eq 0) 'an audit that reads the highest-signal files and says so beats one that refuses to start'
  $defTight = (Get-ChildItem -Path (Join-Path $kbTmp 'audit_state\partitions') -Filter '*.readset-deferred.txt' -ErrorAction SilentlyContinue |
               ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
  Check 'every file past the budget is NAMED with its reason' ($defTight -match 'over-worker-budget') 'a silent gap and a recorded one are different products'

  # And the same floor must NOT report a shortfall when the budget is ample: a warning that
  # always fires carries no information.
  $loose = Invoke-Script 'readplan.ps1' @('-Workspace', $kbTmp, '-ProjectName', 'kbtest', '-FloorPerWorker', '60', '-FloorKBPerWorker', '5000')
  Check 'no coverage warning when both budgets are ample' ($loose.Output -notmatch 'PARTIAL COVERAGE') 'the size rule must discriminate, not fire unconditionally'
} finally { Remove-Item -Recurse -Force -LiteralPath $kbTmp -ErrorAction SilentlyContinue }

# ------------------------------ the audit must not audit itself ------------
#
# Raised by the owner: "are you checking any of the previous audit_state* or threat-model*
# directories?" The answer was only partly yes. audit_state was excluded at the TOP LEVEL only,
# and the threat model only when named exactly "<project>-threat-model" -- while the source
# prompt's own example path is `real-world-threat-model/`, which would not have matched on a
# project called cassidi-app.
#
# The consequence is not wasted work, it is FABRICATED FINDINGS: findings_registry.md is full of
# vulnerability descriptions with file:line citations, so a worker handed one will faithfully
# report every issue the previous run found, attributed to a file that is not application code.
$selfTmp = Join-Path ([System.IO.Path]::GetTempPath()) ("self-" + [guid]::NewGuid().ToString('N'))
try {
  foreach ($d in @('src','audit_state','src\audit_state','real-world-threat-model','cassidi-threat-model','threat-model')) {
    New-Item -ItemType Directory -Force -Path (Join-Path $selfTmp $d) | Out-Null
  }
  Set-Content -LiteralPath (Join-Path $selfTmp 'src\A.cs') -Value 'public class A { var q = "SELECT * FROM U WHERE n=" + n; }' -Encoding UTF8
  foreach ($f in @('audit_state\findings_registry.md','src\audit_state\findings_registry.md',
                   'real-world-threat-model\02-threats.md','cassidi-threat-model\02-threats.md','threat-model\02-threats.md')) {
    Set-Content -LiteralPath (Join-Path $selfTmp $f) -Value 'id: F-001 sev: Critical' -Encoding UTF8
  }
  $null = Invoke-Script 'init-workspace.ps1' @('-Workspace', $selfTmp, '-ProjectName', 'selftest', '-Mode', 'STANDALONE')
  $null = Invoke-Script 'manifest.ps1'       @('-Workspace', $selfTmp, '-ProjectName', 'selftest')
  $mf = Get-Content -LiteralPath (Join-Path $selfTmp 'audit_state\00-file-manifest.txt') -Raw

  Check 'manifest keeps real application source'        ($mf -match 'src/A\.cs') 'the pruning must not be so broad it drops the code under audit'
  Check 'manifest excludes NESTED audit_state'          ($mf -notmatch 'src/audit_state') 'a prior audit nested in the tree was being read as source'
  Check 'manifest excludes a differently-named threat model' ($mf -notmatch 'real-world-threat-model') 'the prompt''s own example path would not have matched the project-name rule'
  Check 'manifest excludes a bare threat-model dir'     ($mf -notmatch '(^|/)threat-model/') 'name convention varies; the role does not'
} finally { Remove-Item -Recurse -Force -LiteralPath $selfTmp -ErrorAction SilentlyContinue }

# ------------------- oversized partitions split by functional area ---------
#
# A service root used to be atomic: roots merged into fewer workers, but one root was never
# divided. A real application handed a single worker 351 auditable files and 5,377 KB -- about
# seven context windows -- and the owner asked the obvious question: "Is it not possible to take
# 351 source files and split those to subagents?" It is. Nothing prevented it except this script
# never trying.
#
# The split must be by DIRECTORY, not by file order: a worker holding src/Areas/API reasons about
# a coherent surface, one holding every seventh file does not. These assert that, plus the
# reconciliation -- a split that loses or duplicates a file is worse than no split.
$splitTmp = Join-Path ([System.IO.Path]::GetTempPath()) ("split-" + [guid]::NewGuid().ToString('N'))
try {
  $pad = ('    // filler' + [Environment]::NewLine) * 700     # ~10 KB per file
  foreach ($sub in @('Areas\API','Areas\Public','Auth','Services')) {
    New-Item -ItemType Directory -Force -Path (Join-Path $splitTmp "src\$sub") | Out-Null
    1..20 | ForEach-Object {
      Set-Content -LiteralPath (Join-Path $splitTmp "src\$sub\C$_.cs") -Value "public class C$_ { var q = `"SELECT * FROM U WHERE n=`" + n;`r`n$pad }" -Encoding UTF8
    }
  }
  $null = Invoke-Script 'init-workspace.ps1' @('-Workspace', $splitTmp, '-ProjectName', 'splittest', '-Mode', 'STANDALONE')
  $null = Invoke-Script 'manifest.ps1'       @('-Workspace', $splitTmp, '-ProjectName', 'splittest')
  $pp = Invoke-Script 'partition-plan.ps1'   @('-Workspace', $splitTmp, '-ProjectName', 'splittest', '-SliceKB', '120')

  $ids = @(Get-ChildItem -Path (Join-Path $splitTmp 'audit_state\partitions') -Filter '*.txt' |
           Where-Object { $_.Name -notlike '*readset*' } | ForEach-Object { $_.BaseName })

  Check 'a large root becomes several slices' ($ids.Count -gt 1) "one root, 800 KB, produced $($ids.Count) slice(s) -- a single subagent cannot hold it"
  Check 'slices are named after the functional area they hold' `
    (@($ids | Where-Object { $_ -match 'areas|auth|services' }).Count -ge 3) `
    "ids were: $($ids -join ', ') -- a name that does not say what the subagent covers is unjudgeable at GATE 1"
  Check 'slicing preserves the reconciliation' ($pp.Output -match 'Reconciliation: OK') 'a slicing scheme that loses or duplicates a file is worse than none at all'
  Check 'the plan states bucket, slices and waves' `
    ($pp.Output -match 'BUCKET:' -and $pp.Output -match 'SLICES:' -and $pp.Output -match 'WAVES :') `
    'the owner decides at GATE 1 how far down the queue to go -- he cannot without those three numbers'

  # And every slice must actually fit, or the slicing achieved nothing.
  $rp = Invoke-Script 'readplan.ps1' @('-Workspace', $splitTmp, '-ProjectName', 'splittest', '-FloorKBPerWorker', '120')
  Check 'every slice fits inside one subagent budget' ($rp.Output -notmatch 'PARTIAL COVERAGE') 'if the pieces still overflow, the slicing solved nothing'
} finally { Remove-Item -Recurse -Force -LiteralPath $splitTmp -ErrorAction SilentlyContinue }

# ------------------------------------------ version stamps agree ----------
#
# The owner asked "are you updating the version, you've made so many changes" and the answer was
# no. Stamps had drifted across five different dates while the architecture was rewritten under
# them, and SKILL.md -- the one printed at session start -- was among the stale ones. So the run
# would announce a version that was not the version running.
#
# That matters specifically here: he pulls this onto an air-gapped work machine and the printed
# stamp is his ONLY way to tell whether the fix he is testing is actually present. A stamp that
# lies is worse than no stamp, because it converts "did my pull work?" from a checkable question
# into a false answer. His notes already record a day lost to exactly this failure on the sibling
# threat-model prompt.
#
# Asserting they are IDENTICAL rather than merely present is the point: forgetting to bump is the
# normal failure, and it is invisible without this check.
$stamped = @{}
foreach ($f in @(Get-ChildItem -LiteralPath $SkillDir -Recurse -File)) {
  $txt = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue
  if ($txt -match 'SKILL VERSION: (v\d+-skill \(\d{4}-\d{2}-\d{2}[a-z]\))') {
    $stamped[$f.FullName.Substring($SkillDir.Length + 1)] = $Matches[1]
  }
}
$distinct = @($stamped.Values | Sort-Object -Unique)
Check 'every skill file carries a SKILL VERSION stamp' ($stamped.Count -ge 10) "only $($stamped.Count) file(s) stamped"
Check 'all SKILL VERSION stamps are identical' ($distinct.Count -eq 1) "found $($distinct.Count): $($distinct -join ', ')"

# SKILL.md's stamp is the one printed at session start, so it is the one the owner reads.
$skillMd = Get-Content -LiteralPath (Join-Path $SkillDir 'SKILL.md') -Raw
$skillStamp = if ($skillMd -match 'SKILL VERSION: (v\d+-skill \(\d{4}-\d{2}-\d{2}[a-z]\))') { $Matches[1] } else { $null }
Check 'SKILL.md carries the same stamp as everything else' ($skillStamp -and $distinct -contains $skillStamp) "SKILL.md says '$skillStamp'"

# --------------------------- feature slicing: down the stack, not across ---
#
# A field worker said it plainly: "I can't validate this finding because the file I need is not in
# my partition." Directories are LAYERS -- OrderController in Areas/API, OrderService in Services,
# OrderRepository in Repositories -- so grouping by directory guarantees no worker ever sees a
# whole path from untrusted input to dangerous sink. Ordering by directory cannot fix that; it is
# what causes it.
#
# The fixture is deliberately layered so a directory-based grouping FAILS it: each feature's files
# are in four different directories. If these pass, one worker can follow the whole path.
$featTmp = Join-Path ([System.IO.Path]::GetTempPath()) ("feat-" + [guid]::NewGuid().ToString('N'))
try {
  foreach ($d in @('src\Areas\API\Controllers','src\Services','src\Repositories','src\Models')) {
    New-Item -ItemType Directory -Force -Path (Join-Path $featTmp $d) | Out-Null
  }
  foreach ($feat in @('Order','Customer','Invoice')) {
    Set-Content -LiteralPath (Join-Path $featTmp "src\Areas\API\Controllers\${feat}Controller.cs") -Value "public class ${feat}Controller { [Authorize] public void Search(string q) { } }" -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $featTmp "src\Repositories\${feat}Repository.cs")          -Value "public class ${feat}Repository { var q = `"SELECT * FROM T WHERE n=`" + n; }" -Encoding UTF8
    # Deliberately holds NO dangerous API: it must still be pulled in, because the middle of the
    # path is where you see whether the parameter was validated before reaching the sink.
    Set-Content -LiteralPath (Join-Path $featTmp "src\Services\${feat}Service.cs")                 -Value "public class ${feat}Service { public void Find(string q) { _repo.Search(q); } }" -Encoding UTF8
  }
  $null = Invoke-Script 'init-workspace.ps1' @('-Workspace', $featTmp, '-ProjectName', 'feattest', '-Mode', 'STANDALONE')
  $null = Invoke-Script 'manifest.ps1'       @('-Workspace', $featTmp, '-ProjectName', 'feattest')
  $fp   = Invoke-Script 'partition-plan.ps1' @('-Workspace', $featTmp, '-ProjectName', 'feattest')

  Check 'cross-layer features are reported as kept together' ($fp.Output -match 'CROSS-LAYER FEATURES KEPT TOGETHER') 'if features are not grouped, every vulnerability spanning layers is split in half'
  Check 'quiet connecting files are pulled in' ($fp.Output -match 'CONNECTING FILES PULLED IN') 'a service that only forwards a parameter has no dangerous API and would otherwise be dropped from its own feature'

  # The decisive check: controller, service and repository for ONE feature in ONE slice.
  $sliceFiles = @{}
  foreach ($pf in @(Get-ChildItem -Path (Join-Path $featTmp 'audit_state\partitions') -Filter '*.txt' | Where-Object { $_.Name -notlike '*readset*' })) {
    $sliceFiles[$pf.BaseName] = @(Get-Content -LiteralPath $pf.FullName)
  }
  $together = $false
  foreach ($k in $sliceFiles.Keys) {
    $f = $sliceFiles[$k]
    if (($f -match 'OrderController') -and ($f -match 'OrderRepository') -and ($f -match 'OrderService')) { $together = $true }
  }
  Check 'one slice holds a full vertical path (controller + service + repository)' $together `
    'this is the whole point -- without it a worker sees a sink and cannot tell if its input is attacker-controlled'
} finally { Remove-Item -Recurse -Force -LiteralPath $featTmp -ErrorAction SilentlyContinue }

# ------------- grouping follows REFERENCES, not filenames -------------------
#
# Filenames are only a PROXY for structure. They work when naming is disciplined
# (OrderController/OrderService/OrderRepository) and fail the moment it is not -- and the owner
# pushed on exactly that: "I still don't understand how 'smart' partitioning will work w/out
# getting to know the application first."
#
# So this fixture is built to DEFEAT name-based grouping: CheckoutController calls BasketService
# calls BasketRepository. No shared stem, three different directories. Only the code's own
# references can group them, which is the whole claim being tested.
$refTmp = Join-Path ([System.IO.Path]::GetTempPath()) ("ref-" + [guid]::NewGuid().ToString('N'))
try {
  foreach ($d in @('src\Areas\API\Controllers','src\Services','src\Repositories')) {
    New-Item -ItemType Directory -Force -Path (Join-Path $refTmp $d) | Out-Null
  }
  $pairs = @{ 'Checkout' = 'Basket'; 'Profile' = 'Account' }
  foreach ($ctrl in $pairs.Keys) {
    $svc = $pairs[$ctrl]
    Set-Content -LiteralPath (Join-Path $refTmp "src\Areas\API\Controllers\${ctrl}Controller.cs") -Value "public class ${ctrl}Controller { [Authorize] public void Go(string q) { new ${svc}Service().Find(q); } }" -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $refTmp "src\Services\${svc}Service.cs")                   -Value "public class ${svc}Service { public void Find(string q) { new ${svc}Repository().Search(q); } }" -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $refTmp "src\Repositories\${svc}Repository.cs")            -Value "public class ${svc}Repository { public void Search(string n) { var q = `"SELECT * FROM T WHERE n=`" + n; } }" -Encoding UTF8
  }
  $null = Invoke-Script 'init-workspace.ps1' @('-Workspace', $refTmp, '-ProjectName', 'reftest', '-Mode', 'STANDALONE')
  $null = Invoke-Script 'manifest.ps1'       @('-Workspace', $refTmp, '-ProjectName', 'reftest')
  $rp   = Invoke-Script 'partition-plan.ps1' @('-Workspace', $refTmp, '-ProjectName', 'reftest')

  Check 'a reference graph is built from the code' ($rp.Output -match 'REFERENCE GRAPH: \d+ declared types, [1-9]\d* file-to-file references') `
    'zero references means grouping fell back to filenames, which this fixture is built to defeat'

  # Decisive: the whole call path in one slice, with names that share nothing.
  $sl = @{}
  foreach ($pf in @(Get-ChildItem -Path (Join-Path $refTmp 'audit_state\partitions') -Filter '*.txt' | Where-Object { $_.Name -notlike '*readset*' })) {
    $sl[$pf.BaseName] = @(Get-Content -LiteralPath $pf.FullName)
  }
  $pathTogether = $false
  foreach ($k in $sl.Keys) {
    $f = $sl[$k]
    if (($f -match 'CheckoutController') -and ($f -match 'BasketService') -and ($f -match 'BasketRepository')) { $pathTogether = $true }
  }
  Check 'a call path with UNRELATED names lands in one slice' $pathTogether `
    'CheckoutController -> BasketService -> BasketRepository share no stem; if these are split, a worker sees the sink and cannot tell whether its input is attacker-controlled'
} finally { Remove-Item -Recurse -Force -LiteralPath $refTmp -ErrorAction SilentlyContinue }

# A sparse graph must not make things WORSE. Creating one slice per seed was the first cut, and on
# files with no detected references it produced one subagent per FILE -- 20 files, 20 slices.
$sparseTmp = Join-Path ([System.IO.Path]::GetTempPath()) ("sparse-" + [guid]::NewGuid().ToString('N'))
try {
  New-Item -ItemType Directory -Force -Path (Join-Path $sparseTmp 'src') | Out-Null
  1..12 | ForEach-Object {
    Set-Content -LiteralPath (Join-Path $sparseTmp "src\Iso$_.cs") -Value "public class Iso$_ { var q = `"SELECT * FROM T WHERE n=`" + n; }" -Encoding UTF8
  }
  $null = Invoke-Script 'init-workspace.ps1' @('-Workspace', $sparseTmp, '-ProjectName', 'sparsetest', '-Mode', 'STANDALONE')
  $null = Invoke-Script 'manifest.ps1'       @('-Workspace', $sparseTmp, '-ProjectName', 'sparsetest')
  $null = Invoke-Script 'partition-plan.ps1' @('-Workspace', $sparseTmp, '-ProjectName', 'sparsetest')
  $sparseSlices = @(Get-ChildItem -Path (Join-Path $sparseTmp 'audit_state\partitions') -Filter '*.txt' | Where-Object { $_.Name -notlike '*readset*' })
  Check 'unrelated files still pack into few slices' ($sparseSlices.Count -le 2) `
    "12 tiny unconnected files produced $($sparseSlices.Count) slice(s) -- the graph must improve grouping where it exists and never worsen it where it does not"
} finally { Remove-Item -Recurse -Force -LiteralPath $sparseTmp -ErrorAction SilentlyContinue }

# ------------------- GATE 2 decisions reach the registry -------------------
#
# Nothing applied the owner's decisions to findings_registry.md. His answers land in
# gate2_progress.md, but renumber-findings.ps1 and Phase 5 read `status:` from the REGISTRY -- so a
# rejection had to reach it or the report would not know it was suppressed. Faced with 24 findings
# and one manual approval per edit, the running agent wrote itself an apply_disposition.py:
# unreviewed code, in a language this skill does not use, mutating the file holding the results,
# invoking a `python3` that does not exist on his machine.
#
# keep and unsure must BOTH stay open. He is not a developer; asked to separate "definitely real"
# from "cannot tell", the honest answer is nearly always the second, and treating them differently
# writes a confidence signal into the record that he never gave.
$dispTmp = Join-Path ([System.IO.Path]::GetTempPath()) ("disp-" + [guid]::NewGuid().ToString('N'))
try {
  New-Item -ItemType Directory -Force -Path (Join-Path $dispTmp 'audit_state') | Out-Null
  $reg = @(
    '# Findings Registry','',
    '- id: F-001','- sev: Critical','- status: open','- file: src/A.cs','',
    '- id: F-002','- sev: High','- status: open','- file: src/B.cs','',
    '- id: F-003','- sev: High','- status: open','- file: src/C.cs',''
  )
  Set-Content -LiteralPath (Join-Path $dispTmp 'audit_state\findings_registry.md') -Value $reg -Encoding UTF8
  Set-Content -LiteralPath (Join-Path $dispTmp 'audit_state\gate2_progress.md') -Encoding UTF8 -Value @(
    '| F-001 | keep | real and reachable | judge:uphold | 2026-08-02T10:00 |',
    '| F-002 | not real | parameterised by the Db wrapper | judge:reject | 2026-08-02T10:01 |',
    '| F-003 | unsure | cannot judge this myself | judge:uphold | 2026-08-02T10:02 |'
  )

  # -WhatIf must change nothing.
  $before = Get-Content -LiteralPath (Join-Path $dispTmp 'audit_state\findings_registry.md') -Raw
  $null = Invoke-Script 'apply-dispositions.ps1' @('-Workspace', $dispTmp, '-ProjectName', 'disptest', '-WhatIf')
  $after = Get-Content -LiteralPath (Join-Path $dispTmp 'audit_state\findings_registry.md') -Raw
  Check 'apply-dispositions -WhatIf writes nothing' ($before -eq $after) 'a dry run that mutates the audit record is worse than none'

  $ad = Invoke-Script 'apply-dispositions.ps1' @('-Workspace', $dispTmp, '-ProjectName', 'disptest')
  Check 'apply-dispositions exits 0' ($ad.Code -eq 0) "exit $($ad.Code)"
  $now = Get-Content -LiteralPath (Join-Path $dispTmp 'audit_state\findings_registry.md') -Raw
  Check 'keep stays open'   ($now -match '(?s)id: F-001.*?status: open')           'a kept finding must remain live'
  Check 'unsure stays open' ($now -match '(?s)id: F-003.*?status: open')           'unsure is not a rejection -- it is a finding he could not judge'
  Check 'rejection becomes false_positive with its reason' `
    ($now -match '(?s)id: F-002.*?status: false_positive' -and $now -match 'sup:.*parameterised') `
    'the reason must travel with the finding, or the report cannot say why it was suppressed'

  # JUDGE REJECTIONS MUST LAND TOO -- the defect that produced a report of 24 open findings after
  # the owner had disposed of everything down to 12. The judge rejected 50 of 85; nothing carried
  # those rulings into the registry, so all 50 stayed `status: open` and Phase 5 read them as live.
  # And where BOTH ruled, the owner wins: he is the superior judge and may overturn any ruling.
  $jTmp = Join-Path ([System.IO.Path]::GetTempPath()) ("judge-" + [guid]::NewGuid().ToString('N'))
  try {
    New-Item -ItemType Directory -Force -Path (Join-Path $jTmp 'audit_state') | Out-Null
    Set-Content -LiteralPath (Join-Path $jTmp 'audit_state\findings_registry.md') -Encoding UTF8 -Value @(
      '# Findings Registry','',
      '- id: F-001','- sev: High','- status: open','',
      '- id: F-002','- sev: High','- status: open','',
      '- id: F-003','- sev: High','- status: open',''
    )
    # Owner overturns the judge on F-001, and says nothing about F-002 or F-003.
    Set-Content -LiteralPath (Join-Path $jTmp 'audit_state\gate2_progress.md') -Encoding UTF8 `
      -Value '| F-001 | keep | judge was wrong, I overturn this | judge:reject | t |'
    Set-Content -LiteralPath (Join-Path $jTmp 'audit_state\judge_rulings.md') -Encoding UTF8 -Value @(
      'id: F-001','ruling: reject','reason: no evidence cited','',
      'id: F-002','ruling: reject','reason: not a security issue','',
      'id: F-003','ruling: uphold','reason: stands',''
    )
    $jr = Invoke-Script 'apply-dispositions.ps1' @('-Workspace', $jTmp, '-ProjectName', 'judgetest')
    $jreg = Get-Content -LiteralPath (Join-Path $jTmp 'audit_state\findings_registry.md') -Raw
    Check 'judge rejections are applied to the registry' ($jreg -match '(?s)id: F-002.*?status: false_positive') `
      'a judge rejection left as open is read by Phase 5 as a live finding -- this is what produced a report of 24 when the owner had settled on 12'
    Check 'the judge reason travels with the suppression' ($jreg -match 'sup:.*judge:.*not a security issue') `
      'the suppressed table must say who rejected it and why'
    Check 'the OWNER overrides a judge rejection' ($jreg -match '(?s)id: F-001.*?status: open') `
      'he is the superior judge; his decision is applied second and wins'
    Check 'an upheld finding stays open' ($jreg -match '(?s)id: F-003.*?status: open') 'uphold is not a disposition to suppress'
    Check 'both sources are reported separately' ($jr.Output -match "from the owner at GATE 2\s*:\s*1" -and $jr.Output -match "from judge 'reject' rulings\s*:\s*1") `
      'the counts must be separable or the owner cannot tell what he decided from what the judge decided'
  } finally { Remove-Item -Recurse -Force -LiteralPath $jTmp -ErrorAction SilentlyContinue }

  # A decision for an id the registry does not hold must abort, not half-apply.
  Add-Content -LiteralPath (Join-Path $dispTmp 'audit_state\gate2_progress.md') -Value '| F-999 | keep | ghost | judge:uphold | 2026-08-02T10:03 |'
  $ghost = Invoke-Script 'apply-dispositions.ps1' @('-Workspace', $dispTmp, '-ProjectName', 'disptest')
  Check 'FAIL-CLOSED on a decision with no matching finding' ($ghost.Code -ne 0) 'a decision recorded and not applied is exactly the silent loss this replaces'
} finally { Remove-Item -Recurse -Force -LiteralPath $dispTmp -ErrorAction SilentlyContinue }

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
