# Progress — fly_footprint() assumes a 9-inch negative (#30)

## Session 2026-08-28

- Plan-mode exploration of `fly_footprint()` and its five internal callers
- Established that GSD alone cannot yield footprint width; recorded the
  `pixel_pitch = GSD / scale` identification lever for the follow-up issue
- Phases approved by user; scope contained by handing sensor-width research
  to a separate issue
- Created branch `30-fly-footprint-assumes-a-9-inch-negative` off main
- Scaffolded `planning/` (first use in this repo) and the PWF baseline
- Next: Phase 1 — failing tests
