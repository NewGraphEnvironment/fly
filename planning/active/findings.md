# Findings — Half the r≈2 mass is a wrong scale (#72)

## Issue context

## Problem

`inst/notes/terrain-correction.md` and the comment on `fly_height_ratio_band()` say the mass of
film frames beyond r ≈ 2 is a 305 mm lens catalogued as 153 mm, so falling back to nominal
scale is "the correct answer there and not merely the cautious one". Measured while settling
fly#60 by the spacing between frames adjacent by frame number, **that is true for about half
of them**.

For the 209 `near_upper` frames beyond r 1.8 catalogued at 153 mm, split per roll-height:

- **90 frames** (mostly 1978–81: bc78051, bc79072, bc80048, bc80122, …) give the designed ~60%
  forward overlap under nominal scale and ~80% under the reported height. 14 fit neither. That is the lens
  reading, and the fallback is right.
- **105 of the 209 frames** give ~60% under the **reported** height and ~20% under nominal.
  91 of those are on 1972–76 bc5xxx rolls (bc5701, bc5509, bc5508, bc5699, bc5702, …); 14 are
  not (bc5138 1965, bc79141, bc79043, bc79039, bc78110), and two 1972–76 rolls do not fit this
  way (bc7407 fits nominal, bc7454 neither). Key it per roll, not by year. The height and lens are right and
  `scale` is the wrong field, recorded at half its true denominator. The fallback draws these
  frames at **half their true width**, and nothing on the row says so.

The instrument was checked on known answers first: in-band random frames read 0.63
[0.59–0.69], and #54's slipped frames read 0.62 after repair against 0.97 before.

This is the upper-side mirror of fly#60's `scale_wrong` class, which fly#60 settles for the
lower tail with logbooks as the second witness.

## What would settle it

The same two instruments fly#60 used, per roll-height: the logbook height (it should equal the
catalogue's where the scale is the wrong field) and spacing. Rows that pass both go into
`flying_height_rolls.csv` with factor 1. That needs the table lookup to reach frames above the
band as well as below it; it already keys on the band edge, not on a direction.

## Evidence

`data-raw/height_calibrate-lower_tail_rolls.R` prints the per-roll split ("near_upper r > 1.8
at 153 mm").


What exploration found that shapes the work:
- `fly_footprint()` needs **no logic change**: `out_of_band` is two-sided and the factor-1 gate is
  `tab_factor == 1 & r_reported > 0` (R/fly_footprint.R ~1166–1193). A near_upper frame is
  `disputed`, not `slipped` (r/10.764 ≈ 0.19), so today it is `implausible` → nominal; tabled, it
  becomes `corrected_roll_table` at the reported height. Only comments/roxygen change.
- **0 of the 44 rolls have logbook rows** in `data-raw/flying_height_logbooks.csv`, and
  `fetch_logbooks()` runs only when the cache dir is absent. Transcription is the heavy phase.
- `settle()` already takes `(set, named, tail)`; spacing, the focal-conflict check (which is
  exactly the lens reading: logbook says 305 → excluded "names a different lens; nominal scale
  already sizes it") and the key-uniqueness guard carry over. Sibling witness (Stage 5b) relations
  are height relations only; near_upper rows skip it with a stated sibling_reason.
- Test `the table holds against the sweep…` hard-codes `tail ∈ {lower, upper}` and "factor-1 row
  ⇒ r < band[1]" — both widen.


## Errors Encountered

| Error | Resolution |
|-------|------------|
