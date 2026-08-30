# fly #9 — terrain-adjusted footprints, code review round 2

Reviewed `git diff main...HEAD` (branch `9-dem-based-terrain-adjusted-footprints`,
HEAD `ff7b217`) against `/tmp/cc9/checklist.md`. Probes run against the real
package with `pkgload::load_all()`, terra 1.9.34 / sf 1.1.2 / R 4.5.2.

## Verification of the round-1 fixes

| round-1 finding | status |
|---|---|
| 1. partial DEM coverage reported as full | **incomplete** — see Finding 1 |
| 2. passthrough tests could not detect a dropped `dem` | **correct** — verified by restoring the defect |
| 3. centroid gate condemned well-covered frames | correct in code; **stale docs left behind** — Finding 2/3 |
| 4. `footprint_terrain` keyed on `width_in` | correct |
| 5. unguarded `terra` in example/vignette | correct |
| test DEM re-buffered 3.6 km → 5.4 km | correct (`ext` is 36.8 × 33.4 km) |

Fix 2 restoration check, per the checklist's "patch **both** bindings" rule —
`asNamespace("fly")` **and** `as.environment("package:fly")` patched with a
`fly_footprint()` that discards `dem`, proof line printed on every call:

```
[ test-fly_terrain_passthrough.R ]  6 failures across all 5 tests
  fly_coverage :25   fly_overlap :38   fly_filter :64
  fly_select   :94, :95              fly_georef :123
```

All five passthrough tests genuinely fail when `dem` is dropped. The header
comment's claim is accurate.

Baseline suite: `FAIL 0 | WARN 0 | SKIP 0 | PASS 194`. `devtools::document()`
produces no diff; `NAMESPACE` untouched, 9 exports, `export(fly_footprint)`
intact (checklist: roxygen-block rebinding — the three new helpers were inserted
above the block, which is the safe side).

Vector alignment in `fly_dem_sample()` checked directly and is **sound**:
`terra::extract()` returns exactly one row per input polygon even when the
polygon is entirely outside the raster (`ID`, `NA`), and for a degenerate
zero-area polygon, so `split()` always yields `length(rects[ok])` groups.
`split()` keys sort numerically past 9 (`1 2 … 10 11 12`), so `vapply()` comes
back in `rects[ok]` order. `elev[is.nan(elev)] <- NA_real_` correctly converts
the all-NA `mean(na.rm = TRUE)` result.

The first-pass fallback `ifelse(is.na(second$elev), first$elev, second$elev)` is
right, and I could not break it. A negative pass-2 half-side (terrain above
aircraft) builds a mirror-image rectangle of the same size — valid, same
elevation, and the frame is then classified `unusable` anyway. An infinite
pass-2 half-side (`focal_length == 0`) does **not** error: `sf::st_transform()`
and `terra::extract()` both tolerate `Inf` corners, returning `covered = 0` and
`elev = NA`, so the frame falls back to `first`, then to `unusable`. Both
confirmed by probe.

---

## Findings

### 1. **[bug]** `R/fly_footprint.R:58` — `dem_coverage` cannot see area beyond the DEM's *extent*, so the round-1 guard does not fire on the case it exists for

`covered[ok] <- vapply(per_frame, function(x) mean(!is.na(x)), numeric(1))`
is the fraction of the cells `terra::extract()` **returned** that carried a
value. Cells outside the raster's extent are never returned at all — they are
not `NA` rows, they simply do not exist — so a footprint hanging off the edge of
the raster reports `covered = 1`.

Minimal reproduction:

```r
r <- terra::rast(nrows=10, ncols=10, xmin=0, xmax=100, ymin=0, ymax=100, crs="EPSG:3005")
terra::values(r) <- 1:100
# square centred at (5,50), half-side 20 -> ~half its area lies west of xmin
terra::extract(r, v)      # 12 rows, none NA  ->  mean(!is.na(x)) == 1
```

The guard therefore detects only NA cells *inside* the extent — the reprojection
slivers. That is the one case the bundled fixture happens to exercise, because
`inst/testdata/dem.tif` is a reprojected clip whose extent holds 621,069 NA
cells out of 1,328,580 (47%). This is the checklist's "a fixture set that cannot
reach the failure mode is not validation": the two new tests
(`test-fly_footprint.R:314`, `:331`) pass, and neither can reach the real
failure.

The real failure is the *ordinary* user path — clip a DEM to the AOI, which is
what `flooded::fl_dem_aoi()` and any `bcdata get-dem` / STAC fetch returns.
Measured against the bundled 20 frames, comparing the AOI-clipped DEM to the
properly buffered one:

```
warnings raised:        0
dem_coverage reported:  1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1   (min = 1)
footprint_terrain:      dem_agl  x20
height_agl error (m):   0 -11.8 0 0 0 0 0 0 12.5 0 0 26.0 -0.4 50.6 24.0 -7.1 0 100.4 0 0
footprint area error:   up to 4.00%
```

A frame sized from a quarter of its own footprint is delivered as `dem_agl`,
`dem_coverage = 1`, no warning — which is exactly the "silently reported as a
full correction" defect round 1 asked to fix, moved one step outward. Worse than
the pre-fix state in one respect: `dem_coverage = 1` now carries an affirmative
claim of completeness.

Fix: `covered` must be measured against the polygon's own area, not against what
came back. Either

```r
expected <- as.numeric(sf::st_area(rects[ok])) / prod(terra::res(dem))
covered[ok] <- vapply(per_frame, function(x) sum(!is.na(x)), numeric(1)) / expected
```

