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
