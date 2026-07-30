# SKILL VERSION: v1-skill (2026-07-29a)
# skills/code-security-audit/scripts/manifest.ps1
#
# Builds audit_state/00-file-manifest.txt: the complete list of SOURCE FILES under audit.
# Phase 2 partitions this list; Phase 3A/4A workers audit the files in their partition.
param(
  [Parameter(Mandatory=$true)][string]$Workspace,
  [Parameter(Mandatory=$true)][string]$ProjectName
)

$ErrorActionPreference = 'Stop'
$WORKSPACE = $Workspace.TrimEnd('\')
if (-not (Test-Path -LiteralPath $WORKSPACE)) { Write-Error "Workspace path does not exist: $WORKSPACE"; exit 1 }
$WORKSPACE = (Resolve-Path -LiteralPath $WORKSPACE).Path.TrimEnd('\')
$PROJECT_NAME = $ProjectName

$outDir = Join-Path $WORKSPACE 'audit_state'
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Force $outDir | Out-Null }

# ---------------------------------------------------------------------------
# TOOL-STATE EXCLUSIONS
#
# This manifest lists SOURCE CODE TO AUDIT. Both workflow directories are excluded
# because neither is source:
#
#  - `audit_state*` -- this skill's OWN output. Excluding it from the manifest is not in
#    tension with the skill being allowed to READ it. Read permission is a rule (common.md
#    rule 6); the manifest is an inventory of the system under review. Include audit_state
#    here and Phase 3A workers would audit findings_registry.md as though it were
#    application code, generating findings about the audit's own output.
#  - `{PROJECT_NAME}-threat-model*` -- the companion STRIDE prompt's output. In COORDINATED
#    mode the audit reads the threat model as cross-reference INPUT, but it is never source
#    code and never evidence about the system.
#
# TOP-LEVEL PREFIX matching (not exact) so archived `-yyyyMMdd` copies of both -- and
# `audit_state_old`, `audit_state-2026-01`, etc. -- are excluded too.
#
# ROOT FILE exclusion for `security_architecture_audit.md`, the cross-run audit log at the
# workspace root. It is a workflow artifact, not system documentation, and a SECURITY* glob
# would otherwise pull it in.
#
# Vendored/generated dir NAMES match at ANY depth.
# ---------------------------------------------------------------------------
$topLevelExcludeExact   = @('.git')
$topLevelExcludePrefix  = @('audit_state', "$PROJECT_NAME-threat-model")
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

$manifestPath = Join-Path $outDir '00-file-manifest.txt'
$manifest | Set-Content -LiteralPath $manifestPath -Encoding ASCII

# Verify the write (common.md rule W-d). A manifest that silently wrote zero files would
# make every downstream partition and worker vacuously "complete".
$chk = Get-Item -LiteralPath $manifestPath
"Manifest file count: $($manifest.Count)"
"Manifest written: $manifestPath ($($chk.Length) bytes)"
if ($manifest.Count -eq 0) {
  Write-Error "Manifest is EMPTY. Either the workspace has no source files or the exclusions are too broad. Refusing to report success."
  exit 1
}
