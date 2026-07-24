# SKILL VERSION: v25-skill (2026-07-23a)
# skills/stride-threat-model/scripts/sweep.ps1
#
# Phase 0 Pass 2 mechanical sweep. Streams matches (does NOT accumulate every match
# object in memory), skips bulk-data/archive/generated files and oversized files, and
# CAPS candidate extraction on saturated patterns so a repo with tens of thousands of
# matches for a noisy pattern (e.g. '://' or 'postgres') completes instead of hanging.
# True per-pattern counts are always recorded (accounting is preserved); only the
# candidate-name harvest is bounded on a saturated pattern -- the raw and density
# artifacts remain complete, and Pass 1 comprehension is the primary discovery method.
# All three thresholds are tunable via parameters.
param(
  [Parameter(Mandatory=$true)][string]$Workspace,
  [Parameter(Mandatory=$true)][string]$ProjectName,
  [int]$MaxFileKB      = 1024,   # skip scanning any file larger than this (data/generated/minified bundles)
  [int]$SaturationCap  = 2000,   # a pattern with more matches than this is flagged SATURATED
  [int]$CandidateCap   = 1000    # max matched lines per pattern fed into candidate extraction
)

$WORKSPACE    = $Workspace.TrimEnd('\')
$PROJECT_NAME = $ProjectName
$out = "$WORKSPACE\$PROJECT_NAME-threat-model"
if (-not (Test-Path $out)) { New-Item -ItemType Directory -Force $out | Out-Null }

# Nine mechanical-sweep patterns (Phase 0 Pass 2). Language-agnostic; extend per-stack, never shorten.
$patterns = @(
  '://',
  's3|bucket|dynamodb|sqs|sns|kinesis|rds|redis|kafka|rabbitmq|mongo|postgres|mysql|elastic|queue|topic',
  'secret|password|token|api[_-]?key|access[_-]?key|credential',
  '\.client\(|\.connect\(|new \w+Client|createClient|connectionString',
  '_URL|_URI|_HOST|_ENDPOINT|_ADDR|_SERVER|_BROKER|_DSN|_QUEUE|_TOPIC|_BUCKET|_TABLE',
  'arn:aws',
  '\b(\d{1,3}\.){3}\d{1,3}\b',
  '([a-z0-9-]+\.)+(com|net|org|io|cloud|internal|corp|local|gov|mil|edu|us)',
  'getenv|environ\[|process\.env'
)

# Extension skip list -- binary, media, fonts, archives/packages, compiled output, and
# BULK DATA / DUMP formats (.sql etc.) that carry no architecture signal worth the scan
# cost. This is the biggest lever: a single .sql dump produced 46k noise matches in the
# field. Add extensions freely; never remove one that is genuinely data/binary.
$skipExt = @(
  # images / media
  'png','jpg','jpeg','gif','ico','bmp','tif','tiff','webp','svg','mp4','mp3','wav','avi','mov','mkv',
  # fonts
  'woff','woff2','ttf','eot','otf',
  # archives / packages
  'zip','tar','war','ear','gz','tgz','bz2','xz','7z','rar','jar','nupkg','whl','gem','pkg','dmg','iso','msi','deb','rpm',
  # compiled / binary
  'exe','dll','so','dylib','a','lib','o','obj','class','pyc','pyo','pdb','bin','dat','wasm',
  # bulk data / database dumps
  'sql','sqlite','sqlite3','db','mdb','parquet','avro','orc','feather',
  # documents (scanned by Pass 1 if relevant, not by the mechanical sweep)
  'pdf'
)
# Generated / minified / lockfile names skipped regardless of extension.
$skipNameRegex = '(\.min\.(js|css)$)|(-lock\.(json|ya?ml)$)|(^package-lock\.json$)|(^yarn\.lock$)|(^pnpm-lock\.ya?ml$)|(\.map$)|(\.sum$)'

# Build the scan set from the manifest, applying extension / name / size exclusions.
$manifestPaths = Get-Content "$out\00-file-manifest.txt"
$skippedExt = 0; $skippedName = 0; $skippedSize = 0
$sweepFiles = New-Object 'System.Collections.Generic.List[string]'
foreach ($rel in $manifestPaths) {
  if (-not $rel) { continue }
  $ext  = [System.IO.Path]::GetExtension($rel).TrimStart('.').ToLowerInvariant()
  $leaf = [System.IO.Path]::GetFileName($rel)
  if ($skipExt -contains $ext)     { $skippedExt++;  continue }
  if ($leaf -match $skipNameRegex) { $skippedName++; continue }
  $full = Join-Path $WORKSPACE ($rel -replace '/','\')
  if (-not (Test-Path $full)) { continue }
  if ((Get-Item -LiteralPath $full).Length -gt ($MaxFileKB * 1KB)) { $skippedSize++; continue }
  $sweepFiles.Add($full)
}
"Sweep scope: $($sweepFiles.Count) files to scan; skipped $skippedExt by extension, $skippedName generated/minified, $skippedSize over ${MaxFileKB}KB (of $($manifestPaths.Count) manifest files)."
if ($sweepFiles.Count -eq 0) { "No files to scan after exclusions."; return }
$scanArray = $sweepFiles.ToArray()

# Stream each pattern: record true count, add to raw+density, feed candidate extraction
# only up to CandidateCap lines per pattern. Nothing accumulates as heavy MatchInfo objects.
$rawSet  = New-Object 'System.Collections.Generic.HashSet[string]'
$candSet = New-Object 'System.Collections.Generic.HashSet[string]'
$density = @{}
$patternCounts = @()
$sw = [System.Diagnostics.Stopwatch]::StartNew()

foreach ($p in $patterns) {
  $t0 = $sw.Elapsed.TotalSeconds
  $count = 0; $fed = 0
  Select-String -Path $scanArray -Pattern $p -ErrorAction SilentlyContinue | ForEach-Object {
    $count++
    [void]$rawSet.Add("$($_.Path):$($_.LineNumber): $($_.Line.Trim())")
    if ($density.ContainsKey($_.Path)) { $density[$_.Path]++ } else { $density[$_.Path] = 1 }
    if ($fed -lt $CandidateCap) {
      foreach ($mm in $_.Matches) { if ($mm.Value) { [void]$candSet.Add($mm.Value) } }
      foreach ($mm in [regex]::Matches($_.Line, '"([^"\s]{3,80})"|''([^''\s]{3,80})''')) {
        $v = $mm.Groups[1].Value + $mm.Groups[2].Value; if ($v) { [void]$candSet.Add($v) }
      }
      foreach ($mm in [regex]::Matches($_.Line, '[=:]\s*["'']?([A-Za-z0-9][A-Za-z0-9._/-]{2,79})')) {
        $v = $mm.Groups[1].Value; if ($v) { [void]$candSet.Add($v) }
      }
      $fed++
    }
  }
  $elapsed = [int]($sw.Elapsed.TotalSeconds - $t0)
  $sat = ''
  if ($count -gt $SaturationCap) { $sat = " (SATURATED -- candidate extraction capped at first $CandidateCap of $count matches)" }
  $line = "pattern ${p}: $count matches [${elapsed}s]$sat"
  $line                       # progress: one line per pattern, with timing, as it completes
  $patternCounts += $line
}

$rawSet  | Sort-Object | Set-Content "$out\00-discovery-raw.txt" -Encoding ASCII
$density.GetEnumerator() | Sort-Object Value -Descending |
  ForEach-Object { "$($_.Value)`t$($_.Key)" } | Set-Content "$out\00-density.txt" -Encoding ASCII
$candSet | Sort-Object | Set-Content "$out\00-candidates.txt" -Encoding ASCII
"Candidates (tool-computed): $($candSet.Count)"
"Sweep complete in $([int]$sw.Elapsed.TotalSeconds)s (raw match sites: $($rawSet.Count))."
