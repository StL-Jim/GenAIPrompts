# skills/code-security-audit/install.ps1
# SKILL VERSION: v1-skill (2026-07-29a) -- installer
param([string]$Target = (Join-Path $HOME ".claude\skills\code-security-audit"))
$src = $PSScriptRoot

if (-not (Test-Path (Join-Path $src "SKILL.md"))) {
  Write-Error "Source does not look like the skill (no SKILL.md in $src)."
  exit 1
}
if ((Split-Path $Target -Leaf) -ne "code-security-audit") {
  Write-Error "Refusing: target must end in 'code-security-audit' (got '$Target')."
  exit 1
}

if (Test-Path $Target) { Remove-Item -Recurse -Force $Target }
New-Item -ItemType Directory -Force $Target | Out-Null
Copy-Item -Recurse -Force "$src\*" $Target

Get-Content (Join-Path $Target "SKILL.md") -TotalCount 5 | Select-String "SKILL VERSION"
"Installed code-security-audit to $Target"
"Files: $((Get-ChildItem -Recurse -File $Target | Measure-Object).Count)"
