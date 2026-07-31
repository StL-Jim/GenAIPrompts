# SKILL VERSION: v1-skill (2026-07-31a)
# skills/code-security-audit/scripts/lib-classify.ps1
#
# SHARED file-role classification, dot-sourced by partition-plan.ps1 and readplan.ps1.
#
# It lives in one file because both scripts must agree exactly. partition-plan.ps1 sizes
# partitions by how much auditable SOURCE each service root holds; readplan.ps1 turns that same
# judgement into the per-worker read floor. If the two ever disagreed, partitions would be sized
# against one definition of "source" and verified against another, and the mismatch would look
# like a coverage failure rather than a definition failure.
#
# Matching is by ROLE via path/filename, deliberately framework-agnostic, first match wins, and
# errs toward INCLUSION: a file wrongly included costs one read, a file wrongly excluded costs a
# missed vulnerability.

# Generated, vendored, binary, or build output. Never floored, never counted against coverage.
$script:reSkip = 'package-lock\.json$|yarn\.lock$|pnpm-lock\.ya?ml$|composer\.lock$|Gemfile\.lock$|poetry\.lock$|Cargo\.lock$|packages\.lock\.json$|\.min\.(js|css)$|\.map$|\.(png|jpe?g|gif|ico|svg|webp|bmp|pdf|zip|gz|tgz|7z|rar|jar|war|ear|dll|exe|so|dylib|pdb|class|pyc|woff2?|ttf|eot|otf|mp[34]|mov|avi|bin|dat|db|sqlite3?|parquet|xlsx?|docx?|pptx?|se1)$|(^|/)(dist|build|out|bin|obj|coverage|__snapshots__)/'

# common.md rule 10: dev/QA/test artifacts may be inventoried but do not generate findings.
$script:reTest = '(^|/)(tests?|spec|specs|__tests__|testdata|fixtures?|e2e|cypress|playwright)/|[._-](test|tests|spec)\.[a-z]+$|(^|/)test_[^/]+\.[a-z]+$|[^/]*Tests?\.(cs|java|kt|scala)$'

# Dependency manifests: FLOOR. Few, small, and the only place A06 evidence exists at all.
$script:reDeps = '(^|/)([^/]*\.csproj|[^/]*\.fsproj|[^/]*\.vbproj|packages\.config|package\.json|requirements[^/]*\.txt|pyproject\.toml|Pipfile|pom\.xml|build\.gradle(\.kts)?|go\.mod|Gemfile|composer\.json|Cargo\.toml|mix\.exs|pubspec\.yaml)$'

# Config / CI / IaC: FLOOR. A05 lives here, and deployment facts set every other finding's score.
#
# The Helm alternative matches Chart.yaml, a helm/ directory, or a templates/ directory beneath a
# chart -- NOT a bare charts/ prefix. A bare charts/ was tried first and, on the owner's astrology
# repo, swept 252 astrology chart DATA files into the config class, which bulk filtering then had
# to throw 226 of them back out. A directory name is not a role; the chart's own marker files are.
# The same bug exists in the threat-model skill's readset.ps1 and should be fixed there too.
$script:reConf = '(^|/)\.env|(^|/)appsettings[^/]*\.json$|(^|/)(config|configs|settings|conf)([/._-]|$)|values[^/]*\.ya?ml$|(^|/)kustomization\.ya?ml$|(^|/)overlays?/|\.tf$|\.tfvars$|(^|/)(configmap|secret)[^/]*\.ya?ml$|(^|/)(web|app)\.config$|\.properties$|(^|/)\.github/workflows/|(^|/)\.gitlab-ci\.ya?ml$|(^|/)Jenkinsfile|(^|/)Dockerfile|docker-compose[^/]*\.ya?ml$|(^|/)Chart\.ya?ml$|(^|/)helm/|(^|/)charts?/[^/]+/templates/'

# Docs: NOT floor. The sharpest departure from the threat model's readset.ps1, which floors all
# docs because prose names integrations no pattern can see. This audit is not hunting
# integrations: common.md rule 1 requires a quoted SOURCE line for any Confirmed finding, so a
# README can never be that line.
$script:reDocs = '\.(md|rst|adoc|txt)$|(^|/)(docs?|documentation)/'

