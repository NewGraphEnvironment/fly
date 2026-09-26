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


## Exploration (plan mode, 2026-09-26)

- Slipped roll-heights (sweep `upper_tail`, in band after ÷K) sit on 13 rolls. The issue's table
  lists 12 and leaves out `bcb98013` frame 52: 97,924 m on a roll whose other 207 frames read
  7,924 m. That is an extra leading digit.
- Logbook links: pages exist for the slipped frames of bc78078 (p6), bc79027 (p4), bc79103 (p5),
  bcb98013 (p1) and bcc00085 (p1). The control bc78065 has already been read. There is no page for
  bc5596 frames 204–211 (the catalogue URL is NA for 141–211), and there are none for the six
  2003/2005 rolls (bcc03004/06/07/08/46, bcc05001).
- bc5596 204–211 catalogue 26,212 m, exactly ×10 of frames 141–203 at 2,621 m on the same roll.
  That is a sibling witness, recorded here and not used as an instrument.
- `R/fly_footprint.R` `tabled` accepted only `factor == 1` or `factor > 1`, so a 1/10 row would be
  dropped silently and handed to #54's repair.

## Blind logbook reading (2026-09-26)

The five pages were fetched into `data-raw/.cache/logbooks/` and transcribed by a subagent that saw
the images and the column spec only, with no catalogue values. The rows are appended to
`data-raw/flying_height_logbooks.csv`.

| roll | catalogue m | logbook ft | logbook m | vs ÷10 | vs ÷10.764 |
|---|---|---|---|---|---|
| bc78065 (control) | 4,115 | 1,350 | 411.5 | 0.0000 | +7.63% |
| bc78078 | 9,449 | 3,100 | 944.9 | 0.0000 | +7.64% |
| bc79027 | 19,995 | 6,500 | 1,981.2 | −0.92% | +6.65% |
| bc79103 | 21,946 | 7,200 | 2,194.6 | 0.0000 | +7.64% |
| bcc00085 | 54,860 / 56,390 / 57,910 | 18,000 / 18,500 / 19,000 | | ≤0.01% | +7.64% |
| bcb98013 f52 | 97,924 | 24,000 | 7,315.2 | −25% | −20% |

- ÷10 is exact to 1e-4 on six of the seven pre-2000 roll-heights. bc79027 is 0.9% off
  (19,995 = 6,560 ft ×10), inside the script's 2% rounding tolerance. ÷10.764 misses every one
  by 6.7–7.6%.
- bcb98013 fits no named factor. Its page is also headed roll **15BCB99013**, flight
  B-010-E-99, 1999, where the file prefix says 98013, and its 24,000 ft differs from the 7,924 m
  (26,000 ft) the roll's other frames carry. Either the catalogue links the wrong scan, or the page
  belongs to a sibling roll. Frame 52 stays on #54's ÷10.764, which gives 9,097 m against the
  7,924 m its roll-mates carry.
