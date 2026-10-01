# Code-check round 1 — fly#80 (`data-raw/dem_measure-canopy_height.R`, `tests/testthat/test-fly_footprint_canopy.R`)

Reviewed `git diff main...HEAD` plus the untracked test. Probes ran in a temp copy
(`scratchpad/rv.hIVczO`), nothing in the repo was edited, and the in-flight run was not touched.

Verified clean, so not findings:
- The test file passes, `NOT_CRAN=true testthat::test_file()`: `[ FAIL 0 | PASS 8 ]`.
- The canopy controls pass with margin. Flat: 1.3e-12 / -6.7e-13. Edge: -1.4e-6 at 32 rays and
  -3.5e-7 at 128, with the gap at -3.1e-2 and -7.8e-3 (a 4x fall, threshold 3x).
- `fns_from()` evaluates only the three named definitions. Workers get closures whose environment
  is globalenv, and `meta_paths` / `raycast` / `fly_footprint` resolve on the PSOCK workers.
- Weights `N_h / n_h` are right against the cached census and sample: 12 strata, summing to
  1,437,124 = census minus the 23 NA frames.
- `d_c`, `rho_X`, clause 1 (weighted 95th of `d_c` >= 0.01), clause 2 (95th |rho_dsm| <= 95th
  |rho_dtm| + 0.01), clause 3 (through-origin slope of `imaged_over_dtm` on `mrdem_canopy`) and
  the outcome ladder all match Amendment 1 / 2.
- The DSM ring is a scaling of the DTM ring about the centroid, so one window from the DTM ring
  scaled out to -50 m covers both ray-casts. The inversion control is well posed.
- Summed-area-table indexing (centre at `(x - xmin)/res + 0.5`) and the `cen_bin` accounting are
  right. The cached census has 0 NA `photo_year`, so the `stopifnot` holds.
- The VRI query through `bcdata::filter(INTERSECTS(fpg))` from inside a function works (probed live).

## Findings

- **[bug] data-raw/dem_measure-canopy_height.R:783 with :908**: the epoch verdict's share is
  biased whenever the 250 cap binds. `sample.int(nrow(ep), 250, prob = ep$weight)` samples
  *without replacement* with unequal probabilities, which is successive sampling: heavy units
  are included with probability ~1 and light units well below. Line 908 then weights each drawn
  frame by its design weight `w` again. The correct weight is `w / pi`, where `pi` is the
  inclusion probability, so the light-weight strata are under-represented by a factor `pi`.
  Those are the high-canopy strata (`p_ge_2/fine` w=45.5, `p_0.5_1/mid` 79.6,
  `p_0.25_0.5/coarse` 53.6, the w=1 strata), which is where "DSM worse than DTM" is decided.

  The cap will bind: the sample already holds 252 frames in the p >= 0.5% strata alone, before
  any `p_0.25_0.5` frame with `d_c >= 0.005`. I simulated the draw with the cached stratum
  weights (~342 eligible, 250 drawn, 2,000 reps). Inclusion came out at 1.000 for w >= 902,
  0.95 for w=297, 0.55 for w=79.6, 0.42 for w=53.6, 0.36 for w=45.5, and 0.01 for w=1. So a
  `p_ge_2/fine` frame counts at ~1/2.7 of its population share in the "EPOCH HOLDS" decade
  shares. That share decides RECOMMEND vs DOCUMENT.

  Neither reading of the rule is implemented. Under true PPS (with replacement) the share is
  unweighted. Under a uniform cap the share is `w`-weighted. The present combination is
  neither. Fixing it changes a pre-registered procedure, so it needs an amendment. The simplest
  correct form is a uniform `sample.int(nrow(ep), N_EPOCH)` with the `w` weighting kept, or no
  cap.

- **[bug] data-raw/dem_measure-canopy_height.R:809-817**: the VRI height is at
  `PROJECTED_DATE`, not at the canopy epoch `cy`. A live probe of `VEG_COMP_LYR_R1_POLY` returns
  `PROJECTED_DATE` = 2025-12-31 on every polygon. `h = PROJ_HEIGHT_1` is therefore the 2025
  height, while `c_then = h (py - O) / (cy - O)` treats it as the height at `cy` (2013 / 2018),
  and `c_now = h` is published as "the modern canopy the DSM carries".

  Under the rule's own linear model, the epoch-`cy` values are `c_then = h (py - O)/(yr - O)` and
  `c_now = h (cy - O)/(yr - O)`. Both published metres are high by `(yr - O)/(cy - O)`. That is
  a few percent for old stands and up to ~25% for stands originating near the photo. `young_share`
  uses the same wrong denominator. This affects:
  - the median `c_then` / `c_now` in the epoch pub line;
  - the `c_now`, `c_then` and `young_share` columns of `dem_canopy_epoch.csv`.

  The per-polygon verdict test (`c_now > 2 c_then`) is invariant to this factor. A frame's
  verdict moves only where its polygons differ in `O`, so the decision is close to unaffected;
  the published metres are not.

  Stands with `cy < O <= yr` (disturbed after the DSM epoch) fall into the "replaced since the
  photo" branch with `c_now` = their young height. The DSM, though, carries the stand they
  replaced.

  This follows Amendment 1 literally, so it needs an amendment or a label, not a silent fix.

- **[bug, low] data-raw/dem_measure-canopy_height.R:805, 906**: the epoch denominator departs
  from the rule. A frame whose VRI polygons are all non-treed returns `c_then = NA` and is
  dropped at line 906. Amendment 1's denominator is admitted frames with `d_c >= 0.5%`, and for
  such a frame both errors are 0, so it should count as "DSM not worse". Dropping it raises the
  "DSM worse" share (conservative against RECOMMEND), and the pub line's `n` is not the rule's
  `n`. Frames with no VRI at all (`vri_share = 0`) are a defensible exclusion but are not stated.

- **[fragile] data-raw/dem_measure-canopy_height.R:68, 325, 385, 597, 783**: the sample and the
  epoch draw are not reproducible from a cold cache. `set.seed(80)` runs once at the top, and
  stage 1 consumes RNG only when its caches are missing: `st_sample` at line 325, and
  `sample.int` / `runif` at lines 385-387. So the stratified sample (line 597) and the epoch
  draw (line 783) depend on which caches existed when they were drawn.

  The same applies to the LidarBC per-window cache `p%04d.rds`, which is keyed on the index `i`
  into a draw that changes with that state. A resumed partial probe can therefore splice windows
  from two different draws.

  Nothing is wrong in the cached numbers. A clean rerun just publishes a different sample.
  Re-seed immediately before each draw.

- **[fragile] data-raw/dem_measure-canopy_height.R:847-851, 893-894, 902-911**: several printed
  figures are unweighted medians over a stratified draw. These are the census-calibration median
  `p_census / p30`, the "identity" and "first order" medians, the epoch VRI-coverage medians and
  the per-decade `c_then` / `c_now` medians. None feeds a verdict. If any is quoted in the note as
  a population figure it is wrong by design: the strata are equal-n while the population is 41%
  `p_lt_0.25/fine`. Use `wq(..., weight, .5)`, or label them as sample medians.
