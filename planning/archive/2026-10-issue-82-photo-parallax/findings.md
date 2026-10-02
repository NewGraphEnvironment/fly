# Findings — Photo parallax as a witness of the surface the camera saw at the photo date (#82)

## Issue context

## Problem

fly#80 measured that sizing a frame from MRDEM's bare-earth DTM rather than its DSM moves it a weighted median 0.17% of width (95th 0.46%), and found that whether a DSM would be the *right* surface depends on whether the canopy it carries (radar 2011–2015, lidar 2019–2025) existed when the photo was taken. The only instrument used for that was VRI stand origin with a linear height-age curve — a model, not an observation of the photo date. Under it a DSM is worse than the DTM on about 15% of 1970s frames where the canopy matters.

Nothing in fly#80 observes the surface the camera actually saw.

## A public instrument that does

The photos themselves. fly already correlates adjacent-frame thumbnails (`data-raw/georef_calibrate-corner_mapping.R`). For two frames adjacent by number, the image shift Δ between them and the air base B give the height of the imaged surface below the camera, `H − e_seen = f · B / Δ`, at the photo date.

Catalogue centroids are noisy, so per frame this is weak. fly#65's design applies: a within-roll slope of the implied surface on the predicted canopy offset (`DSM − DTM` under the frame), where a slope of 1 means the canopy was seen and 0 means bare earth.

## What is not known

- Whether thumbnail resolution resolves a shift of a few tenths of a percent.
- Whether centroid error averages out within a roll at the canopy offsets that occur (median a few metres).

## Approach

Measure before deciding, as fly#58, fly#65 and fly#80 did: fix the rule before any frame is measured, use synthetic controls, and report the slope by decade.


## Pilot probe — bc5282 226–236, 1968 (2026-10-01, scratch scripts, before any rule)

**This leaked.** The probe computed canopy coefficients before the rule existed — review-1
finding 10 is exactly this. Disclosed here, and **roll bc5282 is excluded from the Phase 3
sample** for that reason. What it showed about the instrument (the nuisance half) is usable;
its canopy numbers are not evidence and are not quoted anywhere but here.

- Thumbnails: 1250 x 1250 Byte grey, JPEG quality 85 (`magick identify %Q`; the same on a
  1985 film and a 2012 digital thumbnail). The frame fills the thumbnail, fiducials at the
  corners and edge midpoints, data panel on the right edge.
- Global phase correlation over the 1200 px interior: ~445–470 px row shift on 8 of 10 pairs
  (63% overlap), peak 0.011–0.043; **2 of 10 failed** (227→228 at −46 px, 232→233 at
  205/236), both with peak <= 0.008. A single whole-frame correlation is not robust; needs
  coarse-to-fine or a peak gate.
- Patch matching (64 px windows on a 24 px step, 531–973 patches per pair), parallax along
  the shift direction converted to height relative to the pair median with `H - median(DTM)`,
  regressed on a quadratic in image position + DTM + `DSM − DTM`:
  - DTM slope 0.95–1.13 on all 7 pairs (SE 0.008–0.03); residual SD 2.3–6.0 m.
  - Registering the grid by a ±300 m search on DTM-only R² moved it 0–95 m and raised R² by
    0.000–0.05. Review-1 finding 5: that makes the DTM slope a fitted quantity, not a control.
  - Canopy coefficient (not evidence — see above): −0.23 to +0.28 unregistered,
    −0.13 to +0.13 registered. Against the review's references (~0.15 bare, ~0.82 seen)
    that reads "bare", and is exactly the direction placement attenuation pushes (finding 4),
    so on its own it says nothing.
- Signal at this scale is larger than the plan assumed: 1:12000, f = 153, B ≈ 1,065 m,
  H − h ≈ 1,840 m, global shift ≈ 460 px, so 10 m of canopy ≈ 2.5 px, not 0.8.

## Review 1 — disposition (`review-1.md`)