(the CRS is the DEM's after `st_transform`, so area and `res()` agree), or
`terra::extend(dem, <union of rect extents>)` before extracting so out-of-extent
cells materialise as `NA`. Clamp at 1 for rounding either way.

Then give the test a fixture that can reach it — a DEM cropped so its **extent**
stops inside the footprint, not merely one with NA cells:

```r
small <- terra::crop(dem, terra::ext(xmin(dem)+20000, xmin(dem)+30000,
                                     ymin(dem)+20000, ymin(dem)+30000))
# 1:31680 frame centred on small's west edge -> currently coverage 1, no warning
```

I confirmed that fixture returns `dem_coverage = 1` with zero warnings today,
and 3/4-off-the-corner likewise.

---

### 2. **[bug]** `R/fly_footprint.R:215-217` and `vignettes/airphoto-selection.Rmd:352-354` — the Terrain docs still describe the centroid gate that round-1 fix 3 removed

Both read:

> `no_dem_coverage` catches only a frame whose *centroid* has no elevation; a
> frame whose centroid is covered and whose edges are not is still corrected…

The code has no centroid test any more. `uncovered` is
`sized & !corrected & is.na(elev)`, and `elev` is the mean over the *whole*
rectangle — so `no_dem_coverage` now means "no cell anywhere under the footprint
had a value", and a frame whose centroid sits on a hole is corrected normally
(there is a test for precisely that, `test-fly_footprint.R:394`).

This is not cosmetic staleness: it is the paragraph a user reads to decide how
far to buffer their DEM, and it tells them the centroid is the thing that
matters. Together with Finding 1 it points them at the wrong failure mode
entirely — the case the prose says is caught silently is not, and the case it
says is safe is the dangerous one. `man/fly_footprint.Rd` carries the same text
onto the pkgdown site.

---

### 3. **[bug]** `NEWS.md:6` — the release note describes the pre-fix sampling scheme and contradicts the roxygen

> Elevation is sampled twice — **at the centroid**, then as the mean under the
> resulting rectangle

Pass 1 has averaged over the nominal-scale rectangle since the round-1 fix.
`R/fly_footprint.R:174` states it correctly ("the mean under the whole
footprint, not a reading at the centroid") and the two now disagree in the same
release. NEWS is the user-facing description of what 0.5.0 does.

---

### 4. **[fragile]** `R/fly_footprint.R:346-348` — `dem_coverage` is `NA` on every non-corrected branch, including where its true value is known

`dem_coverage[corrected] <- covered[corrected]` leaves `NA` for `uncovered`,
`unusable`, and unsized frames. For `no_dem_coverage` the value is known and is
`0` — the DEM covered none of that footprint — so `NA` ("not measured") is
weaker than what the code established. Verified:

```
terrain            height_agl  dem_coverage
dem_agl            1984.9      1
no_dem_coverage    NA          NA        <- true coverage is 0
nominal_scale      NA          NA        (unusable metadata; coverage known)
```

Consequence for the workflow the docs recommend — "`dem_coverage` reports the
fraction per frame, so a partially-sampled footprint can be filtered rather than
merely noticed": a caller filtering `dem_coverage >= 0.95` gets `NA` for the
uncorrected frames (an all-`NA` row under base `[` subsetting, dropped under
`dplyr::filter()`), and — because of Finding 1 — a clean `1` for the frames that
are genuinely truncated. The column cannot presently support the filter it is
documented for. Fixing Finding 1 addresses the second half; assigning `0` for
`uncovered` addresses the first.

`footprint_terrain` and `height_agl` are otherwise mutually consistent across
every branch I could construct (corrected / uncovered / unusable / partial /
unparseable scale / unknown format / all-frames-uncovered), each checked by
probe.

---

## Checked and clean

- Alignment, `split()` ordering, NaN/NA handling in `fly_dem_sample()` (above).
- `fly_rectangles()` NA → empty polygon; `Inf` and negative half-sides do not
  crash and land on the right fallback branch.
- `terrain <- ifelse(is.na(half_side), …)` is computed before
  `half_side[corrected] <- candidate[corrected]`, so the ordering is right.
- `resize()` closes over `width_in`, `centroids_sf$flying_height`,
  `centroids_sf$focal_length` — all row-aligned with `pts_3005`/`coords`.
- `corrected <- sized & is.finite(candidate) & candidate > 0` classifies on the
  value actually used, which is the right side of the checklist's "measure the
  output, not the input you handed in".
- `rlang` is in Imports; `terra` is reached only behind
  `rlang::check_installed()`, guarded in `@examples`, and guarded per-chunk in
  the vignette (`eval = requireNamespace("terra", quietly = TRUE)`).
- Positional `fly_select_all(photos_sf, aoi_sf, dem)` lands on the third formal
  `dem = NULL`. Correct.
- `data-raw/make_testdata.R` — `test_photos` is in scope at line 158; the 5.4 km
  buffer clears `half_side * sqrt(2)` = 5.12 km plus the ~25% enlargement.
- `.Rbuildignore` gains `^planning$` and `^Rplots\.pdf$`; `planning/` stays
  tracked in git (checklist requires this).
- Zero-length guards: no `paste0()`/tibble row-builder fed a possibly-empty
  vector in the new code; `st_area()` is not summed per-group here.
- No shell scripts, no secrets, no network calls in package code (the only
  network step is `data-raw/`, documented as such at the top of the file).
