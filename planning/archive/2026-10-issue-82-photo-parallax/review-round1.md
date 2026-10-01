# Review round 1 — data-raw/dem_measure-photo_parallax.R (commit 5675ca8)

Reviewed the committed file (`git show 5675ca8:...`), not the working tree. The working tree
already differs: it moves `vri_over()` above Stage 1 (finding 2). Line numbers below are the
committed file's. Probes ran in a scratch copy; nothing in the repo was run or edited apart from
this file.

## Findings

- **[bug, blocker]** dem_measure-photo_parallax.R:512-514 — `pair_stats()` builds `ystar` with
  `sapply(COLS, function(k) if (k %in% <mid/old>) ifelse(..., gp$rv * gp$C, 0) else 0)`. The
  mid/old branches return a length-n vector and young/post/other return a scalar `0`, so
  `sapply` cannot simplify and returns a **list**. `rowSums()` on a list errors:
  `'x' must be an array of at least two dimensions`. Probed: `class()` is `"list"` and the
  error fires for any n > 1. This crashes every call to `pair_stats()`:
  - Stage 1: every `class` synthetic that reaches `class_phi()` with status ok. The SYN cache is
    written only after the loop, so Stage 1 can never finish and nothing is cached. The
    in-progress smoke includes the class case for src 1, so it will hit this.
  - Stage 4: line 1057, on the first pair that passed the Stage 3 gates.

  Fix: return `numeric(nrow(gp))` in the else branch (or use `vapply(..., numeric(nrow(gp)))`).

- **[bug]** :826 vs :956 — Stage 1 calls `vri_over()` for the class synthetics, but the committed
  file defines it in Stage 3. Every class case fails with "could not find function". The
  uncommitted working tree already moves the definition above Stage 1. Recorded so the fix is
  committed, not left in the tree.

- **[bug]** :950 and :1048 — `FLY_PARALLAX_STOP` is off by one after Stage 2 and after Stage 3.
  The file's own convention is `< n + 1` after stage n: `< 1` after Stage 0 (:595) and `< 2`
  after Stage 1 (:904). But after Stage 2 the test is `< 2` (should be `< 3`), and after Stage 3
  it is `< 3` (should be `< 4`). Consequences:
  - `FLY_PARALLAX_STOP=2` runs the whole network Stage 3.
  - `FLY_PARALLAX_STOP=3` runs Stage 4. Outside smoke, Stage 4 prints phi/D and writes the four
    `inst/extdata/dem_parallax_*.csv` files: the read and the write that a stop exists to
    prevent.

- **[bug: wrong verdict]** :1193-1203 `combine()` — when a source that separates overall has no
  estimate in a decade (e.g. no `mid_l` patches there), the following chain runs:
  1. That source's D is NA in the point estimate and in every resample.
  2. `var(..., na.rm = TRUE)` is NA, so its weight is set to 0.
  3. `sum(wv * vals)` is still NA, because `0 * NA` is `NA` (probed).

  So `D$pt` and every `D$bt` are NA, `boot_fail` is 1, and the decade (and `phi`/`phi_vri`) is
  reported `inconclusive`, when the rule calls for pooling over the sources that separate,
  i.e. reading that decade from radar alone. Lidar is a minority of BC, so a decade with no
  lidar mid patches is likely. Fix: drop sources with zero or non-finite weight from `srcs`
  before forming `pt` and `bt`.

- **[bug: silently wrong number]** :466-478 and :512-515 — the rule's `r` comes from the VRI stand
  under the patch centre. `r` is NA when the centre has no usable origin: it falls in a VRI gap,
  in a non-treed or unaged polygon, or `k` is NA. A patch can still be classed `mid`/`old`,
  because the class needs only 90% of the grown square. The centre can sit in the other 10%.
  - `pair_stats()` then computes `gp$rv * gp$C` as NA, and line 515 replaces it with **0**.
  - In the VRI world that says the camera saw *no* canopy on that mid/old patch. The patch's C
    still enters the observed column.
  - So `Xtr`, and with it phi_VRI and D, are biased toward "less canopy than VRI" by the share of
    such patches. The class synthetic shares the same code, so it cannot catch this.

  Either class such patches `other`, or take `r` from the dominant-class polygons. Do not zero
  them.