| # | finding | disposition |
|---|---|---|
| 1 | Estimator A dead: pre-1990 centroid bases are interpolated | Accepted. Dropped; the triple-spacing probe is the recorded reason |
| 2 | Tilt / scan geometry dominate, confound smooth relief | Accepted. Per-patch 2-D shift; quadratic nuisance in image position; report the surviving share of var(DTM), var(C) per pair |
| 3 | References are ~0.15 / ~0.82, not 0 / 1 | Accepted, and superseded by in-pair controls (6): the verdict is rescaled between the measured control slopes, the LidarBC figures are context |
| 4 | Placement attenuates canopy more than DTM | Accepted. Large patches; shrinkage measured by simulation on each measured pair at its own placement uncertainty, per decade |
| 5 | DTM registration circular | Accepted. No registration on the measured outcome; if any, on open patches only, cross-fitted. Fit `1/p` linear in DTM and C; b = coef_C / coef_DTM |
| 6 | No film-side control | Accepted — the central change. VRI-classed patches inside the same pairs: known-young at photo (origin 0–5 y before) and known-old (age >= 80 at photo, origin before photo) |
| 7 | Digital control weaker than implied | Accepted. Digital becomes a matcher/shrinkage calibration, not a pass/fail at 0.916 |
| 8 | Matching realities | Accepted. Coarse-to-fine, Hann, normalised patches, peak gate, pair-bootstrap SEs; synthetic texture from real thumbnails at JPEG 85 |
| 9 | C/DTM collinearity | Accepted. Report r after nuisance; inclusion cut on regressors only |
| 10 | Pilot leaks; feasibility late | Accepted. Phase 0 nuisance-only; bc5282 excluded (above) |
| 11 | No falsifiable acceptance | Accepted. Decade-level prediction from fly#80's epoch r, written in the rule |
| 12 | Mirror not tested | Accepted. Mirror tested per roll in Phase 0 on y-parallax / DTM fit, not on canopy |
| 13 | Outcome boundary right | Agreed. By-products filed, not acted on |
| 14 | Synthetics ill-posed | Accepted. Flat + fake canopy must return 0; synthetics carry tilt, scan rotation, placement error, JPEG 85 |

## Phase 0 — nuisance only (2026-10-01, `data-raw/.cache/logs/parallax_phase0{,b,c}.log`)

Pilot draw: 3 film rolls per decade 1960s–2000s, seed 8201, f 152–154, 1:8000–1:40000,
frame and frame+1 on one roll with the same scale, lens and height. Rolls in fly#80's sample
and bc5282 excluded, so **none of these pilot rolls is eligible for Phase 3** (listed in
`parallax_phase0_pairs.rds`). No coefficient on canopy was fitted on any of them; `C` entered
only as a regressor variance.

- **Thumbnails.** 2 of 15 rolls have no thumbnail URL (bc5117, bc5346). Adjacent thumbnails
  can differ by one row (1250x1249); cropped to the common size.
- **Global shift.** A single whole-frame phase correlation failed on about half the pairs:
  relief parallax (~100 px across a mountain overlap) smears the peak, snow saturates, and
  an unconstrained argmax lands elsewhere. A magnitude window from centroid spacing failed
  too: bc85054 162's catalogue spacing is 2,353 m where the images say ~1,360 m (×1.7).
  What works: the ten highest local maxima at 1/4 resolution, loosely gated to [0.25, 3] of
  the spacing's prediction, each tried as a seed for 128 px patch matching; the one most
  patches confirm wins, and the global shift is the patches' median. 11 of 13 pairs pass;
  bc80041 7 and bcb96099 41 do not (1 and 4 confirming patches).
- **Matching noise.** y-parallax after a quadratic, robust SD (`stats::mad`, already scaled):
  0.16–1.01 px, median ~0.35. *Corrected 2026-10-01:* the first write-up multiplied
  `stats::mad()` by 1.4826 a second time and quoted 0.24–1.50 px. Plain SD is inflated by
  mismatches (to 2.9 px); a gate at 3 robust SDs on the y-parallax residual is used, and is
  blind to relief by construction.
- **Registration** (offset, rotation, scale on the DTM fit of all matched patches, never on
  C): R² 0.37–0.99. Offsets reach 900 m (bc78129, bcb00031, bc85054), consistent with
  bc85054's misplaced centroid. Two pairs ran rotation/scale to the ±8 bounds (bc78110,
  bcb00031): a registration failure, gated in the rule.
- **Mirror.** Normal beats mirrored placement on 10 of 11; the exception is bcb00031, a
  failed registration. Mirror stays a per-pair choice on the registration fit.
- **Nuisance vs signal.** Share of variance surviving the quadratic: DTM 0.03–0.60, canopy
  0.40–0.92 — canopy varies at shorter range than terrain, which is what makes it
  identifiable. r(C, DTM) after the quadratic −0.54 to +0.64.
