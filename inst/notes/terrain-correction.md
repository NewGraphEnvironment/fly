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
and stops being read. That is why it was *chosen*; fly#58 later measured what it is worth
and it survives for a better reason — see "What a partially covered footprint costs".

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
from the corrected height. Otherwise the frame falls back to nominal scale — unless its roll
was settled by measurement, which fly#60 added and the section after this one describes.
`height_source` records which — `"reported"`, `"corrected_unit_slip"`,
`"corrected_roll_table"`, `"implausible"` — and the caller's
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
  at 153 mm**. This was first read as a 305 mm lens recorded as a 153 — which the DEM route
  draws at twice its true width and the nominal route gets right — and so falling back was
  called the correct answer there rather than merely the cautious one. **That is true of
  about half of it.** Spacing and the logbooks split the mass into two defects that read
  alike from `r` (fly#72, below): a wrong lens, which the fallback sizes correctly, and a
  right height beside a `scale` recorded at half its denominator, which the fallback drew at
  half width and the roll table now corrects. The
  lower edge is the same factor inverted, since the error is a ratio either way — set by
  symmetry, not by a trough: ordinary frames thin out steadily below 0.8 and there is no
  second mass at 0.5.
- **The repair fires on nothing else.** Of 2,733 sampled frames outside the band and not
  slipped, dividing by 10.764 brings none inside it.

**The lower tail is not the slip run backwards, and half its frames were settled per roll by
fly#60** — see the next section. Pooled, ×10.764, ×10 and ×2 each brought a comparable
share of the 1,962 frames under half their nominal height into the band, and the terrain
could not choose. That was the wrong unit: the tail is 42 rolls, and each roll is one
measurement.

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

## The lower tail, settled per roll (fly#60)

The 1,962 film frames reading under half the height their scale implies sit on **42 rolls**,
and nearly every roll carries one `flying_height` — a planned altitude in round feet (609 m is
2,000 ft). So the tail is 77 roll-heights, not 1,962 frames, and two instruments that read
none of the three disputed fields settle 22 of them — 1,001 of the 1,962 frames.

**Frame spacing.** Frames one number apart on a roll are an air base apart, and a flight is
designed to about 60% forward overlap, so the base against the along-track width a reading
implies says whether that reading is the one the aircraft flew. Checked on known answers
before anything was read from the tail:

| control | implied overlap, median [10–90%] |
|---|---|
| random in-band frames, as reported | 0.63 [0.59–0.69], n 2,481 |
| #54 slipped frames, after ÷10.764 | 0.62 [0.58–0.66], n 1,589 |
| the same, as reported | 0.97 |

The acceptance window is the random frames' own 2.5–97.5%, 0.557–0.780, applied to a
roll-height's median. **Spacing separates readings about 1.6 times apart and no closer**:
every reading whose ratio lands in the band implies nearly the nominal width, so it cannot
tell ×10 from ×10.764 (7.6%), and it cannot tell a doubled height from a halved lens.

**The logbooks.** `flight_log_url` links scanned logbook pages whose TRUE HEIGHT column is
thousands of feet above sea level — the figure the catalogue transcribed. 120 pages were read
by hand into `data-raw/flying_height_logbooks.csv`, with the catalogue values of three control
rolls withheld from the reader. The two clean controls read back exactly (`bcc228` 12.650 and
14.0 against 3,856 and 4,267 m; the `bc7349/7350` page 20.0 against 6,096 m). The third was a
#54 slipped roll, and it said something #54 did not know — below.

**The rule, fixed before any roll-height was classified:** the logbook covers at least half
its frames and at least 90% of those name one factor of 1, 10 or 100; no legible logbook
focal length contradicts the catalogue's; and spacing under the logbook's height is inside
the window. Two witnesses, independent of each other and of the fields in dispute.

| verdict | roll-heights | frames |
|---|---|---|
| a digit dropped, ×10 (logbook "20.0" catalogued as 2,000 ft) | 10 | 511 |
| two digits dropped, ×100 (`bc7280`, 60 m catalogued, 20,000 ft logged) | 1 | 101 |
| **height right, scale wrong** — the logbook confirms the height, spacing accepts it | 11 | 389 |
| excluded, each with its reason in `flying_height_rolls_excluded.csv` | 55 | 961 |

The third row is a remedy the issue did not list, and it inverts the fallback: for those
frames it is the **scale** that is wrong, so nominal scale draws them two to ten times too
wide, while the height #54 refused was right all along. The excluded reasons are 30 with no
logbook page covering the frames, 8 where spacing rejects the logbook's height, 5 where the
covering row's height or frame range was not read, 4 where the logbook's height is no named
multiple, 2 where covering rows disagree, 2 under half covered, and 4 where the logbook names a
different lens — `bc79086` an 85 mm, `bc80001`, `bcc162` and `bc81026` a 153 catalogued as
305 — for which nominal scale is already right.

**×10.764 is refused wherever a logbook reads the lower tail**: the logged figure is exactly
ten times the catalogued one in round feet (`bc79122` 21,000; `bc7584` 20,000; `bc81013`
27,000; `bc77014` 28,000), where the inverse slip would give 22,604 and the like. And the
height shipped is the **logbook's**, converted, never the catalogue's times the factor: the
catalogue stores whole metres of a converted figure, so `bc7280`'s 20,000 ft is 60 m, and
×100 of that is 96 m short.

`fly_footprint(dem = )` consults `inst/extdata/flying_height_rolls.csv` before #54's repair,
keyed on roll, height, lens and scale together — which reaches exactly the 1,001 measured
frames (1,300 since fly#71 added the upper tail, and 1,438 since fly#74 added a same-roll
witness, both below) — and marks those frames
`"corrected_roll_table"`. A height slip must still reconcile
the frame's own ratio, as #54's does. A scale-wrong row cannot be asked that, since the ratio
is against the wrong scale, but its height must clear the ground. The table also reaches a
frame whose catalogued height sits *below* the terrain, which is how a height missing two
digits arrives. **Only on the DEM route**: without `dem`, a scale-wrong frame is still sized
from its wrong scale.

**What the controls said about #54.** Roll `bc78065`'s 1:2000 frames are catalogued at 4,115 m
(13,500 ft), and its logbook reads **1.35**, which is 1,350 ft. That is a decimal point, ×10, not
×10.764. Both factors put all 1,589 frames in the band, which is why #54 could not see it. Recorded
as fly#71 and settled there (next section).

## #54's slipped frames, read against the logbooks (fly#71)

fly#71 applied the same instrument to #54's 1,589 slipped frames. These are the upper tail that
÷10.764 brings into the band. They sit on 13 rolls. Logbook pages cover the slipped frames of only
six, flown 1978-2000; the five besides the control were fetched and transcribed by a reader
who saw the images and the column spec and no catalogue value:

| roll | catalogue m | logbook ft | vs ÷10 | vs ÷10.764 |
|---|---|---|---|---|
| `bc78065` (the control) | 4,115 | 1,350 | 0.00% | +7.6% |
| `bc78078` | 9,449 | 3,100 | 0.00% | +7.6% |
| `bc79027` | 19,995 | 6,500 | −0.9% | +6.7% |
| `bc79103` | 21,946 | 7,200 | 0.00% | +7.6% |
| `bcc00085` | 54,860 / 56,390 / 57,910 | 18,000 / 18,500 / 19,000 | ≤0.01% | +7.6% |
| `bcb98013` frame 52 | 97,924 | 24,000 | −25% | −20% |

**On every roll a logbook reaches, bar the one-frame typo at the foot of the table, the height
is the catalogue's divided by 10**: exactly, to within the catalogue's whole-metre rounding, on
four, and 0.9% off on `bc79027`. The logbook sits 6.7–7.6% above ÷10.764 on each. Width
follows height above ground, not above sea level, so on the tabled roll-heights #54 drew the
frames 7.6–9.9% narrow (median per roll-height; 15–19% in area). `bc78065` produced the hypothesis, so the four
other rolls are the independent confirmation.

The same rule as the lower tail, with the named factors 1/10 and 1/10.764, settles **6
roll-heights (299 frames)**, carried in `flying_height_rolls.csv` with `tail = "upper"`, factor
0.1 and cause `height_decimal_dropped`. The table is consulted before #54's repair, so those
frames become `"corrected_roll_table"` and are sized from the logbook's height. A roll-height
whose logbook named 1/10.764 would be excluded ("logbook confirms #54's 10.764") rather than
tabled, since the repair already sizes it. No roll did.

**Where #54's factor still applied, 1,290 frames** (1,281 since fly#74 settled two of the
roll-heights below), each listed in
`flying_height_rolls_excluded.csv` with a reason ending "#54's 10.764 still applies":

