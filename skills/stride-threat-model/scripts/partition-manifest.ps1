# skills/stride-threat-model/scripts/partition-manifest.ps1
# SKILL VERSION: v25-skill (2026-07-21a)
param(
  [Parameter(Mandatory=$true)][string]$Workspace,
  [Parameter(Mandatory=$true)][string]$ProjectName
)

$WORKSPACE = $Workspace.TrimEnd('\')
$PROJECT_NAME = $ProjectName

$out = "$WORKSPACE\$PROJECT_NAME-threat-model"
if (-not (Test-Path $out)) { New-Item -ItemType Directory -Force $out | Out-Null }

$manifest = Get-Content "$out\00-file-manifest.txt"

# Partition rules -- first match wins, docs before iac. Matched against the manifest's
# forward-slash relative paths, case-insensitive (PowerShell -match is CI by default).
$docsExt = @('md','puml','plantuml','mmd','drawio','dsl','c4','proto','graphql','wsdl')
$iacExt = @('tf','tfvars')
$iacFilenames = @('.gitlab-ci.yml','jenkinsfile','azure-pipelines.yml','buildspec.yml')

$docs = @()
$iac = @()
$rest = @()

foreach ($rel in $manifest) {
    $filename = ($rel -split '/')[-1]
    $ext = [System.IO.Path]::GetExtension($rel).TrimStart('.')

    $isDocs = ($rel -match '(^|/)(README|ARCHITECTURE|DESIGN|SECURITY|THREAT)[^/]*$') -or
              ($docsExt -contains $ext) -or
              ($rel -match '(^|/)(docs|doc|documentation|adr)/') -or
              ($rel -match '(^|/)architecture/decisions/') -or
              ($filename -match '^(openapi|swagger)\.')

    $isIac = ($iacExt -contains $ext) -or
             ($filename -match '^(Dockerfile|docker-compose)') -or
             ($rel -match '(^|/)(k8s|manifests|helm|charts)/') -or
             ($rel -match '(^|/)\.github/workflows/') -or
             ($iacFilenames -contains $filename)

    if ($isDocs) {
        $docs += $rel
    } elseif ($isIac) {
        $iac += $rel
    } else {
        $rest += $rel
    }
}

$docs | Set-Content "$out\00-manifest-docs.txt" -Encoding UTF8
$iac  | Set-Content "$out\00-manifest-iac.txt" -Encoding UTF8
$rest | Set-Content "$out\00-manifest-rest.txt" -Encoding UTF8

$total = $docs.Count + $iac.Count + $rest.Count
$manifestTotal = $manifest.Count
if ($total -eq $manifestTotal) { $match = 'yes' } else { $match = 'no' }

"Docs file count: $($docs.Count)"
"IaC file count: $($iac.Count)"
"Rest file count: $($rest.Count)"
"docs+iac+rest = $total  manifest total = $manifestTotal  match: $match"
