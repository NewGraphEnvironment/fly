## Outcome

fly#74 added a third witness for out-of-band `flying_height` roll-heights: a frame one number
away on the same roll, lens and scale, itself in band, whose height the catalogue's stands in an
exact named relation to (×10, ÷10, ÷100, ×10.764, one leading digit). Where no logbook settles a
roll-height, the neighbour's catalogued height is used, provided spacing agrees and no logbook
names a different factor. The rule was fixed at the plan gate and run over all 521 roll-heights
the logbook rule left excluded, in both tails. It settles the two the issue named (`bc5596`
204–211, `bcb98013` frame 52) and three lower-tail roll-heights nobody had flagged (`bc7675`,
`bc87070`, `bcc822`). A logbook row the logbook rule could not accept corroborates each one.
The durable account is the fly#74 section of `inst/notes/terrain-correction.md`.

## Measurement

- 5 roll-heights / 138 frames settled of 521 excluded. The table now reaches 1,438 frames
  (lower 1,001 logbook + 129 sibling, upper 299 + 9); 1,281 slipped frames stay on ÷10.764
  (was 1,290). Catalogue reach = measured, 1,438.
- #54 had drawn `bc5596` 10.3–11.2% narrow and `bcb98013` frame 52 17.1% wide (linear).
- **The tolerance is load-bearing both ways, and it went wrong twice before it was right.**
  `bc5596` 204–211 sit between 2,621 m (×10 to 2 m) and 2,438 m (×10.764 to 30 m, 0.12%). At 2%
  the two neighbours name different relations, and the generator's control stops (shown by
  mutation, with the CSVs left untouched).
  - First wrong turn: with only ×10 named in the upper tail, the tolerance guarded nothing.
    ×10.764 was added.
  - Second: the first bound assumed the catalogue rounds. It also truncates (2,000 ft = 609 on
    `bc5449`), which is code-check round 3's finding. The corrected bound
    big − k·small ∈ [−(1 + k/2), k + 1/2] changed one outcome (`bc7675`, 84 frames, now tabled).
  - Third: round 4 found a 3.28 ft/m storage beyond that (20,000 ft = 6,098 on 2,677 frames).
    It can only refuse, so it was documented rather than widened. Round 4's enumeration of all
    3,876 neighbour-relation pairs found no pair between any bound and twice its width.

## Evidence

`data-raw/height_calibrate-lower_tail_rolls.R` (Stage 5b) prints every figure. The
`review-round*.md` files in this directory are the four code-check rounds.

Closed by: PR for branch `74-sibling-frame-witness`
