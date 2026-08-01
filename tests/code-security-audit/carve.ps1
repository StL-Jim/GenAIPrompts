# tests/code-security-audit/carve.ps1
# SKILL VERSION: v1-skill (2026-07-29a) -- carve + verify tool
#
# BUILD-TIME TOOL. Not shipped inside the skill.
#
# Extracts the methodology sections of code-security-audit.md into the skill's reference
# files by LINE RANGE, so the carve is verbatim by construction rather than by retyping.
# Design decision 1 makes verbatim fidelity the acceptance criterion for this conversion;
# a transcription step would put that criterion at the mercy of paraphrase drift.
#
#   pwsh -File tests/code-security-audit/carve.ps1            # verify (default, read-only)
#   pwsh -File tests/code-security-audit/carve.ps1 -Emit      # write the carve blocks
#
# Each reference file carries its carved region between marker comments:
#
#   <!-- BEGIN VERBATIM CARVE src=code-security-audit.md lines=276-381 sha256=... -->
#   <!-- END VERBATIM CARVE -->
#
# Verify re-extracts from source, re-applies the declared transforms, and compares. It
# fails loudly if the source has moved, so an edit to code-security-audit.md can never
# silently desynchronise the skill from the prompt it was carved from.

[CmdletBinding()]
param(
  [switch]$Emit,
  [string]$RepoRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# $PSScriptRoot is not reliably populated during param binding under
# `powershell.exe -File`, so resolve the default here instead of in the param block.
if (-not $RepoRoot) {
  $here = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
  $RepoRoot = (Resolve-Path (Join-Path $here '..\..')).Path
}

$SourceRel = 'code-security-audit.md'
$SourcePath = Join-Path $RepoRoot $SourceRel
$SkillDir = Join-Path $RepoRoot 'skills\code-security-audit'
$RefDir = Join-Path $SkillDir 'references'

if (-not (Test-Path $SourcePath)) { throw "Source prompt not found: $SourcePath" }

# ---------------------------------------------------------------------------
# TRANSFORMS
#
# The ONLY permitted deviations from source text. Every entry is a notation
# change agreed with the owner -- never a methodology change. Each transform
# declares a minimum match count and the carve FAILS if it is not met, so a
# transform that silently stops matching cannot ship (design lesson 10: two
# unasserted .replace() calls once reported success while changing nothing).
# ---------------------------------------------------------------------------
$Transforms = @(
  @{
    Name    = 'finding-id-drop-date'
    Reason  = 'Decision 7: F-YYYYMMDD-NNN -> F-NNN. Notation only. Matches sibling IDs C-NNN / EX-NNN / AP-NNN and is 10 fewer chars to hand-type.'
    # Order matters: the literal-date form must be rewritten before the template form,
    # otherwise the template pattern cannot distinguish them.
    Rules   = @(
      @{ Pattern = 'F-\d{8}-(\d{3})'; Replacement = 'F-$1';   MinCount = 1 }
      @{ Pattern = 'F-YYYYMMDD-NNN';  Replacement = 'F-NNN';  MinCount = 1 }
    )
  }
)

function Invoke-Transforms {
  param([string]$Text, [ref]$Report)

  foreach ($t in $Transforms) {
    foreach ($rule in $t.Rules) {
      $matchCount = ([regex]$rule.Pattern).Matches($Text).Count
      if ($matchCount -gt 0) {
        $Text = [regex]::Replace($Text, $rule.Pattern, $rule.Replacement)
      }
      $Report.Value += [pscustomobject]@{
        Transform = $t.Name
        Pattern   = $rule.Pattern
        Matches   = $matchCount
        MinCount  = $rule.MinCount
      }
    }
  }
  return $Text
}

# ---------------------------------------------------------------------------
# CARVE MAP
#
# Line ranges verified against code-security-audit.md 2026-07-29 (1243 lines).
# Anchor is asserted on extraction: if the first line of a range does not match,
# the source has been edited and the map must be re-derived before shipping.
# ---------------------------------------------------------------------------
$Carves = @(
  @{ File = 'phase-1-discovery.md'; Start = 276;  End = 381;  Anchor = '^### PHASE 1 -- GLOBAL DISCOVERY' }
  @{ File = 'phase-2.md';           Start = 384;  End = 422;  Anchor = '^### PHASE 2 -- GLOBAL RISK PRIORITIZATION' }
  @{ File = 'phase-3a.md';          Start = 425;  End = 535;  Anchor = '^### PHASE 3A -- WORKER SECURITY REVIEW' }
  @{ File = 'phase-4a.md';          Start = 538;  End = 593;  Anchor = '^### PHASE 4A -- WORKER ARCHITECTURE \+ FUNCTIONAL REVIEW' }
  @{ File = 'phase-3b-4b.md';       Start = 596;  End = 631;  Anchor = '^### PHASE 3B / 4B -- SHARED COMPONENT REVIEW' }
  @{ File = 'phase-5.md';           Start = 634;  End = 908;  Anchor = '^### PHASE 5 -- CONSOLIDATION' }
  @{ File = 'phase-6.md';           Start = 911;  End = 1004; Anchor = '^### PHASE 6 -- COMPARISON HTML RENDER' }
  @{ File = 'schemas.md';           Start = 1007; End = 1193; Anchor = '^FINDING SCHEMA \(COMPACT\)' }
  @{ File = 'global-rules.md';      Start = 65;   End = 150;  Anchor = '^GLOBAL RULES' }
  @{ File = 'tool-usage.md';        Start = 1194; End = 1238; Anchor = '^TOOL USAGE' }
)

$BeginRe = '<!-- BEGIN VERBATIM CARVE src=(?<src>\S+) lines=(?<start>\d+)-(?<end>\d+) sha256=(?<sha>[0-9a-f]{64}) -->'
$EndMarker = '<!-- END VERBATIM CARVE -->'

function Get-Sha256 {
  param([string]$Text)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    return -join ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') })
  } finally { $sha.Dispose() }
}

