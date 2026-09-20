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

## The DEM is read through one window per frame (fly#59)

`fly_footprint(dem = )` offers MRDEM-30 over `/vsicurl/` as a default that needs no download,
and until 0.13.0 that was close to unusable: **two ordinary 1:15000 frames took 583 s**, with
`Rprof` putting all of it in `terra::extract()` and almost none of it in CPU — 61 s sampled of
583 s wall.

That 583 s was never a clean comparison. The run shared bandwidth with the fly#54 calibration
sweep reading the same S3 object from six workers, so it confounded `fun` against no `fun`, one
worker against six, one polygon per call against fifty, and a contended link against a quiet one.
Re-measured 2026-09-20 with one variable moving, one form per **fresh R process** so the GDAL
block cache cannot carry between them, one frame:

| form | secs | HTTP GETs | cells | mean elev |
|---|---|---|---|---|
| `crop(dem, ext(v))` then `extract(crop, v)` | 0.69 | 4 | 12616 | 609.150 |
| `extract(dem, v, fun = mean, na.rm = TRUE)` | 0.66 | 4 | — | 609.150 |
| `extract(dem, v)` — what shipped until 0.13.0 | 64.59 | 158 | 12616 | 609.150 |

94x the wall clock and 39x the requests. **The two fast forms return the identical cell count
and the identical mean**, which is the whole licence for this change: the window alters what is
*read* and never what is counted.

4 requests is about what the object should cost. It is a well-formed COG — `LAYOUT=COG`,
`Block=512x512`, LZW, nine overview levels, 185220 x 166668 at 30 m — so a 512-cell block spans
15.4 km and a 1:15000 footprint is 3.4 km. One frame is one to four blocks. 158 is not.

**Cropping, not `fun = mean`, although they time the same.** The coverage numerator counts
non-`NA` cells, and an aggregating extract returns one number per frame. Taking the mean that way
would need a second call with a custom closure for the count — a closure terra applies in R, over
values it has to return anyway.

**Per frame, not once over the batch**, and this is the same argument as wrong form 4 above
arriving one step earlier. "Crop once to what we are about to sample" *is* the union-sized
allocation: `fly_dem_sample()` is handed every rectangle at once, so a crop spanning them is
sized to the gap between photos, not to the photos — 243 million cells for two frames 700 km
apart. Bounding the crop to one footprint costs 23% on contiguous frames (1.23 s against 1.00 s
for eight, because the block cache absorbs their 60% overlap) and **cannot** reproduce it.
**The read window is not the counting template**, and a review round caught the version that
made it one. `fly_dem_grid()` align()s with terra's default `snap = "near"`, which moves each
edge to the *nearest* cell boundary — so the template can be **smaller** than the footprint, and
reading through it drops cells the whole-DEM extract returned. Measured on the bundled 30 m DEM,
a review round measured 52 of 300 frames drawn between 0.2 and 6 cells across coming back with a
different mean elevation (`planning/archive/.../review-round1.md`).

**Frame width is not the condition, and a first draft of this section said it was.** Interior
frames 3.8 cells across diverge 0 of 200 times. A `snap = "near"` edge moves inward by at most
half a cell, so the column it discards has its own centre *outside* the polygon — and
`terra::extract()` takes a cell by its centre, so discarding it changes nothing. The read can
only diverge where `extract()` abandons the centre rule for its **touched-cells fallback**,
which fires when the frame's **overlap with the DEM covers no cell centre at all**.

That is a frame of **any size** sitting at the edge of coverage — the ordinary case for a DEM
cropped to an AOI, which this note already calls the ordinary failure rather than an exotic one.
Measured with the defect restored, on a full-size 3.4 km frame overlapping the east edge: **100
of 100** overlap depths under half a cell diverge, 50 of 100 under a whole cell, and **0 of 100**
once the overlap passes one cell.

So the read is snapped **out**, which is a superset of both the footprint and the template, since
the nearest boundary is never outside the boundary outside it. The template keeps `snap = "near"`
because fly#9 measured `dem_coverage` against that grid, and a faster read must not move what is
counted. Both windows are one footprint, so the bound holds either way.

**Two things the window must not quietly change**, both checked rather than reasoned:

- `terra::align()` returns the same extent whether it is handed the DEM or a crop of it, and
  `terra::crop()` to an extent overhanging the DEM **clips rather than pads**. So ground past the
  edge still yields no row — wrong form 1 — instead of an `NA` row that would be counted as
  described-and-missing.
