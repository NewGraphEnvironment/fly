# Task: Measure what a partially DEM-covered footprint costs, from real frames (#58)

## Problem

A footprint that hangs off the edge of the DEM is sized from the **mean elevation of the
part that is covered**. That is documented behaviour and it is reported — `dem_coverage`
gives the fraction per frame, and `fly_footprint()` warns once it falls below
`fly_dem_coverage_min()` (0.95) — but nothing has ever measured what it costs.

During the fly#50 run over the province-wide digital population, **18 of 416
DEM-corrected frames fell under 95% `dem_coverage`, one as low as 47%**. A frame half off
the DEM is sized from the half that happens to be on it, and its `height_agl` sits in the
same column, with the same `footprint_terrain = "dem_agl"`, as a fully sampled
neighbour's.

Outcome: a measurement that ships, plus whichever of the four remedies the issue names
(leave as is / move the threshold / add a floor / report a quality column) a rule written
**before the numbers exist** selects.

## What exploration established (plan mode, 2026-09-20)

1. **A single-point `fly_footprint()` call gets `NA` bearing** — `width_source` comes back
   `axis_aligned_no_bearing`, because `fly_bearing()` needs an *adjacent* frame number in
   the object handed to it. A direction-dependent truncation study must not run on an
   axis-aligned square by accident.
2. **The full 1.67M-row catalogue pull is already cached** in `data-raw/.cache/centroids/`.
3. **MRDEM-30 is `NA` only over US territory south of 49 N and far offshore**, so real BC
   partial coverage against the default DEM is a border phenomenon losing one systematic
   direction.
4. **Near-shore ocean is not `NA` and not exact zero** — 40,000 cells in Hecate Strait read
   0.098-0.189 m, no exact zeros. A coastal frame reports coverage ~1 with its mean dragged
   toward sea level, and an "exact zero cells" guard can never fire.

The 2-frame feasibility probe is an anecdote and its numbers must not reach the note or
NEWS as measured figures.

## Phase 1 - The population, before anything synthetic

- [x] Random draw (n ~ 3,000) of DEM-eligible catalogue frames measured against MRDEM-30
      through a PSOCK cluster; base rate under 1, 0.95, 0.8, 0.5 — **0 of 2,975 short**
- [x] Census of every frame that could reach MRDEM nodata — found by distance to nodata on
      a coarse overview, not by latitude: MRDEM extends past 49 N, so a border test would
      have measured the wrong stratum. 113 film candidates, 66 under 0.95; 173 digital
      candidates, 0 under 1
- [x] False-alarm side of 0.95 on a properly buffered DEM — zero, in 2,975 frames
- [x] Ocean contamination recorded as a bound on the claim: a coastal frame reports
      coverage ~1 over a near-zero surface, which removing cells cannot generate
- [ ] Ship `inst/extdata/dem_coverage_population.csv` (written by Stage 6)

## Phase 2 - Harness contract

- [x] `data-raw/dem_calibrate-coverage_error.R`, house pattern: `pkgload::load_all()`,
      resumable `.part` + `file.rename` cache, `write_if_changed()`, a producer line per
      published figure
- [x] Treatment variable is exogenous and geometric (share of the nominal footprint
      removed); achieved `dem_coverage` is an outcome, and the mapping is published
- [x] `NA` masking primary, extent cropping a declared second level
- [x] Assert `terra::origin()` and `terra::res()` unchanged by every truncation
- [x] Window sized from `resize(0, fh)` times sqrt(2)
- [x] Bearing handled explicitly - contiguous roll runs of 3, the target in the middle
- [x] Film primary; digital eligibility resolved by re-pulling `camera_calibration_url`
      for 673 rows rather than the whole catalogue
- [x] Premise assertions: every retained frame is `dem_coverage == 1`, `"dem_agl"`,
      `"reported"` on its full window; anything else dropped by name and counted

## Phase 3 - The sweep

- [ ] mechanism x direction (4 cardinal + 4 diagonal masks) x removed share
- [ ] Record both passes' coverage separately, `height_agl`, width and area,
      `footprint_terrain`, `height_source`, `r_reported`, `r_repaired`, mean elevation of
      the removed part
- [ ] Capture warnings per run rather than suppressing them; report the error curve twice,
      over all rows and conditional on classification matching
- [ ] Record the analytic term `dElev/(fh - elev)` beside the realised error
- [ ] Candidate predictors computable from the covered cells alone: sd, range, planar-fit
      gradient, analytic `|grad z . d centroid| / agl`
- [ ] Record a planar extrapolation of the uncovered part as a fifth candidate remedy
- [ ] Independent anchors: `patb_georef_url` exterior orientation (digital), `r` (film)
- [ ] Ship `inst/extdata/dem_coverage_sweep.csv`

## Phase 4 - Robustness arm, from the same cached windows

- [ ] ~900 m aggregate
- [ ] EPSG:4326 reprojection arm - the branch 0.95 was actually set for
- [ ] Anisotropic cells

## Phase 5 - The remedy, by rules fixed in the plan

- [ ] Metric, sign asymmetry, resolution floor and falsification condition fixed before
      fitting; population-weighted; predictor scored on held-out frames
- [ ] Floor / threshold / quality column decided by the rule and implemented
- [ ] Warning text reworded

## Phase 6 - Note, tests, docs, release

- [ ] New section in `inst/notes/terrain-correction.md`
- [ ] `tests/testthat/test-fly_footprint_coverage.R` recomputing every published figure
- [ ] Behavioural tests for whatever Phase 5 ships, each proven by restoring the defect
- [ ] Roxygen updated
- [ ] NEWS, version bump as the final commit

## Validation

- [ ] Tests pass
- [ ] `/code-check` clean on each commit
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
