# Task: A coastal frame is sized from sea level and reports full DEM coverage (#65)

## Problem

MRDEM-30 returns a **near-zero elevation surface** over near-shore ocean rather than
nodata. Measured over a 3 km window in Hecate Strait (`-130.9, 53.3`): 40,000 cells, all
between **0.098 and 0.189 m**, and **zero** exact zeros.

So a coastal frame half over water is sized from a mean that has been dragged toward sea
level. `flying_height - elev` is therefore too large, and the footprint is drawn too
**wide** — in the same direction, on every coastal frame, with no warning.

**`dem_coverage` cannot see this.** Those cells carry data, so the frame reports coverage
near 1 and `footprint_terrain = "dem_agl"`, exactly like a frame over solid ground.
`dem_shortfall_m` reports 0 for the same reason — the DEM's extent does span the frame.
Both columns added in v0.14.0 are blind to it by construction.

This was found while measuring fly#58 and is recorded there as a bound on that claim
rather than fixed. fly#58's sweep works by *removing* cells, and no amount of removing
cells can produce a frame that is fully covered by wrong values.

## Context (from plan mode)

fly#58 recorded that MRDEM-30 reads 0.098–0.189 m over near-shore ocean rather than nodata,
and called it a coverage-1 failure: a coastal frame's mean is "dragged toward sea level", so
`flying_height - elev` is too large and the footprint too wide. The issue asks to measure
before building: count the population, establish a reference, then decide.

**Exploration surfaced a premise the issue does not test.** The DEM route sizes a frame from
the mean elevation of the *surface the camera sees* (`fly_dem_sample()`, `R/fly_footprint.R:307`,
mean-plane model per `inst/notes/terrain-correction.md` §"Sizing is the mean under the
footprint"). Over water that surface **is** sea level: ~0 m is the correct elevation of the sea
surface, not an artefact standing in for nodata. Under the mean-plane model a frame half over a
500 m shore and half over sea is imaged at a mean surface of ~250 m, so the water-inclusive mean
the code already uses may be the *right* answer and the issue's proposed reference (land-only
mean) the wrong one. The bound in the issue (`water_fraction × elev_land / agl`) is then the
size of the error the land-only reference would *introduce*. This is the fly#58 pattern — an
issue's framing bounding the solution space — so it goes first, with its rule fixed before the
numbers exist.

Instrument that reads no DEM: **adjacent-frame spacing** against the ~60% designed overlap
(`data-raw/height_calibrate-lower_tail_rolls.R:83-117`, with its random-frame overlap window as
the control). Per frame it separates readings only ~1.6× apart, so it is used *population-wise*:
on coastal frames, which of the two elevations (water-inclusive vs land-only) centres the
implied overlap on the inland control's median. Where the two hypotheses predict differences
below the instrument's resolution, that is reported as unresolvable, not as a verdict.

Reused: centroid cache `data-raw/.cache/centroids/*.rds` (1.67 M frames), harness helpers and
MRDEM path/memory caps from `data-raw/dem_calibrate-coverage_error.R` (`cap_memory()`,
`write_if_changed()`, `save_atomic()`, `pub()`, PSOCK workers), `fly_footprint(dem=)` itself for
every DEM-sized number, spacing/overlap code from the lower-tail script. Land/water from two
witnesses that share no ancestor: FWA-derived land polygon (`bcmaps::bc_bound_hres()`, or the
FWA coastline via `bcdata::filter(BBOX(...))` — never the `BBOX(SHAPE,...)` CQL form) and
MRDEM's own near-zero band.

## Phase 1: Premise — is sea surface the wrong datum at all?
- [x] Write the decision rule into `findings.md` **before** any run: hypothesis W (water-inclusive
      mean, current code) vs L (land-only mean, the issue's reference); the spacing statistic;
      the inland control; the minimum predicted W–L difference the instrument can resolve
- [x] Probe MRDEM over water at a few coastal sites (Hecate Strait reproduction, a fjord head,
      a tidal flat, far offshore) — band values, exact zeros, where nodata begins — so the
      "ocean reads near-zero" claim has a population, not one window
- [x] Cross-check the two land/water witnesses on those sites (FWA/bcmaps land polygon vs MRDEM
      near-zero band) and record disagreement; lakes are not water for this question (a lake
      surface is at its own elevation and is correct under either hypothesis)

## Phase 2: Population — how many frames, how much could it matter
- [ ] New script `data-raw/dem_measure-coastal_water.R` (noun_verb-detail, harness pattern): select
      DEM-eligible film frames (and digital frames that reach the DEM route) whose nominal
      footprint intersects the coastline; publish n and share of the eligible population
- [ ] For a stratified sample (water fraction × relief × scale, strata from pre-DEM properties),
      run `fly_footprint(dem=)` on contiguous runs and compute per frame: water fraction (both
      witnesses), W mean, L mean, predicted |W–L| width difference = `w × Δelev / agl`
- [ ] Publish the distribution of predicted |W–L|; if it sits below the spacing instrument's
      resolution everywhere, record that and skip to Phase 4 with "not resolvable, physics
      favours W" as the finding

## Phase 3: Verdict — which elevation does the spacing witness accept
- [ ] On sampled coastal runs with resolvable predicted differences, compute implied forward
      overlap under W and under L; compare each against the inland random control's overlap
      distribution; apply the Phase 1 rule as written
- [ ] Controls: inland frames must return the known overlap (reuse the lower-tail script's
      `ctl_ok` refusal); rerun on a subset to confirm determinism
- [ ] Ship the result table(s) as `inst/extdata/dem_coastal_*.csv` via `write_if_changed()` so the
      suite recomputes the published figures

## Phase 4: Decide and land
Contingent on Phase 3; the options below are what each outcome licenses, and whichever lands is
reported at the PR, not re-asked mid-run (unless it changes the output schema — see below).
- [ ] **If W holds (premise false):** no code change to sizing. Correct the "What the sweep is blind
      to → Ocean" bullet in `inst/notes/terrain-correction.md`, add a fly#65 section with the
      measurement, fix the matching sentence in `CLAUDE.md` Key Decisions (fly#58 entry)
- [ ] **If L holds:** a new output column or a changed mean is a schema/behaviour change — stop and
      put the options (`dem_water_fraction` column; exclude near-zero-band cells from the mean;
      refuse over a stated fraction) to the user with a recommendation, continue docs meanwhile
- [ ] Tests: `tests/testthat/test-dem_coastal.R` (or extend `test-fly_footprint_coverage.R`) reading the
      shipped CSVs and recomputing every published table; plus a synthetic fixture — a DEM half
      at 0.1 m, half at 500 m — pinning whichever behaviour the verdict chose
- [ ] NEWS.md entry (numbers derived from the shipped CSVs), CLAUDE.md Architecture line for the
      new script and CSVs; `.Rbuildignore` unaffected (`data-raw/` already excluded — verify)
- [ ] Edit issue #65 body to carry the verdict (premise, instrument, result)

## Validation
- [ ] Tests pass (`devtools::test()`), lintr clean, `pkgdown::check_pkgdown()` if exports change
- [ ] `/code-check` clean on each commit
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion (README carries Measurement + Evidence sections)

