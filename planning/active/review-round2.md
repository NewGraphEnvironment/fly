# Review round 2: fly#74 staged diff (consumer side and tests)

Reviewer scope: R/fly_footprint.R consumer logic, other readers of the rolls table, tests, doc figures.
Worked in a copy (`git checkout-index` into the session scratchpad); repo tree untouched.

## Findings

- **[fragile, doc]** vignettes/airphoto-selection.Rmd:410-415. It says "On 28 roll-heights the
  province's flight logbooks and the spacing between adjacent frames settled the disagreement" and
  lists the causes as dropped digits, x10 or wrong scale. The shipped table now has 32 roll-heights:
  4 are settled by a sibling frame, and one cause (a leading digit added) is missing from that list.
  The 28 count is still correct for the logbook rows alone, but the sentence describes everything
  marked `"corrected_roll_table"`, so it is now incomplete. The caller said notes and NEWS come in a
  later commit; the vignette is a third place that needs the same edit and was not in that list.

No bugs found in the code or tests.

## Checked and correct

- **Consumer flow (R/fly_footprint.R ~1164-1210).** The code there is unchanged. Every sibling row
  has `factor != 1`: that is 10 for bc87070 and bcc822, 0.1 for bc5596, and 0.08092 for bcb98013. So
  each row goes through `in_band(r_tabled)` using `height_m`, and `factor` is only read in `!= 1` /
  `== 1`. The leading-digit ratio is never used as a multiplier. `fh_used` for the leading-digit row
  is 7924, under the 16,000 m ceiling. `tabled` is excluded from `slipped` and `implausible`, and it
  feeds the second DEM pass and the `roll_tabled` warning count and `height_source`, the same as
  logbook rows. The table has no duplicate keys, so `match()` is unambiguous.
- **Other readers.** Only `fly_height_roll_table()` reads the CSV. The mocked tables in the test file
  replace the function outright. Nothing reads columns by position, and nothing outside tests reads
  `cause` or `logbook_ft`. The new `witness` entry in `colClasses` exists in the shipped CSV.
  `test-fly_footprint_invariants.R` only lists the `height_source` values, and those are unchanged.
- **Doc figures, checked against the shipped CSVs.**
  - Upper-tail tabled frames: logbook 299 + sibling 9 (bc5596 8, bcb98013 1) = 308.
  - Excluded upper-tail frames sum to 1,281 = 1,589 - 308.
  - The only pre-2003 excluded upper-tail row is bc79027 at 10 frames. The rest are bcc03004/6/7/8/46
    and bcc05001.
  - So "299 -> 308", "10 frames of bc79027" and "9 an adjacent frame settles" all hold. "22
    roll-heights" (line 248, test header) is still correct for the logbook instruments: there are 22
    lower-tail logbook rows (1,001 frames).
- **Tests pass on the staged tree** (`NOT_CRAN=true test_file`, all green).
- **Mutation results, run in the copy:**
  - Drop the 4 sibling rows: 3 tests fail (census, sibling pin, sibling sizing).
  - Set sibling `height_m` to catalogue x factor: 2 tests fail (the bc5596/bcb98013 pin and the
    sizing test). The census test stays green. That is expected: for bc87070 and bcc822 the two
    readings differ by at most 2 m, which is inside the rounding that defines the relation, so it is
    not a gap.
  - Consumer gate `!= 1` changed to `> 1`: 2 tests fail.
- **Tolerances.** The rounding bound `0.5 * (k + 1)` is right for both k = 10 and k = 0.1: it is the
  whole-metre rounding on the frame plus k times the sibling's.

/Users/airvine/Projects/repo/fly/planning/active/review-round2.md