- **The six 2003/2005 rolls** (`bcc03004/06/07/08/46`, `bcc05001`; 1,271 frames) have no logbook
  link at all. The five 2003 rolls carry measured per-frame heights, so their 1,054 frames sit on
  458 roll-heights, round feet cannot speak for them, and their ratio to scale × focal fits
  ÷10.764 better (1.06–1.11 against 1.15–1.22 under ÷10). **`bcc05001` is the open case**: 217
  frames on 5 heights that land within 6 ft of round 500-ft altitudes under ÷10 (20,505 to
  22,005 ft). Round feet favour ÷10, while its ratio (0.98 against 1.08) favours ÷10.764. With no
  logbook to decide between them it stays on #54's factor.
- **`bc5596` frames 204–211** have no logbook page. Their 26,212 m is ten times the
  2,621 m of frames 141–203 on the same roll, which points to ÷10, but a same-roll sibling is not
  one of the two instruments. Settled by fly#74 (next section).
- **`bc79027`**: the logbook reads 1/10, but **spacing rejects it**. The implied overlap is 0.82,
  outside the 0.557–0.780 window. The page itself records "80% fwd overlap", so the spacing is
  right and this roll does not fit the window's ~60% design assumption. The rule fixed in fly#60
  is not moved for one roll.
- **`bcb98013` frame 52** is not a slip. The other 207 frames on the roll read 7,924 m, and 97,924
  is that figure with a leading 9. Neither factor recovers it: ÷10.764 gives 9,097 m, about 17% wide
  in linear size. The page the catalogue links is headed roll 15BCB**99**013, flown 1999 at
  24,000 ft, so it may not be this roll's page at all. Settled by fly#74 (next section).

