# SKILL VERSION: v2-skill (2026-08-14a)
# skills/code-security-audit/scripts/init-workspace.ps1
#
# Phase 1 bootstrap in ONE call: derive and print the run's literal values, validate the
# workspace, create audit_state/, add the git excludes, run the prior-audit acknowledgment
# check, initialise STATE.md, and print the top-level repo map. Collapsing these into a
# script keeps multi-line inline PowerShell out of the phase files -- inline blocks are a
# quoting minefield when the agent's shell is bash (Git Bash). See common.md rule S.
#
# -Workspace defaults to the current directory (this is the ONE place the run may derive
# it); pass it explicitly to be certain. Everything downstream uses the PRINTED values.
param(
  [string]$Workspace = (Get-Location).Path,
  [string]$ProjectName,
  [ValidateSet('COORDINATED','STANDALONE')][string]$Mode = 'STANDALONE',
  # The agent self-reports this. Per the source prompt's STATE.md schema notes, a recorded
  # 'unknown' is more useful than a wrong guess, so that is the default.
  [string]$ExecutorModel = 'unknown'
)

$ErrorActionPreference = 'Stop'
$WORKSPACE = $Workspace.TrimEnd('\')
if (-not (Test-Path -LiteralPath $WORKSPACE)) { Write-Error "Workspace path does not exist: $WORKSPACE"; exit 1 }
$WORKSPACE = (Resolve-Path -LiteralPath $WORKSPACE).Path.TrimEnd('\')
if (-not $ProjectName) { $ProjectName = Split-Path -Leaf $WORKSPACE }
$PROJECT_NAME = $ProjectName
$AUDIT_STATE  = Join-Path $WORKSPACE 'audit_state'
$CURRENT_DATE = Get-Date -Format "yyyy-MM-ddTHH:mm"

# The cross-run audit log. Lives at the workspace ROOT, not under audit_state/, because it
# must survive the archive-and-fresh-start model. NEVER created or truncated here -- Phase 5
# owns it, and clobbering it would destroy the only artifact that crosses runs.
$CROSS_RUN_LOG = Join-Path $WORKSPACE 'security_architecture_audit.md'

"=== RUN VALUES (note these literals; every later step substitutes them) ==="
"WORKSPACE     = $WORKSPACE"
"PROJECT_NAME  = $PROJECT_NAME"
"AUDIT_STATE   = $AUDIT_STATE"
"CURRENT_DATE  = $CURRENT_DATE"
"MODE          = $Mode"
"EXECUTOR_MODEL= $ExecutorModel"

$isGit = Test-Path (Join-Path $WORKSPACE '.git')
if (-not $isGit) { Write-Warning "Workspace is not a git repo (no .git directory found). Continuing anyway." }

# PRIOR-AUDIT ACKNOWLEDGMENT (source prompt lines 260-270): presence-only. Do NOT read
# contents. The point is visibility -- a leftover renamed directory should be mentioned
# rather than silently ignored.
"=== PRIOR AUDIT RUNS (presence-only check -- contents are NEVER read) ==="
$priorRuns = @(Get-ChildItem -Path $WORKSPACE -Directory -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -match '^audit_state-\d{8}$' })
if ($priorRuns.Count -gt 0) {
  $priorRuns.Name
  "ACKNOWLEDGMENT REQUIRED: tell the user these were found and that their contents will not be read or referenced."
} else { "none" }

"=== CROSS-RUN AUDIT LOG ==="
if (Test-Path -LiteralPath $CROSS_RUN_LOG) {
  $log = Get-Item -LiteralPath $CROSS_RUN_LOG
  "  PRESENT: security_architecture_audit.md ($($log.Length) bytes, modified $($log.LastWriteTime.ToString('yyyy-MM-ddTHH:mm')))"
  "  Phase 5 must READ and UPDATE this file, never overwrite it. Not created or modified by this script."
} else {
  "  ABSENT: security_architecture_audit.md -- Phase 5 will create it. Not created by this script."
}

"=== AUDIT STATE TREE ==="
New-Item -ItemType Directory -Path $AUDIT_STATE -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $AUDIT_STATE 'workers') -Force | Out-Null
Get-ChildItem -Path $AUDIT_STATE -Directory | ForEach-Object { "  created/present: $($_.Name)" }
"  AUDIT_STATE ready: $AUDIT_STATE"