- **Controls exist but are uneven.** With classes from VRI age at the photo date and a patch
  taking a class when 4 of its 5 sample points agree: young (origin 0–10 y before the photo)
  147 patches over 11 pairs, old (age >= 80 at the photo, treed) 735, the rest 3,150. Young
  is the scarce one; at 0–5 y it was absent from 6 of 11 pairs.
- **Power** (residual variance from the DTM-only fit, information from each class's canopy
  residualised on quadratic + DTM, design effect 4 for patches overlapping by half): pooled
  SE over the 11 pairs young 0.099, old 0.091, rest 0.057. Scaled to 50 pairs a decade:
  0.046 / 0.043 / 0.027. For φ = (b_rest − b_young)/(b_old − b_young) with a control
  separation near 0.4–0.67, SE(φ) ≈ 0.1 per decade at 50–60 pairs, ≈ 0.05 pooled over
  five decades, so the minimum detectable difference pooled is ~0.15. **Under the 0.3 stop
  line; the study proceeds.**

## Amendment A — the digital PATB control is dropped (2026-10-01, before Phase 1 code)

Its two jobs were a matcher check and a measurement of placement shrinkage. The in-pair VRI
controls make shrinkage cancel in φ (both controls and the rest are placed by the same
registration on the same pairs), and the synthetic controls measure the matcher and the
shrinkage directly with a known answer. The digital route would add the fly#38 PATB parsing
traps, a 120 mm format that is extrapolated, and a B/H of ~0.25 that halves the signal, for
a number nothing downstream would read. Recorded rather than silently skipped.

## Decision rule — fixed 2026-10-01, before any Phase 3 pair is measured

### Quantities

A **pair** is film frame A and frame A+1 on one roll, with the same scale, lens and height, both
DEM-eligible in fly#80's census (reported height inside `fly_height_ratio_band()`).

- **Patch**: 64 px window on a 32 px grid inside the overlap. Its 2-D shift between the frames
  comes from phase correlation, coarse to fine (`global_shift()`, `patch_shifts()`).
  - **x-parallax p** is the shift along the global shift direction.
  - **y-parallax q** is the shift across it.
- **Placement**: each patch centre is ray-cast onto MRDEM's DTM (the fly#65 `raycast`) from A's
  catalogue centroid. Image rotation comes from the shift direction and the A→B bearing.
  Placement is then registered: offset, rotation (±8°) and scale (±8%), normal and mirrored.
  The registration maximises R² of `1/p ~ quadratic(x, y) + DTM` over all matched patches, and
  never sees C.
- **DTM, C**: MRDEM-30 DTM and `C = DSM − DTM`, focal-meaned to the patch's ground size and read
  bilinearly at the placed point.
- **Implied height**: `y = (H − e_w)(1 − median(p)/p)`, where `e_w` is the DTM at A's centroid
  and H is the catalogue height.
- **Class**, from VRI (`VEG_COMP_LYR_R1_POLY`) stand age at the photo year,
  `PROJ_AGE_1 − (projection year − photo year)`. A patch takes a class when 4 of its 5 sample
  points (the centre and four points half-way to its corners) agree; otherwise it is `other`.
  | class | condition |
  |---|---|
  | `young` | treed, age 0–10 at the photo |
  | `old` | treed, age ≥ 80 at the photo |
  | `mid` | treed, age 11–79 |
  | `post` | treed, stand originated after the photo |
  | `other` | non-treed, unaged, or no VRI |
- **Model**: per pair, y and each `C·[class = k]` are residualised on that pair's intercept,
  quadratic in image position and DTM. The residuals are stacked over pairs and the class slopes
  `b_k` solved by weighted least squares. Each pair is weighted by `1 / var(residual of y on
  the nuisance)`.
- **φ_mid = (b_mid − b_young) / (b_old − b_young)**: the share of today's canopy the camera saw
  on mid stands, in units of an old stand. **φ_post** is defined the same way.
- **φ_VRI**: what fly#80's model predicts φ_mid to be. The model is linear height-age from
  origin O, so `r = (photo − O)/(2013 − O)`. The predicted slope is `Σ r·C⊥² / Σ C⊥²` over mid
  patches, where C⊥ is the class's residualised canopy.

### Gates — on matching, placement and regressors, never on C's coefficient

- Patch: correlation peak ≥ 0.1, p > 0, the ray met the DTM, finite DTM and C, and the
  quadratic-residual y-parallax within 3 × MAD.
- Pair: matched; registration R² ≥ 0.5; |rotation| ≤ 6° and |scale| ≤ 6%, since a value at the
  ±8 search bound is a failed registration; at least 50 usable patches.

### Sample

