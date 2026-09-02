# Plan review — fly#26 (Plan agent, 2026-09-02)

Full review returned as reply text (the `Plan` agent type has no Write tool). Recorded
here so it survives the session. Verification of each claim is logged in `findings.md`
under "Plan review triage" — several were probed before being acted on, in both
directions, per `karpathy.md` §6.

## Blockers

- **B1** `footprint_bearing` is finite on an EMPTY footprint, so `is.finite()` means
  "was rotated" only by luck — saved by `fly_georef()`'s `empty_fp[j]` skip. NA it in
  the `no_geom` block beside `terrain` / `height_agl` / `dem_coverage`.
- **B2** `paste0(NA_character_, "; ...")` gives the literal string
  `"NA; axis_aligned_no_bearing"` on film, which never touches the camera table.
- **B3** `fly_bearing()` has no frame-gap or step-distance guard, so a sampled roll
  gets cross-leg azimuths, and film footprint geometry becomes **batch-dependent** —
  the same frame covers different ground depending on the subset passed in.
- **B4** After Phase 3, `bearing_to_rotation()` and the `rotation` *argument* become
  unreachable for any film frame on a multi-frame roll. NEWS-level break.
- **B5** The user `rotation` column keeps its precedence and silently changes meaning:
  an absolute corner shift on an axis-aligned square becomes a shift on a ring already
  rotated ~230 degrees. Every by-eye calibration is invalidated.
- **B6** Phase 1 cannot be measured to #38's standard on the bundled film: ~one usable
  overlap pair on the diagonal roll, the well-overlapped roll is cardinal (degenerate),
  and both rolls are 1968 so the "eras disagree" stop condition cannot fire.

## Gaps

G1 the `no_bearing` warning block is still gated on `non_square` and its wording is
now wrong. G2 routing for `assumed_default` and for a `format_size`-sized digital
frame on a square footprint is unenumerated. G3 documentation surface is
under-scoped (`@param rotation`, the whole Rotation section, vignette, NEWS).
G4 the film regression net's two surviving assertions are rotation-invariant, so its
premise dies silently while the test stays green. G5
`test-fly_georef_digital.R:51-68` must change. G6 `test-fly_footprint.R:490-504`
reconstructs pass one with an axis-aligned square. G7 the DEM interaction is absent
from the plan. G8 `non_square` is now a dead local. G9 `findings.md`'s bearing table
has the two rolls swapped. G10 `fly_bearing()` now runs on every film call.

## Ordering

O1 Phase 1 cannot precede the `fly_rectangles()` gate change — real order is
2a -> 1 -> 2b/3. O2 the Phase 4 restore-the-bug wording names a namespace-patching
pattern this suite does not use (`local_mocked_bindings()` is what it uses, and
`test-fly_georef_digital.R:5-10` explains why `.env = asNamespace()` is wrong).

## Assumptions

- **A1** On a square, `hc == ha`, so the constant is only meaningful as a composite
  with `fly_rectangles()`'s vertex order **and** rotation sign. Pin it geometrically:
  vertex 1's azimuth from the centroid is `footprint_bearing + 225` (mod 360).
- **A2** Pre-registered prediction from the issue body: `bc5282_233` was verified by a
  human to need rotation **0** on an axis-aligned ring at bearing ~230. Composed with a
  ring now rotated by ~230, the new constant should quantize to **90 or 270**, not 0 or
  180. Write this down before measuring — a result of 180 means a convention error, not
  a wrong constant.
- **A3** "a film camera is mounted square-on to the flight line" is an assumption, not
  a measurement; crab is uncompensated in the catalogue. State the residual.
- **A4** The "83% at 45 degrees" figure checks out: `2(sqrt(2)-1) = 0.8284`.

## Scope / Acceptance

S1 `fly_summary()` is unaffected (derives from `scale` arithmetically). S2
`fly_filter()` is a fifth consumer the plan omits. S3 measured downstream movement on
the bundled AOI. AC1 every film georef test uses a single frame, so none reaches the
rotated path. AC2 no downstream test pins a number, so "reconcile" is a deliberate
measurement plus NEWS, not something the suite surfaces. AC3 the proposed ring test is
near-vacuous as worded — handedness survives any rotation with `det = +1`.
