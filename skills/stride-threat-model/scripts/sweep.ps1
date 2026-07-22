# SKILL VERSION: v25-skill (2026-07-21a)
# skills/stride-threat-model/scripts/sweep.ps1
param(
  [Parameter(Mandatory=$true)][string]$Workspace,
  [Parameter(Mandatory=$true)][string]$ProjectName
)

$WORKSPACE = $Workspace.TrimEnd('\')
$PROJECT_NAME = $ProjectName

$out = "$WORKSPACE\$PROJECT_NAME-threat-model"
if (-not (Test-Path $out)) { New-Item -ItemType Directory -Force $out | Out-Null }

# Nine mechanical-sweep patterns (Phase 0 Pass 2), copied verbatim from the monolith.
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

# Materialize "<all manifest files>": paths from 00-file-manifest.txt, prepended with
# $WORKSPACE, minus the binary-extension skip list (png|jpg|gif|ico|pdf|zip|jar|gz|exe|dll|so|woff|ttf|mp4).
$binaryExt = @('png','jpg','gif','ico','pdf','zip','jar','gz','exe','dll','so','woff','ttf','mp4')
$manifestPaths = Get-Content "$out\00-file-manifest.txt"
$sweepFiles = $manifestPaths | Where-Object {
  $ext = [System.IO.Path]::GetExtension($_).TrimStart('.').ToLowerInvariant()
  -not ($binaryExt -contains $ext)
} | ForEach-Object { Join-Path $WORKSPACE ($_ -replace '/','\') }

$all = @()
foreach ($p in $patterns) {
    $m = Select-String -Path $sweepFiles -Pattern $p
    "pattern ${p}: $($m.Count) matches"       # per-pattern counts, recorded in 00-discovery.md
    $all += $m
}
$all | ForEach-Object { "$($_.Path):$($_.LineNumber): $($_.Line.Trim())" } |
  Sort-Object -Unique | Set-Content "$out\00-discovery-raw.txt"
$all | Group-Object Path | Sort-Object Count -Descending |
  ForEach-Object { "$($_.Count)`t$($_.Name)" } | Set-Content "$out\00-density.txt"
$cand = @()
$cand += $all.Matches.Value
$cand += $all | ForEach-Object { [regex]::Matches($_.Line, '"([^"\s]{3,80})"|''([^''\s]{3,80})''') |
    ForEach-Object { $_.Groups[1].Value + $_.Groups[2].Value } }
$cand += $all | ForEach-Object { [regex]::Matches($_.Line, '[=:]\s*["'']?([A-Za-z0-9][A-Za-z0-9._/-]{2,79})') |
    ForEach-Object { $_.Groups[1].Value } }
$cand = $cand | Where-Object { $_ } | Sort-Object -Unique
$cand | Set-Content "$out\00-candidates.txt"
"Candidates (tool-computed): $($cand.Count)"
