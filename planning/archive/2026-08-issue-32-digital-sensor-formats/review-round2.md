# Review — round 2 (fly#32, branch `32-establish-sensor-widths-for-digital-fram`)

Scope: staged diff (~1900 lines). Every claim below was reproduced by running the
code, not by reading it. Suite state at time of review: `FAIL 0 | PASS 426`.

## Findings

- **[bug]** `R/fly_footprint.R:564` (`sized <- !is.na(half_cross)`) with `:581`
  (`corrected <- sized & !by_gsd & ...`) — **no digital frame can ever be
  DEM-corrected, so every table-resolved frame that is not on the GSD route gets an
  empty geometry even when a DEM is supplied.**

  `half_cross` at line 479 is `width_in * scale_num * 0.0254 / 2`, and `width_in` is
  `NA` for every row resolved from the camera table (that is what `from_table` at
  :458 means). So `sized` is FALSE for all of them. `corrected` requires `sized`, and
  `corrected` additionally excludes `by_gsd`. The two conditions are disjoint:
  `sized` is only ever TRUE for a digital row *because* `by_gsd` set `half_cross` at
  :497 — and `!by_gsd` then removes exactly those. Compounding it, the first-pass
  sampling rectangle at :556 is built from the same NA `half_cross`, so it is an
  empty polygon and `first$elev` is NA regardless.

  Reproduced (digital fixture with `camera_calibration_url` stripped, so rows take
  the focal-92 fallback; synthetic 100 m DEM covering all frames):

  ```
  footprint_basis:   inferred_format  24
  footprint_terrain: <NA>             24
  empty geometries:  24 of 24
  areas (km2):       0 0 0 0 0 0
  ```

  This contradicts the documentation added in this same diff
  (`R/fly_footprint.R:252-253`): *"pixel count spreads 32-83%, so an inferred frame
  can only be sized through a DEM (`width x height above ground / focal length`) and
  never from its GSD."* The route the docs name as the **only** route for an inferred
  frame is unreachable. `fmt_cross_m`/`fmt_along_m` (:534-535) were written precisely
  to serve it and are dead for these rows.

  Same root cause hits calib-matched frames whose `ground_sample_distance` is
  missing or zero — a population the code itself calls out as real at :115
  (*"`ground_sample_distance` is 0 on every frame of some digital rolls"*), and which
  `digital_fixture()` row 6 exists to represent. Reproduced with the real digital
  fixture and `ground_sample_distance <- 0`: 24/24 empty.

- **[bug]** `R/fly_footprint.R:465` (`unresolved <- is.na(width_in) & !from_table`)
  and `:462` (`basis[from_table] <- ...`) — **the frames in the finding above are
  silent, and their reporting columns claim they were resolved.**

  Because `from_table` is TRUE, they are excluded from the `unresolved` warning; and
  because `sized` is FALSE, none of the three DEM warnings (`uncovered`, `unusable`,
  `partial`) can fire either. A direct `fly_footprint()` call emits **no warning at
  all** while returning empty geometry for every digital frame. Meanwhile:

  | column | value | what it means per the roxygen |
  |---|---|---|
  | `footprint_basis` | `"inferred_format"` / `"Digital - Colour"` | "sized from a format inferred from its focal_length" / "format resolved from the format table" |
  | `width_source` | `"focal_length=92"` / `"121201_2011"` | "names the calibration file … so every footprint traces back to a source" |
  | `footprint_terrain` | `NA` | "no footprint to place — see `footprint_basis`" |

  `footprint_basis` and `footprint_terrain` directly contradict each other, and a
  caller filtering on `footprint_basis != "unknown_format"` — the workflow the
  `@examples` block teaches at :371 — keeps a set that is entirely empty geometry.
  Before #32 these rows were `"unknown_format"` with a warning naming `format_size`,
  so this is a regression in signalling even where the geometry outcome is unchanged.

  `fly_warn_unsized()` does not rescue this: it is only called from `fly_coverage()`
  / `fly_georef()`, never from `fly_footprint()` itself.

- **[bug]** `R/fly_footprint.R:507-508` — `fly_footprint()` now aborts on an `NA` in
  `film_roll`, with an opaque base-R message.

  The guard is `all(c("film_roll", "frame_number") %in% names(centroids_sf))`, which
  tests for *presence*, not usability. `fly_bearing()` then does
  `if (i < length(ord) && rolls[i] == rolls[i + 1])` (`R/fly_bearing.R:53`); with an
  NA roll that condition is `NA` and `if` errors. Reproduced on the bundled digital
  fixture with one `film_roll` set to NA:

  ```
  ERROR: missing value where TRUE/FALSE needed
  ```

  This is latent in `fly_bearing()` but *newly reachable from the package's primary
  function*: before this diff `fly_footprint()` never called it. `flight_log_url` is
  already NA throughout the bundled digital fixture, so NA string fields in this
  layer are not hypothetical. Film-only input is unaffected (`non_square` is all
  FALSE, so `fly_bearing()` is not called), which is why the suite is green.

  Either guard on usable values before calling, or make `fly_bearing()` NA-safe
  (`identical(rolls[i], rolls[i+1])` / `%in%`).

