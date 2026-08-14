# SKILL VERSION: v25-skill (2026-07-23a)
# tests/stride-threat-model/make-fixture.ps1
#
# Generates a realistic medium-size fixture repo for exercising the stride-threat-model
# skill's deterministic scripts (manifest/partition/sweep/validate-drawio) and, if desired,
# a full subagent pipeline run. Deliberately includes the things that break scripts at
# scale: a large SQL dump, an oversized generated file, minified/lock files, binary files,
# tool-state directories (audit_state, an archived threat-model run, the audit log), a
# monorepo layout, files with no extension, and a path component with a space.
#
# Not shipped with the skill (lives under tests/, which install.ps1 does not copy).
param(
  [string]$Path = (Join-Path $env:TEMP 'stm-fixture'),
  [switch]$WithArchive   # also create an archived prior run for archive-comparison testing
)

function Put([string]$rel, [string[]]$lines) {
  $full = Join-Path $Path $rel
  $dir = Split-Path $full -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
  Set-Content -LiteralPath $full -Value $lines -Encoding ASCII
}

if (Test-Path $Path) { Remove-Item -Recurse -Force -LiteralPath $Path }
New-Item -ItemType Directory -Force $Path | Out-Null

# ---- docs (docs partition) ----
Put 'README.md' @(
  '# Filings Platform',
  'A monorepo: an internet-facing API, an async worker, and an admin web UI.',
  'The API sends transactional email via SendGrid and fetches public filings from sec.gov.',
  'Auth is via Okta OIDC. Data lives in RDS Postgres, S3, DynamoDB, and a Redis cache.'
)
Put 'docs/architecture.md' @(
  '# Architecture',
  'services/api -> RDS (filings-prod), S3 (filings-documents), SQS (ingest-queue)',
  'services/worker consumes SQS, writes DynamoDB (filing-alerts), reads S3',
  'services/web is an admin SPA calling the API'
)
Put 'docs/adr/001-datastore.md' @('# ADR 001', 'Chose DynamoDB for watchlists.')
Put 'openapi.yaml' @('openapi: 3.0.0', 'info:', '  title: Filings API')

# ---- IaC (iac partition) ----
Put 'terraform/s3.tf'  @('resource "aws_s3_bucket" "docs" {', '  bucket = "filings-documents"', '}')
Put 'terraform/rds.tf' @('resource "aws_db_instance" "main" {', '  identifier = "filings-prod"', '  publicly_accessible = false', '}')
Put 'terraform/dynamodb.tf' @('resource "aws_dynamodb_table" "alerts" {', '  name = "filing-alerts"', '}')
Put 'terraform/iam.tf' @('resource "aws_iam_role_policy" "api" {', '  policy = jsonencode({ Action = "s3:*" })', '}')
Put 'k8s/deployment.yaml' @('apiVersion: apps/v1', 'kind: Deployment', 'spec:', '  containers:', '    - name: api')
Put 'k8s/ingress.yaml' @('apiVersion: networking.k8s.io/v1', 'kind: Ingress')
Put 'k8s/networkpolicy.yaml' @('apiVersion: networking.k8s.io/v1', 'kind: NetworkPolicy')
Put 'services/api/Dockerfile' @('FROM python:3.12', 'EXPOSE 8000')
Put 'services/worker/Dockerfile' @('FROM python:3.12')
Put '.github/workflows/deploy.yml' @('name: deploy', 'on: [push]', 'jobs:', '  build:', '    steps:', '      - run: echo $AWS_ACCESS_KEY_ID')

# ---- application source (rest partition) ----
Put 'services/api/main.py' @(
  'import boto3, os, requests',
  's3 = boto3.client("s3")',
  'BUCKET = os.environ["DATA_BUCKET"]',
  'DB_HOST = os.environ["DB_HOST"]',
  'SQS_URL = os.environ["INGEST_QUEUE_URL"]',
  'redis_url = "redis://cache-prod:6379/0"',
  'r = requests.get("https://www.sec.gov/cgi-bin/browse-edgar")',
  'sg = requests.post("https://api.sendgrid.com/v3/mail/send")'
)
Put 'services/api/auth.py' @(
  'AUTH_SECRET = os.environ["AUTH_SECRET"]',
  'def check(token): return token == AUTH_SECRET  # shared static secret'
)
Put 'services/worker/consumer.py' @(
  'import boto3',
  'ddb = boto3.client("dynamodb")  # filing-alerts',
  'sqs = boto3.client("sqs")'
)
Put 'services/web/app.js' @('const API = process.env.API_URL;', 'fetch(API + "/filings");')
Put 'services/api/requirements.txt' @('flask', 'boto3', 'requests')
Put 'Makefile' @('build:', "`tpython -m build")   # no-extension file
Put 'services/api/tests/test_main.py' @('def test_ok(): assert True')  # test skip-bucket

# ---- scale / noise files (must be excluded by the sweep, kept in manifest) ----
$sql = New-Object System.Text.StringBuilder
for ($i=0; $i -lt 20000; $i++) { [void]$sql.AppendLine(("INSERT INTO t VALUES (postgres seed row {0});" -f $i)) }
Put 'data/seed.sql' $sql.ToString()
$big = New-Object System.Text.StringBuilder
for ($i=0; $i -lt 30000; $i++) { [void]$big.AppendLine(("generated line {0} https://example{0}.com padding padding padding padding padding padding" -f $i)) }
Put 'services/web/bigdata.js' $big.ToString()   # >1MB, in manifest but SWEEP size-excluded
Put 'services/web/vendor.min.js' @('var a=1;//https://cdn.example.com')  # name-excluded
Put 'services/web/package-lock.json' @('{ "lockfileVersion": 3 }')       # name-excluded
Put 'assets/logo.png' @('binary-ish png placeholder')                     # extension-excluded

# ---- vendored (excluded by manifest at any depth) ----
Put 'services/web/node_modules/left-pad/index.js' @('module.exports = function(){}')
Put 'vendor/thirdparty/lib.py' @('# vendored postgres://should-not-appear')

# ---- tool-state (must be excluded by manifest) ----
Put 'audit_state/findings_registry.md' @('finding: secret at services/api/auth.py; postgres://old')
Put 'security_architecture_audit.md' @('audit cross-run log; postgres://old-audit')

# ---- a path component with a space (robustness) ----
Put 'services/admin tools/report gen.py' @('endpoint = "https://internal.corp.example/reports"')

# ---- optional archived prior run for archive-comparison ----
if ($WithArchive) {
  $arch = 'stm-fixture-threat-model-20260101'
  Put "$arch/00-resources.txt" @(
    "bucket`tfilings-documents",
    "database`tfilings-prod",
    "table`tfiling-alerts",
    "external-api`tsendgrid",
    "bucket`tdecommissioned-legacy-bucket"   # only-in-prior -> should surface as possible regression
  )
  Put "$arch/STATE.md" @('# Threat Model Run State', 'PROJECT_NAME: stm-fixture')
}

"Fixture written to: $Path" + $(if ($WithArchive) { ' (with archived prior run)' } else { '' })
"File count on disk: $((Get-ChildItem -Path $Path -Recurse -File).Count)"