Reproduce with `data-raw/height_calibrate-lower_tail_rolls.R`, which prints every figure in
this section; `test-fly_footprint_height_rolls.R` holds the table to the sweep and the
logbook heights it was measured from.

## A third witness: the same roll's adjacent frame (fly#74)

fly#71 left two slipped roll-heights on ÷10.764 that the evidence said were wrong, and neither
fits the logbook rule. `bc5596` 204–211 have no logbook page. `bcb98013` frame 52's page reads
24,000 ft, which names no factor. Both point at a witness the rule did not have: **the frame
beside them on the same roll**. The rule below was fixed before it was run, and then run over
every roll-height the logbook rule leaves excluded, in both tails, not just the two it was
written from.

A roll-height is settled by a sibling only where:

1. a frame numbered one away, on the same roll, lens and scale, carries a different height.
   That is the adjacency `fly_bearing()` demands;
2. that neighbour's height is itself in the band, against this roll-height's own median
   terrain. Neighbours are not sampled, so this is a proxy; `fly_footprint()` holds every
   frame to the band again;
3. the catalogue's height stands in an **exact** named relation to it. The upper tail names
   ×10, ×10.764 and one leading digit added; the lower tail names ÷10, ÷100 and the leading
   digit dropped. *Exact* means within what storing whole metres can move a converted figure,
   and string identity for the digits. The catalogue sometimes rounds and sometimes
   **truncates**: 2,000 ft (609.6 m) is 609 on `bc5449`, a row the logbook already settles. With
   each figure off its true value by a ∈ [−0.5, 1), the larger height less k times the smaller
   lies in [−(1 + k/2), k + 1/2]. That covers figures converted at 0.3048 m/ft. Some were
   converted at 3.28 ft/m and rounded (20,000 ft is 6,098 m on 2,677 frames). Such a figure
   can put a genuine relation outside the bound, so it is refused, never wrongly accepted.
   Enumerating every adjacent pair of the 521 roll-heights finds none between the bound and
   twice its width;
4. every in-band neighbour that names a relation names the same one, at one height, and at
   least one does. A neighbour naming nothing is a new leg at a new altitude, not a
   contradiction. A unanimous ×10.764 is left to #54's repair, as it is for the logbook;
5. where the logbook named a factor for these frames, it named this one. **A logbook that
   names no factor vetoes nothing**: it is evidence for no repair, #54's included;
6. spacing under the sibling's height sits inside the random-frame window.

The height shipped is the sibling's catalogued height. `witness` in `flying_height_rolls.csv`
says which instrument settled a row, and `sibling_frame` names the neighbour.
`flying_height_rolls_excluded.csv` gains `sibling_reason` beside the logbook's `reason`, so
every excluded row says why each witness passed it over.

**Why the tolerance is the catalogue's storage and not the logbook's 2%.** `bc5596` 204–211 read
26,212 m, between frame 203 at 2,621 m and frame 212 at 2,438 m. 212's height is the logbook's
8,000 ft, so that neighbour is sound. 26,212 is ten times 2,621 to 2 m, and it is also 10.764
times 2,438 to 30 m, which is 0.12%. Under 2% both neighbours name a relation and they name
different ones. Under the storage tolerance, [−6.4, 11.3] m at k = 10.764, only 203 does. Measured by mutation: with `exact()`
swapped for 2%, `bc5596` is refused as "adjacent frames name different relations" and the
generator stops at its control. Round feet agree, though they gate nothing: ÷10 gives 2,621.2 m,
which is 8,600 ft to 0.3 ft, while ÷10.764 gives 7,989 ft, 11 ft short of 8,000.

**The tolerance was corrected once, after the first run, and the correction is recorded
here.** As first fixed, it assumed the catalogue only rounds, |h − k·s| ≤ 0.5(k + 1). Code review
found the truncation above in rows that owe nothing to Stage 5b. The rounding-only form wrongly
refused `bc7675` 609 m: its neighbour, frame 214, reads 6,096 m, exactly 20,000 ft, and
6,096 − 10 × 609 = 6 m against a limit of 5.5. The other witnesses agree on the relation. The
logbook names ×10 on all 34 frames it reads, and was refused only for covering 40%, though its
20,200 ft (6,157 m) sits 1.0% above the sibling's height, so it agrees on the factor rather than
the height. Spacing under 6,096 m gives 0.616. The corrected form changes that outcome and no other, and both
controls hold under it. Its evidence is the catalogue's storage, not the Stage 5b result, which
is why it was taken rather than held to "fixed before looking".

