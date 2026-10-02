# Code-check round 1 — fly#53 parts 3-4 (campaign, georef table lookup, fly#87 bearing)

Probes run in a copy of the repo (scratchpad `flycopy`), never in the working tree. Catalogue
counts are from `data-raw/.cache/centroids/` (1,670,471 frames, reconciled exactly against the
catalogue in `data-raw/.cache/logs/pull.log`, so the ledger's "every film roll" premise holds).

## Findings

- **[severity: bug]** R/fly_georef.R `fly_film_refusal()`, the `max(led$retrieved)` line — the
  "covers every film roll in the catalogue as of <date>, so it was added since" claim prints the
  **campaign write date, not the snapshot date**. The ledger holds two dates: 6,600 unmeasured
  rows carry `SNAPSHOT` (2026-09-18) and the 60 measured rows carry `measured_on` (2026-10-02,
  `Sys.Date()` at Stage 4). `max()` returns 2026-10-02. Coverage comes from the cache snapshot,
  so a roll added between 09-18 and 10-02 is in neither table and gets told it was added after
  10-02. That is false, and it is the claim the brief asked to check. Fix: take the date from
  the unmeasured rows (`max(led$retrieved[!led$measured])`), or write the snapshot date to its
  own column.

- **[severity: fragile]** R/fly_georef.R `fly_film_rotation_states()`, `single_direction`. The
  text says "its legs all fly within 90 degrees of each other". That is right for the 63
  unmeasured rows, whose state came from the cache, and **false for the 3 measured
  rows** in the ledger. Those rolls were drawn, so they were *eligible*, meaning their
  qualifying legs span 90 degrees or more. Their measured `single_direction` comes from
  `fly_rotation_roll_state()` and means the *decisive* legs fell within 90 degrees. The warning
  tells the user something about their roll's geometry that the cache disproves, and it implies
  re-measuring cannot help, when other legs might decide. Fix: key the meaning on `measured` as
  well as on `state`, at least for `single_direction`.

- **[severity: fragile]** R/fly_bearing.R `leg_end()`. A zero **backward** step turns a frame
  onto that step. When frame i-1 shares i's centroid, `step(i, i+1) > 1.5 * 0` is TRUE for any
  forward step. So `leg_end(i)` takes the backward bearing, `atan2(0, 0)`, and `zero` then sets
  it to NA. The frame had a valid forward bearing, and the old code gave it one. Probe:
  `xy = (0,0),(700,700),(700,700),(1400,1400),(2100,2100)` gives `45 0 45 45 45` on HEAD and
  `45 45 NA 45 45` with this diff. The fix corrects frame 2 and breaks frame 3. In the cache
  this reaches 19 frames (29 adjacent zero-length steps in all). The comment "`leg_end()`
  already turns a frame with a neighbour on its other side away from it" holds only for a zero
  *forward* step. Fix: require `step(i - 1, i) > 0` in the ratio branch of `leg_end()`.

- **[severity: fragile]** R/fly_bearing.R `leg_end()` / `zero`. An NA coordinate now aborts the
  whole call. An empty POINT gives `st_coordinates()` an NA row. `step()` is then NA, so
  `step(i, i+1) == 0 || ...` is NA, and `if (... && !leg_end(i))` stops with "missing value
  where TRUE/FALSE needed". The `if (fwd)` inside `zero` fails the same way. On HEAD the same
  input returned `NaN NaN NaN` (probe: frames 1:3 on one roll, the middle one
  `sf::st_point()`). `fly_bearing()` is exported, so this is a new abort path. Through
  `fly_footprint()` (line 1044) the fly#47 abort now arrives from `fly_bearing()`, with a
  message naming nothing. fly#47 left that abort open on purpose to keep per-frame reporting,
  and this adds a second, earlier site for it. Fix: `isTRUE()` around the step comparisons.

- **[severity: fragile]** R/fly_bearing.R `leg_end()`. The 1.5x test cannot tell a long forward
  step from a short backward one, so some frames that were right are now wrong, not merely
  different. Counted over the cache: 1,107 `leg_end` frames whose backward step is itself
  under 1/1.5 of the step before it while the forward step is ordinary against that step. In
  **191** of them (5 digital), the backward bearing is more than 10 degrees off the line
  (judged by the step i-2 -> i-1) and the forward bearing is within 10 degrees of it. HEAD
  rotated those 191 correctly; this diff rotates them onto a short, off-line step. Against
  roughly 42,500 corrected frames this may be an acceptable trade. It is a measured cost the
  roxygen and the comment do not state ("3.0% ... were rotated onto the turn" reads as
  all-gain). Either state the count or also require the backward step to be ordinary against
  i-2 -> i-1.

## Checked and clean

- **fly_georef precedence.** Every combination was checked against the code. A user value wins,
  including over the table. An NA user value falls through to the table, and with no table
  value it refuses whatever the scalar `rotation` is. A non-square rotated frame takes the
  digital constant, because `film_branch` excludes it. An unrotated frame takes the old path.
  An empty footprint hits `next` before any of this. `match()` has no NA-to-NA trap, since the
  table has no NA roll. A `media` column that is absent, a factor or NA is handled without
  error. `table_rot` is indexed by `j` (the photos_sf row), consistently with `user_rot`.
- **Campaign Stage 1b, 3 and 4.**
  - Population `drawn` sums to 116, which equals 56 shipped plus 60 measured in the ledger, and
    every stratum count includes FORCED.
  - Shipped plus ledger is 6,716, which equals `sum(rolls)`. No NA `photo_year` stratum is
    dropped by `split(drop = TRUE)`.
  - `(film_roll, first_frame)` is unique in the legs CSV (0 duplicates), so the test's pair join
    is sound. Pairs has no duplicate rows.
  - Every `colClasses` matches the written shape. `refused` is written as an empty field and
    read as `""`, which `parse_refused()` handles.
  - The `sample.int(length(e))` draw is safe at length 0 and 1.
- **Not a defect, noise only.** In `test-fly_film_rotations.R`, `extdata()` passes
  `colClasses = c(refused = "character")` to the population CSV, which has no `refused`
  column. That raises a warning, "not all columns named in 'colClasses' exist" (reproduced), so
  the coverage test reports a WARN.

/Users/airvine/Projects/repo/fly/planning/active/review-p34-round1.md
