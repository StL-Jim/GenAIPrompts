# SKILL VERSION: v25-skill (2026-07-24b)
# skills/stride-threat-model/scripts/archive-compare.ps1
#
# Phase 0 step 7.7 Part 2: compare THIS run's 00-resources.txt against the most recent
# archived run's, on the NAME column, so DISCOVERY drift (a resource present before and
# missing now -- a possible completeness regression) is separated from CLASSIFICATION
# drift (same resource, different type -- e.g. a fetched-from source corrected from
# data-store to external-api). Prints four sets; the agent writes them up in
# 00-archive-comparison.md and surfaces the discovery-drift set at GATE 1.
#
# Reads ONLY the prior run's machine-readable resource list (or its 01-inventory.md
# element names as a fallback) -- the narrow, sanctioned exception to common.md Rule 13a.
param(
  [Parameter(Mandatory=$true)][string]$Workspace,
  [Parameter(Mandatory=$true)][string]$ProjectName
)

$WORKSPACE    = $Workspace.TrimEnd('\')
$PROJECT_NAME = $ProjectName
$OUTPUT_ROOT  = Join-Path $WORKSPACE "$PROJECT_NAME-threat-model"

$currentResources = Join-Path $OUTPUT_ROOT '00-resources.txt'
if (-not (Test-Path $currentResources)) {
  Write-Error "00-resources.txt not found at $currentResources -- write it (step 7.7 Part 1) BEFORE comparing. Not comparing."
  exit 1
}

$archived = @(Get-ChildItem -Path $WORKSPACE -Directory -Filter "$PROJECT_NAME-threat-model-*" -ErrorAction SilentlyContinue |
              Sort-Object LastWriteTime -Descending)
if ($archived.Count -eq 0) {
  "no prior archived threat-model found -- first assessment, no comparison"
  "(do not write 00-archive-comparison.md; proceed to step 8)"
  exit 0
}
$mostRecent = $archived[0]
"compared against: $($mostRecent.Name) (LastWriteTime $($mostRecent.LastWriteTime))"

function Parse-Res($lines) {
  $h = @{}
  foreach ($l in $lines) {
    if ($l) {
      $p = $l -split "`t", 2
      if ($p.Count -eq 2) { $h[$p[1].Trim().ToLower()] = $p[0].Trim().ToLower() }
    }
  }
  $h
}

$priorResources = Join-Path $mostRecent.FullName '00-resources.txt'
$priorInventory = Join-Path $mostRecent.FullName '01-inventory.md'
$currentMap = Parse-Res (Get-Content $currentResources)

if (Test-Path $priorResources) {
  "comparison basis: 00-resources.txt name column (both runs)"
  $priorMap = Parse-Res (Get-Content $priorResources)
} elseif (Test-Path $priorInventory) {
  # Fallback: older archive predates 00-resources.txt. Extract element names from its
  # inventory headings (### C-001: Name / DS-001: Name / EXT-001: Name). Name-only basis,
  # so classification drift cannot be computed -- say so.
  "comparison basis: 01-inventory.md fallback (prior run predates 00-resources.txt) -- WEAKER: element names only, no type column, so classification drift is not detectable"
  $priorMap = @{}
  foreach ($m in (Select-String -Path $priorInventory -Pattern '^#+\s*(C|DS|EXT)-\d+\s*:\s*(.+?)\s*$' -AllMatches)) {
    $name = $m.Matches[0].Groups[2].Value.Trim().ToLower()
    if ($name) { $priorMap[$name] = '(unknown-type)' }
  }
} else {
  "prior archive has neither 00-resources.txt nor 01-inventory.md -- cannot be compared"
  "record that fact and the reason in 00-archive-comparison.md, then proceed to step 8"
  exit 0
}

$onlyInPrior   = @($priorMap.Keys   | Where-Object { -not $currentMap.ContainsKey($_) } | Sort-Object)
$onlyInCurrent = @($currentMap.Keys | Where-Object { -not $priorMap.ContainsKey($_) }   | Sort-Object)
$bothNames     = @($priorMap.Keys   | Where-Object { $currentMap.ContainsKey($_) })
$classDrift    = @($bothNames | Where-Object { $priorMap[$_] -ne '(unknown-type)' -and $priorMap[$_] -ne $currentMap[$_] } |
                   ForEach-Object { "$_ : $($priorMap[$_]) -> $($currentMap[$_])" } | Sort-Object)
$unchanged     = @($bothNames | Where-Object { $priorMap[$_] -eq '(unknown-type)' -or $priorMap[$_] -eq $currentMap[$_] } | Sort-Object)

"prior resource count: $($priorMap.Count) | current resource count: $($currentMap.Count)"
""
"IN PRIOR, NOT IN CURRENT -- DISCOVERY drift / possible regression ($($onlyInPrior.Count)):"
if ($onlyInPrior.Count) { $onlyInPrior | ForEach-Object { "  $_" } } else { "  (none)" }
""
"IN CURRENT, NOT IN PRIOR -- new since last assessment ($($onlyInCurrent.Count)):"
if ($onlyInCurrent.Count) { $onlyInCurrent | ForEach-Object { "  $_" } } else { "  (none)" }
""
"SAME NAME, DIFFERENT TYPE -- CLASSIFICATION drift ($($classDrift.Count)):"
if ($classDrift.Count) { $classDrift | ForEach-Object { "  $_" } } else { "  (none)" }
""
"UNCHANGED ($($unchanged.Count)):"
if ($unchanged.Count) { $unchanged | ForEach-Object { "  $_" } } else { "  (none)" }
""
"REMINDER: every DISCOVERY-drift item must be surfaced in the step 9 Scope Proposal as a question for the user (regression or legitimately decommissioned?) -- never merged into scope automatically."
