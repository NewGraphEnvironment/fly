# Code-check round 2: fly#99 staged diff

Reviewer: subagent, 2026-10-08. I ran everything in a scratch copy. The only write to the repo is this file.

## Findings

- **[severity: fragile, prose states a census count over the whole roll-height]**
  `R/fly_footprint.R:748-751`, `man/fly_footprint.Rd:225-228`, pinned by
  `tests/testthat/test-fly_footprint_misplaced.R:71-80`.
  The roxygen says "against MRDEM, 112 of the 311 frames on these roll-heights are [under the
  terrain], and the other 199 sit above the terrain but outside the band, so the height check
  refuses them". The 311 is not the frames on these roll-heights. The keys CSV's `frames` is copied
  from `flying_height_above_ground.csv` (`data-raw/height_measure-image_overlap.R:642-645`). That is
  fly#93/#95's census: the frames out of band over the ground plus the frames at `r <= 0`. Frames in
  band over the ground were never in it.
  - **The catalogue has more.** The centroid cache (`data-raw/.cache/centroids/1977.rds`) holds 368
    BW frames on the five keys, and 57 of them are not in the census:
    - `bc77026` 2042: 257
    - `bc77072` 1829: 204-211 and 229
    - `bc77072` 1981: 44 frames between 105 and 203
    - `bc77087` 1158: 32-34
  - **They are in band.** 32 of the 57 have an exact MRDEM read in
    `data-raw/.cache/terrain_tail/elev_8212c794.rds`. All 32 sit at r 0.626 to 1.021, inside the
    band. The other 25 were ruled in band by the census prefilter.
  - **So "the other 199" is wrong.** These frames are sized from the DEM in the ordinary way. They
    are neither named nor refused, so 199 is not "the other" frames on these roll-heights.
  - **The test cannot see this.** It checks 311 against `sum(mk$frames)`, the producer's own census
    count. It stays green while the prose's denominator is wrong. This is the recurring defect class:
    a figure stated over a wider set than its producer computed.
  - **Fix:** scope it to the census, e.g. "112 of the 311 frames fly#93's census holds on these
    roll-heights ... the other 199 ...; frames in band over the ground are sized from the DEM as
    usual". Or count the catalogue instead.

- **[severity: fragile, a per-call sentence that is false for most calls]**
  `R/fly_footprint.R:1427-1428`, asserted at `tests/testthat/test-fly_footprint_misplaced.R:94`.
  The warning tells the caller "Not every frame named is reached by a logbook row". In a warning,
  "named" means the frames this call named. The sentence is true only when those include a `bc77026`
  frame past 219 or `bc77072` 225. On the other three keys every frame the logbook could have reached
  is reached: the keys CSV gives `frames_logbook == frames` for `bc77070` (64/64), `bc77072` 1981
  (55/55) and `bc77087` (57/57).
  - A caller whose under-terrain frames are all on those three keys is told something false. That
    covers the fixture case at line 94, which names only `bc77070`, the largest key (59 frames).
  - The test pins exactly that false-in-context wording.
  - The same applies, more weakly, to "one page's height rests on a digit settled by a read that was
    not blind". It reads as being about the named frames even when no `bc77087` frame is among them.
  - **Fix:** scope it to the roll-heights, e.g. "Not every frame on these roll-heights is reached by
    a logbook row". The roxygen form at line 741 ("not every frame named") is generic across calls
    and reads acceptably, but would be clearer with the same wording.

## Checked and clean

- **Moving `num()` out of the block.** I put `num()` back inside the roll-table `if` in a copy. The
  `format_size` / `Film - Odd` test then fails with `could not find function "num"`, and only that
  test fails (FAIL 1, PASS 41). So it discriminates and is not vacuous: `film_like` is FALSE for that
  media, so `out_of_band` is all FALSE.
- **Unmodified run.** 43 pass, 0 fail, 0 skip (`NOT_CRAN=true`, `load_all`).
- **The `misplaced` rule.** The generator's rule (`location`, `:721-725`) does label
  `consistent_nominal` and `disagrees` keys `misplaced`, as the code comment says. The reader test's
  assertion that every `misplaced` key has `w1 == "step_overstated"` guards the step sentence.
- **The "of those N" wording.** It uses `sum(unusable)`, the same count as the generic warning's
  first number.
- **`under_terrain`.** It is the same predicate as the old inline one.
- **CSV arithmetic.** It reproduces 112 / 311 / 199 (11+59+1+3+38; 107+5+16+52+19).
- **The Rd regex test.** It is not vacuous. "On five roll-heights" is hard-coded, so a sixth key
  makes `expect_length(listed, 1)` fail, and the `\code{bc` count is tied to the reader. Small gap:
  an extra height added to an existing roll in the prose would still pass. That is not a defect today.
- **Message formatting.** `format(fh, trim = TRUE)` and the `table()` ordering are fine for the
  integer heights on these keys.
