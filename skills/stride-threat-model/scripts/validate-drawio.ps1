# SKILL VERSION: v25-skill (2026-07-21a)
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
foreach ($f in Get-ChildItem "$dir\*.drawio") {
  try { $x = [xml](Get-Content $f.FullName -Raw) } catch { "PARSE FAIL: $($f.Name) -- $($_.Exception.Message)"; continue }
  $cells = @($x.SelectNodes("//mxCell")); $ids = @{}; $cells | ForEach-Object { $ids[$_.id] = $true }
  $badE = @($cells | Where-Object { $_.edge -eq '1' -and ((-not $ids[$_.source]) -or (-not $ids[$_.target])) }).Count
  $badP = @($cells | Where-Object { $_.parent -and (-not $ids[$_.parent]) }).Count
  $tb   = @($cells | Where-Object { $_.style -match 'container=1' }).Count
  $edges = @($cells | Where-Object { $_.edge -eq '1' }).Count
  "$($f.Name): parsed OK | cells $($cells.Count) | containers $tb | edges $edges | bad edge refs $badE | bad parents $badP"
}
