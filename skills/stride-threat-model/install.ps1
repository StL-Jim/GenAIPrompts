# skills/stride-threat-model/install.ps1
# SKILL VERSION: v25-skill (2026-07-21a) -- installer
param([string]$Target = (Join-Path $HOME ".claude\skills\stride-threat-model"))
$src = $PSScriptRoot
if (Test-Path $Target) { Remove-Item -Recurse -Force $Target }
New-Item -ItemType Directory -Force $Target | Out-Null
Copy-Item -Recurse -Force "$src\*" $Target
Get-Content (Join-Path $Target "SKILL.md") -TotalCount 5 | Select-String "SKILL VERSION"
"Installed stride-threat-model to $Target"
