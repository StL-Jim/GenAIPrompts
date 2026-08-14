# SKILL VERSION: v2-skill (2026-08-14a)
# skills/code-security-audit/scripts/apply-dispositions.ps1
#
# Applies the owner's GATE 2 decisions from gate2_progress.md to findings_registry.md.
#
# WHY THIS EXISTS: nothing did, and a field run showed what fills a gap like this. The owner's
# answers land in gate2_progress.md (durable, written first, by design) but renumber-findings.ps1
# and Phase 5 read `status:` from the REGISTRY -- so a rejection has to reach the registry or the
# report will not know it was suppressed. Faced with 24 findings and a manual approval per edit,
# the running agent wrote itself an apply_disposition.py: unreviewed code, in a language this
# skill does not use, mutating the file that holds the audit's results. It also invoked `python3`,
# which does not exist on the owner's machine.
#
# The instinct was right and the result was not. This is the sanctioned version: reviewed, tested,
# PowerShell, and it FAILS CLOSED rather than half-applying.
#
#   ...\apply-dispositions.ps1 -Workspace <path> -ProjectName <name> [-WhatIf]
#
# Exit 0 = every decision applied and verified. Exit 1 = nothing written.
param(
  [Parameter(Mandatory=$true)][string]$Workspace,
  [Parameter(Mandatory=$true)][string]$ProjectName,
  # Report what would change and write nothing. Run this first.
  [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$WORKSPACE = $Workspace.TrimEnd('\')
if (-not (Test-Path -LiteralPath $WORKSPACE)) { Write-Error "Workspace path does not exist: $WORKSPACE"; exit 1 }
$WORKSPACE = (Resolve-Path -LiteralPath $WORKSPACE).Path.TrimEnd('\')
$outDir = Join-Path $WORKSPACE 'audit_state'

$regPath  = Join-Path $outDir 'findings_registry.md'
$progPath = Join-Path $outDir 'gate2_progress.md'
foreach ($p in @($regPath, $progPath)) {
  if (-not (Test-Path -LiteralPath $p)) { Write-Error "Not found: $p"; exit 1 }
}

# ---------------------------------------------------------------------------
# THE OWNER'S DECISIONS
#
# Row format is fixed by gate-2.md and read identically by score-judge.ps1:
#   | F-012 | not real | reporting service decommissioned | judge:uphold | 2026-07-31T14:22 |
# ---------------------------------------------------------------------------
$calls = @{}
$reasons = @{}
$source = @{}
foreach ($line in (Get-Content -LiteralPath $progPath)) {
  $m = [regex]::Match($line, '^\s*\|\s*(F-\d+)\s*\|\s*([^|]+?)\s*\|\s*([^|]*?)\s*\|')
  if (-not $m.Success) { continue }
  $calls[$m.Groups[1].Value]   = $m.Groups[2].Value.Trim().ToLower()
  $reasons[$m.Groups[1].Value] = $m.Groups[3].Value.Trim()
  $source[$m.Groups[1].Value]  = 'owner'
}
if ($calls.Count -eq 0) {
  Write-Error "Parsed no decisions from gate2_progress.md. Check its row format against references/gate-2.md."
  exit 1
}

# ---------------------------------------------------------------------------
# THE JUDGE'S REJECTIONS COUNT TOO
#
# This script originally applied ONLY the owner's GATE 2 answers, and a real run showed what that
# leaves behind. The judge rejected 50 of 85 findings; nothing carried those rulings into the
# registry, so all 50 stayed `status: open`. Phase 5 reads status, so the reports presented them
# as live findings -- the owner disposed of 24 findings and received a report describing dozens.
#
# The judge's ruling is a disposition exactly like his, and it has to land the same way. The
# OWNER WINS wherever both spoke: he is the superior judge and may overturn any ruling, so his
# decision is applied second and overwrites.
$rulPath = Join-Path $outDir 'judge_rulings.md'
$fromJudge = 0
if (Test-Path -LiteralPath $rulPath) {
  $rulText = (Get-Content -LiteralPath $rulPath -Raw) -replace "`r`n", "`n"
  foreach ($m in [regex]::Matches($rulText, '(?m)^\s*[-*]?\s*id:\s*(F-\d+)\s*$')) {
    $id = $m.Groups[1].Value
    $end = $rulText.IndexOf("`n`n", $m.Index); if ($end -lt 0) { $end = $rulText.Length }
    $block = $rulText.Substring($m.Index, $end - $m.Index)
    # [\w-] not \w: 'uphold-corrected' would otherwise capture as 'uphold'.
    $r = [regex]::Match($block, '(?m)^\s*[-*]?\s*ruling:\s*([\w-]+)')
    if (-not $r.Success) { continue }
    if ($r.Groups[1].Value.ToLower() -ne 'reject') { continue }   # uphold/uphold-corrected/unresolved stay open
    if ($calls.ContainsKey($id)) { continue }                      # the owner already spoke; he wins
    $why = [regex]::Match($block, '(?m)^\s*[-*]?\s*reason:\s*(.+)$')
    $calls[$id]   = 'not real'
    $reasons[$id] = if ($why.Success) { 'judge: ' + $why.Groups[1].Value.Trim() } else { 'judge: rejected' }
    $source[$id]  = 'judge'
    $fromJudge++
  }
}

# ---------------------------------------------------------------------------
# VOCABULARY -> status
#
# 'keep' and 'unsure' BOTH stay open, and that is deliberate rather than an oversight. The owner
# is not a developer; asked to distinguish "this is definitely real" from "I cannot tell", the
# honest answer is nearly always the second. Treating them differently would write a confidence
# signal into the record that he never intended to give. Both are live findings a developer must
# look at, and the report shows them in one table.
#
# 'unsure' is NOT scored against the judge either -- see score-judge.ps1, same reasoning.
function Get-Status([string]$call) {
  switch -Regex ($call) {
    '^keep'            { return 'open' }
    '^unsure'          { return 'open' }
    '^accept'          { return 'accepted' }
    '^not[ -]?real'    { return 'false_positive' }
    '^not[ -]?sec'     { return 'false_positive' }
    '^dup'             { return 'false_positive' }
    '^reject'          { return 'false_positive' }
    '^false'           { return 'false_positive' }
    default            { return $null }
  }
}

$unknown = @()
foreach ($id in $calls.Keys) { if (-not (Get-Status $calls[$id])) { $unknown += "$id ($($calls[$id]))" } }
if ($unknown.Count -gt 0) {
  Write-Error "UNRECOGNISED DECISION(S): $($unknown -join '; '). Refusing to apply any of them -- a decision this script cannot read is one the report would silently get wrong. Fix the wording in gate2_progress.md, or extend this script deliberately."
  exit 1
}

# ---------------------------------------------------------------------------
# APPLY -- per finding block, status line only
#
# Never rewrite finding TEXT. The registry holds the evidence a developer will act on, and a
# script that reformats it can quietly damage what it was meant to preserve. Only `status:`
# changes, and `sup:` is appended for a suppression so the reason travels with the finding.
# ---------------------------------------------------------------------------
$text = (Get-Content -LiteralPath $regPath -Raw) -replace "`r`n", "`n"
$lines = @($text -split "`n")

$curId = $null
$applied = @{}
$out = New-Object System.Collections.Generic.List[string]
foreach ($line in $lines) {
  $idm = [regex]::Match($line, '^\s*[-*]?\s*id:\s*(F-\d+)\s*$')
  if ($idm.Success) { $curId = $idm.Groups[1].Value }

  $sm = [regex]::Match($line, '^(\s*[-*]?\s*)status:\s*(\S+)\s*$')
  if ($sm.Success -and $curId -and $calls.ContainsKey($curId)) {
    $want = Get-Status $calls[$curId]
    $out.Add("$($sm.Groups[1].Value)status: $want")
    $applied[$curId] = $want
    if ($want -ne 'open' -and $reasons[$curId]) {
      $out.Add("$($sm.Groups[1].Value)sup: $($calls[$curId]) -- $($reasons[$curId])")
    }
    continue
  }
  $out.Add($line)
}

# ---------------------------------------------------------------------------
# RECONCILE BEFORE WRITING
#
# A decision recorded at the gate and not applied here is the exact failure this replaces: the
# owner answered, the report shipped as though he had not, and nothing said so.
# ---------------------------------------------------------------------------
$missed = @($calls.Keys | Where-Object { -not $applied.ContainsKey($_) } | Sort-Object)
$ownerCount = @($source.Values | Where-Object { $_ -eq 'owner' }).Count
"DISPOSITIONS -- $ProjectName"
"  from the owner at GATE 2       : $ownerCount"
"  from judge 'reject' rulings    : $fromJudge"
"  total decisions                : $($calls.Count)"
"  applied to findings_registry.md: $($applied.Count)"
foreach ($s in @('open','accepted','false_positive')) {
  $n = @($applied.Values | Where-Object { $_ -eq $s }).Count
  if ($n -gt 0) { "    {0,-16} {1}" -f $s, $n }
}
if ($missed.Count -gt 0) {
  ""
  Write-Error "NOT APPLIED: $($missed -join ', '). These ids have a decision but no matching finding block in the registry -- either the id is wrong in gate2_progress.md or the registry was regenerated after triage. NOTHING has been written. Re-run merge-findings.ps1 only if you are ready to re-apply every decision."
  exit 1
}

if ($WhatIf) {
  ""
  "-WhatIf: nothing written. Re-run without it to apply."
  exit 0
}

# Backup first. This file is the audit's result and a bad write is not recoverable from anything.
$backup = "$regPath.pre-disposition"
Copy-Item -LiteralPath $regPath -Destination $backup -Force
($out -join "`r`n") | Set-Content -LiteralPath $regPath -Encoding ASCII

# Verify what landed, by re-reading rather than trusting the write.
$check = (Get-Content -LiteralPath $regPath -Raw)
$badly = @()
foreach ($id in $applied.Keys) {
  $blockStart = $check.IndexOf("id: $id")
  if ($blockStart -lt 0) { $badly += $id; continue }
  $blockEnd = $check.IndexOf("`n`n", $blockStart); if ($blockEnd -lt 0) { $blockEnd = $check.Length }
  if ($check.Substring($blockStart, $blockEnd - $blockStart) -notmatch "status:\s*$($applied[$id])") { $badly += $id }
}
if ($badly.Count -gt 0) {
  Copy-Item -LiteralPath $backup -Destination $regPath -Force
  Write-Error "VERIFICATION FAILED for: $($badly -join ', '). Registry RESTORED from $backup. Do not proceed to Phase 5."
  exit 1
}

""
"Written: $regPath  (backup: $(Split-Path -Leaf $backup))"
"Verified: every decision present in the registry with the status it was given."
"NEXT: renumber-findings.ps1, then Phase 5."
exit 0
