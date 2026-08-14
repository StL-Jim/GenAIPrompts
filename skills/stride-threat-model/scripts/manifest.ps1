# SKILL VERSION: v25-skill (2026-07-23a)
# skills/stride-threat-model/scripts/manifest.ps1
param(
  [Parameter(Mandatory=$true)][string]$Workspace,
  [Parameter(Mandatory=$true)][string]$ProjectName
)

$WORKSPACE = $Workspace.TrimEnd('\')
$PROJECT_NAME = $ProjectName

$outDir = "$WORKSPACE\$PROJECT_NAME-threat-model"
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Force $outDir | Out-Null }

# Tool-state exclusion (this workflow's own output and the Code Security Audit prompt's):
#  - TOP-LEVEL PREFIX matches so archived `-yyyyMMdd` copies of BOTH this prompt's output
#    (`$PROJECT_NAME-threat-model*`) and the audit's state dir (`audit_state*`) are excluded,
#    not swept in as source code (Operating Rule 13a).
#  - ROOT FILE exclusion for `security_architecture_audit.md`, the audit's cross-run findings
#    log at the workspace root (it is a workflow artifact, not system documentation, and would
#    otherwise be read by Phase 1A's SECURITY* glob and matched by the sweep).
#  - vendored/generated dir NAMES match at ANY depth.
$topLevelExcludeExact   = @('.git')
$topLevelExcludePrefix  = @("$PROJECT_NAME-threat-model", 'audit_state')
$excludeRootFiles       = @('security_architecture_audit.md')
$anyDepthExclude        = 'node_modules|vendor|target|\.venv|dist|build|__pycache__'
$manifest = Get-ChildItem -Path $WORKSPACE -Recurse -File -Force |
  Where-Object {
    $rel = $_.FullName.Substring($WORKSPACE.Length).TrimStart('\')
    $topSegment = ($rel -split '\\')[0]
    $prefixHit = $false
    foreach ($pre in $topLevelExcludePrefix) { if ($topSegment -like "$pre*") { $prefixHit = $true; break } }
    -not ( ($topLevelExcludeExact -contains $topSegment) -or
           $prefixHit -or
           ($excludeRootFiles -contains $rel) -or
           ($rel -match "(^|\\)($anyDepthExclude)(\\|$)") )
  } |
  ForEach-Object { $_.FullName.Substring($WORKSPACE.Length).TrimStart('\') -replace '\\','/' }
$manifest | Set-Content "$outDir\00-file-manifest.txt" -Encoding ASCII
"Manifest file count: $($manifest.Count)"
