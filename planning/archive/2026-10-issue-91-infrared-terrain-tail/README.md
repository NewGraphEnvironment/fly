## Outcome

fly#89 brought infrared film into the #54 height check, and 56 IR frames fell outside the
band. They sit on three roll-heights where spacing fits the reported height and rejects
nominal, a right height beside a wrong `scale`. No roll-table rule reached them, because the
generator read only the BW/colour sweep. `data-raw/height_calibrate-lower_tail_rolls.R` now
reads #89's IR census. It settles `bci9` (ratio above sea level 2.436) alongside #72's
`near_upper` sample, and puts `bc5312` and `bci12` (0.731, 0.762: out of band only through
terrain) under a new tail, `terrain`, with #72's rule unchanged. The rule was committed
(c9d6a03) before a blind logbook read (197ad06). All three are tabled at factor 1
(`scale_wrong`). One BW/colour assumption was found and amended before the read: the scale
pattern accepted only `1:N`. The same terrain-only population among BW/colour frames is out
of scope and filed as fly#93.

## Measurement

- The blind logbook read gave 11.0, 12.08 and 19.5 thousand feet. Converted, that is
  3,352.8, 3,682.0 and 5,943.6 m against the catalogue's 3,353, 3,682 and 5,944, and it
  agrees with #89's non-blind reviewer.
- Spacing at the logbook height is 0.594, 0.620 and 0.620; at nominal it is 0.805, 0.807 and
  0.228. The window is 0.557-0.780.
- With a DEM, the frames are now drawn at r = 0.473, 0.506 and 2.030 times the nominal width.
- The three keys reach exactly their 56 frames. Every BW/colour row of both tables is
  byte-identical, which also shows amendment A1 moves nothing.
- Per-tail reach (a new producer line) corrected a claim stale since #72: `near_upper` reaches
  3,252 catalogue frames against 145 measured. Only the census tails reach exactly what they
  measured.
- BW/colour random draws out of band only through terrain: 12 of 2,500 (fly#93).
- A dry run before the transcription existed sent all three to `_excluded.csv` as "no logbook
  page covers these frames". That is the refusal path working.

## Evidence

`planning/archive/2026-10-issue-91-infrared-terrain-tail/run_rolls.log`; review rounds
`review-round*.md`.

Closed by: PR for branch 91-three-infrared-roll-heights-carry-a-right
