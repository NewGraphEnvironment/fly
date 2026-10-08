# Code-check round 3: fly#99 staged diff

Reviewer: subagent, 2026-10-08. Read-only review: I ran no code, because every finding is in prose and
can be checked against shipped CSVs and the generator source. The only write to the repo is this file.

## Mechanism

Every finding so far has the same cause. The sentence names its population by its subject (the list,
the frames a page reaches, the frames on a roll-height, the frames this call named), and nobody reads
that population back from the line that computed the figure. The producer always computes over a
specific set:

- the nine keys fly#97 measured, of which `location == "misplaced"` keeps five
- the census frames (`frames`), not the catalogue
- the frames the logbook **reads** (`n_logbook`, explicitly "not frames a row covers",
  `data-raw/height_calibrate-lower_tail_rolls.R:1046-1047`)
- the `r <= 0` subset (the note's "The other 5 have no shipped logbook row")

The prose then attaches the figure to a neighbouring set. There is also a variant: a **rule's
threshold** (W2's `>= 0.9`) is restated as if it were the **measured value**. The enumeration's own
first row shows this. The wording moved from "all" to "at least 90%" because 90% is the rule's
threshold, not because "all" was false.

The mechanism reaches every sentence whose population differs from its producer's. Rounds 1-2 fixed
"named" and "on these roll-heights". It also reaches these four:

1. "the list = what was measured" (5 places)
2. "(not all)" (CLAUDE.md)
3. the count of frames with no logbook row in the code comment
4. "reach" against the producer's "read"

None of the four is in the enumeration.

## Findings

- **[severity: fragile, false scoped claim shipped in the warning, roxygen, Rd, NEWS, note and code
  comment]** "The list holds the roll-heights measured so far" / "an unlisted roll-height is
  unmeasured".
  - **Where.**
    - `R/fly_footprint.R:303` (reader comment: "Only roll-heights fly#97 measured are here, so an
      unlisted one is unmeasured")
    - `R/fly_footprint.R:746-748` and `man/fly_footprint.Rd:223-225` ("The list is the
      roll-heights measured so far ... an unlisted roll-height is unmeasured, not clean")
    - `R/fly_footprint.R:1437`, the warning string ("The list holds the roll-heights measured so
      far, not a census"), pinned by `tests/testthat/test-fly_footprint_misplaced.R:104`
    - `NEWS.md:5` ("The list is what fly#97 measured, so an unlisted roll-height is unmeasured")
    - `inst/notes/terrain-correction.md:1070` ("so it is what fly#97 measured")
  - **Why it is false.** The reader filters `flying_height_image_overlap_keys.csv` to
    `location == "misplaced"`, so the list is 5 of the 9 keys fly#97 measured. The other four were
    measured and are unlisted:
    - `bc7718` 1524 and `bc80117` 1372 (`indistinguishable`, 24 and 19 `r <= 0` frames)
    - `bc5715` 732 and `bcc325` 396 (`too_few_pairs`)
  - **Why it matters.** "Unlisted is unmeasured" is false for 4 roll-heights and 45 `r <= 0`
    frames. NEWS contradicts itself in the same bullet: "an unlisted roll-height is unmeasured",
    then "`bc7718` and `bc80117`, left unsettled by fly#97, are not named". The note says they were
    measured at ~85% overlap. "Not clean" still holds for them, but "unmeasured" does not.
  - **Fix.** Say "the roll-heights fly#97 labelled `misplaced`, of the nine it measured; an
    unlisted roll-height is not clean". Or keep "unmeasured" and name the four measured-but-unlisted
    keys.
  - **Missing from the enumeration.**

- **[severity: fragile, false claim]** `CLAUDE.md:472`, "the pages write the catalogued height
  under M.S.L. for at least 90% **(not all)** of the frames they reach".
  - **What "(not all)" asserts.** That some frames the pages reach do not carry the catalogued
    height under M.S.L.
  - **What the producer shows.** On every one of the five keys:
    - `frames_catalogue == frames_logbook`: 80/80, 64/64, 12/12, 55/55, 57/57
      (`inst/extdata/flying_height_image_overlap_keys.csv`, from
      `flying_height_above_ground.csv`)
    - `frames_other`, `frames_ground_*` and `frames_ambiguous` are all 0
    - every transcribed row for `bc77026`, `bc77070`, `bc77072` and `bc77087` in
      `data-raw/flying_height_logbooks.csv` carries the header `True Height (M'/M.S.L.)`
  - **The variant.** "At least 90%" is W2's threshold (`height_measure-image_overlap.R:651`), so it
    is a true lower bound. The parenthetical then turns the threshold into a measured shortfall that
    does not exist. A future session reading CLAUDE.md would believe some reached frames disagree
    with the catalogue.
  - **Fix.** Drop "(not all)", or write "(W2's rule; on the rows, all)".
  - **Missing from the enumeration.** Its row 1 records the change from "all" but not this
    parenthetical.

- **[severity: fragile, an `r <= 0` count stated over the roll-height]** `R/fly_footprint.R:1406-1408`,
  the code comment "not every frame on them is reached by a logbook row (`bc77072` 225, four of
  `bc77026`'s)".
  - **What the parenthetical counts.** It lists the 5 `r <= 0` frames with no shipped row
    (the note's "The other 5 have no shipped logbook row", `terrain-correction.md:986-990`).
  - **What the sentence's subject covers.** "Frames on them", the roll-heights. On those, the
    census alone has 38 unread `bc77026` frames (118 - 80, all past the 140-219 row, since
    `frames_other` = 0) and 5 on `bc77072` 1829 (17 - 12). The catalogue has `bc77026` 257 as well.
  - **Why it matters.** "Four of `bc77026`'s" reads as the count and is 4 of at least 38. This is
    the round-2 defect again (an `r <= 0` / census figure stated over the roll-height).
  - **Fix.** Scope it ("`r <= 0` frames with no shipped row: `bc77072` 225, `bc77026` 221, 222, 237,
    247"), or drop the parenthetical.
  - **Missing from the enumeration**, which lists the claim's producer as `frames_logbook < frames`.
    That is the roll-height-scope producer, not the one these numbers come from.

- **[severity: fragile, holds today but the guard cannot see it go false]** "for at least 90% of the
  frames they **reach**".
  - **Where.** The warning (`R/fly_footprint.R:1429`), roxygen 738, Rd 215, NEWS:4, CLAUDE.md:472,
    code comment 1405, and the test at `test-fly_footprint_misplaced.R:54,108`.
  - **What the producer computes.** The denominator is `frames_logbook` = `n_logbook`, the frames
    whose logbook state is `read`. The producer separates that from frames a row covers:
    `height_calibrate-lower_tail_rolls.R:1046-1047`, "Frames the logbook READS, not frames a row
    covers: a frame under rows that disagree, or under a row whose height was not interpreted, is
    covered and unread". The note says "read" (`terrain-correction.md:969-970`).
  - **Why it holds today.** On these five keys every unread frame is unspanned: no blank-range row
    covers a frame, and `frames_other` = 0. So reach equals read and the sentence is true.
  - **Why it is fragile.** A re-run in which a conflicting or uninterpreted row covers frames on a
    `misplaced` key would make "reach" the wider set. The test still passes, because
    `expect_true(all(mk$frames_catalogue / mk$frames_logbook >= 0.9))` divides by read frames.
    This is the reach/read conflation fly#93's code-check rounds caught.
  - **Fix.** Say "read", as the note and producer do.
  - **Missing from the enumeration.**

## Checked and clean

- **112 / 311 / 199.**
  - `frames_nonpositive` sums to 11+59+1+3+38 = 112, and `frames` to 118+64+17+55+57 = 311.
  - `_excluded.csv` terrain `frames_measured` on the five keys sums to 107+5+16+52+19 = 199.
  - The 199 are below the band and refused through `implausible`, which has its own warning, and are
    not in `unusable` (`R/fly_footprint.R:1329`). So "refused by the height check with its own
    warning" is right.
  - `frames_outside` = 1+0+9+44+3 = 57, which matches round 2's catalogue count.
- **"Frames in band are sized from the DEM as usual".**
  - No frame on these keys can be above the band: `ratio_asl` is at most 1.514 < 1.6, and r <= r_asl.
  - Under-terrain frames on these keys are always `unusable`. No key is in `flying_height_rolls.csv`,
    and the ÷10.764 slip only lowers r. So "only frames under the terrain are named" is exact.
- **"One has a step margin at the instrument's resolution".** `D_agl` is -0.226 (`bc77070`, margin
  0.006 to tau 0.220), then -0.327, -0.576, -0.588 and -0.993, so only one.
- **"Step longer than the air base".** Every `misplaced` key is `step_overstated`, and the test
  asserts it.
- **"64-77% ... within 0.5%"** matches the note (lines 888 and 1801).
- **The census description** (in band above sea level but below it over the ground, plus under the
  terrain) matches the generator's census, `terrain_frames` plus `nonpositive`.
- **"Frames under the aircraft" in NEWS:4 and note:1069** follows the repo's established idiom for
  `r <= 0` (NEWS:36, note:850), so it is not flagged.
- **Code.** `num()` scope, key formatting, NA roll, and the `under_terrain` reuse were all
  re-checked by rounds 1-2, and nothing in this diff changes them.

/Users/airvine/Projects/repo/fly/planning/active/review-round3.md
