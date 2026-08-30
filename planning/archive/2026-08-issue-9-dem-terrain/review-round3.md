# fly #9 — DEM terrain-adjusted footprints, review round 3

Baseline: `devtools::test()` → `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 201 ]`.
`devtools::document()` is clean and leaves no diff (no roxygen rebinding, no NAMESPACE churn).
`man/`, `inst/testdata/dem.tif` and the planning archive are all committed (they were absent
from the supplied `diff.txt` only because it was filtered).

## Findings

### 1. [bug] R/fly_footprint.R:65 — `expected` mixes m² with degree², so `dem_coverage` is garbage and the 95% guard false-alarms on every frame of a geographic DEM

```r
expected <- as.numeric(sf::st_area(in_dem)) / prod(terra::res(dem))
```

`in_dem` is the footprint reprojected into the **DEM's** CRS. When that CRS is geographic,
`sf::st_area()` returns **m²** (geodesic) while `terra::res()` returns **degrees**. The two
sides of the division are in different units and the quotient is off by ~10 orders of
magnitude. `pmin(1, ...)` cannot help — the error points the wrong way.

Measured, bundled AOI, `d43 <- terra::project(dem, "EPSG:4326")`:

```
DEM CRS      dem_coverage range          warnings
EPSG:3005    0.9945 – 1.0000             0            (shipped fixture)
EPSG:3979    0.9997 – 1.0000             0
EPSG:32609   0.9997 – 1.0000             0
EPSG:4326    1.38e-10 – 1.40e-10        "20 of 20 corrected frames are less than 95%
                                         covered by the DEM (as little as 0% ...)"
```

The footprints themselves are still right (area ratio 4326-DEM vs 3005-DEM is 0.9991–1.0002),
so nothing looks broken from the geometry. What breaks is the column and the guard:

- **`dem_coverage` is meaningless.** The documented workflow — *"`dem_coverage` reports the
  fraction per frame … so a truncated footprint can be filtered rather than merely noticed"* —
  drops all 20 frames.
- **The 95% guard fires on all 20 fully-covered frames.** The comment above
  `fly_dem_coverage_min()` says a guard that noisy "stops being read", and it is now noise on
  every geographic DEM. Once it is noise, a genuinely truncated frame is indistinguishable
  from a fine one, which is the failure round 2 introduced this measure to prevent.
- Confirmed identical through `fly_coverage()` (i.e. with `sf_use_s2(FALSE)` in force), so
  the s2 setting is not a mitigation.

This is not an exotic input. The roxygen says *"Any raster `terra` can open works"*, and
EPSG:4326 is the default delivery CRS for SRTM, Copernicus DEM, ALOS, the AWS terrain tiles
and `elevatr::get_elev_raster()` on a lon/lat AOI. The three sources the docs recommend
(MRDEM-30 / LidarBC / TRIM) all happen to be projected, which is why nothing showed.

**Why the fixture could not reach it:** every DEM in the suite is `inst/testdata/dem.tif`
(EPSG:3005) or a `terra::crop()`/`aggregate()` of it. There is no test with a DEM in *any*
other CRS, so `sf::st_transform(..., sf::st_crs(terra::crs(dem)))` at line 51 is an identity
in 100% of the test suite — the entire reprojection branch of `fly_dem_sample()` is unexecuted
code, and the units assumption behind line 65 was never put to a case that could disagree.

**Fix** — measure the polygon's area in the DEM's own CRS units rather than as a geodesic
area, so both sides of the division use the same units:

```r
expected <- as.numeric(sf::st_area(sf::st_set_crs(in_dem, NA))) / prod(terra::res(dem))
```

Verified: unchanged for projected DEMs; the 4326 case becomes `0.9966 – 1.0000` with no
warning. Pair it with a test that runs the suite's coverage assertions against
`terra::project(dem, "EPSG:4326")` — that single fixture also brings the reprojection branch
under test for the first time.

---

### 2. [fragile] R/fly_footprint.R:411 — the partial-coverage warning tells the user to buffer by *half* the widest footprint, which is the under-buffering round 1 corrected

```r
"represent the whole. Buffer the DEM by at least half the widest ",
"footprint. See `dem_coverage`.",
```

Every other statement of this rule in the package says the opposite:

| location | advice |
|---|---|
| `R/fly_footprint.R:237` (roxygen) | "Buffer past the **corner** of the widest footprint, not its half-side … 5.1 km rather than 3.6 km" |
| `man/fly_footprint.Rd:154` | same |
| `vignettes/airphoto-selection.Rmd:361` | same |
| `data-raw/make_testdata.R` | buffers 5.4 km for a 3.62 km half-side, with a comment saying why half-side is wrong |
| **the warning a user actually sees** | "at least half the widest footprint" |

A half-side buffer leaves all four corners of every edge frame over no-data — that is the
round-1 finding, and it is the exact condition this warning fires on. So a user who follows
the remediation the warning gives them re-triggers the warning, and the one place the
guidance is delivered at the moment it is needed is the one place it is wrong. Same
stale-claim class as round 2's three doc fixes; this one is user-facing at runtime rather
than in the manual.

Suggested text: `"Buffer the DEM past the corner of the widest footprint (half_side * sqrt(2))."`

---

