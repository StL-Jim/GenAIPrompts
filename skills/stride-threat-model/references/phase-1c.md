<!-- SKILL VERSION: v25-skill (2026-07-21a) -- methodology carved verbatim from PROMPT VERSION v24 (2026-07-16a) -->

Read common.md, phase-1-shared.md, STATE.md, 00-scope.md, 00-discovery.md, and your partition file 00-manifest-rest.txt.

### Phase 1C -- Application Source Pass
Depth matters here more than anywhere: Operating Rule 9 governs HOW to read a large file (ranges, not whole-file dumps), never WHETHER to look. Read every source file, and read deeply into the ones that define the items below -- Phase 2's threat coverage is only ever as complete as this walk. Walk the application source and identify:
- Entry points: HTTP handlers/controllers, message consumers, scheduled jobs, CLI entry points, gRPC services, Lambda handlers.
- External integrations: HTTP clients, SDK calls (AWS, Azure, GCP), database drivers, message brokers, third-party APIs.
- Data stores: SQL/NoSQL, cache, file storage, object storage, secrets managers.
- AuthN/AuthZ logic: middleware, guards, interceptors, policy checks, token validation.
- Cryptographic operations: hashing, encryption, signing, key management, TLS configuration.
- Input boundaries: where untrusted data enters (request bodies, query params, headers, file uploads, message payloads, deserialization).
- Output boundaries: where data leaves (responses, logs, outbound HTTP, emails, metrics).
- Configuration surface: env vars, config files, feature flags, remote config.

When you record these as inventory Components, apply the component definition in phase-1-shared.md's Element Classification section: the data stores, managed services, queues, caches, gateways, and identity providers you find here are all COMPONENTS (each a C-NNN with a Phase 2 walk), not a lower tier -- do not fold them away into detail-only sections. Undercounting components here is the largest single cause of missed threats downstream.

Write 01c-partial.md per the shared schema. Unaccounted must be 0; if you run out of room, write what you have and return the remaining file list (the orchestrator re-dispatches a continuation).
