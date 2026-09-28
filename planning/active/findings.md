# Findings — Two #54-slipped roll-heights a sibling frame settles and no logbook does (#74)

## Issue context

## Problem

fly#71 moved the pre-2000 #54-slipped roll-heights that a flight logbook reaches onto
`flying_height_rolls.csv` at ÷10. Two slipped roll-heights are still sized by #54's ÷10.764,
and in both cases the evidence says that is wrong:

- **`bcb98013` frame 52** is catalogued at 97,924 m. The other 207 frames on the roll read
  7,924 m, so this is a leading-digit typo and not a slip. ÷10.764 gives 9,097 m, which draws the
  frame about 15% wide in linear size. The logbook page the catalogue links (`bcb98013_1.jpg`) is
  headed roll **15BCB99013**, flight B-010-E-99, 1999, 24,000 ft. That fits neither 7,924 m
  (26,000 ft) nor the file name, so the catalogue may link the wrong scan.
- **`bc5596` frames 204–211** are catalogued at 26,212 m, ten times the 2,621 m (to the metre) (8,600 ft)
  of frames 141–203 on the same roll. No logbook page covers them: the catalogue's
  `flight_log_url` is NA for frames 141–211.

Neither frame fits the fly#60 rule, which needs a logbook page naming a factor. Both point at one
more witness the rule does not have: **the same roll's other frames**. For `bc5596` that witness
gives an exact ×10; for `bcb98013` it gives an exact leading digit.

## What would settle it

Decide whether a same-roll sibling height counts as an instrument, and under what rule. The rule
has to be fixed before looking: *adjacent by frame number*, *an exact named relation to the
neighbours' height*, and *the neighbours themselves in band*. Otherwise leave both on ÷10.764 and
close this issue as recorded.

## Evidence

`inst/extdata/flying_height_rolls_excluded.csv` (`tail == "upper"`) and the fly#71 section of
`inst/notes/terrain-correction.md`.



## Plan-mode probe (2026-09-27, centroid cache)

- `bc5596` at 1:12000/153: frames 200-203 read 2,621; 204-211 read 26,212; 212-215 read 2,438
  (logbook row 212-227 reads 8.0 = 8,000 ft = 2,438 m). So the run has TWO adjacent
  neighbours at different heights. 26212 / 2621 = 10.0008 (x10, |d| = 2 m); 26212 / 2438 =
  10.751, within 0.12% of 10.764 (|d| = 31 m). A 2% tolerance lets both neighbours name a
  factor, and they name different ones. Only the whole-metre rounding tolerance
  (0.5 * (k + 1) m) separates them.
- `bcb98013` at 1:40000/153: 207 frames at 7,924, frame 52 at 97,924; frames 51 and 53 both 7,924.
- bc5596 carries nine roll-heights (2286 to 2621 at 1:12000, 2529 at 1:16000): legs stepping altitude.
