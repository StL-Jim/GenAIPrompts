# SKILL VERSION: v1-skill (2026-07-30a)
# tests/code-security-audit/make-fixture.ps1
#
# Builds a throwaway repository for exercising the code-security-audit skill's scripts.
#
#   pwsh -File tests/code-security-audit/make-fixture.ps1 -Path <dir> [-Mode COORDINATED]
#
# Shape is chosen to exercise the specific things that have broken or could break:
#   - a monorepo with MORE service roots than the 5-partition cap, so the cap and the
#     'assorted' merge path are hit rather than skipped
#   - node_modules and a vendored dir, which must NOT reach the manifest
#   - security_architecture_audit.md at the ROOT, which must survive init untouched
#   - audit_state-YYYYMMDD, which must be detected presence-only and never read
#   - a real git repo, so the .git/info/exclude path actually runs
#   - in COORDINATED mode, a threat model with a main table AND an Excluded Threats
#     Ledger carrying the three reason values the cross-reference procedure branches on
param(
  [Parameter(Mandatory=$true)][string]$Path,
  [ValidateSet('STANDALONE','COORDINATED')][string]$Mode = 'STANDALONE',
  [switch]$Force
)

$ErrorActionPreference = 'Stop'

if (Test-Path -LiteralPath $Path) {
  if (-not $Force) { Write-Error "Fixture path already exists: $Path. Pass -Force to replace it."; exit 1 }
  Remove-Item -Recurse -Force -LiteralPath $Path
}
New-Item -ItemType Directory -Force -Path $Path | Out-Null
$Path = (Resolve-Path -LiteralPath $Path).Path.TrimEnd('\')
$proj = Split-Path -Leaf $Path

function Put([string]$rel, [string[]]$lines) {
  $full = Join-Path $Path $rel
  $dir = Split-Path -Parent $full
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  Set-Content -LiteralPath $full -Value $lines -Encoding ASCII
}

# --- services: 7 roots, deliberately more than the cap of 5 ------------------
Put 'services/auth/src/login.py' @(
  'import hashlib'
  'def check(user, pw):'
  '    # weak digest, no salt'
  '    return hashlib.md5(pw.encode()).hexdigest() == user.pw_hash'
)
Put 'services/auth/src/session.py' @(
  'SESSION_TTL = 60 * 60 * 24 * 30'
  'def issue(uid):'
  '    return {"uid": uid, "sig": None}   # unsigned session token'
)
Put 'services/auth/src/users.py' @(
  'def get_user(request, uid):'
  '    # no authorization check on uid'
  '    return db.query("SELECT * FROM users WHERE id = " + uid)'
)
Put 'services/payments/src/charge.py' @(
  'def charge(card, amount):'
  '    log.info("charging card %s", card)   # PAN written to logs'
  '    return gateway.post(card, amount)'
)
Put 'services/payments/src/refund.py' @(
  'def refund(txn_id, amount):'
  '    return gateway.refund(txn_id, amount)'
)
Put 'services/notify/src/mailer.py' @(
  'SMTP_PASSWORD = "hunter2"   # hardcoded credential'
  'def send(to, body): pass'
)
Put 'services/reports/src/export.py' @('def export(q): return db.raw(q)')
Put 'services/billing/src/invoice.py' @('def invoice(acct): return acct.total')
Put 'services/search/src/index.py' @('def reindex(): pass')

# --- shared library, flagged by name convention as a 3B/4B candidate --------
Put 'shared/lib/crypto.py' @(
  'def encrypt(data, key):'
  '    # ECB mode, no IV'
  '    return aes_ecb(data, key)'
)
Put 'shared/lib/db.py'    @('def query(sql): return conn.execute(sql)')
Put 'shared/lib/http.py'  @('def get(url): return requests.get(url, verify=False)')

# --- frontend ---------------------------------------------------------------
Put 'frontend/src/app.js'   @('export const API = "https://api.example.internal";')
Put 'frontend/src/admin.js' @('export function isAdmin(u) { return u.role === "admin"; }')

# --- docs and root ----------------------------------------------------------
Put 'docs/architecture.md' @('# Architecture', '', 'auth -> shared/lib -> payments')
Put 'README.md'            @("# $proj", '', 'Fixture repository for audit skill tests.')
Put 'Dockerfile'           @('FROM python:3.11', 'USER root')

# --- MUST BE EXCLUDED from the manifest -------------------------------------
Put 'node_modules/left-pad/index.js' @('module.exports = function(){};')
Put 'vendor/thirdparty/lib.py'       @('def vendored(): pass')
Put 'security_architecture_audit.md' @(
  '# Security Architecture Audit Log'
  ''
  'CROSS-RUN LOG SENTINEL -- this content must survive init-workspace.'
  ''
  '## Run 2026-01-15'
  '- prior finding: F-004 hardcoded credential in notify'
)
Put 'audit_state-20260101/STATE.md' @('# Audit STATE', 'PRIOR RUN -- MUST NOT BE READ')
Put 'audit_state-20260101/findings_registry.md' @('id: F-999', 'title: stale finding from a prior run')

# --- COORDINATED mode: a threat model to cross-reference against ------------
if ($Mode -eq 'COORDINATED') {
  Put "$proj-threat-model/STATE.md" @(
    '# Threat Model Run State'
    "PROJECT_NAME: $proj"
    'LAST_UPDATED: 2026-07-01T09:00'
  )
  Put "$proj-threat-model/02-threats.md" @(
    '# Threats'
    ''
    '## Main Threat Table'
    ''
    '| ThreatID | Component | Category | OWASP | Title |'
    '|---|---|---|---|---|'
    '| 01 | C-001 auth-service | Spoofing | A07:2021 | Session token replay due to absent token binding |'
    '| 02 | C-002 payments-service | Information Disclosure | A09:2021 | Cardholder data exposed in application logs |'
    '| 03 | C-003 shared-crypto | Information Disclosure | A02:2021 | Weak cipher mode in shared crypto helper |'
    ''
    '## Excluded Threats Ledger'
    ''
    '| ID | Component | Category | Reason | Detail |'
    '|---|---|---|---|---|'
    '| EX-001 | C-001 auth-service | Spoofing | Code-level | Password hashing algorithm strength -- routed to the code audit |'
    '| EX-002 | C-004 notify-service | Information Disclosure | Attested-mitigated (unverified) | Owner attests SMTP credentials come from vault, not source |'
    '| EX-003 | C-005 frontend | Elevation of Privilege | Fully mitigated | Admin checks enforced server-side |'
    '| EX-004 | C-006 reports-service | Tampering | Unverified | Possible raw query passthrough; could not be grounded in the System Map |'
  )
}

# --- make it a real git repo so the exclude path is exercised ---------------
Push-Location $Path
try {
  & git init -q 2>$null | Out-Null
  & git -c user.email=fixture@test -c user.name=fixture add -A 2>$null | Out-Null
  & git -c user.email=fixture@test -c user.name=fixture commit -q -m 'fixture' 2>$null | Out-Null
} catch {
  Write-Warning "git init failed; the exclude-effectiveness check will be skipped by init-workspace (which is itself a tested path)."
} finally { Pop-Location }

$fileCount = (Get-ChildItem -Recurse -File -Force -LiteralPath $Path | Where-Object { $_.FullName -notmatch '\\\.git\\' }).Count
"Fixture created: $Path"
"  MODE          : $Mode"
"  PROJECT_NAME  : $proj"
"  files (non-git): $fileCount"
"  git repo      : $(if (Test-Path (Join-Path $Path '.git')) { 'yes' } else { 'no' })"