$srcLines = Get-Content -LiteralPath $SourcePath
if ($srcLines.Count -lt 1243) {
  Write-Warning "Source is $($srcLines.Count) lines; carve map was derived against 1243. Anchors will catch drift."
}

$failures = New-Object System.Collections.Generic.List[string]
$results  = New-Object System.Collections.Generic.List[object]

foreach ($c in $Carves) {
  $target = Join-Path $RefDir $c.File

  # --- extract + assert anchor -------------------------------------------
  if ($c.End -gt $srcLines.Count) {
    $failures.Add("$($c.File): range end $($c.End) exceeds source length $($srcLines.Count)")
    continue
  }
  $block = ($srcLines[($c.Start - 1)..($c.End - 1)]) -join "`n"
  $firstLine = $srcLines[$c.Start - 1]
  if ($firstLine -notmatch $c.Anchor) {
    $failures.Add("$($c.File): ANCHOR MISMATCH at line $($c.Start). Expected /$($c.Anchor)/, got: $firstLine")
    continue
  }

  $report = @()
  $carved = Invoke-Transforms -Text $block -Report ([ref]$report)

  # Normalise ONCE, before hashing, so emit and verify cannot disagree. A range that
  # begins or ends on a blank source line would otherwise hash untrimmed but compare
  # trimmed. Line endings are forced to LF for the same reason.
  $carved = ($carved -replace "`r`n", "`n").Trim("`n")
  $sha = Get-Sha256 -Text $carved

  $results.Add([pscustomobject]@{
    File = $c.File; Start = $c.Start; End = $c.End
    Lines = ($c.End - $c.Start + 1); Sha = $sha
    Transformed = (($report | Measure-Object -Property Matches -Sum).Sum)
  })

  $beginLine = "<!-- BEGIN VERBATIM CARVE src=$SourceRel lines=$($c.Start)-$($c.End) sha256=$sha -->"

  if ($Emit) {
    # Preserve any framing the file already carries outside the markers.
    $pre = ''; $post = ''
    if (Test-Path $target) {
      $existing = Get-Content -LiteralPath $target -Raw
      if ($existing -match $BeginRe) {
        $bIdx = $existing.IndexOf('<!-- BEGIN VERBATIM CARVE')
        $eIdx = $existing.IndexOf($EndMarker)
        if ($eIdx -lt 0) { $failures.Add("$($c.File): BEGIN marker without END marker"); continue }
        $pre  = $existing.Substring(0, $bIdx)
        $post = $existing.Substring($eIdx + $EndMarker.Length)
      } else {
        $pre = $existing.TrimEnd() + "`n`n"
      }
    }
    $out = $pre + $beginLine + "`n" + $carved + "`n" + $EndMarker + $post
    # Write LF-only, no BOM, no NUL -- the test suite asserts all three.
    $out = $out -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($target, $out, (New-Object System.Text.UTF8Encoding($false)))
    if ($out -match "`0") { $failures.Add("$($c.File): NUL byte in output") }
  }
  else {
    if (-not (Test-Path $target)) {
      $failures.Add("$($c.File): MISSING. Run with -Emit to generate.")
      continue
    }
    # Normalise line endings before comparing. Git's core.autocrlf rewrites these files to
    # CRLF on checkout, so the bytes on disk legitimately differ from the LF-joined source
    # text without the CONTENT differing at all. Comparing raw would fail on any Windows
    # clone with autocrlf enabled -- which is the default -- even though nothing is wrong.
    $existing = (Get-Content -LiteralPath $target -Raw) -replace "`r`n", "`n"
    $m = [regex]::Match($existing, $BeginRe)
    if (-not $m.Success) { $failures.Add("$($c.File): no BEGIN VERBATIM CARVE marker"); continue }

    if ($m.Groups['src'].Value -ne $SourceRel) {
      $failures.Add("$($c.File): marker names source '$($m.Groups['src'].Value)', expected '$SourceRel'")
    }
    if ([int]$m.Groups['start'].Value -ne $c.Start -or [int]$m.Groups['end'].Value -ne $c.End) {
      $failures.Add("$($c.File): marker range $($m.Groups['start'].Value)-$($m.Groups['end'].Value) != map range $($c.Start)-$($c.End)")
    }
    if ($m.Groups['sha'].Value -ne $sha) {
      $failures.Add("$($c.File): CONTENT DRIFT. Carved block does not match source lines $($c.Start)-$($c.End). Marker sha=$($m.Groups['sha'].Value) recomputed=$sha. Either the source moved or the reference file was hand-edited inside the markers.")
    }

    $eIdx = $existing.IndexOf($EndMarker)
    if ($eIdx -lt 0) { $failures.Add("$($c.File): BEGIN marker without END marker"); continue }
    $bodyStart = $m.Index + $m.Length
    $body = $existing.Substring($bodyStart, $eIdx - $bodyStart).Trim("`n")
    if ($body -ne $carved) {
      $failures.Add("$($c.File): body between markers differs from freshly carved source text")
    }
  }
}

