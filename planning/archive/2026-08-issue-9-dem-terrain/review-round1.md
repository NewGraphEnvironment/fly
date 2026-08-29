# fly #9 — `dem` argument review (round 1)

Reviewed: `/tmp/cc9/diff.txt` (git diff main...HEAD) against the current tree at
`e5c597c`. Every claim below was reproduced against the real package and the
bundled fixtures (`pkgload::load_all()`, terra 1.9.34); probe scripts are in
`/tmp/cc9/probe*.R`.

Suite is green as it stands: `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 185 ]`.
The measured claims in NEWS/docs all check out — median area change 14.11%,
max 27.17%, centroid-vs-footprint-mean elevation difference 130 m exactly as
stated.

## Findings

---

### 1. **[bug]** Partial DEM coverage is silently averaged and reported as fully corrected

`R/fly_footprint.R:42` (`fly_dem_elevation` → `sample_at`), classification at
`R/fly_footprint.R:317`.

```r
terra::extract(dem, v, fun = mean, na.rm = TRUE)[, 2]
...
uncovered <- sized & !corrected & is.na(elev)
```

`terra::extract()` never returns cells outside the raster extent, and
`na.rm = TRUE` discards NA cells inside it. So a footprint rectangle that is only
*fractionally* covered by the DEM returns a perfectly ordinary non-NA mean —
computed over whatever sliver happened to be there. `is.na(elev)` is the **only**
detection of missing coverage, and it can only be TRUE when the centroid sample
(pass 1) is NA or the rectangle misses the DEM entirely. Partial coverage is
therefore indistinguishable from full coverage, and the guard fails toward
"pass".

This directly contradicts the shipped contract. `R/fly_footprint.R:201-204`:

> a DEM that stops short of the frame edges sends those frames down the
> `no_dem_coverage` fallback. Buffer the AOI by at least half the widest footprint.

