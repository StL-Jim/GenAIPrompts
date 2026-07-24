# SKILL VERSION: v25-skill (2026-07-24b)
# skills/stride-threat-model/scripts/consolidate.ps1
#
# Phase 2C step 3: concatenate the header + the three Phase 2 sub-files into the canonical
# 02-threats.md, then remove the temporary header file. Streams content through the OS
# rather than through the agent's context window (the whole point of doing this with a
# script instead of re-reading and re-writing the files). Verifies the result is at least
# the combined size of its inputs, so a truncated concat fails loudly here.
param(
  [Parameter(Mandatory=$true)][string]$Workspace,
  [Parameter(Mandatory=$true)][string]$ProjectName
)

$WORKSPACE    = $Workspace.TrimEnd('\')
$PROJECT_NAME = $ProjectName
$outDir = Join-Path $WORKSPACE "$PROJECT_NAME-threat-model"

$header = Join-Path $outDir '02-header.md'
$parts  = @(
  $header,
  (Join-Path $outDir '02a-context.md'),
  (Join-Path $outDir '02b-threats.md'),
  (Join-Path $outDir '02c-assumptions.md')
)
$missing = @($parts | Where-Object { -not (Test-Path $_) })
if ($missing.Count -gt 0) {
  Write-Error ("Cannot consolidate -- missing input file(s): " + ($missing -join ', ') + ". Write them before running this script.")
  exit 1
}

$expected = ($parts | ForEach-Object { (Get-Item $_).Length } | Measure-Object -Sum).Sum
$target = Join-Path $outDir '02-threats.md'
Get-Content $parts | Set-Content $target -Encoding UTF8
Remove-Item $header

$actual = (Get-Item $target).Length
"inputs (header + 02a + 02b + 02c) total bytes: $expected"
"02-threats.md bytes: $actual"
if ($actual -lt ($expected * 0.95)) {
  Write-Error "02-threats.md ($actual bytes) is materially smaller than its inputs ($expected bytes) -- concat truncated. Do NOT proceed to Phase 3; re-run this step."
  exit 1
}
"02-threats.md written and size-verified (temporary 02-header.md removed)."
Get-Content $target -TotalCount 3
