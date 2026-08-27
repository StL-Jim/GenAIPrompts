# Skill cleanup -- remove instructions carried over from the source prompt

Copy this whole file to the machine holding the rebuilt STRIDE skill and give it to Claude
Code with the skill directory in reach. Self-contained; nothing else is needed.

Run this AFTER the Phase 4 fix, or before it -- they do not overlap.

## Why this is needed

The skill was rebuilt by carving a monolithic prompt. That prompt was written for a DIFFERENT
harness and for a SINGLE agent running every phase in sequence. Two whole classes of its
instructions are wrong here, and a faithful carve brings them across intact:

- **Tool names from the other harness.** `read_file`, `create_new_file`,
  `single_find_and_replace` are Continue.dev tools. They do not exist in Claude Code.
- **Orchestration for a single linear agent.** The source prompt has each phase update
  `STATE.md` and wait for the user to type `proceed`. In this skill the phases run as
  SUBAGENTS: they cannot talk to the user at all, and `STATE.md` belongs to the orchestrator
  alone. Four of them run in parallel at Phase 3, so a subagent writing `STATE.md` is a
  concurrent write to a file another agent is also writing.

The source prompt contains roughly 83 instances of these. Some may already have been corrected
during the rebuild. This sweep finds whatever survived.

## What to do

Grep the whole skill directory for each pattern below and fix every hit. A pattern returning
nothing is a pass -- report it as such, do not skip it silently.

### Group 1 -- tool names, mechanical replacement

| Find | Replace with |
|---|---|
| `read_file` | the Read tool (see common.md rule R) |
| `create_new_file` | the Write tool (see common.md rule W) |
| `single_find_and_replace` | the Edit tool (see common.md rule W) |
| `Continue.dev` | remove the reference; the harness is Claude Code |
| `Operating Rule 6` | rule R |
| `Operating Rule 7` | rule W |
| `Operating Rule 7(a)` / `7(d)` | rule W / rule W-d |

Rewrite the surrounding sentence so it still reads correctly. Do not leave a sentence whose
grammar assumed the old tool name.

### Group 2 -- orchestration, and this is the half that matters

**`update STATE.md`** -- expect up to nine. Exactly ONE is legitimate: the one in
`phase-0.md`, because Phase 0 runs in the orchestrator's own session rather than a subagent.
Every other occurrence is in a subagent phase file and must GO.

Replace each with a line telling the agent to report the phase status in its completion
summary instead. The information in the deleted instruction is not lost -- the orchestrator
needs it, so hand it over rather than dropping it. For example, where the source said

    update STATE.md: mark `phase-2b: complete` with timestamp, set Last Completed Step,
    set Resume Instruction to `Begin at Phase 2C ...`

write instead

    Do NOT write STATE.md -- it is orchestrator-owned (common.md rule X). In your completion
    summary, report: phase-2b complete; last completed step; and the rehydration files Phase
    2C will need.

**`proceed`** -- the source prompt has each phase stop and wait for the user to type
`proceed`. A subagent cannot ask the user anything, so an instruction to wait is an
instruction to hang. Delete every one in a subagent phase file. The orchestrator's gates
replace them, and they are already defined in SKILL.md.

**`wait for the user`, `NEW session`** -- same reasoning. The source prompt advises starting a
fresh session per phase; the orchestrator now does that for the agent by dispatching each
phase into its own context. Delete the advice.

**`Phase discipline` / "execute phases strictly in order"** -- if any phase file still carries
this, delete it. Sequencing is the orchestrator's job and is defined in SKILL.md's dispatch
table.

## Then verify

Re-run every grep from both groups and show the results. Every one must return nothing, except
`update STATE.md`, which must return exactly one hit, in `phase-0.md`.

Then confirm nothing was broken in the process: `common.md` still defines rules R, W, S, V and
X; every phase file still opens by naming the files it must read; and every phase file still
ends with a completion banner.

## Report

For each pattern: how many hits you found and what you did with them. Name the files you
changed. If you found a hit you were not sure how to fix, quote it rather than guessing.
