# SKILL VERSION: v25-skill (2026-07-23c)
# skills/stride-threat-model/scripts/validate-drawio.ps1
param(
  [Parameter(Mandatory=$true)][string]$Workspace,
  [Parameter(Mandatory=$true)][string]$ProjectName
)

$WORKSPACE = $Workspace.TrimEnd('\')
$PROJECT_NAME = $ProjectName

$dir = "$WORKSPACE\$PROJECT_NAME-threat-model\diagrams"
if (-not (Test-Path $dir)) {
  "No diagrams directory found at $dir"
  return
}
$drawios = @(Get-ChildItem "$dir\*.drawio")
if ($drawios.Count -eq 0) {
  "No .drawio files found in $dir -- Phase 4 wrote nothing to validate."
  return
}
foreach ($f in $drawios) {
  try { $x = [xml](Get-Content $f.FullName -Raw) } catch { "PARSE FAIL: $($f.Name) -- $($_.Exception.Message)"; continue }
  $cells = @($x.SelectNodes("//mxCell")); $ids = @{}; $cells | ForEach-Object { $ids[$_.id] = $true }
  $badE = @($cells | Where-Object { $_.edge -eq '1' -and ((-not $ids[$_.source]) -or (-not $ids[$_.target])) }).Count
  $badP = @($cells | Where-Object { $_.parent -and (-not $ids[$_.parent]) }).Count
  $tb   = @($cells | Where-Object { $_.style -match 'container=1' }).Count
  $edges = @($cells | Where-Object { $_.edge -eq '1' }).Count
  "$($f.Name): parsed OK | cells $($cells.Count) | containers $tb | edges $edges | bad edge refs $badE | bad parents $badP"
}
