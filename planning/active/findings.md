# Findings — A coastal frame is sized from sea level and reports full DEM coverage (#65)

## Issue context

## Problem

MRDEM-30 returns a **near-zero elevation surface** over near-shore ocean rather than
nodata. Measured over a 3 km window in Hecate Strait (`-130.9, 53.3`): 40,000 cells, all
between **0.098 and 0.189 m**, and **zero** exact zeros.

So a coastal frame half over water is sized from a mean that has been dragged toward sea
level. `flying_height - elev` is therefore too large, and the footprint is drawn too
**wide** — in the same direction, on every coastal frame, with no warning.

**`dem_coverage` cannot see this.** Those cells carry data, so the frame reports coverage
near 1 and `footprint_terrain = "dem_agl"`, exactly like a frame over solid ground.
`dem_shortfall_m` reports 0 for the same reason — the DEM's extent does span the frame.
Both columns added in v0.14.0 are blind to it by construction.

This was found while measuring fly#58 and is recorded there as a bound on that claim
rather than fixed. fly#58's sweep works by *removing* cells, and no amount of removing
cells can produce a frame that is fully covered by wrong values.

## Why the obvious guard cannot work

Counting exact-zero cells **can never fire**: there are none. A design review of fly#58
proposed exactly that test and it was falsified by the measurement above. Any guard has to
key on a low-variance near-zero *band*, or on a coastline intersect, not on equality.

## What is not known

- **How much it costs.** Unlike fly#58's case there is no full-coverage reference to
  compare against — the reference would have to be a DEM that represents the water
  correctly, or a land-mask. The error is bounded by `water_fraction x elev_land / agl`,
  which is computable once the water fraction is.
- **How many frames.** The BC catalogue has substantial coastal coverage and fly#58 did
  not count this population. It is plausibly far larger than the 66 frames partial
  coverage reaches, which would make it the bigger of the two problems.
- **Whether other DEMs behave the same way.** LidarBC and BC TRIM are the other two
  sources `fly_footprint()` documents. MRDEM's behaviour here is a property of that
  product, not of the package.

## Approach

Measure before deciding, as fly#58 did, and in this order:

1. **Count the population first.** Frames whose footprint intersects the FWA coastline, as
   a share of DEM-eligible frames. If it is small this may not be worth building.
2. **Establish the reference.** A land/water mask (FWA coastline, or MRDEM's own
   near-zero-variance signature) gives the water fraction per footprint, and the land-only
   mean gives the answer the frame should have had.
3. **Then decide.** Options, none pre-judged: report a `dem_water_fraction` column; exclude
   near-zero-variance cells from the mean; refuse to size a frame over a stated water
   fraction; or measure it and document that it is not worth correcting.

Do **not** start by writing a guard. fly#58's lesson was that the four remedies its issue
listed bounded the solution space and the useful answer was outside them.

## Notes

`inst/notes/terrain-correction.md` — see "What the sweep is blind to" in the fly#58
section, which records the measurement above and states plainly that this is out of scope
there. `data-raw/dem_calibrate-coverage_error.R` is the harness pattern to reuse.


## Decision rule — fixed 2026-09-29, before any coastal frame was measured

Committed before the first run so the verdict cannot be fitted to the numbers.

**Hypotheses.** For a frame whose footprint takes in sea:

- **W** (current code): the imaged surface is the mean of every DEM cell under the
  footprint, sea cells included at their ~0 m value.
