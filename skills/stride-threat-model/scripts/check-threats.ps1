# SKILL VERSION: v26 (2026-08-03a)
# skills/stride-threat-model/scripts/check-threats.ps1
#
# Checks 02b-threats.md against the Phase 2B rules that are MECHANICALLY decidable.
#
# WHY THIS EXISTS: Phase 2B states about a dozen rules of the form "every row must carry X",
# and until now nothing checked any of them. The agent that wrote the rows also audited them,
# in the same context window, at the point of maximum fill -- phase-2b.md says so itself:
# "stated rules degrade as the context window fills; the audit at the end catches what the rule
# missed in the middle". An end-of-phase self-audit is the weakest possible check, and one of
# the numbers it is asked to report (the Impact-to-Gains inconsistency count) cannot be
# computed by the agent at all, so it is recalled -- which common.md Rule 15 calls
# indistinguishable from fabricated.
#
# This script does not judge threats. It cannot tell you whether a threat is real, whether the
# cited code supports it, or whether the reasoning is sound. It checks arithmetic, vocabulary
# and structure -- facts, not arguments -- which is exactly why it can be trusted and why it
# cannot be argued with. Judgment stays with the reviewer at GATE 3.
#
# Scope is deliberately narrow: every check here is one that CANNOT produce a false positive.
# Checks that would over-fire (speculation tell-phrases, the IAM hard gate) are not implemented
# rather than implemented as noise.
#
#   ...\check-threats.ps1 -Workspace <path> -ProjectName <name>
#
# Exit 0 = no mechanical violations. Exit 1 = violations, or the file could not be parsed.
# A row that cannot be parsed is a FAILURE, never a pass: a stray pipe in a prose cell shifts
# every column after it, and a shifted row that scores clean is worse than no check at all.
param(
  [Parameter(Mandatory=$true)][string]$Workspace,
  [Parameter(Mandatory=$true)][string]$ProjectName
)

