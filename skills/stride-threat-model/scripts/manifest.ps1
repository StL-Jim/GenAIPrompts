# SKILL VERSION: v25-skill (2026-07-21a)
# skills/stride-threat-model/scripts/manifest.ps1
param(
  [Parameter(Mandatory=$true)][string]$Workspace,
  [Parameter(Mandatory=$true)][string]$ProjectName
)

$WORKSPACE = $Workspace.TrimEnd('\')
$PROJECT_NAME = $ProjectName

$outDir = "$WORKSPACE\$PROJECT_NAME-threat-model"
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Force $outDir | Out-Null }

# Two-tier exclusion: tool-state dirs match at the TOP LEVEL (by prefix, so archived
# `-yyyyMMdd` copies from prior runs are excluded too, not swept in as source code);
# vendored/generated dir NAMES match at ANY depth (a nested src\app\node_modules or
# __pycache__ is just as vendored as a top-level one -- root-only matching silently
# bloats the manifest and the discovery sweep with third-party files).
$topLevelExcludeExact = @('audit_state', '.git')
$topLevelExcludePrefix = "$PROJECT_NAME-threat-model"
$anyDepthExclude = 'node_modules|vendor|target|\.venv|dist|build|__pycache__'
$manifest = Get-ChildItem -Path $WORKSPACE -Recurse -File -Force |
  Where-Object {
    $rel = $_.FullName.Substring($WORKSPACE.Length).TrimStart('\')
    $topSegment = ($rel -split '\\')[0]
    -not ( ($topLevelExcludeExact -contains $topSegment) -or
           ($topSegment -like "$topLevelExcludePrefix*") -or
           ($rel -match "(^|\\)($anyDepthExclude)(\\|$)") )
  } |
  ForEach-Object { $_.FullName.Substring($WORKSPACE.Length).TrimStart('\') -replace '\\','/' }
$manifest | Set-Content "$outDir\00-file-manifest.txt" -Encoding UTF8
"Manifest file count: $($manifest.Count)"