**What it settles: 5 roll-heights, 138 frames, of the 521 the logbook leaves.**

| tail | roll | catalogue m | lens | scale | frames | relation | from frame | height m | overlap |
|---|---|---|---|---|---|---|---|---|---|
| lower | `bc7675` | 609 | 305 | 1:16000 | 84 | ÷10 | 214 | 6,096 | 0.616 |
| lower | `bc87070` | 396 | 153 | 1:23000 | 34 | ÷10 | 203 | 3,962 | 0.597 |
| lower | `bcc822` | 701 | 305 | 1:15000 | 11 | ÷10 | 119 | 7,010 | 0.613 |
| upper | `bc5596` | 26,212 | 153 | 1:12000 | 8 | ×10 | 203 | 2,621 | 0.619 |
| upper | `bcb98013` | 97,924 | 153 | 1:40000 | 1 | leading digit | 51 | 7,924 | 0.656 |

The three lower-tail rows were not in the issue, and the logbook corroborates each one
independently in a way its own rule could not accept. `bc7675`'s is covered above. On `bc87070` the row covering 169–202 reads
13.0, which is 13,000 ft or 3,962 m, but its frame range was transcribed "169-20?", so the rule
counts it as not read. On `bcc822` the crew wrote "2300" for 120–130, between rows of 22,500
and 23,000 ft. The catalogue copied the dropped zero: 701 m is 2,300 ft.

What it refuses, as roll-heights / frames: in the lower tail, 10 / 486 have no adjacent frame
at another height, 6 / 99 have no adjacent frame in an exact relation, and 36 / 247 have no
adjacent frame in band. In the upper tail, 1 / 10 have no exact relation (`bc79027`), and
463 / 1,271 have no adjacent frame in band. Those are the 2003/2005 rolls, where every
neighbour is slipped too.

**What it cannot do.** It speaks only where a neighbour at the right height happens to sit
one frame away. It is blind to a roll whose every frame carries the defect, and that is most
of the upper tail. Spacing still cannot separate ×10 from ×10.764, so wherever the relation is
not exact to the metre, nothing here chooses between them.

Reproduce with `data-raw/height_calibrate-lower_tail_rolls.R` (Stage 5b), which prints every
figure in this section and stops unless both controls return their neighbours' heights.

## The r ≈ 2 mass is two defects, settled per roll (fly#72)

**Verified:** 2026-09-27 · **Issues:** fly#72 (from fly#54, fly#60) · **Produced by:**
`data-raw/height_calibrate-lower_tail_rolls.R`, set `near_upper`

fly#54 set the band's upper edge in a trough before a mass at r = 2 and called the mass a
305 mm lens catalogued as 153. fly#60's spacing split it instead: of the 209 sampled frames
beyond r 1.8 at 153 mm, 90 give the designed ~60% forward overlap under nominal scale (the
lens reading), 105 give it under the **reported** height with nominal implying ~20%, and 14
fit neither. The generator stops if its spacing no longer reproduces that 90 / 105 / 14.

The same two witnesses fly#60 used then settle it per roll-height, over every sampled frame
beyond the band (252 frames, 53 rolls, 58 roll-heights, all lenses). New logbook pages were
transcribed blind — readers given only the images, one control sheet each, all three read
back as catalogued — into `data-raw/flying_height_logbooks.csv`. One thing changed in how:
`focal_mm` is filled only where a focal length is **written**, never inferred from a camera
model, because on this set the lens is the question.

**The logbook height cannot separate the two readings.** A lens catalogued wrong and a scale
catalogued wrong both predict the crew flew the catalogued height, so factor 1 "agrees" on
both. What separates them is a legible lens and the spacing. So for `near_upper` the rule,
fixed before the run, adds one condition to fly#60's: spacing must fit the reported height
**and reject nominal scale** — fitting alone would not do, since a lens roll's reported
height implies ~0.80 overlap and the window's top is 0.78. A legible logbook scale equal to
the catalogue's would veto a row; no sampled page writes a scale, so it never fired.

The result:

| outcome | roll-heights | frames |
|---|---|---|
| tabled, factor 1, `scale_wrong` | 24 | 120 |
| excluded: logbook writes a 12" lens | 21 | 82 |
| excluded: spacing rejects the reported height | 7 | 31 |
| excluded: logbook lens and spacing disagree | 1 | 2 |
| excluded: logbook height not the catalogue's | 3 | 8 |
| excluded: logbook height not read | 1 | 5 |
| excluded: no logbook page | 1 | 4 |

- The 24 are 20 roll-heights at 153 mm (107 frames, sixteen of them 1972–76 `bc54xx`–`bc57xx`,
  plus `bc5138`, `bc78110`, `bc79039`, `bc79141`) and 4 at 305 mm (13 frames: `bc7692`,
  `bc85079`, `bc85080`, `bc85081`). Three of the 305 mm ones sit at r 1.65–1.69, not 2: the
  scale is the wrong field there too, but not by a factor of two, so `scale_wrong` names the
  field and not the ratio.
