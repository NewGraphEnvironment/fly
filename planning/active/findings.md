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
- **Matching noise.** y-parallax after a quadratic, robust (1.4826·MAD): 0.24–1.50 px,
  median ~0.5. Plain SD is inflated by mismatches (to 2.9 px); a 3·MAD gate on y-parallax
  residual is used, and is blind to relief by construction.
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

## Errors Encountered

| Error | Resolution |
|-------|------------|
| Whole-frame phase correlation locked onto wrong peaks (~half the pilot pairs) | Candidate peaks verified by 128 px patch matching; median of patches |
| A tight magnitude window from centroid spacing rejected the right peak (bc85054, spacing ×1.7 off) | Window loosened to [0.25, 3]; verification decides |
| `sf` geometry lost after `names(r) <- tolower(names(r))` on a subset print | Transform before renaming, or use the cached roll object directly |