- **Frame**: fly#80's census rows (keyed on the same MRDEM ETags), with
  `p_census ≥ 0.0025` (canopy matters), decades 1960–2000. Frame +1 must be in the census on the
  same roll with the same scale, lens and height. Centroid spacing must be within
  [0.15, 0.7] of the format side on the ground; this is a turn and line-break guard, not a
  base.
- **Excluded**: roll bc5282 (the pilot leak) and every Phase 0 pilot roll.
- **Draw**: per decade, rows are shuffled with `set.seed(82)`, one pair is kept per roll, and the
  first **90** are taken. The pooled all-decade figure pools pairs, not decades.
  - *Corrected by code-check round 1*: the rule first said "uniform within a decade, so every
    pair carries equal weight". With one pair per roll, a roll's chance of selection grows
    with its eligible pairs, while the pair's chance within its roll shrinks.
  - The draw is a spread across rolls, not an equal-probability sample of pairs, and the
    estimand is precision-weighted (Amendment B). No design weights are claimed.
- `FLY_PARALLAX_SMOKE=1` draws 2 per decade, into a separate cache.

### Verdicts, in order

1. **Instrument.** Every undisplaced synthetic control passes: κ = 0 slope within 0.10 of 0,
   κ = 1 within 0.15 of 1. If any fails, STOP: "instrument fails its synthetic controls".
   With 150 m of displacement the slope is reported as the placement shrinkage and has no
   threshold.
2. **Controls separate.** Over all decades pooled, `b_old − b_young ≥ 0.25` and the
   pair-bootstrap 95% interval (2,000 resamples of pairs within decade, `set.seed(8203)`)
   excludes 0. Otherwise STOP: "the photos cannot separate canopy that existed from canopy that
   did not". That is recorded as the outcome, and nothing below is read.
3. **Controls per decade or pooled.** A decade uses its own `b_young`, `b_old` when it has at
   least 100 young patches in at least 5 pairs, and the same for old. Otherwise φ uses the
   pooled controls, with the decade's own `b_mid`, and says so.
4. **Resolved.** A decade is resolved when it has at least 10 gated pairs and the 95% interval
   of φ_mid is no wider than 0.6.
5. **Against VRI**, per resolved decade and pooled:
   - **AGREES**: φ_VRI is inside the interval.
   - **MORE CANOPY THAN VRI**: the interval's lower bound is above φ_VRI. VRI's linear curve
     understated the canopy at the photo date, so fly#80's "DSM worse" shares overstate the
     harm.
   - **LESS CANOPY THAN VRI**: the upper bound is below φ_VRI, so fly#80's shares understate
     the harm.
6. **Outcome.** Only `inst/notes/terrain-correction.md` changes (the epoch subsection and the
   "blind to" bullet), whatever the verdict: fly#80's materiality verdict already closed off
   code and defaults. A result that seems to argue otherwise goes to the user at the PR.

### What the rule cannot see, stated before the run

- **The controls are VRI's own.** They are taken at its clean ends, where age is unambiguous
  and the height-age curve's shape barely matters (0–10 y: near bare; ≥ 80 y: near
  asymptote). An old stand still grew between the photo and 2013, so φ = 1 means "as much as
  an old stand", not "all of today's canopy".
- **Patch scale.** A patch is ~140 m (1:10,000) to ~470 m (1:40,000) on the ground, so canopy
  finer than that is averaged.
- **Orientation beyond a quadratic.** Tilt, crab, scan rotation and scale differences are
  modelled; anything of higher order is residual.
- **The scene itself.** Season, snow, leaf-off deciduous stands and shadow length are as they
  were on the day.
- **Census p ≥ 0.25% only.** The verdict is about frames where canopy matters, as fly#80's
  epoch table was.

## Stage 1 under algorithm a1 — FAILED (2026-10-01, `data-raw/.cache/logs/parallax_stage1.log`)

Synthetic controls, not sampled pairs. Under the rule as first fixed, the instrument failed:
- **bcc01030 156:** flat κ=1 1.176 (tolerance 0.15), terrain κ=0 −0.101 (tolerance 0.10).
- **bc85054 162:** every case `no_global`, because the synthetic B was built at the catalogue's
  centroid spacing, which is ×1.7 wrong there. The old code labelled the NA "(shrinkage,
  reported)", which is review-2's silent-pass bug, seen on real output.
- **bc78008 184:** passed; 150 m of displacement was fully recovered (κ=1 1.098).