### 3. [fragile] tests/testthat/test-fly_footprint.R:415-419 — the premise assertion is a tautology, and the premise it claims is false

```r
# The fixture must actually reach the failure mode: no NA interior to count.
expect_equal(
  as.numeric(terra::global(tight, function(x) sum(is.na(x)))[1, 1]),
  as.numeric(terra::global(terra::crop(full, tight), function(x) sum(is.na(x)))[1, 1])
)
```

`tight` is `terra::crop(full, <buffered centroids>, snap = "out")`. `terra::crop(full, tight)`
crops `full` to `tight`'s extent on `full`'s own grid — which is `tight`. Measured: both sides
return **6190**, extents identical. The two arguments are the same raster by construction, so
the assertion holds for any fixture, any crop, any DEM. It cannot fail.

The claim in the comment is also not true: `tight` has **6190 NA cells** of 360126, so it is
not "no NA interior". What is actually true — and what makes the fixture valid — is that none
of those NAs fall *inside a footprint*, so the round-1 measure sees nothing to count. Measured
on this fixture:

```
round-1 measure (non-NA share of returned cells): min 1.0000,  n < 0.95 = 0
shipped measure (got / expected):                 min 0.5621,  n < 0.95 = 6
```

So the **regression test itself is sound** — it does discriminate the round-2 fix from the
round-1 bug, and I confirmed that before writing this. Only the premise guard is decoration.
That matters because the guard is the thing protecting the discrimination: if someone later
widens the 500 m buffer, or the bundled DEM is re-cut with a different NA margin, NA cells
could start landing inside the footprints and the test would silently revert to passing for
the round-1 reason. Assert the property that is load-bearing instead:

```r
cells <- terra::extract(tight, terra::vect(sf::st_sf(geometry = <the nominal rects>)))
expect_equal(min(vapply(split(cells[, 2], cells[, 1]), function(x) mean(!is.na(x)), 0)), 1)
```

or, more cheaply, assert directly that the shortfall is invisible to the old measure.

---

## Checked and clean (recorded so round 4 does not re-spend on them)

- **`pmin(1, got / expected)` — measured, does not hide a real shortfall.** Uncapped ratios on
  the bundled 30 m DEM run 0.992–1.0158, so the cap eats ≤1.6% against a 5% threshold. Pushed
  to a deliberately hostile ratio (DEM aggregated to 487 m, footprint 5.6 cells across, frame
  walked east from the data edge) the measure errs **low** at every offset — measured 0.331 /
  0.464 / 0.619 / 0.771 / 0.818 / 0.859 / 0.864 against true 0.391 / 0.508 / 0.648 / 0.766 /
  0.851 / 0.902 / 0.932. Failure direction is false alarm, never false pass. No finding.
- **`split(cells[, 2], cells[, 1])` alignment.** `terra::extract()` returns an `NA` row for a
  polygon wholly outside the raster extent (verified), and for a polygon that becomes **empty**
  under `st_transform` (the `focal_length = 0` → `Inf` half-side case, verified against a 3979
  DEM where the Inf ring collapses to zero coordinates). `terra::vect()` keeps the row in both
  cases, so `per_frame` is always `sum(ok)` long and `elev[ok] <- vapply(...)` cannot misalign.
  Factor-level ordering is numeric, verified past 10 (`1, 2, 10, 11`). No finding.
- **Anisotropic / non-3005 projected DEMs** (3979, 32609): `st_area` and `res` agree in units,
  coverage 0.9997–1.0000, no warnings. Only the *geographic* case breaks (finding 1).
- **Branch consistency of the three new columns.** All six reachable states are coherent:
  no-dem/sized → `nominal_scale` / NA / NA; no-dem/unsized and dem/unsized → NA / NA / NA;
  corrected → `dem_agl` / value / value; uncovered → `no_dem_coverage` / NA / **0**;
  unusable → `nominal_scale` / NA / measured value. `sized` is captured before
  `half_side[corrected]` is overwritten, so the ordering is right. `resize()` does not consult
  `scale`, but `corrected` is gated on `sized`, so an unparseable scale cannot acquire a
  footprint through the DEM path (test at line 396 covers it).
- **Every `expect_match(w, ..., all = FALSE)` is preceded by `expect_gt(length(w), 0)`** — the
  vacuous-on-`character(0)` trap is closed in all five instances.
- **Reported-vs-sampled rectangle.** `dem_coverage` describes the 2nd-pass rectangle while the
  returned footprint is the 3rd. Difference is the documented <0.02% convergence residual.
  Not worth reporting.
- **`fly_georef` / `fly_select` / `fly_filter` / `fly_coverage` / `fly_overlap` passthrough.**
  `dem` is appended last in every signature (no positional breakage), and
  `fly_select_all(photos_sf, aoi_sf, dem)` matches its formals. The two call sites inside
  `fly_select` are each asserted separately.
- **`.Rbuildignore`** now excludes `planning` and `Rplots.pdf`; `man/` and `dem.tif` are tracked.

## Minor, non-blocking

- `@return` says `dem_coverage` is `"NA` only where there is no footprint"`, but with
  `dem = NULL` it is `NA` for every row including well-formed footprints (asserted by the test
  at line 340). The sentence is true only when a DEM was supplied; it reads as a general claim.
