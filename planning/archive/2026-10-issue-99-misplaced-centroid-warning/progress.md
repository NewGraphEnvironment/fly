# Progress — Surface frames whose catalogue centroids are known to be misplaced (#99)

## Session 2026-10-07

- Plan-mode exploration — phases approved by user (warning from ledger; only the five)
- Created branch `99-surface-frames-whose-catalogue-centroids` off main
- Scaffolded PWF baseline from issue #99 with approved phases
- Next: start Phase 1

## Session 2026-10-08

- Phases 1-3 landed in one commit (code, tests, roxygen, NEWS, CLAUDE.md, note); issue #99 body
  edited to record the decision
- Plan review (Plan agent) arrived after Phase 2: B1 (`num()` scope) and seven wording/test points acted on
- `/code-check`: three rounds, each finding a claim stated over a wider frame set than its producer;
  round 2's was inside the plan review's fix, so the loop ended on a mechanical enumeration of all 184
  added prose lines (findings.md)
- Full suite: 5,761 pass, 0 fail, 0 skip before round 3's wording fixes; misplaced and image-overlap
  files re-run after them (51 and 224 pass)
- Next: full suite, lint, check_pkgdown, archive, PR
