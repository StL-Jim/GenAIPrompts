# SKILL VERSION: v25-skill (2026-07-23a)
# tests/stride-threat-model/test-scripts.ps1
#
# Regression suite for the stride-threat-model skill's DETERMINISTIC scripts. Generates
# the fixture, runs manifest/partition/sweep/validate-drawio/concat, and asserts expected
# behavior (inclusions, exclusions, reconciliation, scale handling). Exit code 0 = all pass.
# This is the layer where the field-reported Phase 0 hang lived; run it after any script change.
param(
  [string]$FixturePath = (Join-Path $env:TEMP 'stm-fixture'),
  [string]$SkillDir    = (Resolve-Path (Join-Path $PSScriptRoot '..\..\skills\stride-threat-model')).Path
)

$ErrorActionPreference = 'Stop'
$scripts = Join-Path $SkillDir 'scripts'
$proj = Split-Path $FixturePath -Leaf
$out  = Join-Path $FixturePath "$proj-threat-model"
$pass = 0; $fail = 0
function Check([string]$name, $cond, [string]$detail='') {
  # $cond may be a real bool, or an array (PowerShell's `$array -match 'x'` returns the
  # matching lines, not a bool). Coerce: bool as-is; null=false; array=true if any truthy.
  if ($cond -is [bool])      { $ok = $cond }
  elseif ($null -eq $cond)   { $ok = $false }
  else                       { $ok = (@($cond | Where-Object { $_ }).Count -gt 0) }
  if ($ok) { "  PASS  $name"; $script:pass++ }
  else     { "  FAIL  $name  $detail"; $script:fail++ }
}

"=== building fixture (with archive) ==="
& (Join-Path $PSScriptRoot 'make-fixture.ps1') -Path $FixturePath -WithArchive

"=== manifest ==="
$mOut = & (Join-Path $scripts 'manifest.ps1') -Workspace $FixturePath -ProjectName $proj
$mOut
$manifest = Get-Content (Join-Path $out '00-file-manifest.txt')
Check 'manifest excludes audit_state'          (-not ($manifest -match '^audit_state/'))
Check 'manifest excludes security_architecture_audit.md' (-not ($manifest -contains 'security_architecture_audit.md'))
Check 'manifest excludes node_modules'         (-not ($manifest -match 'node_modules'))
Check 'manifest excludes vendor'               (-not ($manifest -match '^vendor/'))
Check 'manifest excludes archived TM run'      (-not ($manifest -match 'threat-model-20260101'))
Check 'manifest INCLUDES real source'          ($manifest -contains 'services/api/main.py')
Check 'manifest INCLUDES terraform'            ($manifest -contains 'terraform/s3.tf')
Check 'manifest KEEPS seed.sql (accounting)'   ($manifest -contains 'data/seed.sql')
Check 'manifest KEEPS bigdata.js (accounting)' ($manifest -contains 'services/web/bigdata.js')
Check 'manifest KEEPS no-ext Makefile'         ($manifest -contains 'Makefile')
Check 'manifest KEEPS space-path file'         ($manifest -match 'admin tools/report gen.py')

"=== partition ==="
$pOut = & (Join-Path $scripts 'partition-manifest.ps1') -Workspace $FixturePath -ProjectName $proj
$pOut
Check 'partition reconciles to manifest total' (($pOut -join ' ') -match 'match:\s*yes')
$docs = Get-Content (Join-Path $out '00-manifest-docs.txt')
$iac  = Get-Content (Join-Path $out '00-manifest-iac.txt')
Check 'README in docs partition'   ($docs -contains 'README.md')
Check 'terraform in iac partition' ($iac  -contains 'terraform/s3.tf')
Check 'main.py NOT in docs/iac (=> rest)' ((-not ($docs -contains 'services/api/main.py')) -and (-not ($iac -contains 'services/api/main.py')))

"=== sweep ==="
$swOut = & (Join-Path $scripts 'sweep.ps1') -Workspace $FixturePath -ProjectName $proj
$swOut
$scope = ($swOut | Where-Object { $_ -match '^Sweep scope:' })
Check 'sweep reports scope line'        ($scope)
Check 'sweep skipped >=2 by extension'  ($scope -match 'skipped ([2-9]|\d\d+) by extension')
Check 'sweep skipped >=1 by size'       ($scope -match '([1-9]\d*) over \d+KB')
Check 'sweep skipped generated/minified' ($scope -match '([1-9]\d*) generated/minified')
$cand = Get-Content (Join-Path $out '00-candidates.txt')
Check 'candidates include DATA_BUCKET'  ($cand -contains 'DATA_BUCKET')
Check 'candidates include DB_HOST'      ($cand -contains 'DB_HOST')
Check 'candidates include AUTH_SECRET'  ($cand -contains 'AUTH_SECRET')
Check 'candidates include a real host'  (($cand -join ' ') -match 'sec\.gov|sendgrid|redis://')
Check 'candidates EXCLUDE vendored token' (-not (($cand -join ' ') -match 'should-not-appear'))
$raw = Get-Content (Join-Path $out '00-discovery-raw.txt')
Check 'raw excludes seed.sql (not scanned)' (-not ($raw -match 'seed\.sql'))
Check 'raw excludes bigdata.js (size)'      (-not ($raw -match 'bigdata\.js'))
Check 'raw includes real source'            (($raw -join ' ') -match 'main\.py')

