# SKILL VERSION: v1-skill (2026-07-31b)
# skills/code-security-audit/scripts/score-judge.ps1
#
# Scores the judge's rulings against the owner's own GATE 2 decisions.
#
# WHY THIS EXISTS: the owner wants to stop reviewing every finding before forwarding it to a
# development team, but he cannot decide to trust the judge -- he has to find out whether it
# earned trust. This turns that into a measurement instead of a leap. He reviews as normal;
# gate2_progress.md records what he decided; this compares the two and reports where they
# disagreed and in which direction.
#
# Run it after GATE 2, every run, until the numbers justify a change in how much he reads.
#
# THE TWO ERRORS ARE NOT EQUALLY BAD:
#   JUDGE REJECTED / OWNER KEPT   -- the dangerous one. The judge threw away something real.
#                                    Any of these and full review continues.
#   JUDGE UPHELD  / OWNER DROPPED -- the current problem persisting: junk reaching the list a
#                                    development team would see, which is what costs the tool
#                                    its credibility.
# Agreement alone is not the metric. The direction of disagreement is.
param(
  [Parameter(Mandatory=$true)][string]$Workspace,
  [Parameter(Mandatory=$true)][string]$ProjectName
)

$ErrorActionPreference = 'Stop'
$WORKSPACE = $Workspace.TrimEnd('\')
if (-not (Test-Path -LiteralPath $WORKSPACE)) { Write-Error "Workspace path does not exist: $WORKSPACE"; exit 1 }
$WORKSPACE = (Resolve-Path -LiteralPath $WORKSPACE).Path.TrimEnd('\')
$outDir = Join-Path $WORKSPACE 'audit_state'

$rulingsPath  = Join-Path $outDir 'judge_rulings.md'
$progressPath = Join-Path $outDir 'gate2_progress.md'

if (-not (Test-Path -LiteralPath $rulingsPath)) {
  Write-Error "No judge_rulings.md at $rulingsPath. Nothing to score."
  exit 1
}
if (-not (Test-Path -LiteralPath $progressPath)) {
  Write-Error "No gate2_progress.md at $progressPath. The owner's decisions are the ground truth here -- without them there is nothing to score the judge against."
  exit 1
}

# --- judge rulings: bare field blocks, bullets tolerated (see merge-findings.ps1) ----------
$rulingText = (Get-Content -LiteralPath $rulingsPath -Raw) -replace "`r`n", "`n"
$rulings = @{}
$routes  = @{}
foreach ($m in [regex]::Matches($rulingText, '(?m)^\s*[-*]?\s*id:\s*(F-\d+)\s*$')) {
  $id = $m.Groups[1].Value
  $blockEnd = $rulingText.IndexOf("`n`n", $m.Index)
  if ($blockEnd -lt 0) { $blockEnd = $rulingText.Length }
  $block = $rulingText.Substring($m.Index, $blockEnd - $m.Index)
  $r = [regex]::Match($block, '(?m)^\s*[-*]?\s*ruling:\s*(\w+)')
  if ($r.Success) { $rulings[$id] = $r.Groups[1].Value.ToLower() }
  $rt = [regex]::Match($block, '(?m)^\s*[-*]?\s*route:\s*(\w+)')
  if ($rt.Success) { $routes[$id] = $rt.Groups[1].Value.ToLower() }
}

# --- owner decisions: gate2_progress.md rows | F-012 | not real | words | timestamp | ------
$ownerCalls = @{}
foreach ($line in (Get-Content -LiteralPath $progressPath)) {
  $m = [regex]::Match($line, '^\s*\|\s*(F-\d+)\s*\|\s*([^|]+?)\s*\|')
  if ($m.Success) { $ownerCalls[$m.Groups[1].Value] = $m.Groups[2].Value.Trim().ToLower() }
}

if ($rulings.Count -eq 0) { Write-Error "Parsed no rulings from judge_rulings.md. Check its format against references/judge.md."; exit 1 }
if ($ownerCalls.Count -eq 0) { Write-Error "Parsed no decisions from gate2_progress.md. Check its row format against references/gate-2.md."; exit 1 }

# Owner vocabulary -> kept or dropped. 'unsure' is neither: he explicitly declined to call it,
# and scoring it either way would put words in his mouth.
function Get-OwnerVerdict([string]$call) {
  switch -Regex ($call) {
    '^keep'          { return 'kept' }
    '^not security'  { return 'dropped' }
    '^not real'      { return 'dropped' }
    '^duplicate'     { return 'dropped' }
    '^unsure'        { return 'abstain' }
    default          { return 'abstain' }
  }
}

$agreeKeep = @(); $agreeDrop = @(); $judgeThrewAwayReal = @(); $judgeLetJunkThrough = @()
$unresolvedKept = @(); $unresolvedDropped = @(); $abstained = @(); $unscored = @(); $routedDev = @()

foreach ($id in ($rulings.Keys | Sort-Object)) {
  $j = $rulings[$id]
  $rt = if ($routes.ContainsKey($id)) { $routes[$id] } else { '(none)' }

  # Route FIRST, before anything about the owner's call. A developer-routed question is not his
  # to answer, so 'unsure' is the correct response to it -- and an abstain check placed ahead of
  # this would make exactly those items disappear from the count. Found by an end-to-end run:
  # the judge routed one to a developer, the owner sensibly said 'unsure', and the scorecard
  # reported zero developer-routed items.
  if ($j -eq 'unresolved' -and $rt -eq 'developer') { $routedDev += $id; continue }

  if (-not $ownerCalls.ContainsKey($id)) { $unscored += $id; continue }
  $owner = Get-OwnerVerdict $ownerCalls[$id]
  if ($owner -eq 'abstain') { $abstained += $id; continue }
  switch ($j) {
    'uphold'     { if ($owner -eq 'kept') { $agreeKeep += $id } else { $judgeLetJunkThrough += $id } }
    'reject'     { if ($owner -eq 'dropped') { $agreeDrop += $id } else { $judgeThrewAwayReal += $id } }
    'unresolved' { if ($owner -eq 'kept') { $unresolvedKept += $id } else { $unresolvedDropped += $id } }
  }
}

$scored = $agreeKeep.Count + $agreeDrop.Count + $judgeThrewAwayReal.Count + $judgeLetJunkThrough.Count
$agreed = $agreeKeep.Count + $agreeDrop.Count

"JUDGE SCORECARD -- $ProjectName"
"  Findings ruled on by the judge : $($rulings.Count)"
"  Decisions recorded by the owner: $($ownerCalls.Count)"
"  Comparable (both called it)    : $scored"
if ($abstained.Count -gt 0) { "  Owner abstained ('unsure')     : $($abstained.Count)  -- not scored either way" }
if ($unscored.Count -gt 0)  { "  Not reviewed by the owner      : $($unscored.Count)" }
""
"  AGREED: $agreed of $scored$(if ($scored -gt 0) { "  ($([math]::Round(100.0*$agreed/$scored,1))%)" })"
"    both kept    : $($agreeKeep.Count)"
"    both dropped : $($agreeDrop.Count)"
""
"  DISAGREED:"
"    JUDGE REJECTED, OWNER KEPT   : $($judgeThrewAwayReal.Count)   <-- the dangerous error"
if ($judgeThrewAwayReal.Count -gt 0) { "        $($judgeThrewAwayReal -join ', ')" }
"    JUDGE UPHELD, OWNER DROPPED  : $($judgeLetJunkThrough.Count)   <-- junk that would have reached the dev team"
if ($judgeLetJunkThrough.Count -gt 0) { "        $($judgeLetJunkThrough -join ', ')" }
""
$unresolvedTotal = $unresolvedKept.Count + $unresolvedDropped.Count
"  UNRESOLVED (route: owner): $unresolvedTotal"
if ($unresolvedTotal -gt 0) { "    owner kept $($unresolvedKept.Count), dropped $($unresolvedDropped.Count) -- disputes only he could settle" }
"  UNRESOLVED (route: developer): $($routedDev.Count)  -- questions for a developer, not scored against the owner"
$missingRoute = @($rulings.Keys | Where-Object { $rulings[$_] -eq 'unresolved' -and -not $routes.ContainsKey($_) })
if ($missingRoute.Count -gt 0) {
  Write-Warning "$($missingRoute.Count) unresolved ruling(s) carry no route: $($missingRoute -join ', '). An unresolved ruling with no route is a question addressed to nobody -- it reaches neither the owner nor a developer."
}

# Calibration read. Deliberately conservative: this decides whether findings reach a development
# team without him reading them first.
""
"  READ:"
if ($judgeThrewAwayReal.Count -gt 0) {
  "    The judge threw away $($judgeThrewAwayReal.Count) finding(s) you kept. Keep reviewing every"
  "    finding. Read those rejections and their reasons before trusting this further."
} elseif ($scored -lt 20) {
  "    Only $scored comparable decisions. Too few to conclude anything -- run it again."
} elseif ($judgeLetJunkThrough.Count -gt ($scored * 0.1)) {
  "    No dangerous errors, but $($judgeLetJunkThrough.Count) of $scored upheld findings you dropped."
  "    The judge is too permissive to forward unread; that is the credibility problem, not a"
  "    safety one. Worth another run before changing anything."
} else {
  "    No dangerous errors and few permissive ones across $scored decisions. One clean run is not"
  "    a pattern -- compare against the previous run's scorecard before reading less."
}
if ($rulings.Count -ge 20 -and $unresolvedTotal -le 1) {
  ""
  Write-Warning "The judge ruled 'unresolved' on $unresolvedTotal of $($rulings.Count) findings. A judge that resolves nearly everything has stopped weighing and started deciding. Treat its confidence as unearned until this number looks realistic."
}
exit 0
