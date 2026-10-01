# Task: Photo parallax as a witness of the surface the camera saw at the photo date (#82)

fly#80 measured that sizing a frame from MRDEM's bare-earth DTM rather than its DSM moves it a weighted median 0.17% of width (95th 0.46%), and found that whether a DSM would be the *right* surface depends on whether the canopy it carries (radar 2011–2015, lidar 2019–2025) existed when the photo was taken. The only instrument used for that was VRI stand origin with a linear height-age curve — a model, not an observation of the photo date. Under it a DSM is worse than the DTM on about 15% of 1970s frames where the canopy matters.

Nothing in fly#80 observes the surface the camera actually saw.

## Context

fly#80 found sizing from MRDEM's DTM rather than its DSM immaterial (weighted median 0.17% of
width), and left one question it answered only with a model: was the canopy the DSM carries
there at the photo date? VRI stand origin with a linear height-age curve says a DSM would be
worse on 15.1% of the 1970s frames where canopy matters (`inst/notes/terrain-correction.md`
§"Whether the canopy a DSM carries was there"). The note's "blind to" list files fly#82 as the
observed witness: parallax between number-adjacent frames.

**Outcome boundary, stated up front.** fly#80's materiality verdict already closed off any code
or default change, so #82 can revise the note's epoch statement and nothing else. A result that
seems to argue for a code change goes to the user at the PR. A negative result ("thumbnails
cannot resolve it") is a valid outcome and is recorded, as fly#80 recorded HRDEM.

## Things the exploration found that shape the phases

- **Resolution budget.** Film thumbnails are 1250 × 1250 px over the 9-inch frame; digital ones
  ~800 × 1200 RGB. At 60% overlap the image shift is ~500 px, and canopy of 7.6 m at 4,575 m above
  ground is 0.17% of it, so **~0.8 px**. That is reachable only with sub-pixel phase correlation,
  so the estimator must be proved on synthetic pairs at thumbnail resolution, JPEG and all.
- **The issue's estimator is weak because of B.** `H − e_seen = f·B/Δ` needs the air base from
  catalogue centroids. An error of ~100 m on a ~1.4 km base is ~7% per pair against a 0.17%
  signal, so on the order of 10⁴–10⁵ pairs for a usable slope. That is a guess until measured.
- **A second estimator cancels B.** Inside one overlap, the parallax *difference* between patches
  is `Δp/p = Δh/(H − h)`, so B and H scale it out. Regressing per-patch parallax on the patch's
  DTM relief and its `DSM − DTM` gives two slopes. The DTM-relief slope is a **built-in positive
  control on every pair**: terrain is certainly seen, so it must come out at 1. The canopy slope is
  the answer. It needs each patch placed on the ground. Film has no corner-mapping constant
  (fly#26), but the direction of the image shift, together with the flight bearing and frame
  order, fixes the image rotation per pair, 180° ambiguity included. Phase 1 decides between the
  estimators by measurement, not here.
- **A real positive control exists.** Digital frames from 2011–2013 carry PATB exterior
  orientation (precise B and H, `georef_calibrate-corner_mapping.R` §1), and their date matches
  MRDEM's radar canopy epoch. On them the canopy slope must reproduce something near fly#80's
  LidarBC 0.916.
- **Reuse.**
  - `fns_from()` pattern from `dem_measure-canopy_height.R`: pull the overlap window from
    `height_calibrate-lower_tail_rolls.R` and the ray-cast helpers, rather than copying.
  - `pair_r()` and the georef-at-rotation harness from `georef_calibrate-corner_mapping.R`.
  - `fly_fetch(type = "thumbnail")` and `fly_mask()` for the collar.
  - The centroid cache under `data-raw/.cache/centroids`.
  - The MRDEM ETag cache key (`head_of()`), and `write_if_changed()` / `save_atomic()`.
  - fly#80's sample (`inst/extdata/dem_canopy_sample.csv`), so the parallax and VRI verdicts can
    be compared frame for frame.

## Revision after review-1 (2026-10-01)

Review-1 (`review-1.md`) and the pilot (`findings.md`) changed the instrument; the approved
goal, outcome boundary and phase order are unchanged. Estimator A is dropped (pre-1990 bases
are interpolated). The verdict is no longer read against 0/1 but **rescaled between two
in-pair controls classed from VRI** — ground known young at the photo date and ground known
old — so placement attenuation, matcher response and MRDEM's DTM bias cancel to first order.
A Phase 0 measures only nuisance quantities. Roll bc5282 is excluded (pilot leak).

## Phase 0: Feasibility — nuisance quantities only, no canopy coefficient

- [x] JPEG quality of thumbnails (85, film and digital)
- [x] Pilot matcher on bc5282 (recorded as a leak; roll excluded)
- [x] Matcher: coarse-to-fine global shift with a peak gate, per-patch 2-D shift, Hann window,
      normalised patches; failure rate on ~10 film pairs across decades
- [x] Per pair: y-parallax SD, x-parallax residual SD after quadratic + DTM, surviving share of
      var(DTM) and var(C), r(C, DTM) after nuisance; mirror vs non-mirror on the DTM fit
- [x] Control availability: how many pairs carry enough known-young and known-old VRI area
- [x] Power: SE of the rescaled canopy position per decade at the n available; stop if the
      minimum detectable difference exceeds 0.3

## Phase 1: Instrument

- [ ] `data-raw/dem_measure-photo_parallax.R`, staged like the fly#80 script (Stage 0 versions
      and keys, `FLY_PARALLAX_SMOKE`, `FLY_PARALLAX_STOP`), caches under the gitignored
      `data-raw/.cache/photo_parallax/` keyed on MRDEM ETags and an algorithm tag
- [ ] Pairs: frames number-adjacent on one roll, same lens/scale/height, both in
      `fly_height_ratio_band()`; overlap from the measured global shift
- [ ] Estimator: `1/p` linear in DTM and C with a quadratic nuisance in image position, C split
      by VRI class (young-at-photo, old-at-photo, other); pooled per decade with pair fixed
      effects; pair-bootstrap intervals
- [ ] Synthetic controls from real thumbnail texture draped on DTM / DTM + C, with tilt, scan
      rotation, placement error and JPEG 85: flat + fake canopy returns 0; DSM-draped returns 1;
      the shrinkage they produce is reported
- [x] ~~Digital 2011–2013 pairs as a matcher/shrinkage calibration~~ — dropped by Amendment A (findings)

## Phase 2: Decision rule — fixed in `findings.md` before any measured pair is read

- [x] Quantities, sample, thresholds, the rescaled verdict per decade, and the falsifiable
      prediction from fly#80's epoch r
- [x] Stop clause: the controls do not separate, or power fails → "instrument cannot resolve",
      recorded, nothing more run
- [x] What the rule cannot see, stated before the run
- [ ] Amendments dated, landing before the data they govern

## Phase 3: Measure

- [ ] Sample: pairs at fly#80's sampled frames (excluding bc5282 and Phase 0 pilots), topped up
      by a decade-stratified seeded draw if power needs it
- [ ] Run; every figure the note quotes gets a producer line

## Phase 4: Ship the record

- [ ] `inst/extdata/dem_parallax_*.csv` through `write_if_changed()`
- [ ] `tests/testthat/test-fly_footprint_parallax.R` recomputing the note's tables and figures
- [ ] `inst/notes/terrain-correction.md`: fly#82 subsection, "blind to" bullet updated
- [ ] CLAUDE.md Architecture + Key Decisions; NEWS (version bump left to `/gh-pr-merge`)

## Validation

- [ ] Tests pass (`devtools::test()`), lintr clean
- [ ] `/code-check` clean on each commit (rounds until a round finds nothing inside the previous fix; prose claims enumerated against producer lines)
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion (README with Measurement and Evidence), then `/gh-pr-push`

## Verification

The synthetic controls and the digital PATB control must pass before film is believed. The test
file must fail when a note figure is altered, which is checked by mutating one figure and
watching the test go red. `FLY_PARALLAX_SMOKE=1` must run end to end and write nothing.
