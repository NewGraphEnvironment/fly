# Progress — Georef output contract (#56)

## Session 2026-09-28

- Plan-mode exploration — phases approved by user; "go all phases to pr"
- Gate decisions: grayscale just changes to 2 bands (no opt-out arg); relax the
  border + srcnodata refusal rather than add a mask value
- Created branch `56-georef-output-contract-a-real-alpha-band` off main
- Scaffolded PWF baseline from issue #56 with approved phases
- Next: start Phase 1
- Phase 1: measured interior zeros and mask decline over 264 calibration + 10,105 current
  thumbnails (findings.md). Plan review returned; dispositions in review-plan.md
- Phases 2-3: tests first (red for the right reasons), then `-dstalpha` for all outputs,
  refusal relaxed, declined-mask-without-fallback warning (review G4), roxygen rewritten.
  Mutations checked: dropping `-srcnodata` reddens the fallback test; restoring
  `-dstnodata 0` beside alpha reddens the collision test on `anyNA`, not only band count.
  Three aspect tests in test-fly_georef_digital.R used UInt32 fixtures the mask declines;
  given `mask = "none"` (aspect guard runs before masking). Full suite 2585 pass, 0 warn.