- Their keys reach **3,227** catalogue frames. That is an upper bound on what moves:
  terrain *lowers* r below its above-sea-level value, and the table is consulted only
  outside the band, so a frame on a tabled key over high enough ground (287–2,636 m,
  depending on the roll) is inside it and was already sized from its reported height —
  the same height the table gives it, so nothing changes there. In the sample, 120 of the
  132 frames on the tabled keys are beyond the band; the 12 inside are all on `bc85079`,
  `bc85080` and `bc85081`. The frames beyond it were drawn by the fallback at 1/r of their
  width — half, at r = 2; they are now drawn from the height the crew flew.
- The 82 frames whose logbooks write a 12" lens are the lens reading with a witness spacing
  never saw — the issue's lens rolls `bc78051`, `bc79072` and `bc80122` among them. Nominal
  scale remains right for them.
- `bc80048` fits neither story: its logbook writes 6", and spacing fits neither reading —
  0.79 under nominal and 0.89 under the reported height, both above the 0.78 top of the
  window. It stays on nominal because nothing here justifies moving it, not because the
  spacing supports nominal.
  `bc79043` is the reverse — 12" written, spacing fitting the reported height — and is
  excluded with a reason saying the witnesses disagree.

**Bound.** `near_upper` is a 600-frame sample of 2 < r above sea level ≤ 3, not a census.
Not measured: roll-heights no sampled frame sits on; the 505 `upper_tail` census frames that
#54 does not repair; and frames just under the stratum's floor. The largest known group is
there: **1,534 frames on nine 1985 rolls** (`bc85063`–`bc85091`) at 6,096 m, 305 mm and
1:10000, whose ratio above sea level is 1.999 against the sample's lowest 2.025. Two of them
turned up among the random draws beyond the band (`bc85083` r 1.73, `bc85090` r 1.63), their
neighbours `bc85080` and `bc85081` log 20,000 ft in the pages read here, and the tabled
`bc85079`–`bc85081` are the same camera, lens and scale — so they are likely the same
`scale_wrong`, and unmeasured. A third random frame, `bc5703` (1:6000, 153 mm, r 1.99), looks
like the 1972–76 group. An unlisted roll-height stays on nominal scale.

## What a partially covered footprint costs (fly#58)

A footprint hanging off the edge of the DEM is sized from the mean of the part that is
covered. `dem_coverage` has reported the fraction since fly#9 and `fly_dem_coverage_min()`
has warned below 0.95 since then, but nothing measured what it was worth. This section is
that measurement, and it changed one thing: `dem_elev_sd` now ships beside `dem_coverage`,
because coverage alone cannot tell an expensive truncation from a free one.

### It almost never happens against the DEM this package recommends

Measured before anything synthetic was generated, because the answer decides which remedy
is worth building. Candidates were found by distance to the nearest nodata cell on an
1833 m overview of MRDEM-30, read through `gdal_translate -outsize` so it resolves against
the COG's own overviews; every candidate was then measured at full resolution through
`fly_footprint()` itself.

| population | n | could reach nodata | DEM-sized | under 0.95 |
|---|---|---|---|---|
| film, DEM-eligible | 1,437,147 | 113 | 87 | **66** |
| digital | 223,667 | 173 | 6 | **0** |
| random film control | 3,000 | — | 2,975 | **0** |

So 66 frames in 1.44 million — 0.005%. Of the 173 digital candidates, 167 never reach the
DEM route at all: they are sized from their ground sample distance. The affected film
frames run 1982-1996 at 1:10000 to 1:70000, and 26 more are off the DEM entirely.

**The random draw is the control on the finder**, which reads a coarse overview and so
cannot see a nodata hole a few cells across. 0 of 2,975 randomly drawn frames were short
of full coverage, which is what licenses the census above as a census. Its residual blind
spot is a nodata patch smaller than a coarse cell.

**The issue's own figure does not reproduce.** fly#58 reports "18 of 416 DEM-corrected
frames fell under 95% `dem_coverage`, one as low as 47%" from the fly#50 run. Nothing in
the catalogue's digital population is partially covered by MRDEM-30. The likely
explanation is that the run supplied a DEM cropped to its own area of interest — which is
the failure this file already calls the ordinary one — but that is inference, and the run
left no artifact to check it against.

**The frequency is therefore not a property of the catalogue.** With the documented
default DEM it is a 0.005% event; with a DEM cropped to an AOI it happens exactly as often
as that AOI is under-buffered, which no measurement here can bound. That is why the
decision below rests on what partial coverage costs, not on how often it occurs.

### The cost is exactly the elevation bias over the height above ground