Recorded as a failure. The a2 instrument below was developed against synthetic frames only:
known answers, no sampled pair.

## Amendment B — fixed 2026-10-01 from review-2 and the synthetic harness, before any sampled pair is read

The smoke run measured 10 pairs drawn with the real seed. Its Stage 4 crashed in `pair_stats`
before any slope existed, so no coefficient was computed on them. Smoke now draws with its own
seed (9182) and prints and writes no slope, φ or D.

**Instrument.**
1. **Hann sampling.** The DEM is read through a Hann kernel of the patch's ground size, matching
   the matcher's window, not a boxcar. In the harness (`scratchpad harness1`), the boxcar
   overstated the flat κ=1 slope (1.128 / 1.168 / 1.138); Hann gave 1.000 / 1.058 / 1.024.
2. **DTM gradient in the nuisance** (review-2 S4). Harness, bc78008 terrain κ=0: −0.049
   without it, +0.011 with it.
3. **Registration** (review-2 3a). Registering on the DTM fit of every patch attenuated the
   synthetic canopy slope from 1.144 to 0.525 (bc78008) and from 1.050 to 0.749 (bc85054)
   (`harness2`).
   - **Registering on open ground** (C < 2 m at the unregistered placement) restored it where
     ≥ 30 open patches exist: bc85054 1.042 and bcc01030 1.024, against 1.050 and 1.062 at
     true placement.
   - **Registering with C as a free regressor** gave 1.052 and 1.045 (`harness3`).
   - **Rule:** open ground when there are ≥ 30 open patches, otherwise C free.
   - **bc78008** (forested lidar, 1:10,000, < 30 open) reached only 0.676–0.689 under either.
     Both ran rotation to the −8° bound (`reg78.R`), which the pair gate refuses, so the
     instrument declines that pair rather than misreporting it. Truth there is 1.232.
   - **Revised, still before any sampled pair (code-check round 1 period):** rotation is no
     longer searched. The image rotation comes from the measured shift and the line's bearing,
     and a free rotation overfits: on bc78008 the search turned 7.5° and scaled 6.3% where the
     truth is 0 and 0. Fixing rotation gave canopy slope 1.122 (from 0.843), full-model R²
     0.996 (from 0.979) and an offset of 21 m (`rot.R`). Offset and scale are still searched.
   - **bc5225 151** (snow, 1967) reads 0.703 at κ=1 even at true placement (`rot2.R`, y-parallax
     robust SD 1.48 px). That is the matcher's own attenuation on saturated texture, a per-pair
     multiplier, which is what the in-pair φ ratio exists to cancel.
4. **Synthetics carry 2-D nuisance**: tilt on both axes, 0.3° rotation and 0.3% scale between
   exposures. Base at a designed 62% overlap, not catalogue spacing. A synthetic that fails to
   measure FAILS.
5. **Acceptance** (κ=1 tolerance widened before any sampled pair, and why). Synthetics pass
   through the same pair gates. A synthetic the gates refuse is *gated*, which is neither pass
   nor fail. So is one the matcher refuses (`no_global`, `no_registration`), exactly as a real
   pair that fails to match is dropped. A synthetic that measures and returns a wrong answer,
   or NA, is a FAIL. Each case (plain flat_C0, flat_C1,
   dtm_C0, dtm_C1; class undisplaced; class displaced 150 m) needs ≥ 2 of its 3 frames
   measured and passing, and none measured and failing.
   - Plain κ=0 must be within 0.10 of 0: an additive bias does not cancel in φ.
   - Plain κ=1 must be within **0.25** of 1. φ is a ratio of two canopy slopes from one matcher,
     so a multiplicative response cancels; at true placement the a2 harness gives 1.04–1.23.
   - New **class-structured synthetic** (review-2 S5): the world is fly#80's VRI model (κ = r
     on mid and old, 0.5 elsewhere) on three pilot frames with old ground (bc5225 151,
     bcb96067 13, bcc04013 120). The measured φ must be within **0.10** of the φ the VRI
     machinery predicts from the same patches. This is the test of the quantity actually
     reported.

**Classes.**
6. **Area share** (review-2 S1). A patch takes a class when ≥ 90% of its footprint, grown by
   60 m, lies in VRI polygons of that class (dissolved by class). The disc-inside-one-polygon
   form review-2 proposed gave **0 classed patches** on the pilots, because a 440–900 m disc
   rarely fits one polygon; neighbouring polygons of one class are not contamination.
