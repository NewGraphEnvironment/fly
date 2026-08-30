# Terrain correction in `fly_footprint()`

Why the DEM path works the way it does, and the four ways of computing its coverage
number that look right and are not. Written after fly#9, whose six review rounds are in
`planning/archive/2026-08-issue-9-dem-terrain/review-round[1-6].md` — those record what was
*measured*, and are the thing to read before changing any of this.

## The error being corrected is a datum offset, not a slope effect

Two facts, both established by measurement and both contrary to how fly#9 was originally
written:

**`FLYING_HEIGHT` is metres above sea level, not height above ground.** The catalogue's
values are round feet — 8000, 8500, 19500, 20000 ft. Turning it into the height that ground
coverage actually scales with requires subtracting terrain elevation, which is the whole
reason a DEM is needed.

**Reported scale understates footprint area by a median 13.8%, ranging to 26.4%, and always
in the same direction.** The scale is referenced to an elevation above the valley floor the
photos actually cover, so it understates every frame:

| scale | n | ground elevation (m) | area correction | median |
|---|---|---|---|---|
| 1:12000 | 10 | 596–736 | +0.5% .. +18.1% | +13.1% |
| 1:31680 | 10 | 647–949 | +6.2% .. +26.4% | +15.3% |

Slope would push in both directions and is far smaller. **Treating this as a slope problem
would build the wrong ~2% and leave the ~14% in place.**

Per-corner ray-casting — projecting each corner ray onto the terrain instead of keeping a
rectangle — measures about 2% on this area. It is deferred, not rejected, and it would cost
the rectangle geometry every downstream function depends on. The remaining accuracy work is
#10 (tilt and roll, absent from the catalogue), not slope.

## Sizing is the mean under the footprint, measured twice

Elevation is the mean under the whole footprint, not a reading at the centroid — the two
differ by up to 140 m on a 7.2 km 1:31680 frame.

Two passes, because the window being averaged is itself what the correction changes: the
first averages over the nominal-scale rectangle, the second over the rectangle the first
produced. The second pass is a refinement worth under 0.5% of area against the correction's
own 14%, and a third moves it 0.03%. Worth one more extract; not worth describing as
"iterates until convergence".

## `dem_coverage` has four natural-looking wrong forms

The column reports what fraction of each footprint the DEM actually described. Four
implementations shipped in sequence, each passing its own tests while wrong:

1. **Non-NA share of *returned* cells.** `terra::extract()` returns no row for ground beyond
   the raster's extent — not an NA row — so a footprint hanging off the edge read as fully
   covered. Measured on a DEM cropped to the AOI: all 20 frames reported coverage `1` while
   the sampled elevation was wrong by 83 m.
2. **Footprint area ÷ cell size.** `sf::st_area()` on a geographic CRS returns geodesic m²
   while `terra::res()` returns degrees. An EPSG:4326 DEM reported coverage of `1.4e-10` and
   warned on twenty fully-covered frames.
3. **Area denominator against a centre-count numerator.** `extract()` takes a cell when its
   *centre* falls inside the polygon, so an area-based denominator is a different
   measurement, low by roughly `2/k` for a `k`-cell-wide footprint. On a DEM with nothing
   missing and room to spare, that reported 91% at 900 m cells.
4. **One counting grid over the union of all frames.** The union's bounding box spans the
   whole photo set, so one outlying frame sizes the grid to the *gap*: 243 million cells for
   two frames 700 km apart, against 16 thousand counted separately. `terra::extend()` fails
   the same way — it sizes to the union of raster and features.

**Current form:** a per-frame grid aligned to the DEM via `terra::align()`, with the non-NA
count over the cell count — both counted the same way, on the same centres.

The 0.95 warning threshold in `fly_dem_coverage_min()` is not arbitrary. Reprojecting a DEM
leaves NA slivers along its edges, so a frame near the margin is routinely a fraction of a
percent short through no fault of the caller; warning on any missing cell fires on good data
and stops being read.

## Testing this

The bundled fixture — one 30 m EPSG:3005 DEM — **cannot reach any of the four failures
above.** A fine grid hides the `2/k` error, a CRS matching the data makes every reprojection
an identity, a generously buffered extent never truncates, and frames that are close
together never blow up the grid. Two hundred tests passed over each of the wrong forms.

Vary the fixture along the axes the bundled one holds constant:

| axis | why |
|---|---|
| resolution — 30 m **and** ~900 m | the `2/k` error scales with footprint width in cells |
| anisotropic cells | non-square cells are ordinary away from the equator |
| geographic CRS | the only way to execute the reprojection branch at all |
| a truncating extent | a DEM cropped to an AOI is the common case, and it stops rather than going NA |
| frames far apart | grid allocation scales with the gap, not the frames |

And buffer a DEM past the **corner** of the widest footprint, `half_side * sqrt(2)` — 5.1 km
at 1:31680, not the 3.6 km half-side — plus room for the correction, which enlarges the
rectangle before the second pass samples it.