120 frames, stratified by scale and by a ruggedness surface computed from the coarse DEM —
both properties known before any truncation, never the error itself. Each frame's DEM
window was truncated from eight directions at eight depths, by `NA` masking and by extent
cropping, and the result compared against that frame's own full-coverage answer.
11,520 runs; `data-raw/dem_calibrate-coverage_error.R` reproduces all of it, and
`inst/extdata/dem_coverage_sweep.csv`, `dem_coverage_targets.csv` and
`dem_coverage_population.csv` ship so the suite recomputes every **table** here from the
artifact rather than trusting it — all eight, cell by cell, at the precision each is
printed to, with the table count itself asserted so a ninth cannot be added unchecked.
Figures stated only in **prose** are a different matter: some recompute and are asserted,
some recompute and are not, and eight are **not** recomputable from the shipped tables and rest on
the script's own run log instead: the digital population's route split, the 1982-1996 span
of the affected film frames, the ocean probe, the determinism check, the 0.215 correction
above, the `1.6e-13` analytic agreement at full precision (the shipped table is rounded, so
the suite checks 1e-5), the 223,667 digital total, and the 1833 m overview resolution.

**The treatment variable is the share of the nominal footprint removed, computed from
geometry before any DEM is read.** Achieved `dem_coverage` is recorded as an outcome, and
that distinction is load-bearing: truncation biases the first pass, which changes the
height above ground, which resizes the rectangle, which moves the coverage again.

**Measured, that feedback is negligible in the middle and real in the tail.** Across the
native runs, `share_removed` minus `1 - dem_coverage` has a median of **0.000**, a 90th
percentile of **0.055** and a maximum of **0.284** — so a 0.30 geometric share comes back
at a median achieved coverage of 0.699, and the two agree for most frames. The design
decision does not rest on the magnitude: achieved coverage is downstream of the treatment
whatever its size, so regressing the error on it would be fitting an outcome to an
outcome. The mapping between the two is published instead, because any shipped constant
has to be expressed in the number the code holds.

An earlier draft of this paragraph claimed a 0.30 target came back as 0.215. That figure
is from the two-frame feasibility probe, which parameterised the cut as a fraction of the
footprint's bounding box rather than as a share of its area — a different quantity, quoted
as if it were this one. It is the anecdote-into-the-note failure this file warns about,
and it survived two review rounds.

**Realised error equals `Δelev / height_agl` to 1.6e-13 over 10,248 runs.** The half-side
scales with the height above ground, so the whole first-order effect is the elevation bias
divided by that height, and the pipeline adds nothing measurable on top. This is a
terrain-statistics result that transfers past this package: partial coverage costs
whatever the covered mean differs from the true mean, scaled by the flying height.

Signed linear error against the full-coverage answer, by achieved coverage. Area error is
the square of this — roughly twice it, for small values:

Over the 6,743 of the 7,616 usable native `na_mask` runs whose frame the DEM still sized —
the 873 that lost their terrain entirely are `no_dem_coverage` and are counted separately
below, not mixed in here:

| achieved coverage | n | median | 5-95% | max abs |
|---|---|---|---|---|
| 0.99-1 | 402 | -0.000% | -0.034% .. +0.021% | 0.175% |
| 0.95-0.99 | 764 | -0.000% | -0.136% .. +0.148% | 0.794% |
| 0.90-0.95 | 552 | +0.005% | -0.316% .. +0.374% | 1.280% |
| 0.80-0.90 | 662 | +0.020% | -0.555% .. +0.707% | 2.520% |
| 0.60-0.80 | 922 | +0.036% | -1.194% .. +1.428% | 5.569% |
| 0.40-0.60 | 968 | +0.038% | -2.384% .. +2.656% | 8.577% |
| 0.20-0.40 | 966 | +0.007% | -4.316% .. +3.696% | 12.529% |
| 0-0.20 | 1,507 | -0.008% | -7.296% .. +5.487% | 23.563% |

**The signed median is near zero everywhere, and that is the trap.** Every median in the
table above is of the *signed* error; the DEM-vs-nominal and spread tables below are of
the *absolute* error, and the two are not comparable. Truncation is unbiased in
aggregate — losing high ground and losing low ground are equally likely across a
population — so a median is the wrong summary for a caller holding one frame. What grows
as coverage falls is the spread.

### 0.95 survives, for a better reason than it was chosen for

It was set to stay quiet on reprojection slivers. Measured:

| coverage floor | n | max abs linear error |
|---|---|---|
| >= 0.99 | 402 | 0.175% |
| >= 0.96 | 1,021 | 0.794% |
| **>= 0.95** | **1,166** | **0.794%** |
| >= 0.94 | 1,289 | 0.794% |
| >= 0.92 | 1,529 | 1.221% |
| >= 0.90 | 1,718 | 1.280% |
| >= 0.85 | 2,151 | 2.520% |

One percent of width is about two percent of area, which is what this file records as the
cost of the per-corner ray-casting the model defers. So at 0.95 the *worst* truncated
frame is still cheaper than an error already accepted in every frame, and the worst case
first passes that line at 0.92. The threshold is where it should be; only its
justification changes.

**It is not moved down**, although the median error stays under 0.05% all the way to 0.8.
The warning's own remedy — buffer past the corner, `half_side * sqrt(2)` — is correct at
every coverage, so moving the threshold down silences exactly the frames that advice
works on. And the median is not what a caller is exposed to; see the spread below.

