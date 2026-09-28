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
  10.751, within 0.12% of 10.764 (|d| = 30 m with 3.28084²). A 2% tolerance lets both neighbours name a
  factor, and they name different ones. Only the whole-metre rounding tolerance
  (0.5 * (k + 1) m) separates them.
- `bcb98013` at 1:40000/153: 207 frames at 7,924, frame 52 at 97,924; frames 51 and 53 both 7,924.
- bc5596 carries nine roll-heights (2286 to 2621 at 1:12000, 2529 at 1:16000): legs stepping altitude.

## Generator run, fixed rule (2026-09-27)

`Rscript data-raw/height_calibrate-lower_tail_rolls.R` (frozen copy), exit 0, all controls pass.

- Sibling witness settles **4 roll-heights (54 frames) of the 521 the logbook left**:

  | tail | roll | catalogue m | lens | scale | frames | relation | sibling frame | height m | overlap | r |
  |---|---|---|---|---|---|---|---|---|---|---|
  | lower | bc87070 | 396 | 153 | 23000 | 34 | /10 | 203 | 3,962 | 0.597 | 0.795 |
  | lower | bcc822 | 701 | 305 | 15000 | 11 | /10 | 119 | 7,010 | 0.613 | 1.098 |
  | upper | bc5596 | 26,212 | 153 | 12000 | 8 | x10 | 203 | 2,621 | 0.619 | 0.957 |
  | upper | bcb98013 | 97,924 | 153 | 40000 | 1 | leading digit | 51 | 7,924 | 0.656 | 1.124 |

- The two lower-tail rows were not in the issue, and the logbook corroborates both
  independently, though not in a way the logbook rule could read:
  - `bc87070` 169-202: logbook row "169-20?" reads 13.0 (13,000 ft = 3,962 m), but its frame
    range did not parse, so "logbook height or frame range not read". Frames 203+ read 3,962.
  - `bcc822` 120-130: the crew wrote "2300" (four digits) between rows of 22,500 and 23,000 ft;
    the catalogue copied the dropped zero (701 m = 2,300 ft). Frame 119 reads 7,010 (23,000 ft).
    Frame 131 on the other side reads 6,858 (22,500 ft), which names nothing, so it doesn't
    contradict.
- Refused, by reason (roll-heights / frames): lower: no adjacent frame at another height 10 / 486,
  no exact relation 7 / 183, no adjacent frame in band 36 / 247. upper: no exact relation 1 / 10
  (`bc79027`), no adjacent frame in band 463 / 1,271 (the 2003/05 rolls, every neighbour slipped too).
- Totals: 32 roll-heights corrected (1,354 frames; lower 1,001 logbook + 45 sibling, upper 299 +
  9), 517 excluded (2,197). Catalogue reach 1,354 = measured. Slipped frames still on ÷10.764:
  1,281 (was 1,290).

## Plan correction: x10.764 is a named sibling relation in the upper tail

The approved rule named only x10 and leading digit for the upper tail. With that set the
2,438 m neighbour of bc5596 could never name anything, so the whole-metre tolerance guarded
nothing: loosening it to 2% changed no result. The logbook rule's upper set is {1/10, 1/10.764},
so the sibling set now matches it. A unanimous x10.764 is "adjacent frames confirm #54's
10.764" and is not tabled, the same as for the logbook. No roll-height hit that reason.

Restore-the-bug, measured: with `exact()` swapped for a 2% relative tolerance, bc5596 is refused
("adjacent frames name different relations", 8 frames) and the generator stops at the bc5596
control, leaving the CSVs untouched (checked with `cmp`). Under 2%, bc79027 also flips to
"spacing rejects the sibling's height".

## Deviation: excluded table carries `sibling_reason`, not `witness`

`witness` means nothing on a row nobody settled. The excluded table instead says why the sibling
witness passed each row over, beside the logbook's `reason`. So every excluded row carries the
reason each witness actually fired on.

## Correction after code-check round 3: the catalogue truncates as well as rounds

Round 3 (`review-round3.md`) found `exact()` assumed rounding only. The catalogue also truncates:
2,000 ft = 609.6 m is stored as 609 on bc5449/bc7584/bc5536, which the logbook table already
settles. That evidence owes nothing to Stage 5b. Across the cache the reviewer counted 50,579
frames at floored round-foot values and 363,865 at rounded ones.

- New bound: with the larger height `big`, each figure off its true value by a ∈ [−0.5, 1),
  big − k·small ∈ [−(1 + k/2), k + 1/2]. At k = 10.764 that is [−6.4, 11.3], so bc5596's 2,438 m
  neighbour (−30.4 with 3.28084²) still names nothing.
- Outcome change: exactly one. **bc7675 609 m (305 mm, 1:16000, 84 frames)** is accepted at
  6,096 m from frame 214. The residual is 6 m against 5.5 under the old form. The logbook names
  x10 on all 34 frames it reads (refused for 40% coverage); spacing 0.616, r 1.000.
- New totals: sibling 5 roll-heights / 138 frames. Corrected 33 / 1,438 (lower 1,001 logbook +
  129 sibling, upper 299 + 9). Excluded 516 / 2,113. Catalogue reach 1,438 = measured. Lower
  "no exact relation" 6 / 99.
- The 2% mutation still stops at the bc5596 control, CSVs untouched (`cmp`). The test pins
  bc7675 with the premise that 6096 − 6090 > 5.5.
- The sweep test's own exactness check had the symmetric form and, for lower-tail rows, the wrong
  direction (k = 0.1). It passed bc87070/bcc822 by luck. Rewritten to the big/small form.
- Methodology: the rule was amended after the first population run. The amendment's evidence is
  independent of the outcome, and the rule's stated intent (the catalogue's storage precision)
  was already this; the first form got the storage wrong. Recorded in the note.
- Accepted, not changed: "adjacent frames name different relations" also labels one neighbour
  naming two relations, and two neighbours at different heights naming one relation. Neither
  occurs in the data (round 3).
- Round 2's vignette finding ("28 roll-heights") is fixed in the Phase 4 docs.

## Code-check round 4: a third storage, and the enumeration that ended the loop

Round 4 found a defect inside round 3's fix, and it was documentary only. "Rounds or
truncates" is not everything the catalogue does: some figures were converted at 3.28 ft/m and
rounded (20,000 ft = 6,098 on 2,677 frames; 15,000 ft = 4,573 on 770; 10,000 ft = 3,049 on 106).
Such a figure is off by about −(0.5 + 0.000256·T), which can only push a genuine relation
outside the bound, toward refusal. The bound was not widened after the fact; the docs now say
it covers 0.3048 conversions and that a 3.28 figure refuses.

**Enumeration (terminal):** every adjacent neighbour of all 521 roll-heights the logbook left
gives 3,876 (pair, relation) rows. Under the new interval exactly the four tabled factor rows
name a relation; the old interval gives the same four minus bc7675. The only near-bound pair is
bc5596's 2,438 m under x10.764, at r = −30.4 against [−6.4, 11.3]. No "different relations"
case occurs. No pair sits between either bound and two widths past it. Loosening the digit
string relation to ±1 finds nothing beyond bcb98013 frames 51/53.

Doc slips fixed: "31 m" → 30 m (3.28084², not the rounded 10.764). bc7675's logbook agrees on
the factor, not the height (20,200 ft = 6,157 m, 1.0% above). The vignette's "where they are
silent" becomes "where they do not settle it" (bc7675 and bcb98013 have logbooks that speak).
