# SKILL VERSION: v2-skill (2026-08-14a)
# skills/code-security-audit/scripts/verify-deliverables.ps1
#
# Checks that Phase 5's deliverables actually contain every finding the registry holds.
#
# WHY THIS EXISTS: the carved methodology states plainly that the consolidated report MUST
# include every finding from findings_registry.md, and that selecting which to include is
# filtering and is wrong. It also documents the failure that rule exists to prevent: an agent
# reads a registry of N findings, writes planning prose, exhausts its per-response output budget
# mid-report, and produces a summarised findings list instead of a complete one. Findings that
# were detailed in the registry become bullet points or vanish.
#
# That narrowing is a BUDGET ARTIFACT, not a decision, and nothing in the output reveals it
# happened. The report looks finished. It reads as complete. Only counting catches it.
#
# Until now nothing counted. This audit has already produced two silent-loss defects of exactly
# this shape -- a worker writing findings.csv, and a merge reporting "Total findings: 0" and
# exiting 0 -- both caught only because someone happened to look. The pattern is that any
# hand-off where content can quietly shrink needs an arithmetic check across it.
#
#   ...\verify-deliverables.ps1 -Workspace <path> -ProjectName <name>
#
# Exit 0 = every finding accounted for in every deliverable that should carry it.
# Exit 1 = a deliverable is short. Do NOT ship it; re-dispatch that Phase 5 subagent.
param(
  [Parameter(Mandatory=$true)][string]$Workspace,
  [Parameter(Mandatory=$true)][string]$ProjectName
)

