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

### Phase 2 — aspect invariant pinned

- `tests/testthat/test-fly_georef_aspect.R`: the GCP mapping must send the image's long
  pixel axis onto the footprint's long ground edge, expressed as an anisotropy ratio
  (m/px on the width axis over m/px on the height axis) that must be 1
- Premise asserted beside it: the shipped `camera_formats.csv` aspect matches the
  aspect of the thumbnails the catalogue actually serves, to 1e-3. A regenerated CSV
  that disagreed would fail there, naming the cause, rather than here
- Negative half pinned with numbers, not a threshold: rotations 0 and 180 squash by
  ratio^2 — **1.21x** on the DMC II, **2.42x** on the UltraCam. The DMC II alone would
  survive a loose tolerance; a fixture change dropping the UltraCam frames fails
- Stated explicitly that the invariant is vacuous on square film, which is why the film
  mapping needed imagery and why this cannot finish the digital job either
- **Restore-the-bug check**: patched `fly_georef_gcps()` to ignore its rotation argument
  (the pre-#38 behaviour — `bearing_to_rotation(271)` returns 0), in *both*
  `asNamespace("fly")` and `as.environment("package:fly")`, with a printed ground
  coordinate that can only come from the broken version. Result: **FAIL=2**, the two
  isotropy assertions. The guard fires
