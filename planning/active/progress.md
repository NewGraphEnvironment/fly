# Progress — Photo parallax as a witness of the surface the camera saw at the photo date (#82)

## Session 2026-10-01

- Plan-mode exploration — phases approved by user ("go all phases")
- Created branch `82-photo-parallax-as-a-witness-of-the-surfa` off main
- Scaffolded PWF baseline from issue #82 with approved phases
- Next: start Phase 1
- Plan review (Plan agent) returned 14 findings → `review-1.md`; disposition in `findings.md`
- Pilot matcher on bc5282 226–236: DTM slope ≈ 1 on all 7 pairs; computed canopy coefficients
  before a rule existed — disclosed as a leak, roll excluded
- Plan revised (Phase 0 added, Estimator A dropped, in-pair VRI controls)
- Phase 0 complete: matcher made robust (candidate-verified global shift), 11 of 13 pilot pairs
  measured, controls counted, power pooled SE(φ) ≈ 0.05 → proceed. Amendment A drops the
  digital PATB control. Logs `data-raw/.cache/logs/parallax_phase0*.log`
- Script `data-raw/dem_measure-photo_parallax.R` written (Stages 0–4). Stage 1 under a1 FAILED
  its synthetic thresholds (bcc01030; bc85054 unmeasured). Rule review (review-2) returned;
  synthetic harness tested Hann sampling, gradient nuisance and three registration schemes.
  Amendment B fixed; algorithm a2. Smoke run caught a PSOCK `mean()` dispatch bug (colour
  thumbnails) and an `apply(X =)` collision; neither computed a coefficient.
- Stage 1 under a6: plain synthetics pass, pooled class synthetic FAILS in both sources → STOP
  at verdict 1; no canopy slope computed on any pair of the real draw
- Record written (note section, test, NEWS, CLAUDE.md), reviewed three rounds to a 137-claim
  enumeration; follow-up filed as fly#85