- **[fragile: caching blesses a failure]** :1009-1012 (with `fetch_pair` :622-629, `roll_meta`
  :598-611, `window_of` :589-593) — only `error: VRI…` and `thumbnail_http_5xx` are treated as
  transient. Everything else is saved to the pair cache permanently, including:
  - a curl transport error from `curl_fetch_disk()` (timeout or reset, which *raises*);
  - a `bcdata` failure inside `roll_meta()`;
  - HTTP 429;
  - a `/vsicurl/` read error from the MRDEM crop.

  Stage 4 then sees `gate = "error: …"` and silently drops the pair. The "refuse to report with
  holes" check at :1046-1047 passes, because the file exists.

  Separately, when `curl_fetch_disk()` errors mid-transfer it leaves a partial file at `dest`.
  The next run sees `file.size > 0` and reads a truncated JPEG. There is no `.part` and rename
  here, unlike `save_atomic()`.

  A GDAL/curl hiccup on the MRDEM crop can also come back as NA cells with a warning rather than
  an error. That is cached as `no_dem`, or as fewer usable patches.

- **[bug: rule not implemented]** :1191, :1267-1271, :1279-1282, :1297-1300 — a STOP (synthetic
  controls fail, or neither source separates) only overwrites the `verdict` column with
  `not_read`. Every decade's phi, phi_VRI and D with their intervals is still printed to the log
  (outside smoke) and written to `inst/extdata/dem_parallax_verdicts.csv`. The rule says "If any
  fails, STOP … nothing below is read". The code computes and publishes exactly what must not be
  read. Gate the per-decade `pub` and the phi/D columns on `!nzchar(STOPPED)`.

- **[bug: rule not implemented]** :857-858 — Amendment B rule 5 says "Synthetics pass through the
  same pair gates." Only the rotation/scale bound is applied. The gates that are missing:
  - fewer than 50 usable patches;
  - full-model R² < 0.5;
  - SE(ĝ) > 0.1.

  So a synthetic that a real pair's gates would refuse is still judged, and can count as one of
  the ≥ 2 passes. For class cases, `pair_stats()` already returns `r2_full` and `g_se`, so
  `class_phi()` can apply them. Plain cases need the same from `synth_slope()`.

- **[fragile: guard fails toward pass]** :884-888 — a synthetic with `status == "ok"` but an NA
  result gets `pass = NA`. Two cases:
  - `slope` NA (too few usable rows, or an aliased coefficient);
  - for the class set, `phi` finite but `phi_vri` NA (`TRUE & NA` is `NA`).

  `pass = NA` counts as neither pass nor fail. The rule says a synthetic that fails to measure
  FAILS. A case with two passes and one such NA is judged PASS where the rule makes it FAIL.
  Make non-finite results FALSE once status is ok.

- **[fragile: synthetic geometry]** :713-722 `to_full()` — the coarse field has
  `length(rs) = ceiling(nr/8)` cells over the extent `0..length(rs)`, and it is resampled onto
  `nr` rows over the same extent. Sample k sits at pixel `8k - 7`, but its cell centre maps to
  pixel ≈ `7.96k - 3.5`. The parallax field is therefore misregistered against the pixels whose
  heights produced it, from −3.0 px at row 100 to +1.3 px at row 1000. Columns behave the same
  (probed on 1250 x 1250). This is a small, built-in placement error plus a 0.5% scale error in
  every synthetic:
  - registration can absorb it in the terrain cases;
  - the flat cases (unregistered) cannot.

  Small next to a 64 px patch, but it is an unintended bias in the known answer. Fix: set the
  coarse raster's extent to `[rs[1] - st/2, rs[n] + st/2]` in pixel units, against a full
  raster spanning `[0.5, nr + 0.5]`.