7. **Single-source patches** (review-2 S6). ≥ 99% radar or ≥ 99% lidar in MRDEM's source
   layer; mixed footprints are `other`. Radar-only would have dropped 4 of 11 pilot pairs
   entirely: bc78008, bcc01030, bc81009 and bc85054 are all lidar. So mid and old are split by
   source (columns `mid_r`, `mid_l`, `old_r`, `old_l`). The canopy epoch is 2013 on radar and
   2018 on lidar, as fly#80 used.
8. **Young is dropped as a control.** Under rules 6–7 the pilots carry **2 young patches in
   11 pairs** (VRI only, `amendB.R`). Corroborating with consolidated cutblocks dated within 12
   years before the photo found 0. Young stays a reported column with no role in a verdict.
   The bare reference becomes **external, per source**, the slope on C when the camera saw bare
   ground:
   - radar: **0.1456** (SE 0.0676), fly#80's LidarBC ground-minus-DTM on C with an intercept,
     recomputed in the script from `dem_canopy_lidar.csv` and drawn afresh in every bootstrap;
   - lidar: 0, since the DTM is lidar ground.

**Estimand and comparator.**
9. **φ_s = (b_mid_s − β0_s)/(b_old_s − β0_s)** per source. The verdict reads **D_s = φ_s −
   φ_VRI_s**, paired in every bootstrap resample. Sources are pooled by inverse bootstrap
   variance of D, over the sources that separate.
10. **φ_VRI corrected** (review-2 B2). y* = r·C on mid and old patches, with r = clamp((photo −
    O)/(epoch − O), 0, 1) and O the origin of the stand under the patch centre. On young, post
    and other it is the observed slope times C, so those columns cancel. y* is residualised on
    the same nuisance, weighted the same and solved jointly. Under VRI the seen slope is
    β0 + r̄(β1 − β0), so φ_VRI_s = r̄_mid / r̄_old and needs neither β.

**Pooling and weights.**
11. y is divided by **ĝ**, the pair's own DTM coefficient in the full model (review-2 4b).
    New pair gate: SE(ĝ) ≤ 0.1.
12. **Weight** w = 1/σ², with σ = (H − e_w)/median(p) · (robust SD of the y-parallax residual)
    / |ĝ| (review-2 4a). It never involves y's residual.
13. **Pair gate** on the full per-pair model's R² ≥ 0.5, which is symmetric in seen and unseen
    canopy, not on the registration's DTM-only R² (review-2 3a). The rotation/scale gate
    (≤ 6) is unchanged.
14. **Class intercepts are a sensitivity, not the primary** (review-2 S3). On the pilots
    (`amendB.R`, DEFF 4) they raise SE(b) about fourfold or more: mid_r 0.119 → 0.680,
    old_r 0.084 → 0.293, old_l 0.088 → 0.726. A MORE or LESS verdict becomes INCONCLUSIVE when
    the intercept fit's D interval lies wholly on the other side of 0.
15. **Bootstrap**: 2,000 resamples of pairs within decade (`set.seed(8203)`). A decade with
    more than 1% failed resamples is INCONCLUSIVE.

**Thresholds and verdicts.**
16. **Controls separate** (review-2 5a), per source over all decades: the bootstrap lower bound
    of b_old − β0 must be ≥ **0.15**. A source that fails is dropped from the pool. If both
    fail, STOP.
17. **Old fallback**: a decade's own old column needs ≥ 100 patches in ≥ 5 pairs. Otherwise it
    is pooled with the adjacent decades only (review-2 4e).
18. **Four verdicts on D's 95% interval** (review-2 5b), with ≥ 10 gated pairs:
    | verdict | condition |
    |---|---|
    | MORE CANOPY THAN VRI | lower bound > 0 |
    | LESS | upper bound < 0 |
    | AGREES | the interval lies within ±0.15 |
    | INCONCLUSIVE | otherwise |
19. **What the comparison can see** (VRI and C only, `amendB.R`, before Stage 3). Linear
    against concave growth (Chapman–Richards shape, k 0.03, c 1.3) moves φ_VRI by **0.009** on
    radar ground (0.694 → 0.685) and **0.18** on lidar (0.834 → 1.013). On radar the parallax
    cannot tell the growth curves apart; on lidar it can only at a precision of ~0.1.

**What the rule cannot see**, added: radar C reliability differs by class; mountain pine
beetle grey-attack stands carry low C in 2013 but had full canopy at the photo, which raises
b_old; the external bare reference is a cross-tile figure assumed to hold within pairs.

