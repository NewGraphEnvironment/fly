# Review round 3 — fly#60

Reviewed the staged diff, plus the unstaged edits to `inst/notes/terrain-correction.md` and
the vignette. I ran `data-raw/height_calibrate-lower_tail_rolls.R` in a copy
(`/tmp/fly_review_r3`), with RC=0 and every control passing. The two CSVs it wrote are
byte-identical to the shipped ones (`cmp`). I recomputed every count in the new note section
from the shipped CSVs and the run log.

## Mechanism

One fact is represented in two places, and nothing checks that the two agree. Usually the
second representation also merges states that the first kept apart:

- the table height as catalogue times factor, against the logbook height;
- an illegible focal length, against a conflicting one;
- a 2-field grouping, against a 4-field key;
- a reason string, against the predicate that actually fired;
- the test's list of `height_source` values, against the function's;
- `100000L`, against `100000`.

Each time, the downstream site re-derives the meaning from a proxy. That proxy agrees with the
source on the cases in hand and loses a distinction elsewhere. In this round the live proxy is
`is.finite(log_ft)`. It merges "no logbook row covers the frame", "a row covers it but its
height or frame range was not interpreted", and "two covering rows disagree" into one NA. The
reason labels, and the note's counts, then report all three as "no row covers".

## Where the mechanism reaches, and what was checked

- **`fly_footprint()` key** (`num()` on both sides, NA guard, `out_of_band` mask): correct. In
  the sweep, all 1,001 table frames pass the per-frame gate (factor > 1 in band; factor 1
  with `r_reported > 0`).
- **`height_source` value lists:**
  - The invariants test is fixed.
  - `setup.R` and `test-fly_footprint_height.R` list fixture-specific values, which is
    correct.
  - `test-fly_footprint_coverage.R:299` and `data-raw/dem_calibrate-coverage_error.R:870`
    use `!%in% "reported"`, which keeps its meaning.
  - No other `R/` consumer reads the column.
- **Script `key4()`** (line 368): still uses `paste()`, the representation r2 removed from the
  function. Today it matches: the cache holds integers, and the table has no scale of 1e5 or
  more. A mismatch would fail loud through `stopifnot(reach >= ...)`. So it is fragile, not
  wrong, and I have not listed it as a finding. Note the consequence: the note's claim that
  the key "reaches exactly the 1,001" comes from a different key builder than the one
  `fly_footprint()` uses. The two only happen to agree.
- **Script verdict grouping, and test `key()`:** the same 4 fields and the same `read.csv`
  representation on both sides. Consistent.
- **Script reasons from `is.finite(log_ft)`:** wrong. See finding 1.
- **The note's rates, compared against the shipped counts:** see finding 2.

## Findings

- **[severity: bug]** `data-raw/height_calibrate-lower_tail_rolls.R:248,252,284,328-329`. The
  exclusion reasons treat any NA `log_ft` as "not covered", so 6 of the 36 roll-heights
  labelled `"no logbook row covers these frames"` are in fact covered by a logbook row:
  - `bc5524` 243/274/304 (69 frames): the covering rows read "1,000", "900" and "600", with
    units left uninterpreted.
  - `bcc822` 701 (11 frames): the covering row "2300" was deliberately not interpreted.
  - `bc5598` 2 (29 frames, 153-181): two covering rows conflict, 110-196 at 7.5 against
    153-181 at 8.5.
  - `bc87070` 396 (34 frames): the page covers them as "169-20?", a range the script cannot
    parse.

  `bc79209` 7620 is labelled `"logbook covers under half the frames"`, but every one of its
  85 frames is covered. 51 of them sit under two disagreeing rows (sheet 1 "1-85" at 25,000,
  sheet 2 "1-51" at 21,340), and that is the only reason they are not counted as covered.

  These labels ship in `inst/extdata/flying_height_rolls_excluded.csv`, and the note repeats
  them. `terrain-correction.md` line ~310 says "36 with no logbook page covering the frames"
  and "3 under half covered". The page-covering count is 30, and one of the 3 is a
  conflict, not partial coverage. This is the same class as r1's "spacing rejects" label
  written where no spacing was measured. A reader acting on "no page covers" would go and
  fetch or read pages that are already transcribed.

  Fix: count covering rows before the `is.finite(logs$log_ft)` filter. Then give "covering
  rows disagree" and "logbook height or frame range not interpreted" their own reasons ahead
  of the coverage reasons.

- **[severity: bug]** `inst/notes/terrain-correction.md:244` and `:271`. There are two
  published rates for how much of the lower tail fly#60 settled, and they contradict each
  other. The data supports neither:
  - Line 244 says "three quarters of it was settled per roll". The actual share is 1,001 of
    1,962 frames (51%). Even counting the 4 different-lens exclusions as settled only gives
    1,311 of 1,962 (67%).
  - Line 271 says the two instruments "settle about half of them". In context, "them" is the
    77 roll-heights, and 22 of 77 is 29%.

  Supported wordings:
  - about half the frames (1,001 of 1,962);
  - 22 of 77 roll-heights;
  - 21 of 42 rolls.

- **[severity: fragile]** `inst/notes/terrain-correction.md:238` and `R/fly_footprint.R:214`
  say "the 1972-76 rolls" in the r ≈ 2 mass fit their reported height. The script's own
  per-roll table disagrees in both directions:
  - 12 of the 105 reported-fitting frames are from 1965, 1978 and 1979 (`bc5138`,
    `bc79141`, `bc79039`, `bc78110`).
  - `bc7407` (1972) fits nominal, and `bc7454` (1973) fits neither.

  "About half" (105 of 209) is correct. The year range is a description, not the classifier,
  and fly#72 should key on the per-roll fit, not on the years.