$ErrorActionPreference = 'Stop'
$WORKSPACE = $Workspace.TrimEnd('\')
if (-not (Test-Path -LiteralPath $WORKSPACE)) { Write-Error "Workspace path does not exist: $WORKSPACE"; exit 1 }
$WORKSPACE = (Resolve-Path -LiteralPath $WORKSPACE).Path.TrimEnd('\')
$out = Join-Path $WORKSPACE "$ProjectName-threat-model"

$threatsPath = Join-Path $out '02b-threats.md'
$contextPath = Join-Path $out '02a-context.md'
if (-not (Test-Path -LiteralPath $threatsPath)) {
  Write-Error "No 02b-threats.md at $threatsPath. Phase 2B has not produced a table to check."
  exit 1
}

# ---------------------------------------------------------------------------
# ASSET TIERS -- the authority is 02a-context.md, not the threat row.
# phase-2b.md: "Carry the tier across from 02a-context.md; it is not re-judged here, and
# re-rating an asset upward while writing a threat is severity inflation wearing a different hat."
# ---------------------------------------------------------------------------
$assetTier = @{}
if (Test-Path -LiteralPath $contextPath) {
  foreach ($line in (Get-Content -LiteralPath $contextPath)) {
    $m = [regex]::Match($line, '(AS-\d+)')
    if (-not $m.Success) { continue }
    $t = [regex]::Match($line, '(Crown Jewel|Sensitive|Supporting)')
    if ($t.Success -and -not $assetTier.ContainsKey($m.Groups[1].Value)) {
      $assetTier[$m.Groups[1].Value] = $t.Groups[1].Value
    }
  }
}

# ---------------------------------------------------------------------------
# THE ROWS
# ---------------------------------------------------------------------------
$EXPECTED_COLS = 21
$COLS = @('ThreatID','Confidence','Priority','Category','OWASP','Component','TrustBoundary',
          'Title','ThreatAgent','Asset','Attack','AttackSurface','Impact','Description',
          'Evidence','Likelihood','SecurityControl','ResidualRisk','Mitigation',
          'Disposition','DispositionRationale')

$lines = Get-Content -LiteralPath $threatsPath
$rows = @(); $parseFailures = @(); $lineNo = 0
foreach ($line in $lines) {
  $lineNo++
  $t = $line.Trim()
  if (-not $t.StartsWith('|')) { continue }
  if ($t -match '^\|[\s\-\|:]+\|$') { continue }              # separator row
  # Strip exactly ONE leading and ONE trailing pipe. Trim('|') would strip ALL of them, and
  # the last two cells (Disposition, DispositionRationale) are EMPTY by contract during
  # generation -- so a row written without padding spaces ends '|||' and would silently lose
  # two fields, then be reported as a parse failure it did not have.
  $inner = $t
  if ($inner.StartsWith('|')) { $inner = $inner.Substring(1) }
  if ($inner.EndsWith('|'))   { $inner = $inner.Substring(0, $inner.Length - 1) }
  $cells = @(($inner -split '\|') | ForEach-Object { $_.Trim() })
  if ($cells.Count -ge 1 -and $cells[0] -eq 'ThreatID') { continue }   # header row
  if ($cells.Count -ne $EXPECTED_COLS) {
    $parseFailures += "line ${lineNo}: row has $($cells.Count) fields, expected $EXPECTED_COLS. First cell: '$($cells[0])'"
    continue
  }
  $r = @{}
  for ($i = 0; $i -lt $EXPECTED_COLS; $i++) { $r[$COLS[$i]] = $cells[$i] }
  $r['_line'] = $lineNo
  $rows += ,$r
}

if ($parseFailures.Count -gt 0) {
  "CHECK FAILED -- $($parseFailures.Count) row(s) could not be parsed"
  ""
  $parseFailures | ForEach-Object { "  $_" }
  ""
  "A wrong field count is almost always a stray '|' inside a prose cell (Description, Evidence,"
  "Mitigation). Every column after it is shifted, so nothing below can be trusted. Fix the cell"
  "-- escape the pipe or reword -- and re-run. No other check ran."
  exit 1
}

if ($rows.Count -eq 0) {
  Write-Error "Parsed no threat rows from 02b-threats.md. Either Phase 2B produced an empty table or its format is not what this script expects. Nothing was checked -- this is NOT a pass."
  exit 1
}

# ---------------------------------------------------------------------------
# CHECKS
# ---------------------------------------------------------------------------
$V = @()   # violations
function Add-V($id, $what) { $script:V += [PSCustomObject]@{ Id = $id; What = $what } }

$STRIDE  = @('Spoofing','Tampering','Repudiation','Information Disclosure','Denial of Service','Elevation of Privilege')
$SURFACE = @('External Interfaces','Internal Network','Development & Deployment',
             'Infrastructure & Orchestration','Configuration & Secrets','Observability & Operations',
             'Supply Chain','Authentication & Identity','Data Storage','Client-Side')

foreach ($r in $rows) {
  $id = $r['ThreatID']; if (-not $id) { $id = "line $($r['_line'])" }

  # --- closed vocabularies -------------------------------------------------
  if ($r['Confidence']   -notin @('Confirmed','Likely'))      { Add-V $id "Confidence is '$($r['Confidence'])' -- must be Confirmed or Likely" }
  if ($r['Priority']     -notin @('Priority 1','Priority 2')) { Add-V $id "Priority is '$($r['Priority'])' -- must be Priority 1 or Priority 2" }
  if ($r['Category']     -notin $STRIDE)                      { Add-V $id "Category is '$($r['Category'])' -- not one of the six STRIDE categories" }
  if ($r['AttackSurface'] -notin $SURFACE)                    { Add-V $id "AttackSurface is '$($r['AttackSurface'])' -- not one of the ten permitted values" }
  if ($r['Likelihood']   -notin @('Medium','High'))           { Add-V $id "Likelihood is '$($r['Likelihood'])' -- must be Medium or High (Low is excluded by the inclusion gate)" }
  if ($r['ResidualRisk'] -notin @('Severe','Elevated'))       { Add-V $id "ResidualRisk is '$($r['ResidualRisk'])' -- must be Severe or Elevated" }
  if ($r['Disposition']           -ne '')                     { Add-V $id "Disposition must be EMPTY during generation (reviewers fill it in); found '$($r['Disposition'])'" }
  if ($r['DispositionRationale']  -ne '')                     { Add-V $id "DispositionRationale must be EMPTY during generation; found '$($r['DispositionRationale'])'" }

  # --- mandatory structure -------------------------------------------------
  $agentLevel = [regex]::Match($r['ThreatAgent'], '\(L([0-4])\)')
  if (-not $agentLevel.Success) { Add-V $id "ThreatAgent '$($r['ThreatAgent'])' carries no (L0)-(L4) privilege level -- mandatory" }

  $assetM = [regex]::Match($r['Asset'], '(AS-\d+)\s*\((Crown Jewel|Sensitive|Supporting)\)')
  if (-not $assetM.Success) { Add-V $id "Asset '$($r['Asset'])' is not in the form 'AS-NNN (tier)'" }

  # NOTE: use .Contains(), not -like. In a -like pattern '[' opens a character class, so
  # "*[Prereq:*" is not a valid wildcard pattern and throws.
  $desc = [string]$r['Description']
  foreach ($note in @('[Prereq:','[Gains:','[Risk calc:')) {
    if (-not $desc.Contains($note)) { Add-V $id "Description is missing the mandatory $note ...] note" }
  }
  if ($agentLevel.Success -and $agentLevel.Groups[1].Value -in @('3','4')) {
    if (-not $desc.Contains('[Cap escape:')) {
      Add-V $id "ThreatAgent is L$($agentLevel.Groups[1].Value) but the Description carries no [Cap escape: path|gain -- ...] note. The L3/L4 cap was never lifted, so this row belongs in the ledger as 'Low likelihood'."
    }
  }

  # --- risk-calc arithmetic ------------------------------------------------
  # phase-2b.md: CRITICAL = High x Critical -> Priority 1
  #              HIGH     = High x High, OR Medium x Critical -> Priority 2
  $rc = [regex]::Match($desc, '\[Risk calc:\s*(Very Low|Low|Medium|High|Critical)\s*likelihood\s*x\s*(Low|Medium|High|Critical)\s*impact\s*\]', 'IgnoreCase')
  if (-not $rc.Success) {
    if ($desc.Contains('[Risk calc:')) { Add-V $id "[Risk calc: ...] is present but not in the form '<Likelihood> likelihood x <Impact> impact'" }
  } else {
    $rcL = (Get-Culture).TextInfo.ToTitleCase($rc.Groups[1].Value.ToLower())
    $rcI = (Get-Culture).TextInfo.ToTitleCase($rc.Groups[2].Value.ToLower())

    if ($rcL -ne $r['Likelihood']) {
      Add-V $id "Likelihood column says '$($r['Likelihood'])' but its own [Risk calc:] note says '$rcL'"
    }

    $outcome = 'NOT-ADMISSIBLE'
    if     ($rcL -eq 'High'   -and $rcI -eq 'Critical') { $outcome = 'Priority 1' }
    elseif ($rcL -eq 'High'   -and $rcI -eq 'High')     { $outcome = 'Priority 2' }
    elseif ($rcL -eq 'Medium' -and $rcI -eq 'Critical') { $outcome = 'Priority 2' }

    if ($outcome -eq 'NOT-ADMISSIBLE') {
      Add-V $id "[Risk calc: $rcL likelihood x $rcI impact] yields neither CRITICAL nor HIGH, so this row does not clear the inclusion gate and does not belong in the main table"
    } elseif ($outcome -ne $r['Priority']) {
      Add-V $id "Priority is '$($r['Priority'])' but $rcL x $rcI computes to $outcome"
    }

    # Critical impact requires a Crown Jewel or Sensitive target (phase-2b.md Impact test).
    if ($rcI -eq 'Critical' -and $assetM.Success -and $assetM.Groups[2].Value -eq 'Supporting') {
      Add-V $id "Impact is Critical but the target $($assetM.Groups[1].Value) is tier Supporting -- a threat against a Supporting asset caps at High however broad the gain"
    }
  }

  # --- asset tier must match 02a-context.md --------------------------------
  if ($assetM.Success -and $assetTier.Count -gt 0) {
    $asId = $assetM.Groups[1].Value; $asTier = $assetM.Groups[2].Value
    if (-not $assetTier.ContainsKey($asId)) {
      Add-V $id "Asset $asId does not appear in 02a-context.md"
    } elseif ($assetTier[$asId] -ne $asTier) {
      Add-V $id "Asset $asId is tier '$asTier' here but '$($assetTier[$asId])' in 02a-context.md -- the tier is carried across, never re-judged"
    }
  }
}

# ---------------------------------------------------------------------------
# REPORT
# ---------------------------------------------------------------------------
""
"CHECK-THREATS -- 02b-threats.md"
"  rows parsed          : $($rows.Count)"
"  assets read from 02a : $($assetTier.Count)"
if ($assetTier.Count -eq 0) {
  "  NOTE: 02a-context.md was not found or held no AS-NNN tiers, so the asset-tier"
  "        cross-check DID NOT RUN. The other checks did."
}
"  violations           : $($V.Count)"
""

if ($V.Count -gt 0) {
  "VIOLATIONS"
  foreach ($g in ($V | Group-Object Id | Sort-Object Name)) {
    "  $($g.Name)"
    $g.Group | ForEach-Object { "    - $($_.What)" }
  }
  ""
  "These are RULE violations, not opinions -- each one is decidable from the row itself or from"
  "02a-context.md. Fix them in 02b-threats.md before GATE 3, so the reviewer spends the walk on"
  "judgement instead of on bookkeeping. Re-run this check after fixing."
  exit 1
}

"CHECK OK -- no mechanical rule violations in $($rows.Count) rows."
"(This says nothing about whether the threats are REAL. That is GATE 3's job.)"
exit 0
