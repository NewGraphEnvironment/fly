# Review 2 — Plan agent on the decision rule (2026-10-01)

Returned as reply text (the Plan type cannot write files); condensed here. It was written while
Stage 1 was the last stage in the script, so its notes on Stages 2–4 are against the rule's
text, not their code. No pair data were read.

The three findings that would have changed the answer were B2 (φ_VRI on the wrong scale),
S1 (cutblock-edge contamination of young) and 4a (pair weight carries the canopy signal).

- **S1 Bias — young patches at cutblock edges.** 4-of-5 points at ±patch/4 leave the outer half
  of a patch in the neighbouring stand, often old forest at the photo date; phase correlation
  locks onto the edge. The error is additive on b_young, so it does not cancel:
  φ' = (b_mid − b_young − δ)/(b_old − b_young − δ). Remedy: classify only where a disc of
  radius patch/√2 + 60 m lies inside one polygon, for every class.
- **S2 Bias — VRI age error at the young/post boundary.** age 0–3 at the photo may be a stand
  cut after it. Remedy: young = 3–10, ideally corroborated by a consolidated-cutblock or fire
  date before the photo.
- **S3 Bias — no class intercepts.** b_k is then identified partly from class-level offsets
  (edges, texture, terrain beyond linear DTM). Remedy: class-intercept fit as a pre-registered
  sensitivity; disagreement in direction → unresolved; pick the primary by Phase 0 power.
- **S4 Bias — error in the regressors differs by class.** Residual offset puts ∇DTM·δ into the
  DTM regressor. Remedy: add DTM gradient terms to the nuisance. Radar C reliability by class and
  mountain pine beetle (grey stands low C in 2013, full canopy at the photo) go under
  "cannot see".
- **S5 Gap — cancellation is asserted, not tested.** Remedy: a class-structured synthetic,
  h = DTM + C·(0 young, 1 old, r mid), with and without displacement; pass if φ_mid is within
  ±0.1 of the known answer.
- **S6 Gap — lidar-sourced cells** carry another canopy epoch and no 0.146 DTM bias. Remedy:
  classify only radar-sourced patches.
- **B2 Bug — φ_VRI is on the wrong scale.** It is in units of today's canopy where φ_mid is in
  units of (old − young). Under the linear model r_old ≈ 0.71–0.94 and r_young ≈ 0.09–0.38.
  Uncorrected minus corrected is −0.13 (1965) to +0.02 (2005), pushing towards "MORE". The code
  was also not the regression's own slope: it used Σ r·Z⊥² rather than Σ Z⊥·(r·C), summed
  the denominator over mid only, ignored the joint fit, and left vri_num/vri_den unweighted.
  Remedy: y* = r·C on young, mid and old (r clamped to [0, 1]), b̂_k·C on post and other;
  residualise, solve with the same weights, and φ_VRI = (b*_mid − b*_young)/(b*_old − b*_young)
  inside every bootstrap; the verdict comes from D = φ_mid − φ_VRI.
- **3a Bias — the registration-R² gate selects on the outcome.** Seen canopy lowers the
  DTM-only R². Remedy: gate on the full per-pair model's R²; register on C < 2 m patches where
  there are ≥ 30.
- **3b Fine — the q gate.** Report its pass rate by class.
- **4a Bias — w = 1/var(y residual) contains the canopy signal.** Remedy:
  σ = (H − e_w)/median(p) · 1.4826·MAD(q residual).
- **4b Bias — pair scale does not cancel after pooling**, because classes draw on different
  pairs. Remedy: divide y by the pair's own DTM coefficient ĝ, and gate on SE(ĝ) ≤ 0.1, or report
  that as a sensitivity.
- **4c Fine — Frisch–Waugh stacking.**
- **4d Gap — resamples with no young.** Count them as failures; over 1% → unresolved.
- **4e Bias — the pooled-control fallback.** Pool with the adjacent decade only; the estimand is
  precision-weighted.
- **5a Bias — separation ≥ 0.25 favours stopping when the linear model holds**, and "the CI
  excludes 0" is vacuous. Remedy: lower bound ≥ 0.15.
- **5b Bias — a width of 0.6 makes AGREES automatic.** Remedy: four outcomes from D's interval
  (MORE / LESS / AGREES within ±0.15 / INCONCLUSIVE); before Stage 3, compute the
  linear-vs-concave gap in φ_VRI on pilot patches.
- **6 Bugs —** a synthetic that fails to measure is NA, and `all(na.rm = TRUE)` passes it. The
  synthetics also lack scan rotation, a scale difference and across-track tilt, so the q gate
  and the rotation estimate are untested. Pass only usable patches to `pair_stats`; give the VRI
  extent a buffer and run `st_make_valid`.
