## Outcome

fly#99 asked whether fly should tell the caller about the five roll-heights fly#97 labelled
`misplaced`. At the plan gate the choice was a warning read from a ledger, not a new column and not
nothing. Only those five are named; `bc7718` and `bc80117` are not. `fly_footprint(dem =)` now adds a
second warning beside the "terrain at or above the aircraft" fallback, naming any of the caller's frames
under the terrain on those keys with a count per roll-height. It reads
`flying_height_image_overlap_keys.csv` directly, so `location` lives in one file. Geometry and columns
are unchanged. The code was small; the work was the wording. A plan review and three code-check rounds
each found the same defect class this repo keeps recording: a figure computed over one set of frames (the
census, a roll-height, frames a logbook reads, the `r <= 0` subset, 5 of 9 measured keys) stated over a
wider neighbouring set. Round 2 found one inside the previous fix, so the loop ended on a mechanical
enumeration of every added prose line, not on a reviewer's Clean (findings.md). The plan review also
caught a real crash: `num()` lived inside the roll-table block, so the warning would have errored for
any frame the band check never compared.

## Measurement

- **Reach.** Of the 311 frames fly#93's census holds on the five keys, 112 are under MRDEM's terrain and
  get named. The other 199 sit below the band over the ground and are refused by the height check. The
  1977 centroid cache holds 368 frames on those keys, so the census is not the catalogue. That 368 is what
  stopped the roxygen calling 311 "the frames on these roll-heights".
- **Logbook.** The pages write the catalogue's figure for 100% of the frames they read on all five keys
  (80/80, 64/64, 12/12, 55/55, 57/57). The 90% in the wording is W2's threshold, kept so a re-run cannot
  falsify the sentence. The test pins the threshold, not the 100%.
- **Mutations against `test-fly_footprint_misplaced.R`.** Dropping the r <= 0 conjunct gives 1 failure,
  dropping the `location` filter 4, ignoring `focal_length` in the key 2, an unformatted height in the
  key 12, and restoring `num()`'s old scope 1 (the B1 test alone).
- **Not separable.** Swapping `under_terrain` for `unusable` passes: for a keyed frame with complete
  metadata the two coincide. That was recorded instead of being tested around.
- **Suite.** 5,765 pass, 0 fail, 0 skip on the final tree.

Closed by: PR (see branch `99-surface-frames-whose-catalogue-centroids`)
