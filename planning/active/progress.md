# Progress — Two #54-slipped roll-heights a sibling frame settles and no logbook does (#74)

## Session 2026-09-27

- Plan-mode exploration; phases approved by user, with two gate decisions (scope: both tails;
  logbook vetoes only when it names a different factor)
- Created branch `74-sibling-frame-witness` off main
- Scaffolded PWF baseline from issue #74 with approved phases
- Next: Phase 1
- Phase 1: tests pinned (commit 146389f), failing against the old table
- Phase 2: Stage 5b sibling witness in the generator; regenerated both CSVs; 4 roll-heights
  settled (two beyond the issue, both logbook-corroborated); tolerance guard proven by mutation
- Phase 3: loader reads `witness`; docs/comments/warning in R/fly_footprint.R; counts 299 -> 308
- /code-check: four rounds. R1 clean. R2 found a stale vignette count. R3 found the tolerance
  assumed rounding only (catalogue also truncates); fixed, bc7675 now tabled. R4 found a third
  storage (3.28 ft/m) inside R3's fix (docs only, refuses toward safety), and ended the loop
  by enumerating all 3,876 neighbour-relation pairs. Commit 8f29789
- Phase 4: fly#74 section in terrain-correction.md, NEWS, CLAUDE.md Key Decision, vignette count
  28 -> 33, issue #74 body edited with the two-neighbour finding and the adopted rule
