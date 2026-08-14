# skills/code-security-audit/install.ps1
# SKILL VERSION: v2-skill (2026-08-14a) -- installer
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

# Extract just the stamp, not the whole header line -- the header is a paragraph and
# printing it in full makes every install look like an error dump.
$stamp = (Get-Content (Join-Path $Target "SKILL.md") -TotalCount 5 |
  Select-String -Pattern 'SKILL VERSION: (\S+ \([^)]*\))' | ForEach-Object { $_.Matches[0].Groups[1].Value })
if ($stamp) { "SKILL VERSION: $stamp" } else { Write-Warning "No SKILL VERSION stamp found in SKILL.md" }
"Installed code-security-audit to $Target"
"Files: $((Get-ChildItem -Recurse -File $Target | Measure-Object).Count)"
