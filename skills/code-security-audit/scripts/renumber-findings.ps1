# SKILL VERSION: v2-skill (2026-08-14a)
# skills/code-security-audit/scripts/renumber-findings.ps1
#
# Renumbers findings into one contiguous F-001..F-NNN sequence for the final report.
#
# WHY: workers are given disjoint id blocks so they cannot collide while running in parallel,
# which means the merged registry reads F-001, F-021, F-041, F-101, F-250... A reader cannot
# tell whether the gaps mean findings were removed, lost, or never existed, and it invites
# exactly that question of every report.
#
# WHY A SCRIPT: a finding id is referenced from three places -- the finding's own `id`, other
# findings' `rel:` cross-references, and the `findings:` and `steps:` lines of attack paths.
# Renumbering by hand or by model updates one and forgets another, and the result is an attack
# path citing a finding that no longer exists. This rewrites all of them from a single mapping
# in one pass and then verifies that no reference dangles.
#
# WHEN: after GATE 2, before Phase 5. The report gets contiguous ids; the worker directories
# under audit_state/workers/ are NEVER touched, so the original ids remain traceable back to
# the worker that produced them.
#
#   ...\renumber-findings.ps1 -Workspace <path> -ProjectName <name>            # renumber
#   ...\renumber-findings.ps1 -Workspace <path> -ProjectName <name> -WhatIf    # show the map only
param(
  [Parameter(Mandatory=$true)][string]$Workspace,
  [Parameter(Mandatory=$true)][string]$ProjectName,
  [switch]$WhatIf,
  # Suppressed findings keep their place in the sequence by default so a reader of the
  # gate2 log can still find them. Pass this to number only the surviving findings.
  [switch]$ExcludeSuppressed
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$WORKSPACE = $Workspace.TrimEnd('\')
if (-not (Test-Path -LiteralPath $WORKSPACE)) { Write-Error "Workspace path does not exist: $WORKSPACE"; exit 1 }
$WORKSPACE = (Resolve-Path -LiteralPath $WORKSPACE).Path.TrimEnd('\')

$outDir   = Join-Path $WORKSPACE 'audit_state'
$registry = Join-Path $outDir 'findings_registry.md'
$paths    = Join-Path $outDir 'attack_paths.md'

if (-not (Test-Path -LiteralPath $registry)) {
  Write-Error "findings_registry.md not found at $registry -- run merge-findings.ps1 first. Nothing to renumber."
  exit 1
}

# ---------------------------------------------------------------------------
# BUILD THE MAPPING
#
# Order is the registry's own order, which merge-findings.ps1 produced by walking the
# partition directories in sorted order. That is stable across runs, so renumbering twice
# gives the same answer.
# ---------------------------------------------------------------------------
$regText = (Get-Content -LiteralPath $registry -Raw) -replace "`r`n", "`n"

# Capture id and the status that follows it within the same finding block, so
# -ExcludeSuppressed can skip suppressed findings without reordering the rest.
$idMatches = [regex]::Matches($regText, '(?m)^\s*id:\s*(F-\d+)\s*$')
if ($idMatches.Count -eq 0) {
  Write-Error "No findings matching '^id: F-NNN' in $registry. Refusing to renumber a file whose format is not what this script expects."
  exit 1
}

$map = [ordered]@{}
$next = 1
$skipped = 0
foreach ($m in $idMatches) {
  $oldId = $m.Groups[1].Value
  if ($map.Contains($oldId)) {
    Write-Error "DUPLICATE id $oldId in the registry. merge-findings.ps1 should have caught this. Refusing to renumber against an ambiguous mapping."
    exit 1
  }
  if ($ExcludeSuppressed) {
    # Look ahead within this finding's block for a suppressed status.
    $blockEnd = $regText.IndexOf("`n`n", $m.Index)
    if ($blockEnd -lt 0) { $blockEnd = $regText.Length }
    $block = $regText.Substring($m.Index, $blockEnd - $m.Index)
    if ($block -match '(?m)^\s*status:\s*(false_positive|accepted)\s*$') { $skipped++; continue }
  }
  $map[$oldId] = ('F-{0:D3}' -f $next)
  $next++
}

"MAPPING ($($map.Count) findings$(if ($skipped) { ", $skipped suppressed and left unnumbered" }))"
$changed = 0
foreach ($k in $map.Keys) {
  if ($k -ne $map[$k]) { $changed++; "  $k -> $($map[$k])" }
}
if ($changed -eq 0) { "  (already contiguous -- nothing to change)" }

if ($WhatIf) { "WhatIf: no files written."; exit 0 }

# ---------------------------------------------------------------------------
# REWRITE
#
# Single-pass token replacement over the whole text. A naive sequential replace would
# corrupt the mapping -- rewriting F-001 to F-002 and then later rewriting every F-002 --
# so every id token is resolved against the ORIGINAL map in one MatchEvaluator pass.
# ---------------------------------------------------------------------------
$evaluator = {
  param($m)
  $id = $m.Value
  if ($map.Contains($id)) { return $map[$id] }
  return $id   # unmapped (e.g. a suppressed id under -ExcludeSuppressed): leave it alone
}

$targets = @($registry)
if (Test-Path -LiteralPath $paths) { $targets += $paths }

$backupDir = Join-Path $outDir 'pre-renumber'
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

foreach ($t in $targets) {
  $orig = (Get-Content -LiteralPath $t -Raw) -replace "`r`n", "`n"
  Copy-Item -LiteralPath $t -Destination (Join-Path $backupDir (Split-Path -Leaf $t)) -Force
  $new = [regex]::Replace($orig, 'F-\d+', $evaluator)
  [System.IO.File]::WriteAllText($t, $new, (New-Object System.Text.UTF8Encoding($false)))
  $chk = Get-Item -LiteralPath $t
  if ($chk.Length -eq 0) { Write-Error "$($chk.Name) wrote zero bytes"; exit 1 }
  "  rewritten: $($chk.Name) ($($chk.Length) bytes)  [original copied to audit_state/pre-renumber/]"
}

# ---------------------------------------------------------------------------
# VERIFY -- no reference may dangle
#
# This is the whole reason the renumber is a script. Every F-NNN token now appearing
# anywhere must correspond to a finding that exists in the rewritten registry.
# ---------------------------------------------------------------------------
$newRegText = (Get-Content -LiteralPath $registry -Raw) -replace "`r`n", "`n"
$validIds = @([regex]::Matches($newRegText, '(?m)^\s*id:\s*(F-\d+)\s*$') | ForEach-Object { $_.Groups[1].Value })

$dangling = @()
foreach ($t in $targets) {
  $text = (Get-Content -LiteralPath $t -Raw)
  foreach ($m in [regex]::Matches($text, 'F-\d+')) {
    if ($validIds -notcontains $m.Value) {
      $dangling += "$(Split-Path -Leaf $t): $($m.Value)"
    }
  }
}
$dangling = @($dangling | Sort-Object -Unique)

"VERIFICATION"
"  findings in registry after renumber : $($validIds.Count)"
"  expected                            : $($map.Count)"
"  distinct dangling references        : $($dangling.Count)"

if ($validIds.Count -ne $map.Count) {
  Write-Error "Registry has $($validIds.Count) findings but the mapping had $($map.Count). The rewrite lost or duplicated findings. Restore from audit_state/pre-renumber/ before proceeding."
  exit 1
}
if ($dangling.Count -gt 0) {
  $dangling | Select-Object -First 20 | ForEach-Object { "    DANGLING: $_" }
  Write-Error "$($dangling.Count) reference(s) point at finding ids that do not exist. Restore from audit_state/pre-renumber/ and investigate before Phase 5."
  exit 1
}

$lastId = if ($map.Count -gt 0) { @($map.Values)[-1] } else { '(none)' }
"  sequence                            : F-001 .. $lastId"
"renumber-findings complete -- worker directories untouched, original ids still traceable there."
