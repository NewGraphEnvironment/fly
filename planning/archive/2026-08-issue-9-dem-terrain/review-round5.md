# Review round 5 — `fly_dem_sample()` / terrain branch

Verified by running R against `pkgload::load_all("/Users/airvine/Projects/repo/fly")`,
terra 1.9.34. Probe scripts in `/tmp/cc9/r5/`.

## Findings

### 1. [bug] R/fly_footprint.R:74-81 — the template is sized by the union bbox of ALL frames, so the 260-million-cell allocation the round-4 fix set out to avoid is still there

`terra::ext(v)` is the bounding box of **every** frame in the call, not of one frame.
The comment on line 68-73 claims "this template is only ever as large as the frames"
and contrasts it with `extend()`'s "260-million cell allocation"; measured, the
template lands in the same place.

Reproducing the fixture from the existing test
*"fly_footprint falls back to nominal scale outside DEM coverage"* (two frames, one
moved to `-120, 50`), with the bundled 30 m `dem.tif`:

```
template dims: 15604 x 15476   ncell: 241,487,504
terra::values(tmpl) <- 1L      inMemory TRUE, 0.71 s
```

Peak RSS for the whole `fly_footprint()` call on those **two** frames: **4.13 GB**
(`/usr/bin/time -l`, probe `p3.R`). `devtools::test(filter="fly_footprint")` peaks at
**4.60 GB**, and this is exactly the shape CLAUDE.md records as passing locally and
OOMing a 7 GB runner. And it is paid twice — once per pass.

It gets worse with a finer DEM, because cost scales as (spread / res)^2:

| frame spread | DEM res | template cells | as doubles |
|---|---|---|---|
| 200 km | 30 m | 44,444,444 | 0.4 GB |
| 20 km | 1 m (LidarBC, documented) | 400,000,000 | 3.2 GB |
| 1100 km (BC-wide) | 30 m (MRDEM-30, the documented default) | 1,344,444,444 | 10.8 GB |

Measured at 1 m with frames 300 km apart (`p4.R`): 909M cells, terra spills to disk
(`inMemory FALSE`), ~7 GB of temp file, **27.7 s per pass**, 6.3 GB peak RSS — for two
frames. The package's whole premise is province-wide (CRS 3005 "works province-wide"),
so a query returning centroids from two watersheds is enough.

Fix: build the template **per frame** rather than once over the union. Verified
equivalent — on the bundled 20-frame AOI a per-frame `align()`/`rast()`/`extract()`
gives counts `identical()` to the union template, max abs diff 0 (`p13.R`) — and each
template is then bounded by one footprint. (An analytic count of aligned centres inside
each polygon's aligned extent would avoid the allocation entirely.)

Nothing in the suite bounds the template, so this cannot go red.

### 2. [bug] R/fly_footprint.R:387-392, 452 — `dem_coverage` for a frame that falls back to nominal scale is measured over a rectangle that is not the returned footprint

`covered` is taken from the **second** pass whenever `second$elev` is not NA. The
second pass samples `fly_rectangles(coords, resize(first$elev))` — the *corrected*
rectangle. For a frame classified `corrected` that is right, since the corrected
rectangle is what is returned. For a frame classified **`unusable`** (terrain at or
above the aircraft — the documented "feet recorded as metres" case) the corrected
rectangle is still finite, just wrong-signed, so the second pass measures coverage over
a mirrored rectangle of a different size, while the geometry actually returned is the
**nominal** one.

Measured (`p11.R` / `p12.R`): bundled DEM cropped to 2 km around one centroid,
`scale = "1:31680"` (7240 m footprint), `flying_height` set 1 m below terrain:

```
footprint_terrain : "nominal_scale"
returned footprint: 7242 m per side
dem_coverage      : 1
true coverage of that returned footprint: 0.3042
```

`dem_coverage` affirmatively claims full coverage for a footprint the DEM describes
30% of. The `partial` warning cannot catch it either — line 433 gates on `corrected`,
so the only warning emitted is the metadata one. That is worse than an NA: the docs
advertise `dem_coverage` as the column to *filter* truncated frames on
("so a truncated footprint can be filtered rather than merely noticed"), and this frame
passes the filter.

The sibling fallbacks are fine: an NA or zero `focal_length` makes the second-pass
half-side non-finite, so `fly_rectangles()` returns empty, `second$elev` is NA, and
line 392 correctly keeps the nominal-rectangle coverage from pass one. Only the
sign-flip path reaches this.

Fix: key the reported coverage to the rectangle actually returned — take `first$covered`
for every frame that is not `corrected`, not only for those whose second pass produced
no elevation.

No test asserts `dem_coverage` on a fallback frame, so this too cannot go red today.

## Interrogated and found correct

- **Aligned-template denominator (item 1).** `terra::align()` defaults to `snap="near"`,
  which shrinks the extent inward in 1366 of 2000 random cases (`p9.R`) — but losing an
  interior cell centre needs the polygon edge to coincide with the snapped boundary
  exactly, a measure-zero event. Empirically: 300 random configurations (random origins
  not multiples of resolution, random and anisotropic resolutions, footprints from 2 to
  4000 cells wide) over fully-valid DEMs all reported coverage exactly 1 (`p5.R`); and
  against a brute-force ground truth on cropped DEMs — true count of DEM cell centres in
  each polygon taken from an uncropped parent — 150 configurations matched to **0**
  (`p6.R`). `got > expected` (which `pmin` would silently hide) occurred 0 times in 600
  frames (`p9.R`).
- **Footprint smaller than one cell.** terra falls back to touched cells when a polygon
  covers no centre, and does so identically for DEM and template, so a 200 m footprint on
  a 900 m grid straddling four cells reports coverage 1, not 0 (`p7.R`). `rast()` does not
  produce a degenerate extent there.
- **`split()` alignment (item 3).** `terra::extract()` returns exactly one NA row for a
  geometry with no overlapping cells rather than omitting it — verified with a
  middle-frame-off-raster case, `table(ID)` = `1:4, 2:1, 3:4` (`p7.R`) — so `per_frame`
  stays elementwise aligned to `rects[ok]`. `split()` on the numeric ID orders levels
  numerically, not lexically.
- **`fly_rectangles()` empty on non-finite (item 4).** No callers outside
  `fly_footprint.R` (grepped). `sized`/`corrected`/`uncovered`/`unusable` all key off
  `half_side` or `candidate` rather than the geometry, `dem_coverage[sized]` leaves NA
  only where there is no footprint, and `!any(ok)` short-circuits.
- **Assertions can fail (item 5).** Restoring the round-3 defect (area / cell area) makes
  *"reports full coverage on a DEM that is entirely valid"* report 0.9132 at 900 m, and
  restoring a square-cell denominator (`rep(res(dem)[1], 2)`) makes *"handles anisotropic
  DEM cells"* report 0.15/0.1429 (`p10.R`). Both new guards fire. The premise assertion in
  *"detects a footprint running past the DEM's extent"* is reachable and would fail if the
  crop buffer were widened.

Baseline: `devtools::test(filter="fly_footprint")` — FAIL 0 | WARN 0 | SKIP 0 | PASS 100.
