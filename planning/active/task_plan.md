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

- [x] Extend `data-raw/georef_calibrate-corner_mapping.R` with a film section, reusing
      its existing `georef_at()` / `grey()` / `pair_r()` helpers rather than
      re-deriving them (`georef_at()` parameterised rather than copied)
- [x] Adjacent-frame overlap correlation — the route that decided #38 and the only one
      available here (1968 film has no `patb_georef_url` exterior orientation). Score
      all four rotations on bc5282 with a bearing-rotated square footprint
- [x] Repeat on a second era — bc83062 (1983), three separate legs. bc5306 was NOT
      used: its well-overlapped pairs are cardinal, where every rotation is a quarter
      turn of the same square and the measurement cannot discriminate
- [ ] Repeat on bc5306, and on a second era if the catalogue has film near the AOI
      from another decade
- [x] Positive control FIRST — digital through the same harness returns 270 at +0.713
      against 90 at +0.425, reproducing #38. A harness that cannot find a known answer
      is not evidence
- [ ] FWA lake darkness as the outside opinion (not needed: the overlap result is
      decisive in the negative direction, and a weak third route cannot rescue a
      per-roll answer)
- [ ] Record every number in `inst/notes/georeferencing.md`, including which rotations
      the measurement could *not* separate

**STOP CONDITION FIRED.** bc5282 (1968) = 0; bc83062 (1983) = 90, consistently across
three bearings. The mapping is flight-relative but per-roll. There is no
`fly_film_rotation()` to write. A fixed-geographic alternative was tested and
falsified. User decision 2026-09-02: `fly_georef()` refuses a rotated film frame and
names the fix, rather than georeferencing on a guess.

**Stop condition, stated up front:** if rolls or eras disagree, the answer is a
per-roll or per-era column, not a constant — stop and re-scope rather than pooling
into an average.

## Phase 2: Rotate film footprints

- [x] `fly_rectangles()` — drop the `!isTRUE(all.equal(hc, ha))` gate so a finite
      bearing rotates a square too. Leave the NA / non-finite / zero guards alone
- [x] `fly_footprint()` — compute `bearing` for every frame, not only where
      `non_square`, and tag `axis_aligned_no_bearing` on any frame without one.
      Tag applied after `no_geom` is known, so an unsized frame does not claim an
      alignment it never had (review B2, and the `ifelse` for `NA_character_`)
- [x] Add a `footprint_bearing` column, assigned onto `attrs` alongside
      `footprint_basis` — never as a trailing argument to `st_sf()` (#35). Add it to
      `fly_reported_cols()` in `tests/testthat/setup.R`
- [x] NA `footprint_bearing` in the `no_geom` block, so `is.finite()` means "was
      rotated" by construction rather than by `fly_georef()` happening to skip empty
      footprints first (review B1)
- [x] Delete the now-dead `non_square` local and its comment (review G8)
- [x] **`fly_bearing()` refuses a non-adjacent neighbour** (review B3, user decision
      2026-09-02). A gap of more than one frame number yields NA. Without it, film
      rotates onto cross-leg azimuths and footprint geometry becomes batch-dependent:
      `centroids[1:2, ]` gave 51.5 where the full batch gave 318.2 / 231.6
- [x] Update the `@details` text that states "Film stays square and is unaffected"

## Phase 3: Route georef on rotation, not on shape

- [x] `fly_georef()` — replace the `fly_is_square()` branch with
      `is.finite(footprint_bearing)`. A rotated ring gets the fixed mapping; an
      unrotated one keeps the legacy `rotation` / `bearing_to_rotation()` path
- [x] ~~add `fly_film_rotation()`~~ — **not buildable**, see the Phase 1 stop
      condition. Rotated film is refused unless the caller supplies the roll's value
- [x] Keep the user `rotation` column at highest precedence, and keep `fly_is_square()`
- [x] Re-gate and re-word the no-bearing warning, which was gated on `non_square` and
      so never fired for film (review G1)
- [x] Rewrite `@param rotation` and the whole Rotation section; update the example to
      one that does not warn (review G3)
- [x] Verify the stretch guard still passes rotated film

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
