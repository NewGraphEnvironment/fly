# Review — #53 Phase 2, round 1 (staged diff: R/fly_rotation_calibrate.R + tests)

Checked and found correct: the leg rule (10 deg against the run's first step, 1.5x against the
run's median spacing, >= 6 frames, median bearing >= 15 deg off cardinal, central 11 with
5:15 for a 20-frame leg), the sign-test thresholds (pbinom(wins - 1, n, .5, upper) gives
exactly 5/5, 6/6, 7/7, 7/8, 8/9, 9/10; under 5 never), the roll-state order for every state
the rule defines, the circular bearing spread, max_legs ordering (longest, then first frame),
legs not sharing frames across a leg-change step, and bcdc_sf tibble input (probed through
`fly_rotation_calibrate()` with the scorer mocked: subsetting, `photos_sf$film_roll == roll`
with NA rolls, and `frames %in% keep` all behave; the bundled and catalogue `frame_number`
is integer). Band layouts: every output `georef_one()` can write from a 1- or 3-band
thumbnail is 2 or 4 bands with alpha last, which `fly_rotation_luminance()` handles.

## Findings

- **[bug] R/fly_rotation_calibrate.R:317-320** — `fly_rotation_score_leg()` writes each trial
  GeoTIFF to `file.path(dest_dir, "r<rot>", "<j>.tif")` without removing an existing file, and
  `sf::gdal_utils("warp")` opens an existing destination and warps INTO its grid rather than
  replacing it. Probed: warping a raster, then a copy shifted 5 km east, to the same output
  path leaves the extent at the first raster's (0-1000 both times). So any re-run into a
  persistent `dest_dir` where the footprint for slot `j` has changed — a code change to the
  footprint, a different input subset moving a leg's central 11 (slots are numbered by
  position, not frame), a changed `mask`/`mask_threshold` (old pixels survive wherever the new
  alpha is 0) — silently scores frames clipped to a stale grid and still returns `"scored"`.
  This is the expected use, not a corner case: `fly_fetch()` caches thumbnails under the same
  `dest_dir`, which invites a persistent directory, and the (untracked)
  `data-raw/georef_calibrate-film_rotations.R` passes `file.path(IMG_DIR, roll)` under
  `.cache/` and runs controls into fixed `IMG_DIR/control_*` paths. Fix: `unlink(o)` before
  `georef_one()`.

- **[fragile] R/fly_rotation_calibrate.R:318-335** — a leg whose warps failed is reported as
  measured. `georef_one()` returning FALSE or erroring (e.g. a thumbnail that downloaded with
  `success = TRUE` but GDAL cannot read, so `fly_gdal_dim()` is NULL) makes that rotation NA;
  one such frame NAs all four rotations, and the leg still returns `status = "scored"` with an
  all-NA matrix. `fly_rotation_leg_row()` then gives no verdict, and the roll lands in
  `no_decisive_leg` ("legs were scored and none decided") — a failed measurement recorded as an
  evidential non-decision in the campaign ledger. Relatedly, the pre-registered rule removes
  from competition only "a rotation refused by the stretch guard"; the code removes a rotation
  on any error too. On a square film footprint the guard can never refuse, so on film every
  NA column is an error, not a refusal.

- **[fragile] R/fly_rotation_calibrate.R:289-291** — fall-through to `no_decisive_leg` when legs
  exist but none was scored and none is `thumbnails_unavailable` (all `not_rotated`, or all
  `not_scored` under `max_legs = 0`). Probed: `status = c("not_rotated", "not_scored")` returns
  `"no_decisive_leg"`, which the rule defines as ">= 1 leg scored, none decisive". `not_rotated`
  is reachable from the top-level path: a frame with an unknown format draws an EMPTY footprint,
  which the squareness check at line 93-94 deliberately lets through (`drawn` excludes it), and
  `fly_rotation_score_leg()` then finds a non-finite `footprint_bearing`.

- **[fragile] R/fly_rotation_calibrate.R:109,132** — when no row has a usable `film_roll`, `rolls`
  is empty and `dplyr::bind_rows(list())` returns a 0 x 0 tibble with no columns (probed). The
  documented join `roll$rotation <- cal$rotation[match(...)]` then assigns `NULL`, silently
  creating no column, and `cal[, c("film_roll", "rotation", "state")]` errors. Low reach (input
  with every roll NA), but it is the zero-length case the convention names.
