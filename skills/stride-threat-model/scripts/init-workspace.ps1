# SKILL VERSION: v25-skill (2026-07-24b)
# skills/stride-threat-model/scripts/init-workspace.ps1
#
# Phase 0 steps 1/2/3/5 in ONE call: derive and print the run's literal values, validate
# the workspace, create the output tree, add the git exclude, list prior archived runs,
# and print the top-level repo map. Collapsing these into a script removes four multi-line
# inline PowerShell blocks from phase-0.md -- inline blocks are a quoting minefield when
# the agent's shell is bash (Git Bash) rather than PowerShell, and they carried the
# shell-state re-declaration burden. See common.md "Running the skill's scripts".
#
# -Workspace defaults to the current directory (this is the ONE place the run may derive
# it); pass it explicitly to be certain. Everything downstream uses the PRINTED values.
param(
  [string]$Workspace = (Get-Location).Path,
  [string]$ProjectName
)

$ErrorActionPreference = 'Stop'
$WORKSPACE = $Workspace.TrimEnd('\')
if (-not (Test-Path -LiteralPath $WORKSPACE)) { Write-Error "Workspace path does not exist: $WORKSPACE"; exit 1 }
$WORKSPACE = (Resolve-Path -LiteralPath $WORKSPACE).Path.TrimEnd('\')
if (-not $ProjectName) { $ProjectName = Split-Path -Leaf $WORKSPACE }
$PROJECT_NAME = $ProjectName
$OUTPUT_ROOT  = Join-Path $WORKSPACE "$PROJECT_NAME-threat-model"
$CURRENT_DATE = Get-Date -Format "yyyy-MM-ddTHH:mm"

"=== RUN VALUES (note these literals; every later step substitutes them) ==="
"WORKSPACE    = $WORKSPACE"
"PROJECT_NAME = $PROJECT_NAME"
"OUTPUT_ROOT  = $OUTPUT_ROOT"
"CURRENT_DATE = $CURRENT_DATE"

$isGit = Test-Path (Join-Path $WORKSPACE '.git')
if (-not $isGit) { Write-Warning "Workspace is not a git repo (no .git directory found). Continuing anyway." }

"=== PRIOR ARCHIVED RUNS (read-only reference -- NEVER written to, never a resume target) ==="
$archivedRuns = @(Get-ChildItem -Path $WORKSPACE -Directory -Filter "$PROJECT_NAME-threat-model-*" -ErrorAction SilentlyContinue)
if ($archivedRuns.Count -gt 0) { $archivedRuns.Name } else { "none" }

"=== OUTPUT TREE ==="
New-Item -ItemType Directory -Path $OUTPUT_ROOT -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $OUTPUT_ROOT 'diagrams') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $OUTPUT_ROOT 'outputs')  -Force | Out-Null
Get-ChildItem -Path $OUTPUT_ROOT -Directory | ForEach-Object { "  created/present: $($_.Name)" }
"  OUTPUT_ROOT ready: $OUTPUT_ROOT"

"=== GIT EXCLUDE ==="
$excludeFile = Join-Path $WORKSPACE '.git\info\exclude'
if (Test-Path $excludeFile) {
    $entry = "$PROJECT_NAME-threat-model*/"
    $current = Get-Content $excludeFile -Raw -ErrorAction SilentlyContinue
    if ($current -notmatch [regex]::Escape($entry)) {
        Add-Content -Path $excludeFile -Value "`n# Added by STRIDE threat modeling agent`n$entry" -Encoding UTF8
        "Added '$entry' to .git/info/exclude"
    } else {
        "'$entry' already present in .git/info/exclude"
    }
} else {
    Write-Warning "No .git/info/exclude found; skipping exclude setup. You may see the output directory in 'git status'."
}
if ($isGit) {
  $st = & git -C $WORKSPACE status --short -- "$PROJECT_NAME-threat-model*/" 2>&1
  if ($st) { "git status (output dir should be EMPTY here -- if files are listed the exclude did not take effect):"; $st }
  else { "git status: output directory not tracked (exclude effective)" }
}

"=== TOP-LEVEL REPO MAP (for repo-type classification) ==="
Get-ChildItem -Path $WORKSPACE -Force |
  Where-Object { $_.Name -notlike "$PROJECT_NAME-threat-model*" -and $_.Name -ne '.git' } |
  ForEach-Object { "  {0,-6} {1}" -f $(if ($_.PSIsContainer) { 'dir' } else { 'file' }), $_.Name }

"=== init-workspace complete ==="