- A frame with no DEM beneath it at all is the one place the two differ in kind:
  `terra::extract()` returns an `NA` placeholder row, and `terra::crop()` **errors**. Unguarded
  that would abort a batch over one unlocatable frame. It is **guarded on the extents and
  deliberately not caught** — see the comment at the guard. `tryCatch` here would test a proxy:
  "crop() failed" and "no DEM here" come apart, and a transient read failure on a remote DEM
  would become a frame that silently reports no coverage and falls back to nominal scale. Over
  400 randomized geometries and 800 degenerate edge overlaps, no input was found where the
  extent test passes and `crop()` then errors.

The check that licensed the change was parity against the previous implementation pulled from
git rather than rewritten by hand — identical `elev` and `covered` over all 20 bundled frames,
a frame 200 km off the DEM, two off and two on, a frame straddling the DEM edge, an empty
geometry among real ones, all-empty input, a DEM hole, a geographic-CRS DEM, anisotropic
120 x 904 cells, a multi-layer DEM, and frames swept from 0.05 to 60 cells across at three
resolutions.

**That parity is conditional, and the condition is worth stating.** It holds wherever the frame
covers at least one cell **centre**. Where a frame covers none but still touches the raster,
`terra::extract()` falls back to the cells the polygon touches, and that fallback is computed
over whatever raster it is handed — so the full DEM and a one-row crop of it return different
cells. Measured on a synthetic 10 x 10 DEM at 100 m: a frame poking 0.5 to 49.9 m into the
bottom row gives 96 from the whole raster and 95.5 from the crop, with `dem_coverage` unchanged.

One case in the same family is a **deliberate correction rather than a parity loss**: a frame
that merely *abuts* the DEM shares a boundary line with it and no area at all, so no cell centre
can be inside it. The old whole-DEM read still returned a mean from the cells touching that line
— `elev` 60 and `dem_coverage` 0.0556 on the same synthetic grid — where the strict-inequality
overlap test now reports no elevation and zero coverage. That is what `no_dem_coverage` is for,
and it is the answer the centre rule implies. **No route to it through `fly_footprint()` was found** — a real
footprint spans many cells, and on the bundled DEM the NA edge collar makes both paths agree at
`no_dem_coverage` — so it is recorded as the boundary of the claim rather than as a live
defect.

## `flying_height` is held against the scale before it is believed (fly#54)

The DEM route sizes a frame from `flying_height - terrain`, so it inherits whatever is wrong
with `flying_height`, and until 0.12.0 it had no opinion about that. Two 2003 frames came
back 110,834 m across against 8,022 m at nominal scale, as fly#54 reported them. Nothing in fly was wrong: **the
catalogue's `FLYING_HEIGHT` is 3.28084² = 10.764 times too large on 1,589 film frames** — a
feet-to-metres conversion applied the wrong way round. 13 rolls: `bc5596` (1974), `bc78065`,
`bc78078` (1978), `bc79027`, `bc79103` (1979), `bcb98013` (1998), `bcc00085` (2000),
`bcc03004`, `bcc03006`, `bcc03007`, `bcc03008`, `bcc03046` (2003 — 1,054 of the frames) and
`bcc05001` (2005).

Measured over the whole catalogue — all 1,670,471 centroids, reconciled against the
catalogue's own count — and over MRDEM-30 under the 7,156 frames that decide the constants.
`data-raw/height_calibrate-flying_height_slip.R` reproduces all of it from public data, and
the sweep ships as `inst/extdata/flying_height_sweep.csv` and `flying_height_population.csv`
so the suite checks the constants against the data rather than against themselves.

**A film frame states its height above ground twice**: `flying_height - terrain`, and
`scale x focal_length`. Call their ratio `r`.

| population | r |
|---|---|
| ordinary frames (random 2,500 of the 1.42 million at `ratio_asl` ≤ 2) | median 1.03, 2.5–97.5% 0.81–1.25, **99.2% inside [1/1.6, 1.6]** — 98.7% of all 1.44 million film frames, weighting in the two strata above |
| slipped, as reported (1,589) | 10.01–15.83 |
| slipped, divided by 10.764 | **0.80–1.32**, median 1.05 |
| between the two populations | nothing from 6.69 to 10.01 |

The repaired slipped frames land in the same shape as the ordinary ones, which is the
confirmation of the factor that does not depend on having guessed it. Reading the value as
plain feet instead leaves r at 3.02–4.71, and **0 of the 1,589** inside the band.

So `fly_footprint(dem = )` compares the two after its first DEM pass. Inside
`fly_height_ratio_band()` the height is used as reported. Outside it, dividing by
`fly_height_slip_factor()` is tried, and where that lands inside the band the frame is sized
from the corrected height. Otherwise the frame falls back to nominal scale. `height_source`
records which — `"reported"`, `"corrected_unit_slip"`, `"implausible"` — and the caller's
`flying_height` column is never overwritten, so `flying_height - height_agl` is **not** the
ground elevation on a corrected row.

