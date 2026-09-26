## Outcome

fly#54 left 1,962 film frames reading under half the height their scale implies as
`"implausible"`, because ×10.764, ×10 and ×2 each explained a comparable share when pooled.
Plan-mode exploration found that was the wrong unit. The frames sit on 42 rolls, nearly each
carrying one round-feet `flying_height`, so the tail is 77 roll-heights.

Two instruments independent of the disputed fields settled 22 of them (1,001 frames). One was
the spacing between frames adjacent by number, measured against the ~60% designed overlap. The
other was the province's flight logbook scans, 120 pages transcribed by three parallel readers
with the catalogue values of three control rolls withheld. The corrections ship as
`inst/extdata/flying_height_rolls.csv`, which `fly_footprint(dem = )` reads, marking those
frames `"corrected_roll_table"`; the other 55 roll-heights ship with reasons in
`flying_height_rolls_excluded.csv`.

The largest surprise was a remedy the issue did not list. On 11 roll-heights the height is
right and the **scale** is wrong, so #54's fallback to nominal was itself the defect. The
controls also exposed two findings outside the issue, both filed rather than acted on: #71
(#54's own factor looks like ×10 on pre-2000 rolls) and #72 (half the r ≈ 2 mass is a wrong
scale, not a mislabelled lens).

## Measurement

- **Spacing controls.** Random in-band frames read 0.63 [0.59–0.69] (n 2,481). #54's slipped
  frames read 0.62 after ÷10.764 and 0.97 before. The acceptance window, the random frames'
  2.5–97.5%, is 0.557–0.780. Spacing separates readings ~1.6× apart and no closer.
- **Logbook controls.** `bcc228` reads 12.650 / 14.0 against 3,856 / 4,267 m, and the
  `bc7349/7350` page reads 20.0 against 6,096 m, both exact. `bc78065` (#54-slipped) reads
  1.35, i.e. 1,350 ft, where the catalogue has 13,500 ft: a decimal point, not ×10.764.
- **Verdict.**
  - ×10: 10 roll-heights, 511 frames.
  - ×100: 1, 101 frames.
  - Height right, scale wrong: 11, 389 frames. Nominal scale drew these 2.05–10.4× too wide.
  - Excluded: 55, 961 frames — 30 no page, 8 spacing rejects, 5 not read, 4 no named
    multiple, 4 different lens, 2 rows disagree, 2 under half covered.
  - The four-field key reaches exactly the 1,001 measured frames.
- **Wrong turns, kept.** The script first treated the note's r≈2 claim as a control, and it
  failed as one (nominal median 0.50 [0.13–0.69]). Split per roll it became #72.
- **Code-check.**
  - Round 1: shipping catalogue × factor left `bc7280` 96 m short; now ships the logbook
    height.
  - Round 2: `paste()` spelt 100000L and 100000 differently in the key.
  - Round 3 found a defect inside round 1's fix: three logbook states were folded into
    "no page". This moved the exclusion counts from 36/3 to 30/5/2/2.
  - Ended by enumerating all 77 labels against an independent predicate: 77/77 agree.
- **Suite:** 2,279 passed, 0 failed. Seven restored defects each turned a test red.

## Evidence

`data-raw/height_calibrate-lower_tail_rolls.R` prints every figure above from the gitignored
`data-raw/.cache/centroids/*` and `data-raw/.cache/logbooks/*`. The transcription is
`data-raw/flying_height_logbooks.csv`, and the review rounds are `review-round*.md` in this
directory.

Closed by: PR for branch `60-lower-tail-flying-height` (v0.15.0)
