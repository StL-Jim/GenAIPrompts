# SKILL VERSION: v2-skill (2026-08-02a)
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

# PRUNE during traversal, do not filter after it.
#
# This was `Get-ChildItem -Recurse -File -Force | Where-Object { ...exclude .git... }`, which is
# correct and catastrophically slow: -Recurse descends INTO .git and node_modules, enumerates
# every loose object and vendored file, and only then discards them. The owner's 1,479-file
# application took over five minutes; a 1,500-file fixture with no .git took 2.7 seconds. The
# difference is not the algorithm, it is the tens of thousands of files nobody ever wanted --
# and on a corporate machine every one of them is also an antivirus round trip.
#
# .git is pruned at ANY depth here, not just the top level, so submodules are cheap too. A
# directory named .git is never source in any repository.
$pruneDirs = @('.git','node_modules','vendor','target','.venv','dist','build','__pycache__')

$walked = New-Object System.Collections.Generic.List[string]
$stack  = New-Object System.Collections.Generic.Stack[string]
$stack.Push($WORKSPACE)
while ($stack.Count -gt 0) {
  $dir = $stack.Pop()
  try { $subs = [System.IO.Directory]::EnumerateDirectories($dir) } catch { continue }
  foreach ($sub in $subs) {
    $leaf = [System.IO.Path]::GetFileName($sub)
    if ($pruneDirs -contains $leaf.ToLower()) { continue }

    # THIS AUDIT'S OWN OUTPUT, and the threat model's, at ANY depth.
    #
    # The owner asked whether prior audit_state or threat-model directories were excluded. The
    # honest answer was: only if they sit at the top level AND the threat model is named exactly
    # "<project>-threat-model". Anything else was being audited as application source -- and the
    # source prompt's own example path is `real-world-threat-model/`, which would NOT have
    # matched on a project named cassidi-app.
    #
    # Auditing a previous audit is worse than wasted work: findings_registry.md is full of
    # vulnerability descriptions and file:line citations, so a worker reading it will "find"
    # every issue the last run already reported, in a file that is not application code.
    if ($leaf -like 'audit_state*') { continue }
    if ($leaf -match '(?i)-threat-model$|^threat-model$') { continue }
    $stack.Push($sub)
  }
  try { foreach ($f in [System.IO.Directory]::EnumerateFiles($dir)) { $walked.Add($f) } } catch { }
}

# The original Where-Object is KEPT as a safety net rather than replaced. It is now cheap -- it
# runs over the pruned set -- and it still enforces the cases the walk does not express, such as
# $excludeRootFiles. Two independent expressions of the same exclusion is the right trade here:
# a pruning bug that let .git through would otherwise be invisible in the output.
$manifest = $walked | Sort-Object |
  ForEach-Object { Get-Item -LiteralPath $_ -Force } |
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