$ErrorActionPreference = 'Stop'
$WORKSPACE = $Workspace.TrimEnd('\')
if (-not (Test-Path -LiteralPath $WORKSPACE)) { Write-Error "Workspace path does not exist: $WORKSPACE"; exit 1 }
$WORKSPACE = (Resolve-Path -LiteralPath $WORKSPACE).Path.TrimEnd('\')
$outDir = Join-Path $WORKSPACE 'audit_state'

$registryPath = Join-Path $outDir 'findings_registry.md'
if (-not (Test-Path -LiteralPath $registryPath)) {
  Write-Error "No findings_registry.md at $registryPath. Nothing to verify against."
  exit 1
}

# ---------------------------------------------------------------------------
# THE DENOMINATOR
#
# Every finding in the registry, and which of them GATE 2 suppressed. Suppressed findings are
# NOT exempt: phase-5.md requires them to appear compactly with their rationale, precisely so
# that what was set aside -- and on whose word -- stays visible. Dropping them entirely is the
# same failure wearing a justification.
# ---------------------------------------------------------------------------
$regText = (Get-Content -LiteralPath $registryPath -Raw) -replace "`r`n", "`n"
$allIds = @([regex]::Matches($regText, '(?m)^\s*[-*]?\s*id:\s*(F-\d+)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
if ($allIds.Count -eq 0) {
  Write-Error "Parsed no finding ids from findings_registry.md. Either the merge produced nothing or the format is not what this script expects."
  exit 1
}

$suppressed = @()
foreach ($m in [regex]::Matches($regText, '(?m)^\s*[-*]?\s*id:\s*(F-\d+)')) {
  $id = $m.Groups[1].Value
  $blockEnd = $regText.IndexOf("`n`n", $m.Index)
  if ($blockEnd -lt 0) { $blockEnd = $regText.Length }
  $block = $regText.Substring($m.Index, $blockEnd - $m.Index)
  if ($block -match '(?m)^\s*[-*]?\s*status:\s*(false_positive|accepted)\s*$') { $suppressed += $id }
}
$suppressed = @($suppressed | Sort-Object -Unique)
$open = @($allIds | Where-Object { $suppressed -notcontains $_ })

# ---------------------------------------------------------------------------
# WHAT EACH DELIVERABLE MUST CARRY
#
# The consolidated report is COMPREHENSIVE -- every finding, open and suppressed.
# The executive briefing is deliberately SELECTIVE (Critical findings plus attack-path-relevant
# Highs), so it is checked for presence and non-emptiness only, never for completeness. Checking
# it against the full set would fail a document that is working as designed.
# ---------------------------------------------------------------------------
$checks = @(
  @{ File = '05_consolidated_report.html'; Must = $allIds; Label = 'consolidated report'; Complete = $true }
  @{ File = 'threat_audit_comparison.md';  Must = @();     Label = 'comparison intermediate'; Complete = $false; CoordinatedOnly = $true }
  @{ File = 'executive_briefing.html';     Must = @();     Label = 'executive briefing'; Complete = $false }
)

$mode = 'STANDALONE'
$cmPath = Join-Path $outDir 'coordination_mode.md'
if (Test-Path -LiteralPath $cmPath) {
  if ((Get-Content -LiteralPath $cmPath -Raw) -match '(?m)^\s*MODE:\s*(\w+)') { $mode = $Matches[1].ToUpper() }
}

"DELIVERABLE COMPLETENESS -- $ProjectName"
"  Registry: $($allIds.Count) findings ($($open.Count) open, $($suppressed.Count) suppressed at GATE 2)"
"  Mode    : $mode"
""

$failures = @()
$anyChecked = $false

foreach ($c in $checks) {
  $path = Join-Path $outDir $c.File
  if ($c.ContainsKey('CoordinatedOnly') -and $c.CoordinatedOnly -and $mode -ne 'COORDINATED') { continue }

  if (-not (Test-Path -LiteralPath $path)) {
    "  {0,-28} ABSENT -- not produced" -f $c.File
    continue
  }
  $anyChecked = $true
  $text = Get-Content -LiteralPath $path -Raw
  $bytes = (Get-Item -LiteralPath $path).Length

  if (-not $c.Complete) {
    # Selective by design -- the briefing carries Critical findings plus attack-path-relevant
    # Highs, so checking it for completeness would fail a document working exactly as specified.
    #
    # What CAN be asserted is semantic rather than dimensional: if the registry holds Critical
    # findings, a briefing that names none of them has either lost them or is not a briefing. A
    # byte threshold was tried first and rejected -- it fails honest short documents and passes
    # long empty ones, which is the wrong error in both directions.
    $found = @([regex]::Matches($text, 'F-\d+') | ForEach-Object { $_.Value } | Sort-Object -Unique)
    "  {0,-28} {1,7} bytes | {2} finding id(s) referenced | selective by design, not completeness-checked" -f $c.File, $bytes, $found.Count

    $criticals = @()
    foreach ($m in [regex]::Matches($regText, '(?m)^\s*[-*]?\s*id:\s*(F-\d+)')) {
      $cid = $m.Groups[1].Value
      $bEnd = $regText.IndexOf("`n`n", $m.Index); if ($bEnd -lt 0) { $bEnd = $regText.Length }
      if ($regText.Substring($m.Index, $bEnd - $m.Index) -match '(?m)^\s*[-*]?\s*sev:\s*Critical\s*$') { $criticals += $cid }
    }
    $criticals = @($criticals | Where-Object { $suppressed -notcontains $_ } | Sort-Object -Unique)
    if ($criticals.Count -gt 0 -and $found.Count -eq 0) {
      $failures += "$($c.File) references no findings at all, but the registry holds $($criticals.Count) open Critical finding(s). A briefing that names none of them is not selective -- it is empty."
    }
    continue
  }

  $missing = @($c.Must | Where-Object { $text -notmatch [regex]::Escape($_) })
  $present = $c.Must.Count - $missing.Count
  $flag = if ($missing.Count -eq 0) { 'OK' } else { 'SHORT' }
  "  {0,-28} {1,7} bytes | {2} of {3} findings present  {4}" -f $c.File, $bytes, $present, $c.Must.Count, $flag

  if ($missing.Count -gt 0) {
    $missing | Select-Object -First 25 | ForEach-Object { "        MISSING: $_" }
    if ($missing.Count -gt 25) { "        ... and $($missing.Count - 25) more" }
    $failures += "$($c.Label) is missing $($missing.Count) of $($c.Must.Count) findings"
  }

  # Suppressed findings must be PRESENT AND SEPARATE, not folded into the headline list. This
  # cannot be verified precisely from text, but their total absence is decisive and cheap to spot.
  if ($suppressed.Count -gt 0) {
    $suppressedMissing = @($suppressed | Where-Object { $text -notmatch [regex]::Escape($_) })
    if ($suppressedMissing.Count -eq $suppressed.Count) {
      $failures += "$($c.Label) contains NONE of the $($suppressed.Count) findings suppressed at GATE 2. They must appear compactly with their rationale -- what was set aside, and on whose word, is part of the audit record."
    }
  }
}

""
if (-not $anyChecked) {
  Write-Warning "No Phase 5 deliverables found under $outDir. Nothing was verified -- this is not a pass."
  exit 1
}

if ($failures.Count -gt 0) {
  "VERIFICATION FAILED"
  $failures | ForEach-Object { Write-Error $_ }
  ""
  "A short deliverable is almost always BUDGET EXHAUSTION, not a filtering decision: the agent ran"
  "out of output room mid-report. Re-dispatch that one Phase 5 subagent with a fresh budget. Do not"
  "patch the file by hand -- the missing findings are missing from its reasoning, not just its text."
  exit 1
}

"VERIFICATION OK -- every finding the registry holds appears in the deliverables that must carry it."
exit 0
