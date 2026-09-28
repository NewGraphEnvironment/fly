# Task: Two #54-slipped roll-heights a sibling frame settles and no logbook does (#74)

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

## The rule (fixed here, before it is run over the population)

A roll-height the logbook rule excluded is settled by a sibling only if all of these hold:
1. **Adjacent**: a frame numbered ±1 from a frame of the roll-height, on the same roll with
   the same focal length and scale and a different height. This uses the adjacency rule from
   `fly_bearing()`/Stage 1.
2. **Neighbour in band**: `(sibling − elev) / nominal_agl` is in `fly_height_ratio_band()`,
   using the roll-height's own median terrain from the sweep. Neighbours are unsampled, so the
   note states this as a proxy. `fly_footprint()` re-checks the band per frame anyway.
3. **Exact named relation**: upper tail is catalogue = 10 × sibling, or catalogue = one digit
   prepended to the sibling's digits. Lower tail is catalogue = sibling / 10 or / 100, or the
   sibling with its leading digit dropped. "Exact" for a factor k means
   |catalogue − k·sibling| ≤ 0.5·(k + 1) m (whole-metre rounding on both sides). For the digit
   relations it means string identity.
4. **Unanimous**: every in-band adjacent neighbour that names a relation names the same one,
   and at least one does. A neighbour that names none, such as a new leg at a new altitude,
   is not a contradiction.
5. **No logbook contradiction**: if the logbook rule named a factor for these frames, it must
   be the same one. A logbook that names no factor vetoes nothing.
6. **Spacing**: under the sibling's height, spacing falls in the random-frame window (fly#60
   condition 3). With no adjacent base the roll-height is refused, as in the logbook route.

The shipped height is the sibling's catalogued height.

## Phase 1: Tests first (fail until the table carries sibling rows)
- [x] `test-fly_footprint_height_rolls.R`: extend the contract. There are two witnesses
      (`logbook`, `sibling`). Causes grow by `height_leading_digit_added` / `_dropped`. Sibling
      rows have `logbook_ft` NA and `height_m` equal to the sibling's catalogued height. The
      factor/cause pairing is checked per witness.
- [x] Pin both issue cases against the table: `bc5596` 26212 → 2621, factor 0.1;
      `bcb98013` 97924 → 7924, leading digit.
- [x] A fixture test checks that a sibling-tabled frame becomes `corrected_roll_table` and is
      sized from `height_m`, ahead of #54. Only the tabled key moves; a frame differing in
      height or scale does not.
- [x] Pin the rule against the population with the sweep plus the table: every sibling row's
      corrected ratio is recomputed from the sweep. The frame count still reconciles to the
      census (tabled + excluded == set).

## Phase 2: Generator (`data-raw/height_calibrate-lower_tail_rolls.R`)
- [x] Add a Stage 4b `sibling()` implementing rules 1–6 over `frames` (the centroid cache)
      for the roll-heights `v` did not accept, in both tails. The rule block is written as a
      comment before the code, as in Stage 5.
- [x] Controls, which must return known answers before anything ships. `bc5596` 26212 names
      ×10 from frame 203 and nothing from 212 (the 10.764 near-miss is rejected by the rounding
      tolerance). `bcb98013` 97924 names the leading digit from 51 and 53. `stop()` otherwise.
- [x] Add a `witness` column (`logbook` | `sibling`) to both shipped CSVs. Sibling-excluded
      rows keep their logbook reason. Accepted sibling rows move from excluded to rolls. The
      reconciliation `stopifnot`s and the key-reach check stay.
- [x] Run the generator and record every printed figure (how many roll-heights and frames it
      settles per tail and relation, and what it refuses and why) in `findings.md`.
- [x] Regenerate `flying_height_rolls.csv` / `_excluded.csv`.

## Phase 3: Package code and docs
- [x] `fly_height_roll_table()` reads `witness` as character. Its comment (R/fly_footprint.R
      ~243) and the `height_source` roxygen (~703) name the sibling witness. No change to the
      application logic (`tab_factor != 1` + band check already covers it). Verify rather
      than assume.
- [x] `devtools::document()`, full `devtools::test()`, `lintr::lint_package()`.

## Phase 4: Record
- [x] `inst/notes/terrain-correction.md`: add a fly#74 section with the rule, the two-neighbour
      finding on `bc5596`, the whole-metre tolerance and why it separates them, the population
      result, and what it cannot do (it cannot tell ×10 from ×10.764 without an exact
      neighbour). Update the fly#71 bullets that say "(fly#74)".
- [x] NEWS.md entry (no version bump). CLAUDE.md Key Decisions gets a short fly#74 bullet
      pointing at the note.
- [x] Edit the issue body to add the two-neighbour finding (spec, not comment).

## Validation
- [ ] Tests pass
- [x] `/code-check` clean on each commit
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion

Gate decisions (2026-09-27): rule runs over every excluded roll-height in both tails; a logbook vetoes only if it names a different factor.

**Plan corrections during the run** (see findings.md): x10.764 was added as an upper-tail
sibling relation, so the tolerance guards something. Rule 3's "exact" became the catalogue's
actual storage (rounds or truncates): big − k·small ∈ [−(1 + k/2), k + 1/2]. The excluded
table carries `sibling_reason` rather than `witness`.
