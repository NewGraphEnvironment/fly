# fly — code review round 4

Scope: `fly_dem_sample()` and the `dem` block of `fly_footprint()` in
`/Users/airvine/Projects/repo/fly/R/fly_footprint.R`, plus the terrain tests in
`tests/testthat/test-fly_footprint.R`.

Baseline: `devtools::test(filter="fly_footprint")` -> FAIL 0 | PASS 90.

---

## Findings

### [bug] R/fly_footprint.R:70-77 — `got` and `expected` are not the same quantity, so `dem_coverage` is wrong (and the 95% guard fires falsely) on any DEM whose cells are coarse relative to the footprint

```r
expected <- as.numeric(sf::st_area(sf::st_set_crs(in_dem, NA))) /
  prod(terra::res(dem))
got <- vapply(per_frame, function(x) sum(!is.na(x)), numeric(1))
covered[ok] <- pmin(1, got / expected)
```

`got` is a **count of cell centres** falling inside the polygon.
`expected` is the polygon's **area** expressed in cell units. Those differ by a
boundary term of order `2/k` per axis, where `k` is the footprint width in
cells. The round-3 fix corrected the *units* (planar vs geodesic) but left the
two sides measuring different things, so `dem_coverage` carries a systematic
error of roughly `±2/k` **even when the DEM covers the footprint completely and
contains no NA at all**.

Measured, decisively — synthetic DEM, EPSG:3005, `values(r) <- 700` so **zero NA
cells anywhere**, extent 30 km beyond every footprint (so no truncation is
possible), three 1:12000 frames:

| DEM resolution | reported `dem_coverage` | true coverage | warned? |
|---|---|---|---|
| 300 m | 1, 1, 1 | 1 | no |
| **900 m** | **0.9134, 0.9134, 0.9134** | **1** | **yes** |
| 120 x 904 m (anisotropic) | 0.9782, 0.9782, 0.9375 | 1 | — |

The 900 m run emits:

```
3 of 3 corrected frames are less than 95% covered by the DEM (as little as 91%
of one footprint). Their ground elevation is the mean of the covered part...
```

That is a false statement about a DEM that covers 100% of every frame, and
`dem_coverage` is documented as "the fraction of each footprint the DEM actually
covered" — the column the docs tell callers to filter on. A caller following the
documented workflow discards perfectly-covered frames.

The same error is present, smaller, in the shipped fixture. Using
`terra::extract(..., exact = TRUE)` as the reference, the true area-weighted NA
fraction under the 20 returned footprints is **0 for 19 of them and 0.000227 for
the twentieth**, yet `dem_coverage` reports **0.99455 - 1.0**. Raw ratios before
`pmin()` run 0.99455 to 1.00919.

`pmin(1, ...)` hides the error in the other direction, which is the part that
matters for the guard: on frames 1 and 5 of the shipped data the raw ratio is
1.0092, so up to ~0.9% of genuinely missing cells is invisible at 30 m. In the
extreme (aggregate the bundled DEM to 6090 m cells, footprint 2743 m — smaller
than one cell) `got = 1`, `expected = 0.2`, and `dem_coverage` reports **1** for
a "footprint mean" that is a single cell's value.

Practical bound: at the documented DEM sources (MRDEM-30 at 30 m, TRIM at 25 m,
LidarBC sub-10 m) `k >= 90` and the error stays under ~2%, so the shipped path is
not broken — but the threshold is 5 points and the noise is 1-2 points, and
`dem` is documented as accepting *any* raster terra can open. At 305 m cells the
bundled frames already report 0.951, one point off the threshold.

Fixes, with the cost I measured:

- `terra::extract(dem, v, exact = TRUE)` and sum `fraction` over non-NA cells.
  Verified exact: the ratio comes out 1.0000 at 30 m, 305 m and 914 m. **But it
  is 23x slower** on this data (0.52 s -> 12.2 s for one pass over 20 frames),
  and there are two passes, so this is not a free swap.
- Cheaper and like-for-like: make `expected` a centre count too — build a
  template raster aligned to `dem`'s origin and resolution over the polygons'
  bbox and count centres inside each polygon, or `terra::extend()` the DEM to
  that bbox and go back to `mean(!is.na(x))` over the returned cells. Both sides
  are then centre counts, which fixes the quantization *and* still catches
  ground beyond the extent (the round-2 failure mode).

---

### [fragile] tests/testthat/test-fly_footprint.R:320-324 — the comment's premise is false; the assertion passes on the artifact from the finding above

```r
# The bundled DEM is buffered past the widest footprint, so nothing here is
# materially short — but reprojection leaves NA slivers, so it is not all 1
# either. ...
expect_lt(min(terr$dem_coverage), 1)
```

Measured: the NA fraction among cells returned under every one of the 20
nominal-scale footprints is **exactly 0**, and the area-weighted NA fraction
under the 20 *returned* footprints is 0 for 19 frames and 0.000227 for one.
There are effectively no "reprojection slivers" in this fixture.

So `min(terr$dem_coverage) = 0.99455` is ~24x larger than any real shortfall and
is dominated by the centre-count/area mismatch. The assertion is not vacuous —
it fails when the coverage measure is stubbed to 1 (verified) — but it is
passing for a reason the comment denies, and once the finding above is fixed it
survives only on that single frame's 0.023%. The comment should say what the
fixture actually contains, and the "not all 1" property deserves a fixture that
really has NA inside the extent under a footprint.

---

### [fragile] R/fly_footprint.R:362-364 + test-fly_footprint.R:245-258 — nothing detects removal of the second pass, and the docs overstate what it buys

