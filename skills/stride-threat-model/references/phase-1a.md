<!-- SKILL VERSION: v25-skill (2026-07-21a) -- methodology carved verbatim from PROMPT VERSION v24 (2026-07-16a) -->

Read common.md, phase-1-shared.md, STATE.md, 00-scope.md, 00-discovery.md, and your partition file 00-manifest-docs.txt.

### Phase 1A -- Documentation Pass

Search for and read, in this order (RECURSIVELY -- every match at ANY directory depth, from 00-file-manifest.txt, not just the repo root; a subdirectory README is exactly where an integration or dependency hides, and the Phase 0 discovery sweep already read these in full -- confirm and deepen, do not re-skip them):
1. `README*`, `ARCHITECTURE*`, `DESIGN*`, `SECURITY*`, `THREAT*`, `docs/`, `doc/`, `documentation/` -- at any depth
2. Any `*.puml`, `*.plantuml`, `*.mmd` (Mermaid), `*.drawio`, `*.dsl` (Structurizr), `*.c4` files
3. ADRs under `docs/adr/`, `architecture/decisions/`, `adr/`
4. OpenAPI / Swagger specs: `openapi.*`, `swagger.*`, `*.openapi.yaml`
5. API contract files: `*.proto`, `*.graphql`, `*.wsdl`

For each artifact found, extract and record: purpose, date (if available), and key architectural assertions (components, protocols, data stores, external integrations). Quote diagram source verbatim when it's short (under 100 lines) so the later phase can cross-reference.

Write 01a-partial.md per the shared schema. Unaccounted must be 0; if you run out of room, write what you have and return the remaining file list (the orchestrator re-dispatches a continuation).