"=== GIT EXCLUDE ==="
$excludeFile = Join-Path $WORKSPACE '.git\info\exclude'
if (Test-Path $excludeFile) {
    # Both entries are needed: the state dir (and its archived copies) and the root-level
    # cross-run log, which would otherwise show up as an untracked file at the repo root.
    $entries = @('audit_state*/', 'security_architecture_audit.md')
    $current = Get-Content $excludeFile -Raw -ErrorAction SilentlyContinue
    if ($null -eq $current) { $current = '' }
    $toAdd = @($entries | Where-Object { $current -notmatch [regex]::Escape($_) })
    if ($toAdd.Count -gt 0) {
        Add-Content -Path $excludeFile -Value "`n# Added by Code Security Audit agent`n$($toAdd -join "`n")" -Encoding UTF8
        "Added to .git/info/exclude: $($toAdd -join ', ')"
    } else {
        "All entries already present in .git/info/exclude"
    }
} else {
    Write-Warning "No .git/info/exclude found; skipping exclude setup. You may see audit artifacts in 'git status'."
}
if ($isGit) {
  # A `.git` directory can exist without being a usable repo (partial clone, broken
  # submodule, or just an `info/exclude` created by hand). Do NOT let that abort init:
  # the exclude check is a convenience, not a precondition for auditing. Note also that
  # `2>&1` on a native exe in PowerShell 5.1 wraps stderr lines in ErrorRecords and trips
  # $ErrorActionPreference='Stop', so stderr is discarded and the exit code is checked
  # instead.
  $prevEAP = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $st = & git -C $WORKSPACE status --short -- "audit_state*/" "security_architecture_audit.md" 2>$null
    if ($LASTEXITCODE -ne 0) {
      Write-Warning "'.git' is present but git could not read the repo (exit $LASTEXITCODE). Skipping the exclude effectiveness check; the audit itself is unaffected."
    } elseif ($st) {
      "git status (should be EMPTY here -- if files are listed the exclude did not take effect):"; $st
    } else {
      "git status: audit artifacts not tracked (exclude effective)"
    }
  } catch {
    Write-Warning "git status check failed ($($_.Exception.Message)). Skipping; the audit itself is unaffected."
  } finally {
    $ErrorActionPreference = $prevEAP
  }
}

"=== STATE.md ==="
$stateFile = Join-Path $AUDIT_STATE 'STATE.md'
if (Test-Path -LiteralPath $stateFile) {
  "  PRESENT already -- NOT overwritten. This is a RESUME, not a fresh run."
  "  Read it, report Phase Status / Last Completed Step / Resume Instruction to the user,"
  "  and ask whether to resume or restart a phase before doing any work."
} else {
  # Phase 6 is initialised not_applicable in STANDALONE so resume logic never waits on a
  # phase that was never going to run. Phase 3B/4B genuinely cannot be resolved yet
  # (shared_components.md does not exist), so it starts pending.
  $phase6 = if ($Mode -eq 'STANDALONE') { 'not_applicable' } else { 'pending' }
  $lines = @(
    '# Audit STATE'
    ''
    "PROJECT_NAME: $PROJECT_NAME"
    "WORKSPACE: $WORKSPACE"
    "MODE: $Mode"
    "EXECUTOR_MODEL: $ExecutorModel"
    "LAST_UPDATED: $CURRENT_DATE"
    ''
    '## Phase Status'
    ''
    '- Phase 1 (Global Discovery): pending'
    '- Phase 2 (Risk Prioritization): pending'
    '- Phase 3A (Worker Security Review):'
    '  - (partitions added when partition_plan.md exists)'
    '- Phase 4A (Worker Architecture Review):'
    '  - (partitions added when partition_plan.md exists)'
    '- Phase 3B/4B (Shared Component Review): pending'
    '- Phase 5 (Consolidation): pending'
    "- Phase 6 (Comparison HTML Render): $phase6"
    ''
    '## Last Completed Step'
    ''
    'None. Workspace initialised.'
    ''
    '## Resume Instruction'
    ''
    'Begin Phase 1 (Global Discovery).'
  )
  Set-Content -LiteralPath $stateFile -Value $lines -Encoding ASCII
  $chk = Get-Item -LiteralPath $stateFile
  "  CREATED: $stateFile ($($chk.Length) bytes)"
  if ($chk.Length -eq 0) { Write-Error "STATE.md wrote zero bytes"; exit 1 }
  "  Phase 6 initialised to '$phase6' (MODE = $Mode)"
}

"=== TOP-LEVEL REPO MAP (for repo-type classification) ==="
Get-ChildItem -Path $WORKSPACE -Force |
  Where-Object { $_.Name -notlike 'audit_state*' -and $_.Name -ne '.git' -and $_.Name -ne 'security_architecture_audit.md' } |
  ForEach-Object { "  {0,-6} {1}" -f $(if ($_.PSIsContainer) { 'dir' } else { 'file' }), $_.Name }

"=== init-workspace complete ==="
