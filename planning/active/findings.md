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