Four things here were measured and each is load-bearing:

- **The check has to be relative, because the slip hides at legal altitudes.** `bc78065`
  reads 4,115 m at 1:2000 and `bc78078` 9,449 m at 1:6000. The issue proposed a plausibility
  bound on `height_agl`; no bound separates these from a legitimate flight. The highest
  legitimate `flying_height` in the catalogue is 14,630 m and the lowest slipped one is
  4,115 m.
- **The rule is per frame, never per roll.** 1,208 frames sit on a slipped roll without
  being slipped themselves.
- **The band's upper edge sits in a trough, and what is beyond it is a second defect.** The
  least favourable legitimate frames — low flights over high ground, where terrain is a
  large share of the height — still sit around 1: the 348 of the 600 sampled that are
  inside the band have a median of 1.05 and run 0.83–1.51 (5–95%). The next mass out is
  centred on
  **r = 2, and of the 223 frames sampled beyond r 1.8 in that stratum, 209 are catalogued
  at 153 mm**: a 305 mm lens recorded as a 153. The DEM route draws those at twice their
  true width; the nominal route gets them right, because it never reads `focal_length`.
  Falling back is therefore the correct answer there and not merely the cautious one. The
  lower edge is the same factor inverted, since the error is a ratio either way — set by
  symmetry, not by a trough: ordinary frames thin out steadily below 0.8 and there is no
  second mass at 0.5.
- **The repair fires on nothing else.** Of 2,733 sampled frames outside the band and not
  slipped, dividing by 10.764 brings none inside it.

**The slip appears to run the other way as well, and that is deliberately not repaired.**
1,963 frames read under half their nominal height, 1,962 of them sampled as the lower tail
(the other was already in the random draw). Multiplying by 10.764 brings 726 of those into
the band — but multiplying by **10** brings 729 (a dropped digit in a height in feet:
609 m is 2,000 ft), and for a different set of rolls doubling brings 799 (a 153 mm lens
catalogued as 305 would do that, and 519 of them are catalogued at 305 — but 280 are at 153,
which that reading cannot explain). Nor does 10.764 sort the lower tail the way it sorts the
upper one: it scatters the 1,962 from −0.70 to 5.38, leaving 130 still below the band and
1,106 above it, where the forward repair puts all 1,589 at 0.80–1.32 with the nearest
unslipped frame at 6.69 and the nearest slipped one at 10.01. Three remedies the
terrain cannot tell apart, so none is applied and those frames come back `"implausible"`
at nominal scale. Do not "finish" this by picking one.

**The ceiling, `fly_flying_height_max()`, is a backstop and not a discriminator.** A digital
frame's `scale` is a nominal figure a third of its true image scale, so there is nothing to
hold its height against, and for those the only check is that no survey aircraft flies at
16,000 m. No digital frame in the catalogue comes near it — the highest is 7,513 m of
223,667 — so today it catches nothing. It is judged on `flying_height` itself, before any
DEM window is built: a camera-table frame seeds its first window from the whole flying
height, so judging `height_agl` would mean fetching 100 km of terrain to learn the height
was wrong. The second pass is withheld from a refused frame for the same reason, and a test
asserts on the grids rather than on the answer — classifying after both passes returns the
right footprint and still pays for the wrong one.

**What this cannot do.** `r` cannot tell a wrong height from a wrong `scale`. Where the
scale is the wrong one, falling back to nominal is the worse choice, and nothing here can
know. That is why the `"implausible"` warning names no cause, and why the frames are
flagged rather than silently resized.

## Testing this

The bundled fixture — one 30 m EPSG:3005 DEM — **cannot reach any of the four failures
above, nor the fly#59 window defect.** A fine grid hides the `2/k` error, a CRS matching the data makes every reprojection
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
| a footprint whose **overlap with the DEM is under one cell** | where `align()`'s snapping matters — *not* a small footprint, which is the wrong axis and was tried first: interior frames 3.8 cells across never diverge. A window snapped to the nearest boundary can be smaller than the footprint, but the column it drops has its centre outside the polygon anyway. Divergence needs `extract()`'s touched-cells fallback, i.e. an overlap covering no cell centre — a frame of any size at the edge of coverage. fly#59 shipped that defect past a green suite; it was caught in review, and the first test written for it varied the wrong axis |
| a `flying_height` that disagrees with the scale | every bundled frame agrees with its own scale, so the height checks never fire — and relabelling a frame's `scale` without moving its `flying_height` builds exactly the disagreement they refuse |

And buffer a DEM past the **corner** of the widest footprint, `half_side * sqrt(2)` — 5.1 km
at 1:31680, not the 3.6 km half-side — plus room for the correction, which enlarges the
rectangle before the second pass samples it.
