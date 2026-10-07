# Findings — Frames under terrain where spacing rejects both nominal scale and the height read as above ground (#97)

## Issue context

## Problem

fly#95 tested whether the catalogued `flying_height` is a height above ground on the frames under terrain at or above the aircraft (`r <= 0`). On nine roll-heights, adjacent-frame spacing rejects **both** readings on offer: the catalogued height read as above ground, and nominal scale. These frames are drawn at nominal scale today, with a warning. Spacing does not support that fallback either.

| roll | height (m) | focal | scale | frames | of them `r <= 0` | overlap, above ground | overlap, nominal |
|---|---|---|---|---|---|---|---|
| `bc5715` | 732 | 153 | 1:4800 | 2 | 1 | 0.199 | 0.202 |
| `bc77026` | 2042 | 305 | 1:6000 | 118 | 11 | 0.479 | 0.419 |
| `bc77070` | 1158 | 153 | 1:5000 | 64 | 59 | 0.526 | 0.283 |
| `bc77072` | 1829 | 153 | 1:10000 | 17 | 1 | 0.355 | 0.228 |
| `bc77072` | 1981 | 153 | 1:10000 | 55 | 3 | 0.354 | 0.164 |
| `bc77087` | 1158 | 153 | 1:5000 | 57 | 38 | 0.478 | 0.209 |
| `bc7718` | 1524 | 305 | 1:5000 | 24 | 24 | 0.857 | 0.857 |
| `bc80117` | 1372 | 153 | 1:8000 | 19 | 19 | 0.860 | 0.843 |
| `bcc325` | 396 | 153 | 1:2000 | 2 | 1 | 0.285 | 0.075 |

The window is 0.557-0.780, from the generator. That is 157 `r <= 0` frames out of the 374. Source: `inst/extdata/flying_height_above_ground.csv`.

## Leads, none tested

- **Overlap below the window** (seven of the nine). The along-track side is longer than nominal, so the frames cover more ground than their scale says. The logbooks for `bc77026`, `bc77072` and `bc77087` write the catalogued heights under an M.S.L. header, and that figure is below MRDEM under some of the frames.
- **Overlap above the window** (`bc7718`, `bc80117`). The side is shorter than nominal. On `bc7718`, 1,524 m is 5,000 ft, which is exactly nominal height above ground for 1:5000 on a 12-inch lens.
- **A misplaced centroid.** A centroid on ground higher than the photo covers would give `r <= 0`, and spacing cannot see a translation. Thumbnails against the terrain could.
- **Frames that are not adjacent along one line.** The f1 air base rule takes the nearer neighbour by number. A roll flown in short legs could still pair frames across a turn.

## What to do

Decide whether any instrument can say what these frames covered. Fix any rule before running it, as in fly#60, #72, #93 and #95.

Related: fly#95, fly#93.

