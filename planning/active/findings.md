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

## Errors Encountered

| Error | Resolution |
|-------|------------|
