# Progress — fly has no R-CMD-check workflow (#52)

## Session 2026-09-21

- Plan-mode exploration: read `.github/workflows/pkgdown.yaml`, the test suite's skip
  guards, every `@examples` block that touches the network, and the three sibling repos
  that already carry an `R-CMD-check.yaml` (gq, rfp, spacehakr)
- Two decisions put to the user at the plan gate and answered: 3-platform matrix at R
  release, and fix the pre-existing WARNING in this PR rather than relaxing `error-on`
- Created branch `52-fly-has-no-r-cmd-check-workflow` off main (level with origin)
- Scaffolded PWF baseline with the approved phases
- Next: Phase 1 — run `devtools::check()` locally and record the real NOTE/WARNING set

### Later the same session

- **Phase 1** — measured the check before writing anything: 0 errors, 1 warning, 1 note,
  243 s. Both planning predictions were wrong and are recorded as wrong
- **Phase 2** — one character, `R/fly_mask.R:293` -> `\u2014`. WARNING cleared
- **Plan review** (concurrent, per `planning.md`) — one blocker: seven unguarded live
  downloads in `test-fly_georef.R` with hard assertions, so a catalogue outage would have
  reddened three runners on any diff. Measured at **FAIL 11** with HTTP blackholed, FAIL 0
  / SKIP 9 with the guards. Thirteen further findings, all in `review-plan.md`
- **Phase 3b** — guards, `withr::local_tempdir()` for fourteen shared tempdir names, a
  GDAL floor premise, README badge
- **Phase 3** — the workflow. `/code-check` ran **three rounds plus a plan review and two
  enumerations**; round 1 found a defect inside a fix (a concurrency group that would have
  made the three runners cancel each other), so the loop ended on enumeration rather than
  on a quiet round. Six wrong claims out of twenty-six, including a GDAL floor of 3.7 taken
  from this repo's own conventions where upstream says 3.8 — a guard that would have passed
  on a build with no `-alg` flag
- Filed [#66](https://github.com/NewGraphEnvironment/fly/issues/66) (`^\.git$`, scoped out
  at the plan gate) and
  [soul#255](https://github.com/NewGraphEnvironment/soul/issues/255) (the GDAL version
  error in the shared convention)
- Next: commit workflow-first, push, open the PR, read the red run, then push the fix