### No fallback floor: the DEM route beats nominal scale at every coverage

The rule was fixed before the numbers existed: add a floor only if some coverage band
exists where the DEM route is worse than the nominal fallback it replaced, in the median,
on the population that occurs. There is none.

| achieved coverage | median abs DEM | median abs nominal | DEM worse on |
|---|---|---|---|
| 0.99-1 | 0.003% | 3.321% | 0 of 402 (0.0%) |
| 0.95-0.99 | 0.032% | 4.467% | 0 of 764 (0.0%) |
| 0.90-0.95 | 0.079% | 6.236% | 3 of 552 (0.5%) |
| 0.80-0.90 | 0.178% | 7.807% | 7 of 662 (1.1%) |
| 0.60-0.80 | 0.335% | 6.316% | 24 of 922 (2.6%) |
| 0.40-0.60 | 0.632% | 5.755% | 62 of 968 (6.4%) |
| 0.20-0.40 | 0.967% | 5.755% | 97 of 966 (10.0%) |
| 0-0.20 | 1.491% | 5.755% | 229 of 1,507 (15.2%) |

Even below 20% coverage the DEM route is better in the median by nearly four times, though
it is worse on 15% of runs there — the tail is what the next section is about. A frame sized from a sliver of its own terrain still beats
one sized from a scale referenced to ground it does not cover. **`no_dem_coverage` remains
the only fallback**, and it is reached only when a footprint finds no elevation at all.

Note this is a *sensitivity* measure, not a ground-truth accuracy claim: the reference is
the answer the caller would get by following the existing warning's advice and buffering
the DEM. What it licenses is "buffering is worth this much", not "the DEM route is
accurate to this much".

### `dem_elev_sd`, because coverage cannot separate the frames inside a band

At a fixed coverage the measured error spans **13 to 52 times** between frames, and until
now nothing on the row distinguished them. The issue said so at the outset — 47% covered
over a plateau costs nothing, 80% across a valley wall may cost a lot — and it is right:

| achieved coverage | median abs error | max abs error | spread |
|---|---|---|---|
| 0-0.20 | 1.491% | 23.563% | 15.8x |
| 0.20-0.40 | 0.967% | 12.529% | 13.0x |
| 0.60-0.80 | 0.335% | 5.569% | 16.6x |
| 0.80-0.90 | 0.178% | 2.520% | 14.1x |
| 0.95-0.99 | 0.032% | 0.794% | 25.1x |

**The predictor has to be computable from the cells the DEM route actually read**, because
that is all production has. A relief figure taken from the full window predicts well and
could never be reported. Candidates were fixed in advance and scored on held-out frames —
a third of the targets, untouched until the comparison:

| predictor, covered cells only | Spearman rho vs abs error |
|---|---|
| `dem_coverage` | -0.717 (0.717 in magnitude; more coverage, less error) |
| `covered_range` | 0.152 |
| `covered_sd` | 0.185 |
| `covered_grad` (planar fit) | 0.480 |
| `covered_grad` x lost share x side / agl | 0.801 |

Pooled, the gradient product barely beats coverage, and on that alone no column would have
shipped. **Pooling is the wrong comparison**: coverage dominates it, and the question is
what is left once coverage is known. Within each coverage band both spread measures carry
real signal — `covered_sd` at rho 0.39 to 0.59, `covered_grad` at 0.27 to 0.59 — and `sd`
is the better of the two in **five** bands of six while needing no plane fit:

| achieved coverage | `covered_sd` | `covered_grad` |
|---|---|---|
| 0-0.20 | +0.438 | +0.505 |
| 0.20-0.40 | +0.513 | +0.474 |
| 0.40-0.60 | +0.544 | +0.500 |
| 0.60-0.80 | +0.594 | +0.589 |
| 0.80-0.95 | +0.474 | +0.451 |
| 0.95-1 | +0.385 | +0.266 |

What it buys, on held-out frames, splitting each band at its median spread:

| achieved coverage | low-spread median | high-spread median | ratio |
|---|---|---|---|
| 0-0.50 | 0.719% (n=479) | 1.636% (n=480) | 2.3x |
| 0.50-0.80 | 0.231% (n=246) | 0.728% (n=246) | 3.2x |
| 0.80-0.95 | 0.066% (n=217) | 0.174% (n=218) | 2.6x |
| 0.95-1 | 0.006% (n=186) | 0.026% (n=187) | 4.1x |

So `dem_elev_sd` is the standard deviation of the DEM values under the returned footprint,
taken from values `fly_dem_sample()` already holds and read off the same pass as
`dem_coverage`.

**A calibrated bound is deliberately not shipped.** `4.97 * sd * (1 - coverage) / agl`
covers 95.3% of held-out runs, fitted on the training third alone — but it is a median
6.1 times the actual error and holds on only 89.4% of runs below half coverage, which is
where a caller would want it. A number that looks authoritative and is six times too large
is worse than the two inputs it was built from.

### The number that was missing was not a better description of the damage