- **[fragile]** :345, :378 — `use_open` is decided separately for the normal and mirrored
  placements. If one has ≥ 30 open patches and the other does not, `isTRUE(mirror$r2 >
  normal$r2)` compares R² from different models on different patch sets:
  - one side is a DTM-only fit on open patches;
  - the other is a fit on all patches with C as a free regressor.

  The C-free fit has an extra regressor. The mirror choice can flip for that reason alone. Also,
  if normal's grid search is all NA and mirror's is finite, `isTRUE(NA)` picks normal, and the
  pair returns `no_registration` although mirror registered.

- **[fragile: mislabel]** :1220-1221, :1250-1252 — when a decade fails `own_old()` but has no
  gated pairs in the adjacent decades, `near` equals `rows`. `identical(olds[[sn]], rows)` is
  then TRUE and `old_from` says `own`. The decade is read from its own old column although it
  failed the ≥ 100 patches / ≥ 5 pairs requirement, and the CSV says it passed.

## Checked and clean

- PSOCK: all functions and constants that the worker path reaches are exported. `dtm`, `dsm` and
  `src_rast` are built in `clusterEvalQ` (which evaluates in `.GlobalEnv`), and `setwd(REPO)`
  makes the relative cache paths resolve. Unattached terra: the worker uses only primitives
  (`+`, `==`, `*`, `[[`) on SpatRasters, and those dispatch once the namespace is loaded. No
  `mean()` / `%in%` is called on a SpatRaster. `terra::vect()` on an sfc works (probed).
- `fns_from()` matches the canopy script's definition. The helpers' signatures match their uses:
  `raycast(ring, centre, H, e_w, win, step, n_bisect)`; `head_of` returns `status`/`etag`;
  `save_atomic(x, path)`. The `CENSUS_KEY` construction matches fly#80's `VKEY` (dtm|dsm|source),
  and MRDEM source codes 1/10 match fly#80.
- `BETA0`: 0.1456 (SE 0.0676) from `dem_canopy_lidar.csv`. The sign is right
  (`dtm_resid = DTM − ground`), and the names come out `r`/`l` (probed).
- Sign conventions: `phase_corr` (b[i+s] ~ a[i]), `image_theta` (θ = bearing − atan2(−dx, −dy)),
  `img_vec`, `rot_ground` (image-up → azimuth θ, image-right → θ + 90°), and `synth_pair` (camera
  moves image-up along the bearing, content moves +row) are mutually consistent. `p` and `q` are
  the along- and across-shift projections, and the implied-height algebra is right.
- Pooled regression: FWL per pair with pair-specific nuisance, then summed weighted
  `crossprod`s. This equals the stacked WLS. `gi` indexes the DTM column, and the
  `solve_vri()` right-hand side matches review-2 B2.
- Bootstrap: resampled within decade once, then reused by `%in%` for decade rows and adjacent
  rows, so the decade estimate and its old fallback come from the same draw. β0 is drawn once
  per resample and shared between the main and intercept fits.
- `vri_classes`: area share over a 3005 square grown 60 m. Intersection areas are summed by class,
  which equals a dissolve on a non-overlapping coverage. The source share is taken from
  centre-counted cells in 3979, and a square past the window gives NaN, which falls to `other`
  (probed).

## Not a code defect: the rule's own claim

- :936-942 implements the rule's draw exactly: shuffle, keep the first pair per roll, take 90.
  But the rule's sentence "the draw is uniform within a decade, so every pair carries equal
  weight" is false when a decade has more than 90 rolls:
  - a roll with more eligible pairs reaches the front sooner, so rolls are size-biased;
  - within a roll, each pair has a 1/m chance.

  So a pair's inclusion probability is neither uniform per pair nor per roll. The code is
  faithful to the procedure; the claim about the estimand's weighting is what is wrong.

/Users/airvine/Projects/repo/fly/planning/active/review-round1.md
