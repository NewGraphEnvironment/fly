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

## Phase 1: Instrument — build and prove it before any frame counts

- [ ] `data-raw/dem_measure-photo_parallax.R` skeleton: staged like the fly#80 script (Stage 0
      versions and keys, `FLY_PARALLAX_SMOKE`, `FLY_PARALLAX_STOP`), with caches under the
      gitignored `data-raw/.cache/photo_parallax/` keyed on the MRDEM ETags and on the algorithm
      tag.
- [ ] Pair builder: frames number-adjacent on one roll, with the same lens, scale and height,
      both inside `fly_height_ratio_band()`, and spacing inside the fly#60 overlap window.
- [ ] Shift estimator: phase correlation with a sub-pixel peak (base `fft()`, no new dependency).
      Collar masked through `fly_mask()`. Global shift per pair, and a patch grid inside the
      overlap.
- [ ] Estimator A (the issue's): frame-level `f·B/Δ`, within-roll slope of implied `e_seen − DTM`
      on `DSM − DTM`.
- [ ] Estimator B (B cancels): per-patch parallax regressed on DTM relief and on canopy, image
      rotation fixed from the shift direction and the bearing.
- [ ] Synthetic controls at thumbnail resolution, JPEG-compressed:
  - a flat surface, which must return slope 0;
  - a canopy step of known height, which must return slope 1;
  - DTM-only against DSM-draped texture, which must return 0 and 1.
      Thresholds are written before the controls are run.
- [ ] Real positive control: 2011–2013 digital pairs with PATB EO. The DTM slope must be ≈ 1 and
      the canopy slope near 0.916.
- [ ] Pilot on a few film rolls: per-pair noise for each estimator, and the n each needs per
      decade. Record it in `findings.md` with its log under `data-raw/.cache/logs/parallax_*`.

## Phase 2: Decision rule — fixed in `findings.md` before any measured frame is read

- [ ] Quantities, the estimator chosen from Phase 1 and why, the sample design, the thresholds,
      verdicts by decade with a roll-bootstrap 95% interval, and the comparison against fly#80's
      VRI epoch table.
- [ ] A stop clause: if the controls fail or the pilot's power cannot reach the decision width,
      the outcome is "instrument cannot resolve". It is recorded and nothing more is run.
- [ ] "What the rule cannot see", stated before the run (tilt #10, thumbnail resolution, scan
      geometry, seasonal and leaf-off effects).
- [ ] Plan-agent review of the rule, run concurrently. Amendments are dated and land before the
      data they govern.

## Phase 3: Measure

- [ ] Sample: fly#80's sampled frames with `d ≥ 0.5%` and their adjacent frames, topped up by a
      decade-stratified draw if Phase 1's power says so. Each draw is seeded, with design weights
      carried.
- [ ] Run, then report the canopy slope by decade beside the VRI "DSM worse" share. Every figure
      the note will quote gets a producer line.

## Phase 4: Ship the record

- [ ] `inst/extdata/dem_parallax_*.csv` (controls, pairs, verdicts), written through
      `write_if_changed()`.
- [ ] `tests/testthat/test-fly_footprint_parallax.R`, which recomputes the note's tables and
      prose figures from the CSVs, as `test-fly_footprint_canopy.R` does.
- [ ] `inst/notes/terrain-correction.md`: a new fly#82 subsection under fly#80's epoch section,
      and the "blind to" bullet updated.
- [ ] CLAUDE.md Architecture entry for the script and a Key Decisions entry. NEWS entry; the
      version bump is left to `/gh-pr-merge`.

## Validation

- [ ] Tests pass (`devtools::test()`), lintr clean
- [ ] `/code-check` clean on each commit (rounds until a round finds nothing inside the previous fix; prose claims enumerated against producer lines)
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion (README with Measurement and Evidence), then `/gh-pr-push`

## Verification

The synthetic controls and the digital PATB control must pass before film is believed. The test
file must fail when a note figure is altered, which is checked by mutating one figure and
watching the test go red. `FLY_PARALLAX_SMOKE=1` must run end to end and write nothing.