## Stage 1 under algorithm a4 — plain synthetics pass, class synthetics FAIL (2026-10-01, `parallax_stage1_a4.log`)

**Plain cases: every undisplaced one passes.**
- κ=0: −0.029 to +0.045.
- κ=1: 0.989 to 1.123.
- Displaced 150 m, κ=1: 1.111, 1.001, 1.057. Registration recovers the displacement.

**Class-structured cases (Amendment B 5) FAIL.**
- **bcb96067 13**: φ undefined (NA) in both cases. Under the area-share rule it holds 1 mid
  patch against 49 old.
- **bc5225 151**: refused in both cases (registration bound), with φ −1.6 and 5.2.
- **bcc04013 120**: refused undisplaced; displaced 1.066 against 0.922, outside ±0.10.

Under Amendment B this is a STOP. The test was ill-posed. φ is a ratio of two class slopes, and
a single frame with 1–21 mid patches cannot estimate it to ±0.1 even when the instrument is
right. The analysis never estimates φ from one pair; it pools pairs.

## Amendment C — fixed 2026-10-01 after the a4 synthetics, before any sampled pair is read

The class-structured synthetic is measured the way the verdict is.
- **Frames.** All 11 Phase 0 pilot frames that matched: bc5225 151, bc78129 145, bc78008 184,
  bc78110 69, bc85054 162, bc81009 18, bcb96017 221, bcb96067 13, bcc04013 120, bcc01030 156
  and bcb00031 10. Each is undisplaced and displaced 150 m. Each is gated as a real pair is.
- **Pooling.** The frames that pass are pooled by summing `pair_stats()` exactly as Stage 4
  pools pairs. φ_s and φ_VRI_s are computed per source with β0 = 0 (a synthetic has no DTM
  bias).
- **Pass.** For each source whose pooled mid and old columns each have ≥ 30 patches,
  |φ_s − φ_VRI_s| ≤ 0.10, in both the undisplaced and the displaced pool. At least one source
  must qualify.
- **Per-frame φ** is still computed and written, as a diagnostic with no threshold.

The plain-case acceptance (Amendment B 5) is unchanged.

## Code-check — rounds 1–5 on `dem_measure-photo_parallax.R` (`review-round{1..5}.md`)

| Round | Findings | Fixed | Accepted | Inside previous fix? |
|---|---|---|---|---|
| 1 | 13 | 13 | 0 | — |
| 2 | 7 | 7 | 0 | y (6 of 7) |
| 3 | 7 (+ mechanism, enumeration) | 7 | 0 | y (4) |
| 4 | 7 (58-row enumeration) | 7 | 0 | y (3) |
| 5 | 2 (82-row enumeration) | 2 | 0 | y (2) |

- **Mechanism** (named in round 3): a guard computed on one object while the quantity it
  protects is computed on a sibling. The pairs it took were:
  - point against resample;
  - normal against mirror placement;
  - the pair list against a per-source column;
  - the printed line against the CSV column;
  - `diag > 0` against carrying information;
  - an error's text against its cause.
- **How it ended.** Round 5 enumerated every guard, gate, filter, keep-mask, status
  classification and stop check against the quantity each protects: **82 rows**. Two were
  defective, and both fixes are probed (`r5probe.R`).
  - Restore-the-bug check: the old pass logic returns TRUE when every frame of a case is
    refused; the new logic returns FALSE.
  - Digit-masked grouping joins the two "too few values … N" messages.

  The loop ended on that enumeration, not on a reviewer reporting "clean".
- **What the rounds caught that mattered most:**
  - the intercept sensitivity could never run, and failed toward pass;
  - φ_VRI zeroed undated patches;
  - transient failures were cached;
  - a STOP still wrote estimates;
  - a systematic failure would have read as "controls do not separate".
- **Spend:** seven review agents in total (two plan reviews, five code-check rounds), past the
  usual five, because every round through round 5 found a defect inside the previous fix.

## Outcome — STOP at verdict 1: the instrument fails its synthetic controls (2026-10-01, algorithm a6, `parallax_stage1_a6.log`, `parallax_final.log`)

No sampled pair was measured. Under the rule, nothing below the stop is run or read.

**Plain synthetics (Amendment B 5): pass.**
- Undisplaced κ=0: −0.029 to +0.070. κ=1: 0.975 to 1.123.
- Displaced 150 m, κ=1: 1.111, **0.403**, 1.022. bc85054 lost its registration while
  passing every gate. Displaced rows carry no threshold; it is reported.

