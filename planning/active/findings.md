# Findings — fly#54's ÷10.764 looks like ÷10 on the pre-2000 slipped rolls (#71)

## Issue context

## Problem

fly#54 repairs 1,589 film frames by dividing `FLYING_HEIGHT` by 3.28084² = 10.764. Measured
while settling fly#60, that factor looks right for the 2003 rolls and **about 7.6% wrong for
the pre-2000 ones**, where the defect appears to be a dropped decimal point, ×10.

Two independent signs, both from public data:

- **A flight logbook.** Roll `bc78065` is catalogued at 4,115 m (13,500 ft) on its 1:2000
  frames. Its scanned logbook page (`flight_log_url`), read with the catalogue values withheld,
  gives TRUE HEIGHT **1.35**, i.e. 1,350 ft. ÷10 gives 411 m; ÷10.764 gives 382 m.
- **Round feet.** Planned altitudes are round numbers of feet. Under ÷10 the pre-2000 slipped
  heights land exactly on them: bc5596 8,600 ft, bc78065 1,350, bc78078 3,100, bc79103 7,200,
  bcc00085 18,000 / 18,500 / 19,000. Under ÷10.764 they don't.

The ratio to `scale × focal_length` points the same way. Ordinary frames centre on r = 1.03:

| roll | year | frames | r ÷10 | r ÷10.764 |
|---|---|---|---|---|
| bc5596 | 1974 | 8 | 0.957 | 0.856 |
| bc78065 | 1978 | 24 | 0.975 | 0.880 |
| bc78078 | 1978 | 15 | 0.957 | 0.884 |
| bc79027 | 1979 | 10 | 0.970 | 0.898 |
| bc79103 | 1979 | 24 | 1.031 | 0.929 |
| bcc00085 | 2000 | 236 | 1.030 | 0.944 |
| bcc03004 / 06 / 07 / 08 / 46 | 2003 | 1,054 | 1.15–1.22 | 1.06–1.11 |
| bcc05001 | 2005 | 217 | 1.078 | 0.979 |

The 2003 rolls carry measured per-frame heights, not planned ones, so round feet cannot speak
for them, and there ÷10.764 is the better fit.

## Why it matters

A pre-2000 slipped frame is drawn about 7.6% narrow (15% in area). Every one of the 1,589 lands
in the band under either factor, which is why #54's band test could not separate them.

## What would settle it

The logbook pages for the other 12 slipped rolls, read the same way as fly#60's
(`data-raw/height_calibrate-lower_tail_rolls.R`, stage 4). If they agree, the fix is to carry
the pre-2000 rolls in `flying_height_rolls.csv` with factor 1/10, not to change
`fly_height_slip_factor()`.

## Evidence

`data-raw/flying_height_logbooks.csv` (the `CONTROL_bc78065` rows),
`inst/extdata/flying_height_sweep.csv` (`set == "upper_tail"`), and the fly#60 section of
`inst/notes/terrain-correction.md`.

