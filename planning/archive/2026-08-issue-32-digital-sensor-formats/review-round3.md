# Review round 3 — `R/fly_footprint.R`

Scoped to `R/fly_footprint.R`, with `R/fly_camera_format.R`, `R/fly_bearing.R`,
`tests/testthat/test-fly_camera_format.R` and `tests/testthat/test-camera_formats.R`
read for context. Every claim below was reproduced against the working tree.

## Findings

- **[bug]** `R/fly_footprint.R:516-525` (with `:666-667` and `:724`) — **a footprint sized
  by the DEM route is never rotated onto the flight line, and nothing records that it
  wasn't.** This is the mechanism behind round 2's blocker showing up one line later:
  `dem_eligible` was corrected to see camera-table rows, but `non_square` — computed at
  line 516, *before* the DEM block — was not.

  `non_square` is derived from `half_cross`/`half_along` as they stand at line 516. For
  every camera-table row those are `NA` (`width_in` is NA there by definition — the same
  fact that made round 2's `sized <- !is.na(half_cross)` unreachable). So `non_square` is
  `FALSE` for every DEM-sized digital row, which has two consequences:

  1. `bearing` is left all-`NA` (line 518 never fires), so the final
     `fly_rectangles(coords, half_cross, half_along, bearing)` at line 724 draws an
     axis-aligned rectangle.
  2. The `; axis_aligned_no_bearing` annotation at lines 521-525 is also keyed on the
     stale `non_square`, so `width_source` stays silent. The documented contract —
     *"Where no bearing can be computed the rectangle stays axis-aligned and
     `width_source` says so"* (roxygen line 266) — is violated in the one direction that
     matters: the bearing **was** computable and the rectangle is axis-aligned anyway.

  Measured, on the suite's own fixture (`digital_fixture()` with
  `camera_calibration_url <- NA`, `ground_sample_distance <- NA`, `dem = dem.tif` —
  i.e. verbatim the setup of the test at `test-fly_camera_format.R:270`):

  ```
  basis:        inferred_format x6
  terrain:      dem_agl x6
  width_source: focal_length=92 focal_length=92 focal_length=80 ...   <- no annotation
  fly_bearing(p)$bearing:  90.49  90.45  90.42  90.42  NA  NA         <- computable
  row 1: cross=2595.1  along=1471.8  along-edge azimuth = 360.00      <- should be ~90.5
  ```

  Row 1 is a DMC III (100.3 x 56.9 mm, 1.76:1) on a flight line running due east. The
  long axis is drawn **along** the heading instead of across it — the footprint is
  transposed 90 degrees. Area is unchanged, so `st_area` cannot see it, but the ground
  actually covered is wrong, and `fly_coverage()`, `fly_overlap()` and photo selection all
  read that ground.

  The DEM sampling windows use the same all-`NA` bearing, so `dem_coverage` and
  `height_agl` are internally consistent — consistent with the wrong shape.

  Second, quieter symptom of the same mechanism: whether a row is rotated depends on
  **what else is in the same call**, because `bearing` is assigned as a whole vector
  under `if (any(non_square))`. Same fixture, same row 1, differing only in whether
  unrelated rows carry a GSD:

  ```
  rows 1-4 keep GSD (by_gsd -> non_square TRUE)  -> row 1 azimuth = 90.49   (rotated)
  rows 1-4 GSD set to NA (all on the DEM route)  -> row 1 azimuth =  0.00   (not rotated)
  ```

  A frame's geometry changing because a *different* frame in the batch had a
  `ground_sample_distance` is the "two conditions that only happen to agree" shape.

  Why the suite can't see it: the two tests that exercise the DEM route for digital
  (`test-fly_camera_format.R:270` "an inferred-format frame IS sized when a dem is
  supplied" and `:291` "a calibrated frame with no usable gsd is sized by the dem
  instead") assert `footprint_basis`, non-emptiness, `footprint_terrain` and
  `height_agl > 0` — nothing about orientation. The only rotation assertions
  (`:119` and `:148`) both run **without** a DEM, so they only ever reach the
  `by_gsd` path where `non_square` happens to be computable in time. No assertion in the
  package currently reaches a rotated DEM-sized footprint.

  Fix shape: `non_square` (and therefore `bearing`, and therefore the
  `axis_aligned_no_bearing` annotation) has to be decided from the dimensions the row
  will actually ship — i.e. the format's aspect, which is known from `fmt$width_mm` /
  `fmt$height_mm` before any sizing route runs — not from the half-dimensions as they
  stand mid-function. Note that `bearing` must be available *before* line 590, because
  the seed and second-pass sampling rectangles use it too.

  Regression test that would have caught it: repeat the `:119` azimuth assertion
  ("along-track edge must point along the heading, mod 360") on the DEM route, and assert
  `width_source` gains `axis_aligned_no_bearing` **only** where `fly_bearing()` returns
  NA.

- **[fragile]** `R/fly_footprint.R:697-706` — the new `resolved_unsized` warning fires on a
  **film** frame whose only problem is an unparseable `scale`, and its text points
  entirely at digital metadata. Reproduced on the bundled film centroids with
  `scale[2] <- "unknown"`:

  ```
  WARN: 1 of 3 frames have a known recording format but could not be sized, so they
  have no footprint. A digital frame needs either a `ground_sample_distance` and a
  calibrated pixel count, or `dem` together with `flying_height` and `focal_length`.
  ```

  `basis` is `Film - BW`, `width_source` is `NA`, and neither `ground_sample_distance`
  nor `dem` would help — the fix is the `scale` string. Same misfire on the
  no-`media`-column path (`assumed_default`). This case produced no `fly_footprint()`
  warning at all before this diff, so it is new behaviour, and it sends the reader to the
  wrong column. Splitting the message on `from_table` (digital advice) versus
  `!is.na(width_in) & is.na(scale_num)` (say `scale` could not be parsed) costs one
  branch.

## Checked and clean

- **`half_cross` / `half_along` mutual consistency.** `half_along` is only ever set
  independently on the two paths that also set `half_cross` (`by_gsd` at 508-509,
  `corrected` at 666-667). They cannot disagree in NA-ness, so `no_geom` at 687 and
  `fly_rectangles`' own guard classify identically for every value reachable from
  catalogue data.
- **Invariant "footprint_terrain is NA exactly where the geometry is empty".** Holds on
  every path I could reach. The one structural gap is that `no_geom` tests `is.na` while
  `fly_rectangles` tests `is.finite`, so an `Inf` half-dimension would ship an empty
  geometry with a non-NA `footprint_terrain` — but I could not reach `Inf` from any
  realistic input: the DEM route filters on `is.finite(candidate$...)` before assigning,
  and `by_gsd` requires a finite positive GSD. Noted, not reported.
- **Sea-level seed is safe for film.** `need_seed <- dem_eligible & is.na(seed_cross)` is
  `FALSE` for every film row with a parseable scale, so film seeds from its nominal
  rectangle exactly as before. A film row with an unparseable scale is not `dem_eligible`
  at all (`!is.na(half_cross) | from_table` is FALSE), so it never reaches `resize(0)`.
  Film output is byte-identical: `test-camera_formats.R:97` passes, and I re-confirmed
  all 20 bundled footprints are square to 4.1e-12 relative.
- **Seed non-finiteness.** `resize(0)` returns NA/Inf for an NA or zero `focal_length`;
  `fly_rectangles` turns that into an empty polygon, `fly_dem_sample` returns NA elev, and
  the row lands in `uncovered` (rather than `unusable`, which is a slightly misleading
  warning but the final state — empty geometry, NA terrain — is correct).
- **`fly_is_square()` tolerance.** Not a false-positive risk: real film footprints
  round-tripped through EPSG:4326 show a maximum relative edge spread of 4.1e-12 against
  `all.equal`'s 1.5e-8 — four orders of margin. All 20 classify square from both a 3005
  and a 4326 input.
- **`fly_bearing()` row order.** Assigns via `bearing[ord[i]]`, so the returned vector is
  in input order and aligns with `coords` / `half_cross`. Confirmed by the 90.4-90.5
  values landing on rows 1-4.
- **`dem_coverage` / `terrain` exclusion of `by_gsd`.** Correct on both branches: the
  `gsd_scaled` rows are sampled (wastefully) by the seed pass but excluded from
  `dem_eligible`, so neither `terrain[dem_eligible]` nor `dem_coverage[dem_eligible]`
  touches them.
- **Test assertions.** No assertion in either test file is structurally incapable of
  failing. `test-camera_formats.R:18` (check B) correctly excludes the `!mm_stated` rows
  that would compare arithmetic against itself, and asserts the premise. The
  `expect_gt(..., 5 * X / 5)` at `test-fly_camera_format.R:26` is an odd expression but
  does discriminate the scale route from the GSD route (8.80e6 vs 3.04e6). The
  drift-guard-fires test at `test-camera_formats.R:106` re-implements the setdiff rather
  than calling the guard, so it duplicates rather than proves — but it does have a real
  failure mode, so it is not decoration.