Everything above measures what partial coverage *costs*. None of it tells a caller what to
*do*, and the population section says why that matters: against a remote MRDEM read this
happens to 66 frames in 1.44 million, so in practice it is a DEM cropped to an area of
interest that is too small. The remedy is not a better statistic, it is a bigger crop.

`dem_shortfall_m` is the metres the DEM would have to extend to contain the footprint. On
the same frame where `dem_coverage` reports 0.253 and `dem_elev_sd` 94.1 m, it reports
**3,822 m** — and `max(fp$dem_shortfall_m)` is the buffer that would contain the whole
batch. It needs no DEM read, being pure geometry, so it is computed on the rectangle the
caller actually receives rather than on the one the second pass sampled; those differed by
6.4 m on a 3,822 m shortfall, which is small and exactly the kind of near-miss that makes
a number impossible to check against the object in front of you.

**Zero is an answer, and it is the point of the column.** Partial coverage has two causes
that `dem_coverage` reports identically:

| cause | `dem_shortfall_m` | remedy |
|---|---|---|
| the DEM's extent stops short of the frame | > 0 | re-crop by that much; the frame is recovered exactly |
| nodata *inside* an extent that already spans the frame | 0 | none — no re-crop reaches it |

The warning distinguishes them in those words rather than quoting a coverage fraction at
both. That distinction is the part `dem_coverage` structurally cannot make, and it went
unbuilt for three releases because the question was framed as "how do we describe this
better" rather than "what is the caller supposed to do".

**Not an automatic top-up.** Falling back to MRDEM for the missing terrain was considered
and rejected: it partially ignores a documented argument and reaches the network without
being asked. Reporting the window the caller needs leaves the decision where it belongs.

### What the sweep is blind to

- **Ocean.** MRDEM returns a near-zero surface over near-shore water rather than nodata —
  40,000 cells in Hecate Strait read 0.098 to 0.189 m, with no exact zeros at all. A
  coastal frame therefore reports `dem_coverage` near 1 while its mean is dragged toward
  sea level. That is a coverage-1 failure, it cannot be produced by removing cells, and
  neither `dem_coverage` nor `dem_shortfall_m` can see it — the cells carry data and the
  extent does span the frame. Not fixed here; filed as fly#65. Note also that the obvious
  guard for it — counting exact-zero cells — can never fire.
- **The reference is one frame's own full-coverage answer**, which carries MRDEM's own
  vertical error and the ~2% of area that per-corner ray-casting would move. Differences
  below about 1% of width are not resolvable against it and are not read as a knee.
- **One target of 120 failed its premise** (`1154997`, scale_fine/relief_q4) and is
  excluded by name: its full-window reference was not a fully covered, DEM-sized,
  believed-height frame, so truncation would not have been the only treatment.
- **Film only.** A digital frame's DEM eligibility depends on `camera_calibration_url`,
  and its `scale` is not an image scale, so it carries no second statement of height to
  anchor against. The physics is media-independent, but it was measured on film.

### The controls that make the above readable

- **Both truncation mechanisms agree where it matters.** `NA` masking keeps extent, origin
  and resolution fixed; extent cropping moves them and is the only one that exercises the
  `on_dem` guard and `crop()`-clips-rather-than-pads. Over 1,856 matched runs the maximum
  error difference is 14.79% — but that is three runs at total loss, where a one-cell ring
  at the boundary decides between `dem_agl` with a handful of cells and `no_dem_coverage`.
  Restricted to the 1,633 runs where both kept the frame on the DEM route: **max 0.43%,
  99th percentile 0.11%, median 0.003%**.
- **Resolution, CRS and cell shape do not change the answer.** The same frames swept at
  ~900 m, reprojected to EPSG:4326 and with anisotropic cells give a median absolute error
  of 0.696%, 0.585% and 0.677% below 0.8 coverage against 0.777% natively, with zero
  classification flips. **Each arm is measured against its own full-coverage reference**,
  which the shipped tables key on `airp_id` AND `arm` for: an arm samples a different
  raster, so its reference is not the native one — `ref_n` is 90,692 cells natively and
  101 on the coarse arm for the same frame — and joining every arm to one reference
  conflates "this arm's DEM differs" with "truncation cost this much". The geographic arm matters most: the reprojection branch is the one
  0.95 was originally set for, and it does not execute at all on a DEM in the data's own CRS.
- **Truncation does not trip the fly#54 height checks.** 873 of the 7,616 usable native
  `na_mask` runs change classification (11.5%) and **every one is `no_dem_coverage` at
  coverage exactly 0** —
  the legitimate total-loss endpoint. Zero runs with any coverage at all flip to
  `"implausible"`, so the ratio band is not being crossed by a biased first pass.
- **A frame can be `dem_agl` with `dem_coverage == 0`.** Reachable, and self-consistent:
  the height came from the first pass and coverage describes the second-pass rectangle,
  which moved off the DEM. The documented `dem_coverage` filter still excludes it.
- **The sweep is deterministic.** A resume bug re-ran 40 targets twice; the two runs came
  back byte-identical across every column.

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
