# Findings — BW/colour frames out of the height band only through terrain (#93)

## Issue context

## Problem

Some BW and colour film frames leave `fly_height_ratio_band()` only because of the ground under them. Their catalogued `flying_height` is within the band of `scale x focal_length` above sea level, but subtracting the terrain takes the ratio above ground out of it. No roll-table rule reads them.

`data-raw/height_calibrate-lower_tail_rolls.R` cuts its strata on the ratio above sea level:

| stratum | ratio above sea level |
|---|---|
| `lower_tail` | ≤ 0.5 |
| `near_upper` | 2 to 3 |
| `upper_tail` | > 3 |

A frame in band above sea level is in none of them. With a DEM, the #54 check sends every such frame to nominal scale (`height_source = "implausible"`), whatever caused it.

fly#91 settled the infrared frames of this kind (`bc5312`, `bci12`) under a new `terrain` tail, because #89's IR census held all of them. The BW/colour ones were left out of scope there.

## How many

- In the sweep's `random` set, 12 of 2,500 frames are out of band only through terrain. All 12 are below the band and none is above it. The generator prints this line; the 2,500 are a draw from the BW/colour frames with ratio above sea level ≤ 2.
- That is 0.48%, with a Poisson 95% interval of about 0.25-0.84%.
- Scaled to the 1,419,822 usable BW/colour frames at ratio ≤ 2, it comes to roughly **7,000 frames, range 3,500 to 11,900**. This is an estimate from 12 draws, not a census.

It is not known how many of them are a wrong `scale` rather than a frame where nominal scale is right. Low flights over high ground are exactly where terrain is a large share of the reported height, so some of them may be fine as catalogued.

## What to do

1. **Census the stratum.** Take every BW/colour frame whose ratio above sea level is in band and whose ratio above ground is not. That needs MRDEM under each candidate, run as a PSOCK cluster per CLAUDE.md, and it can cover a superset first: frames whose `flying_height` minus the highest plausible terrain could leave the band.
2. **Group by roll-height, and pull and transcribe the logbooks blind.** Transcribe into `data-raw/flying_height_logbooks.csv` with the catalogue values withheld, as fly#60 and fly#91 did.
3. **Run the `terrain` tail's rule unchanged.** It is #72's near_upper rule: the logbook names factor 1, no focal-length conflict, spacing fits the reported height and rejects nominal, and no logbook scale equals the catalogue's. It was fixed in fly#91's archived findings before that read. Re-register it in writing before this census is read.

Related: fly#60, fly#72, fly#89, fly#91.

