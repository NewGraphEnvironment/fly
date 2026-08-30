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

### Phase 1 — GCP construction extracted

- `fly_georef_gcps(ncol_px, nrow_px, coords, rotation)` split out of `georef_one()`:
  pure, no GDAL, no file I/O
- Parity verified against the pre-change implementation lifted with
  `git show HEAD:R/fly_georef.R` (not reconstructed): 1024 cases — the 20 bundled film
  footprints, the 24 digital ones, and 20 random rings, at four image shapes and four
  rotations — **0 differences**
- One real difference found and fixed while doing it: the old loop produced a *named*
  character vector whenever the ring came from `sf::st_coordinates()`, because
  `coords[4, 1:2]` carries X/Y dimnames. GDAL ignores names; `identical()` does not
- Golden values written into `tests/testthat/test-fly_georef_gcps.R` so the pin survives
  that sha becoming history
- Full suite: 1181 passing, 0 failures