- **L** (the issue's proposed reference): the right elevation is the mean of the land
  cells only; sea cells are an artefact.

**Instrument — reads no DEM.** Adjacent-frame air base `B` (same roll, frame number ±1,
the rule `fly_bearing()` and `height_calibrate-lower_tail_rolls.R` already use) against
the along-track side each hypothesis implies, `side_H = 0.2286 m × (flying_height −
elev_H) / focal`. Implied forward overlap `p_H = 1 − B / side_H`.

**Why a slope, not a level.** Let `d = side_W / side_L − 1` (≥ 0: sea lowers the W mean,
so W draws the wider frame). If W is true, `p_W` is flat in `d` and `p_L` falls with
slope `−(1 − p₀) ≈ −0.4`. If L is true, `p_L` is flat and `p_W` rises with slope
`≈ +0.4`. A slope is immune to the design overlap differing between coastal and inland
flying, which a level comparison is not.

**Primary statistic.** Within-roll (roll-demeaned) OLS slope of `p_W` on `d`, over coastal
frames with `d > 0`; 95% CI from 2,000 bootstrap resamples **by roll**.

**Verdict.**

- **W** if the CI lies wholly below **+0.2** (half the slope L predicts);
- **L** if the CI lies wholly above **+0.2**;
- **unresolved** otherwise — including when the CI is wider than ±0.2, which means the
  sample's spread in `d` is too small for the instrument. Reported as such, never as
  support for either.

`p_L`'s slope is reported beside it as the mirror check (W predicts −0.4, L predicts 0);
a verdict with the mirror disagreeing is reported as unresolved.

**Admission.** Film only (a digital frame's `scale` is not an image scale, fly#32).
Height believed as catalogued — `height_source == "catalogue"` from `fly_footprint()`
itself — so no fly#54/#60 repair sits inside the comparison. Both frames of the pair
present, base finite and non-zero. Sea fraction taken from the land polygon witness.

**Controls, run first, each able to stop the script.**

1. *Level*: inland random frames (`d = 0` by construction) return median `p_W` within
   0.1 of 0.6 — the lower-tail script's `ctl_ok`.
2. *Slope sensitivity (positive control)*: on the same inland frames, fly#9's datum offset
   is real (13.8% median) and is the same kind of error — an elevation under the
   footprint. Slope of `p_nominal` on `d_nom = side_DEM / side_nominal − 1`, roll-demeaned,
   must come back negative and inside [−0.6, −0.2]; slope of `p_DEM` on the same `d_nom`
   inside [−0.2, +0.2]. If the instrument cannot see fly#9's offset, it is not believed
   about this one.
3. *W reproduces the package*: the all-cells mean computed here equals the elevation
   `fly_footprint()` sized the frame from (`flying_height − height_agl`) to 1e-6 m.

**Land/water, two witnesses sharing no ancestor.** The BC terrestrial boundary polygon
(`bcmaps::bc_bound_hres()`, BC Data Catalogue record `30aeb5c1…`; inland lakes are inside
it, so only sea counts as water — correct, since a lake surface sits at its own elevation
under either hypothesis) and MRDEM's own near-zero band. Their disagreement is published.
A frame whose outside-polygon cells are not near-zero is over a land border (Alberta,
Yukon, Alaska, Washington), not over sea, and is excluded by name with a count.

## Phase 1 probe — what MRDEM holds over sea (2026-09-29)

3 km windows at nine sites, read at full resolution; cells split by the BC terrestrial
boundary polygon. Producer: the probe script in the session scratchpad, reproduced as
Stage 1 of `data-raw/dem_measure-coastal_water.R`.

| site | sea cells (median, range) | land cells | exact zeros |
|---|---|---|---|
| Hecate Strait (issue's site) | 0.136 m, 0.105..0.174 | — | 0 |
| Strait of Georgia | 0.137 m, 0.074..0.205 | — | 0 |
| Dixon Entrance | 0.137 m, 0.119..0.148 | — | 0 |
| Howe Sound (fjord) | 0.020 m, −1.52..78.1 | median 293 m | 0 |
| Boundary Bay (tidal flat) | 0.037 m, −1.87..1.07 | — | 0 |
| Roberts Bank (delta) | 0.072 m, −1.02..2.74 | median 1.14 m | 1 |
| Queen Charlotte Sound | **all nodata** | — | — |
| west of Haida Gwaii | **all nodata** | — | — |
| Knight Inlet (fjord) | — (window all land in polygon) | median 1000 m | 0 |

- The issue's measurement reproduces: 0.105–0.174 m, no exact zeros.
- **Near-shore sea is ~0.14 m, open water further out is nodata.** So MRDEM carries a sea
  surface for some distance off the coast and then stops. A frame over the far water sees
  the fly#58 partial-coverage case, not this one.
- ~0.1 m is a plausible sea surface against CGVD2013 (mean sea level sits within tens of
  centimetres of the geoid on this coast). The values are **not** an artefact standing in
  for nodata; they are an elevation, and a correct one to within the tide.
- **The near-zero band cannot be the land/water witness.** 14.8% of Roberts Bank *land*
  cells read |elev| < 1 m (a delta at sea level), and fjord shore cells outside the
  polygon reach 78 m (polygon/DEM misregistration at a steep shore). The band is published
  as the second witness, the polygon is the one the rule uses — as fixed above.

## Amendments to the rule — made before the first coastal frame was measured

Found while writing the script, from reading `fly_footprint()`; none depends on a result.

1. **Name.** The column value meaning "height believed as catalogued" is
   `height_source == "reported"`, not `"catalogue"`. Same admission, right spelling.
2. **Control 3 cannot be exact.** `fly_footprint()` samples the DEM under the second-pass
   rectangle and returns a slightly different one (the terrain note, fly#58
   `dem_shortfall_m`: "those differed by 6.4 m on a 3,822 m shortfall"). So the all-cells
   mean read here under the *returned* rectangle is not the package's elevation to 1e-6 m.
   Instead: W is taken **from the package** (`flying_height − height_agl`), and L is
   `W + (mean_land − mean_all)`, both means read here under the one returned rectangle, so
   the W–L difference is measured on identical cells. Control 3 becomes: median
   |mean_all − W| under 1 m over admitted frames, or the script stops.
3. **Turns and gaps, trimmed on a hypothesis-free quantity.** A frame whose base is under
   0.5× or over 1.5× its roll's median base (across a turn, a skipped exposure) is dropped
   before either overlap is computed. The window is symmetric and does not read `p_W` or
   `p_L`, so it cannot favour either.
4. **Coastline.** FWA coastlines (`WHSE_BASEMAPPING.FWA_COASTLINES_SP`, 56,204 lines,
   37,908 km, fetched whole through `bcdata`) decide which frames are coastal: the
   centroid within the nominal half-diagonal of a coastline. The land polygon decides
   which cells are sea. Frames with `dem_coverage` under `fly_dem_coverage_min()` are
   excluded — that is fly#58's case (open water is nodata, the probe above), not this one.

## Amendment 2 — the instrument changes, before any coastal frame was measured (2026-09-29)

Driven by plan review 1 (`review-1.md`). The first run was stopped in Stage 2, during
population selection: **no frame had been sized and no overlap had been read**, so this
amendment cannot have been fitted to a result. `data-raw/.cache/dem_coastal/runs/` was
empty when it was killed.

**Why the spacing witness is demoted.** It measures when the shutter fired, not what the
photo covered: an intervalometer set from the planned datum, or an overlap regulator
tracking ground texture near nadir. Over water a regulator has nothing to track, so its
behaviour changes exactly where the question lives, and an inland control cannot calibrate
that. It stays in the script as a **secondary** reading with its bias predicted now: if it
leans anywhere over sea, **toward L**, by crew practice rather than geometry.

**The primary reference is a ray-cast.** Once the Phase 1 probe established the sea values
are a real elevation, W vs L is a question about how cells are *combined*, which the
package's own model can answer exactly. Under the vertical camera `fly_footprint()` already
assumes, each point of the returned rectangle maps to an image point; its true ground
position is where the ray through it first meets MRDEM, found by descending from the
window's highest elevation and bisecting at the first crossing (so occlusion is handled).
32 rays per edge. The true footprint T is that 128-vertex ring. W is the package's
rectangle; L is W scaled about the centroid by `(H − e_L) / (H − e_W)`; **S** (per-side,
review S1) is scored for reference and not shipped.

**Metrics — one per kind of consumer (review A1).**

- *Area* (`fly_coverage()`, `fly_overlap()`): linear error `sqrt(area / area_T) − 1`.
- *Land edge* (`fly_filter()`, `fly_select()` against a land AOI): land falsely included,
  `area(land ∩ C \ T) / area(land ∩ T)`, and land falsely excluded,
  `area(land ∩ T \ C) / area(land ∩ T)`.

**Rule.**

1. *Materiality.* Publish the distribution of `d = side_W / side_L − 1` over coastal
   frames. If its 95th percentile is under **1%** of width — the error the package already
   accepts for deferring per-corner ray-casting — the W/L choice is immaterial whatever the
   verdicts below say, and that is the finding.
2. *Area verdict.* Paired, on coastal frames with `d > 0`: the median of
   `|err_W| − |err_L|`, 95% CI by 2,000 roll-bootstrap resamples (seed 65). W is better if
   the CI is wholly below 0, L if wholly above, otherwise tied.
3. *Land-edge verdict.* The same on `false_incl + false_excl`.
4. *The premise.* The issue claims coastal frames are sized wrong **because of the sea**.
   Compare W's error on coastal frames against W's error on inland frames, which carries
   only the per-corner cost already accepted. A remedy is warranted only if the coastal
   95th percentile exceeds the inland 95th percentile by more than **1% of width** on
   either metric. If not, the finding is documentation. If so, which remedy is a schema
   decision and goes to the user.

**Controls, each able to stop the script.**

- *Flat*: on a synthetic level DEM, T's area equals W's to 1e-5 relative.
- *Step*: on a synthetic DEM at 0 m on one side of the centroid and 500 m on the other,
  T's area equals the analytic `2a²((H − e)² + H²)` to 1e-4 relative, and W's area
  exceeds nothing — `4a²(H − e/2)²` — so the Jensen gap `e²` is reproduced.
- *Inland*: W's inland linear error is published as the reference level; it is the
  "~2% of area" per-corner figure the note already states, now measured.

**Admission.** Film, `footprint_terrain == "dem_agl"`, `height_source == "reported"`,
`dem_coverage >= fly_dem_coverage_min()`. A frame is excluded if any ray reaches nodata, or
if more than 10% of its outside-polygon cells read above 2 m or any reads nodata (a land
border, review G7). Every exclusion is counted.

**Sampling fix (review B3).** A run is 10 consecutive frame numbers from the whole roll,
centred on a coastal frame drawn within a scale × coastal-relief stratum. Only the centre
frame's stratum is used; its neighbours are measured and admitted on their own coastal
flag.

Also carried: `dem_elev_sd` by sea fraction (review G3), one LidarBC coastal probe
(review G4), population counted on fly#58's own eligibility (review G8), digital dropped
(review S3).

## LidarBC over sea (review G4), 2026-09-29

Two public LidarBC 1 m tiles over Howe Sound (`bc_092g054_xl1m_utm10_2019`,
`bc_092g044_xl1m_utm10_2019`, via the public `stac-elevation-bc` collection), aggregated to
20 m with any-NA → NA, cells split by the land polygon:

| tile | sea cells nodata | finite sea median | land cells nodata |
|---|---|---|---|
| 092g054 | 75.2% | −2.533 m | 44.8% (outside the flown block) |
| 092g044 | 91.9% | −2.533 m | 55.9% |

So **LidarBC is nodata over most sea**; the remainder reads a flat −2.533 m, which looks like
a hydro-flattened water surface. `fly_footprint()` on LidarBC therefore already computes
something close to **L** for a coastal frame — the mean of the land cells — reports
`dem_coverage` below 1, and when that falls under 0.95 it warns about "nodata *inside* its
extent" with no re-crop that helps. The same frame gets W on MRDEM and ≈L on LidarBC. Which
of the two is right is the question the ray-cast settles. TRIM's WCS
(`openmaps.gov.bc.ca/om/wcs`) returned 503 at probe time and is not characterised.
