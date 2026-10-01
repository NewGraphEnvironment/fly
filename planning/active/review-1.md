# Review 1 — Plan agent on task_plan.md (2026-10-01)

Returned as reply text (the Plan type cannot write files); transcribed here.

**Probes the reviewer ran.**
- Pre-1990 film centroids are evenly spaced. Over consecutive frame triples, the share whose two
  air bases are equal within 0.5%: 1965 67%, 1975 77%, 1985 64%, 1995 10%, 2004 24%. Base-ratio
  IQR: 0.998–1.002 up to 1985, 0.95–1.05 after. Before the 1990s, centroid spacing carries no
  per-frame information about B.
- The MRDEM reference slopes are not 0 and 1. From `dem_canopy_lidar.csv` (150 tiles), with an
  intercept:
  - LidarBC ground − MRDEM DTM on `DSM − DTM`: **0.146** (SE 0.068); through the origin, 0.25.
  - LidarBC DSM − MRDEM DTM on `DSM − DTM`: **0.82** (SE 0.06); through the origin, 0.916.
- The centroid cache holds 37k digital frames from 2011–2013, at focal lengths 80, 92, 100 and
  120 mm. Median adjacent spacing is 1,077 m. The 120 mm format is extrapolated, and GSD is 0 at
  100 and 120 mm.
- The overlap window in `height_calibrate-lower_tail_rolls.R` is an inline `quantile()`, so
  `fns_from()` cannot pull it. `pair_r()` is a ground-grid Pearson r, not a shift estimator.

**Findings** (B = Blocker, G = Gap, O = Ordering, A = Assumption, S = Scope, Acc = Acceptance).

1. **B — Estimator A is dead.** B taken from the centroids is interpolated spacing for the
   1960s–80s, its errors are systematic per line, and they do not average out within a roll.
   Drop it.
2. **B — Tilt and scan geometry are the dominant parallax terms.**
   - Sizes, in thumbnail px: dκ gives −dκ·y, ~5 px at 0.5°; scale difference gives a term
     linear in x, ~2 px; dφ gives dφ(f + x²/f), ~7.5 px at 1°; dω gives ~dω·x·y/f. The unknown
     scan offset breaks the exact 1/p form.
   - They are smooth in image position, and so are terrain and canopy, so the two confound.
   - Either model relative orientation from the y-parallax and fit only a plane in x, or fit a
     full quadratic. In both cases, report the share of `var(DTM)` and `var(C)` that survives
     the polynomial.
3. **B/A — The reference slopes are ~0.15 (bare earth seen) and ~0.82 (canopy seen).** Write the
   thresholds against these, split by source layer, with a midpoint boundary of ~0.5.
4. **G — Placement error attenuates the canopy slope more than the DTM slope.**
   - Canopy decorrelates within a stand, the DTM over kilometres, so the canopy/DTM ratio is
     biased toward "bare".
   - Placement error has four sources: interpolated spacing, scale inside the band, tilt
     displacement of 80–240 m, and relief displacement of up to ~150 m.
   - Place patches by ray-cast, use large patches, and measure the shrinkage per decade by
     simulation.
5. **G — Registering the grid to the DTM is circular**: the DTM slope stops being a control, and
   the registration can absorb canopy.
   - Register on open patches only, with cross-fitting, or symmetrically against the DTM and the
     DSM.
   - Gate on the ratio, not on DTM slope = 1, since H − h is uncertain by up to 60%.
   - Fit 1/p linear in DTM and C; then b = coef_C / coef_DTM.
6. **G — No film-side control.** Matching responds to canopy texture, crown shadow, lean and
   occlusion. Add per-decade controls:
   - known-bare at the photo date: disturbance 0–5 years before the photo, forest now;
   - known-canopy: old stands with no disturbance since the photo.
   Rescale the verdict between the two, and stop if they do not separate.
7. **A — The digital control is weaker than the plan implies.**
   - B/H is ~0.25, so canopy is ~0.4–0.5 px.
   - 0.916 is LidarBC first-return, not a prediction of patch parallax.
   - The fly#38 PATB parsing traps apply.
   - Its real value is exact placement: run it at the PATB positions and again with film-like
     perturbation to measure shrinkage.
8. **G — Matching realities.**
   - JPEG pixel-locking, shear on slopes, fixed-in-frame features (fiducials, data panel,
     vignetting) and texture-dependent errors.
   - Remedies: coarse-to-fine, a Hann window, normalisation, a synthetic texture taken from real
     thumbnails at the measured JPEG quality, weights, and pair/roll bootstrap SEs.
   - Rough power: ~100 patches per pair gives SE(b) 0.2–0.4 per pair, and 50+ pairs per decade
     gives 0.05–0.1. Decades are resolvable; frames are not.
9. **G — Collinearity of C with DTM.** Report r after the polynomial, set the inclusion cut on
   regressors only, and pool with pair fixed effects.
10. **O — Feasibility comes after the expensive build, and the pilot leaks.** Add a Phase 0 that
    measures nuisance only. Pilot rolls compute no canopy coefficient and are excluded from the
    Phase 3 sample. Stop if the minimum detectable difference is over ~0.3.
11. **Acc — "Beside the VRI share" is not a test.** Predict a slope of ≈ 0.15 + 0.67·r from
    fly#80's r, and test it per decade, or require a positive slope of the pair slope on r.
12. **A — Orientation.** The direction of the shift resolves 180° but not a mirrored scan; test
    for a mirror. Replace the catalogue overlap window with the measured global shift.
13. **S — The outcome boundary is right.** H from the intercept and the tilts are by-products, to
    be filed, not acted on. Tilt moves out of "cannot see".
14. **G — The synthetic controls as written are ill-posed or too clean.**
    - "Flat must return 0" has no relief variance; use flat ground with a fake canopy layer.
    - Synthetics must include tilt, scan rotation and offset, placement error and JPEG at the
      measured quality, and report the shrinkage they produce.
