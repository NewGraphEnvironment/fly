# Progress — Georeference digital frames (#38)

## Session 2026-08-30

- Plan-mode exploration: read `R/fly_georef.R`, `R/fly_footprint.R`,
  `tests/testthat/test-fly_georef.R`, `tests/testthat/test-fly_camera_format.R`,
  `data-raw/make_camera_formats.R`, `data-raw/test_georef_decades.R`
- Measured the ring-order contract, the rotation-to-edge mapping, and both bundled
  cameras' thumbnail dimensions — see `findings.md`. Narrowed the corner mapping from
  eight possibilities to one bit by geometry alone
- Two decisions taken with the user: the orthophoto QA runs in the private catalogue repo
  and only its constant comes back; a user `rotation` column keeps overriding for
  non-square frames
- Phases approved by user
- Created branch `38-georeference-digital-frames-the-corner-m` off main
- Scaffolded PWF baseline
- Next: Phase 1 — extract the GCP construction into a pure, testable function
