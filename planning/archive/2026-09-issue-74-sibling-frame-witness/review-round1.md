# Code-check review, round 1 — fly#74 sibling witness (staged diff)

## Clean

No issues found.

## What was checked, and how

- **Reproduced the generator from the staged index** (`git checkout-index -a` into a temp dir,
  `centroids/` and `logbooks/` caches copied): exit 0, both controls pass, and the regenerated
  `flying_height_rolls.csv` / `_excluded.csv` are byte-identical to the staged ones.
  `test-fly_footprint_height_rolls.R` passes against that tree with `NOT_CRAN=true`.
- **Rules 1-6 against `sibling()`**
  - Adjacency is frame number ±1 of any catalogue frame on the key, same roll, lens and scale (`%in%`
    for scale, so the 5,831 NA scales cannot give NA rows), at a different height. The cache has
    0 NA `flying_height`, 0 NA `focal_length`, 0 non-integer heights and 0 duplicated
    (roll, frame) keys, so the `==` subsets cannot inject NA rows and `digits()` never rounds.
  - The band proxy uses `median(d$elev)`. It is never NA: 0 of 549 v rows, 0 NA elev in `lt_all`.
  - Exact relations: the tolerance matches `|h - k s| <= 0.5 (k+1)` for each of x10, xK, /10
    and /100. The digit relations are string identity. A neighbour naming two relations is
    rejected, so an x10/digit coincidence cannot slip through. `rel_factor("digit")` can never
    land on 0.1 or 10 exactly, so the `case_when` cause order is safe.
  - Unanimity: one relation, one sibling height, at least one naming neighbour. An all-xK result
    goes to #54.
  - Logbook veto: this fires only when the logbook's modal factor is finite and different.
    Five focal-conflict rows could have let a sibling override the "different lens" exclusion,
    but all five carry `log_factor = 1`, which a sibling never names, so the veto would fire
    anyway (and today none of them has a neighbour at another height).
  - Spacing is gated through the same `fits()` window.
- **Reach**: `fly_footprint()` matches on the same four-field `num()` key. The generator's reach
  check prints 1,354 reached and 1,354 measured, so no sibling row touches an unmeasured frame.
  `r_tabled` is still held to the band per frame.
- **Accounting**: accepted rows move from excluded to tabled with `reason` set to NA. The
  partition `stopifnot` and the per-tail census reconciliation in the test both still hold.
  Counts in the doc text (299 + 8 + 1 = 308) check out.
- **CSV consumers**: `fly_height_roll_table()` is the only reader in `R/`. It reads `witness`
  as character, and the new columns do not disturb the key or `factor`/`height_m`. Written
  with `na = ""`, the empty `sibling_frame` reads back as NA integer. For `sibling_reason`, an
  empty value would read as "" and the `nzchar` check catches it.
- **Tests can fail**: the named-row pins, the `nzchar`/`anyNA` checks on `sibling_reason`, and the
  fixture test (26212 vs 26213, 97924 vs 97925 separating table from #54) all bind to values that
  a wrong rule would move.

## Observations (not defects)

- Four sibling rows ship, not two: `bc87070` 396 (34 frames) and `bcc822` 701 (11 frames) in the
  lower tail as well. Both are corroborated by logbook rows the transcription left uninterpreted
  ("169-20?" at 13.0 = 3,962 m; "2300" beside 23,000 ft = 7,010 m). The planned note and NEWS
  update (Phase 3) should state all four. `inst/notes/terrain-correction.md` still says the table
  reaches "exactly the 1,001 measured frames" in the lower tail, and that is now 1,046.
- `bcb98013`'s linked page reads 24,000 ft (7,315 m) where the shipped height is 7,924 m. Rule 5
  treats that as naming no factor. The page's roll number (99013) and scale (1:35000) also
  disagree with the catalogue for the neighbours, so it does not discriminate. It is worth one
  sentence in the note.
