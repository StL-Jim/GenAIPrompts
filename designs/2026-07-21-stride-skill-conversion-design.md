# STRIDE Threat Model — Claude Code Skill Conversion (Design)

**Date:** 2026-07-21
**Branch:** `stride-v25-skill` (off `stride-v24-merge` tip `192f852`)
**Source freeze:** `stride-threat-model-prompt.md` v24 (2026-07-16a). No methodology
changes ride along with this conversion. Prompt-text improvements resume only after
the skill is the canonical source.

## 1. Goal

Convert the monolithic STRIDE prompt into a Claude Code skill named
**`stride-threat-model`**: an orchestrator (SKILL.md) that dispatches per-phase
subagents, each loading only its own phase instructions. This is **packaging, not
rewriting** — methodology text carves over verbatim.

Wins this buys:
- **Progressive disclosure**: a phase session loads ~1/6 of the prompt instead of all
  of it. Every subagent gets a fresh 200K window, which obsoletes the entire
  fresh-session-per-phase / rehydration-as-context-defense machinery (the rehydration
  sections survive — repurposed as subagent briefings).
- **Kills hand-paste version drift**: the skill is cloned/installed once, versioned in git.
- **Retires the Continue.dev workaround layer** (tool tables, edit_existing_file
  avoidance, create_new_file ceilings) in favor of native Read/Write/Edit.
- **Parallelism** where phases are genuinely independent (Section 6).

## 2. Source of truth, naming, versioning

- Per-phase skill files become **canonical** at conversion. The monolith is demoted to
  a build artifact: `scripts/concat-monolith.ps1` rebuilds
  `stride-threat-model-prompt.md` (with a Continue.dev preamble adapter) for as long
  as a fallback matters. Cutover = the day the concat stops being run.
- The `PROMPT VERSION` stamp discipline carries over: one stamp in SKILL.md
  (starting `v25-skill (2026-07-21a)`), echoed at session start, injected into every
  deliverable. Bump on every skill-changing commit.
- **Git home**: GitHub `GenAIPrompts` is canonical during build and stabilization; the
  work machine clones from GitHub. After development genuinely shifts to work,
  internal git becomes the one editable source and GitHub demotes to archive. The
  cutover criterion is an **event, not a date**: the first prompt/skill fix authored
  on the work machine makes that repo home.
- **Parallel effort**: a separate Sonnet 4.5-built skill named `threat-model` exists at
  work. Different names = no install collision; treat it as an independent design
  experiment. Before any methodology edits resume, exactly ONE of the two skills is
  declared canonical (one-editable-source rule) — otherwise version drift returns.
- STATE.md gains `EXECUTOR_HARNESS: claude-code-skill` so cross-harness runs stay
  comparable. STATE.md format is otherwise unchanged: a half-finished monolith run is
  resumable by the skill and vice versa during the overlap.

## 3. Packaging and layout

A skill directory inside GenAIPrompts, installed by copying into `~/.claude/skills/`.
Deliberately NOT a plugin — plugins would allow named agent definitions and commands
but add marketplace/install machinery; generic subagents briefed by file references
work identically on both machines. Plugin conversion remains a future option.

```
skills/stride-threat-model/
  SKILL.md                  # orchestrator (Section 4)
  references/
    common.md               # executor-facing operating rules every subagent loads
    phase-0.md
    phase-1a.md  phase-1b.md  phase-1c.md  phase-1-reconcile.md
    phase-2a.md  phase-2b.md  phase-2c.md
    phase-3.md   phase-4.md
  scripts/
    manifest.ps1            # Phase 0 file manifest
    sweep.ps1               # Phase 0 Pass 2 mechanical sweep (nine patterns, three artifacts)
    validate-drawio.ps1     # Phase 4 XML parse + edge/parent integrity + count reconciliation
    concat-monolith.ps1     # rebuilds the monolith build artifact
  install.ps1               # copy to ~/.claude/skills/stride-threat-model
```

`install.ps1` copies rather than symlinks (works on both machines, no elevation).

## 4. Orchestrator (SKILL.md)

The main session that invoked the skill is the **only thing that talks to the user**.
Claude Code subagents cannot interact with the user, so every interactive step lives
here: Phase 0 stakeholder Q&A, System Restatement confirm/correct, and all gates.

Control flow:
1. Echo version stamp. Read STATE.md; announce last completed step + Resume
   Instruction exactly as today; confirm resume/restart before any work.
2. Loop: dispatch next pending phase as a subagent → receive its ≤10-line completion
   summary → verify the phase's output files exist and are non-trivial → update
   STATE.md → gate or auto-proceed per policy.
3. Artifacts live on disk; the orchestrator window accumulates only summaries, so one
   orchestrator session survives an entire engagement. If the orchestrator itself
   dies, STATE.md resumes it — same spine as today.

**Gate policy** (recorded in STATE.md, adjustable per run):
- Default `three-gates`: pause for the user after (1) Phase 0 scope review,
  (2) Phase 1 System Restatement confirm — this one is mandatory user input, not
  optional review, (3) Phase 2C, before export. Everything else auto-proceeds,
  including 2A→2B→2C.
