# SKILL VERSION: v25-skill (2026-07-24l)
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
  [switch]$Verify,            # compare 00-files-read.txt against the read set and report gaps
  [int]$BulkClassThreshold = 40   # a class larger than this is signal-filtered (see below)
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

# APP-SOURCE is the catch-all for ordinary application code -- business logic, services,
# models, repositories, controllers -- that matches none of the named roles above. Without
# it the body of the codebase is in NO class and therefore in no accounting, which is
# exactly how a source-file count went missing from a field report.
$reCode = '\.(cs|vb|fs|py|rb|php|java|kt|kts|scala|go|rs|swift|m|mm|c|h|cpp|hpp|cc|js|mjs|cjs|ts|pl|pm|lua|ex|exs|erl|clj|groovy|dart|sh|ps1|psm1|sql?)$'

function Get-Class([string]$p) {
  if ($p -match $reDocs)     { return 'docs' }
  if ($p -match $reViewExt)  { return 'client-view' }
  if ($p -match $reEntry)    { return 'entrypoint' }
  if ($p -match $reConf)     { return 'config-env' }
  if ($p -match $reAuth)     { return 'auth' }
  if ($p -match $reClient)   { return 'ext-client' }
  if ($p -match $reViewPath) { return 'client-view' }
  if ($p -match $reCode)     { return 'app-source' }
  return $null   # non-code, non-doc (data, assets, binaries) -- outside the read set
}

$classes = @('entrypoint','config-env','auth','ext-client','app-source','client-view','docs')
$set = foreach ($p in $manifest) { $c = Get-Class $p; if ($c) { [PSCustomObject]@{ Class = $c; Path = $p } } }
$set = @($set)

# SIGNAL FILTERING for high-cardinality classes. A floor of hundreds of files is not a
# floor -- it is unmeetable, so it gets discarded wholesale and the whole mechanism is
# lost (field: a 464-file floor produced 21 files read and a hand-written "adequate").
# For any class above the threshold, the floor keeps only the files that actually carry an
# EXTERNAL-REFERENCE signal; the rest are deferred with a MECHANICAL reason, not a
# judgment call, so nothing is silently dropped and the totals still reconcile. Small,
# high-value classes are never filtered -- an entry point or a config file matters whether
# or not it contains a URL.
$neverFilter = @('entrypoint','config-env','auth','ext-client','docs')
$signalRe = '://|<script[^>]+src=|<iframe[^>]+src=|<embed[^>]+src=|fetch\(|axios|XMLHttpRequest|\.ajax\(|integrity=|HttpClient|WebClient|RestClient|RestSharp|new \w+Client|createClient|connectionString|getenv|environ\[|process\.env|ConfigurationManager|IConfiguration|AppSettings|arn:aws|_URL|_URI|_HOST|_ENDPOINT|_ADDR|_BUCKET|_TABLE|_QUEUE|_TOPIC'
$deferred = @()
foreach ($c in $classes) {
  if ($neverFilter -contains $c) { continue }
  $inClass = @($set | Where-Object { $_.Class -eq $c })
  if ($inClass.Count -le $BulkClassThreshold) { continue }
  foreach ($item in $inClass) {
    $full = Join-Path $WORKSPACE ($item.Path -replace '/','\')
    $hit = $false
    if (Test-Path -LiteralPath $full) {
      try { $hit = [bool](Select-String -LiteralPath $full -Pattern $signalRe -List -ErrorAction SilentlyContinue) } catch { $hit = $true }
    } else { $hit = $true }   # cannot check -> keep it in the floor (err toward reading)
    if (-not $hit) { $deferred += [PSCustomObject]@{ Class = $c; Path = $item.Path } }
  }
}
$deferredPaths = @{}
foreach ($d in $deferred) { $deferredPaths[$d.Path] = $true }
$setAll = $set
$set = @($set | Where-Object { -not $deferredPaths[$_.Path] })

if (-not $Verify) {
  $set | Sort-Object Class, Path | ForEach-Object { "$($_.Class)`t$($_.Path)" } |
    Set-Content "$out\00-readset.txt" -Encoding ASCII
  if ($deferred.Count -gt 0) {
    $deferred | Sort-Object Class, Path | ForEach-Object { "$($_.Class)`t$($_.Path)" } |
      Set-Content "$out\00-readset-deferred.txt" -Encoding ASCII
  }
  "MANDATORY READ SET written to 00-readset.txt -- every file listed is read IN FULL."
  "  {0,-12} {1,8} {2,9} {3,9}" -f 'class','in class','IN FLOOR','deferred'
  foreach ($c in $classes) {
    $tot = @($setAll   | Where-Object { $_.Class -eq $c }).Count
    $flo = @($set      | Where-Object { $_.Class -eq $c }).Count
    $def = @($deferred | Where-Object { $_.Class -eq $c }).Count
    $note = if ($def -gt 0) { '  (signal-filtered)' } else { '' }
    "  {0,-12} {1,8} {2,9} {3,9}{4}" -f $c, $tot, $flo, $def, $note
  }
  "  {0,-12} {1,8} {2,9} {3,9}" -f 'TOTAL', $setAll.Count, $set.Count, $deferred.Count
  "Manifest total: $($manifest.Count) | mandatory read set (READ ALL OF THESE): $($set.Count)"
  if ($deferred.Count -gt 0) {
    "Deferred: $($deferred.Count) files in high-cardinality classes carry NO external-reference signal (listed in 00-readset-deferred.txt). They are accounted for, not dropped -- read any the sweep or your investigation later flags."
  }
  ""
  "NEXT: as you read, append EVERY file you read to 00-files-read.txt (one relative path per line)."
  "      That file is the record of what was reviewed -- without it nothing can be verified."
  "      Then run this script with -Verify. Do not hand-write a coverage summary."
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
$stamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
"  TOTAL UNREAD IN MANDATORY SET: $totalMissing"
"  [readset.ps1 $stamp | read-set $($set.Count) files | read-log $($readList.Count) entries]"
if ($totalMissing -gt 0) {
  "VERDICT: INCOMPLETE -- $totalMissing of $($set.Count) mandatory files unread. Read the files named above, append them to 00-files-read.txt, and re-run. Do not proceed to scope on this."
  exit 1
}
"VERDICT: COMPLETE -- all $($set.Count) files in the mandatory read set appear in the read log."
exit 0
