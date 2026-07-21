<!-- SKILL VERSION: v25-skill (2026-07-21a) -- methodology carved verbatim from PROMPT VERSION v24 (2026-07-16a) -->

Read common.md, phase-1-shared.md, STATE.md, 00-scope.md, 00-discovery.md, and your partition file 00-manifest-iac.txt.

### Phase 1B -- Infrastructure-as-Code Pass
Find and analyze:
- Terraform: `*.tf`, `*.tfvars` -- extract `resource`, `module`, `data` blocks. Map cloud resources (compute, storage, network, IAM, secrets, queues, databases).
- Kubernetes/Helm: `*.yaml` under `k8s/`, `manifests/`, `helm/`, `charts/` -- extract `Deployment`, `Service`, `Ingress`, `NetworkPolicy`, `ServiceAccount`, `Role`/`RoleBinding`, `Secret`/`ConfigMap` references.
- Docker: `Dockerfile*`, `docker-compose*.y*ml` -- extract base images, exposed ports, volumes, env vars, user/USER directives.
- CI/CD: `.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`, `azure-pipelines.yml`, `buildspec.yml` -- extract deployment targets, secrets usage, artifact flow.

For each IaC file, record: resources declared, trust boundaries implied, secrets referenced, network paths opened.

Write 01b-partial.md per the shared schema. Unaccounted must be 0; if you run out of room, write what you have and return the remaining file list (the orchestrator re-dispatches a continuation).
