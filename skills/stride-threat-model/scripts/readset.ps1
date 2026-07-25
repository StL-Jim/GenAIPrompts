# SKILL VERSION: v25-skill (2026-07-24g)
# skills/stride-threat-model/scripts/readset.ps1
#
# Computes Phase 0 Pass 1's MANDATORY READ SET from the file manifest, and (in -Verify
# mode) reconciles it against what the agent actually read.
#
# Why this is a script and not prose: a field run read SIX source files and nothing caught
# it, because Pass 1 had no computed denominator -- the agent chose what to read and then
# described what it chose. Enumerating the read set mechanically gives the pass a
# denominator it cannot negotiate with, and -Verify makes the "did you read it" number
# TOOL-COMPUTED rather than recalled (common.md Rule 15: numbers are computed, never
# recalled -- a recalled number is indistinguishable from a fabricated one).
#
# Classes are matched by ROLE via path/filename, deliberately framework-agnostic. The
# match is heuristic and errs toward INCLUSION: a file wrongly included costs one read,
# a file wrongly excluded costs a missed integration.
param(
  [Parameter(Mandatory=$true)][string]$Workspace,
  [Parameter(Mandatory=$true)][string]$ProjectName,
  [switch]$Verify    # compare 00-files-read.txt against the read set and report gaps
)

$WORKSPACE    = $Workspace.TrimEnd('\')
$PROJECT_NAME = $ProjectName
$out = "$WORKSPACE\$PROJECT_NAME-threat-model"
$manifestFile = "$out\00-file-manifest.txt"
if (-not (Test-Path $manifestFile)) {
  Write-Error "00-file-manifest.txt not found at $manifestFile -- run manifest.ps1 first. Not computing the read set."
  exit 1
}
$manifest = @(Get-Content $manifestFile | Where-Object { $_ })

# --- class matchers (first match wins; a file belongs to one class for accounting) ---
$reDocs  = '(^|/)(README|ARCHITECTURE|DESIGN|SECURITY|THREAT|CONTRIBUTING|CHANGELOG)[^/]*$|\.(md|rst|adoc)$|(^|/)(docs?|documentation)/'
$reEntry = '(^|/)(main|app|index|server|program|startup|wsgi|asgi|manage|bootstrap|entrypoint)\.[a-z]+$|(^|/)(handler|lambda_function|function_app)\.[a-z]+$|(^|/)(worker|consumer|listener|subscriber|scheduler|cron|job|jobs|tasks|cli|cmd|commands)([/.]|$)'
$reConf  = '(^|/)\.env|(^|/)appsettings[^/]*\.json$|(^|/)(config|configs|settings|conf)([/.]|$)|values[^/]*\.ya?ml$|(^|/)kustomization\.ya?ml$|(^|/)overlays?/|\.tfvars$|(^|/)(configmap|secret)[^/]*\.ya?ml$|(^|/)(web|app)\.config$|\.properties$|(^|/)\.github/workflows/'
$reAuth  = '(auth|oauth|oidc|saml|sso|login|signin|token|jwt|session|identity|principal|permission|policy|policies|guard|middleware|rbac|claims)'
$reClient= '(client|gateway|adapter|connector|integration|integrations|webhook|proxy|outbound|external|thirdparty|third_party|sdk)'
# View matching is split: an unambiguous VIEW EXTENSION wins over every other class (an
# `Index.cshtml` is a view, not an entry point -- extension-first stops that misfile),
# while the weaker PATH-based view match runs last so a server file under a `client/` or
# `web/` directory still classifies by its stronger role first.
$reViewExt  = '\.(jsx|tsx|vue|svelte|cshtml|razor|erb|hbs|mustache|ejs|pug|jade|twig|j2|jinja2?)$|\.blade\.php$|\.html?$'
$reViewPath = '(^|/)(views?|templates?|pages|components|screens|wwwroot|public|static|assets|frontend|ui)/'

function Get-Class([string]$p) {
  if ($p -match $reDocs)     { return 'docs' }
  if ($p -match $reViewExt)  { return 'client-view' }
  if ($p -match $reEntry)    { return 'entrypoint' }
  if ($p -match $reConf)     { return 'config-env' }
  if ($p -match $reAuth)     { return 'auth' }
  if ($p -match $reClient)   { return 'ext-client' }
  if ($p -match $reViewPath) { return 'client-view' }
  return $null   # not in the mandatory floor; still reachable via investigation/density
}

$classes = @('entrypoint','config-env','auth','ext-client','client-view','docs')
$set = foreach ($p in $manifest) { $c = Get-Class $p; if ($c) { [PSCustomObject]@{ Class = $c; Path = $p } } }
$set = @($set)

if (-not $Verify) {
  $set | Sort-Object Class, Path | ForEach-Object { "$($_.Class)`t$($_.Path)" } |
    Set-Content "$out\00-readset.txt" -Encoding ASCII
  "MANDATORY READ SET written to 00-readset.txt -- every file listed is read IN FULL."
  foreach ($c in $classes) {
    $n = @($set | Where-Object { $_.Class -eq $c }).Count
    "  {0,-12} {1,5}" -f $c, $n
  }
  "  {0,-12} {1,5}" -f 'TOTAL', $set.Count
  "Manifest total: $($manifest.Count) | in mandatory read set: $($set.Count) | reachable by investigation/density: $($manifest.Count - $set.Count)"
  "After reading, record every file you read (one relative path per line) in 00-files-read.txt, then re-run this script with -Verify."
  exit 0
}

# --- Verify mode: tool-computed reconciliation ---
$readFile = "$out\00-files-read.txt"
if (-not (Test-Path $readFile)) {
  Write-Error "00-files-read.txt not found at $readFile -- write the list of files you actually read (one relative path per line) before verifying."
  exit 1
}
$readList = @(Get-Content $readFile | Where-Object { $_ } | ForEach-Object { $_.Trim().Replace('\','/') })
$readSetLower = @{}
foreach ($r in $readList) { $readSetLower[$r.ToLower()] = $true }

"PASS 1 READ-SET RECONCILIATION (tool-computed):"
$totalMissing = 0
foreach ($c in $classes) {
  $files   = @($set | Where-Object { $_.Class -eq $c } | Select-Object -ExpandProperty Path)
  $missing = @($files | Where-Object { -not $readSetLower[$_.ToLower()] })
  $totalMissing += $missing.Count
  $flag = if ($missing.Count -eq 0) { 'OK' } else { 'UNREAD' }
  "  {0,-12} enumerated {1,5} | read {2,5} | unread {3,5}  {4}" -f $c, $files.Count, ($files.Count - $missing.Count), $missing.Count, $flag
  if ($missing.Count -gt 0) { $missing | Select-Object -First 25 | ForEach-Object { "        UNREAD: $_" } }
  if ($missing.Count -gt 25) { "        ... and $($missing.Count - 25) more" }
}
"  TOTAL UNREAD IN MANDATORY SET: $totalMissing"
if ($totalMissing -gt 0) {
  "VERDICT: INCOMPLETE -- the files listed above are in the mandatory read set and were not read. Read them, append them to 00-files-read.txt, and re-run. Do not proceed to scope on this."
  exit 1
}
"VERDICT: COMPLETE -- every file in the mandatory read set was read."
exit 0