and the vignette repeats it verbatim ("a DEM that stops short of the frame edges
sends those frames to the `no_dem_coverage` fallback"). Neither is true. The
"buffer generously" advice is presented as the remedy for a fallback that cannot
fire, so a user who *doesn't* buffer gets silently biased elevations rather than
the documented, visible degradation.

**Reproduced** (`/tmp/cc9/probe11.R`) — DEM clipped to a 1 km box around one
1:31680 centroid, i.e. **0.98 km² of a 52.4 km² frame (1.9% coverage)**:

```
warnings: 0
footprint_terrain: dem_agl
height_agl: 5180.8          # averaged over 1.9% of the frame
height_agl with full DEM: 5220.4
area km2 clipped-dem: 59.92   full-dem: 60.84
```

**It is already live in the shipped fixture.** `/tmp/cc9/probe3.R` measures the
valid-DEM fraction under each of the 20 bundled footprints:

| frame | scale | frac of rectangle with valid DEM |
|---|---|---|
| 14 | 1:31680 | 0.982 |
| 16 | 1:31680 | 0.964 |
| 18 | 1:31680 | 0.981 |
| other 17 | — | 1.000 |

All three are reported `dem_agl` with no warning. The `data-raw/make_testdata.R`
comment claims the 4 km buffer prevents exactly this ("Without the buffer, edge
frames would sample NA and fall back to nominal scale — which the fixture exists
to exercise the *absence* of"). The arithmetic is off: a **square** of half-side
3621 m reaches 3621 × √2 = **5121 m** at its corners, not 3621 m, so a 4 km
buffer cannot contain it. The buffer needs `half_side * sqrt(2)`, i.e. ≥ 5.2 km
here — and the docs' "half the widest footprint" advice has the same error.

Note the bundled `dem.tif` bounding box is **47% NA** (the EPSG:3979 crop
rectangle reprojected to 3005 is rotated ~24°, so the box corners are empty) —
NA cells under a footprint are not an exotic case in this fixture.

**Fix options** — either makes the documented behaviour real:

```r
sample_at <- function(geom) {
  v <- terra::vect(sf::st_transform(geom, dem_crs))
  m <- terra::extract(dem, v, fun = mean, na.rm = TRUE)[, 2]
  frac <- terra::extract(!is.na(dem), v, fun = mean, na.rm = TRUE)[, 2]
  ifelse(is.na(frac) | frac < 1, NA_real_, m)   # or a documented threshold
}
```

or drop `na.rm = TRUE` on the polygon pass so any NA under the rectangle
propagates. Whichever you pick, the fixture cannot currently detect the
regression (all its DEM-covered frames sit at ≥0.964), so the test needs a
deliberately-short DEM — `probe11.R` is a ready-made one.

---

### 2. **[bug]** Two of the five passthrough tests cannot detect a dropped `dem`

`tests/testthat/test-fly_terrain_passthrough.R:38, 42` (`fly_filter`) and
`:50, 57` (`fly_select`, both modes).

The file's header states the contract explicitly:

> Each test therefore asserts the numbers actually MOVE, not merely that the
> argument is tolerated.

For `fly_filter` and `fly_select` that is false. The assertions are non-strict —
`expect_gte(nrow(terr), nrow(flat))`, `expect_lte(nrow(min_terr), nrow(min_flat))`,
`expect_true(all(flat$airp_id %in% terr$airp_id))` — and on the bundled data both
sides are **identical**, so equality is what they actually observe
(`/tmp/cc9/probe4.R`):

```
filter flat: 20  terr: 20
select all flat: 10  terr: 10
select min flat: 10  terr: 10
```

**Restore-the-bug check** (`/tmp/cc9/probe5.R`) — `fly_footprint` patched in both
`asNamespace("fly")` and `as.environment("package:fly")` to discard `dem`,
simulating a passthrough that was never wired:

```
1. Failure fly_coverage  passes dem through   <- caught
2. Failure fly_overlap   passes dem through   <- caught
3. Failure fly_georef    passes dem through   <- caught
   fly_filter            PASSED               <- not caught
   fly_select            PASSED (both modes)  <- not caught
```

So deleting `dem = dem` from `R/fly_filter.R:478`, `R/fly_select.R:632` and
`R/fly_select.R:690` would leave the suite green.

**Fix:** assert on a quantity that actually moves. Total footprint area of the
returned set works for both (`fly_filter` returns points, so compute it from
`fly_footprint()` on the result), or reuse the `fly_georef` trick already in this
file — strip `flying_height` and `expect_error(..., "flying_height")`, which can
only pass if `dem` reached `fly_footprint()`.

---

### 3. **[fragile]** One NA cell under the centroid condemns the whole frame, with a misleading warning

`R/fly_footprint.R:44-51`.

Pass 1 samples a **single point**. If that one 30 m cell is NA, `ok` is FALSE, the
footprint-mean pass never runs, and the frame is classified `no_dem_coverage` and
falls back to nominal scale — even if 99% of its rectangle has good data. Given
the bundled DEM's bbox is 47% NA, that is a reachable state, not a hypothetical.

This is the safe failure direction (fallback, not silent bias), so it is not
finding 1's severity. But the warning text — "frames fall outside the DEM's
coverage" — misdescribes what happened, which sends the user to widen a DEM that
is already wide enough. Consider falling through to the polygon pass whenever the
provisional rectangle is non-empty, and only declaring `no_dem_coverage` on the
polygon result.

---

### 4. **[fragile]** A frame with an empty geometry can be labelled `footprint_terrain = "nominal_scale"`

`R/fly_footprint.R:296` seeds `terrain` from `is.na(width_in)`, but the
sized/unsized decision at `:301` is `!is.na(half_side)`, and
`half_side = width_in * scale_num * ...`. A frame with a resolvable `media` but an
unparseable `scale` has `width_in` non-NA and `scale_num` NA — so it gets an empty
geometry while claiming a terrain treatment was applied.

Documented contract at `R/fly_footprint.R:175`: `NA` = "no footprint to place".

**Reproduced** (`/tmp/cc9/probe12.R`):

```
      basis       terrain      agl empty
1 Film - BW       dem_agl 1986.315 FALSE
2 Film - BW nominal_scale       NA  TRUE     <- empty geometry, non-NA terrain
```

**Fix:** seed from the half-side, which is the thing that decides whether a
polygon exists — `terrain <- ifelse(is.na(half_side), NA_character_, "nominal_scale")`
(move the line below `half_side`). Untested today in either direction.

---

### 5. **[fragile]** Examples and vignette call a Suggests-only package unconditionally

`R/fly_footprint.R:223` (`@examples`) and `vignettes/airphoto-selection.Rmd`
chunks `terrain-compare`, `fig-terrain`, `terrain-basis`.

`terra` is in Suggests (correctly), and `rlang::check_installed()` **errors** in a
non-interactive session. So `R CMD check` and the pkgdown build fail outright on
any environment without terra, rather than skipping. The tests get this right via
`skip_if_no_terra()`; the examples and vignette do not.

`@examplesIf requireNamespace("terra", quietly = TRUE)` on the terrain block, and
`eval = requireNamespace("terra", quietly = TRUE)` on those three chunks, closes
it. Low priority while CI installs Suggests, but it is a hard failure when it
fires, not a NOTE.

---

## Checked and clean

- **Vector alignment through the DEM path.** `elev[sized] <- fly_dem_elevation(...)`,
  `elev[ok] <- sample_at(provisional[ok])`, `half_side[corrected] <- candidate[corrected]`
  are all consistently subset; `terra::extract()` was verified to return exactly
  one row per input geometry in input order, including geometries entirely
  outside the raster (`/tmp/cc9/probe1.R`, `nrow(res) = 3` for 3 polygons).
- **Zero-length / NA classification.** `corrected` / `uncovered` / `unusable`
  partition `sized` exhaustively; `NaN` from `mean(numeric(0))` is caught by
  `is.na()`; NA `flying_height`, NA and zero `focal_length` all land in `unusable`
  and keep their nominal footprint, as the tests assert.
- **Unit arithmetic.** `width_in * (agl / focal_m) * 0.0254 / 2` with `focal_m =
  focal_length/1000` reduces to the nominal form when `agl/focal_m == scale_num`.
  Verified numerically: 2591 m ASL − ~620 m terrain over 0.153 m → 12882 vs a
  nominal 12000, i.e. +7.3% linear / +15% area, matching the measured median.
- **CRS handling.** `sf::st_crs(terra::crs(dem))` then transform-per-sample is
  correct; `fly_rectangles()` stamps 3005 and the result is transformed back to
  `input_crs`. No `st_join(largest=)` or bbox-corner reprojection anywhere.
- **terra traps.** `data-raw/make_testdata.R:617` correctly uses
  `terra::minmax(dem_clip, compute = TRUE)`. No `%in%` on a SpatRaster (the
  import-vs-attach S4 dispatch trap), no bare `terra::freq()`.
- **Backwards compatibility.** `dem` is appended last in every signature
  (`fly_footprint`, `fly_coverage`, `fly_overlap`, `fly_filter`, `fly_select`,
  `fly_georef`), so no positional caller breaks. `fly_select_all(photos_sf,
  aoi_sf, dem)` and `fly_select_minimal(..., dem)` match their definitions
  positionally.
- **`expect_match(..., all = FALSE)` on a possibly-empty vector** — every use is
  preceded by `expect_gt(length(w), 0)`. Correct.
- **`fly_footprint(dem = NULL)` is byte-identical to the old path** — the
  refactor into `fly_rectangles()` preserves the NA-half-side → empty-polygon
  contract, and the regression test asserts it.
- **`data-raw/make_testdata.R` reproducibility.** `terra::crop()` does not mask
  (verified, `/tmp/cc9/probe8.R`); the committed `dem.tif`'s non-rectangular
  valid region is the reprojected EPSG:3979 crop rectangle, consistent with the
  script. No generator/artifact drift.
