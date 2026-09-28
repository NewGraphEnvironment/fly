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
