# Plan review 1 — fly#54 (Plan agent, 2026-09-18, written up by the parent session)

Returned while Phase 1's pull was running. Verified = checked against the code or data by
the parent; the rest is the reviewer's reading.

## Blocker
- **B1. `unusable` is a residual class** (`R/fly_footprint.R` `unusable <- dem_eligible &
  !corrected & !uncovered`), so an implausible frame removed from `corrected` lands in it
  and fires the "missing, zero, or terrain at or above the aircraft" warning as well as the
  new one; a camera-table one also reaches the `unsized_digital` warning that tells the
  caller to supply the `dem` they supplied. In reverse, existing unusable frames have
  r <= 0 / Inf / NA, so a ratio check run first relabels them and breaks
  `expect_match(w, "above")` and `expect_match(w, "focal_length")`. **Adopted:** the ratio
  test applies only to frames that would otherwise be `corrected`; `implausible` is its own
  class excluded from `unusable`; `height_source` is defined for every class.
- **B2. Nothing forces classification ahead of the expensive pass.** `r1 <- resize(first$elev)`
  then the second `fly_dem_sample()` builds a 110 km polygon and a ~13M-cell grid per
  slipped frame. An implementation that classifies after both passes passes every planned
  test. **Adopted:** classify after pass one; implausible rows are NA before pass two; a
  `fly_dem_grid` size assertion copied from the union-grid test.

## Gap
- **G1.** Camera-table frames seed the first pass from raw `flying_height` (`resize(0)`), so
  the ceiling on `agl` is judged after paying for a 100 km window. **Adopted:** the absolute
  check moves to `flying_height` itself (ASL), which is known before any route runs.
  Deviation from the approved plan's `fly_agl_max()`; stricter, same intent.
- **G2.** "Film" has no predicate: the scale route also takes media named in `format_size`
  and every row when there is no `media` column. A digital frame entering through
  `format_size` has r ~ 3. **Adopted:** the relative check keys on film media (or no media
  column, which the package already documents as assumed film); `format_size`-named
  non-film media gets the ceiling only.
- **G3.** No invariant stated for `height_source`. **Adopted:** `height_source` is
  `"reported"` or `"corrected_unit_slip"` iff `footprint_terrain == "dem_agl"` iff
  `!is.na(height_agl)`; `"implausible"` survives an empty geometry the way `width_source`
  does, because it says why there is nothing.
- **G4.** `resize()` and `agl` both close over the raw column — both need a `fh_used` vector.
- **G5.** `flying_height - height_agl` is used as ground elevation in the vignette and two
  tests; on a corrected row that is ~ +68 km. Document it.

## Assumption
- **A1.** Digital frames do parse a `scale` (r ~ 1-3.5 legit). Phase 1 measures whether any
  digital frame is slipped before deciding the ceiling alone is enough.
- **A2.** Error on r is additive (relief, feet rounding), so low flights spread widest. Keep
  the band wide — the gap out to ~10 does the separating. `r_agl <= r_asl`, so the upper
  edge is measurable over the whole population with no DEM.
- **A3.** r cannot tell a wrong height from a wrong scale or a 305/153 focal mislabel. Keep
  the implausible warning neutral about cause.
- **A4.** The ceiling has thin margins and cannot separate the populations — verified and
  stronger than the reviewer knew: slipped roll `bc78065` reads 4,115 m. The ceiling is a
  physical-possibility backstop only.

## Acceptance
- Sweep a *slipped* fixture through the tibble shapes; on bundled data the column is
  constantly `"reported"`.
- Batch independence: compare `height_agl`, not rings (`fly_bearing()` is neighbour-dependent).
- No exact warning counts on the restore-the-bug run (the 40 km second-pass box on `main`
  overruns the bundled DEM and fires the partial-coverage warning too).
- The 900 m / geographic cases say nothing about classification; the truncating extent does
  (it checks `second$covered` is what a corrected row reports).
- Ship a population-wide ASL-ratio summary beside the sampled controls; state a row budget.
- `expect_silent` DEM tests stay quiet only if the band's lower edge is <= 1.00.