Patching the source so the second pass is skipped entirely —

```r
second <- fly_dem_sample(dem, fly_rectangles(coords, resize(first$elev)))
# replaced with:
second <- first
```

— leaves `test-fly_footprint.R` at **90 PASS / 0 FAIL**. (Patch confirmed
applied via a marker; the same harness reddens the suite for five other
restored defects, so it is not a harness artifact.)

Measured on the bundled data, pass 1 -> pass 2 moves mean elevation by at most
**14.5 m** and footprint area by at most **0.53%**; pass 2 -> pass 3 moves area by
at most 0.034%. The roxygen claim

> Iterating is not ceremony — the correction can enlarge a footprint by a
> quarter, so the nominal rectangle is measurably the wrong window to average over

conflates two different deltas: the *correction* enlarges by ~25% (pass 0 ->
pass 1, which the DEM path genuinely buys), the *iteration* is worth 0.5%.

The test header that claims to cover this —

> The two-pass iteration is load-bearing, not cosmetic: centroid and
> footprint-mean elevation differ by up to 130 m on the wide 1:31680 frames.

— then asserts footprint-mean vs **centroid** sampling, which is a different
property and is unaffected by dropping the second pass. So the iteration is
asserted in prose in two places and guarded in neither. Either add an assertion
that can see it (e.g. pin `height_agl` against the single-pass value, which
differs by up to 14.5 m here) or scale the claims back to what was measured.

Related and minor, same lines: `covered` is the coverage of the pass-2 *input*
rectangle, while the returned geometry is `resize(second$elev)` — a third,
slightly different rectangle. Bounded by the same 0.03% convergence on this
data, so it is a documentation nuance rather than a defect, but `dem_coverage`
is not literally "the fraction of *this* footprint".

---

### [fragile] R/fly_footprint.R:50-51 — a DEM with no CRS dies with an error that names neither `dem` nor `fly`

```r
in_dem <- sf::st_transform(sf::st_sf(geometry = rects[ok]),
                           sf::st_crs(terra::crs(dem)))
```

`terra::crs(dem)` is `""` for a raster with no CRS (common for a hand-built or
ASCII-grid DEM). `sf::st_crs("")` then throws
`Error in st_crs.character(""): invalid crs:` — before `st_transform` is even
reached. It fails loudly, so nothing is silently wrong, but the message points
at neither the `dem` argument nor the fact that a CRS is required. A one-line
check next to the existing `flying_height`/`focal_length` validation would say
so.

---

## Verified correct — please do not re-litigate in round 5

Each of these was probed, not reasoned about:

- **`split()` alignment is sound for every input I could construct.**
  `terra::extract()` emits at least one (NA) row per polygon for a polygon
  entirely outside the raster extent, for an *empty* polygon, and for a polygon
  with `Inf` coordinates (the zero-`focal_length` path); `terra::vect()`
  preserves empty geometries as rows rather than dropping them; and `split()` on
  a numeric ID column orders levels numerically, so IDs > 9 do not sort as
  strings. Checked elementwise against independent per-rectangle extraction with
  empties interleaved at positions 2, 7, 13, 19 of 20: **max abs diff 0, NA
  positions identical**. `cells` cannot have zero rows given the `!any(ok)`
  guard, so the `vapply`-into-nonzero-index error is unreachable.
- **"First pass NA, second pass not NA" is unreachable.** `first$elev` NA =>
  `resize()` NA => empty pass-2 rectangle => `second$elev` NA. The `ifelse`
  fallback is exercised in the *other* direction (NA `focal_length` /
  `flying_height` make the second rectangle empty while the first sampled fine),
  and it is load-bearing: patching it to `covered <- second$covered` reddens the
  zero-coverage test.
- **Planar area over planar resolution is the right pairing** for geographic,
  projected, skewed and anisotropic DEMs alike, because `terra` extracts against
  the same straight-edged transformed polygon that `st_area()` measures. The
  geographic path measures 0.9958-1.0 on the bundled frames. The residual error
  in all of these is the centre-count issue above, not the CRS handling.
- **The three prior rounds' guards fire.** Restoring R1's defect (no coverage
  measure) reddens 8 assertions; R2's (NA share of returned cells) reddens 3;
  R3's (geodesic m2 over degree res) reddens 1. Restoring `dem_coverage[corrected]`
  in place of `[sized]`, dropping `is.na(elev)` from the `uncovered` test, and
  dropping `pmin()` each redden the suite too.
- **Branch consistency between `dem_coverage` / `footprint_terrain` /
  `height_agl` holds in all four branches.** `covered` can only be `NaN` where
  the corresponding `elev` is `NA` (zero-area or infinite rectangle), so no
  `corrected` frame can carry a `NaN` coverage, and `partial`'s `!is.na(covered)`
  guard is belt-and-braces rather than load-bearing.
- A multi-layer `dem` silently uses layer 1 (`cells[, 2]`). Reasonable; noting
  it only so it is not mistaken for an oversight.

## Out of scope but noticed

`fly_footprint()` gives a frame with an unparseable `scale` an **empty geometry
while `footprint_basis` records the format as resolved** (e.g. `"Film - BW"`).
The only warning is R's generic `NAs introduced by coercion` from `as.numeric()`.
The documented filter `footprints[footprints$footprint_basis != "unknown_format", ]`
— used in the package's own `@examples` — therefore keeps a frame with no
geometry. Pre-existing, but the terrain work added
`test-fly_footprint.R:365` for this exact path and it asserts nothing about the
silence.
