# Task: Bearing rotation for diagonal flight lines — film half (mechanism built in #32) (#26)

## Problem

`fly_georef(rotation = "auto")` quantizes flight bearing to 90 degree increments via
`bearing_to_rotation()` and uses the result to shuffle which corner of an
**axis-aligned** footprint the top-left pixel maps to. That works for E-W and N-S
flight lines and cannot work for a diagonal one: on a ~230 degree bearing the image is
warped into a north-up square, so the picture sits ~50 degrees off from the ground it
covers, and no corner shuffle repairs it.

#32 (v0.6.0) built the mechanism — `fly_rectangles()` takes a `bearing` and applies
continuous rotation about the centroid — but gated it on the recording format being
non-square, so it reaches digital frames only. Film stayed square and axis-aligned,
which is what kept #32 from moving every existing footprint. #38 (v0.7.0) then
measured the corner mapping for a pre-rotated non-square footprint.

**What remains is the film half**, and it is not only a georef bug. A film frame's
true ground footprint *is* a square rotated onto the flight line; the axis-aligned
square `fly_footprint()` currently draws is wrong for any off-cardinal bearing, and
at 45 degrees it overlaps the true footprint by only ~83%. So `fly_coverage()`,
`fly_select()` and `fly_overlap()` are already reporting ground that diagonal film
frames do not cover — silently. Rotating the footprint fixes both halves.

Scope confirmed by the user 2026-09-02: **rotate the footprint**, accepting that
diagonal film geometry moves.

### The bundled data reaches the failure mode

`inst/testdata/photo_centroids.gpkg` holds **bc5282** — the exact roll the issue
names — with 10 frames on bearings 224.9-231.6 degrees, plus **bc5306** (8 frames) as
a second roll. Thumbnails come from the public catalogue via `fly_fetch()`. Nothing
licence-restricted is needed, so the calibration is reproducible.

## Phase 1: Measure the film corner mapping

Load-bearing, and it comes first: the geometry alone cannot settle it. A square
footprint makes the aspect invariant in `test-fly_georef_aspect.R` **vacuous** (all
four rotations pair the axes admissibly), so no test in the suite can catch a wrong
film constant.

- [ ] Extend `data-raw/georef_calibrate-corner_mapping.R` with a film section, reusing
      its existing `georef_at()` / `grey()` / `pair_r()` helpers rather than
      re-deriving them
- [ ] Adjacent-frame overlap correlation — the route that decided #38 and the only one
      available here (1968 film has no `patb_georef_url` exterior orientation). Score
      all four rotations on bc5282 with a bearing-rotated square footprint
- [ ] Repeat on bc5306, and on a second era if the catalogue has film near the AOI
      from another decade
- [ ] FWA lake darkness as the outside opinion, reporting the water's off-centre
      offset beside each result
- [ ] Record every number in `inst/notes/georeferencing.md`, including which rotations
      the measurement could *not* separate

**Stop condition, stated up front:** if rolls or eras disagree, the answer is a
per-roll or per-era column, not a constant — stop and re-scope rather than pooling
into an average.

## Phase 2: Rotate film footprints

- [ ] `fly_rectangles()` — drop the `!isTRUE(all.equal(hc, ha))` gate so a finite
      bearing rotates a square too. Leave the NA / non-finite / zero guards alone
- [ ] `fly_footprint()` — compute `bearing` for every frame, not only where
      `non_square`, and tag `axis_aligned_no_bearing` on any frame without one
- [ ] Add a `footprint_bearing` column, assigned onto `attrs` alongside
      `footprint_basis` — never as a trailing argument to `st_sf()` (#35). Add it to
      `fly_reported_cols()` in `tests/testthat/setup.R`
- [ ] Update the `@details` text that states "Film stays square and is unaffected"

## Phase 3: Route georef on rotation, not on shape

- [ ] `fly_georef()` — replace the `fly_is_square()` branch with
      `is.finite(footprint_bearing)`. A rotated ring gets the fixed mapping; an
      unrotated one keeps the legacy `rotation` / `bearing_to_rotation()` path
- [ ] Where film's measured constant differs from `fly_digital_rotation()`, add
      `fly_film_rotation()` beside it and key on the **recording format**, known
      before any sizing route runs — never on `half_cross`/`half_along` (#32 gotcha)
- [ ] Keep the user `rotation` column at highest precedence, and keep `fly_is_square()`
- [ ] Verify the stretch guard still passes rotated film

## Phase 4: Reconcile downstream numbers and tests

- [ ] Measure how far the bundled AOI's coverage and selection actually move
- [ ] Restore the pre-change behaviour and confirm the new tests fail, patching **both**
      `asNamespace("fly")` and `as.environment("package:fly")`
- [ ] Update tests whose premise was film-is-axis-aligned
- [ ] Sweep `centroid_shapes()` for `footprint_bearing`
- [ ] New test: a diagonal film footprint is **not** axis-aligned, and its ring order
      still means rear-left / rear-right / front-right / front-left
- [ ] Vignette `airphoto-selection.Rmd` — re-knit and check any stated numbers

## Phase 5: Document and release

- [ ] `inst/notes/georeferencing.md` — film section with the Phase 1 tables
- [ ] CLAUDE.md Key Decisions entry
- [ ] NEWS.md + version bump to 0.9.0 as the final commit
- [ ] Close #26 with `Fixes #26`

## Validation

- [ ] Tests pass
- [ ] `/code-check` clean on each commit
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
