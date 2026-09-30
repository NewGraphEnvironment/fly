# Task: Footprints are sized from bare earth, but over forest the camera sees the canopy (#80)

## Problem

`fly_footprint(dem =)` sizes a frame from the mean of a **bare-earth** DEM (MRDEM-30 is a DTM), but over forest the camera images the canopy top. So every frame sized over forest is drawn too wide by about `canopy_height × (land share) / height_agl`, in the same direction — the datum-offset kind of error #9 exists to remove, left at canopy height.

Found while measuring fly#65. There it matters because the land-and-sea mean the package uses (W) and the land-only mean (L) err in **opposite directions**, so a canopy offset changes which is closer. To first order (a uniform canopy over every land cell, not a re-run ray-cast), over 1,242 coastal frames:

| canopy on the land | median(\|W\| − \|L\|) | W area 95th, coastal | inland |
|---|---|---|---|
| 0 m | −0.00287 | 2.16% | 3.18% |
| 15 m | −0.00122 | 2.27% | 3.37% |
| 30 m | +0.00014 | 2.38% | 3.62% |
| 60 m | +0.00220 | 3.05% | 4.97% |

The inland column is the general point: an all-land frame takes the whole shift, so its 95th-percentile linear error goes from 3.18% to 4.97% under 60 m of canopy. Producer: the `canopy` lines of `data-raw/dem_measure-coastal_water.R` (fly#65).

## Context (from plan mode)

`fly_footprint(dem =)` sizes each frame from the mean of a bare-earth DTM (MRDEM-30), but over
forest the camera images the canopy top, so a forested frame is drawn too wide by roughly
`canopy × land share / height_agl`, always in the same direction. fly#65 produced only a
first-order, uniform-canopy sensitivity table (`canopy` lines, `data-raw/dem_measure-coastal_water.R:668-683`).
The issue asks to **measure before deciding**: how much of the catalogue sits under canopy that
matters, whether first order holds against a ray-cast on a real surface model, and whether
"pass a DSM" is simply the answer. Outcome licensed: document it, recommend a DSM, or nothing.

**What exploration found:**

- **MRDEM-30 publishes a DSM on the identical grid**, same public bucket, same COG layout:
  `mrdem-30/mrdem-30-dsm.tif` beside `mrdem-30-dtm.tif` (both 185220 x 166668, 30 m, LCC;
  plus a `mrdem-30-source.tif` provenance layer). So `DSM − DTM` is a province-wide canopy
  surface with no reprojection, and `fly_footprint(dem = <DSM>)` is the literal "pass a DSM"
  candidate the issue names.
- **An independent canopy witness is public:** Meta/WRI 1 m canopy height
  (`s3://dataforgood-fb-data/forests/v1/alsgedi_global_v6_float/`, quadkey tiles, a
  `tiles.geojson` index and a `CHM_acquisition_date.tif`). Needed because **presence is not
  provenance**: if MRDEM's DTM was derived *from* its DSM by subtracting a canopy model, then
  `DSM − DTM` is that model, not a measurement, and agreeing with itself proves nothing.
- **The ray-cast is circular for the "recommend a DSM" question.** Ray-cast on the DSM is the
  true footprint *given that surface*; the package's rectangle sized from the same DSM will
  agree with it the way W agreed with T on bare earth. What the ray-cast cannot settle is
  whether the modern canopy is the one the photo saw. Photos run 1930s–2010s; the canopy
  products are ~2011–2020, and BC forest has been logged, burned and regrown in between. A
  DSM applied to a frame shot over a then-clearcut is wrong by the same amount, the other way.
  So the verdict must carry the epoch gap explicitly, stratified by `photo_year`.
- Reusable harness, all in `data-raw/dem_measure-coastal_water.R`: `raycast()`, `densify()`,
  `close_ring()`, the flat/step synthetic controls, `cap_memory()`, `write_if_changed()`,
  `save_atomic()`, `pub()`, the PSOCK run loop, run selection (10 consecutive frames on a roll),
  and `fly_footprint()` for every sized number. Coarse-overview reader: `gdal_translate -outsize`
  against the COG's own overviews (`data-raw/dem_calibrate-coverage_error.R:151-170`). Centroid
  cache (1.67 M frames) and `mrdem_coarse.tif` are present under `data-raw/.cache/`.
- Test pattern: `tests/testthat/test-fly_footprint_coastal.R` recomputes every published table
  from the shipped `inst/extdata/dem_coastal_*.csv`.
- Docs to change whichever way it lands: `R/fly_footprint.R:760-816` ("DEM sources", and the
  coastal paragraph's "A canopy can reverse the first"), `inst/notes/terrain-correction.md:1008-1030`
  and `:1097` ("Canopy … No canopy-height model was used"), `CLAUDE.md` fly#65 entry, NEWS.

## Phase 1: Rule and instruments, fixed before any frame is measured
- [ ] Write the decision rule into `findings.md` before any run: the primary quantity (linear
      area error of the DTM-sized rectangle W_dtm against the ray-cast on the DSM, T_dsm), the
      materiality threshold (95th percentile ≥ 1% of width over forested frames, the #65
      convention), and what licenses each outcome — *nothing* / *document* / *recommend a DSM* —
      with the epoch condition the DSM recommendation must also meet
- [ ] Establish provenance of MRDEM's `DSM − DTM`: NRCan's product documentation plus the
      `mrdem-30-source.tif` layer over BC — is the DTM derived from the DSM, and from which
      sources (GLO-30 X-band under-reads canopy; CDEM/lidar differ)
- [ ] Probe both canopy surfaces at a handful of sites (old-growth coast, interior pine,
      recent clearcut, alpine, urban): `DSM − DTM` against Meta CHM aggregated to 30 m, and
      Meta's acquisition date; record where they disagree before either is trusted
- [ ] Extract `raycast()`, `densify()`, `close_ring()` and the two synthetic controls into a
      sourced helper (`data-raw/dem_raycast-functions.R`); `dem_measure-coastal_water.R` sources
      it — a pure move, its controls must still print the same figures

## Phase 2: Population — how much of the catalogue sits under canopy that matters
- [ ] New script `data-raw/dem_measure-canopy_height.R` (harness pattern, `FLY_CANOPY_SMOKE=1`):
      coarse overviews of DSM and DTM via `gdal_translate -outsize`; for every DEM-eligible film
      frame (#58's denominator), mean `DSM − DTM` under its nominal footprint and the first-order
      predicted width error `canopy / height_agl`
- [ ] Publish the distribution overall and by scale band and by decade; the share of frames
      over 0.5% and 1%

## Phase 3: Ray-cast — does first order hold, and what does a DSM buy
- [ ] Stratified sample of runs (canopy × scale × relief, strata from pre-DEM properties, plus
      a no-canopy control stratum); both synthetic controls must pass first
- [ ] Per frame: T_dsm (ray-cast on DSM), T_dtm (ray-cast on DTM, replicates #65's base), W_dtm
      (`fly_footprint(dem = DTM)`, the package today), W_dsm (`fly_footprint(dem = DSM)`); score
      linear area error, and realised against first-order predicted shift
- [ ] Independent-witness subsample: repeat T against DTM + Meta CHM (aggregated to 30 m), so
      the magnitude does not rest on `DSM − DTM` alone
- [ ] Epoch: report W_dtm vs W_dsm by `photo_year` against the canopy product's date; state the
      clearcut-then case as the symmetric error a DSM introduces
- [ ] Ship `inst/extdata/dem_canopy_*.csv` via `write_if_changed()`

## Phase 4: Decide and land
Contingent on Phase 3; whichever lands is reported at the PR. A new output column or changed
default is a schema/behaviour change and goes to the user with options, docs continuing meanwhile.
- [ ] Apply the Phase 1 rule as written; `inst/notes/terrain-correction.md` gets a fly#80
      section built from producer lines, replacing the "No canopy-height model was used" bullet
      and qualifying the #65 canopy table with the measured answer
- [ ] `R/fly_footprint.R` "DEM sources": add or decline MRDEM's DSM with the measured reason and
      the epoch caveat; revise the coastal paragraph's canopy sentence; `devtools::document()`
- [ ] `tests/testthat/test-fly_footprint_canopy.R`: recompute every published table from the
      shipped CSVs; a synthetic fixture (flat DTM, DSM = DTM + c) pinning that the package sizes
      from whichever surface it is handed
- [ ] NEWS.md (numbers from the CSVs), CLAUDE.md Architecture line for the script/helper/CSVs and
      the fly#65 Key Decisions sentence on canopy; edit issue #80's body to carry the verdict

## Validation

- [ ] Tests pass (`devtools::test()`), lintr clean
- [ ] `/code-check` clean on each commit
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion (README carries Measurement + Evidence)

## Verification

- Synthetic controls print and pass (flat < 1e-5, step convergence) in both scripts after the
  helper extraction; `FLY_COASTAL_SMOKE=1` of the #65 script still runs
- `FLY_CANOPY_SMOKE=1` end to end before the full run; the full run refuses to report if any run
  errored (the #65 guard)
- `NOT_CRAN=true` `devtools::test()` green, with the new test file recomputing the shipped tables
- Restore-the-bug check on the new tests: perturb one shipped CSV value and confirm a table
  assertion goes red