# Global transform assertion: every declared rule must have fired somewhere.
$allText = ($srcLines -join "`n")
foreach ($t in $Transforms) {
  foreach ($rule in $t.Rules) {
    $n = ([regex]$rule.Pattern).Matches($allText).Count
    if ($n -lt $rule.MinCount) {
      $failures.Add("TRANSFORM '$($t.Name)' pattern /$($rule.Pattern)/ matched $n times in source, minimum $($rule.MinCount). The transform is stale -- either the source notation changed or the rule is wrong. Refusing to report success.")
    }
  }
}

$results | Format-Table -AutoSize | Out-String | Write-Host

# ---------------------------------------------------------------------------
# SOURCE COVERAGE ACCOUNTING
#
# Decision 1 makes verbatim fidelity the acceptance criterion, so it is not enough to
# show that what WAS carved is faithful -- it must also be shown that nothing
# methodological was left behind. Every line of the source prompt must be accounted for
# as exactly one of:
#
#   CARVED    reproduced verbatim in a reference file (the map above)
#   ABSORBED  rewritten into SKILL.md because it describes ORCHESTRATION, not analysis --
#             the operating model, phase order, and state system, all of which the skill
#             necessarily reimplements (subagents, gates, orchestrator-owned STATE.md)
#   FILLER    a `---` separator, a section banner, or a blank line
#
# Any line in none of those is an UNACCOUNTED line and fails the run. That is the check
# that would catch methodology being silently dropped.
# ---------------------------------------------------------------------------
$Absorbed = @(
  @{ Start = 1;   End = 64;  Why = 'CONTEXT / PRIMARY OBJECTIVE / SECONDARY OUTPUTS / OPERATING MODEL / PHASE EXECUTION ORDER -> SKILL.md dispatch table and gate policy' }
  @{ Start = 151; End = 273; Why = 'STATE FILE SYSTEM / STATE.md SCHEMA / SESSION-START / PRIOR-AUDIT ACK -> SKILL.md state schema + scripts/init-workspace.ps1' }
)
$Filler = @(
  @{ Start = 274; End = 275 }, @{ Start = 382; End = 383 }, @{ Start = 423; End = 424 }
  @{ Start = 536; End = 537 }, @{ Start = 594; End = 595 }, @{ Start = 632; End = 633 }
  @{ Start = 909; End = 910 }, @{ Start = 1005; End = 1006 }
)