- **[fragile]** `R/fly_camera_format.R:134-136` vs `R/fly_footprint.R:460-461` — the
  `withheld:` diagnostic is computed and then thrown away.

  `fly_camera_format()` sets `width_source = "withheld:<key>"` for a refused
  calibration, but those rows have `resolved = FALSE` / `width_mm = NA`, so
  `from_table` is FALSE and `width_source[from_table] <- ...` never copies it.
  Reproduced with the two withheld medium-format keys:

  ```
  resolver width_source:  withheld:11937933_2009  withheld:12335326_2017
  footprint width_source: NA                      NA
  warning:                "... no known recording format (Digital - Colour) ...
                           see the `format_size` argument"
  ```

  The roxygen at `:257-258` states *"frames naming one are refused rather than
  inferred"* and `:255` that `width_source` traces every footprint to a source —
  neither is observable from the returned object. The user is told the camera is
  unknown when `fly` in fact holds a visually-read spec it deliberately declined to
  ship, which is a materially different situation and points them at the wrong fix.

- **[fragile]** `R/fly_footprint.R:160-169` (`fly_axis_aligned`) — the georef
  double-rotation guard tests a proxy, not the property.

  `fly_georef()` skips a frame when its ring is not axis-aligned, standing in for
  "was rotated onto its flight line". A bearing at an exact multiple of 90° produces
  a footprint that *was* rotated and *is* axis-aligned, so it is not skipped and
  `bearing_to_rotation()` applies the shift a second time — the exact
  landscape-onto-portrait failure the comment at `R/fly_georef.R:122-127` describes.
  The tolerance (`sqrt(eps) * max(abs(xy))` ≈ 1.5 cm at BC Albers magnitudes) makes
  this narrow, but the property is knowable exactly: `fly_footprint()` already knows
  which rows it rotated. Carrying that as a column (or reusing the
  `axis_aligned_no_bearing` marker already in `width_source`) removes the guess.

- **[fragile]** `R/fly_footprint.R:496` — `by_gsd` gates on `px_cross` only, then
  `:525` sets `terrain[by_gsd] <- "gsd_scaled"` unconditionally.

  A table row carrying `px_cross` but `NA` `px_along` would leave `half_along` NA at
  :498 → empty polygon at :128, while `footprint_terrain` claims `"gsd_scaled"`, i.e.
  a sized frame. Not reachable from today's shipped CSV (every `calib_file` row has
  both), and `test-camera_formats.R:65-66` only pins the *fallback* rows as NA —
  nothing asserts calib rows carry both. One `& !is.na(fmt$px_along)` closes it.

## Test gaps (assertions that cannot fail on the above)

- `tests/testthat/test-fly_camera_format.R:44-59` and `:62-78` are the only DEM
  tests on digital input, and both restrict themselves to `sized` rows / rows 1-4 —
  which are exactly the `by_gsd` rows. Nothing anywhere asserts that
  `digital_fixture()` row 5 (inferred format, the row the docs say *requires* a DEM)
  gets a footprint when a DEM is supplied. Adding
  `expect_false(sf::st_is_empty(sf::st_geometry(with_dem)[5]))` fails today.
- `tests/testthat/test-fly_camera_format.R:53` computes `sized` from the **no-DEM**
  run and then indexes the DEM run by it, so a DEM run that sizes strictly fewer
  frames than the flat run cannot be detected.
- `tests/testthat/test-fly_camera_format.R:145-156` covers the "columns absent" path
  only. There is no case with `film_roll` present and NA, which is the crash.
- `width_source` was not added to `fly_reported_cols()` (`tests/testthat/setup.R:159`),
  so the four-shape class sweep — including the DEM-path one at
  `test-fly_footprint.R:692-716`, which is where #35 actually lived — never compares
  its values. The replacement at `test-fly_camera_format.R:176-189` sweeps two shapes
  on the flat path only, and its loop compares `out$plain` against itself for the
  `plain` element.

## Verified correct (checked, no action)

- Rotation matrix `R/fly_footprint.R:145`: `xy %*% rot` sends `(0,1)` to
  `(sin b, cos b)`. Confirmed numerically against a returned ring at bearing 270.5° —
  the along-track edge lies along the heading and the long cross-track edge is
  perpendicular. Vertex order BL/BR/TR/TL/BL is preserved through the rotation.
- `bearing` row alignment: `fly_bearing()` writes via `bearing[ord[i]]`, i.e. back
  into input row positions, and `coords` comes from `st_transform(centroids_sf)` with
  no reordering. Aligned.
- The `!by_gsd` gate at `:581`/`:645` works as intended: with a DEM supplied, GSD-sized
  frames keep byte-identical areas and `dem_coverage`/`height_agl` stay NA.
- Film output is bit-identical to before, including in a mixed film+digital frame
  (geometry `all.equal` TRUE, areas TRUE), and `fly_axis_aligned()` survives the
  3005 → 4326 → 3005 round trip.
- `take()`'s `<<-` in `R/fly_camera_format.R:100-109`: `rows` is a length-`n` logical
  and `from` has `sum(rows)` rows in both call sites; `matched` / `refused` / `digital`
  are all length `n` and consistently derived from `key`. No length or index
  disagreement found.
- Zero-row input: `fly_footprint(x[0, ])` returns character-typed reporting columns
  and does not error; `paste0("withheld:", character(0))` assigns into a zero-length
  subscript harmlessly.
- Round-1 fixes spot-checked and correct: the `excl()` empty-key guard, the unzip
  guard on PDF presence rather than directory existence, the excluded-table lookup in
  the resolver, `FALLBACK_EXTRAPOLATE` as an opt-in property with a stale-entry check,
  the `!is.na()`-before-`any()` on `focal_disagrees`, the modal-width index selection
  (with an `is.na(w)` backstop for the `%in%` reparse), and the `focal_mm` bound in
  check D.
