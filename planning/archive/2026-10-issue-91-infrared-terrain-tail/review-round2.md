# Code-check round 2 — fly#91 staged diff

## Findings

- **[severity: fragile — published claim]** `inst/notes/terrain-correction.md:550` — the #72
  section's bound still reads "`near_upper` is a 600-frame sample of 2 < r above sea level ≤ 3,
  not a census." That sentence names the tail value, and the shipped `near_upper` rows now
  include `bci9`, which comes from fly#89's IR census and was never in the 600-frame draw (the
  sweep that drew it is BW/colour only). The diff fixed exactly this sentence in its other copy:
  the `fly_height_roll_table()` comment (`R/fly_footprint.R:285-286`) was changed to "The
  BW/colour near_upper rows come from a 600-frame sample of that stratum, not a census; the
  infrared rows (fly#91) from a census of every IR frame beyond the band". The note's copy was
  left behind. The new section's own phrasing, "It joins #72's sample" (`:576`), points the same
  wrong way: `bci9` is settled alongside the sample under the same rule, and it was not drawn
  into it. No outcome moves. Fix: scope line 550 to the BW/colour rows ("`near_upper`'s
  BW/colour rows are a 600-frame sample ..."), or add a clause naming the IR census, and say
  "is settled alongside #72's sample" at `:576`.

## Round 1's two fixes, re-checked

- Condition 1 at `terrain-correction.md:584` now reads "the logbook covers at least half the
  frames, and at least 90% of those name factor 1". That matches the generator:
  `covered = n_logbook / n >= 0.5` and `agreeing = n_agree / n_logbook >= 0.9`, with
  `named = 1` so `factor` is finite only when the modal index names 1. Conditions 2-4 also
  match `focal_conflict`, `spacing_ok & !fits(p_nominal)` under `nu_row`, and
  `scale_veto = nu_row & n_scale_same > 0`.
- The pin block's comment (`test-fly_footprint_height_rolls.R:307-309`) now points at
  `test-fly_footprint_infrared.R`. Lines 121-127 there do assert, per roll, that `p_rep` falls
  inside the window and `p_nom` falls outside it.

## Verified (no issue)

- **Tests run green.** Both changed test files pass under `NOT_CRAN=true` with `load_all`:
  0 failures, 0 skips. The new fixture test makes 8 expectations and the recompute block 345.
- **The new assertions can fail against their defects.**
  - Drop the terrain row, or narrow the `fly_footprint()` factor-1 gate to the upper side:
    the fixture's frames come back `implausible` (`:538`).
  - Use the catalogued height instead of `height_m`: `expect_equal(height_agl, h - 1000)` at
    default tolerance fails on `bc5312`, which is 3,353 against 3,352.8, a relative 8.5e-5.
  - Relabel a tail: caught at `:221` and `:286`.
  - The cited line numbers in `findings.md`'s mutation table (221, 267, 270, 286, 312, 320,
    538) are the lines they name.
- **The test's set construction is a superset of the generator's.**
  - The test omits `r > band[2]` and `r > 0`. Every census `outside_band` frame satisfies
    those, or the generator would have stopped, so the reconciliation can only fail falsely,
    never pass falsely.
  - Strata are disjoint by key: `ratio_asl` is a function of `flying_height`, `scale` and
    `focal` alone, so no key can straddle two tails.
- **The note's widths and the no-DEM claim hold for `fly_footprint()`.**
  - "About half / about twice": width over nominal equals r, here 0.473, 0.506 and 2.030.
  - "Without a DEM every film frame is still nominal": the whole height check, roll table
    included, sits inside `if (!is.null(dem))` (`R/fly_footprint.R:1097`).
  - With a DEM, a tabled key gives `fh_used = height_m` wherever the caller's DEM puts the
    frame out of band. Where the DEM puts it in band, the catalogued height is used, which
    is within 0.2 m. Either way the frame is not nominal, unless the DEM does not cover it.
- **Nothing else consumes the new tail value.** `fly_height_roll_table()` reads `tail` as
  character, and nothing in `R/` reads it. No fixture in `setup.R` collides with the three
  new keys.
- **Generator Stage 3b.**
  - `setequal(names(irs), names(s))` holds, and the reorder to `names(s)` happens before
    `rbind`.
  - `settle()` merges `fn` by `airp_id` with a row-count `stopifnot`, so the IR frames get
    frame numbers from the same centroid cache.
  - Every branch keyed on the tail uses `%in% c("near_upper", "terrain")` or names `upper`
    or `lower` explicitly: `nu_row`, the sibling skip, the suffix, and `cause`.
  - `rnd_terr` reads `nominal_agl`, which exists on `s`.
- **Docs and roxygen.** The Rd change mirrors the roxygen edit. The added em dash in
  `R/fly_footprint.R` is in a comment, as earlier ones in that file are, so it is not an
  R CMD check ASCII issue. `fly_footprint.R:739` is now 123 characters, over `.lintr`'s 120;
  that is style only and nothing in CI lints.