"=== validate-drawio ==="
$dg = Join-Path $out 'diagrams'
if (-not (Test-Path $dg)) { New-Item -ItemType Directory -Force $dg | Out-Null }
@'
<mxfile host="app.diagrams.net" compressed="false"><diagram id="d" name="d"><mxGraphModel><root><mxCell id="0"/><mxCell id="1" parent="0"/><mxCell id="a" vertex="1" parent="1"><mxGeometry x="0" y="0" width="80" height="40" as="geometry"/></mxCell><mxCell id="b" vertex="1" parent="1"><mxGeometry x="120" y="0" width="80" height="40" as="geometry"/></mxCell><mxCell id="e" edge="1" source="a" target="b" parent="1"><mxGeometry relative="1" as="geometry"/></mxCell></root></mxGraphModel></diagram></mxfile>
'@ | Set-Content (Join-Path $dg 'good.drawio') -Encoding ASCII
@'
<mxfile host="app.diagrams.net" compressed="false"><diagram id="d" name="d"><mxGraphModel><root><mxCell id="0"/><mxCell id="1" parent="0"/><mxCell id="e" edge="1" source="a" target="MISSING" parent="1"><mxGeometry relative="1" as="geometry"/></mxCell></root></mxGraphModel></diagram></mxfile>
'@ | Set-Content (Join-Path $dg 'bad.drawio') -Encoding ASCII
$vOut = & (Join-Path $scripts 'validate-drawio.ps1') -Workspace $FixturePath -ProjectName $proj
$vOut
Check 'validate: good.drawio parses, 0 bad refs' (($vOut | Where-Object { $_ -match 'good.drawio' }) -match 'bad edge refs 0')
Check 'validate: bad.drawio flagged bad ref'     (($vOut | Where-Object { $_ -match 'bad.drawio'  }) -match 'bad edge refs [1-9]')

"=== concat ==="
$tmp = Join-Path $env:TEMP 'stm-concat-test.md'
& (Join-Path $scripts 'concat-monolith.ps1') -OutFile $tmp | Out-Null
Check 'concat produced non-empty output' ((Test-Path $tmp) -and ((Get-Item $tmp).Length -gt 10000))
if (Test-Path $tmp) { Remove-Item $tmp }

"=== degenerate inputs (graceful failure, not silent-wrong) ==="
$deg = Join-Path $env:TEMP 'stm-degenerate'
if (Test-Path $deg) { Remove-Item -Recurse -Force -LiteralPath $deg }
New-Item -ItemType Directory -Force (Join-Path $deg 'stm-degenerate-threat-model\diagrams') | Out-Null
Set-Content (Join-Path $deg 'x.py') 'x=1' -Encoding ASCII
# sweep/partition BEFORE manifest exists -> must fail clearly (Write-Error + exit 1), not
# report false success. These scripts intentionally error; catch it so the suite continues.
$swFailed = $false
try { & (Join-Path $scripts 'sweep.ps1') -Workspace $deg -ProjectName 'stm-degenerate' 2>$null; if ($LASTEXITCODE -ne 0) { $swFailed = $true } } catch { $swFailed = $true }
Check 'sweep fails clearly when manifest missing' $swFailed
$ptFailed = $false
try { & (Join-Path $scripts 'partition-manifest.ps1') -Workspace $deg -ProjectName 'stm-degenerate' 2>$null; if ($LASTEXITCODE -ne 0) { $ptFailed = $true } } catch { $ptFailed = $true }
Check 'partition fails clearly when manifest missing' $ptFailed
# validate-drawio with an empty diagrams dir -> clear message, no crash
$vEmpty = & (Join-Path $scripts 'validate-drawio.ps1') -Workspace $deg -ProjectName 'stm-degenerate' 2>&1
Check 'validate-drawio reports empty diagrams dir' (($vEmpty -join ' ') -match 'No .drawio files found')
# empty repo -> manifest count 0, no crash
$empty = Join-Path $deg 'sub-empty'; New-Item -ItemType Directory -Force $empty | Out-Null
$emOut = & (Join-Path $scripts 'manifest.ps1') -Workspace $empty -ProjectName 'sub-empty' 2>&1
Check 'manifest handles empty repo (count 0)' (($emOut -join ' ') -match 'Manifest file count: 0')
Remove-Item -Recurse -Force -LiteralPath $deg

"`n=== RESULT: $pass passed, $fail failed ==="
Remove-Item -Recurse -Force -LiteralPath $FixturePath
if ($fail -gt 0) { exit 1 } else { exit 0 }