**Pooled class-structured synthetic (Amendment C): FAIL in both sources and both pools.**

| source | displaced | φ measured | φ known (VRI world) | mid / old patches |
|---|---|---|---|---|
| radar | 0 | 1.356 | 0.860 | 135 / 65 |
| lidar | 0 | 0.793 | 0.550 | 172 / 43 |
| radar | 150 m | 46.35 | 0.860 | 135 / 65 |
| lidar | 150 m | 0.810 | 0.553 | 173 / 43 |

- **Frames.** 7 of the 11 were admitted. The 4 refused: bc5225 and bc81009 (registration
  bound), bc78110 and bcb96017 (no global match).

**Why the instrument fails.** Both mechanisms are visible in the shipped rows; what follows is
diagnosis, not a further measurement.
1. **The matcher's response differs by frame, and the classes sit in different frames.**
   - At κ=1 the plain synthetics read 0.975–1.123 undisplaced, and bc5225 read 0.703 at true
     placement (`rot2.R`).
   - The frames hold their classes unevenly:
     - **bc78129**: 124 mid patches against 3 old, counted in its dominant source; its 3 km
       window is 66% radar.
     - **bcb96067 and bcb00031**: old patches and no mid ones.
   - So the pool's mid and old columns are drawn from different frames.
   - φ is a ratio of a mid slope to an old slope, so pooled over frames it inherits the ratio
     of the frames' responses. Review-2 4b and S5 anticipated this. The pooled synthetic is
     what measured it.
2. **Registration can land wrong and still pass every gate.** Displaced 150 m, the radar pool's
   old slope collapsed to near zero (φ 46), and bc85054's plain κ=1 fell to 0.403. Real
   centroids are off by up to ~900 m (Phase 0), so a test passed only undisplaced would not
   protect the sample.

**What this leaves for the epoch question.** fly#80's VRI estimate remains the only one: a DSM
worse on 15.1% of the 1970s frames where canopy matters. Photo parallax at thumbnail resolution
cannot check it. Per-patch parallax resolves terrain: the DTM slope came back near 1 on every
pilot pair. But the canopy ratio needs matcher response and placement to be equal across frames,
and the synthetics show they are not.

**Outcome (rule verdict 6).** Only `inst/notes/terrain-correction.md` changes: a fly#82
subsection and the "blind to" bullet. The script and its synthetic CSV ship so the stop is
reproducible.

## Record review — three rounds on the note, NEWS, CLAUDE.md and headers (`review-record{1,2,3}.md`)

| Round | Claims enumerated | Wrong or unsupported | Inside previous rewrite? |
|---|---|---|---|
| 1 | 87 | 28 (14 findings + 3 test) | — |
| 2 | 118 | 23 (12 + 4 test) | y |
| 3 | 137 | 9 (7 findings) | y, all wording |

- **The defect class was the one CLAUDE.md names for fly#65 and fly#80:** prose written from
  the story rather than read off a producer line.
- **The worst instances:**
  - "no sampled pair was measured": smoke runs had matched pairs from the real draw. What holds
    is that no canopy slope was computed on one.
  - a causal size argument resting on three frames;
  - a terrain figure credited to the shipped script that came from scratch code.
- **What ended it.** Cutting the prose to claims a shipped row or a cited record produces, then
  enumerating all 137. Round 3's 9 were fixed against producers it had already verified, and
  every test assertion was shown able to fail: ten mutations, all red.
- **Cost.** Ten review agents in all: two plan reviews (the plan and the rule), five
  code-check rounds and three record rounds.

## Errors Encountered

| Error | Resolution |
|-------|------------|
| Whole-frame phase correlation locked onto wrong peaks (~half the pilot pairs) | Candidate peaks verified by 128 px patch matching; median of patches |
| A tight magnitude window from centroid spacing rejected the right peak (bc85054, spacing ×1.7 off) | Window loosened to [0.25, 3]; verification decides |
| `sf` geometry lost after `names(r) <- tolower(names(r))` on a subset print | Transform before renaming, or use the cached roll object directly |
| PSOCK worker: base `mean()` on a SpatRaster returns NA when terra is loaded but not attached | Band arithmetic `(r1 + r2 + r3) / 3` |
| `apply(Z, 2, resid_on, X = N)`: `X` collided with `apply`'s own argument | Anonymous function |
| `gp$r` (VRI ratio) would overwrite `gp$r` (image row) | Renamed `rv` |
| `vri_over()` defined after Stage 1 used it | Moved above Stage 1 |
