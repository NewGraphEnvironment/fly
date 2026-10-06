# Findings — Three infrared roll-heights carry a right height beside a wrong scale (#91)

## Issue context

## Problem

fly#89 sized infrared film as the 9-inch negative, so IR frames now reach the #54 `flying_height` check. 56 of the 3,825 IR frames fall outside `fly_height_ratio_band()`. They sit on three roll-heights. On every one of them, adjacent-frame spacing in `inst/extdata/infrared_film_frames.csv` fits the **reported** height and rejects nominal scale. The figures are printed by `data-raw/format_measure-infrared_film.R` and recomputed by `test-fly_footprint_infrared.R`:

| roll | frames | scale | flying_height | focal | ratio above sea level | r | overlap at nominal | overlap at reported |
|---|---|---|---|---|---|---|---|---|
| `bc5312` | 17 | 1:30000 | 3353 | 153 | 0.731 | 0.47 | 0.805 | 0.594 |
| `bci12` | 14 | 1:15840 | 3682 | 305 | 0.762 | 0.51 | 0.807 | 0.620 |
| `bci9` | 25 | 1:8000 | 5944 | 305 | 2.436 | 2.03 | 0.228 | 0.620 |

The window is 0.557 to 0.780. The logbook pages write each catalogued height: 11.0, 12.08 and 19.5 thousand feet. So each roll-height carries a right height beside a wrong `scale`, the defect fly#60 and fly#72 tabled for BW and colour.

Today all 56 are drawn at nominal scale, with or without a DEM. That is about 2x (`bc5312`, `bci12`) or 0.5x (`bci9`) the width the spacing supports. With a DEM the #54 check sends them to nominal; without one every film frame is nominal.

## What to do

**The existing rules do not reach two of the three.** `data-raw/height_calibrate-lower_tail_rolls.R` reads the strata cut on ratio above sea level: `lower_tail` (at or below 0.5), `upper_tail`, and `near_upper` (2 to 3).
- `bci9` (2.436) is inside `near_upper`, so it can go through the near-upper rule as it stands.
- `bc5312` and `bci12` (0.73, 0.76) leave the band only through terrain, so no stratum holds them.

Settling those two needs a rule for terrain-driven out-of-band frames, fixed before it is run. The witnesses are the same: logbook and spacing.

**Logbook note on `bci9`.** Sheet 2 (`bcir9_2.jpg`, finals 101-128) has "Scale 1/15,840" written on it. Its 1:8000 frames are 12-36, which sheet 1 covers, and sheet 1 writes no scale. So that note is not yet a witness for them.

**The rules were fixed for BW and colour.** Check whether any of them assumes BW/colour before running them on IR, and record any amendment as such.

Found in code-check rounds 3-4 of fly#89. It was out of scope there: that issue settles format, not height.

