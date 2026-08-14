# stride-threat-model deterministic-script tests

Regression suite for the skill's PowerShell scripts (manifest, partition, sweep,
validate-drawio, concat) -- the deterministic layer that does not involve an LLM, and
where the first field-reported failure (the Phase 0 sweep hang on a large repo) lived.

These files are under `tests/`, which `install.ps1` does NOT copy, so they never ship
into `~/.claude/skills`.

## Run

```powershell
powershell -File tests/stride-threat-model/test-scripts.ps1
```

Exit code 0 = all assertions pass. Run it after any change to a script in
`skills/stride-threat-model/scripts/`.

## What it covers

`make-fixture.ps1` generates a realistic monorepo fixture that deliberately includes the
things that break scripts at scale or on real machines: a large SQL dump and an oversized
generated file (must be sweep-excluded but kept in the manifest for accounting), minified
and lockfiles, a binary, tool-state directories (`audit_state/`, an archived
`*-threat-model-YYYYMMDD/` run, `security_architecture_audit.md`), a monorepo layout,
a no-extension file, a vendored dir, and a path component with a space.

`test-scripts.ps1` asserts:
- manifest excludes tool-state / vendored / archived-run, keeps real source + data files
- partition reconciles to the manifest total
- sweep skips bulk-data (by extension), oversized (by size), and generated/minified (by
  name) files; harvests the real resource names; excludes vendored tokens; completes fast
- validate-drawio passes a good diagram and flags a dangling edge ref
- concat rebuilds the monolith artifact

To generate a fixture for a manual full-pipeline run (with an archived prior run for
archive-comparison testing):

```powershell
powershell -File tests/stride-threat-model/make-fixture.ps1 -Path C:\tmp\stm-fixture -WithArchive
```

## Bash-invocation test

```bash
bash tests/stride-threat-model/test-bash-invocation.sh
```

Proves every script runs from bash (Git Bash on Windows) using the canonical form in
common.md rule S. This exists because a field run whose Claude Code harness drove bash
could not run the skill at all -- the phase files showed PowerShell-native call syntax
and multi-line inline PowerShell, neither of which survives being pasted into bash. Run
it whenever a script or a call site changes.

## Diagram fixtures

Two diagram data files feed `scripts/render-drawio.ps1`. Both are HAND-MAINTAINED --
there is no generator, and editing them means editing the JSON.

- `real-repo-diagram-data.json` -- derived by hand from the astrolog-chart-automation
  repo (18 nodes, 18 edges; a 9-member tier against a 1-member tier). This is the
  PRIMARY fixture. Real structure finds layout defects a designed sample cannot: five
  rounds against a synthetic sample found fewer defects than two rounds against this,
  because a fixture built to exercise the layout cannot surprise it.
- `sample-diagram-data.json` -- smaller (11 nodes, 13 edges), kept because it renders
  a differently shaped grid and costs nothing to check alongside the real one.

`make-sample-diagram.py` used to generate the second file. It was removed once the
JSON was committed: nothing referenced the generator, and regenerating a fixture that
had never been regenerated was not worth 291 lines.

The rendered `.drawio` and exported `.png` are gitignored -- they are output,
reproducible from these JSON files.
