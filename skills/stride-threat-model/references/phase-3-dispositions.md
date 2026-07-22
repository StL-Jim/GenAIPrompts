<!-- SKILL VERSION: v25-skill (2026-07-21a) -- methodology carved verbatim from PROMPT VERSION v24 (2026-07-16a) -->

Read these files with the Read tool (disk content overrides memory): common.md, STATE.md, 02-threats.md, and the dispositions.csv at the path the orchestrator names in your briefing.

**Matching procedure:**

For each threat in the current `02-threats.md`, attempt to find a matching disposition entry in the loaded dispositions.csv. Use semantic matching across these dimensions:

1. Component match: same component (by ID like C-NNN, or by name if IDs differ)
2. OWASP category match: same OWASP Top 10 category
3. Technical content match: Title and Description describe the same underlying concern

Classify the match strength:

- **High confidence match**: Component aligns AND OWASP category aligns AND technical content clearly describes the same concern. Transfer the disposition.
- **Lower confidence match (Medium or Low)**: Do NOT transfer the disposition. The threat appears in exports with empty disposition fields.

Conservative matching is intentional. The cost of incorrectly attributing a prior disposition to a different threat is real -- it produces a confident-looking but incorrect record. The cost of leaving a threat un-dispositioned is just developer re-review work in the next stakeholder session.

After matching is complete, report:
```
Disposition matching complete: <N> threats matched (high confidence), <M> threats had no qualifying match. Exports will populate dispositions for matched threats only.
```

This reporting is critical for the user to understand what dispositions transferred. Do not skip it.

**Priority revision handling:**

If a matched disposition entry has different OriginalPriority and RevisedPriority values, the team revised the rating during a prior stakeholder review. Both values carry forward: the threat's effective Priority becomes the RevisedPriority, and the OriginalPriority is preserved for display alongside it. If the values are equal, no revision was made and the current Priority is used as-is.

Write every high-confidence match to {PROJECT_NAME}-threat-model/03-dispositions-matched.md per the table below; low/medium-confidence candidates are listed below the table under '## Not Transferred' with one-line reasons. Return the match report line.

| ThreatID | OriginalPriority | RevisedPriority | Disposition | DispositionRationale |