$script:reAuthz = '(auth|oauth|oidc|saml|sso|login|signin|signup|token|jwt|session|identity|principal|permission|policy|policies|guard|middleware|rbac|acl|claims|password|credential|crypto|crypt|cipher|hash|kms|vault|secret)'
$script:reEntry = '(^|/)(main|app|index|server|program|startup|wsgi|asgi|manage|bootstrap|entrypoint)\.[a-z]+$|(^|/)(handler|lambda_function|function_app)\.[a-z]+$|(controller|route|router|routes|endpoint|api|handler|resolver|graphql|grpc|servlet|webhook|consumer|listener|subscriber|worker|scheduler|cron|job|jobs|tasks|cli|cmd|command)([/._-]|$)'
$script:reData  = '(repositor|dao|entity|entities|model|schema|query|queries|orm|dbcontext|database|store|storage|persistence|mapper|migration)([/._-]|$)|\.sql$'
$script:reExt   = '(client|gateway|adapter|connector|integration|proxy|outbound|external|thirdparty|third_party|sdk|httpclient|rest|soap|feign)([/._-]|$)'
$script:reCode  = '\.(cs|vb|fs|py|rb|php|java|kt|kts|scala|go|rs|swift|m|mm|c|h|cpp|hpp|cc|js|mjs|cjs|jsx|ts|tsx|vue|svelte|pl|pm|lua|ex|exs|erl|clj|groovy|dart|sh|bash|ps1|psm1|cshtml|razor|erb|hbs|ejs|jinja2?|j2|twig|html?)$'

# DANGEROUS-API PATTERN. What promotes ordinary app-source into the floor. The threat model's
# equivalent asks "could this file name an integration"; this asks "could this file contain an
# exploitable defect". Every alternative maps to an OWASP category the methodology already
# analyses: command/code execution, raw SQL, unescaped output, unsafe deserialization, weak or
# disabled crypto and certificate validation, and path handling from caller-controlled input.
#
# Deliberately NARROWER than "any source file". Every source file could in principle hold a
# defect, and a floor that says so is a floor of hundreds -- the unmeetable floor that got
# discarded wholesale in the field. Quiet source is not dropped; it lands in the deferred list.
$script:sinkRe = 'eval\(|exec\(|execSync|system\(|popen|subprocess|Runtime\.getRuntime|ProcessBuilder|Process\.Start|shell_exec|passthru|child_process|Invoke-Expression|' +
  'executeQuery|executeUpdate|createQuery|createNativeQuery|rawQuery|SqlCommand|FromSqlRaw|ExecuteSqlRaw|cursor\.execute|knex\.raw|sequelize\.query|\bSELECT\b.{0,80}\bFROM\b|' +
  'innerHTML|outerHTML|dangerouslySetInnerHTML|document\.write|v-html|Html\.Raw|render_template_string|autoescape|' +
  'pickle\.loads|yaml\.load\(|BinaryFormatter|ObjectInputStream|readObject|unserialize\(|TypeNameHandling|' +
  'MD5|SHA1\b|DES\b|RC4|ECB|NoPadding|verify\s*=\s*False|InsecureSkipVerify|ServerCertificateValidation|TrustAllCerts|AllowAnyOrigin|Access-Control-Allow-Origin|' +
  'os\.path\.join|Path\.Combine|\.\./|GetFullPath|FileStream|File\.(Read|Write|Open)|readFile|writeFile|' +
  'AllowAnonymous|\[Authorize|@PreAuthorize|@RolesAllowed|login_required|is_?admin|is_?superuser|' +
  'setuid|chmod|0777|pickle|marshal|Deserialize'

$script:FloorClasses = @('authz','entry-route','data-access','ext-call','config-iac','dep-manifest','app-source')
$script:AllClasses   = @('authz','entry-route','data-access','ext-call','config-iac','dep-manifest','app-source','docs','test','excluded')

function Get-AuditClass {
  param([string]$Path)
  if ($Path -match $script:reSkip)  { return 'excluded' }
  if ($Path -match $script:reTest)  { return 'test' }
  if ($Path -match $script:reDeps)  { return 'dep-manifest' }
  if ($Path -match $script:reConf)  { return 'config-iac' }
  if ($Path -match $script:reDocs)  { return 'docs' }
  if ($Path -match $script:reAuthz) { return 'authz' }
  if ($Path -match $script:reEntry) { return 'entry-route' }
  if ($Path -match $script:reData)  { return 'data-access' }
  if ($Path -match $script:reExt)   { return 'ext-call' }
  if ($Path -match $script:reCode)  { return 'app-source' }
  return $null
}

function Test-Sink {
  param([string]$Workspace, [string]$RelPath)
  $full = Join-Path $Workspace ($RelPath -replace '/','\')
  if (-not (Test-Path -LiteralPath $full)) { return $true }   # cannot check -> keep (err toward reading)
  try { return [bool](Select-String -LiteralPath $full -Pattern $script:sinkRe -List -ErrorAction SilentlyContinue) }
  catch { return $true }
}

# Does this file count toward a partition's AUDITABLE WEIGHT? Same rule the read floor uses:
# floor-class files always count; ordinary app-source counts only where a dangerous API matched.
function Test-Auditable {
  param([string]$Workspace, [string]$RelPath)
  $c = Get-AuditClass -Path $RelPath
  if (-not $c) { return $false }
  if ($script:FloorClasses -notcontains $c) { return $false }
  if ($c -eq 'app-source') { return (Test-Sink -Workspace $Workspace -RelPath $RelPath) }
  return $true
}
