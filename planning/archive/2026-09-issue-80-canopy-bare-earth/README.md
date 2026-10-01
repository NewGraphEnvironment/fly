## Outcome

fly#80 asked whether sizing footprints from MRDEM's bare-earth DTM, while the camera images the canopy, is an error worth acting on. Measured, it is not: sizing through `fly_footprint()` on MRDEM's DSM instead shrinks a frame by a weighted median 0.17% of width, 0.46% at the 95th percentile, under the 1% the rule fixed in advance. So no code or recommendation changed. The work was mostly instrument validation, and that is what was learned:

- MRDEM's DTM on radar cells (88% of BC) *is* its DSM minus NRCan's forest-removal model.
- NRCan's own HRDEM lidar covers almost none of those cells.
- Public LidarBC tiles showed MRDEM overstating canopy while its DTM sits ~2.5 m under lidar ground, so the two cancel (slope 0.916).

A ray-cast cannot decide "recommend a DSM", because a rectangle agrees by construction with a ray-cast onto its own surface. The photo-date question went to VRI stand origin (a DSM is worse on 1.3% of all 1970s frames) and to a follow-up for an observed witness, #82. fly#65's "a canopy can reverse the area verdict" does not hold, to first order, at the canopy BC has.

The rule was fixed before any frame was sized and amended five times, each before the data it governed existed. The wrong turns are kept in `findings.md`:

- A HRDEM witness that turned out to cover nothing.
- A probe that cached an empty result.
- LidarBC nodata read as 1e37.
- A 6.5-hour run caused by strip TIFFs read over `/vsicurl/`.
- An epoch test that compared VRI heights with the DSM on different scales.

## Measurement

| quantity | value | what it changed |
|---|---|---|
| d = side_DTM / side_DSM − 1, weighted, 594 admitted of 612 sampled | median 0.17%, 95th 0.46%, 99th 1.13%; 1.2% of frames over 1%, 99.5% of that weight fine-scale | MATERIAL false → outcome NOTHING |
| mean DSM − DTM under a frame, weighted | median 7.56 m, 95th 14.49 m | explains the size: 1% at the median 4,575 m above ground needs 46 m |
| census p (coarse canopy / nominal agl), 1,437,147 frames | median 0.16%, 95th 0.53%; calibrated against 30 m at 1.01 | stratification only |
| MRDEM source over BC land | radar 88.3%, lidar 7.5%, blend 0.4% | `DSM − DTM` is a model on most of BC |
| HRDEM lidar ground on MRDEM radar cells | 0 of 3,000 random points | HRDEM dropped as witness (Amendment 2) |
| LidarBC, 150 tiles on radar cells | imaged surface over MRDEM DTM = 0.916 × MRDEM DSM−DTM; MRDEM DTM −2.50 m under lidar ground; MRDEM DSM +0.34 m over lidar DSM | clause 3 holds: MRDEM's DSM is the imaged surface to ~10% |
| rectangle relief residual, weighted 95th | DSM 2.89%, DTM 2.86% | a DSM does not degrade the model |
| first order against the ray-cast | weighted median 1.68e-4 | `c/(agl − c)` is the canopy shift |
| epoch, DSM worse than DTM (VRI) | 1960s 7.3%, 1970s 15.1% (1.3% of all 1970s frames), 1980s 2.3%, 1990s 1.5% of frames where canopy matters | would decide a DSM recommendation; recorded, not reached |
| fly#65 under measured canopy, first order | median(|W| − |L|) −0.00127 (bare earth −0.00287) | fly#65's area verdict stands |
| over sea | DSM within 0.03 m of DTM at every readable site | fly#65's sea cells are surface-independent |

## Evidence

- `data-raw/.cache/logs/canopy_*.log` (gitignored, local to the measuring machine). `canopy_stage1g.log` is the clean LidarBC probe, `canopy_full.log` Stage 3, and `canopy_final.log` the verdicts. `data-raw/dem_measure-canopy_height.R` reproduces every figure from its keyed caches and ships `inst/extdata/dem_canopy_*.csv`, from which `tests/testthat/test-fly_footprint_canopy.R` rebuilds the note's tables and prose figures.
- Reviews: `review-1.md` (plan) and `review-round1.md` … `review-round4.md` (code-check). Rounds 2 and 4 each found real defects, round 2 inside round 1's fix. The loop ended on round 4's enumerated claim table.
- Write-up: `inst/notes/terrain-correction.md`, "A forested frame is sized from bare earth, and it does not matter (fly#80)".

Closed by: PR (this branch, `80-footprints-are-sized-from-bare-earth-but`)
