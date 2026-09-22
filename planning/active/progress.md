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
