# Build the STRIDE threat-model skill from `stride-threat-model.md`

Paste this whole document into a fresh session. `stride-threat-model.md` is in the working
directory. You are building a Claude Code skill from it, in this repository.

## The one rule

**CARVE, NEVER INVENT.** Every line you write must come from `stride-threat-model.md`, moved
or lightly re-worded to fit its new file. If the prompt does not say something, the skill does
not say it. Where a phase file needs a rule that lives in the Operating Rules, reference it by
number rather than paraphrasing it.

This rule exists because it was broken once. A previous rebuild was asked to produce a skill
larger than its source; the agent filled the gap with plausible invention, and the result was
measured at 66% fidelity, with the damage concentrated in the files that had the least source
material. If you find yourself writing a sentence you cannot point at in the prompt, stop and
leave a `TODO:` line naming what is missing instead. A short honest skill beats a complete
invented one.

## What you are building

    SKILL.md                     orchestrator: gates, phase dispatch, failure handling
    references/common.md         IDENTITY and PURPOSE, Required Inputs, Operating Rules 1-16,
                                 Session-Start Behavior
    references/phase-0.md        Phase 0 (steps 1-10) incl. the discovery passes
    references/phase-1.md        Phase 1, its 1A/1B/1C passes, and the Architectural
                                 Inventory output schema
    references/phase-2a.md       Phase 2A
    references/phase-2b.md       Phase 2B, incl. the threat table schema and GATE 3
    references/phase-2c.md       Phase 2C
    references/phase-3.md        Phase 3, incl. 3A HTML, 3B CSV, 3C explainer
    references/phase-4.md        Phase 4
    scripts/render-drawio.ps1    built from the contract inside Phase 4 Step 1
    scripts/validate-drawio.ps1  built from the same contract

**Carve to the prompt's own seams, exactly as listed above.** Do not split further. In
particular do not create `phase-1-shared` / `phase-1a` / `phase-1b` / `phase-1c` /
`phase-1-reconcile` files: those exist in an older skill because it ran Phase 1 as parallel
subagents, and this prompt contains no partition machinery to fill them with. One file per
phase is correct here.

## How to do it

1. **Read `stride-threat-model.md` completely first.** All of it, before writing anything. It
   is about 1,730 lines. Do not start carving from a partial read.

2. **Write the reference files.** Move each section verbatim where you can. Two adjustments
   are allowed and expected:
   - The prompt tells the agent to update `STATE.md` at the end of each phase. In the skill
     the ORCHESTRATOR owns `STATE.md`. In each phase file, replace those instructions with
     "report your completion banner to the orchestrator; it owns STATE.md", and move the
     actual STATE.md fields into SKILL.md.
   - The prompt's "Type 'proceed'" gate text is user dialogue. A subagent cannot talk to the
     user, so that text moves to SKILL.md too. Everything else stays where it is.

3. **Write SKILL.md.** It needs: YAML frontmatter with `name` and a `description` saying when
   to use it; the STATE.md schema and the rule that only the orchestrator writes it; the
   Session-Start resume check; a dispatch table mapping each phase to its reference file; the
   three user gates (scope proposal after Phase 0, system restatement after Phase 1, threat
   review after Phase 2B), including the asset-tier confirmation between 2A and 2B; and a
   briefing template for dispatching a phase agent that tells it to read `common.md` plus its
   own phase file, then execute. Every one of those items is described in the prompt -- take
   the wording from there.

4. **Build the two scripts.** Phase 4 Step 1 of the prompt contains a full prose contract for
   `render-drawio.ps1` and `validate-drawio.ps1` -- geometry constants, the five layout
   stages, edge routing, the six known defects, and the BOM requirement. Implement it exactly.
   Put them in `scripts/`, and change Phase 4's Step 1 in the skill to say the scripts already
   exist and are invoked, rather than built.

5. **Leave every other PowerShell block inline, where the prompt has it.** Phase 0's manifest
   and sweep blocks stay inline. Do NOT turn them into `sweep.ps1`, `readset.ps1`,
   `manifest.ps1` or similar. The prompt has no contract for those, so writing them means
   inventing their behaviour -- the exact failure this document's first rule is about.

## Do not

- Do not add phases, rules, gates, or output files the prompt does not define.
- Do not renumber the Operating Rules. Phase files cite them by number.
- Do not change any ID scheme. `C-NNN` component, `DS-NNN` store, `EXT-NNN` integration,
  `TB-NNN` boundary, `A-NNN` actor, `ASM-NNN` assumption, `DF-NNN` flow, `AS-NNN` asset.
- Do not "improve" the threat table schema, the STRIDE walk, the exclusion reasons, or the
  L0-L4 privilege ladder.
- Do not write `.drawio` files by hand anywhere.

## Before you say you are done

Report all of these as numbers, not impressions:

1. **Line accounting.** Total lines in `stride-threat-model.md` vs the sum of all files you
   produced. The skill should be within roughly 10% of the source. If it is much larger, you
   invented; if much smaller, you dropped something. Explain any gap.
2. **Section coverage.** List every `##` heading in the prompt and name the skill file each
   one landed in. A heading that landed nowhere is a dropped section.
3. **Dangling references.** Grep the skill for every file it names -- `00-*`, `01-*`, `02*`,
   `04-diagram-data.json`, both `.ps1` scripts. Each must be produced by something in the
   skill. Report any that are referenced but never written.
4. **Rule citations.** Grep for `Operating Rule <n>`. Every number cited must exist in
   `common.md`.
5. **TODOs.** List every `TODO:` you left, verbatim. This is the honest record of what the
   prompt did not contain, and it is more useful than a clean-looking result.

Do not report success on any of these from memory -- run the check and paste its output.