$covered = @{}
foreach ($c in $Carves)   { for ($i = $c.Start; $i -le $c.End; $i++) { $covered[$i] = 'CARVED' } }
foreach ($a in $Absorbed) { for ($i = $a.Start; $i -le $a.End; $i++) { if (-not $covered.ContainsKey($i)) { $covered[$i] = 'ABSORBED' } } }
foreach ($f in $Filler)   { for ($i = $f.Start; $i -le $f.End; $i++) { if (-not $covered.ContainsKey($i)) { $covered[$i] = 'FILLER' } } }

$unaccounted = @(1..$srcLines.Count | Where-Object { -not $covered.ContainsKey($_) })
$nCarved   = @($covered.Values | Where-Object { $_ -eq 'CARVED' }).Count
$nAbsorbed = @($covered.Values | Where-Object { $_ -eq 'ABSORBED' }).Count
$nFiller   = @($covered.Values | Where-Object { $_ -eq 'FILLER' }).Count

Write-Host "SOURCE COVERAGE ($SourceRel, $($srcLines.Count) lines):"
Write-Host ("  CARVED      {0,5}  verbatim in reference files" -f $nCarved)
foreach ($a in $Absorbed) { Write-Host ("  ABSORBED    {0,5}  lines {1}-{2}: {3}" -f ($a.End - $a.Start + 1), $a.Start, $a.End, $a.Why) }
Write-Host ("  FILLER      {0,5}  separators, banners, blanks" -f $nFiller)
Write-Host ("  UNACCOUNTED {0,5}" -f $unaccounted.Count)

# Verify FILLER really is filler rather than an assumption -- a range asserted to be a
# separator that actually holds prose would hide dropped methodology behind this check.
foreach ($f in $Filler) {
  for ($i = $f.Start; $i -le $f.End; $i++) {
    $line = $srcLines[$i - 1]
    if ($line.Trim() -ne '' -and $line.Trim() -ne '---' -and $line.Trim() -ne 'PHASE EXECUTION') {
      $failures.Add("FILLER line $i is not filler: '$line'. The coverage map is wrong and may be hiding dropped methodology.")
    }
  }
}
if ($unaccounted.Count -gt 0) {
  $ranges = ($unaccounted | Select-Object -First 20) -join ', '
  $failures.Add("UNACCOUNTED source lines ($($unaccounted.Count)): $ranges$(if ($unaccounted.Count -gt 20) { ' ...' }). Every line must be CARVED, ABSORBED or FILLER. An unaccounted line is methodology that may have been dropped.")
}

if ($failures.Count -gt 0) {
  Write-Host "CARVE $(if ($Emit) { 'EMIT' } else { 'VERIFY' }): FAILED ($($failures.Count))" -ForegroundColor Red
  $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
  exit 1
}

Write-Host "CARVE $(if ($Emit) { 'EMIT' } else { 'VERIFY' }): OK -- $($results.Count) sections, $(($results | Measure-Object -Property Lines -Sum).Sum) source lines" -ForegroundColor Green
exit 0