- `all-gates`: pause after every phase and sub-phase (first-field-run fallback and
  debugging mode; matches today's cadence).
- The proceed gates' old second purpose — forcing fresh sessions for context head-room
  — is obsolete and is dropped without replacement.

**Phase 0 runs in the orchestrator**, not a subagent: it is interactive end-to-end and
its heavy lifting (manifest, sweep) is script-shaped.

**Subagent briefing template** (per dispatch): read STATE.md; read
`references/common.md`; read `references/phase-N.md`; read the named input artifacts
(the existing Rehydration lists, verbatim); do the phase; write the phase's output
files; return a short summary (files written, counts per Operating Rule 15, anything
the orchestrator must relay to the user). Briefings forbid the subagent from touching
STATE.md — the orchestrator owns it (single-writer; concurrent phase agents must not
race on it).

## 5. Carving rules

- Methodology text moves **verbatim**. The nuance-loss watchlist is run against the
  carve as an explicit review step before first field use, and the concat artifact is
  diffed against the frozen v24 monolith (differences must be only the intended
  scaffolding removals).
- Dropped (harness scaffolding made obsolete): session-start ceremony, the
  fresh-session-per-phase advice in Operating Rule 1, Continue.dev tool tables and
  tool-bug workarounds (Rules 6/7's harness-specific parts), `proceed` ceremony text.
- Split of today's Operating Rules: orchestrator concerns (phase discipline,
  session-start, STATE.md protocol, gate policy) → SKILL.md; executor concerns
  (evidence citation Rule 2, read-completely Rule 9, computed-numbers Rule 15,
  AI-disclosure Rule 16, schemas and caps) → `references/common.md`, loaded by every
  subagent.
- Rehydration sections → subagent briefings, contents unchanged.

## 6. Phase → agent map and parallelism (v1)

| Step | Executor | Concurrency |
|---|---|---|
| Phase 0 | orchestrator + scripts | — (interactive) |
| **GATE 1** — scope review | user | |
| Phase 1A docs / 1B IaC / 1C app source | 3 subagents, each writing a partial inventory file | **parallel** |
| Phase 1 reconciliation | 1 subagent: merge partials + Discovery Delta → `01-inventory.md` | after 1A/1B/1C |
| **GATE 2** — System Restatement confirm | user (orchestrator relays) | |
| Phase 2A → 2B → 2C | 1 subagent each | **sequential**, auto-proceed |
| **GATE 3** — pre-export review | user | |
| Phase 3-HTML / Phase 3-CSV / Phase 4 drawio | 3 subagents (Phase 4 depends only on inventory + 02a) | **parallel** |

The Phase 1 reconciliation step is a real agent with real instructions (the
cross-pass reconciliation is where Phase 1's quality comes from) — never a concat.

**Deliberately deferred to v2**: fanning out Phase 2B by component or STRIDE category.
Biggest wall-clock win, but dedup, cross-element threats, ID numbering, and the
investigator texture all get harder — and the field record says structural
elaboration beyond the winning texture correlates with worse results. Sequential 2B
first; revisit only after the skill field-validates.

## 7. Scripts: v1 vs deferred

v1 ships only scripts the prompt already mandates as PowerShell (manifest, sweep,
drawio validation) plus the concat. Deferred, each its own project:
- **drawio generator** (script writes the XML from inventory + 02a; model draws
  nothing) — the skill-era endgame for Phase 4; v1 keeps 15f model-drawn + validation.
- CSV export as a script.
- Scripted Phase 0 double-run union (`Compare-Object` over two `00-resources.txt`) —
  orchestrator-triggered ensemble, per the recorded run-twice-and-union intent.

## 8. Out of scope

Methodology/prompt-text changes of any kind; 2B fan-out; drawio generator; plugin
packaging; converting the code-security-audit prompt (only after its hardening
design field-validates, per the agreed conversion order).

## 9. Build and test plan

1. Carve v24 into `references/`, extract scripts, write SKILL.md + install.ps1 on
   `stride-v25-skill`.
2. Nuance-loss review: watchlist pass + concat-vs-monolith diff.
3. Field-test the whole skill **on the build machine** in Claude Code against a sample
   repo: dispatch, state handling, gates, parallel groups, script execution, resume
   after killing the orchestrator mid-run. These bugs are model-independent.
4. Push; user clones at work and runs `install.ps1`.
5. First work engagement runs with `all-gates` available as fallback. Sonnet 4.5's
   adherence under this structure is **untested until that run** — nothing is
   "validated" before it (no premature victory).

## 10. Risks

- **Nuance loss in the carve** — mitigated by verbatim rule + watchlist review + diff.
- **Sonnet 4.5 adherence** under orchestrator/subagent structure unknown until field
  run — mitigated by all-gates fallback and unchanged STATE.md resume spine.
- **Dual-skill drift** (`threat-model` vs `stride-threat-model`) — mitigated by the
  one-canonical declaration before methodology edits resume.
- **Parallel-write races** — mitigated by single-writer STATE.md and per-agent
  distinct output files.
