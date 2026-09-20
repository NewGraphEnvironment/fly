# Progress — Measure what a partially DEM-covered footprint costs (#58)

## Session 2026-09-20

- Plan-mode exploration: read `inst/notes/terrain-correction.md`, the DEM block of
  `R/fly_footprint.R`, the fly#54 calibration script and the two sweep-backed tests
- Five read-only probes (see `findings.md`): bearing on a single-point call, the cached
  catalogue pull and what it lacks, MRDEM's NA region relative to BC, near-shore ocean
  values, and a 2-frame feasibility run of the truncation harness
- Plan agent design review, 16 findings; two of its factual claims verified and one of its
  proposed remedies falsified (exact-zero ocean test)
- Phases approved by user, with: ship the remedy the pre-registered rule selects in this
  PR, and include the population arm
- Created branch `58-measure-what-a-partially-dem-covered-f` off main
- Scaffolded PWF baseline from issue #58 with approved phases
- Next: Phase 1, the population
