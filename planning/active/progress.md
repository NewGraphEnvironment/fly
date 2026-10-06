# Progress — Three infrared roll-heights carry a right height beside a wrong scale (#91)

## Session 2026-10-06

- Plan-mode exploration — phases approved by user. Gate decisions: new tail `terrain`;
  scope IR only, with a follow-up issue for the BW/colour terrain-driven stratum
- Created branch `91-three-infrared-roll-heights-carry-a-right` off main
- Scaffolded PWF baseline from issue #91 with approved phases
- Next: start Phase 1 (pre-register the rule)
- Phase 1: rule, populations, outcome mapping and BW/colour audit written to findings.md and
  committed before the blind logbook read. Amendment A1 (scale pattern accepts `/`) written
  in the same commit, before the read.
- Phase 2: blind transcription of the six IR logbook pages appended to
  `flying_height_logbooks.csv` (51 rows). All three disputed roll-heights read the catalogued
  height; agrees with #89's non-blind read.
- Filed fly#93 (BW/colour terrain-driven stratum: 12 of 2,500 random frames, ~7,000 est.).
- Phase 3: generator reads the IR census (Stage 3b), `terrain` tail, amendment A1; run →
  three rows tabled, BW/colour byte-identical. Run log `planning/active/run_rolls.log`.
- Phase 4: tests extended (four sets, IR pins, `fly_footprint()` fixture); mutation table in
  findings. Full suite before review fixes: FAIL 0, PASS 5044.
- Phase 5: notes, roxygen, CLAUDE.md.
- /code-check: 3 rounds + enumeration.

  | Round | Findings | Fixed | Accepted | Inside previous fix? |
  |---|---|---|---|---|
  | 1 | 2 | 2 | 0 | — |
  | 2 | 1 | 1 | 0 | n (a sibling copy of a sentence fixed elsewhere) |
  | 3 | 5 + 2 pre-existing | 7 | 0 | n (siblings; mechanism named: table prose written for three tails and one source) |

  Ended by enumeration: round 3 listed ~60 sentences describing the roll table with a verdict
  each; every FALSE one fixed, then a repo grep for the drifted phrases found none left.
  Generator gained a per-tail reach print, so the note's reach figures have a producer.
